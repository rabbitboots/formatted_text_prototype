-- Color mixing helpers.

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


local auxColor = {}


local love_math = love.math


local function mixCorrected(r, g, b, a, col)

	local r1, g1, b1 = love_math.gammaToLinear(r, g, b)
	local r2, g2, b2 = love_math.gammaToLinear(col[1], col[2], col[3])

	local mix_r, mix_g, mix_b = love_math.linearToGamma(r1*r2, g1*g2, b1*b2)

	love.graphics.setColor(mix_r, mix_g, mix_b, a * col[4])
end


local function mixUncorrected(r, g, b, a, col)
	love.graphics.setColor(r * col[1], g * col[2], b * col[3], a * col[4])
end


--[[
local function mixColorCorrectedT(t1, t2)

	local r1, g1, b1 = love_math.gammaToLinear(t1[1], t1[2], t1[3])
	local r2, g2, b2 = love_math.gammaToLinear(t2[1], t2[2], t2[3])

	local mix_r, mix_g, mix_b = love_math.linearToGamma(r1*r2, g1*g2, b1*b2)

	love.graphics.setColor(mix_r, mix_g, mix_b, t1[4] * t2[4])
end


local function mixColorCorrectedRGBA(ra, ga, ba, aa, rb, gb, bb, ab)

	local r1, g1, b1 = love_math.gammaToLinear(ra, ga, ba)
	local r2, g2, b2 = love_math.gammaToLinear(rb, gb, bb)

	local mix_r, mix_g, mix_b = love_math.linearToGamma(r1*r2, g1*g2, b1*b2)

	love.graphics.setColor(mix_r, mix_g, mix_b, aa * ab)
end


local function mixColorUncorrectedT(t1, t2)
	love.graphics.setColor(t1[1] * t2[1], t1[2] * t2[2], t1[3] * t2[3], t1[4] * t2[4])
end


local function mixColorUncorrectedRGBA(ra, ga, ba, aa, rb, gb, bb, ab)
	love.graphics.setColor(ra * rb, ga * gb, ba * bb, aa * ab
end
--]]


if love.graphics.isGammaCorrect() then
	auxColor.mix = mixCorrected
	--auxColor.mixT = mixColorCorrectedT
	---auxColor.mixRGBA = mixColorCorrectedRGBA

else
	auxColor.mix = mixUncorrected
	--auxColor.mixT = mixColorUncorrectedT
	--auxColor.mixRGBA = mixColorUncorrectedRGBA
end


return auxColor
