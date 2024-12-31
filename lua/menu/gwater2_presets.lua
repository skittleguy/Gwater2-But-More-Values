---@diagnostic disable: inject-field
-- CAUTION!!
-- This is not a "custompresets" file. Instead, use import functionality in presets tab.
-- This file contains code used to generate, parse, and handle presets.
-- DO NOT EDIT ANYTHING IN THERE UNLESS YOU KNOW WHAT YOU ARE DOING!!

AddCSLuaFile()

if SERVER or not gwater2 then return end

local styling = include("menu/gwater2_styling.lua")
local _util = include("menu/gwater2_util.lua")

local default_presets = {
	["000-(Default) Water"]={
		["CUST/Author"]="Meetric",
		["CUST/Master Reset"]=true,
		["CUST/Default Preset Version"]=1
	},
	["001-Acid"]={
		["CUST/Author"]="Meetric",
		["VISL/Color"]={240, 255, 0, 150},
		["PHYS/Adhesion"]=0.1,
		["PHYS/Viscosity"]=0,
		["INTC/TouchDamage"]=2,
		["CUST/Master Reset"]=true,
		["CUST/Default Preset Version"]=1
	},
	["002-Blood"]={
		["CUST/Author"]="GHM",
		["VISL/Color"]={210, 30, 30, 150},
		["PHYS/Cohesion"]=0.45,
		["PHYS/Adhesion"]=0.15,
		["PHYS/Viscosity"]=1,
		["PHYS/Surface Tension"]=0,
		["PHYS/Fluid Rest Distance"]=0.55,
		["CUST/Master Reset"]=true,
		["CUST/Default Preset Version"]=1
	},
	["003-Glue"]={ -- yeah, sure... "glue"...
		["CUST/Author"]="Meetric",
		["VISL/Color"]={230, 230, 230, 255},
		["PHYS/Cohesion"]=0.03,
		["PHYS/Adhesion"]=0.1,
		["PHYS/Viscosity"]=10,
		["INTC/MultiplyWalk"]=0.25,
		["CUST/Master Reset"]=true,
		["CUST/Default Preset Version"]=1
	},
	["004-Lava"]={
		["CUST/Author"]="Meetric",
		["VISL/Color"]={255, 130, 0, 200},
		["VISL/Color Value Multiplier"]=2.1,
		["PHYS/Cohesion"]=0.1,
		["PHYS/Adhesion"]=0.01,
		["PHYS/Viscosity"]=10,
		["INTC/TouchDamage"]=5,
		["INTC/MultiplyWalk"]=0.25,
		["CUST/Master Reset"]=true,
		["CUST/Default Preset Version"]=1
	},
	["005-Oil"]={
		["CUST/Author"]="Meetric",
		["VISL/Color"]={0, 0, 0, 255},
		["PHYS/Cohesion"]=0,
		["PHYS/Adhesion"]=0,
		["PHYS/Viscosity"]=0,
		["PHYS/Surface Tension"]=0,
		["CUST/Master Reset"]=true,
		["CUST/Default Preset Version"]=1
	},
	["006-Goop"]={
		["CUST/Author"]="Meetric",
		["VISL/Color"]={170, 240, 140, 50},
		["PHYS/Cohesion"]=0.1,
		["PHYS/Adhesion"]=0.1,
		["PHYS/Viscosity"]=10,
		["PHYS/Surface Tension"]=0.25,
		["INTC/MultiplyWalk"]=0.25,
		["CUST/Master Reset"]=true,
		["CUST/Default Preset Version"]=1
	},
	["007-Portal Gel (Blue)"]={
		["CUST/Author"]="Meetric",
		["VISL/Color"]={0, 127, 255, 255},
		["PHYS/Cohesion"]=0.1,
		["PHYS/Adhesion"]=0.1,
		["PHYS/Viscosity"]=2,
		["PHYS/Surface Tension"]=0.1,
		["PHYS/Fluid Rest Distance"] = 0.55,
		["INTC/MultiplyJump"]=2,
		["CUST/Master Reset"]=true,
		["CUST/Default Preset Version"]=1
	},
	["008-Portal Gel (Orange)"]={
		["CUST/Author"]="Meetric",
		["VISL/Color"]={255, 127, 0, 255},
		["PHYS/Cohesion"]=0.1,
		["PHYS/Adhesion"]=0.1,
		["PHYS/Viscosity"]=2,
		["PHYS/Surface Tension"]=0.1,
		["PHYS/Fluid Rest Distance"] = 0.55,
		["INTC/MultiplyWalk"]=2,
		["CUST/Master Reset"]=true,
		["CUST/Default Preset Version"]=1
	}
}

local presets
if file.Exists("DATA", "gwater2/presets.txt") then
    presets = util.JSONToTable(file.Read("gwater2/presets.txt", "DATA"))
else
    presets = default_presets
end

function gwater2.options.detect_preset_type(preset)
	if util.JSONToTable(preset) ~= nil then
		return "JSON"
	end
	if util.Decompress(util.Base64Decode(preset)) ~= "" and util.Decompress(util.Base64Decode(preset)) ~= nil then
		if pcall(function() util.JSONToTable(util.Decompress(util.Base64Decode(preset))) end) then
			return "B64-PI"
		else
			return nil
		end
	end


	local preset_parts = preset:Split(',')

	if preset_parts[2] == '' and preset_parts[3] ~= nil then
		if preset_parts[4] == '' and preset_parts[5] ~= nil and preset_parts[5] ~= '' then
			return "Extension w/ Author"
		end
		if preset_parts[4] ~= nil then
			return nil
		end
		return "Extension"
	end
	if preset_parts[2] ~= '' and preset_parts[2] ~= nil then
		if preset_parts[3] ~= nil then
			return nil
		end
		return "CustomPresets"
	end
	return nil
end

function gwater2.options.read_preset(preset)
	local type = gwater2.options.detect_preset_type(preset)
	if type == "JSON" then
		local p = util.JSONToTable(preset)
		for k,v in pairs(p) do
			return {k, v}
		end
	end
	if type == "B64-PI" then
		local p = util.Decompress(util.Base64Decode(preset))
		local pd = p:Split("\0")
		local name, data, author = pd[1], pd[2], pd[3]
		local prst = {}
		for _,v in pairs(data:Split("\2")) do
			local n = v:Split("\1")[1]
			prst[n] = v:Split("\1")[2]
			if v:Split("\1")[3] == "j" then
				prst[n] = util.JSONToTable(prst[n])
			end
			if v:Split("\1")[3] == "n" then
				prst[n] = tonumber(prst[n])
			end
			if v:Split("\1")[3] == "b" then
				prst[n] = not (prst[n] == '0')
			end
		end
		prst["CUST/Author"] = prst["CUST/Author"] or LocalPlayer():Name()
		return {name, prst}
	end
    -- TODO: read extension, extension w/ author and custompresets preset formats
	return {"", {}}
end

local button_functions -- wtf lua
button_functions = {
    paint = function(self, w, h)
        if self:IsHovered() and not self.washovered then
            self.washovered = true
            _util.emit_sound("rollover")
        elseif not self:IsHovered() and self.washovered then
            self.washovered = false
        end
        if self:IsHovered() and not self:IsDown() then
            self:SetColor(Color(0, 127, 255, 255))
        elseif self:IsDown() then
            self:SetColor(Color(63, 190, 255, 255))
        else
            self:SetColor(Color(255, 255, 255))
        end
        styling.draw_main_background(0, 0, w, h)
    end,
    apply_preset = function(self)

    end,
    save_extended = function(self)
        local params = self:GetParent():GetParent():GetParent().params

        local frame = styling.create_blocking_frame()
        frame:SetSize(ScrW()/2, ScrH()/2)
        frame:Center()
        local label = frame:Add("DLabel")
        label:Dock(TOP)
        label:SetText(_util.get_localised("Presets.save.preset_name"))
        label:SetFont("GWater2Title")
        local textarea = frame:Add("DTextEntry")
        textarea:Dock(TOP)
        textarea:SetFont("GWater2Param")
        textarea:SetValue("PresetName")
        local label = frame:Add("DLabel")
        label:Dock(TOP)
        label:SetText(_util.get_localised("Presets.save.include_params"))
        label:SetFont("GWater2Title")
        local panel = frame:Add("DScrollPanel")
        panel:Dock(FILL)
        panel.Paint = nil

        local preset = {}

        local do_overwrite = panel:Add("DCheckBoxLabel")
        do_overwrite:SetText("Master Reset (reset all unchecked parameters to default)")
        do_overwrite:Dock(TOP)
        function do_overwrite:OnChange(val)
            if not val then preset['CUST/Master Reset'] = nil return end
            preset['CUST/Master Reset'] = true
        end
        do_overwrite:SetValue(true)

        local _parameters = params._parameters
        local _visuals = params._visuals
        local _interactions = params._interactions

        local paramlist = {}
        for name,_ in pairs(_parameters) do paramlist[#paramlist+1] = "PHYS/"..name end
        for name,_ in pairs(_visuals) do paramlist[#paramlist+1] = "VISL/"..name end
        for name,_ in pairs(_interactions) do paramlist[#paramlist+1] = "INTC/"..name end
        local _checks = {}
        for k,v in pairs(paramlist) do
            local check = panel:Add("DCheckBoxLabel")
            _checks[#_checks + 1] = check
            local real = ""
            if v:sub(0, 4) == "VISL" then
                real = _visuals[v:sub(6)].label:GetText()
            elseif v:sub(0, 4) == "PHYS" then
                real = _parameters[v:sub(6)].label:GetText()
            elseif v:sub(0, 4) == "INTC" then
                real = _interactions[v:sub(6)].label:GetText()
            end
            check:SetText(v:sub(0, 4).."/"..real)
            check:Dock(TOP)
        end

        local qpanel = frame:Add("DPanel")
        qpanel:Dock(TOP)
        qpanel.Paint = nil

        local deselect_all = qpanel:Add("DButton")
        deselect_all:SetText("Deselect all")
        deselect_all:Dock(LEFT)
        deselect_all:SizeToContents()
        deselect_all.Paint = button_functions.paint
        function deselect_all:DoClick()
            for _,check in pairs(_checks) do
                check:SetValue(false)
            end
        end

        local select_visl = qpanel:Add("DButton")
        select_visl:SetText("Select all VISL")
        select_visl:Dock(LEFT)
        select_visl:SizeToContents()
        select_visl.Paint = button_functions.paint
        select_visl.section = "VISL"
        function select_visl:DoClick()
            for _,check in pairs(_checks) do
                if check:GetText():sub(0,4) ~= self.section then continue end
                check:SetValue(true)
            end
        end

        local select_phys = qpanel:Add("DButton")
        select_phys:SetText("Select all PHYS")
        select_phys:Dock(LEFT)
        select_phys:SizeToContents()
        select_phys.Paint = button_functions.paint
        select_visl.section = "PHYS"
        select_phys.DoClick = select_visl.DoClick

        local select_itrc = qpanel:Add("DButton")
        select_itrc:SetText("Select all INTC")
        select_itrc:Dock(LEFT)
        select_itrc:SizeToContents()
        select_itrc.Paint = button_functions.paint
        select_visl.section = "ITRC"
        select_itrc.DoClick = select_visl.DoClick

        _util.emit_sound("confirm")
    end,
    import = function(self)
        local local_presets = self:GetParent():GetParent():GetParent().presets

        local frame = styling.create_blocking_frame()
        frame:SetSize(ScrW()/2, ScrH()/2)
        frame:Center()
        local label = frame:Add("DLabel")
        label:Dock(TOP)
        label:SetText(_util.get_localised("Presets.import.paste_here"))
        label:SetFont("GWater2Title")
        local textarea = frame:Add("DTextEntry")
        textarea:Dock(FILL)
        textarea:SetFont("GWater2Param")
        textarea:SetValue("")
        textarea:SetMultiline(true)
        textarea:SetVerticalScrollbarEnabled(true)
        textarea:SetWrap(true)

        local btnpanel = frame:Add("DPanel")
        btnpanel:Dock(BOTTOM)
        btnpanel.Paint = nil

        local label_detect = frame:Add("DLabel")
        label_detect:SetText("...")
        label_detect:Dock(BOTTOM)
        label_detect:SetTall(label_detect:GetTall()*2)
        label_detect:SetFont("GWater2Param")
        
        local confirm = vgui.Create("DButton", btnpanel)
        confirm:Dock(RIGHT)
        confirm:SetText("")
        confirm:SetSize(20, 20)
        confirm:SetImage("icon16/accept.png")
        confirm.Paint = nil
        function confirm:DoClick()
            local pd = gwater2.options.read_preset(textarea:GetValue())
            local name, preset = pd[1], pd[2]
            local m = 0
            for k,v in SortedPairs(presets) do m = tonumber(k:sub(1, 3)) end

            local selector = local_presets:Add("DButton")
            selector:SetText(name.." ("..(preset["CUST/Author"] or _util.get_localised("Presets.author_unknown"))..")")
            selector:Dock(TOP)
            selector.Paint = button_functions.paint
            selector.preset = preset
            selector.DoClick = button_functions.apply_preset
            local_presets:SetTall(local_presets:GetTall()+25)

            presets[string.format("%03d-%s", m+1, name)] = preset
            file.Write("gwater2/presets.txt", util.TableToJSON(presets))
            frame:Close()
            _util.emit_sound("select_ok")
        end

        function textarea:OnChange()
            local type = gwater2.options.detect_preset_type(textarea:GetValue())
            if type == nil then
                confirm:SetEnabled(false)
                return label_detect:SetText(_util.get_localised("Presets.import.bad_data"))
            end
            confirm:SetEnabled(true)
            label_detect:SetText(_util.get_localised("Presets.import.detected", type))
        end

        local deny = vgui.Create("DButton", btnpanel)
        deny:Dock(LEFT)
        deny:SetText("")
        deny:SetSize(20, 20)
        deny:SetImage("icon16/cross.png")
        deny.Paint = nil
        function deny:DoClick()
            frame:Close()
            _util.emit_sound("select_deny")
        end

        _util.emit_sound("confirm")
    end
}

local function presets_tab(tabs, params)
    local tab = vgui.Create("DPanel", tabs)
	tab.Paint = nil
	tabs:AddSheet(_util.get_localised("Presets.title"), tab, "icon16/images.png").Tab.realname = "Presets"
	tab = tab:Add("DScrollPanel")
	tab:Dock(FILL)
	--tab.Paint = function(s, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(255, 255, 255)) end
	styling.define_scrollbar(tab:GetVBar())

	local _ = tab:Add("DLabel") _:SetText(" ") _:SetFont("GWater2Title") _:Dock(TOP) _:SizeToContents()
	function _:Paint(w, h)
		draw.DrawText(_util.get_localised("Presets.titletext"), "GWater2Title", 6, 6, Color(0, 0, 0), TEXT_ALIGN_LEFT)
		draw.DrawText(_util.get_localised("Presets.titletext"), "GWater2Title", 5, 5, Color(187, 245, 255), TEXT_ALIGN_LEFT)
	end

	if not file.Exists("gwater2/presets.txt", "DATA") then file.Write("gwater2/presets.txt", util.TableToJSON(default_presets)) end
	local succ, presets = pcall(function() return util.JSONToTable(file.Read("gwater2/presets.txt")) end)
	if not succ then
		tab.help_text = tabs.help_text
		_util.make_title_label(tab, _util.get_localised("Presets.critical_fail"))
		return
	end
    local presets_control = tab:Add("DPanel")
    presets_control.Paint = nil
	presets_control:Dock(TOP)
    presets_control:DockPadding(0, 5, 5, 0)

    local local_presets = tab:Add("DPanel")
    local_presets.Paint = nil
	local_presets:Dock(TOP)
    local_presets:DockPadding(0, 5, 5, 0)

    tab.presets = local_presets
    tab.params = params

    local save_button = presets_control:Add("DButton")
    save_button:SetText("Save")
    save_button:Dock(LEFT)
    save_button.Paint = button_functions.paint
    save_button.DoClick = button_functions.save_extended

    local import_button = presets_control:Add("DButton")
    import_button:SetText("Import")
    import_button:Dock(RIGHT)
    import_button.Paint = button_functions.paint
    import_button.DoClick = button_functions.import

    local_presets:SetTall(0)
    for name,preset in pairs(presets) do
        local selector = local_presets:Add("DButton")
        selector:SetText(string.sub(name, 5).." ("..(preset["CUST/Author"] or _util.get_localised("Presets.author_unknown"))..")")
        selector:Dock(TOP)
        selector.Paint = button_functions.paint
        selector.preset = preset
        selector.DoClick = button_functions.apply_preset
        local_presets:SetTall(local_presets:GetTall()+25)
    end
    local_presets:SetTall(local_presets:GetTall()-25)
end

return {presets_tab=presets_tab}