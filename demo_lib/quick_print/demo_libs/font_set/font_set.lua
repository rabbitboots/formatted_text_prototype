-- FontSet: A library for sizing LÖVE fonts within the context of a scalable UI.
-- See README.md for info and license details.
-- Version 1.0.0

local fontSet = {}

fontSet.conf = {}

-- When true, collect garbage after releasing LÖVE resources associated with a font.
fontSet.conf.aggressive_cleanup = true

-- The default font size if none is specified.
fontSet.conf.default_size = 12

local _mt_set = {}
_mt_set.__index = _mt_set


-- * Internal *

local function assertArgType(n, val, str)
	if type(val) ~= str then
		error("argument #" .. n .. ": expected type " .. str .. ", got " .. type(val), 2)
	end
end


local function assertFilterType(arg_n, f_str)
	if f_str ~= "nearest" and f_str ~= "linear" then
		error("argument #" .. arg_n .. ": invalid filter enum.")
	end
end


local function checkSourceField(src, directive, label, i)
	-- ImageFonts and BMFonts only.

	-- Exempt 'src' being a Data object.
	if type(src) == "userdata" then
		if not src:typeOf("Data") then
			error("set #" .. i .. " " .. label .. ": expected string or Data object, got non-Data userdata.")
		end

	elseif type(src) ~= "string" then
		error("set #" .. i .. " " .. label .. ": expected string, got " .. type(src))
	end

	if type(src) == "string" and directive == "exists" then 
		-- [UPGRADE] l.fs.exists() will be re-added in LÖVE 12.
		if not love.filesystem.getInfo(src) then
			error("set #" .. i .. " " .. label .. ": missing file or insufficient read permissions.")
		end
	end
end


local function validateSourceTables(sets_t, check_src, check_image_src, check_size)
	-- ImageFonts and BMFonts only.

	local size_min = false

	for i, set in ipairs(sets_t) do
		if check_src then
			checkSourceField(set.src, "exists", "src", i)
		end

		if check_size then
			local size = set.size
			if type(size) ~= "number" then
				error("set #" .. i .. " size: expected number, got " .. type(size))
			end

			if size_min and size <= size_min then
				error("set table #" .. i .. ": size is out of order or the same as the previous entry.")
			end
			size_min = size
		end

		if check_image_src == "absent" then
			if set.image_src ~= nil then
				error("set table #" .. i .. ": 'image_src' is not supported for this font type (BMFont only).")
			end

		elseif check_image_src then
			-- The image source param is optional. If not present, LÖVE will check the .fnt file for the image path.
			if set.image_src ~= nil then
				checkSourceField(set.image_src, "exists", "image_src", i)
			end
		end
	end
end


local function findSubset(self, size)
	-- The logic to select a font subset table. ImageFonts and BMFonts only.

	local st = self.set_t

	-- Special case: If the requested size is less or equal to the first subset, just return it.
	if st and st[1] and size <= st[1].size then
		return 1, st[1]
	end

	local i = 1
	while true do
		local first = st[i]
		local second = st[i + 1] -- can be nil

		-- No suitable match: just return the very first entry. If the list is empty, it will return nil.
		if not first then
			return i, st[1]

		-- Reached last item in the list: return it
		elseif first and not second then
			return i, first

		-- Floor, round, ceil implementations
		elseif self.select_mode == "floor" and size >= first.size and size < second.size then
			return i, first

		elseif self.select_mode == "round" then
			if size - first.size <= (second.size - first.size) / 2 then
				return i, first
			elseif size <= second.size then
				return i + 1, second
			end

		elseif self.select_mode == "ceil" and size > first.size and size <= second.size then
			return i + 1, second
		end

		i = i + 1
	end
end


-- * / Internal *


-- * Set Creation *


function fontSet.newImageFont(set_t, glyph_str)

	assertArgType(1, set_t, "table")
	validateSourceTables(set_t, true, false, true)

	assertArgType(2, glyph_str, "string")

	local self = {}

	self.font_type = "imagefont"

	self.set_t = set_t

	-- ImageFont params
	self.glyph_str = glyph_str
	self.extraspacing = 0

	-- FontSet params
	self.select_mode = "round"
	self.scale_mode = "fluid"

	-- General font params
	self.line_height = 1.0
	self.min, self.mag, self.anisotropy = love.graphics.getDefaultFilter()

	self.object = false

	-- font_set internal settings
	self.scale_index = 1
	self.transform_scale = 1.0

	setmetatable(self, _mt_set)

	return self
end


function fontSet.newBMFont(set_t)

	--[[
	[WARN] If both src and image_src are used, then both fields must be either file-path strings or LÖVE Data.
	Mixing them will raise an error:
		String src, ImageData image_src: "Error: Could not decode data to ImageData: unsupported encoded format"
		FileData src, string image_src: "Error: bad argument #2 to '?' (ImageData expected, got string)"
	--]]

	assertArgType(1, set_t, "table")
	validateSourceTables(set_t, true, true, true)

	local self = {}

	self.font_type = "bmfont"

	self.set_t = set_t

	-- FontSet params
	self.select_mode = "round"
	self.scale_mode = "fluid"

	-- General font params
	self.line_height = 1.0
	self.min, self.mag, self.anisotropy = love.graphics.getDefaultFilter()

	self.object = false

	-- font_set internal settings
	self.scale_index = 1
	self.transform_scale = 1.0

	setmetatable(self, _mt_set)

	return self
end


function fontSet.newTrueType(src, hinting, dpi_scale)

	-- Exempt 'src' from further checks if it's a FileData object.
	if type(src) == "userdata" and src:typeOf("FileData") then
		-- Do nothing

	elseif src ~= false then
		assertArgType(1, src, "string")

		-- Try touching the TTF file to prove it exists.
		local file_info = love.filesystem.getInfo(src)
		if not file_info then
			error("TrueType font at 'src' path doesn't exist or there are not sufficient read permissions: " .. src)
		end
	end

	hinting = (hinting ~= nil) and hinting or "normal"
	if hinting ~= "normal" and hinting ~= "light" and hinting ~= "mono" and hinting ~= "none" then
		error("'hinting' needs to be nil, 'normal', 'light', 'mono' or 'none'.")
	end

	dpi_scale = (dpi_scale ~= nil) and dpi_scale or love.graphics.getDPIScale()
	assertArgType(3, dpi_scale, "number")

	local self = {}

	self.font_type = "truetype"

	self.src = src

	-- select_mode and scale_mode don't apply to TTF sets.

	-- TTF params
	self.hinting = hinting
	self.dpi_scale = dpi_scale

	-- General font params
	self.line_height = 1.0
	self.min, self.mag, self.anisotropy = love.graphics.getDefaultFilter()

	self.object = false

	-- font_set internal settings
	self.transform_scale = 1.0 -- for TTF, should always be 1.0
	self.scale_index = nil -- for TTF, not applicable

	setmetatable(self, _mt_set)

	return self
end


-- * / Set Creation *


-- * Methods *


function _mt_set:reload(size)

	size = size or fontSet.conf.default_size

	assertArgType(1, size, "number")
	if size < 1 then
		error("font size must be at least 1.")
	end

	local do_cleanup = false

	if self.object then
		self.object:release()
		self.object = false

		do_cleanup = true
	end

	self.object, self.transform_scale, self.scale_index = self:spawnFontObject(size)

	if do_cleanup and fontSet.conf.aggressive_cleanup then
		collectgarbage("collect")
		collectgarbage("collect")
	end

	return self.object, self.transform_scale
end


function _mt_set:getFont()
	if not self.object then
		self:reload(fontSet.conf.default_size)
	end

	return self.object, self.transform_scale
end


function _mt_set:spawnFontObject(size)

	size = math.max(1, size)

	local font_object
	local sub_i, subset -- ImageFont and BMFont only
	local transform_scale

	if self.font_type == "truetype" then
		transform_scale = 1

		if self.src == false then
			font_object = love.graphics.newFont(size, self.hinting, self.dpi_scale)
		else
			font_object = love.graphics.newFont(self.src, size, self.hinting, self.dpi_scale)
		end

	else
		sub_i, subset = findSubset(self, size)
		if not subset then
			error("subset locator failed for size: " .. tostring(size))
		end

		local scale
		if self.scale_mode == "fluid" then
			transform_scale = size / subset.size
			--print("transform_scale = size / subset.size", transform_scale, size, subset.size)

		elseif self.scale_mode == "fixed" then
			transform_scale = 1

		else
			error("unknown scale_mode setting.")
		end

		if self.font_type == "imagefont" then
			local src = subset.src
			local glyphs = self.glyph_str
			local x_spacing = math.floor(self.extraspacing * (subset.size / 12))

			font_object = love.graphics.newImageFont(src, glyphs, x_spacing)

		elseif self.font_type == "bmfont" then
			local bm_font
			if subset.image_src then
				font_object = love.graphics.newFont(subset.src, subset.image_src)
			else
				font_object = love.graphics.newFont(subset.src)
			end

		else
			error("unknown font type.")
		end
	end

	-- Set general font config
	font_object:setFilter(self.min, self.mag, self.anisotropy)
	font_object:setLineHeight(self.line_height)

	return font_object, transform_scale, sub_i
end


function _mt_set:setExtraSpacing(extraspacing)

	assertArgType(1, extraspacing, "number")

	if self.font_type ~= "imagefont" then
		error("extraspacing is applicable to ImageFonts only.")
	end

	self.extraspacing = extraspacing
end


function _mt_set:setLineHeight(line_height)

	assertArgType(1, line_height, "number")

	self.line_height = line_height

	if self.object then
		self.object:setLineHeight(self.line_height)
	end
end


function _mt_set:setScaleMode(scale_mode)
	if self.font_type ~= "imagefont" and self.font_type ~= "bmfont" then
		error("scale_mode is applicable to ImageFonts and BMFonts only.")

	elseif scale_mode ~= "fluid" and scale_mode ~= "fixed" then
		error("invalid scale mode.")
	end

	self.scale_mode = scale_mode
end


function _mt_set:setSelectMode(select_mode)
	if self.font_type ~= "imagefont" and self.font_type ~= "bmfont" then
		error("select_mode is applicable to ImageFonts and BMFonts only.")

	elseif select_mode ~= "round" and select_mode ~= "floor" and select_mode ~= "ceil" then
		error("invalid select mode.")
	end

	self.select_mode = select_mode
end


function _mt_set:setFilter(min, mag, anisotropy)

	min = min or "linear"
	assertFilterType(1, min)

	mag = mag or "linear"
	assertFilterType(1, mag)

	anisotropy = anisotropy or 1
	assertArgType(3, anisotropy, "number")

	self.min = min
	self.mag = mag
	self.anisotropy = anisotropy

	if self.object then
		self.object:setFilter(self.min, self.mag, self.anisotropy)
	end
end


-- * / Methods *


return fontSet
