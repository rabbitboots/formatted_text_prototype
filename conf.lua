jit.off()

function love.conf(t)
	local major, minor = love.getVersion()
	t.window.title = "rtext prototype (2023-03) (LÖVE " .. major .. "." .. minor .. ")"
	t.window.resizable = true
end
