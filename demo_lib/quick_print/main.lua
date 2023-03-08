--[[
	QuickPrint demo launcher for LÖVE 11.x.

	[UPGRADE] In LÖVE 12, you can just run the demo files directly.

	Usage: love . <require.path.to.demo>

	Just type 'love .' to launch the first demo.
--]]

function love.load(arguments)
	local demo_id = arguments[1] or "demo1"

	require(demo_id)
end
