
--[[
	LinePlacer:
	* Arranges marked-up text into wrapped lines of text blocks.
	* Handles line-wrap and breaking words.

	LinePlacer uses a temporary word buffer (self.word_buf) to determine if a single word fits
	into a line, or if it has to be moved or broken into smaller fragments. The contents of the
	word buffer should represent one clump of non-whitespace text, with up to one instance of
	whitespace (trailing at the end). When the word buffer contains this whitespace, it is time
	to place the word-fragments and clear the buffer. You also need a check for words with no
	trailing whitespace at the end of your loop.

	USAGE NOTES:
	* When getting the length of the word buffer, use 'self.word_buf_len' instead of '#self.word_buf'.
	  The word buffer may contain junk (recyclable) tables.
	* Do not pass line feeds or empty strings to the word buffer.
--]]

--[[
MIT License

Copyright (c) 2023 RBTS

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

local linePlacer = {}


local REQ_PATH = ... and (...):match("(.-)[^%.]+$") or ""

-- LÖVE Auxiliary
local utf8 = require("utf8")


local textForms = require(REQ_PATH .. "text_forms")


local _mt_lp = {}
_mt_lp.__index = _mt_lp


linePlacer.enum_align = {left = true, center = true, right = true, justify = true}
linePlacer.enum_v_align = {top = true, ascent = true, middle = true, baseline = true, descent = true, bottom = true}


-- * Internal *


-- Helper to get the kerning offset between the last code point of 's1' and the first code point of 's2'. Both strings
--	must have at least one code point.
local function kerningPairs(font, s1, s2)
	--[[
	local kerning = font:getKerning(string.sub(s1, utf8.offset(s1, -1)), string.sub(s2, 1, utf8.offset(s2, 1, 2)))
	print(font, "|"..s1.."|", "|"..s2.."|", "kerning", kerning)
	return kerning
	--]]
	return font:getKerning(string.sub(s1, utf8.offset(s1, -1)), string.sub(s2, 1, utf8.offset(s2, 1, 2)))
end


-- * / Internal *


--- Makes a new linePlacer instance.
-- @param default_f_inf The starting font-info table to use when setting text. Required. (See `font_info.lua` for more info.)
-- @return The linePlacer instance.
function linePlacer.new(default_f_inf)

	-- Assertions
	-- [[
	if type(default_f_inf) ~= "table" then
		error("argumnet #1: bad type (expected table, got " .. type(default_f_inf) .. ")")

	elseif type(default_f_inf.font) ~= "userdata" then
		error("argument #1: bad type for 'default_f_inf.font' (expected userdata, got " .. type(default_f_inf.font) .. ")")
	end
	--]]

	local self = {}

	-- Default resources and settings.
	self.f_inf = default_f_inf
	self.color = false
	self.wrap_limit = math.huge

	-- Shape state flags.
	self.underline = false
	self.strikethrough = false
	self.background = false

	-- A color table to use for shapes when no explicit color is set.
	self.default_shape_color = {1, 1, 1, 1}

	-- Individual colors for underline, strikethrough and background/highlight. When not
	-- populated, falls back to 'self.color' or 'linePlacer.color_default'.
	self.color_ul = false
	self.color_st = false
	self.color_bg = false

	-- Cursor position.
	self.x = 0

	-- Temporary word buffer.
	self.word_buf = {}

	-- Current length of the buffer (anything past this index is old data).
	self.word_buf_len = 0

	-- The max number of buffer entries to reuse. Anything greater than this index is discarded
	-- when invoking clearBuf.
	-- For minimally tagged input, word buffer usage should rarely exceed one entry. It will
	-- increase from tags appearing within words.
	-- Text in reused entries is set to false so that the strings remain eligible for garbage
	-- collection.
	self.word_buf_cutoff = 0

	setmetatable(self, _mt_lp)

	return self
end


--- Resets the cursor X position and empties the word buffer and string buffer. Call between uses.
function _mt_lp:reset()

	self.x = 0
	self:clearBuf()
end


local function writeLineBlock(self, x, blocks, f_inf, font_h, combined, word_w, space_w, has_ws, color, color_ul, color_st, color_bg)
	--print("writeLineBlock(): ", combined)
	local block = textForms.newTextBlock(
		combined,
		f_inf,
		x,
		0,
		word_w,
		font_h,
		space_w,
		has_ws,
		color,
		color_ul,
		color_st,
		color_bg
	)
	blocks[#blocks + 1] = block

	return block
end


-- Clears GC-able references from reused word buffer fragments so that we don't prevent them from being collected.
local function _wipeBufReferences(self)

	for i = 1, self.word_buf_len do
		local fragment = word_buf[i]
		fragment.combined = false
		fragment.word = false
		fragment.space = false

		fragment.f_inf = false

		fragment.color = false
		fragment.color_ul = false
		fragment.color_st = false
		fragment.color_bg = false
	end
end


--- Kerning offsets are rolled into block width dimensions. As a result, it's technically possible that a width
--	may be zero or less.
function linePlacer.setFragmentSize(prev, frag)

	local font = frag.f_inf.font

	frag.word_w = font:getWidth(frag.word)
	frag.space_w = font:getWidth(frag.space)

	-- Intra-fragment kerning 
	if #frag.word > 0 and #frag.space > 0 then
		frag.word_w = frag.word_w + kerningPairs(font, frag.word, frag.space)
	end

	-- Kerning between previous and current fragment. Affects the previous fragment.
	-- Leave 'prev' false/nil if the current fragment is the start of a new line.
	--[[
	    Prev       Frag
	+------+--+ +------+--+
	|word  |sp|-|word  |sp|
	+------+--+ +------+--+

	+------+    +------+--+
	|word  |----|word  |sp|
	+------+    +------+--+

	+------+--+        +--+
	|word  |sp|--------|sp|
	+------+--+        +--+

	+------+           +--+
	|word  |-----------|sp|
	+------+           +--+
	--]]

	-- Differences in the following style fields should prevent inter-fragment kerning from being applied.
	if prev
	and prev.f_inf.font == font -- implicitly covers differences in italic and bold state
	and prev.color_bg == frag.color_bg
	and prev.color_ul == frag.color_ul
	and prev.color_st == frag.color_st
	then
		local p_id, p_w, f_id

		if #prev.space > 0 then
			p_id, p_w = "space", "space_w"

		elseif #prev.word > 0 then
			p_id, p_w = "word", "word_w"
		end

		if #frag.word > 0 then
			f_id = "word"

		elseif #frag.space > 0 then
			f_id = "space"
		end

		if p_id and f_id then
			prev[p_w] = prev[p_w] + kerningPairs(font, prev[p_id], frag[f_id])
		end
	end

	--print("setFragmentSize", prev.combined, prev.word_w
end


local function getLastColoredTextString(coloredtext)
	for i = #coloredtext, 1, -1 do
		local chunk = coloredtext[i]
		if type(chunk) == "string" then
			return i, chunk
		end
	end
	return nil, nil
end


--- Get the scaled kerning offset between the last block in a line and the first fragment to be placed next.
function linePlacer.getBlockFragmentKerning(block, frag)

	--[[
	if true then
		return 0
	end
	--]]

	local f_inf = block.f_inf

	-- Check for style compatibility.
	if f_inf == frag.f_inf
	and block.color_bg == frag.color_bg
	and block.color_ul == frag.color_ul
	and block.color_st == frag.color_st
	then
		local last_text
		if type(block.text) == "table" then
			local _
			_, last_text = getLastColoredTextString(block.text)
			if not last_text then
				error("no strings in this coloredtext. (Can't get kerning against an empty string.)")
			end
		else
			last_text = block.text
		end

		local offset = kerningPairs(f_inf.font, last_text, frag.combined) * f_inf.sx
		--print("linePlacer.getBlockFragmentKerning(): offset:", offset)
		if offset ~= 0 then
			--error("breakpoint")
		end
		return kerningPairs(f_inf.font, last_text, frag.combined) * f_inf.sx
	end

	return 0
end


--- Push a fragment of text onto the word buffer.
-- @param combined Word content plus whitespace. There must be at least one codepoint in the combined text.
-- @param word Just the word content.
-- @param space Just the trailing whitespace content, if applicable.
-- @return The fragment table (which is also appended to self.word_buf).
function _mt_lp:pushBuf(combined, word, space)

	local word_buf = self.word_buf
	local f_inf = self.f_inf

	local fragment = word_buf[self.word_buf_len + 1] or {}
	word_buf[self.word_buf_len + 1] = fragment

	fragment.combined = combined
	fragment.word = word
	fragment.space = space

	fragment.f_inf = f_inf
	fragment.font_h = f_inf.height

	fragment.color = self.color

	local color_fallback = self.color or self.default_shape_color

	fragment.color_ul = self.underline and (self.color_ul or color_fallback) or false
	fragment.color_st = self.strikethrough and (self.color_st or color_fallback) or false
	fragment.color_bg = self.background and self.color_bg or false

	-- Calculate width of word and whitespace parts, including kerning against the last code point
	-- in the buffer.
	local prev = word_buf[self.word_buf_len]
	linePlacer.setFragmentSize(prev, fragment) -- sets fragment.word_w, fragment.space_w

	self.word_buf_len = self.word_buf_len + 1

	-- 'fragment.combined_w' is (word_w + space_w)

	return fragment
end


--- Get the text width of word-buffer contents, plus trailing whitespace if applicable.
-- @return Width of the buffer contents without trailing whitespace; width of trailing whitespace.
function _mt_lp:getBufWidth()

	local word_buf = self.word_buf
	local count = 0

	for i = 1, self.word_buf_len - 1 do
		local frag = word_buf[i]
		local f_inf = frag.f_inf
		count = count + (frag.word_w + frag.space_w) * f_inf.sx
	end

	local space_w = 0
	local last = word_buf[self.word_buf_len]
	if last then
		local f_inf = last.f_inf
		count = count + last.word_w * f_inf.sx
		space_w = last.space_w * f_inf.sx
	end

	return count, space_w
end


--- Clear the word buffer.
-- @param full When true, clears all fragment tables regardless of the cutoff setting.
function _mt_lp:clearBuf(full)

	if full then
		local word_buf = self.word_buf
		for i = #word_buf, 1, -1 do
			word_buf[i] = nil
		end

	else
		-- Discard fragment tables past the cutoff index.
		local word_buf = self.word_buf
		for i = #word_buf, self.word_buf_len + 1, -1 do
			word_buf[i] = nil
		end

		-- Uncomment to blank out all garbage-collectable references in reused fragments on every buffer clear.
		-- May be helpful in some extreme cases.
		--_wipeBufReferences(self)
	end

	self.word_buf_len = 0
end


--- Try to place the word buffer contents into the current block array. The word buffer is cleared when successful, and left as-is when the word doesn't fit.
-- @param blocks The block array to append to.
-- @param break_first When true, always break the first fragment of the word. Needed for this module's implementation of justify alignment.
-- @return true if all contents of the word buffer were placed on the line, false if not.
function _mt_lp:placeBuf(blocks)

	local word_buf = self.word_buf

	-- These values are scaled.
	local w_width, w_space = self:getBufWidth()

	-- Check for kerning between the last block and first fragment, but only if the style is compatible.
	local last_block = blocks[#blocks]
	local first_frag = word_buf[1]
	local bf_kern = 0
	if last_block and first_frag then
		bf_kern = linePlacer.getBlockFragmentKerning(last_block, first_frag)
		w_width = w_width + bf_kern
	end

	--print("placeBuf", "self.x", self.x, "w_width", w_width, "w_space", w_space, "wrap_limit", self.wrap_limit)
	--print("Word fits?", (self.x + w_width <= self.wrap_limit))

	-- Word fits on the current line
	if self.x + w_width <= self.wrap_limit then
		-- Apply kerning offset to last block
		if last_block then
			if last_block.has_ws then
				last_block.ws_w = last_block.ws_w + bf_kern

			else
				last_block.w = last_block.w + bf_kern
			end
		end

		for i = 1, self.word_buf_len do
			local frag = word_buf[i]
			local f_inf = frag.f_inf

			writeLineBlock(
				self,
				self.x,
				blocks,
				frag.f_inf,
				frag.font_h * f_inf.sy,
				frag.combined,
				frag.word_w * f_inf.sx,
				frag.space_w * f_inf.sx,
				(#frag.space > 0),
				frag.color,
				frag.color_ul,
				frag.color_st,
				frag.color_bg
			)

			self.x = self.x + (frag.word_w + frag.space_w) * f_inf.sx
		end
		self:clearBuf()

		return true

	-- Word doesn't fit
	else
		return false
	end
end


--- Fit as much of the word buffer contents as possible into a block array. Intended to be called in a loop. The caller needs to clear the word buffer after the work is finished.
-- @param blocks The block array.
-- @param f Index of the current fragment in the word buffer. The first call should be 1, and subsequent calls should use the fragment index returned by this function.
-- @return The index of the next fragment (f). Work is complete if 'f > self.word_buf_len'.
function _mt_lp:breakBuf(blocks, f)

	local word_buf = self.word_buf

	--[[
	print("breakBuf: current contents (f=="..f..")")
	for i = 1, self.word_buf_len do
		print("", i, "|"..self.word_buf[i].combined.."|")
	end
	--]]

	-- Need to recalculate fragment sizes as we go.
	linePlacer.setFragmentSize(false, word_buf[f])

	while f <= self.word_buf_len do

		--print("f/word_buf_len", f, self.word_buf_len)

		local frag = word_buf[f]
		local frag2 = false
		if f + 1 <= self.word_buf_len then
			frag2 = word_buf[f + 1]
		end

		if not frag2 then
			linePlacer.setFragmentSize(false, frag)

		else
			linePlacer.setFragmentSize(frag, frag2)
		end

		--print("self.x", self.x, "frag.word_w", frag.word_w, "wrap_limit", self.wrap_limit)

		if self.x + frag.word_w * frag.f_inf.sx <= self.wrap_limit then
			--print("f: Fits in current line. Append:", frag.combined, "self.x:", self.x)
			local f_inf = frag.f_inf
			writeLineBlock(
				self,
				self.x,
				blocks,
				frag.f_inf,
				frag.font_h * f_inf.sy,
				frag.combined,
				frag.word_w * f_inf.sx,
				frag.space_w * f_inf.sx,
				(#frag.space > 0),
				frag.color,
				frag.color_ul,
				frag.color_st,
				frag.color_bg
			)

			self.x = self.x + (frag.word_w + frag.space_w) * f_inf.sx
			f = f + 1

		else
			--print("f: Doesn't fit in current line. Break fragment.")

			local f_inf = frag.f_inf
			local font = f_inf.font

			-- (XXX: Look for a more efficient way to break words at the first wrap-index.)
			local _, b_wrapped = font:getWrap(frag.combined, self.wrap_limit / math.max(f_inf.sx, 1) - self.x)
			local b_combined = b_wrapped[1]
			--print("initial b_combined", b_combined)

			-- For single characters that can't fit onto a line, the entry in getWrap() will
			-- be an empty string. If that's the case, swap in the first codepoint, and if
			-- applicable, any trailing whitespace.
			-- XXX: LÖVE 12: Get the whole first user-perceivable character plus any trailing whitespace.
			-- http://unicode.org/reports/tr29/
			if b_combined == "" then
				--print("breakBuf: f", f, "word_buf_len", self.word_buf_len, "frag.combined |" .. frag.combined .. "|")
				local o2 = utf8.offset(frag.combined, 2, 1) - 1
				b_combined = string.sub(frag.combined, 1, o2) .. string.match(frag.combined, "%s*", o2 + 1)
				--b_combined = "~"
				--print("b_combined", b_combined)
			end

			local b_word, b_space = string.match(b_combined, "(%S*)(%s*)")
			local b_word_w = font:getWidth(b_word)
			local b_space_w = font:getWidth(b_space)

			--print("frag:", frag.combined, frag.word, frag.space, frag.word_w, frag.space_w)
			--print("b_combined", b_combined, "b_word", b_word, "b_space", b_space, "b_word_w", b_word_w, "b_space_w", b_space_w)

			-- End this line if there is already something here and this reduced fragment
			-- passes beyond the wrap limit.
			if self.x > 0 and self.x + b_word_w * f_inf.sx > self.wrap_limit then
				--print("breakBuf: end early (f=="..f.."). x", self.x, "b_word_w", b_word_w, "f_inf.sx", f_inf.sx, "wrap_limit", self.wrap_limit)

				return f
			end

			--print("PLACING "..b_combined.." AT X "..self.x)
			writeLineBlock(
				self,
				self.x,
				blocks,
				frag.f_inf,
				frag.font_h * f_inf.sy,
				b_combined,
				b_word_w * f_inf.sx,
				b_space_w * f_inf.sx,
				(#b_space > 0),
				frag.color,
				frag.color_ul,
				frag.color_st,
				frag.color_bg
			)

			self.x = self.x + (b_word_w + b_space_w) * f_inf.sx

			-- Remove what we added.
			frag.combined = string.sub(frag.combined, #b_combined + 1)
			frag.word = string.sub(frag.word, #b_word + 1)
			frag.space = string.sub(frag.space, #b_space + 1)

			-- Recalculate frag.word_w and frag.space_w
			linePlacer.setFragmentSize(false, frag)

			--print("new frag combined", frag.combined, "word", frag.word, "space", frag.space)
			--print("#frag.word", #frag.word, "#frag.space", #frag.space, "f", f)

			-- Increment if the non-whitespace part of the fragment has been reduced to an empty string.
			if #frag.word == 0 then
				f = f + 1
			end
		end
	end

	--self:flushStringCache(blocks)

	-- Caller must clear the word buffer when finished.
	--print("breakBuf: end (f=="..f..")")
	return f
end


--- Try to place an arbitrary block on the line. The caller is responsible for setting up the block structure -- see
--	the comments in text_forms.lua for more info.
-- @param blocks The blocks array.
-- @param block The arbitrary block to add.
-- @param force_placement When true, always place the block, regardless of the remaining space.
-- @return true if the block was placed successfully, false if not (try again on a new line).
function _mt_lp:placeArbitraryBlock(blocks, block, force_placement)

	if force_placement or self.x + block.w <= self.wrap_limit then
		block.x = self.x
		blocks[#blocks + 1] = block
		self.x = self.x + block.w
		return true

	-- Block doesn't fit
	else
		return false
	end
end


-- Normalizes to left alignment and returns total width.
local function setInitialHorizontalAlignment(blocks)

	local prev_block = blocks[1]
	if prev_block then
		prev_block.x = 0
	end
	for i = 2, #blocks do
		local block = blocks[i]
		block.x = prev_block.x + prev_block.w + prev_block.ws_w
		prev_block = block
	end

	local last_block = blocks[#blocks]
	if last_block then
		return last_block.x + last_block.w -- don't include trailing whitespace of last block

	else
		return 0
	end
end


--- @param j_x_step Allows for coarse positioning of blocks. Useful for monospaced fonts. For variable width fonts
--	(or if you want the normal justify layout for mono text), use the default (1).
local function justifyImplementation(blocks, remain, x_offset, j_x_step)

	j_x_step = j_x_step or 1
	if type(j_x_step) ~= "number" or j_x_step <= 0 then
		error("argument #3: j_x_step, if specified, must be a number > 0 (usually 1).")
	end

	-- NOTE: This function is destructive, as it changes block sizes to fill gaps.

	-- Count the number of whitespace gaps between blocks, and how much we need to space out blocks.
	-- (Ignore the final block's trailing whitespace.)
	local n_gaps = 0
	for i = 1, #blocks - 1 do
		local block = blocks[i]
		if block.has_ws then
			n_gaps = n_gaps + 1
		end
	end

	local gap_w = 0
	if n_gaps > 0 then -- avoid div/0
		gap_w = remain / n_gaps
	end

	--print("\tjustify: n_gaps", n_gaps, "gap_w", gap_w, "#blocks", #blocks)

	-- Space out blocks that appear after trailing whitespace in the previous block.
	-- This excludes the first block in the line.
	-- Set fractional positions, then floor them in a second pass. Also widen blocks
	-- to close the gaps.
	local placed_n = 1
	local prev_block = blocks[1]
	for i = 2, #blocks do
		local sub_block = blocks[i]
		local h_spacing = 0

		if prev_block.has_ws then
			h_spacing = gap_w
			placed_n = placed_n + 1
		end

		sub_block.x = prev_block.x + prev_block.w + prev_block.ws_w + h_spacing

		prev_block = sub_block
	end

	prev_block = blocks[1]
	for i = 2, #blocks do
		local sub_block = blocks[i]
		--sub_block.x = math.floor(sub_block.x + 0.5)
		sub_block.x = math.floor((sub_block.x) / j_x_step) * j_x_step

		-- Widen block width or whitespace to cover the gaps. This stretches shapes to remove
		-- gaps, and can be helpful when implementing mouse cursor selection.
		if prev_block.has_ws then
			prev_block.ws_w = sub_block.x - (prev_block.x + prev_block.w)

		-- This shouldn't happen, but handle it just in case
		else
			prev_block.w = sub_block.x - prev_block.x
		end

		prev_block = sub_block
	end

	-- One more loop, for indent on a per-block basis.
	if x_offset ~= 0 then
		for i, block in ipairs(blocks) do
			block.x = block.x + x_offset
		end
	end
end


--- Apply horizontal alignment by offsetting a container bounding box, or offsetting block positions in the case of 'justify' alignment.
-- @param box A table containing 'x', 'y', 'w' and 'h' fields.
-- @param blocks The array of text blocks which belong to the bounding box.
-- @param align The horizontal alignment mode: "left", "center", "right" or "justify"
-- @param line_width The intended line width.
-- @param x_offset X pixel offset for indents, margins, padding, etc.
-- @param j_x_step Justify alignment pixel granularity. Should be 1 in most cases.
-- @return Nothing.
function linePlacer.applyAlignBoundingBox(box, blocks, align, line_width, x_offset, j_x_step)

	local blocks_w = setInitialHorizontalAlignment(blocks)
	local remain = math.max(0, line_width - blocks_w)

	if align == "left" then
		box.x = x_offset
		box.w = blocks_w

	elseif align == "center" then
		box.x = x_offset + math.floor(remain / 2 + 0.5)
		box.w = blocks_w

	elseif align == "right" then
		box.x = x_offset + math.floor(remain)
		box.w = blocks_w

	elseif align == "justify" then
		justifyImplementation(blocks, remain, 0, j_x_step)
		box.x = x_offset
		box.w = line_width

	else
		error("unknown align setting: " .. tostring(align))
	end
end


--- Apply horizontal alignment by offsetting block positions.
-- @param blocks The block array to arrange.
-- @param align The horizontal alignment mode: "left", "center", "right" or "justify"
-- @param line_width The intended line width.
-- @param x_offset X pixel offset for indents.
-- @param j_x_step Justify alignment pixel granularity. Should be 1 in most cases.
-- @return Nothing.
function linePlacer.applyAlignGranular(blocks, align, line_width, x_offset, j_x_step)

	local blocks_w = setInitialHorizontalAlignment(blocks)
	local remain = math.max(0, line_width - blocks_w)

	if align == "left" then
		for i, block in ipairs(blocks) do
			block.x = block.x + x_offset
		end

	elseif align == "center" then
		local offset = math.floor(remain / 2 + 0.5)
		for i, block in ipairs(blocks) do
			block.x = block.x + offset + x_offset
		end

	elseif align == "right" then
		local offset = math.floor(remain)
		for i, block in ipairs(blocks) do
			block.x = block.x + offset + x_offset
		end

	elseif align == "justify" then
		justifyImplementation(blocks, remain, x_offset, j_x_step)

	else
		error("unknown align setting: " .. tostring(align))
	end
end


function linePlacer.getHeight(blocks)

	-- Will return 0 for empty block-arrays. In that situation, the height of a default / currently
	-- selected font may be better.
	local tallest = 0
	for i, block in ipairs(blocks) do
		local f_inf = block.f_inf
		tallest = math.max(tallest, f_inf.height * f_inf.sy)
	end

	return tallest
end


--- Set vertical (in-line) alignment.
-- @param blocks The block array to arrange.
-- @param v_align The vertical alignment setting: "top", "middle" (between baseline and ascent), "ascent", "descent", "baseline" and "bottom"
-- @return Nothing.
function linePlacer.applyVerticalAlign(blocks, v_align)

	if v_align == "top" then
		for i, block in ipairs(blocks) do
			block.y = 0
		end

	elseif v_align == "middle" then -- half of the tallest height
		local middle = -math.huge
		for i, block in ipairs(blocks) do
			local height = (block.type == "text" and block.f_inf.height) or block.h
			middle = math.max(middle, height / 2)
		end
		for i, block in ipairs(blocks) do
			block.y = math.floor(middle - block.f_inf.height/2 + 0.5)
		end

	elseif v_align == "ascent" then
		local ascent = -math.huge
		for i, block in ipairs(blocks) do
			local f_inf = block.f_inf
			ascent = math.max(ascent, f_inf.baseline - f_inf.ascent)
		end
		for i, block in ipairs(blocks) do
			local f_inf = block.f_inf
			block.y = ascent - (f_inf.baseline - f_inf.ascent)
		end

	elseif v_align == "descent" then
		local descent = -math.huge
		for i, block in ipairs(blocks) do
			local f_inf = block.f_inf
			descent = math.max(descent, f_inf.baseline - f_inf.descent)
		end
		for i, block in ipairs(blocks) do
			local f_inf = block.f_inf
			block.y = descent - (f_inf.baseline - f_inf.descent)
		end

	elseif v_align == "baseline" then
		local baseline = -math.huge
		for i, block in ipairs(blocks) do
			local f_inf = block.f_inf
			baseline = math.max(baseline, f_inf.baseline)
		end
		for i, block in ipairs(blocks) do
			local f_inf = block.f_inf
			block.y = baseline - f_inf.baseline
		end

	elseif v_align == "bottom" then
		local bottom = -math.huge
		for i, block in ipairs(blocks) do
			local f_inf = block.f_inf
			bottom = math.max(bottom, f_inf.height)
		end
		for i, block in ipairs(blocks) do
			local f_inf = block.f_inf
			block.y = bottom - f_inf.height
		end

	else
		error("unknown vertical align setting: " .. tostring(v_align))
	end
end


return linePlacer
