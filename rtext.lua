
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


local REQ_PATH = ... and (...):match("(.-)[^%.]+$") or ""


local rtext = {}


-- LÖVE Auxiliary
local utf8 = require("utf8")


-- Troubleshooting
local inspect = require("demo_lib.inspect.inspect")


local fontGroup = require(REQ_PATH .. "font_group")
local media = require(REQ_PATH .. "media")
local linePlacer = require(REQ_PATH .. "line_placer")
local textForms = require(REQ_PATH .. "text_forms")


local _mt_rt = {}
_mt_rt.__index = _mt_rt


local singular_charpattern = "^(" .. utf8.charpattern .. ")"


local function errArgBadType(n, val, expected, level)
	level = level or 2
	error("argument #" .. n .. ": bad type (expected " .. expected .. ", got " .. type(val), level)
end


function _mt_rt:refreshFont()

	local lplace = self.lplace

	local f_grp = self.font_groups[self.f_grp_id]
	--print("refreshFont(): f_grp:", f_grp, "self.f_grp_id:", self.f_grp_id, debug.traceback())
	if f_grp then
		local f_inf = fontGroup.getFace(f_grp, self.bold, self.italic)
		--print("refreshFont(): f_inf: ", f_inf)
		if f_inf then
			self:setFontInfo(f_inf)
			return true
		end
	end

	return false
end


--- Create a new word style. Contains line-level state settings, like font and color references.
-- @param f_grp_id The font-group table to use with this style. Required.
-- @return The word style table.
function rtext.newWordStyle(f_grp_id)

	-- Assertions
	-- [[
	if type(f_grp_id) ~= "string" then
		error("argument #1: bad type (expected string, got " .. type(f_grp_id) .. ")")
	end
	--]]

	local self = {}

	self.f_grp_id = f_grp_id

	self.bold = false
	self.italic = false
	self.strikethrough = false
	self.underline = false
	self.background = false

	self.color = false
	self.color_ul = false
	self.color_st = false
	self.color_bg = false

	return self
end


function _mt_rt:applyWordStyle(word_style)

	--print("applyWordStyle() f_grp_id", word_style.f_grp_id)

	local lplace = self.lplace

	self.f_grp_id = word_style.f_grp_id

	self.bold = word_style.bold
	self.italic = word_style.italic
	lplace.strikethrough = word_style.strikethrough
	lplace.underline = word_style.underline
	lplace.background = word_style.background

	lplace.color = word_style.color
	lplace.color_ul = word_style.color_ul
	lplace.color_st = word_style.color_st
	lplace.color_bg = word_style.color_bg

	self:refreshFont()
end


--- Create a new paragraph style.
-- @param word_style The default word style to use.
-- @return the new paragraph style table.
function rtext.newParagraphStyle(word_style)

	-- Assertions
	-- [[
	if type(word_style) ~= "table" then
		error("argument #1: bad type (expected table, got " .. type(word_style) .. ")")
	end
	--]]

	local self = {}

	self.word_style = word_style

	-- Controls the current wrap-line indent.
	self.indent_x = 0

	-- Increases or decreases the wrap-limit for this line.
	self.ext_w = 0

	self.align = "left" -- "left", "center", "right", "justify"
	self.v_align = "baseline" -- "top", "middle", "ascent", "descent", "baseline", "bottom"

	-- For the last wrap-line, "justify" alignment falls back to "left" if this is false.
	self.justify_last_line = false

	-- Pixel granularity setting for justified text. Useful for paragraphs containing
	-- exclusively monospaced glyphs of the same size. For everything else, use 1.
	self.j_x_step = 1

	--[[
	Indent width hint for tags. A good starting value is the width of the tab character
	for the paragraph's default font. (We don't set it here because we don't have
	direct access to the font yet.)

	Something like:
	paragraph style -> word style -> font-info[1] -> font:getWidth() * font-info.sx
	--]]
	self.hint_indent_w = 20

	-- Spacing between paragraphs.
	self.para_spacing_top = 0
	self.para_spacing_bottom = 0

	-- Spacing between a paragraph and the document edge.
	self.para_spacing_left = 0
	self.para_spacing_right = 0

	-- Spacing between paragraph and inner content.
	self.para_margin_left = 0
	self.para_margin_right = 0
	self.para_margin_top = 0
	self.para_margin_bottom = 0

	-- Enforces a minimum line height for this paragraph
	self.para_min_line_height = 0

	-- Line-level padding -- bottom side only.
	self.line_pad_bottom = 0

	-- Callbacks

	-- Called before the first text chunk is parsed for a paragraph.
	self.cb_initParagraph = false -- (rtext_instance, paragraph, para_style)

	-- Called after a wrap-line is finished.
	self.cb_finishedWrapLine = false -- (rtext_instance, paragraph, line, last_in_paragraph)

	-- Called after a paragraph is finished.
	self.cb_finishedParagraph = false -- (rtext_instance, paragraph, para_style)

	return self
end


function _mt_rt:setParagraphStyle(para_style)

	--[[
	Paragraph style declarations should be the very first thing to appear in a paragraph.
	There should not be more than one paragraph style declaration per line. Some paragraph
	style tags can modify the paragraph (otherwise it's difficult to transfer tag
	parameters). Those tags should check the return status of setParagraphStyle(), and
	fail if it returned false (as it means paragraph state was locked).

	The default paragraph style is applied at the start of processing every paragraph, and
	so it should not mutate the paragraph in ways that might make other paragraph styles
	fail.
	--]]
	--print("setParagraphStyle")

	-- Assertions
	-- [[
	if type(para_style) ~= "table" then
		error("argument #1: bad type (expected table, got " .. type(para_style) .. ")")
	end

	self.pending_paragraph_style = para_style
	self:updateDeferredParagraphState()

	return not self.para_busy
end


-- linePlacer tag reference tables.
rtext.default_tag_defs = require(REQ_PATH .. "tag_defs")


function rtext.new(font_groups, default_f_grp_id, default_color_id, colors, word_styles, para_styles, data)

	-- Assertions
	-- [[
	if type(font_groups) ~= "table" then
		error("argument #1: bad type (expected table, got " .. type(font_groups) .. ")")

	elseif type(default_f_grp_id) ~= "string" then
		error("argument #2: bad type (expected string, got " .. type(default_f_grp_id) .. ")")

	elseif default_color_id and type(default_color_id) ~= "string" then
		error("argument #3: bad type (expected nil/false/string, got " .. type(default_color_id) .. ")")

	elseif colors and type(colors) ~= "table" then
		error("argument #4: bad type (expected nil/false/table, got " .. type(colors) .. ")")
	end

	-- Confirm there is a default font group with at least a regular style font-info and font object.
	local default_f_grp = font_groups[default_f_grp_id]
	if not default_f_grp
	or not default_f_grp[1]
	or type(default_f_grp[1]) ~= "table"
	or type(default_f_grp[1].font) ~= "userdata"
	then
		error("A default font group with a regular type face is required. Group ID: " .. tostring(default_f_grp_id))
	end
	--]]

	local self = setmetatable({}, _mt_rt)

	local default_f_inf = default_f_grp[1]
	self.lplace = linePlacer.new(default_f_inf)

	-- Hash of tag handlers, where the tag ID is the key.
	self.tag_defs = rtext.default_tag_defs

	-- Temporary queue of text generated by tags.
	self.text_ingress = {}

	-- Hint for tag handlers when they encounter a problem.
	-- "silent": consume the tag.
	-- "verbatim": reject the tag, and let the parser treat it as text.
	-- "error": throw an error.
	self.bad_tag_policy = "silent" -- XXX: not implemented

	-- Optional table of assets for tag definitions (textures, etc.).
	-- This is not allocated by default, as none of the core tags make use of it.
	-- When attaching non-core tag defs, check their documentation for requirements.
	self.data = data or false

	-- Tag patterns. These are used in plain mode, and so are literal matches (no string patterns).
	self.t1 = "["
	self.t2 = "]"

	-- Font group tables and colors accessible by string ID
	self.font_groups = font_groups or {}
	self.colors = colors or {}

	-- Style tables accessible by string ID
	self.word_styles = word_styles or {}
	self.para_styles = para_styles or {}

	-- Default resources and settings.
	-- The default paragraph style is applied at the start of processing every paragraph, so make
	-- sure that it doesn't apply any destructive changes that may conflict with further paragraph
	-- style assignments.
	self.default_word_style = rtext.newWordStyle(default_f_grp_id)
	self.default_paragraph_style = rtext.newParagraphStyle(self.default_word_style)

	-- Set true to make a block for every code point. Potentially useful for incremental printing in
	-- message boxes, as it makes every character individually addressable. Not recommended otherwise.
	self.singular_parsing = false

	-- This callback fires when a wrapped line is complete.
	-- You can use it to change the wrap limit or alignment on a per-wrapline basis, change the position of
	-- the line, etc.
	--self.cb_finishedWrapLine -- (self, paragraph, line, last_in_paragraph)
	-- Optional return: next Y position in paragraph.

	-- This callback fires when a paragraph is complete.
	--self.cb_finishedParagraph -- (self, paragraph, para_style)
	-- Optional return: next Y position in documnet.

	-- See this method (and updateParagraphStyle + applyWordStyle) for additional fields.
	self:setDefaultState()

	return self
end


function _mt_rt:setDefaultState()

	local lplace = self.lplace

	-- Store a temp copy of the document width. Used to set the width of paragraphs.
	self.doc_w = 0

	-- Some state changes are deferred to the start of wrapped line processing.
	-- Ditto for paragraphs.
	self.line_busy = false
	self.para_busy = false

	-- Temporary values used to place lines and paragraphs within a document.
	self.ly = 0
	self.py = 0

	self:setParagraphStyle(self.default_paragraph_style)

	-- The following are locked during wrap-line parsing. Do not modify directly.
	-- They will be updated between lines.
	self._align = self.align
	self._v_align = self.v_align

	self._j_x_step = self.j_x_step
	self._indent_x = self.indent_x
	self._ext_w = self.ext_w
end


function _mt_rt:setTagPatterns(open, close)

	-- Assertions
	-- [[
	if type(open) ~= "string" then errArgBadType(1, open, "string")
	elseif #open == 0 then error("argument #1: string must be at least one character in length.")
	elseif type(close) ~= "string" then errArgBadType(2, close, "string")
	elseif #close == 0 then error("argument #2: string must be at least one character in length.") end
	--]]

	-- The same string for both tags is possible but not recommended.
	self.t1 = open 
	self.t2 = close
end


function _mt_rt:updateDeferredWrapLineState()

	if not self.line_busy then
		--print("updateDeferredWrapLineState()")
		self._align = self.align
		self._v_align = self.v_align

		self._j_x_step = self.j_x_step
		self._indent_x = self.indent_x
		self._ext_w = self.ext_w
	end
end


function _mt_rt:updateDeferredParagraphState()

	--print("updateDeferredParagraphState()", debug.traceback())
	if not self.para_busy then
		local lplace = self.place
		local para_style = self.pending_paragraph_style
		if para_style then
			self.pending_paragraph_style = false

			self._paragraph_style = para_style
			self:applyWordStyle(para_style.word_style)

			self.indent_x = para_style.indent_x
			self.ext_w = para_style.ext_w

			self.align = para_style.align
			self.v_align = para_style.v_align

			self.justify_last_line = para_style.justify_last_line
			self.j_x_step = para_style.j_x_step
			self.hint_indent_w = para_style.hint_indent_w

			self.para_spacing_top = para_style.para_spacing_top
			self.para_spacing_bottom = para_style.para_spacing_bottom
			self.para_spacing_left = para_style.para_spacing_left
			self.para_spacing_right = para_style.para_spacing_right
			self.para_min_line_height = para_style.para_min_line_height
			self.line_pad_bottom = para_style.line_pad_bottom

			self.para_margin_left = para_style.para_margin_left
			self.para_margin_right = para_style.para_margin_right
			self.para_margin_top = para_style.para_margin_top
			self.para_margin_bottom = para_style.para_margin_bottom

			self.cb_initParagraph = para_style.cb_initParagraph
			self.cb_finishedWrapLine = para_style.cb_finishedWrapLine
			self.cb_finishedParagraph = para_style.cb_finishedParagraph
		end
	end
end


function _mt_rt:checkParagraphInit(paragraph)

	if not self.para_busy then
		self.ly = self.para_margin_top
		paragraph.x = self.para_spacing_left
		paragraph.w = math.max(0, self.doc_w - self.para_spacing_left - self.para_spacing_right)

		-- Shorten wrap limit. Indent will be handled later (during horizontal alignment processing).
		self.lplace.wrap_limit = paragraph.w + self._ext_w - self.para_margin_left - self.para_margin_right
		--[[
		print(
			"NEW WRAP LIMIT:", self.lplace.wrap_limit,
			"doc_w", self.doc_w,
			"ext_w", self.ext_w,
			"_ext_w", self._ext_w,
			"self.para_margin_left", self.para_margin_left,
			"self.para_margin_right", self.para_margin_right,
			"self.para_spacing_left", self.para_spacing_left,
			"self.para_spacing_right", self.para_spacing_right
		)
		--]]

		if self.cb_initParagraph then
			self:cb_initParagraph(paragraph, self._paragraph_style)
		end

		self:updateDeferredParagraphState()

		--self.lplace.wrap_limit = paragraph.w + self._ext_w
		

		self.para_busy = true
	end
end


function _mt_rt:checkWrapLineInit(paragraph)

	if not self.line_busy then
		self:updateDeferredWrapLineState()
		--self.lplace.wrap_limit = self.doc_w + self._ext_w
		self.lplace.wrap_limit = paragraph.w + self._ext_w - self.para_margin_left - self.para_margin_right
		--print("NEW WRAP LIMIT:", self.lplace.wrap_limit, "doc_w", self.doc_w, "ext_w", self.ext_w, "_ext_w", self._ext_w)

		self.line_busy = true
	end
end


local function assertColorID(self, id)

	local color = self.colors[id]
	if not color then
		error("no color registered with this ID: " .. tostring(id), 2)
	end

	return color
end


function _mt_rt:setFontInfo(f_inf)
	self.lplace.f_inf = f_inf
end


function _mt_rt:setColor(id)

	if not id then
		self.lplace.color = false

	else
		local color = assertColorID(self, id)
		self.lplace.color = color
	end
end


function _mt_rt:setAlign(align)

	--print("rt:setAlign()", align, "line_busy", self.line_busy)

	-- If you change self.align directly, you need to call self:updateDeferredWrapLineState() afterwards.
	-- Do not modify self._align.

	if not linePlacer.enum_align[align] then
		error("unknown alignment setting: " .. tostring(align))
	end

	self.align = align

	self:updateDeferredWrapLineState()
end


function _mt_rt:setVAlign(v_align)

	-- If you change self.v_align directly, you need to call self:updateDeferredWrapLineState() afterwards.
	-- Do not modify self._v_align.

	if not linePlacer.enum_v_align[v_align] then
		error("unknown vertical alignment setting: " .. tostring(v_align))
	end

	self.v_align = v_align

	self:updateDeferredWrapLineState()
end


local function finishWrappedLine(self, paragraph, line, last_in_paragraph)

	-- Empty paragraph
	if not line then
		--print("finishWrappedLine: Empty paragraph. Make an empty line.")
		line = paragraph:appendLine(0, 0, 0, 0)
		-- [[
		local lplace = self.lplace
		local blank = textForms.newTextBlock(
			"",
			lplace.f_inf,
			0,
			0,
			0,
			lplace.f_inf.height * lplace.f_inf.sy,
			0,
			false,
			self.color,
			self.color_ul,
			self.color_st,
			self.color_bg
		)
		line.blocks[1] = blank
		--]]
	end

	local lplace = self.lplace
	local blocks = line.blocks

	local align = self._align
	if not self.justify_last_line and last_in_paragraph and align == "justify" then
		align = "left"
	end

	--print("finishWrappedLine(): self.justify_last_line:", self.justify_last_line, "last_in_paragraph", last_in_paragraph, "align", align)
	local x_offset = self.indent_x + self.para_margin_left

	-- This sets line.x and line.w.
	linePlacer.applyAlignBoundingBox(line, blocks, align, lplace.wrap_limit, x_offset, self._j_x_step)
	linePlacer.applyVerticalAlign(blocks, self._v_align)

	line.y = self.ly
	-- Empty line: Use the current font height.
	if #blocks == 0 then
		line.h = self.lplace.f_inf.font:getHeight()

	else
		line.h = math.floor(linePlacer.getHeight(blocks) + 0.5)
	end
	line.h = math.max(self.para_min_line_height, line.h)

	self.line_busy = false
	self:updateDeferredWrapLineState()

	if self.cb_finishedWrapLine then
		self.cb_finishedWrapLine(self, paragraph, line, last_in_paragraph)
	end

	self.ly = line.y + line.h + self.line_pad_bottom
	--print("NEW SELF.LY", self.ly)
end


local function finishParagraph(self, paragraph)

	local lines = paragraph.lines

	for l, line in ipairs(lines) do
		--paragraph.w = math.max(paragraph.w, line.x + line.w)
		paragraph.h = math.max(paragraph.h, line.y + line.h)
	end
	paragraph.h = paragraph.h + self.para_margin_bottom

	self.py = self.py + self.para_spacing_top
	paragraph.y = self.py

	if self.cb_finishedParagraph then
		self.cb_finishedParagraph(self, paragraph, self._paragraph_style)
	end

	self.py = paragraph.y + paragraph.h + self.para_spacing_bottom
end


local function breakStringLoop(self, paragraph)

	local lplace = self.lplace
	local lines = paragraph.lines

	--print("breakStringLoop: lplace.x", lplace.x)
	if lplace.x > 0 then
		finishWrappedLine(self, paragraph, lines[#lines], false)
		paragraph:appendLine(0, 0, 0, 0)
		lplace.x = 0
	end

	local f = 1
	while f <= lplace.word_buf_len do
		self:checkWrapLineInit(paragraph)
		self:checkParagraphInit(paragraph)

		local blocks = lines[#lines].blocks
		f = lplace:breakBuf(blocks, f)
		if f <= lplace.word_buf_len then
			finishWrappedLine(self, paragraph, lines[#lines], false)
			paragraph:appendLine(0, 0, 0, 0)
			blocks = lines[#lines].blocks
			lplace.x = 0
		end
	end
	lplace:clearBuf()
end


local function parseTextChunk(self, chunk, paragraph)

	-- The first bit of text in a line locks some state for the duration of a line or paragraph.
	if not self.line_busy then
		self:checkWrapLineInit(paragraph)
	end
	self:checkParagraphInit(paragraph)

	local lplace = self.lplace

	local lines = paragraph.lines
	local line = lines[#lines] or paragraph:appendLine(0, 0, 0, 0)

	-- Non-breaking line feeds. These should be injected by tags: line feeds are otherwise
	-- delimiters for paragraphs.
	if chunk == "\n" then
		--print("parseTextChunk: inject non-breaking line feed")
		local blocks = lines[#lines].blocks
		if not lplace:placeBuf(blocks) then
			breakStringLoop(self, paragraph)
		end
		finishWrappedLine(self, paragraph, lines[#lines], false)
		paragraph:appendLine(0, 0, 0, 0)
		lplace.x = 0

	else
		local i, j = 1, 1
		while i <= #chunk do
			local combined, word, space
			-- XXX: LÖVE 12: This needs to handle multi-codepoint characters.
			if self.singular_parsing then
				i, j, combined = string.find(chunk, singular_charpattern, i)
				--[[
				if combined == "" then
					error("code point parsing failed. Possible bad UTF-8 encoding, or not reading "
					.. "from the start of a UTF-8 multi-byte code point.")
				end
				--]]

				if string.find(combined, "%s+") then
					word = ""
					space = combined

				else
					word = combined
					space = ""
				end

			else
				i, j, combined, word, space = string.find(chunk, "((%S*)(%s*))", i)
			end

			--print("parseTextChunk: i,j", i, j, "comb", combined, "word", word, "space |" .. space .. "|")

			if not i or i > j then
				--print("parseTextChunk: break")
				break
			end

			lplace:pushBuf(combined, word, space)

			--print("parseTextChunk: #space > 0?", #space > 0)
			if #space > 0 then
				local blocks = lines[#lines].blocks
				if not lplace:placeBuf(blocks) then
					breakStringLoop(self, paragraph)
				end
				lplace:clearBuf()
			end

			i = j + 1
		end
	end
end


local function parseParagraph(self, str, document)

	local lplace = self.lplace

	lplace.x = 0
	self.ly = 0
	self.doc_w = document.w

	self:setParagraphStyle(self.default_paragraph_style)
	local paragraph = document:appendParagraph(0, 0, 0, 0)

	--print("parseParagraph", "str", str, "#str:", #str)

	local i, j = 1, 1
	while i <= #str do

		-- Look for upcoming tag
		local t1a, t1b = string.find(str, self.t1, i, true)
		j = t1a and t1a - 1 or #str

		-- Handle text between 'i' and before tag start (or end of paragraph)
		--print("parseParagraph i j", i, j, "t1a t1b", t1a, t1b)
		if i <= j then
			local chunk = string.sub(str, i, j)

			parseTextChunk(self, chunk, paragraph)
			i = j + 1
		end

		-- Handle tags. Treat unparsed / malformed tag content as text content.
		if t1a then
			local t2a, t2b = string.find(str, self.t2, t1b + 1, true)
			--print("parseParagraph: handle tags:", t1a, t1b, t2a, t2b)
			if not t2a then
				parseTextChunk(self, string.sub(str, t1a, t1b), paragraph)
				i = t1b + 1

			else
				local tag_defs = self.tag_defs
				local tag_str = string.sub(str, t1a + #self.t1, t2b - #self.t2)
				local id, arg_str = string.match(tag_str, "^(%S+)%s*(.*)")

				-- Execute tag handler.
				--[[
				Return values:
					true: tag was successful.
					false: tag failed, and the text should be passed on verbatim
					"arbitrary", <block>: Handler was successful, and has an arbitrary block to add
						to the document. If the line already has contents and the block doesn't fit,
						it will be moved down to the next line.

					No error checking is done on the incoming block.
				--]]
				local verbatim = false
				if not tag_defs[id] then
					verbatim = true

				else
					local res1, res2 = tag_defs[id](self, arg_str, paragraph)
					if not res1 then
						verbatim = true

					elseif res1 == "arbitrary" then
						local lines = paragraph.lines
						if #lines == 0 then
							paragraph:appendLine(0, 0, 0, 0)
						end

						-- Flush any pending text fragments
						if lplace.word_buf_len > 0 then
							--print("flush remaining fragments before arbitrary block")

							local blocks = lines[#lines].blocks
							if not lplace:placeBuf(blocks) then
								breakStringLoop(self, paragraph)
							end
						end

						-- Try to place on the current line. If the line already has content and there
						-- is not enough space, make a new line and force its placement.
						--print(lines, #lines, lines[#lines])
						if not lplace:placeArbitraryBlock(lines[#lines].blocks, res2, false) then
							if #lines[#lines].blocks > 0 then
								finishWrappedLine(self, paragraph, lines[#lines], false)
								paragraph:appendLine(0, 0, 0, 0)
								lplace.x = 0
							end

							lplace:placeArbitraryBlock(lines[#lines].blocks, res2, true)
						end
					end
				end

				if verbatim then
					--print("parseParagraph: tag failed: ", string.sub(str, t1a, t2b))
					parseTextChunk(self, string.sub(str, t1a, t2b), paragraph)
				end
				i = t2b + 1

				-- Handle any text content pushed by tags
				local text_ingress = self.text_ingress
				if #text_ingress > 0 then
					local z = 1
					while z <= #text_ingress do
						parseTextChunk(self, text_ingress[z], paragraph)
						z = z + 1
					end
					self:clearTextQueue()
				end
			end
		end
	end

	-- Check for last fragments without trailing whitespace
	if lplace.word_buf_len > 0 then
		--print("parseParagraph: check remaining fragments")

		local lines = paragraph.lines
		local blocks = lines[#lines].blocks
		if not lplace:placeBuf(blocks) then
			breakStringLoop(self, paragraph)
		end
		
		--lplace:clearBuf()
	end

	-- Catch paragraphs with tags but no text content
	self:checkParagraphInit(paragraph)

	local lines = paragraph.lines
	finishWrappedLine(self, paragraph, lines[#lines], true) -- clears line_busy
	finishParagraph(self, paragraph)

	return paragraph

end


function _mt_rt:parseText(input, document, input_i, max_paragraphs)

	--self:setDefaultState()
	-- Call self:setDefaultState() before working on a new document.

	document = document or media.newDocument()
	input_i = input_i and math.floor(input_i) or 1
	max_paragraphs = max_paragraphs or math.huge

	-- Assertions
	-- [[
	if type(input) ~= "string" then errArgBadType(1, input, "string")
	elseif type(input_i) ~= "number" then errArgBadType(2, input_i, "nil/number")
	--elseif input_i < 1 or input_i > #input then error("argument #2: string index is out of range.")
	elseif type(document) ~= "table" then errArgBadType(3, document, "nil/table")
	elseif type(max_paragraphs) ~= "number" then errArgBadType(4, max_paragraphs, "nil/number") end
	--]]

	local lplace = self.lplace
	lplace:clearBuf()

	while input_i <= #input do
		--print("\n----------INPUT_I", input_i, "----------\n")
		if max_paragraphs <= 0 then
			break
		end

		self.line_busy = false
		self.para_busy = false

		self:updateDeferredWrapLineState()
		self:updateDeferredParagraphState()

		local j = string.find(input, "\n", input_i, true) or #input + 1
		local str_line = string.sub(input, input_i, j - 1)
		parseParagraph(self, str_line, document)

		input_i = j + 1
		max_paragraphs = max_paragraphs - 1
	end

	return document, input_i
end


--- Arrange paragraphs in the document. Assumes all paragraphs are correctly shaped and that any previous paragraphs are already placed.
function _mt_rt:arrangeParagraphs(document, para1, para2)

	local x, y = 0, 0

	local paragraphs = document.paragraphs
	local prev_para = paragraphs[para1 - 1]

	if prev_para then
		y = prev_para.y + prev_para.h
	end

	for i = para1, para2 do
		local para = document.paragraphs[i]
		para.y = y
		y = y + para.h -- plus paragraph padding

		prev_para = para
	end
end


--- Push a string onto the text queue. Tag Defs use this as a way to inject text content into the document. Note that the ingress text is not parsed for tags.
-- @param str The string content to inject into the document.
-- @return Nothing.
function _mt_rt:pushTextQueue(str)
	table.insert(self.text_ingress, str)
end


--- Clear the text queue.
-- @return Nothing.
function _mt_rt:clearTextQueue()
	local text_ingress = self.text_ingress
	for i = #text_ingress, 1, -1 do
		text_ingress[i] = nil
	end
end


return rtext


