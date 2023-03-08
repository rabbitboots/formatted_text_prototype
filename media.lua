--[[
	Provides Document, Paragraph and Line structures.
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

local media = {}


local _mt_doc = {}
_mt_doc.__index = _mt_doc


local _mt_para = {}
_mt_para.__index = _mt_para


local _mt_line = {}
_mt_line.__index = _mt_line


-- Make as much of this file accessible as possible to facilitate development of custom structures.
media._mt_doc = _mt_doc
media._mt_para = _mt_para
media._mt_line = _mt_line


function media.newDocument()

	local self = {}

	self.w = 0
	self.h = 0

	self.paragraphs = {}

	setmetatable(self, _mt_doc)

	return self
end


function media.newParagraph(x, y, w, h)

	local self = {}

	self.x = x
	self.y = y
	self.w = w
	self.h = h

	self.lines = {}

	setmetatable(self, _mt_para)

	return self
end


function media.newLine(x, y, w, h)

	local self = {}

	self.x = x
	self.y = y
	self.w = w
	self.h = h

	self.blocks = {}

	setmetatable(self, _mt_line)

	return self
end


function media.default_docAppendParagraph(self, x, y, w, h)

	local paragraph = media.newParagraph(x, y, w, h)

	self.paragraphs[#self.paragraphs + 1] = paragraph

	return paragraph
end


function media.default_docDraw(self, x, y, para1, para2)

	local paragraphs = self.paragraphs

	--[[
	x = x or 0
	y = y or 0

	para1 = para1 or 1
	para2 = para2 or #paragraphs

	para1 = math.max(1, math.min(para1, #paragraphs))
	para2 = math.max(1, math.min(para2, #paragraphs))

	for i = para1, para2 do
	--]]

	if self.cb_render then
		self:cb_render(x, y)
	end

	for i = 1, #paragraphs do
		local paragraph = paragraphs[i]
		paragraph:draw(x, y)
	end
end


function media.default_docDebugDraw(self, x, y, para1, para2)

	local paragraphs = self.paragraphs

	for i = 1, #paragraphs do
		local paragraph = paragraphs[i]
		paragraph:debugDraw(x, y)
	end
end


function media.default_paraAppendLine(self, x, y, w, h)

	local line = media.newLine(x, y, w, h)
	self.lines[#self.lines + 1] = line

	return line
end


function media.default_paraDraw(self, x, y)

	if self.cb_render then
		self:cb_render(self.x + x, self.y + y)
	end

	for i, line in ipairs(self.lines) do
		for b, block in ipairs(line.blocks) do
			block:draw(self.x + line.x + x, self.y + line.y + y)
		end
	end
end

local dbg_font = love.graphics.newFont(13)
function media.default_paraDebugDraw(self, x, y)

	love.graphics.push("all")

	love.graphics.setColor(0, 0, 1, 0.5)
	love.graphics.rectangle("fill", self.x + x, self.y + y, self.w, self.h)

	for i, line in ipairs(self.lines) do
		love.graphics.setColor(0, 0, 1, 0.5)
		love.graphics.rectangle("fill", self.x + line.x + x, self.y + line.y + y, line.w, line.h)

		for j, block in ipairs(line.blocks) do
			if block.debugRender then
				block:debugRender(self.x + line.x + x, self.y + line.y + y)
			end
		end
		--[[
		-- show wrapline #
		love.graphics.setColor(1,1,1,1)
		love.graphics.print(i, dbg_font, self.x + line.x + x + line.w + 32, self.y + line.y + y)
		--]]
	end

	love.graphics.pop()
end


_mt_doc.appendParagraph = media.default_docAppendParagraph
_mt_doc.draw = media.default_docDraw
_mt_doc.debugDraw = media.default_docDebugDraw

_mt_para.appendLine = media.default_paraAppendLine
_mt_para.draw = media.default_paraDraw
_mt_para.debugDraw = media.default_paraDebugDraw


--- Check for the first paragraph at a position within a document.
-- @param x X position, relative to document left
-- @param y Y position, relative to document top
-- @return The first paragraph overlapping this point, or nil if none are found.
function _mt_doc:getParagraphAtPoint(x, y)

	for i, para in ipairs(self.paragraphs) do
		--print(i, x, y, para, para.x, para.y, para.w, para.h)
		if x >= para.x and x < para.x + para.w and y >= para.y and y < para.y + para.h then
			return para
		end
	end

	return nil
end


--- Check for the first line at a position within a paragraph.
-- @param x X position, relative to paragraph left
-- @param y Y position, relative to paragraph top
-- @return The first wrapped line overlapping this point, or nil if none are found.
function _mt_para:getLineAtPoint(x, y)

	for i, line in ipairs(self.lines) do
		if x >= line.x and x < line.x + line.w and y >= line.y and y < line.y + line.h then
			return line
		end
	end

	return nil
end


--- Check for the first block at a position within a wrapped line. Checks horizontal dimension only.
-- @param x X position, relative to line left
-- @return The first block overlapping this point, or nil if none are found.
function _mt_line:getBlockAtPoint(x)

	for i, block in ipairs(self.blocks) do
		if x >= block.x and x < block.x + block.w + block.ws_w then
			return block
		end
	end

	return nil
end


-- XXX: Get character byte offset within text block at position. This might need to be handled at the line level.


return media
