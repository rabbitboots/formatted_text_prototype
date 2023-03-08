# font_set.lua

FontSet is a LÖVE library for selecting and scaling LÖVE ImageFonts and BMFonts relative to a TrueType font size. It's intended to be used within the context of UI scaling.


## How it works

A `font_set` table holds metadata associated with an ImageFont or BMFont. It can hold details of multiple subsets of the same ImageFont or BMFont, at different scales. When you call `font_set:reload()`, it generates or regenerates a LÖVE Font object which you can use for printing.

A TTF size of 12 is presumed to have glyphs that require 12 pixel rows in order to be fully displayed. (Typically, the pipe glyph ("|") covers this vertical range.) Fonts typically have additional padding, making the size of whole lines about 1.25 times larger than the font size number. You may prefer to just treat size 12 as 1:1 scaling for ImageFonts, regardless of their actual size, but if you want to mix them with TTFs, there will be a height difference.

Pixel fonts look perfect with nearest filtering at integral scales. Fractional scales below 3.0 can get horribly mangled, with 1.5 being particularly bad. Personally, I think it's hard to tell the difference with 'nearest' above 4.0 (if it's not constantly changing scale, at least.) 'linear' filtering arguably looks better for 1.5 scale than 'nearest', but it gets very fuzzy beyond that.

As a compromise, FontSet can swap in pre-scaled versions of the ImageFont with 'linear' filtering. It's still blurry at non-integral scales, but the extent of the blur is diminished at higher prescale values. This isn't free, however: a 4x prescaled ImageFont requires 16 times as much memory.

FontSet treats BMFonts nearly the same as ImageFonts. TrueType fonts are technically supported, but FontSet offers little value to them other than being able to keep track of the hinting mode and line height.


## Functions

### fontSet.newImageFont

Creates a new ImageFont set.

`fontSet.newImageFont(set_t, glyph_str)`

* `set_t`: Table-of-tables containing `{size=<number>, src=<string|ImageData>}`. The `src` field can be a path to a PNG file, or a pre-loaded LÖVE ImageData object. Font sizes may contain gaps, but must be ordered smallest to largest, and duplicate sizes are not allowed.
* `glyph_str`: A string that identifies the supported glyphs. All subsets of the ImageFont must use the same glyph string.

**Returns:** The new ImageFont set.


### fontSet.newBMFont

Create a new BMFont set.

`fontSet.newBMFont(set_t)`

* `set_t`: Table-of-tables containing `{size=<number>, src=<string|Data>, image_src=<string|ImageData>`. `src` can be a path to a .bmf file or an equivalent LÖVE Data object. `image_src` is optional, and can be a path to the associated .png file, or an equivalent LÖVE ImageData. Font sizes may contain gaps, but should be ordered smallest to largest, and duplicate sizes are not allowed.

**Returns:** The new BMFont set.

**Warning:** If both `src` and `image_src` are used, then they must both be string file-paths or LÖVE Data objects. Mixing types will cause an error.


### fontSet.newTrueType

Create a new TrueType Font set.

`fontSet.newTrueType(src, hinting, dpi_scale)`

* `src`: String path to the TTF file, a TTF file in memory as a LÖVE Data object, or false to use LÖVE's built-in font (*Noto Sans* on LÖVE 12, *Vera Sans* before that.)
* `hinting`: *("normal")* The TrueType hint enum. Can be "normal", "light", "mono" or "none".
* `dpi_scale`: *(love.graphics.getDPIScale())* DPI scale of the font.

**Returns:** The new TrueType set.


## font_set Methods


### self:reload

Generate or regenerate the LÖVE Font object associated with a `font_set`.

`self:reload(size)`

* `size`: The font size to use.

**Returns:** The new LÖVE Font object, and the transform scale for rendering.


### self:getFont

Gets a reference to the current LÖVE Font object, plus the scale needed for when drawing or offsetting. If not yet loaded, the Font object will be created at the default size (`fontSet.conf.default_size`).

`self:getFont()`

**Returns:** The LÖVE Font object, and the transform scale for rendering.


### self:spawnFontObject

Generate a LÖVE Font object based on the current set configuration. This is the internal function which powers `self:reload()` behind the scenes. It's exposed because it might be helpful to users in some special cases. When called externally, the font object is independent of the `font_set` table, and further changes to the set won't affect it.

`self:spawnFontObject(size)`

* `size`: The font size to use.

**Returns:** The new LÖVE Font object, the transform scale for rendering, and the chosen subset index (for ImageFonts and BMFonts.)


### self:setExtraSpacing

**(ImageFonts only)** Set an ImageFont's `extraspacing` value. This is scaled with the ImageFont pre-scale when LÖVE Font objects are created. Changes take effect upon font reload.

`self:setExtraSpacing(extraspacing)`

* `extraspacing`: Number of pixels to use for spacing between glyphs. Can be negative.

**Returns:** Nothing.

*See:* [LÖVE Wiki: love.graphics.newImageFont](https://love2d.org/wiki/love.graphics.newImageFont)


### self:setLineHeight

Set a font's line height. Can be called before the font object is created, and takes effect immediately if the font object does exist.

`self:setLineHeight(line_height)`

* `line_height`: The new line height value to pass to `Font:setLineHeight()`.

**Returns:** Nothing.

*See:* [LÖVE Wiki: Font:setLineHeight](https://love2d.org/wiki/Font:setLineHeight)


### self:setScaleMode

**(ImageFonts and BMFonts only)** Sets the scaling mode for the font set. Changes take effect upon font reload.

`self:setScaleMode(scale_mode)`

* `scale_mode`: `"fluid"` to allow non-integral scales (1.15, etc.), `"fixed"` to force integral scales (1, 2, 3, etc.)

**Returns:** Nothing.


### self:setSelectMode

**(ImageFonts and BMFonts only)** Sets the subset selection (rounding) mode for the font set. If a font_set has sizes 12 and 24, and the user requests size 18, this setting determines which subset is chosen. Changes take effect upon font reload.

`self:setSelectMode(select_mode)`

* `select_mode`: `"round"` to round to nearest size, `"floor"` to round down, `"ceil"` to round up.

**Returns:** Nothing.


### self:setFilter

Sets the font's `min`, `mag` and `anisotropy` settings. Can be called before the Font object is created, and changes take effect immediately if the Font object exists.

`self:setFilter(min, mag, anisotropy)`

* `min` *("linear")* Downscaling interpolation. `"linear"` or `"nearest"`.
* `min` *("linear")* Upscaling interpolation. `"linear"` or `"nearest"`.
* `anisotropy` *(1)* Max amount of anisotropic filtering.

**Returns:** Nothing.

*See:* [LÖVE Wiki: Font:setFilter](https://love2d.org/wiki/Font:setFilter)


## Usage Notes

The demo may give the impression that FontSet is intended for constantly scaling text. Not so! Reloading fonts is an expensive operation, especially at large sizes. It's assumed that loading/reloading only happens during boot-up, during load screens, or when the UI scale settings change at the request of the user (or something semi-automated prompts a change, like if the UI scale is keyed to the window size). For fluid, sprite-like text printing, you may want to try something like [SYSL-Text](https://github.com/sysl-dev/SYSL-Text) instead.

By default, when a reload occurs, it releases old font objects, and calls the garbage collector twice to ensure they are cleaned up. Be careful about dangling font references. If you just want unattached Font objects, you can use the `font_set:spawnFontObject()` method.

The LÖVE wiki advises against printing text at non-integer positions, because it may result in blurry text. Non-integral scaling of pixel art text guarantees that this will happen. Such is life.

FontSet does not handle the assignment of fallback fonts. This info is lost upon reloading, since new Font objects are created, so they need to be set every time a reload occurs. More info on that feature [here](https://love2d.org/wiki/Font:setFallbacks).

A suitably high MSAA value might achieve smooth results with 'nearest' font filtering. You can print to a MSAA-enabled canvas / texture without applying MSAA to the main framebuffer.

BMFont is more advanced than LÖVE's ImageFonts, but your results will vary depending on the program you use to make them. The BMFonts included in the demo were generated with [fontbm](https://github.com/vladimirgamalyan/fontbm), a cross-platform command line utility.


## License

Copyright (c) 2022 RBTS

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


