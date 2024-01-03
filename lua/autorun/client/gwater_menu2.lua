AddCSLuaFile()

if SERVER then return end

require("gwater2")

local version = "0.1a"
local options = {
	solver = FlexSolver(1000),
	tab = CreateClientConVar("gwater2_tab0", "1", true),
	blur_passes = CreateClientConVar("gwater2_blur_passes", "3", true),
	cheap = CreateClientConVar("gwater2_cheap", "1", true),
	absorption = CreateClientConVar("gwater2_absorption", "1", true),
	menu_key = CreateClientConVar("gwater2_menukey", KEY_G, true),
	parameter_tab_header = "Parameter Tab",
	parameter_tab_text = "This tab is where you can change how the water interacts with itself and the environment.\n\nHover over a parameter to reveal its functionality.\n\nScroll down for presets!",
	about_tab_header = "About Tab",
	about_tab_text = "On each tab, this area will contain useful information.\n\nFor example:\nClicking anywhere outside the menu, or re-pressing the menu button will close it.\n\nMake sure to read this area!",
	performance_tab_header = "Performance Tab",
	performance_tab_text = "This tab has options which can help and alter your performance.\n\nEach option is colored between green and red to indicate its performance hit.\n\nAll parameters directly impact the GPU.",
	
	Cohesion = {text = "Controls how well particles hold together.\n\nHigher values make the fluid more solid/rigid, while lower values make it more fluid and loose."},
	Adhesion = {text = "Controls how well particles stick to surfaces.\n\nNote that this specific parameter doesn't reflect changes in the preview very well and may need to be viewed externally."},
	Gravity = {text = "Controls how strongly fluid is pulled down. This value is measured in meters per second.\n\nNote that the default source gravity is -15.48 which is NOT the same as Earths gravity of -9.81."},
	Viscosity = {text = "Controls how much particles resist movement.\n\nHigher values look more like honey or syrup, while lower values look like water or oil.\n\nUsually bundled with cohesion."},
	Radius = {text = "Controls the size of each particle. In the preview it is clamped to 15 to avoid weirdness.\n\nRadius is measured in source units (aka inches) and is the same for all particles."},
	Color = {text = "Controls what color the fluid is.\n\nUnlike all other parameters, color is separate, and per-particle.\n\nThe alpha channel controls the amount of color absorbsion."},
	Iterations = {text = "Controls how many times the physics solver attempts to converge to a solution.\n\nLight performance impact."},
	Substeps = {text = "Controls the number of physics steps done per tick.\n\nParameters may not be properly tuned for different substeps!\n\nMedium-High performance impact."},
	["Blur Passes"] = {text = "Controls the number of blur passes done per frame. More passes creates a smoother water surface. Zero passes will do no blurring.\n\nMedium performance impact."},
	["Depth Fix"] = {text = "Changes particles to look spherical instead of flat, causes shader redraw and is pretty expensive.\n\n(Set blur passes to 0 to see the effect better!)\n\nHigh performance impact."},
	["Absorption"] = {text = "Enables absorption of light over distance inside of fluid\n\n(aka. more depth = darker color).\n\nMedium-High performance impact."}
}

options.solver:SetParameter("gravity", 15.24)	-- flip gravity because y axis positive is down
options.solver:SetParameter("timescale", 10)	-- pixel space is small, so we need to speed up the simulation
options.solver:SetParameter("static_friction", 0)
options.solver:SetParameter("dynamic_friction", 0)

-- designs for tabs and frames
local function draw_tabs(self, w, h)
	draw.RoundedBox(0, 2, 0, w - 4, 20, Color( 27, 27, 27, 255))
	if h == 20 then
		surface.SetDrawColor(0, 0, 255)
	else
		--surface.SetDrawColor(91, 0, 196)
		surface.SetDrawColor(255, 255, 255)
	end
	surface.DrawOutlinedRect(2, 0, w - 4, 21, 1)
end

surface.CreateFont("GWater2Param", {
    font = "Space Mono", 
    extended = false,
    size = 20,
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = false,
    additive = false,
    outline = false,
})

surface.CreateFont("GWater2Title", {
    font = "coolvetica", 
    extended = false,
    size = 24,
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = false,
    additive = false,
    outline = false,
})

-- Smooth scrollbar (code from Spanky)
local GFScrollPanel = {}
AccessorFunc(GFScrollPanel, "scrolldistance", "ScrollDistance", FORCE_NUMBER)
function GFScrollPanel:Init()
    self:SetScrollDistance(32)
    local scrollPanel = self

    local vbar = self:GetVBar()
    function vbar:OnMouseWheeled( dlta )
        if not self:IsVisible() then return false end
        -- We return true if the scrollbar changed.
        -- If it didn't, we feed the mousehweeling to the parent panel
        if self.CurrentScroll == nil then self.CurrentScroll = self:GetScroll() end
        self.CurrentScroll = math.Clamp(self.CurrentScroll + (dlta * -scrollPanel:GetScrollDistance()), 0, self.CanvasSize)
        self:AnimateTo(self.CurrentScroll, 0.1, 0, 0.5)
        return self:AddScroll( dlta * -2 )
    end
    function vbar:OnMouseReleased()
        self.CurrentScroll = self:GetScroll()

        self.Dragging = false
        self.DraggingCanvas = nil
        self:MouseCapture( false )
    
        self.btnGrip.Depressed = false
    end
end
vgui.Register("GF_ScrollPanel", GFScrollPanel, "DScrollPanel")

local function set_parameter(option, val)
	if gwater2[option] then 
		gwater2[option] = val 
		return
	end

	gwater2.solver:SetParameter(option, val)

	if option == "gravity" then val = -val end	-- hack hack hack! y coordinate is considered down in screenspace!
	if option == "radius" then 					-- hack hack hack! radius needs to edit multiple parameters!
		gwater2.solver:SetParameter("surface_tension", 0.01 / val^4)	-- not sure why this is a power of 4. might be proportional to volume
		gwater2.solver:SetParameter("fluid_rest_distance", val * 0.7)
		gwater2.solver:SetParameter("collision_distance", val * 0.5)
		gwater2.solver:SetParameter("anisotropy_max", 1.5 / val)
		
		if val > 15 then val = 15 end	-- explody
		options.solver:SetParameter("surface_tension", 0.01 / val^4)
		options.solver:SetParameter("fluid_rest_distance", val * 0.7)
		options.solver:SetParameter("collision_distance", val * 0.5)
	end
	options.solver:SetParameter(option, val)
end

-- some helper functions
local function create_slider(self, text, min, max, decimals, dock)  

	local option = string.lower(text)
	option = string.gsub(option, " ", "_")
	local param = gwater2[option] or gwater2.solver:GetParameter(option)
	if options[text] then 
		options[text].default = options[text].default or param
	else
		print("Undefined parameter '" .. text .. "'!") 
	end
	
	local label = vgui.Create("DLabel", self)
	label:SetPos(10, dock)
	label:SetSize(200, 20)
	label:SetText(text)
	label:SetColor(Color(255, 255, 255))
	label:SetFont("GWater2Param")

	local slider = vgui.Create("DNumSlider", self)
	slider:SetPos(-40, dock)
	slider:SetSize(400, 20)
	slider:SetMinMax(min, max)
	slider:SetValue(param)
	slider:SetDecimals(decimals)
	
	function slider:OnValueChanged(val)
		if decimals == 0 and val != math.Round(val, decimals) then 
			self:SetValue(math.Round(val, decimals))
			return
		end

		set_parameter(option, val)
	end

	local button = vgui.Create("DButton", self)
	button:SetPos(355, dock)
	button:SetSize(20, 20)
	button:SetText("")
	button:SetImage("icon16/arrow_refresh.png")
	button.Paint = nil

	function button:DoClick()
		slider:SetValue(options[text].default)
		surface.PlaySound("buttons/button15.wav")
	end

	return label, slider
end

local function create_label(self, text, subtext, dock, size)
	local label = vgui.Create("DLabel", self)
	label:SetPos(0, dock)
	label:SetSize(383, size or 320)
	label:SetText("")

	function label:Paint(w, h)
		surface.SetDrawColor(0, 0, 0, 100)
		surface.DrawRect(0, 0, w, h)

		surface.SetDrawColor(255, 255, 255)
		surface.DrawOutlinedRect(0, 0, w, h)
		
		draw.DrawText(text, "GWater2Title", 8, 5, Color(0, 0, 0), TEXT_ALIGN_LEFT)
		draw.DrawText(text, "GWater2Title", 7, 4, Color(187, 245, 255), TEXT_ALIGN_LEFT)

		draw.DrawText(subtext, "DermaDefault", 7, 25, Color(187, 245, 255), TEXT_ALIGN_LEFT)
	end
	return label
end

-- color picker
local function copy_color(c) return Color(c.r, c.g, c.b, c.a) end
local function create_picker(self, text, dock, size)
	local label = vgui.Create("DLabel", self)
	label:SetPos(10, dock)
	label:SetSize(100, 100)
	label:SetFont("GWater2Param")
	label:SetText(text)
	label:SetColor(Color(255, 255, 255))
	label:SetContentAlignment(7)

	if options[text] then 
		options[text].default = options[text].default or copy_color(gwater2.color)	-- copy, dont reference
	else
		print("Undefined parameter '" .. text .. "'!") 
	end

	local mixer = vgui.Create("DColorMixer", self)
	mixer:SetPos(130, dock + 5)
	mixer:SetSize(210, 100)	
	mixer:SetPalette(false)  	
	mixer:SetLabel()
	mixer:SetAlphaBar(true)
	mixer:SetWangs(false)
	mixer:SetColor(gwater2.color) 
	function mixer:ValueChanged(col)
		gwater2.color = copy_color(col)	-- color returned by ValueChanged doesnt have any metatables
	end

	local button = vgui.Create("DButton", self)
	button:SetPos(355, dock)
	button:SetSize(20, 20)
	button:SetText("")
	button:SetImage("icon16/arrow_refresh.png")
	button.Paint = nil
	function button:DoClick()
		local copy = copy_color(options[text].default)
		mixer:SetColor(copy)
		surface.PlaySound("buttons/button15.wav")
	end

	return label, mixer
end

local function create_explanation(parent)
	local explanation = vgui.Create("DLabel", parent)
	explanation:SetTextInset(5, 30)
	explanation:SetWrap(true)
	explanation:SetColor(Color(255, 255, 255))
	explanation:SetContentAlignment(7)	-- shove text in top left corner
	explanation:SetFont("GWater2Param")

	return explanation
end

--------------------------------------------------------

local mainFrame = nil
local just_closed = false
concommand.Add("gwater2_menu", function()
	local average_fps = 1 / 60
	local particle_material = CreateMaterial("gwater2_menu_material", "UnlitGeneric", {
		["$basetexture"] = "vgui/circle",
		["$vertexcolor"] = 1,
		["$vertexalpha"] = 1,
		["$ignorez"] = 1
	})

    -- start creating visual design
    mainFrame = vgui.Create("DFrame")
    mainFrame:SetSize(800, 400)
    mainFrame:SetPos(ScrW() / 2 - 400, ScrH() / 2 - 200)
	mainFrame:SetTitle("gwater2 (v" .. version .. ")")
    mainFrame:MakePopup()
	mainFrame:SetScreenLock(true)
	function mainFrame:Paint(w, h)
		-- dark background around 2d water sim
		surface.SetDrawColor(0, 0, 0, 230)
		surface.DrawRect(0, 0, w, 25)
		surface.SetDrawColor(0, 0, 0, 100)
		surface.DrawRect(0, 25, w, h - 25)

		-- 2d simulation
		local x, y = mainFrame:LocalToScreen()
		options.solver:InitBounds(Vector(x, 0, y + 25), Vector(x + 192, options.solver:GetParameter("radius"), y + 390))
		options.solver:Tick(math.max(average_fps, 1 / 9999))
		options.solver:AddCube(Vector(x + 60, 0, y + 50), Vector(0, 0, 50), Vector(4, 1, 1), options.solver:GetParameter("radius") * 0.7, color_white)
		
		surface.SetMaterial(particle_material)
		local radius = options.solver:GetParameter("radius")
		local function exp(v) return Vector(math.exp(v[1]), math.exp(v[2]), math.exp(v[3])) end
		options.solver:RenderParticles(function(pos)
			local depth = math.max((pos[3] - y) / 390, 0) * 20
			local is_translucent = gwater2.color.a < 255
			local absorption = is_translucent and exp((Vector(1, 1, 1) - gwater2.color:ToVector()) * -1 * gwater2.color.a / 255 * depth) or gwater2.color:ToVector()
			surface.SetDrawColor(absorption[1] * 255, absorption[2] * 255, absorption[3] * 255, 255)
			surface.DrawTexturedRect(pos[1] - x, pos[3] - y, radius, radius)
		end)
		
		average_fps = average_fps + (FrameTime() - average_fps) * 0.01

		-- main outline
		surface.SetDrawColor(255, 255, 255)
		surface.DrawOutlinedRect(0, 0, w, h)
		surface.DrawOutlinedRect(5, 30, 192, h - 35)

		draw.RoundedBox(5, 36, 35, 125, 30, Color(10, 10, 10, 230))
		draw.DrawText("Fluid Preview", "GWater2Title", 100, 40, Color(255, 255, 255), TEXT_ALIGN_CENTER)
	end

	-- close menu if menu button is pressed
	function mainFrame:OnKeyCodePressed(key)
		if key == options.menu_key:GetInt() then
			mainFrame:Remove()
			just_closed = true
		end
	end

	-- menu "center" button
	local button = vgui.Create("DButton", mainFrame)
	button:SetPos(680, 3)
	button:SetSize(20, 20)
	button:SetText("")
	button:SetImage("icon16/anchor.png")
	button.Paint = nil
	function button:DoClick()
		mainFrame:SetPos(ScrW() / 2 - 400, ScrH() / 2 - 200)
		surface.PlaySound("buttons/button15.wav")
	end

	input.SetCursorPos(ScrW() / 2 - 80, ScrH() / 2 - 188)

	-- 2d simulation
	options.solver:Reset()

    -- the tabs
    local tabsFrame = vgui.Create("DPanel", mainFrame)
    tabsFrame:SetSize(600, 365)
    tabsFrame:SetPos(200, 30)
    tabsFrame.Paint = nil

    -- the parameter tab, contains settings for the water
    local function parameterTab(tabs)
        local scrollPanel = vgui.Create("GF_ScrollPanel", tabs)
        local scrollEditTab = tabs:AddSheet("Fluid Parameters", scrollPanel, "icon16/cog.png").Tab
		scrollEditTab.Paint = draw_tabs

		-- explanation area 
		local explanation = create_explanation(scrollPanel)
		explanation:SetSize(175, 320)
		explanation:SetPos(390, 0)
		explanation:SetText(options.parameter_tab_text)
		local explanation_header = options.parameter_tab_header
		function explanation:Paint(w, h)
			self:SetPos(390, scrollPanel:GetVBar():GetScroll())
			surface.SetDrawColor(0, 0, 0, 100)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(255, 255, 255)
			surface.DrawOutlinedRect(0, 0, w, h)
			draw.DrawText(explanation_header, "GWater2Title", 6, 6, Color(0, 0, 0), TEXT_ALIGN_LEFT)
			draw.DrawText(explanation_header, "GWater2Title", 5, 5, Color(187, 245, 255), TEXT_ALIGN_LEFT)
		end

		-- parameters
		local labels = {}
		local sliders = {}
		create_label(scrollPanel, "Fun Parameters", "These parameters directly influence physics and visuals.", 0)
		labels[1], sliders["Cohesion"] = create_slider(scrollPanel, "Cohesion", 0, 2, 3, 50)
		labels[2], sliders["Adhesion"] = create_slider(scrollPanel, "Adhesion", 0, 0.2, 3, 80)
		labels[3], sliders["Gravity"] = create_slider(scrollPanel, "Gravity", -30.48, 30.48, 2, 110)
		labels[4], sliders["Viscosity"] = create_slider(scrollPanel, "Viscosity", 0, 10, 2, 140)
		labels[5], sliders["Radius"] = create_slider(scrollPanel, "Radius", 1, 100, 1, 170)
		labels[6], sliders["Color"] = create_picker(scrollPanel, "Color", 200, 200)

		create_label(scrollPanel, "Presets", "A dropdown menu of example presets.\nNote that the color of existing particles will not change, but their settings will!", 323)

		local presets = vgui.Create("DComboBox", scrollPanel)
        presets:SetPos(5, 383)
        presets:SetSize(200, 20)
        presets:SetText("Liquid Presets")
		presets:AddChoice("Acid", "Color:240 255 0 200\nCohesion:\nAdhesion:0.1\nViscosity:0")
		presets:AddChoice("Blood", "Color:240 0 0 250\nCohesion:0.01\nAdhesion:0.05\nViscosity:10")
		presets:AddChoice("Glue", "Color:230 230 230 255\nCohesion:0.03\nAdhesion:0.1\nViscosity:10")	-- yeah sure.. "glue"...
		presets:AddChoice("Lava", "Color:255 210 0 200\nCohesion:0.1\nAdhesion:0\nViscosity:10")
		presets:AddChoice("Oil", "Color:0 0 0 255\nCohesion:0\nAdhesion:0\nViscosity:0")
		presets:AddChoice("Water (Default)", "Color:\nCohesion:\nAdhesion:\nViscosity:")
		function presets:OnSelect(index, value, data)
			local params = string.Split(data, "\n")
			for _, param in ipairs(params) do
				local key, val = unpack(string.Split(param, ":"))
				if val == "" then val = tostring(options[key].default) end
				if key != "Color" then
					sliders[key]:SetValue(tonumber(val))
				else
					sliders[key]:SetColor(string.ToColor(val))
				end
			end
		end

		function scrollPanel:AnimationThink()
			local mousex, mousey = self:LocalCursorPos()
			local text_name = nil
			for _, label in pairs(labels) do
				local x, y = label:GetPos()
				y = y - self:GetVBar():GetScroll() - 1
				local w, h = 345, 22
				if y >= -20 and mousex > x and mousey > y and mousex < x + w and mousey < y + h then
					label:SetColor(Color(177, 255, 154))
					text_name = label:GetText()
				else
					label:SetColor(Color(255, 255, 255))
				end
			end

			if text_name then
				explanation:SetText(options[text_name].text)
				explanation_header = text_name
			else
				explanation:SetText(options.parameter_tab_text)
				explanation_header = options.parameter_tab_header
			end
		end

    end

    local function performanceTab(tabs)
        local scrollPanel = vgui.Create("DScrollPanel", tabs)
        local scrollEditTab = tabs:AddSheet("Performance Settings", scrollPanel, "icon16/application_xp_terminal.png").Tab
		scrollEditTab.Paint = draw_tabs

		-- explanation area 
		local explanation = create_explanation(scrollPanel)
		explanation:SetSize(175, 320)
		explanation:SetPos(390, 0)
		explanation:SetText(options.performance_tab_text)
		local explanation_header = options.performance_tab_header
		function explanation:Paint(w, h)
			self:SetPos(390, scrollPanel:GetVBar():GetScroll())
			surface.SetDrawColor(0, 0, 0, 100)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(255, 255, 255)
			surface.DrawOutlinedRect(0, 0, w, h)
			draw.DrawText(explanation_header, "GWater2Title", 6, 6, Color(0, 0, 0), TEXT_ALIGN_LEFT)
			draw.DrawText(explanation_header, "GWater2Title", 5, 5, Color(187, 245, 255), TEXT_ALIGN_LEFT)
		end

		local colors = {
			Color(127, 255, 0),
			Color(255, 127, 0),
			Color(255, 255, 0),
			Color(255, 0, 0),
			Color(255, 127, 0),
		}

		local labels = {}
		create_label(scrollPanel, "Performance Settings", "These settings directly influence performance", 0)
		labels[1] = create_slider(scrollPanel, "Iterations", 1, 10, 0, 50) 
		labels[2] = create_slider(scrollPanel, "Substeps", 1, 10, 0, 80) 
		--labels[3] = create_slider(scrollPanel, "Blur Passes", 0, 4, 0, 110) 

		-- blur passes slider is special since it uses a convar
		local label = vgui.Create("DLabel", scrollPanel)
		label:SetPos(10, 110)
		label:SetSize(200, 20)
		label:SetText("Blur Passes")
		label:SetColor(Color(255, 255, 255))
		label:SetFont("GWater2Param")
		labels[3] = label

		local slider = vgui.Create("DNumSlider", scrollPanel)
		slider:SetPos(-40, 110)
		slider:SetSize(400, 20)
		slider:SetMinMax(0, 4)
		slider:SetValue(options.blur_passes:GetInt())
		slider:SetDecimals(0)
		function slider:OnValueChanged(val)
			if val != math.Round(val, decimals) then 
				self:SetValue(math.Round(val, decimals))
				return
			end

			options.blur_passes:SetInt(val)
		end
		local button = vgui.Create("DButton", scrollPanel)
		button:SetPos(355, 110)
		button:SetSize(20, 20)
		button:SetText("")
		button:SetImage("icon16/arrow_refresh.png")
		button.Paint = nil
		function button:DoClick()
			slider:SetValue(3)
			surface.PlaySound("buttons/button15.wav")
		end
		
		-- Depth fix checkbox & label
		local label = vgui.Create("DLabel", scrollPanel)	
		label:SetPos(10, 140)
		label:SetSize(100, 100)
		label:SetFont("GWater2Param")
		label:SetText("Depth Fix")
		label:SetContentAlignment(7)
		labels[4] = label

		local box = vgui.Create("DCheckBox", scrollPanel)
		box:SetPos(132, 140)
		box:SetSize(20, 20)
		box:SetChecked(!options.cheap:GetBool())
		function box:OnChange(val)
			options.cheap:SetBool(!val)
			gwater2.material:SetInt("$cheap", val and 0 or 1)
		end

		-- Absorption checkbox & label
		local label = vgui.Create("DLabel", scrollPanel)	
		label:SetPos(10, 170)
		label:SetSize(100, 100)
		label:SetFont("GWater2Param")
		label:SetText("Absorption")
		label:SetContentAlignment(7)
		labels[5] = label

		local box = vgui.Create("DCheckBox", scrollPanel)
		box:SetPos(132, 170)
		box:SetSize(20, 20)
		box:SetChecked(options.absorption:GetBool())
		function box:OnChange(val)
			options.absorption:SetBool(val)
			gwater2.material:SetFloat("$alpha", val and 0.025 or 0)
		end

		function scrollPanel:AnimationThink()
			local mousex, mousey = self:LocalCursorPos()
			local text_name = nil
			for i, label in pairs(labels) do
				local x, y = label:GetPos()
				y = y - self:GetVBar():GetScroll() - 1
				local w, h = 345, 22
				if y >= -20 and mousex > x and mousey > y and mousex < x + w and mousey < y + h then
					label:SetColor(Color(colors[i].r + 127, colors[i].g + 127, colors[i].b + 127))
					text_name = label:GetText()
				else
					label:SetColor(colors[i])
				end
			end

			if text_name then
				explanation:SetText(options[text_name].text)
				explanation_header = text_name
			else
				explanation:SetText(options.performance_tab_text)
				explanation_header = options.performance_tab_header
			end
		end
	
    end

	local function aboutTab(tabs)
        local scrollPanel = vgui.Create("GF_ScrollPanel", tabs)
        local scrollEditTab = tabs:AddSheet("About", scrollPanel, "icon16/exclamation.png").Tab
		scrollEditTab.Paint = draw_tabs

		local label = vgui.Create("DLabel", scrollPanel)
		label:SetPos(0, 0)
		label:SetSize(383, 400)
		label:SetText([[
			Thank you for downloading gwater2 alpha! This menu is the interface that you will be using to control everything about gwater. So get used to it! :D

			This tab will contain updates and info about the addon when it is updated. 

			Since this is the first release, I don't have any changelogs or much to report, so feel free to play around with the settings!

			Changelog (v0.1a): 
			- Initial release
		]])
		label:SetColor(Color(255, 255, 255))
		label:SetTextInset(5, 30)
		label:SetWrap(true)
		label:SetContentAlignment(7)	-- shove text in top left corner
		label:SetFont("GWater2Param")
		function label:Paint(w, h)
			surface.SetDrawColor(0, 0, 0, 100)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(255, 255, 255)
			surface.DrawOutlinedRect(0, 0, w, h, 1)

			draw.DrawText("Welcome to gwater2! (v" .. version .. ")", "GWater2Title", 6, 6, Color(0, 0, 0), TEXT_ALIGN_LEFT)
			draw.DrawText("Welcome to gwater2! (v" .. version .. ")", "GWater2Title", 5, 5, Color(187, 245, 255), TEXT_ALIGN_LEFT)
		end

		-- explanation area 
		local explanation = create_explanation(scrollPanel)
		explanation:SetSize(175, 320)
		explanation:SetPos(390, 0)
		explanation:SetText(options.about_tab_text)
		function explanation:Paint(w, h)
			self:SetPos(390, scrollPanel:GetVBar():GetScroll())
			surface.SetDrawColor(0, 0, 0, 100)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(255, 255, 255)
			surface.DrawOutlinedRect(0, 0, w, h)
			draw.DrawText(options.about_tab_header, "GWater2Title", 6, 6, Color(0, 0, 0), TEXT_ALIGN_LEFT)
			draw.DrawText(options.about_tab_header, "GWater2Title", 5, 5, Color(187, 245, 255), TEXT_ALIGN_LEFT)
		end
    end
	

    local tabs = vgui.Create("DPropertySheet", tabsFrame)
	tabs:Dock(FILL)
	function tabs:Paint(w, h)
		surface.SetDrawColor(0, 0, 0, 100)
		surface.DrawRect(0, 20, w, h - 20)
		surface.SetDrawColor(255, 255, 255)
		surface.DrawOutlinedRect(0, 20, w, h - 20, 1)
	
		--surface.SetSize(192, 365)
		--SetPos(603, 30)
	end

	-- we need to save the index the tab is in, and when the menu is reopened it will set to that tab
	-- we cant use a reference to an actual panel because it wont be valid the next time the menu is opened... so we use the index instead
	function tabs:OnActiveTabChanged(old, new)
		for k, v in ipairs(self.Items) do
			if v.Tab == new then
				options.tab:SetInt(k)
			end
		end
	end

	aboutTab(tabs)
    parameterTab(tabs)
    performanceTab(tabs)

	tabs:SetActiveTab(tabs.Items[options.tab:GetInt()].Tab)
end)

hook.Add("GUIMousePressed", "gwater2_menuclose", function(mouse_code, aim_vector)
	if !IsValid(mainFrame) then return end

	local x, y = gui.MouseX(), gui.MouseY()
	local frame_x, frame_y = mainFrame:GetPos()
	if x < frame_x or x > frame_x + mainFrame:GetWide() or y < frame_y or y > frame_y + mainFrame:GetTall() then
		mainFrame:Remove()
	end

	options.mouse_pos = {x, y}
end)

hook.Add("PopulateToolMenu", "gwater2_menu", function()
    spawnmenu.AddToolMenuOption("Utilities", "gwater2", "gwater2_menu", "Menu Options", "", "", function(panel)
		panel:ClearControls()
		panel:Button("Open Menu", "gwater2_menu")
        panel:KeyBinder("Menu Key", "gwater2_menukey")
	end)
end)

hook.Add("PlayerButtonDown", "gwater2_menu", function(ply, key)
	if key == options.menu_key:GetInt() then
		if just_closed then 
			just_closed = false
		else
			RunConsoleCommand("gwater2_menu")
		end
	end
end)