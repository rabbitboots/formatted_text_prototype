--[[
RText auxiliary library. Provides functions that generate:

* Paragraph style: Bulleted list item
* Paragraph style: Numbered list item
* Paragraph style: Paragraph with image
* Paragraph style: Horizontal separator line, similar to the old <hr> tag in HTML
* Arbitrary block: in-line image
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


local auxiliary = {}


local REQ_PATH = ... and (...):match("(.-)[^%.]+$") or ""


local auxColor = require(REQ_PATH .. "aux_color")
local fontInfo = require(REQ_PATH .. "font_info")
local media = require(REQ_PATH .. "media")
local rtext = require(REQ_PATH .. "rtext")


-- * Helper functions *


function auxiliary.tagDef_genericParagraph(self, id)

	local para_style = self.para_styles[id]
	if para_style then
		return self:setParagraphStyle(para_style)
	end

	return false
end


-- * / Helper functions *


-- * Bullet List Items *


--- Make a paragraph style for a bulleted list item.
-- @param word_style The default word style for this paragraph style.
-- @param bullet_font The font to use for the bullet point.
-- @param bullet_text A string or coloredtext sequence with the desired bullet character. Ex: • (U+2022)
-- @param indent_width Width in pixels of the indent.
-- @param bullet_ox Left X position of the bullet, relative to document left. (Bullet Y position is always
--	relative to the baseline of the first text block.)
-- @return The paragraph style.
function auxiliary.makeBulletedListStyle(word_style, bullet_font, bullet_text, indent_width, bullet_ox)

	local self = rtext.newParagraphStyle(word_style)

	self.indent_x = indent_width
	self.ext_w = -indent_width
	self.cb_initParagraph = auxiliary.bullet_initParagraph
	self.cb_finishedParagraph = auxiliary.bullet_finishedParagraph

	self.cb_render = auxiliary.bullet_cb_render

	self.bullet_font = bullet_font
	self.bullet_text = bullet_text

	self.bullet_ox = bullet_ox
	-- bullet_oy is set in the paragraph as part of the finalization callback

	return self
end


function auxiliary.bullet_initParagraph(self, para, para_style)

	para.cb_render = para_style.cb_render

	para.bullet_font = para_style.bullet_font
	para.bullet_text = para_style.bullet_text

	para.bullet_ox = para_style.bullet_ox
	-- bullet_oy is set in the paragraph as part of the finalization callback
end


function auxiliary.bullet_finishedParagraph(self, para, para_style)

	para.bullet_y = 0

	-- Set the bullet's Y position.
	local line = para.lines[1]
	if line then
		local blocks = line.blocks
		local first_block = blocks[1]

		if first_block then
			local f_inf = first_block.f_inf
			para.bullet_oy = first_block.y + f_inf.baseline - para.bullet_font:getBaseline()
		end
	end
end


function auxiliary.bullet_cb_render(self, x, y)

	local old_font = love.graphics.getFont()
	love.graphics.setFont(self.bullet_font)
	love.graphics.print(self.bullet_text, x + self.bullet_ox, y + self.bullet_oy)

	love.graphics.setFont(old_font)
end


function auxiliary.tagDef_bullet1(self)
	return auxiliary.tagDef_genericParagraph(self, "aux_bullet1")
end


function auxiliary.tagDef_bullet2(self)
	return auxiliary.tagDef_genericParagraph(self, "aux_bullet2")
end


function auxiliary.tagDef_bullet3(self)
	return auxiliary.tagDef_genericParagraph(self, "aux_bullet3")
end


-- * / Bullet List Items *


-- * Numbered List Items *


function auxiliary.makeNumberedListStyle(word_style, numList_font, default_numList_text, indent_width, numList_ox)

	local self = rtext.newParagraphStyle(word_style)

	self.indent_x = indent_width
	self.ext_w = -indent_width
	self.cb_initParagraph = auxiliary.numList_initParagraph
	self.cb_finishedParagraph = auxiliary.numList_finishedParagraph

	self.cb_render = auxiliary.numList_cb_render

	self.numList_font = numList_font
	self.default_numList_text = default_numList_text

	self.numList_ox = numList_ox
	-- numList_oy is set in the paragraph as part of the finalization callback

	return self
end


function auxiliary.numList_initParagraph(self, para, para_style)

	para.cb_render = para_style.cb_render

	para.numList_font = para_style.numList_font
	para.numList_text = para.numList_text or para_style.default_numList_text

	para.numList_ox = para_style.numList_ox
	-- numList_oy is set in the paragraph as part of the finalization callback
end


function auxiliary.numList_finishedParagraph(self, para, para_style)

	para.numList_y = 0

	-- Set the numList label's Y position.
	local line = para.lines[1]
	if line then
		local blocks = line.blocks
		local first_block = blocks[1]

		if first_block then
			local f_inf = first_block.f_inf
			para.numList_oy = first_block.y + f_inf.baseline - para.numList_font:getBaseline()
		end
	end
end


function auxiliary.numList_cb_render(self, x, y)

	local old_font = love.graphics.getFont()
	love.graphics.setFont(self.numList_font)
	love.graphics.print(self.numList_text, x + self.numList_ox, y + self.numList_oy)

	love.graphics.setFont(old_font)
end


function auxiliary.tagDef_numListParagraph(self, str, paragraph, id)

	local pst_numList = self.para_styles[id]
	if pst_numList then
		if self:setParagraphStyle(pst_numList) then

			local numList_text = string.match(str, "%S+")
			if numList_text then
				paragraph.numList_text = numList_text
			end

			return true
		end
	end

	return false
end


function auxiliary.tagDef_numList1(self, str, paragraph)
	return auxiliary.tagDef_numListParagraph(self, str, paragraph, "aux_num_list1")
end


function auxiliary.tagDef_numList2(self, str, paragraph)
	return auxiliary.tagDef_numListParagraph(self, str, paragraph, "aux_num_list2")
end


function auxiliary.tagDef_numList3(self, str, paragraph)
	return auxiliary.tagDef_numListParagraph(self, str, paragraph, "aux_num_list3")
end


-- * / Numbered List Items *


-- * Horizontal Separator *


--- Make a basic horizontal separator paragraph style.
-- @param word_style The default word style for this paragraph style. (Helps with vertical height and color.)
-- @param pad_left Left padding in pixels.
-- @param pad_right Right padding in pixels.
-- @return The paragraph style.
function auxiliary.makeHorizontalSeparatorStyle(word_style, line_width, line_style, pad_left, pad_right)

	local self = rtext.newParagraphStyle(word_style)

	self.pad_left = pad_left
	self.pad_right = pad_right

	self.line_width = line_width
	self.line_style = line_style

	self.color = word_style.color or false

	self.cb_finishedParagraph = auxiliary.horiSep_finishedParagraph
	self.cb_render = auxiliary.horiSep_cb_render

	return self
end


function auxiliary.horiSep_finishedParagraph(self, para, para_style)

	para.cb_render = auxiliary.horiSep_cb_render

	para.hr_y = math.floor(para.h/2 + 0.5)

	para.hr_x1 = para_style.pad_left
	para.hr_x2 = math.max(para.hr_x1, self.doc_w - para_style.pad_right)

	para.hr_line_width = para_style.line_width
	para.hr_line_style = para_style.line_style
	para.hr_color = para_style.color
end


function auxiliary.horiSep_cb_render(self, x, y)

	love.graphics.push("all")

	local rr, gg, bb, aa = love.graphics.getColor()
	if self.hr_color then
		auxColor.mix(rr, gg, bb, aa, self.hr_color)
	end

	love.graphics.setLineWidth(self.hr_line_width)
	love.graphics.setLineStyle(self.hr_line_style)

	love.graphics.line(
		x + self.hr_x1 + 0.5,
		y + self.hr_y + 0.5,
		x + self.hr_x2 + 0.5,
		y + self.hr_y + 0.5
	)

	love.graphics.pop()
end


function auxiliary.tagDef_horiSep(self)
	return auxiliary.tagDef_genericParagraph(self, "aux_hori_sep")
end



-- * / Horizontal Separator *


-- * Paragraph style: Image with text


--[[
Implements three kinds of image paragraph:

Image left, text right with indent
+----+-------------+
| \/ |Foo foo foo  |
| /\ |foo foo.     |
+----+-------------+

Image right, text left with shortened wrap-limit
+-------------+----+
|Foo foo foo  | \/ |
|foo foo.     | /\ |
+-------------+----+

Image center, no text
+------+----+------+
|      | \/ |      |
|      | /\ |      |
+------+----+------+
--]]


--- Make an image paragraph style.
-- @param word_style The default word style for this paragraph style.
-- @return The paragraph style.
function auxiliary.makeImageStyle(word_style)

	local self = rtext.newParagraphStyle(word_style)

	self.cb_initParagraph = auxiliary.imagePara_initParagraph
	self.cb_finishedParagraph = auxiliary.imagePara_finishedParagraph
	self.cb_render = auxiliary.imagePara_cb_render

	return self
end


--- A tag definition for the image paragraph style.
-- Suggested tag ID: 'p_img'
-- Required fields: self.data.image_para
-- [p_img <image_def_id> (side) (h_pos) (v_pos)]
-- (side) defaults to "left"
-- (h_pos) defaults to 0.0 (left for left side, right for right side)
-- (v_pos) defaults to 0.0 (top)
--function auxiliary.tagDef_numListParagraph(self, str, paragraph, id)
function auxiliary.imagePara_tagDef(self, str, paragraph)

	local para_style = self.para_styles["aux_image"]
	if para_style then
		local image_id, side, h_pos, v_pos = string.match(str, "(%S+)%s*(%S*)%s*(%S*)%s*(%S*)")
		local image_def = self.data.image_para[image_id]

		if image_def then
			-- Defaults
			if side == "" then
				side = "left"
			end
			if h_pos == "" then
				h_pos = 0.0
			end
			if v_pos == "" then
				v_pos = 0.0
			end

			-- Validate params
			if side ~= "left" and side ~= "right" then
				return false
			end

			h_pos = tonumber(h_pos)
			if h_pos then
				h_pos = math.max(0.0, math.min(h_pos, 1.0))

			else
				return false
			end

			v_pos = tonumber(v_pos)
			if v_pos then
				v_pos = math.max(0.0, math.min(v_pos, 1.0))

			else
				return false
			end

			-- Seems good.
			paragraph.pi_def = image_def
			paragraph.pi_side = side
			paragraph.pi_h_pos = h_pos
			paragraph.pi_v_pos = v_pos

			return self:setParagraphStyle(para_style)
		end
	end

	return false
end


--- Paragraph initializer callback for the image paragraph style.
function auxiliary.imagePara_initParagraph(self, para, para_style)

 	local side = para.pi_side
 	local h_pos = para.pi_h_pos

	local def = para.pi_def
	if def then
		local width_truncated = self.doc_w - def.w

		--print("imagePara_initParagraph", "width_truncated", width_truncated, "self.doc_w", self.doc_w, "def.w", def.w, "h_pos", h_pos)
		para.pi_x = math.floor(width_truncated * h_pos + 0.5)

		-- para.pi_y is calculated in finishedParagraph once the paragraph height is known.

		if side == "left" then
			self.indent_x = def.w
			self.ext_w = -def.w

		elseif side == "right" then
			self.indent_x = 0
			self.ext_w = -def.w

			-- Move to right side
			para.pi_x = width_truncated - para.pi_x
		end

		-- For an update to the wrap-limit for the first line. Subsequent lines should be okay with the
		-- above indent_x and ext_w settings applied. This callback fires *after* the wrap limit is set...
		self.lplace.wrap_limit = self.doc_w + self.ext_w
	end
end


--- Paragraph finisher callback for the image paragraph style.
function auxiliary.imagePara_finishedParagraph(self, para, para_style)

	local def = para.pi_def
	local v_pos = para.pi_v_pos

	if def then
		para.h = math.max(para.h, def.h)
		local height_truncated = para.h - def.h

		para.pi_y = math.floor(height_truncated * v_pos * 0.5)

		para.cb_render = para_style.cb_render
	end
end


--- Render callback for the image paragraph style.
function auxiliary.imagePara_cb_render(self, x, y)

	love.graphics.push("all")

	-- This function assumes that pi_def is assigned.

	local def = self.pi_def

	if def.color then
		local rr, gg, bb, aa = love.graphics.getColor()
		auxColor.mix(rr, gg, bb, aa, def.color)
	end

	if def.quad then
		love.graphics.draw(
			def.texture,
			def.quad,
			x + self.pi_x + def.d_x,
			y + self.pi_y + def.d_y,
			def.d_r,
			def.d_sx,
			def.d_sy,
			def.d_ox,
			def.d_oy,
			def.d_kx,
			def.d_ky
		)

	else
		--print("x", x, "self.pi_x", self.pi_x, "def.d_x", def.d_x, "def.w", def.w)
		--print("y", y, "self.pi_y", self.pi_y, "def.d_y", def.d_y, "def.h", def.h)
		love.graphics.draw(
			def.texture,
			x + self.pi_x + def.d_x,
			y + self.pi_y + def.d_y,
			def.d_r,
			def.d_sx,
			def.d_sy,
			def.d_ox,
			def.d_oy,
			def.d_kx,
			def.d_ky
		)
	end

	love.graphics.pop()
end


--- Create a new imageDef for the image paragraph style.
function auxiliary.imagePara_newDef(texture, quad, color)

	local self = {}

	self.texture = texture
	self.quad = quad or false
	self.color = color or false

	-- self.w, self.h: Bounding box size for the image. Used for positioning against the text part of the 
	-- paragraph. These default values will need to be changed if you are applying any tranform settings,
	-- or if you want to add padding around the texture when rendering.
	if quad then
		local qx, qy, qw, qh = quad:getViewport()
		self.w, self.h = qw, qh

	else
		self.w, self.h = texture:getDimensions()
	end

	-- Parameters for love.graphics.draw():
	self.d_x = 0 -- relative to paragraph + bounding box
	self.d_y = 0
	self.d_r = 0
	self.d_sx = 1.0
	self.d_sy = 1.0
	self.d_ox = 0
	self.d_oy = 0
	self.d_kx = 0
	self.d_ky = 0

	return self
end


-- * / Paragraph style: Image with text


-- * In-line image *


--[[
This is a basic implementation of embedding images into the text flow. It can't
handle all use cases, so you may need to rewrite portions, or the whole thing,
to get exactly what you want.

Arbitrary blocks may be used for other kinds of visual content as well, or as
stand-ins for entities that belong to your project's UI layer.

Some alternatives which might work better, depending on the circumstances:

* Use a paragraph style that displays an image, either alone or to the side
  of text.

* Implement the images as LÖVE ImageFonts.
--]]


--- The default draw function for defs without a quad.
function auxiliary.imageEmbed_draw(self, x, y)

	local f_inf = self.f_inf

	love.graphics.push("all")

	love.graphics.setBlendMode(self.blend, self.blend_alpha)

	love.graphics.draw(
		self.texture,
		self.x + self.d_x + x,
		self.y + self.d_y + y,
		self.d_r,
		self.d_sx,
		self.d_sy,
		self.d_ox,
		self.d_oy,
		self.d_kx,
		self.d_ky
	)

	love.graphics.pop()
end


--- The default draw function for defs with a viewport quad.
-- @param self The def table.
-- @param x X draw position (top-left).
function auxiliary.imageEmbed_drawQuad(self, x, y)

	local f_inf = self.f_inf

	love.graphics.push("all")

	love.graphics.setBlendMode(self.blend, self.blend_alpha)

	love.graphics.draw(
		self.texture,
		self.quad,
		self.x + self.d_x + x,
		self.y + self.d_y + y,
		self.d_r,
		self.d_sx,
		self.d_sy,
		self.d_ox,
		self.d_oy,
		self.d_kx,
		self.d_ky
	)

	love.graphics.pop()
end


function auxiliary.imageEmbed_newDef(texture, quad, f_inf)

	local self = {}

	self.texture = texture
	self.quad = quad or false

	if not f_inf then

		f_inf = fontInfo.newInfoTableArbitrary()

		-- NOTE: f_inf.sx and f_inf.sy here are for placement only.
		-- When drawing, the texture uses block.d_sx and block.d_sy.
		f_inf.sx = 1.0
		f_inf.sy = 1.0
		f_inf.height = texture:getHeight()
		f_inf.baseline = f_inf.height
		f_inf.ascent = f_inf.height
		f_inf.descent = 0
	end

	self.f_inf = f_inf

	return self
end


function auxiliary.imageEmbed_newArbitraryBlock(def, w, h)

	local texture = def.texture
	local f_inf = def.f_inf
	local quad = def.quad

	local block = {}

	block.type = "arbitrary"
	block.f_inf = f_inf
	block.texture = texture
	block.quad = quad

	block.x = 0
	block.y = 0
	block.w = w * f_inf.sx
	block.h = h * f_inf.sy

	-- Values for love.graphics.setBlendMode():
	block.blend = "alpha"
	block.blend_alpha = "alphamultiply"

	-- Values for love.graphics.draw():
	block.d_x = 0 -- (Texture top-left offset into the block)
	block.d_y = 0
	block.d_r = 0
	block.d_sx = 1.0
	block.d_sy = 1.0
	block.d_ox = 0
	block.d_oy = 0
	block.d_kx = 0 -- XXX: kx and ky might be removed in LÖVE 12.
	block.d_ky = 0

	if quad then
		block.draw = auxiliary.imageEmbed_drawQuad

	else
		block.draw = auxiliary.imageEmbed_draw
	end

	block.has_ws = false
	block.ws_w = 0

	return block
end


--- A TagDef implementation for in-line images. Suggested tag ID: "img"
-- [img <image_id>]
-- Required field: self.data.image_embed
-- On failure: treat as text
function auxiliary.imageEmbed_tagDef(self, str)

	local image_id = string.match(str, "%S+")
	local image_t = self.data.image_embed[image_id]
	if not image_t then
		return false
	end

	local bw, bh = 0, 0
	local texture = image_t.texture
	local quad = image_t.quad
	if quad then
		local _
		_, _, bw, bh = quad:getViewport()

	else
		bw, bh = texture:getDimensions()
	end

	local block = auxiliary.imageEmbed_newArbitraryBlock(image_t, bw, bh)
	
	block.d_x = math.floor(bw/2 + 0.5)
	block.d_y = math.floor(bh/2 + 0.5)
	block.d_ox = block.d_x
	block.d_oy = block.d_y

	return "arbitrary", block
end


-- * / In-line image *


return auxiliary
