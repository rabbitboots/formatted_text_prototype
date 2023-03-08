# quick\_print.lua

QuickPrint is a text drawing library for the [LÖVE](https://love2d.org/) Framework.

Version: **v1.0.4** (See CHANGELOG.md for potential breaking changes from v1.0.3.)


![quickprint\_gh\_1](https://user-images.githubusercontent.com/23288188/168460007-1d08b8ba-3893-4e07-a01b-21a2f3332a8e.png)


## Features

* Virtual tab stops
* Can print to LÖVE Text Objects
* Basic support for scaled text (for pixel-art LÖVE ImageFonts)


## Hello World

```lua
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
```

Check out the demo files for more examples.


## How it works

QuickPrint updates an internal cursor position with every draw. When virtual tab stops are enabled, the next write is positioned relative to the current tab X position. It can draw text to the screen/canvas, or add text to a LÖVE Text object.

Functions take effect immediately (there is no reshaping step, and limited memory of previous drawing operations), so it's limited in the kinds of layouts it supports. The library was originally written for debug-printing.

QuickPrint's writing functions are split into "plain" and "formatted" categories. The plain functions convert all values to be printed to strings. As a result, LÖVE `coloredtext` sequences won't work. The formatted writing functions do not apply any type conversion, and are programmed to handle `coloredtext`.


## Public Functions


### quickPrint.new

Creates and returns a new quick\_print state table.

`quickPrint.new(ref_w, ref_h)`
* `ref_w`: (math.huge) Reference width for the cursor. Affects formatted print calls with non-left alignment.
* `ref_h`: (math.huge) Reference height for the cursor. Doesn't affect printing, but may help with other tasks such as setting a draw scissor.

**Returns:** A new `qp` state table.


## State Get/Set, Cursor Movement, Tab Advance

### qp:getFont

Gets the LÖVE graphics state font, or the font associated with a LÖVE Text object which is assigned to `qp`.

`qp:getFont()`

**Returns:** A LÖVE Font object.


### qp:setTextObject

Assigns a LÖVE Text object to `qp`, or removes any existing object. All print commands will be directed to the Text object instead of the framebuffer/canvas. The `qp` table should be reset after calling, and you should call `Text:clear()` to ensure you are working with a clean slate.

`qp:setTextObject(text_object)`

* `text_object`: The LÖVE Text object to assign, or false/nil to remove any existing Text object.


### qp:getTextObject

Returns the currently assigned `qp` Text object, or nil if none is assigned.

`local text_object = qp:getTextObject()`

**Returns:** A LÖVE Text object or nil.


### qp:setTabs

Assigns a table of virtual tab stops, or removes any existing tab sequence. Each entry is either a number representing the tab's absolute X position, or a sub-table containing `x` and `align` fields. Although the X positions are absolute, they should be ordered left-to-right in the table.

`qp:setTabs(tabs)`

* `tabs`: A sequence of tab stops, or false/nil to remove any assigned tabs.


### qp:getTabs

Gets the currently-assigned table of tabs, or nil if no tabs are assigned.

`local tabs_t = qp:getTabs()`

**Returns:** Table of tabs if present, or nil if nothing is assigned.


### qp:setTabIndex

Sets the current tab index. Does not check if the index is valid or that the qp state has a tabs table assigned. Note that the cursor will not automatically go backwards to a tab that is behind.

`qp:setTabIndex(i)`

* `i`: The tab index to jump to.


### qp:getTabIndex

Gets the current tab index, or false if tab state is invalid.

`local tab_i = qp:getTabIndex()`

**Returns:** The current tab index, or false if tab state is invalid.


### qp:setAlign

Sets the align mode. Alignment behavior varies between plain and formatted print functions. `justify` mode behaves like `left` in plain functions. Some printing functions have arguments which override this setting.

`qp:setAlign(align)`

* `align`: The LÖVE align mode. Can be `left`, `center`, `right`, or `justify`.

**See:** LÖVE Wiki: [AlignMode](https://love2d.org/wiki/AlignMode)


### qp:getAlign

Gets the current align mode.

`local align = qp:getAlign()`

**Returns:** The align LÖVE enum.


### qp:advanceX

Moves the X cursor by a number of pixels. (Cursor X advance is generally only useful with left alignment. The other align modes are intended to be used with virtual tab stops.) Clears kerning memory.

`qp:advanceX(width)`

* `width`: Number of pixels to move


### qp:advanceXStr

Moves the X cursor by the pixel-width of a string, measured in reference to the current active font. Clears kerning memory.

`qp:advanceXStr(str)`

* `str`: The string whose width will be used (via `Font:getWidth()`.)


### qp:setXMin

Moves the X cursor to at least the requested minimum position. Clears kerning memory, even if the X position is unaffected.

`qp:advanceXMin(x_min)`

* `x_min`: The minimum position.


### qp:advanceXCoarse

Moves the X cursor right in "coarse" steps, acting somewhat like a tab stop without involving the `qp.tabs` table. Clears kerning memory.

`qp:advanceXMod(coarse_x, margin)`

* `coarse_x`: The "snap-to" width to use when positioning the cursor, in pixels.

* `margin`: (0) Adds pixel padding to the current X position, making it jump to the next coarse position earlier. Use to ensure there is a buffer of empty space between printed text.


### qp:advanceTab

If tab stops are assigned, moves the X cursor to the current virtual tab stop, if it is currently behind. Increments the tab stop index. Clears kerning memory. If no tabs are assigned, does nothing.

`qp:advanceTab()`


### qp:setPosition

Moves the cursor to an arbitrary position, relative to the origin. Clears kerning memory and invalidates tab stop state.

`qp:setPosition(x, y)`

* `x`: X position, relative to `qp.origin_x`.
* `y`: Y position, relative to `qp.origin_y`.


### qp:setXPosition

Moves the cursor to an arbitrary horizontal position, relative to the origin. Clears kerning memory and invalidates tab stop state.

`qp:setXPosition(x)`

* `x`: X position, relative to `qp.origin_x`.


### qp:setYPosition

Moves the cursor to an arbitrary vertical position, relative to the origin. Does not clear kerning memory or tab stop state.

`qp:setYPosition(y)`

* `y`: Y position, relative to `qp.origin_y`.


### qp:getPosition

Gets the current cursor position, relative to the origin.

`local x, y = qp:getPosition()`

**Returns:** The cursor X and Y positions (`qp.x` and `qp.y`).


### qp:getXPosition

Gets the current cursor X position, relative to the origin.

`local x = qp:getXPosition()`

**Returns:** The cursor X position (`qp.x`).


### qp:getYPosition

Gets the current cursor Y position, relative to the origin.

`local y = qp:getYPosition()`

**Returns:** The cursor Y position (`qp.y`).


### qp:movePosition

Moves the cursor, relative to the current position. Resets kerning memory and invalidates tab stop state.

`qp:movePosition(dx, dy)`

* `x`: Amount to add to the current X position (`qp.x`).
* `y`: Amount to add to the current Y position (`qp.y`).


### qp:moveXPosition

Moves the cursor horizontally, relative to the current position. Resets kerning memory and invalidates tab stop state.

`qp:moveXPosition(dx)`

* `x`: Amount to add to the current X position (`qp.x`).


### qp:moveYPosition

Moves the cursor vertically, relative to the current position. Does not reset kerning memory or tab stop state.

`qp:moveYPosition(dy)`

* `y`: Amount to add to the current Y position (`qp.y`).


### qp:setOrigin

Repositions the `qp` origin (top-left printing area). Resets cursor position to (0, 0). Resets kerning memory.

`qp:setOrigin(origin_x, origin_y)`

* `origin_x`: New X origin.
* `origin_y`: New Y origin.


### qp:setXOrigin

Repositions the `qp` X origin (left printing area). Resets cursor position to (0, 0). Resets kerning memory.

`qp:setXOrigin(origin_x)`

* `origin_x`: New X origin.


### qp:setYOrigin

Repositions the `qp` Y origin (top printing area). Resets cursor position to (0, 0). Resets kerning memory.

`qp:setYOrigin(origin_y)`

* `origin_y`: New Y origin.


### qp:getOrigin

Gets the current `qp` origin.

`local orig_x, orig_y = qp:getOrigin()`

**Returns:** The `qp` origin X and Y (`qp.origin_x` and `qp.origin_y`).


### qp:getXOrigin

Gets the current `qp` X axis origin.

`local orig_x = qp:getXOrigin()`

**Returns:** The `qp` X origin (`qp.origin_x`).


### qp:getYOrigin

Gets the current `qp` Y axis origin

`local orig_y = qp:getYOrigin()`

**Returns:** The `qp` Y origin (`qp.origin_y`).


### qp:moveOrigin

Moves the `qp` origin relative to its current location. Resets cursor position to (0, 0). Resets kerning memory.

`qp:moveOrigin(dx, dy)`:
 
* `dx`: Amount to add to the current X origin (`qp.origin_x`).
* `dy`: Amount to add to the current Y origin (`qp.origin_y`).


### qp:setReferenceDimensions

Sets the current reference width and height (of the printing area). Resets kerning memory.

`qp:setReferenceDimensions(ref_w, ref_h)`

* `ref_w`: New base width (`qp.ref_w`).
* `ref_h`: New base height (`qp.ref_h`).

**Note:** Reference height is not currently used by QuickPrint, but is provided in case it helps with positioning and applying scissor-boxes.


### qp:getReferenceDimensions

Gets the current reference dimensions.

`local ref_w, ref_h = qp:getReferenceDimensions()`

**Returns:** The current reference dimensions.


### qp:setReferenceWidth

Sets the `qp` reference width (of the printing area). Resets kerning memory.

`qp:setReferenceWidth(ref_w)`

* `ref_w`: The new reference width.


### qp:getReferenceWidth

Gets the `qp` reference width.

`local ref_w = qp:getReferenceWidth()`

**Returns:** The reference width.


### qp:setReferenceHeight

Sets the `qp` reference height (of the printing area). Resets kerning memory.

`qp:setReferenceHeight(ref_h)`

* `ref_h`: The new reference height.

**Note:** Reference height is not currently used by QuickPrint, but is provided in case it helps with positioning and applying scissor-boxes.


### qp:getReferenceHeight()

Gets the current reference height.

`local ref_h = qp:getReferenceHeight()`

**Returns:** The reference height.


### qp:setScale

Sets the `qp` scale. Intended to help with drawing pixel art ImageFonts within a scaled interface. These values will be passed as the `sx` and `sy` arguments for `love.graphics.print()` and `love.graphics.printf()`, and the cursor will attempt to take the scale into account when moving forward.

`qp:setScale(sx, sy)`

* `sx` X scale. 1.0 is normal size, 2.0 is double, 0.5 is half, etc.
* `sy` *(sx)* Y scale.


### qp:getScale

Gets the current `qp` scale.

`local sx, sy = qp:getScale()`

**Returns:** The X scale and Y scale values (`qp.sx`, `qp.sy`).


### qp:setVerticalPadding

Sets a vertical padding value, which is applied whenever the cursor moves down a line.

`qp:setVerticalPadding(pad_v)`

* `pad_v` Additional padding (in pixels).

**Note:** It may be more effective to set a custom line height multiplier in your LÖVE Font objects. See: [Font:setLineHeight()](https://love2d.org/wiki/Font:setLineHeight)


### qp:getVerticalPadding

Gets the current vertical padding value.

`local pad_v = qp:getVerticalPadding()`

**Returns:** The vertical padding value (`qp.pad_v`)


### qp:reset

Moves cursor to (0, 0), resets the alignment mode to `"left"`, and resets the tab stop index to 1. It does not clear the `qp.tabs` table, nor does it remove bound Text objects. Clears kerning memory.

`qp:reset()`


### qp:down

Moves cursor down by a number of lines. Line height is determined by the current font, its line height setting, and the `qp`'s Y scaling. Vertical padding (`qp.pad_v`) is applied once per call. Clears kerning memory.

`qp:down(qty)`

* `qty`: (1) How many lines to move down. Numbers less than 1 are ignored.


### qp:clearKerningMemory

Clears kerning memory, and nothing else.

`qp:clearKerningMemory()`


## Plain Writing Functions

In all plain writing functions, values are converted to strings before being passed to `love.graphics.print()`.


### qp:write

Writes a varargs series of strings to a line.

`qp:write(...)`

* `...` Varargs list of variables to write.


### qp:writeSeq

A version of `qp:write()` that takes one sequence (array table).

`qp:writeSeq(tbl)`

* `tbl`: Table of values to write. Values can be any type except `nil`.


### qp:writeN

Versions of `qp:write()` which take exactly 1 to 4 arguments. Additional arguments are ignored.

`qp:write1(s1)`

`qp:write2(s1, s2)`

`qp:write3(s1, s2, s3)`

`qp:write4(s1, s2, s3, s4)`

* `s1`: The first value to write.
* `s2`: The second value.
* `s3`: The third value.
* `s4`: The fourth value.


### qp:print

Writes a varargs list of arguments to a line, and then moves the cursor to the start of the next line.

`qp:print(...)`

* `...` Varargs list of variables to write.


### qp:printSeq

Version of `qp:print()` that takes one sequence (array table).

`qp:printSeq(tbl)`

* `tbl`: Table of values to write. Values can be any type except `nil`.


### qp:printN

Versions of `qp:print()` which take exactly 1 to 4 arguments. Additional arguments are ignored.

`qp:print1(s1)`

`qp:print2(s1, s2)`

`qp:print3(s1, s2, s3)`

`qp:print4(s1, s2, s3, s4)`


* `s1`: The first value to write.
* `s2`: The second value.
* `s3`: The third value.
* `s4`: The fourth value.


## Formatted Writing Functions

These do not convert values to strings, and are programmed to support `coloredtext` sequences. Unlike the plain functions, they take only one string or `coloredtext` sequence per call.


### qp:writefSingle

Prints one string or `coloredtext` sequence using formatting features provided by `love.graphics.printf()`. This function assumes that the text will not exceed one line (or that the caller is not concerned if it happens to wrap). If you use align modes other than `"left"`, you must set a reference width (`qp.ref_w`), or else the text will render infinitely to the right. This function is also affected by virtual tab stop state. It does not advance the X cursor.

`qp:writefSingle(text, align)`

* `text`: The string or `coloredtext` sequence to print.
* `align`: (`qp.align`) LÖVE AlignMode enum: `"left"`, `"center"`, `"right"` or `"justify"`.


### qp:printfSingle

Like `qp:writefSingle()`, but automatically moves the cursor down one line after printing.

`qp:printfSingle(text, align)`

* `text`: The string or `coloredtext` sequence to print.
* `align`: (`qp.align`) LÖVE AlignMode enum: `"left"`, `"center"`, `"right"` or `"justify"`.


### qp:printf

Prints one string or `coloredtext` sequence using formatting features provided by `love.graphics.printf()`, and then moves the cursor down to the next free line. Unlike `qp:writefSingle()` and `qp:printfSingle()`, this does not take the virtual tab state into account. It will also generate some throwaway tables and strings in order to calculate the new Y cursor position.

`qp:printf(text, align)`

* `text`: The string or `coloredtext` sequence to print.
* `align`: (`qp.pf_align`) LÖVE AlignMode enum: `"left"`, `"center"`, `"right"` or `"justify"`.


## Tips, Limitations

* Switching fonts between write operations on the same line may lead to inconsistent offsetting and kerning. Text objects do not support multiple simultaneous fonts, so you shouldn't change a Text object's font as you write to it.

* QuickPrint is not optimized, and cannot be optimized very much given its design. (It's quick as in *quick and dirty*.) If you have a lot of text that rarely changes, you can save some CPU cycles by printing it to a LÖVE Text object and drawing that, only clearing and rewriting the Text when there's a change. Rendering to a canvas is another option.


## Known Bugs

### One
* In LÖVE 11.4, adding empty or whitespace-only strings to a Text Object crashes the application.
  * This is fixed in LÖVE 12.
  * `_love11TextGuard()` is implemented as a workaround. It will be removed when the library is upgraded to LÖVE 12.

### Two
* In LÖVE 11.4, small `wraplimit` values given to `Text:addf()` crash the application.
  * This is fixed in LÖVE 12. `Text:setf()` and `love.graphics.printf()` are not affected.
  * Workaround: If using `Text:addf()`, find a minimum working value for your font(s) and never make the reference width smaller than that.

