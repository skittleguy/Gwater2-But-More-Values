-- fixes menu not working in singleplayer because of predicted hooks. Fuck this shit hack
if !game.SinglePlayer() or CLIENT then return end

hook.Add("PlayerButtonDown", "gwater2_menu", function(ply, key)
	ply:SendLua("pcall(function() gwater2.open_menu(LocalPlayer(), " .. key .. ") end)")
end)
hook.Add("PlayerButtonUp", "gwater2_menu", function(ply, key)
	ply:SendLua("pcall(function() gwater2.close_menu(LocalPlayer(), " .. key .. ") end)")
end)