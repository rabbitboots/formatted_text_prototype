--[[
	The example in README.md.
--]]

local quickPrint = require("quick_print")
local qp = quickPrint.new()

local tabs = {0, 128, 160, 256}

function love.update(dt)
	tabs[2] = love.mouse.getX()
end

function love.draw()
	qp:reset()
	qp:setTabs(tabs)
	
	qp:print("Hello ", "World! ", "Lorem ", "Ipsum")
	
	qp:setTabs()
end
