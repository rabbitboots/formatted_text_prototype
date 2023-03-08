local fontGroup = {}

--[[
	Provides a basic structure for grouping fonts into Regular, Bold, Italic and Bold-Italic
	categories. Regular is required, while the others are optional (and attempting to select
	a missing optional font will fall back to Regular).
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

function fontGroup.new(regular, bold, italic, bold_italic)

	-- This also works well enough:
	-- local f_grp = {regular, bold, italic, bold_italic}
	-- Replace any missing optional faces with boolean false or references to the regular face.

	if not regular then
		error("argument #1: missing required 'regular' font ID.")
	end

	local self = {}

	self[1] = regular
	self[2] = bold or false
	self[3] = italic or false
	self[4] = bold_italic or false

	return self
end


function fontGroup.getFace(self, bold, italic)

	local index = 1
	if bold then
		index = index + 1
	end
	if italic then
		index = index + 2
	end

	return self[index] or self[1]
end


return fontGroup
