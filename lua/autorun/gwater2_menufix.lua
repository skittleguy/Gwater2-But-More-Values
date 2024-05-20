-- fixes menu not working in singleplayer. Fuck this shit hack
if !game.SinglePlayer() or CLIENT then return end

hook.Add("PlayerButtonDown", "gwater2_menu", function(ply, key)
	ply:SendLua("OpenGW2Menu(LocalPlayer(), " .. key .. ")")
end)
hook.Add("PlayerButtonUp", "gwater2_menu", function(ply, key)
	ply:SendLua("CloseGW2Menu(LocalPlayer(), " .. key .. ")")
end)