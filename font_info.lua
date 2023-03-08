
-- Font Info Tables.

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

local fontInfo = {}

local REQ_PATH = ... and (...):match("(.-)[^%.]+$") or ""


local auxColor = require(REQ_PATH .. "aux_color")


function fontInfo.default_renderText(self, block, x, y)
	love.graphics.print(block.text, x, y, 0, self.sx, self.sy)
end


function fontInfo.default_renderBackground(self, x, y, w, h, color)

	local rr, gg, bb, aa = love.graphics.getColor()
	auxColor.mix(rr, gg, bb, aa, color)

	love.graphics.rectangle(
		"fill",
		x + self.bg_ox,
		y + self.bg_oy,
		w + self.bg_ext_w,
		h + self.bg_ext_h
	)

	love.graphics.setColor(rr, gg, bb, aa)
end


function fontInfo.default_renderUnderline(self, x1, y1, x2, y2, color)

	love.graphics.push("all")

	local rr, gg, bb, aa = love.graphics.getColor()
	auxColor.mix(rr, gg, bb, aa, color)
	love.graphics.setLineWidth(self.ul_width)
	love.graphics.setLineStyle(self.ul_style)

	love.graphics.line(
		x1 + self.ul_ox + 0.5,
		y1 + self.ul_oy + 0.5,
		x2 + self.ul_ox + 0.5,
		y2 + self.ul_oy + 0.5
	)

	love.graphics.pop()
end


function fontInfo.default_renderStrikethrough(self, x1, y1, x2, y2, color)

	love.graphics.push("all")

	local rr, gg, bb, aa = love.graphics.getColor()
	auxColor.mix(rr, gg, bb, aa, color)
	love.graphics.setLineWidth(self.st_width)
	love.graphics.setLineStyle(self.st_style)

	love.graphics.line(
		x1 + self.st_ox + 0.5,
		y1 + self.st_oy + 0.5,
		x2 + self.st_ox + 0.5,
		y2 + self.st_oy + 0.5
	)

	love.graphics.pop()
end


--- A standalone printing function, intended for testing. Expects single lines (no \n characters).
-- @param text The text to draw. Either a string or a LÖVE coloredtext sequence. Multi-line strings will not work correctly.
-- @param f_inf The font-info table to use when drawing.
-- @param x Top-left X position.
-- @param y Top-left Y position.
-- @param color_bg Optional background color, in the form of a table {1, 1, 1, 1} (red, green, blue, alpha), or
--	false/nil to not draw the background.
-- @param color_ul Optional underline color, or false/nil to not draw.
-- @param color_st Optional strikethrough color, or false/nil to not draw.
-- @return Nothing.
function fontInfo.printSingle(text, f_inf, x, y, color_bg, color_ul, color_st)

	local font = f_inf.font

	-- Get text dimensions.
	local text_w
	local text_h = font:getHeight()

	if type(text) == "table" then
		local utf8 = require("utf8")
		local chunk_prev = false

		for i, chunk in ipairs(text) do
			if type(chunk) == "string" then
				text_w = text_w + font:getWidth(chunk)

				if chunk_prev then
					text_w = text_w + font:getKerning(
						string.sub(chunk_prev, utf8.offset(chunk_prev, -1)),
						string.sub(chunk, 1, utf8.offset(chunk, 2, 1) - 1)
					)
				end
				chunk_prev = chunk
			end
		end

	else
		text_w = font:getWidth(text)
	end

	-- Scale text dimensions
	text_w = text_w * f_inf.sx
	text_h = text_h * f_inf.sy

	love.graphics.push()
	local old_font = love.graphics.getFont()

	if color_bg then
		f_inf:renderBackground(x, y, text_w, text_h, color_bg)
	end

	if color_ul then
		f_inf:renderUnderline(x, y, text_w, y, color_ul)
	end

	love.graphics.setFont(f_inf.font)	
	love.graphics.print(text, x, y, 0, f_inf.sx, f_inf.sy)

	if color_st then
		f_inf:renderStrikethrough(x, y, text_w, y, color_st)
	end

	love.graphics.setFont(old_font)
	love.graphics.pop()
end


function fontInfo.newInfoTable(font)

	local self = {}

	--[[
	These contain the LÖVE Font object, plus drawing offsets and rendering functions for shapes.
	This is essentially here as documentation of how the defaults work, and you do not necessarily
	have to use this function to create FontInfo tables so long as the fields marked 'required'
	are present (either through direct assignment or via the __index metamethod).
	--]]

	-- Assertions
	-- [[
	if type(font) ~= "userdata" then
		error("argument #1: bad type (expected userdata (LÖVE Font), got " .. type(font) .. ")")
	end
	--]]

	-- -> Required:
	-- The LÖVE Font object.
	self.font = font

	-- X and Y offsets when drawing
	self.ox = 0
	self.oy = 0

	-- X and Y scale when drawing and constructing blocks.
	-- Non-integral values will lead to text blocks being placed off the pixel grid, and appearing blurry
	-- as a result.
	self.sx = 1.0
	self.sy = 1.0

	--[[
	The following vertical font metrics are cached as well. This allows tweaking the metrics of
	LÖVE ImageFonts, which only have their height set by the Font subsystem, so that they may
	be vertically aligned with TrueType and BMFont blocks.
	--]]
	self.height = font:getHeight()
	self.baseline = font:getBaseline()
	self.ascent = font:getAscent()
	self.descent = font:getDescent()

	-- Methods used to render text and shapes.
	self.renderText = fontInfo.default_renderText
	self.renderBackground = fontInfo.default_renderBackground
	self.renderUnderline = fontInfo.default_renderUnderline
	self.renderStrikethrough = fontInfo.default_renderStrikethrough


	-- -> Dependent on shape implementation; required for the default methods.
	-- X and Y offsets when drawing underlines. Added to 'ox' and 'oy'.
	self.ul_ox = 0
	self.ul_oy = self.baseline

	-- The underline width and style.
	self.ul_width = 1
	self.ul_style = "smooth"

	-- X and Y offsets when drawing strikethrough lines. Added to 'ox' and 'oy'.
	self.st_ox = 0
	self.st_oy = math.floor(self.height / 2)

	-- The strikethrough width and style.
	self.st_width = 1.0
	self.st_style = "smooth"

	-- X and Y offsets when drawing background rectangles. Added to 'ox' and 'oy'.
	self.bg_ox = 0
	self.bg_oy = 0

	-- Extend or shorten the dimensions of background rectangles when drawing.
	self.bg_ext_w = 0
	self.bg_ext_h = 0

	--[[
	Font object-level state is not handled here:
	* Fallback fonts.
	* Font filters. If you are scaling up pixel art text, you likely want to set the filtering to nearest
	  neighbor.
	--]]

	return self
end


--- Use this when creating arbitrary blocks. Such a block (and this f_inf) should never run in code paths
--	intended for text blocks (as in, calls to font:getWidth(), etc.).
function fontInfo.newInfoTableArbitrary()

	local self = {}

	self.sx = 1.0
	self.sy = 1.0

	self.height = 0
	self.baseline = 0
	self.ascent = 0
	self.descent = 0

	return self
end



return fontInfo
