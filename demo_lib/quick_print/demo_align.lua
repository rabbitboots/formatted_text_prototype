--[[
	QuickPrint Demo: tab alignment
--]]

require("demo_libs.test.strict")
local quickPrint = require("quick_print")

-- Set up LÖVE.
love.window.setTitle("QuickPrint Demo: Tab stop alignment")
love.window.updateMode(love.graphics.getWidth(), love.graphics.getHeight(), {resizable = true})
love.keyboard.setKeyRepeat(true)

local scroll_y = 1
local demo_show_tabs = false
local demo_elapsed = 0.0
local demo_zoom = 1.0

-- Fonts
local orig_font = love.graphics.newFont(16)
local main_font = love.graphics.newFont(16)
main_font:setLineHeight(1.5)

local qp = quickPrint.new()

--[[
The behavior of non-left align modes is a bit unintuitive, owing to the fact that this library began existence
as a debug-printing tool.

The 'plain' printing commands, under normal circumstances, will not move the X cursor backwards to the left. If
your first tab stop is at X position 0, then no text will ever center-align or right-align against it (unless
you moved the cursor backwards first.) However, if you slide the first tab stop a bit to the right, then there
should be some "breathing room" to allow the expected placement.

The 'formatted' print functions are a bit different. They were grafted on after the initial design, when I
realized that LÖVE's printf() word-wrap and coloredtext features were too useful to ignore, even if they didn't
quite work the same as the rest of the library. Only qp:writefSingle() respects tab stops, and it will position
text without caring about what has already been printed on the current line.

I hope this answers any questions you had about QuickPrint virtual tab stops, and that you have a fantastic day.
--]]

local tome = {
	{"The behavior ", "of non-left", " align modes",},
	{"is a bit unintuitive, ", "owing to the", " fact that this library"},
	{"began existence as a ", "debug-printing tool.", ""},
	{"", "", ""},
	{".", ".", "."},
	{"", "", ""},
	{"The 'plain' printing commands, ", "under normal circumstances,", " will not move the X cursor"},
	{"backwards to the left. ", "If your first tab", " stop is at X position 0, then"},
	{"no text will ever ", "center-align", " or right-align against it"},
	{"(unless you moved the ", "cursor backwards ", " first.)"},
	{"However, if you slide the ", "first tab stop", " a bit to the right, then"},
	{"there should be some ", "\"breathing room\"", " to allow the expected"},
	{"placement. ", "", ""},
	{"", "", ""},
	{".", ".", "."},
	{"", "", ""},
	{"The 'formatted' print functions ", "are", " a bit different."},
	{"They were grafted on ", "after", " the initial design, when I"},
	{"realized that LÖVE's ",  "printf()", " word-wrap and coloredtext"},
	{"features were too ", "useful", " to ignore, even if they"},
	{"didn't quite work ", "the same as", " the rest of the library."},
	{"Only qp:writefSingle() ", "respects", " tab stops, and it will"},
	{"position text without ", "caring", " about what has already"},
	{"been printed on the ", "current line.", ""},
	{"", "", ""},
	{".", ".", "."},
	{"", "", ""},
	{"I hope this answers ", "any questions", " you had about QuickPrint"},
	{"virtual tab stops, and that you ", "", ""},
	{"", "", "have a"},
	{"", "", "fantastic"},
	{"", "", "day."},
}


-- Set up some virtual tab stops with alignment settings.
-- Tab X positions will be updated based on the window width.
local demo_tabs = {
	{x=0, align="right"},
	{x=0, align="center"},
	{x=0, align="left"},
}


function love.keypressed(kc, sc)
	if sc == "escape" then
		love.event.quit()
	elseif sc == "tab" then
		demo_show_tabs = not demo_show_tabs
	elseif sc == "up" or sc == "kp8" then
		scroll_y = math.max(1, scroll_y - 1)
	elseif sc == "pageup" then
		scroll_y = math.max(1, scroll_y - 8)
	elseif sc == "down" or sc == "kp2" then
		scroll_y = math.min(#tome, scroll_y + 1)
	elseif sc == "pagedown" then
		scroll_y = math.min(#tome, scroll_y + 8)
	elseif sc == "-" or sc == "kp-" then
		demo_zoom = math.max(0.1, demo_zoom * 0.95)
	elseif sc == "=" or sc == "kp+" then
		demo_zoom = math.min(10, demo_zoom * 1.05)
	end
end


function love.wheelmoved(x, y)
	if love.keyboard.isScancodeDown("lctrl", "rctrl") then
		if y < 0 then
			demo_zoom = math.max(0.1, demo_zoom * 0.95)
		else
			demo_zoom = math.min(10, demo_zoom * 1.05)
		end
	else
		scroll_y = math.max(1, math.min(scroll_y - y, #tome))
	end
end


function love.update(dt)
	demo_elapsed = demo_elapsed + dt

	demo_tabs[1].x = (love.graphics.getWidth() / demo_zoom / 2) - 128
	demo_tabs[2].x = (love.graphics.getWidth() / demo_zoom / 2)
	demo_tabs[3].x = (love.graphics.getWidth() / demo_zoom / 2) + 128
end


function love.draw()
	love.graphics.setFont(main_font)
	love.graphics.scale(demo_zoom)

	if demo_show_tabs then
		love.graphics.setColor(1, 0, 0, 1)
		for _, tab in ipairs(demo_tabs) do
			local tx = type(tab) == "number" and tab or tab.x
			love.graphics.line(tx, 0, tx, love.graphics.getHeight() / demo_zoom)
		end
		love.graphics.setColor(1, 1, 1, 1)
	end
	
	qp:setOrigin(0, 72)
	qp:setTabs(demo_tabs)
	qp:reset()
	
	if #tome > 0 then
		local lines_bottom = scroll_y + 1 + math.floor(love.graphics.getHeight() / demo_zoom / (main_font:getHeight() * main_font:getLineHeight()))
		lines_bottom = math.min(lines_bottom, #tome)
		
		for i = scroll_y, lines_bottom do
			local ii = i + demo_elapsed
			love.graphics.setColor(math.abs(math.cos(ii / 4)), math.abs(math.cos(ii / 8)), math.abs(math.cos(ii / 12)), 1)
			qp:print3(tome[i][1], tome[i][2], tome[i][3])
		end
	end

	love.graphics.origin()

	love.graphics.setColor(0, 0, 0, 0.75)
	love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), 48)
	love.graphics.setColor(1, 1, 1, 1)
	
	love.graphics.setFont(orig_font)
	love.graphics.printf("(TAB: show lines\tARROWS: scroll\t(+-)Zoom\tESCAPE: quit)", 0, math.floor(48/2 - orig_font:getHeight()/2), love.graphics.getWidth(), "center")
end

