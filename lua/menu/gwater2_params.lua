AddCSLuaFile()

if SERVER or not gwater2 then return end

if gwater2.__PARAMS__ then return gwater2.__PARAMS__ end

local styling = include("menu/gwater2_styling.lua")
local _util = include("menu/gwater2_util.lua")

local parameters = {
	["001-Physics Parameters"] = {
		["list"] = {
			["001-Adhesion"] = {
				min=0,
				max=0.2,
				decimals=3,
				type="scratch"
			},
			["002-Cohesion"] = {
				min=0,
				max=2,
				decimals=3,
				type="scratch"
			},
			["003-Radius"] = {
				min=1,
				max=100,
				decimals=1,
				type="scratch"
			},
			["004-Gravity"] = {
				min=-30.48,
				max=30.48,
				decimals=2,
				type="scratch"
			},
			["005-Viscosity"] = {
				min=0,
				max=20,
				decimals=2,
				type="scratch"
			},
			["006-Surface Tension"] = {
				min=0,
				max=1,
				decimals=2,
				type="scratch"
			},
			["007-Timescale"] = {
				min=0,
				max=2,
				decimals=2,
				type="scratch"
			}
		}
	},
	["002-Advanced Physics Parameters"] = {
		["list"] = {
			["002-Collision Distance"] = {
				min=0.1,
				max=1,
				decimals=2,
				type="scratch"
			},
			["001-Fluid Rest Distance"] = {
				min=0.55,
				max=0.85,
				decimals=2,
				type="scratch"
			},
			["003-Dynamic Friction"] = {
				min=0,
				max=1,
				decimals=2,
				type="scratch"
			},
			["004-Vorticity Confinement"] = {
				min=0,
				max=200,
				decimals=0,
				type="scratch"
			}
		}
	}
}
local visuals = {
	["001-Diffuse Threshold"] = {
		min=1,
		max=500,
		decimals=1,
		type="scratch"
	},
	["002-Diffuse Lifetime"] = {
		min=0,
		max=20,
		decimals=1,
		type="scratch"
	},
	["006-Color"] = {
		type="color",
		func=function(col)
			local finalpass = Material("gwater2/finalpass")
			local col = Color(col:Unpack())
			col.r = col.r * gwater2.options.parameters.color_value_multiplier.real
			col.g = col.g * gwater2.options.parameters.color_value_multiplier.real
			col.b = col.b * gwater2.options.parameters.color_value_multiplier.real
			--col.a = col.a * gwater2.options.parameters.color_value_multiplier.real
			finalpass:SetVector4D("$color2", col:Unpack())
			return true
		end
	},
	["007-Color Value Multiplier"] = {
		type="scratch",
		min=0,
		max=3,
		decimals=2,
		setup=function(scratch)
			scratch:SetValue(gwater2.options.parameters.color_value_multiplier.real)
		end
	},
	["008-Reflectance"] = {
		type="scratch",
		min=1,
		max=10,
		decimals=3,
		func=function(val)
			local finalpass = Material("gwater2/finalpass")
			finalpass:SetFloat("$ior", val)
			return true
		end,
		setup=function(slider)
			local finalpass = Material("gwater2/finalpass")
			slider:SetValue(finalpass:GetFloat("$ior"))
		end
	}
}

local performance = {
	["001-Iterations"] = {
		min=1,
		max=10,
		decimals=0,
		type="scratch",
		setup = function(slider)
			local label = slider:GetParent().label
			label.fancycolor = Color(250, 250, 0)
			label.fancycolor_hovered = Color(255, 255, 200)
			label:SetColor(label.fancycolor)
		end
	},
	["002-Substeps"] = {
		min=1,
		max=10,
		decimals=0,
		type="scratch",
		setup = function(slider)
			local label = slider:GetParent().label
			label.fancycolor = Color(255, 127, 0)
			label.fancycolor_hovered = Color(255, 200, 127)
			label:SetColor(label.fancycolor)
		end
	},
	["004-Blur Passes"] = {
		min=0,
		max=4,
		decimals=0,
		type="scratch",
		func=function(n)
			gwater2.options.blur_passes:SetInt(n)
		end,
		setup=function(slider)
			slider:SetValue(gwater2.options.blur_passes:GetInt())

			local label = slider:GetParent().label
			label.fancycolor = Color(127, 255, 0)
			label.fancycolor_hovered = Color(200, 255, 150)
			label:SetColor(label.fancycolor)
		end
	},
	["003-Particle Limit"] = {
		min=1,
		max=1000000,
		decimals=0,
		type="scratch",
		func=function(_) return true end,
		setup=function(slider)
			local label = slider:GetParent().label
			label.fancycolor = Color(255, 0, 0)
			label.fancycolor_hovered = Color(255, 127, 127)
			label:SetColor(label.fancycolor)

			slider:SetValue(gwater2.solver:GetMaxParticles())
			local panel = slider:GetParent()
			local button = panel:Add("DButton")
			button:Dock(RIGHT)
			button:SetText("")
			button:SetImage("icon16/accept.png")
			button:SetWide(button:GetTall())
			button.Paint = nil
			panel.button_apply = button
			function button:DoClick()
				local frame = styling.create_blocking_frame()
				frame:SetSize(600, 300)
				frame:Center()
				--function frame:Paint(w, h)
				--	styling.draw_main_background(0, 0, w, h)
				--end

				-- from testing it seems each particle is around 0.8kb so you could probably do some math to figure out the memory required and show it here
				local size_fmt = 0.8*slider:GetValue() * 1024
			    local u = ""
			    for _,unit in pairs({"", "K", "M", "G", "T", "P", "E", "Z"}) do
			    	u = unit
			    	if math.abs(size_fmt) < 1024.0 then
			    		break
			    	end
			    	size_fmt = size_fmt / 1024.0
			    end
			    size_fmt = math.Round(size_fmt)
			    size_fmt = size_fmt..u.."B"

				local label = frame:Add("DLabel")
				label:Dock(TOP)
				label:SetText(_util.get_localised("Performance.Particle Limit.title", math.floor(slider:GetValue()), size_fmt))
				label:SetFont("GWater2Title")
				label:SizeToContentsY()
				label.text = label:GetText()
				label:SetText("")
				function label:Paint() draw.DrawText(self.text, self:GetFont(), self:GetWide() / 2, 0, color_white, TEXT_ALIGN_CENTER) end

				local label2 = frame:Add("DLabel")
				label2:Dock(TOP)
				label2:SetText(_util.get_localised("Performance.Particle Limit.warning"))
				label2:SetFont("DermaDefault")
				label2:SizeToContentsY()
				label2.text = label2:GetText()
				label2:SetText("")
				function label2:Paint() draw.DrawText(self.text, self:GetFont(), self:GetWide() / 2, 0, color_white, TEXT_ALIGN_CENTER) end

				local confirm = vgui.Create("DButton", frame)
				confirm:SetPos(600 * (3/4) - 10, 170)
				confirm:SetText("")
				confirm:SetSize(20, 20)
				confirm:SetImage("icon16/accept.png")
				confirm.Paint = nil
				function confirm:DoClick() 
					gwater2.solver:Destroy()
					gwater2.solver = FlexSolver(slider:GetValue())
					gwater2.reset_solver(true)
					frame:Close()
					surface.PlaySound("gwater2/menu/select_ok.wav")
				end

				local deny = vgui.Create("DButton", frame)
				deny:SetPos(600 * (1/4) - 10, 170)
				deny:SetText("")
				deny:SetSize(20, 20)
				deny:SetImage("icon16/cross.png")
				deny.Paint = nil
				function deny:DoClick() 
					frame:Close()
					surface.PlaySound("gwater2/menu/select_deny.wav")
				end

				surface.PlaySound("gwater2/menu/confirm.wav")
			end
		end
	},
	["006-Absorption"] = {
		type="check",
		func=function(val)
			local water_volumetric = Material("gwater2/volumetric")
			gwater2.options.absorption:SetBool(val)
			water_volumetric:SetFloat("$alpha", val and 0.125 or 0)
			return true
		end,
		setup=function(check)
			local label = check:GetParent().label
			label.fancycolor = Color(255, 255, 0)
			label.fancycolor_hovered = Color(255, 255, 200)
			label:SetColor(label.fancycolor)

			check:SetValue(gwater2.options.absorption:GetBool())
		end
	},
	["007-Depth Fix"] = {
		type="check",
		func=function(val)
			local water_normals = Material("gwater2/normals")
			gwater2.options.depth_fix:SetBool(val)
			water_normals:SetInt("$depthfix", val and 1 or 0)
			return true
		end,
		setup=function(check)
			local label = check:GetParent().label
			label.fancycolor = Color(255, 127, 0)
			label.fancycolor_hovered = Color(255, 200, 127)
			label:SetColor(label.fancycolor)

			check:SetValue(gwater2.options.depth_fix:GetBool())
		end
	},
	["008-Player Collision"] = {
		type="check",
		func=function(val)
			gwater2.options.player_collision:SetBool(val)
			net.Start("GWATER2_REQUESTCOLLISION")
			net.WriteBool(val)
			net.SendToServer()
			return true
		end,
		setup=function(check)
			local label = check:GetParent().label
			label.fancycolor = Color(127, 255, 0)
			label.fancycolor_hovered = Color(200, 255, 127)
			label:SetColor(label.fancycolor)

			check:SetValue(gwater2.options.player_collision:GetBool())
		end
	},
	["009-Diffuse Enabled"] = {
		type="check",
		func=function(val)
			gwater2.solver:EnableDiffuse(val)
			gwater2.solver:ResetDiffuse()
			gwater2.options.diffuse_enabled:SetBool(val)
			return true
		end,
		setup=function(check)
			local label = check:GetParent().label
			label.fancycolor = Color(255, 255, 0)
			label.fancycolor_hovered = Color(255, 255, 200)
			label:SetColor(label.fancycolor)

			check:SetValue(gwater2.options.diffuse_enabled:GetBool())
		end
	},
}
local interaction = {
	["001-Reaction Force Parameters"] = {
		["list"] = {
			["001-Reaction Forces"] = {
				type="check",
				func = function(val)
					gwater2.solver:SetParameter("reaction_forces", val and 1 or 0)
					gwater2.ChangeParameter("reaction_forces", val and 1 or 0)
					return true
				end,
				setup=function(check)
					check:SetValue(gwater2.solver:GetParameter("reaction_forces") != 0)
				end
			},
			["002-Force Multiplier"] = {
				min=0.001,
				max=0.02,
				decimals=3,
				type="scratch"
			},
			["003-Force Buoyancy"] = {
				min=0,
				max=500,
				decimals=1,
				type="scratch"
			},
			["004-Force Dampening"] = {
				min=0,
				max=1,
				decimals=2,
				type="scratch"
			}
		}
	},
	["002-Swimming Parameters"] = {
		["list"] = {
			["001-Player Interaction"] = {
				type="check",
				func = function(val)
					gwater2["player_interaction"] = val
					gwater2.ChangeParameter("player_interaction", val)
					return true
				end,
				setup = function(check)
					check:SetValue(gwater2["player_interaction"])
				end
			},
			["002-SwimSpeed"] = {
				type="scratch",
				min=-20,
				max=100,
				decimals=0,
				func=function(val) end,
				setup=function(scratch) end
			},
			["003-SwimFriction"] = {
				type="scratch",
				min=0.75,
				max=1,
				decimals=3,
				func=function(val) end,
				setup=function(scratch) end
			},
			["004-SwimBuoyancy"] = {
				type="scratch",
				min=-2,
				max=2,
				decimals=2,
				func=function(val) end,
				setup=function(scratch) end
			},
			["005-MultiplyParticles"] = {
				type="scratch",
				min=0,
				max=200,
				decimals=0,
				func=function(val) end,
				setup=function(scratch) end
			},
			["008-MultiplyWalk"] = {
				type="scratch",
				min=0,
				max=2,
				decimals=2,
				func=function(val) end,
				setup=function(scratch) end
			},
			["009-MultiplyJump"] = {
				type="scratch",
				min=0,
				max=2,
				decimals=2,
				func=function(val) end,
				setup=function(scratch) end
			},
			["010-TouchDamage"] = {
				type="scratch",
				min=-10,
				max=10,
				decimals=0,
				func=function(val) end,
				setup=function(scratch) end
			},
		}
	}
}
local developer = {
	["001-Anisotropy Scale"] = {
		min=0,
		max=2,
		decimals=2,
		type="scratch"
	},
	["002-Anisotropy Min"] = {
		min=-0.1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["003-Anisotropy Max"] = {
		min=0,
		max=2,
		decimals=2,
		type="scratch"
	},
	["004-static_friction"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["006-particle_friction"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["007-free_surface_drag"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["008-drag"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["009-lift"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["010-solid_rest_distance"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["011-smoothing"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["012-dissipation"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["013-damping"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["014-particle_collision_margin"] = {
		min=-10,
		max=10,
		decimals=2,
		type="scratch"
	},
	["015-shape_collision_margin"] = {
		min=-10,
		max=10,
		decimals=2,
		type="scratch"
	},
	["016-sleep_threshold"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["017-shock_propagation"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["018-restitution"] = {
		min=-10,
		max=10,
		decimals=2,
		type="scratch"
	},
	["019-max_speed"] = {
		min=-1e5,
		max=1e5,
		decimals=2,
		type="scratch"
	},
	["020-max_acceleration"] = {
		min=-1e5,
		max=1e5,
		decimals=2,
		type="scratch"
	},
	["021-relaxation_factor"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["022-solid_pressure"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["023-buoyancy"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["024-diffuse_buoyancy"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["025-diffuse_drag"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
}

gwater2.__PARAMS__ = {parameters=parameters, visuals=visuals, performance=performance, interaction=interaction, developer=developer}
return gwater2.__PARAMS__