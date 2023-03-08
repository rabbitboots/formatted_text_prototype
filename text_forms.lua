
--[[
TextForms: arrays of drawable media blocks.
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


--[[
	A text block is a table with the following fields:

	block.type = "text": IDs the table as a drawable text block.
	block.f_inf: ("Font Info") A table with a LÖVE Font object and associated drawing details and methods.
		See `font_info.lua` for more information.

	block.text:
		For monochrome text: A string: "Hello"
		For colorized text: A `coloredtext` sequence: { {1, 1, 1, 1}, "Hello", ... }

	block.x, block.y, block.w, block.h: The block's position (relative to the line) and dimensions, excluding
		trailing space on the end.
	block.ws_w: Width of any trailing space at the end of block.text.
	block.has_ws: Boolean indicating if this block has trailing whitespace. Needed for future support of
		zero-width space. (NOTE: need custom patterns to detect multi-byte UTF-8 spaces before this can
		work.)
	block:draw(x, y): A function that draws the block.

	The following are either false/nil or a color table:

	block.color_bg
	block.color_ul
	block.color_st


	Arbitrary non-text blocks may be created and inserted into lines.

	block.type = <not "text">
	block.f_inf: You need a stand-in font-info table so that higher logic knows how to place arbitrary
		blocks in relation to text blocks. See 'fontInfo.newInfoTableArbitrary()' for the necessary fields.
	block.x, block.y, block.w, block.h: The block's position (relative to the line) and dimensions. Doesn't
		necessarily have to be the dimensions of what you intend to draw.
	block.has_ws = <always nil or false>
	block.ws_w = <always 0>
	block:draw(x, y): A function that draws the block.
--]]



local textForms = {}


local _mt_text_block = {type = "text"}
_mt_text_block.__index = _mt_text_block


-- * Internal *


local function _love11TextGuard(text)

	-- [UPGRADE] Remove in LÖVE 12.
	if type(text) == "string" and string.find(text, "%S") then
		return true

	else
		for i = 1, #text do
			local chunk = text[i]
			if type(chunk) == "string" and string.find(text[i], "%S") then
				return true
			end
		end
	end

	return false
end


-- * / Internal *


function textForms.newTextBlock(text, f_inf, x, y, w, h, ws_w, has_ws, color, color_ul, color_st, color_bg)

	local block = {}

	if color then
		block.text = {color, text}

	else
		block.text = text
	end

	block.f_inf = f_inf

	block.x = x
	block.y = y
	block.w = w
	block.h = h

	block.ws_w = ws_w
	block.has_ws = has_ws

	block.color_ul = color_ul or false
	block.color_bg = color_bg or false
	block.color_st = color_st or false

	setmetatable(block, _mt_text_block)

	return block
end


function _mt_text_block:draw(x, y)

	local f_inf = self.f_inf
	local font = f_inf.font

	local old_font = love.graphics.getFont()
	love.graphics.setFont(font)

	local xx = self.x + f_inf.ox + x
	local yy = self.y + f_inf.oy + y

	-- Shape-drawing methods are expected to restore any altered graphics state.
	if self.color_bg then
		f_inf:renderBackground(xx, yy, self.w + self.ws_w, self.h, self.color_bg)
	end
	if self.color_ul then
		f_inf:renderUnderline(xx, yy, xx + self.w + self.ws_w - 1, yy, self.color_ul)
	end

	f_inf:renderText(self, xx, yy)

	if self.color_st then
		f_inf:renderStrikethrough(xx, yy, xx + self.w + self.ws_w - 1, yy, self.color_st)
	end

	love.graphics.setFont(old_font)
end


--- Draw a block of text to a LÖVE TextBatch. The block font (self.f_inf.font) should match the TextBatch font.
--	Shapes need to be drawn separately.
-- @param text_batch The TextBatch to add to.
-- @param x X drawing position within the TextBatch.
-- @param y Y drawing position within the TextBatch.
-- @return Nothing.
function _mt_text_block:drawToTextBatch(text_batch, x, y)

	local f_inf = self.f_inf
	local font = f_inf.font

	-- Uncomment to crash the application if there is a font mismatch.
	--[[
	if font ~= text_batch:getFont() then
		error("Font mismatch between TextBatch and text block.")
	end
	--]]

	if _love11TextGuard(self.text) then
		text_batch:add(self.text, x + self.x + f_inf.ox, y + self.y + f_inf.oy)
	end
end


local function debugStepColor(tick)
	love.graphics.setColor(
		(math.abs(math.sin(tick*3))),
		0,--0.5 + (tick/4 % 0.5),
		0,--0.5 + (-tick/3 % 0.5),
		1.0--0.5 + (tick/2 % 0.5)
	)
	return tick + tick/9
end


function _mt_text_block:debugRender(x, y)

	local f_inf = self.f_inf
	local font = f_inf.font

	local xx = self.x + f_inf.ox + x
	local yy = self.y + f_inf.oy + y

	love.graphics.push("all")

	-- Word portion of block
	love.graphics.setColor(1, 0, 0, 0.5)
	love.graphics.rectangle("fill", x + self.x, y + self.y, self.w, self.h)

	-- Trailing whitespace portion of block
	if self.has_ws and self.ws_w > 0 then
		love.graphics.setColor(0, 1, 0, 0.5)
		love.graphics.rectangle("fill", x + self.x + self.w, y + self.y, self.ws_w, self.h)
	end

	love.graphics.setLineWidth(1)
	love.graphics.setLineStyle("rough")

	-- [[
	-- Illustrate the font's ascent, baseline and descent.
	local y_baseline = font:getBaseline()
	local y_ascent = y_baseline - font:getAscent()
	local y_descent = y_baseline - font:getDescent()

	love.graphics.setColor(1,1,1,1)
	love.graphics.line(
		xx + 0.5,
		yy + y_ascent + 0.5,
		xx + self.w - 1 + 0.5,
		yy + y_ascent + 0.5
	)

	love.graphics.setColor(0,1,1,1)
	love.graphics.line(
		xx + 0.5,
		yy + y_baseline + 0.5,
		xx + self.w - 1 + 0.5,
		yy + y_baseline + 0.5
	)

	love.graphics.setColor(1,0,1,1)
	love.graphics.line(
		xx + 0.5,
		yy + y_descent + 0.5,
		xx + self.w - 1 + 0.5,
		yy + y_descent + 0.5
	)

	love.graphics.setColor(1,1,1,1)
	--]]

	-- Draw indicators for backgrounds, underlines and strikethroughs.
	-- FontInfo shape offsetting and expansions / contractions is not accounted for.
	local tick = love.timer.getTime() * 4
	if self.color_bg then
		tick = debugStepColor(tick)
		love.graphics.rectangle(
			"line",
			xx,
			yy,
			self.w + (self.has_ws and self.ws_w or 0) - 1,
			self.h - 1
		)
	end

	if self.color_ul then
		tick = debugStepColor(tick)
		love.graphics.line(
			xx + 0.5,
			yy + f_inf.baseline + 0.5,
			xx + self.w - 1 + 0.5,
			yy + f_inf.baseline + 0.5
		)
	end

	if self.color_st then
		tick = debugStepColor(tick)
		love.graphics.line(
			xx + 0.5,
			yy + math.floor(f_inf.height / 2) + 0.5,
			xx + 0.5,
			yy + math.floor(f_inf.height / 2) + 0.5
		)
	end

	love.graphics.pop()
end


return textForms
