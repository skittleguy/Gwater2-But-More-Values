AddCSLuaFile()

if SERVER then return end

require("gwater2")

local version = "0.1a"
local options = {
	solver = FlexSolver(1000),
	color = Color(0, 127, 255),
	tab = 1,
	parameter_tab_header = "Parameter Tab",
	parameter_tab_text = "This tab is where you can change how the water interacts with itself and the environment.\n\nHover over a parameter to reveal its functionality, and changes to it will be reflected in the preview!",
	about_tab_header = "About Tab",
	about_tab_text = "On each tab, this area will contain useful information.\n\nMake sure to read it!",
	performance_tab_header = "Performance Tab",
	performance_tab_text = "This tab has options which can help and alter your performance.\n\nEach option is colored between green or red to indicate its performance hit.\n\nAll parameters directly impact the GPU.",
	
	Cohesion = {text = "Controls how well particles hold together.\n\nHigher values make the fluid more solid/rigid, while lower values make it more fluid and loose."},
	Adhesion = {text = "Controls how well particles stick to surfaces.\n\nNote that this specific parameter doesn't reflect changes in the preview very well and may need to be viewed externally."},
	Gravity = {text = "Controls how strongly fluid is pulled down. This value is measured in meters per second.\n\nNote that the default source gravity is -15.48 which is NOT the same as Earths gravity of -9.81."},
	Viscosity = {text = "Controls how much particles resist movement.\n\nHigher values look more like honey or syrup, while lower values look like water or oil.\n\nUsually bundled with cohesion."},
	Radius = {text = "Controls the size of each particle. In the preview it is clamped to 15 to avoid weirdness.\n\nRadius is measured in source units (aka inches) and is the same for all particles."},
	Color = {text = "Controls what color the fluid is.\n\nUnlike all other parameters, color is separate, and per-particle."},
	Iterations = {text = "Controls how many times the physics solver attempts to converge to a solution.\n\nLight performance impact."},
	Substeps = {text = "Controls the number of physics steps done per tick.\n\nParameters may not be properly tuned for different substeps!\n\nMedium-high performance impact."},
	["Blur Passes"] = {text = "Controls the number of blur passes done per frame. More passes creates a smoother water surface. Zero passes will do no blurring.\n\nMedium performance impact."},
	["Depth Fix"] = {text = "Changes the particle sprite to look spherical instead of flat. Causes GPU redraw and is very expensive.\n\nHigh performance impact."}
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
		if val != math.Round(val, decimals) then 
			self:SetValue(math.Round(val, decimals))
			return
		end

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
			
			if val > 15 then val = 15 end
			options.solver:SetParameter("surface_tension", 0.01 / val^4)
			options.solver:SetParameter("fluid_rest_distance", val * 0.7)
			options.solver:SetParameter("collision_distance", val * 0.5)
		end
		options.solver:SetParameter(option, val)
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
local function create_picker(self, text, dock, size)
	local label = vgui.Create("DLabel", self)
	label:SetPos(10, dock)
	label:SetSize(100, 100)
	label:SetFont("GWater2Param")
	label:SetText(text)
	label:SetColor(Color(255, 255, 255))
	label:SetContentAlignment(7)

	if options[text] then 
		options[text].default = options[text].default or gwater2.color
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
		gwater2.color = col
	end

	local button = vgui.Create("DButton", self)
	button:SetPos(355, dock)
	button:SetSize(20, 20)
	button:SetText("")
	button:SetImage("icon16/arrow_refresh.png")
	button.Paint = nil
	function button:DoClick()
		mixer:SetVector(options[text].default:ToVector())
		surface.PlaySound("buttons/button15.wav")
	end

	return label
end

concommand.Add("gwater2_menu2", function()
	local average_fps = 1 / 60
	local particle_material = CreateMaterial("gwater2_menu_material", "UnlitGeneric", {
		["$basetexture"] = "vgui/circle",
		["$vertexcolor"] = 1,
		["$vertexalpha"] = 1,
		["$ignorez"] = 1
	})

    // start creating visual design
    local mainFrame = vgui.Create("DFrame")
    mainFrame:SetSize(800, 400)
    mainFrame:Center()
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
		options.solver:AddCube(Vector(x + 60, 0, y + 50), Vector(0, 0, 70), Vector(4, 1, 1), 7, color_white)
		
		surface.SetMaterial(particle_material)
		local radius = options.solver:GetParameter("radius")
		options.solver:RenderParticles(function(pos)
			local depth = math.max((pos[3] - y - 100) / 100, 1.9)
			surface.SetDrawColor(gwater2.color.r / depth * 2, gwater2.color.g / depth * 2, gwater2.color.b / depth * 2, 255)
			surface.DrawTexturedRect(pos[1] - x, pos[3] - y, radius, radius)
		end)
		
		average_fps = average_fps + (FrameTime() - average_fps) * 0.01

		-- main outline
		surface.SetDrawColor(255, 255, 255)
		surface.DrawOutlinedRect(0, 0, w, h)
		surface.DrawOutlinedRect(5, 30, 192, h - 35)

		draw.RoundedBox(5, 18, 35, 165, 30, Color(10, 10, 10, 230))
		draw.DrawText("gwater2 Preview", "GWater2Title", 100, 40, Color(255, 255, 255), TEXT_ALIGN_CENTER)
	end

	-- I dont like the mouse originating in the center of the screen
	input.SetCursorPos(mainFrame:GetPos())

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
		local explanation = vgui.Create("DLabel", scrollPanel)
		explanation:SetSize(175, 320)
		explanation:SetPos(390, 0)
		explanation:SetTextInset(5, 30)
		explanation:SetWrap(true)
		explanation:SetColor(Color(255, 255, 255))
		explanation:SetContentAlignment(7)	-- shove text in top left corner
		explanation:SetText(options.parameter_tab_text)
		explanation:SetFont("GWater2Param")
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
		local sliders = {}
		create_label(scrollPanel, "Fun Parameters", "These parameters directly influence physics and visuals", 0)
		sliders[1] = create_slider(scrollPanel, "Cohesion", 0, 2, 3, 50)
		sliders[2] = create_slider(scrollPanel, "Adhesion", 0, 0.2, 2, 80)
		sliders[3] = create_slider(scrollPanel, "Gravity", -30.48, 30.48, 2, 110)
		sliders[4] = create_slider(scrollPanel, "Viscosity", 0, 10, 2, 140)
		sliders[5] = create_slider(scrollPanel, "Radius", 1, 100, 1, 170)
		sliders[6] = create_picker(scrollPanel, "Color", 200, 200)
		

		create_label(scrollPanel, "WIP!", "Ignore Me! This is a test label for future parameters\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\nsecret :)", 323)

		function scrollPanel:AnimationThink()
			local mousex, mousey = self:LocalCursorPos()
			local text_name = nil
			for _, label in pairs(sliders) do
				local x, y = label:GetPos()
				y = y - self:GetVBar():GetScroll()
				local w, h = 345, 20
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
		local explanation = vgui.Create("DLabel", scrollPanel)
		explanation:SetSize(175, 320)
		explanation:SetPos(390, 0)
		explanation:SetTextInset(5, 30)
		explanation:SetWrap(true)
		explanation:SetColor(Color(255, 255, 255))
		explanation:SetContentAlignment(7)	-- shove text in top left corner
		explanation:SetText(options.performance_tab_text)
		explanation:SetFont("GWater2Param")
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
		}

		local sliders = {}
		create_label(scrollPanel, "Performance Settings", "These settings directly influence performance", 0)
		sliders[1] = create_slider(scrollPanel, "Iterations", 1, 10, 0, 50) sliders[1]:SetColor(Color(127, 255, 0))
		sliders[2] = create_slider(scrollPanel, "Substeps", 1, 10, 0, 80) sliders[2]:SetColor(Color(255, 127, 0))
		sliders[3] = create_slider(scrollPanel, "Blur Passes", 0, 4, 0, 110) sliders[3]:SetColor(Color(255, 255, 0))
		
		local label = vgui.Create("DLabel", scrollPanel)
		label:SetPos(10, 140)
		label:SetSize(100, 100)
		label:SetFont("GWater2Param")
		label:SetText("Depth Fix")
		label:SetColor(Color(255, 50, 50))
		label:SetContentAlignment(7)
		sliders[4] = label

		local box = vgui.Create("DCheckBox", scrollPanel)
		box:SetPos(132, 140)
		box:SetSize(20, 20)

		function scrollPanel:AnimationThink()
			local mousex, mousey = self:LocalCursorPos()
			local text_name = nil
			for i, label in pairs(sliders) do
				local x, y = label:GetPos()
				y = y - self:GetVBar():GetScroll()
				local w, h = 345, 20
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

    local function saveTab(tabs)
        local scrollPanel = vgui.Create("DScrollPanel", tabs)
        local scrollEditTab = tabs:AddSheet("Presets", scrollPanel, "icon16/disk.png").Tab
		scrollEditTab.Paint = draw_tabs
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
		local explanation = vgui.Create("DLabel", scrollPanel)
		explanation:SetSize(175, 320)
		explanation:SetPos(390, 0)
		explanation:SetTextInset(5, 30)
		explanation:SetWrap(true)
		explanation:SetColor(Color(255, 255, 255))
		explanation:SetContentAlignment(7)	-- shove text in top left corner
		explanation:SetText(options.about_tab_text)
		explanation:SetFont("GWater2Param")
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
				options.tab = k
			end
		end
	end

	aboutTab(tabs)
    parameterTab(tabs)
    performanceTab(tabs)
    saveTab(tabs)

	tabs:SetActiveTab(tabs.Items[options.tab].Tab)
	
end)