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
    presets = util.JSONToTable(file.Read("gwater2/presets.txt"))
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

local function presets_tab()
    local tab = vgui.Create("DPanel", tabs)
	function tab:Paint() end
	tabs:AddSheet(_util.get_localised("Presets.title"), tab, "icon16/images.png").Tab.realname = "Presets"
	tab = tab:Add("DScrollPanel")
	tab:Dock(FILL)

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
end

return {presets_tab=presets_tab}