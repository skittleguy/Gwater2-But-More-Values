-- accepts swep, returns frame

local _util = include("menu/gwater2_util.lua")
local styling = include("menu/gwater2_styling.lua")

local function make_scratch(frame, locale_parameter_name, default, min, max, decimals, convar)
    local panel = frame:Add("DPanel")
	function panel:Paint() end
	panel:Dock(TOP)
	local label = panel:Add("DLabel")
	label:SetText(_util.get_localised(locale_parameter_name))
	label:SetColor(Color(255, 255, 255))
	label:SetFont("GWater2Param")
	label:SetMouseInputEnabled(true)
	label:SizeToContents()
	local slider = panel:Add("DNumSlider")
    slider:SetConVar(convar)
	slider:SetDecimals(decimals)
	slider:SetMinMax(min, max)
	local button = panel:Add("DButton")
	button:SetText("")
	button:SetImage("icon16/arrow_refresh.png")
	button:SetWide(button:GetTall())
	button.Paint = nil
	panel.label = label
	panel.slider = slider
	panel.button = button
	label:Dock(LEFT)
	button:Dock(RIGHT)

	slider:SetText("")
	slider:Dock(FILL)

	-- HACKHACKHACK!!! Docking information is not set properly until after all elements are loaded
	-- I want the weird arrow editor on the text part of the slider, so we need to move and resize the slider after
	-- ..all of the docking information is loaded
	slider.Paint = function(w, h)
		local pos_x, pos_y = slider:GetPos()
		local size_x, size_y = slider:GetSize()
		
		slider:Dock(NODOCK)
		slider:SetPos(pos_x - size_x / 1.45, pos_y)	-- magic numbers. blame DNumSlider for this shit
		slider:SetSize(size_x * 1.7, size_y)

		slider.Paint = nil
	end
	
	--slider.Label:Hide()

	slider.TextArea:SizeToContents()
	function button:DoClick()
		slider:SetValue(default)
		if gwater2.options.read_config().sounds then surface.PlaySound("gwater2/menu/reset.wav", 75, 100, 1, CHAN_STATIC) end
	end


	panel:SetTall(panel:GetTall()+2)
    return panel
end

return function(self)
    local frame
    -- gwater 2 main menu: steal his look!!!
    do -- so that we can collapse it
        frame = vgui.Create("DFrame")
        frame:SetSize(ScrW()/3, ScrH()/3)
        frame:Center()
        frame:MakePopup()
        frame:SetTitle("GWater 2 " .. gwater2.VERSION .. ": Water Gun Menu")

        frame:SetScreenLock(true)
        function frame:Paint(w, h)
            styling.draw_main_background(0, 0, w, h)
        end

        local minimize_btn = frame:GetChildren()[3]
        minimize_btn:SetVisible(false)
        local maximize_btn = frame:GetChildren()[2]
        maximize_btn:SetVisible(false)
        local close_btn = frame:GetChildren()[1]
        close_btn:SetVisible(false)

        local new_close_btn = vgui.Create("DButton", frame)
        new_close_btn:SetPos(frame:GetWide() - 20, 0)
        new_close_btn:SetSize(20, 20)
        new_close_btn:SetText("")

        function new_close_btn:DoClick()
            frame:Close()
        end

        function new_close_btn:Paint(w, h)
            if self:IsHovered() then
                surface.SetDrawColor(255, 0, 0, 127)
                surface.DrawRect(0, 0, w, h)
            end
            surface.SetDrawColor(255, 255, 255)
            surface.DrawOutlinedRect(0, 0, w, h)
            surface.DrawLine(5, 5, w - 5, h - 5)
            surface.DrawLine(w - 5, 5, 5, h - 5)
        end
    end

    -- TODO: parameter explanations
    make_scratch(frame, "WaterGun.Velocity", 10, 0, 100, 2, "gwater2_gun_velocity")
    make_scratch(frame, "WaterGun.Distance", 250, 100, 1000, 2, "gwater2_gun_distance")
    make_scratch(frame, "WaterGun.Density", 1, 0.1, 10, 2, "gwater2_gun_density")
    make_scratch(frame, "WaterGun.SpawnMode", 1, 1, 2, 0, "gwater2_gun_spawnmode")

    return frame
end