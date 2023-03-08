--[[
	QuickPrint Demo #1
--]]

require("demo_libs.test.strict")
local quickPrint = require("quick_print")

-- Set up LÖVE.
love.window.setTitle("QuickPrint Demo #1")
love.window.updateMode(love.graphics.getWidth(), love.graphics.getHeight(), {resizable = true})
--love.keyboard.setKeyRepeat(true)


-- Fonts
local main_font = love.graphics.newFont(16)
main_font:setLineHeight(1.5)

local aux_font = love.graphics.newFont(14)
love.graphics.setFont(main_font)


-- Make a quickprint state table
local qp = quickPrint.new()


-- Set up some virtual tab stops.
local demo_tabs = {
	0,
	128,
	192,
	256,
	300,
}


function love.keypressed(kc, sc)
	-- QuickQuit
	if sc == "escape" then
		love.event.quit()
	end
end


local seq1 = {"a", "b", "c", "d", "e", "f", "g"}
local colored_text = {{1,1,1,1}, "Colored ", {0,1,1,1}, "text ", {1,0,1,1}, "table ", {1,1,0,1}, "of ", {1,0,0,1}, "tables."}

function love.draw()
	love.graphics.setFont(main_font)

	-- Set the printing region to the window dimensions,
	-- minus 16 pixels of padding on each side.
	local PAD = 16
	qp:setOrigin(PAD, PAD)
	qp:setReferenceDimensions(love.graphics.getWidth() - PAD*2, love.graphics.getHeight() - PAD*2)

	-- Print a line.
	qp:print("The quick brown fox jumps over the lazy dog")

	-- Print a varargs list of values without having to concatenate them.
	qp:print("Al", "to", "ge", "ther")

	-- Some versions of print() with a hardcoded number of arguments.
	qp:print1("One ", "(dropped)")
	qp:print2("One ", "Two ", "(dropped)")
	qp:print3("One ", "Two ", "Three ", "(dropped)")
	qp:print4("One ", "Two ", "Three ", "Four ", "(dropped)")

	-- Print a sequence of values (anything but nil)
	qp:printSeq(seq1)

	-- It's generally OK to change fonts between lines (after a qp:print*() call, after qp:down(), etc.)
	love.graphics.setFont(aux_font)

	-- Write multiple strings left-to-right without moving to the next line.
	for i = 1, 12 do
		qp:write("`", "-", ".", "~")
	end

	-- (qp:write<1234>() and qp:writeSeq() are also available.)

	-- Move down one line.
	qp:down()

	-- Assign tab stops
	qp:setTabs(demo_tabs)

	qp:print("|", "|", "|", "|", "|")
	qp:print("|virtual", "|tab", "|stop", "|test", "|.")
	qp:print("|", "|", "|", "|", "|")

	-- Remove tab stops
	qp:setTabs()

	-- Use qp:printf() to align text, auto-wordwrap, and to use LÖVE coloredtext sequences.

	-- Move down four lines.
	qp:down(4)

	-- Narrow the reference width for alignment and wrapping.
	local bar = "----------------------------------------------------------"
	qp:print(bar)

	local bar_width = aux_font:getWidth(bar)
	qp:setReferenceWidth(bar_width)

	-- Alignment
	--[[
	NOTE: qp:printf() generates some garbage as part of determining the next cursor Y position.
	If you know that the printed text will occupy a single line only, you can use qp:printfSingle()
	or qp:writefSingle() to skip that logic.
	--]]

	-- [[
	qp:printfSingle("Left Text", "left")
	qp:printfSingle("Middle Text", "center")
	qp:printfSingle("Right Text", "right")
	qp:printfSingle("Text with 'justify' alignment.", "justify")
	--]]
	--[[
	qp:printf("Left Text", "left")
	qp:printf("Middle Text", "center")
	qp:printf("Right Text", "right")
	qp:printf("Text with 'justify' alignment.", "justify")
	--]]

	qp:down()
	qp:print(bar)
	qp:down()

	-- coloredtext
	qp:printfSingle(colored_text, "left")
	--qp:printf(colored_text, "left")

	qp:down(4)

	--[[
	The act of printing memory usage in Lua typically causes the reported number to increase as
	a result of interning a new string. You can counter this slightly by stripping off the
	decimal values. Other stuff like table creation (or generating other new strings, unrelated
	to the memory counter) will still contribute to the count.
	--]]

	qp:print("Lua Memory (KB): ", math.floor(collectgarbage("count") * 10) / 10)
	--qp:print("Lua Memory (Bytes): ", collectgarbage("count") * 1024)
	
	qp:setOrigin(love.graphics.getWidth() - 256, PAD)
	qp:print("Getting to the other demos:")
	qp:print("love . demo2")
	qp:print("love . full_test")

end

