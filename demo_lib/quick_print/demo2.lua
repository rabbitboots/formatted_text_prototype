--[[
	QuickPrint Demo #2

	NOTE: Getting pixel art and BMFonts to look decent at non-integer scales or when scaled
	down < 50% is beyond the scope of this demo. All that matters here is placement and
	alignment.
--]]


-- [UPGRADE] LÖVE 12 Development (f17d3d9) renames `Text` to `TextBatch`.
local _lg_newTextBatch
do
	local love_major, love_minor, love_revision, love_codename = love.getVersion()

	if love_major == 12 then
		_lg_newTextBatch = love.graphics.newTextBatch
	else
		_lg_newTextBatch = love.graphics.newText
	end
end


require("demo_libs.test.strict")
local fontSet = require("demo_libs.font_set.font_set")
local quickPrint = require("quick_print")


-- Set up LÖVE.
love.window.setTitle("QuickPrint Demo #2")
love.window.updateMode(love.graphics.getWidth(), love.graphics.getHeight(), {resizable = true})
love.keyboard.setKeyRepeat(true)

-- Grab a copy of LÖVE's built-in font.
local _default_font = love.graphics.getFont()


-- Demo state
local demo_tick_time = 0

local demo_garbage_modes = {"default", "step_1", "step_4", "step_16", "step_256", "collect_x2"}
local demo_garbage_i = 1
local demo_tab_lines = false


-- Current font_set index, font size, and a direct link to the one active font_set in this demo.
local font_i = 1
local font_size = 16
local current_font_set

-- Make the QuickPrint state table.
local qp = quickPrint.new(love.graphics.getWidth() - 32, 4)

-- Virtual tab offset
local tab_ox = 0


-- Construct an artificial coloredtext sequence
local demo_colors = {}
for i = 1, 12 do
	demo_colors[i] = {1, 1, 1, 1}
end
local temp_ascii = "coloredtext (printf() only)"
local demo_coloredtext = {}
for i = 1, #temp_ascii do
	table.insert(demo_coloredtext, demo_colors[(i-1) % #demo_colors + 1])
	table.insert(demo_coloredtext, string.sub(temp_ascii, i, i))
end


-- Mess with the colors in love.update()
local function mutateColors(colors)
	for i, color_set in ipairs(colors) do
		for j, color in ipairs(color_set) do
			color_set[j] = math.max(0, math.min(color + (love.math.random(-8, 8) / 255), 1))
		end
	end
end


-- This LÖVE Text object is set up in love.load() and just rendered in love.draw()
local txt = _lg_newTextBatch(_default_font)
do
	local qp2 = quickPrint.new(256)
	qp2:setTextObject(txt)
	qp2:setTabs({0,48})
	qp2:print("Write", "to")
	qp2:print("a", "bound")
	qp2:print("LÖVE", "Text")
	qp2:print("object") -- don't dead open inside

	qp2:setTabs()

	qp2:setTextObject()
end


--[[
Using a separate library to map virtual font sizes to ImageFonts.
--]]

local fonts = {}
local font_names = {}

-- TrueType
-- The default LÖVE font.
font_names[1] = "<LÖVE Default>"
fonts[1] = fontSet.newTrueType(false)

font_names[2] = "DejaVu Sans Mono, Book"
fonts[2] = fontSet.newTrueType("demo_fonts/ttf/DejaVu_Mono/dejavu_mono.ttf")

font_names[3] = "Damion"
fonts[3] = fontSet.newTrueType("demo_fonts/ttf/Damion/Damion-Regular.ttf")

font_names[4] = "Montserrat, Regular"
fonts[4] = fontSet.newTrueType("demo_fonts/ttf/Montserrat/Montserrat-Regular.ttf")

font_names[5] = "Open Sans Condensed, Medium"
fonts[5] = fontSet.newTrueType("demo_fonts/ttf/Open_Sans_Condensed/OpenSans_Condensed-Medium.ttf")

font_names[6] = "Cabin Bold"
fonts[6] = fontSet.newTrueType("demo_fonts/ttf/Cabin-v1.5/Cabin-Bold-TTF.ttf")


-- ImageFont
local i_font_glyphs = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
local i_glyphs_437 =
 "☺☻♥♦♣♠•◘○◙♂♀♪♫☼►◄↕‼¶§▬↨↑↓→←∟↔▲▼" ..
" !\"#$%&'()*+,-./0123456789:;<=>?" ..
"@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_" ..
"`abcdefghijklmnopqrstuvwxyz{|}~⌂" ..
"ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜ¢£¥₧ƒ" ..
"áíóúñÑªº¿⌐¬½¼¡«»░▒▓│┤╡╢╖╕╣║╗╝╜╛┐" ..
"└┴┬├─┼╞╟╚╔╩╦╠═╬╧╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀" ..
"αßΓπΣσµτΦΘΩδ∞φε∩≡±≥≤⌠⌡÷≈°∙·√ⁿ²■"


font_names[7] = "term_thick_var (Base size: 9)"
fonts[7] = fontSet.newImageFont({{size = 9, src = "demo_fonts/imagefont/term_thick_var.png"}}, i_font_glyphs)
fonts[7]:setFilter("nearest", "nearest")

font_names[8] = "term_thin_var (Base size: 9)"
fonts[8] = fontSet.newImageFont({{size = 9, src = "demo_fonts/imagefont/term_thin_var.png"}}, i_font_glyphs)
fonts[8]:setFilter("nearest", "nearest")

font_names[9] = "microtonal_mono (Base size: 7)"
fonts[9] = fontSet.newImageFont({{size = 7, src = "demo_fonts/imagefont/microtonal_mono.png"}}, i_font_glyphs)
fonts[9]:setFilter("nearest", "nearest")

font_names[10] = "dosbox_cp437 (Base size: 14)"
fonts[10] = fontSet.newImageFont({{size = 14, src = "demo_fonts/imagefont/dosbox_cp437.png"}}, i_glyphs_437)
fonts[10]:setFilter("nearest", "nearest")


-- BMFont
font_names[11] = "ClickerScript (BMF Conv.) (Base size: 24)"
fonts[11] = fontSet.newBMFont({{size = 24, src = "demo_fonts/bmf/Clicker_Script/clicker_24.fnt"}})

font_names[12] = "Quantico (BMF Conv.) (Base size: 24)"
fonts[12] = fontSet.newBMFont({{size = 24, src = "demo_fonts/bmf/Quantico_Regular/quantico_24.fnt"}})


-- Demo logic
local function demoReloadFont()
	current_font_set = fonts[font_i]
	current_font_set:reload(font_size)
end
-- Load Font #1 ASAP.
demoReloadFont()


local function demoCycleFont(dir)
	font_i = font_i + dir
	if font_i < 1 then
		font_i = #fonts
	elseif font_i > #fonts then
		font_i = 1
	end

	demoReloadFont()
end


function love.keypressed(kc, sc)
	-- Quit the demo
	if sc == "escape" then
		love.event.quit()
		return

	-- Cycle through provisioned fonts
	elseif sc == "tab" then
		if love.keyboard.isScancodeDown("lshift", "rshift") then
			demoCycleFont(-1)
		else
			demoCycleFont(1)
		end

	-- Toggle VSync
	elseif sc == "0" then
		love.window.setVSync(1 - love.window.getVSync())

	-- Step through garbage collector modes
	elseif sc == "9" then
		demo_garbage_i = demo_garbage_i % #demo_garbage_modes + 1

	-- Adjust the demo font size
	elseif sc == "up" then
		font_size = math.min(72, font_size + 1)
		demoReloadFont()

	elseif sc == "down" then
		font_size = math.max(1, font_size - 1)
		demoReloadFont()

	-- Adjust vertical padding
	elseif sc == "3" then
		qp:setVerticalPadding(math.max(-64, qp.pad_v - 1))

	elseif sc == "4" then
		qp:setVerticalPadding(math.min(64, qp.pad_v + 1))

	-- Render virtual tab stops
	elseif sc == "5" then
		demo_tab_lines = not demo_tab_lines

	-- Mess with the tab offset.
	elseif sc == "left" then
		tab_ox = tab_ox - 4

	elseif sc == "right" then
		tab_ox = tab_ox + 4
	end
end


function love.update(dt)
	demo_tick_time = demo_tick_time + dt
	if demo_tick_time > 1/30 then
		demo_tick_time = 0
		mutateColors(demo_colors)
	end

	local garbage_mode = demo_garbage_modes[demo_garbage_i]
	if garbage_mode == "collect_x2" then
		collectgarbage("collect")
		collectgarbage("collect")

	elseif garbage_mode == "step_1" then
		collectgarbage("step", 1)

	elseif garbage_mode == "step_4" then
		collectgarbage("step", 4)

	elseif garbage_mode == "step_16" then
		collectgarbage("step", 16)

	elseif garbage_mode == "step_256" then
		collectgarbage("step", 256)
	end
end


local prefab_string_seq = {"Print table sequence: ",
	"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", 
	"n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
}

local demo_tabs = {}

function love.draw()
	love.graphics.push("all")

	love.graphics.setColor(1, 1, 1, 1)

	-- Draw the arbitrary LÖVE Text object.
	love.graphics.draw(txt, love.graphics.getWidth() - 96, 32)

	qp:setReferenceWidth(love.graphics.getWidth() - 32)

	local font_sub, font_scale = current_font_set:getFont()
	love.graphics.setFont(font_sub)

	-- Auto-scale ImageFonts to be somewhat in line with TrueType font sizes.
	qp:setScale(font_scale)

	local font_type = current_font_set.font_type

	--local COL_WIDTH = 110
	local COL_WIDTH = font_sub:getWidth("_") * 18
	if font_type == "imagefont" or font_type == "bmfont" then
		COL_WIDTH = math.ceil(COL_WIDTH * qp.sx)
	end

	qp:reset()
	qp:setTabs()
	qp:setOrigin(16, 16)

	demo_tabs[1] = 0
	demo_tabs[2] = COL_WIDTH + tab_ox
	demo_tabs[3] = COL_WIDTH*2 + tab_ox
	demo_tabs[4] = demo_tabs[3] + math.floor(COL_WIDTH / 2) + tab_ox
	demo_tabs[5] = demo_tabs[4] + math.floor(COL_WIDTH / 4) + tab_ox

	qp:setTabs(demo_tabs)

	if demo_tab_lines and qp:getTabs() then
		love.graphics.setColor(1, 0, 0, 1)
		for i, stop in ipairs(demo_tabs) do
			love.graphics.line(qp.origin_x + stop, 0, qp.origin_x + stop, love.graphics.getHeight())
		end
	end
	love.graphics.setColor(1, 1, 1, 1)

	qp:print("FPS: ", love.timer.getFPS())
	qp:print("FrameDelta: ", love.timer.getAverageDelta())
	qp:print("Mem (KB): ", math.floor(collectgarbage("count") * 10) / 10)

	qp:down()

	qp:print("(0) VSync: ", love.window.getVSync())
	qp:print("(9) GC Mode: ", demo_garbage_modes[demo_garbage_i])

	qp:down()

	qp:print("(Tab) Set Font: ", font_names[font_i])

	qp:print("(up-down) Font Sz: ", font_size)
	qp:print("(3-4) V.Padding: ", qp:getVerticalPadding())

	qp:down()

	local temp

	qp:print("This text spills into the next column: ", "boo!")
	qp:print("This does not: ", "jeepers!")

	qp:down()

	qp:print("(5) Show tabstops: ", demo_tab_lines)
	qp:print("(left-right) Offset tabs")
	qp:write("Tabstop test:", "1", "2", "3")
	qp:write("4")
	qp:down()

	qp:printSeq(prefab_string_seq)

	qp:setTabs()

	qp:printfSingle("(lll)", "left")
	qp:printfSingle("(ccc)", "center")
	qp:printfSingle("(rrr)", "right")

	qp:printfSingle(demo_coloredtext, "center")

	qp:setTabs(demo_tabs)

	qp:setAlign("left")
	qp:write("|lll|")
	qp:setAlign("center")
	qp:write("|ccc|")
	qp:setAlign("right")
	qp:write("|rrr|")

	qp:setAlign("left")
	qp:down()

	qp:writefSingle("|l||l|", "left")
	qp:writefSingle("|c||c|", "center")
	qp:writefSingle("|r||r|", "right")

	qp:setAlign("left")
	qp:down()

	local v_sep = love.graphics.getHeight() - math.ceil(font_sub:getHeight() * qp.sy) - 64

	local rr, gg, bb, aa = love.graphics.getColor()
	love.graphics.setColor(0, 0, 0, 4/5)
	love.graphics.rectangle("fill", 0, v_sep, love.graphics.getWidth(), love.graphics.getHeight() - v_sep)
	love.graphics.setColor(rr, gg, bb, aa)

	qp:setOrigin(16, v_sep + 32)
	qp:setTabs()

	qp:print("Press escape to quit!")

	love.graphics.pop()
end

