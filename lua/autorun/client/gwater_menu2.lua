AddCSLuaFile()

if SERVER then return end

-- *Ehem*
-- BEHOLD. THE GWATER MENU CODE
-- THIS MY FRIEND.. IS THE SINGLE WORST PIECE OF CODE I HAVE EVER WRITTEN
-- DO NOT USE ANY OF THIS IN YOUR OWN CODE BECAUSE IT MIGHT SELF DESTRUCT
-- SOURCE VGUI IS ABSOLUTELY DOG DOODOO
-- THANK YOU FOR COMING TO MY TED TALK

local version = "0.2b"
local options = {
	solver = FlexSolver(1000),
	tab = CreateClientConVar("gwater2_tab"..version, "1", true),
	blur_passes = CreateClientConVar("gwater2_blur_passes", "3", true),
	absorption = CreateClientConVar("gwater2_absorption", "1", true),
	depth_fix = CreateClientConVar("gwater2_depth_fix", "0", true),
	menu_key = CreateClientConVar("gwater2_menukey", KEY_G, true),
	color = Color(209, 237, 255, 25),
	parameter_tab_header = "Parameter Tab",
	parameter_tab_text = "This tab is where you can change how the water interacts with itself and the environment.\n\nHover over a parameter to reveal its functionality.\n\nScroll down for presets!",
	about_tab_header = "About Tab",
	about_tab_text = "On each tab, this area will contain useful information.\n\nFor example:\nClicking anywhere outside the menu, or re-pressing the menu button will close it.\n\nMake sure to read this area!",
	performance_tab_header = "Performance Tab",
	performance_tab_text = "This tab has options which can help and alter your performance.\n\nEach option is colored between green and red to indicate its performance hit.\n\nAll parameters directly impact the GPU.",
	patron_tab_header = "Patron Tab",
	patron_tab_text = "This tab has a list of all my patrons.\n\nThe list is sorted from biggest donator to smallest\n\nIt will be updated routinely until release.",

	Cohesion = {text = "Controls how well particles hold together.\n\nHigher values make the fluid more solid/rigid, while lower values make it more fluid and loose."},
	Adhesion = {text = "Controls how well particles stick to surfaces.\n\nNote: This specific parameter doesn't reflect changes in the preview very well and may need to be viewed externally."},
	Gravity = {text = "Controls how strongly fluid is pulled down. This value is measured in meters per second.\n\nNote: The default source gravity is -15.24 which is NOT the same as Earths gravity of -9.81."},
	Viscosity = {text = "Controls how much particles resist movement.\n\nHigher values look more like honey or syrup, while lower values look like water or oil.\n\nUsually bundled with cohesion."},
	Radius = {text = "Controls the size of each particle. In the preview it is clamped to 15 to avoid weirdness.\n\nRadius is measured in source units (aka inches) and is the same for all particles."},
	Color = {text = "Controls what color the fluid is.\n\nUnlike all other parameters, color is separate, and per-particle.\n\nThe alpha channel controls the amount of color absorbsion."},
	Iterations = {text = "Controls how many times the physics solver attempts to converge to a solution.\n\nLight performance impact."},
	Substeps = {text = "Controls the number of physics steps done per tick.\n\nNote: Parameters may not be properly tuned for different substeps!\n\nMedium-High performance impact."},
	["Blur Passes"] = {text = "Controls the number of blur passes done per frame. More passes creates a smoother water surface. Zero passes will do no blurring.\n\nMedium performance impact."},
	["Absorption"] = {text = "Enables absorption of light over distance inside of fluid.\n\n(more depth = darker color)\n\nMedium-High performance impact."},
	["Depth Fix"] = {text = "Makes particles appear spherical instead of flat, creating a cleaner and smoother water surface.\n\nCauses shader overdraw.\n\nHigh performance impact."},
	["Particle Limit"] = {text = "USE THIS PARAMETER AT YOUR OWN RISK.\n\nChanges the limit of particles.\n\nNote that a higher limit will negatively impact performance even with the same number of particles spawned."},
}

-- garry, sincerely... fuck you
local volumetric = Material("gwater2/volumetric")
timer.Simple(0, function() volumetric:SetFloat("$alpha", options.absorption:GetBool() and 0.025 or 0) end)

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
		gwater2.solver:SetParameter("fluid_rest_distance", val * 0.65)
		gwater2.solver:SetParameter("collision_distance", val * 0.5)
		gwater2.solver:SetParameter("anisotropy_max", 1.5 / val)
		
		if val > 15 then val = 15 end	-- explody
		options.solver:SetParameter("surface_tension", 0.01 / val^4)
		options.solver:SetParameter("fluid_rest_distance", val * 0.65)
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
		options[text].default = options[text].default or copy_color(options.color)	-- copy, dont reference
	else
		print("Undefined parameter '" .. text .. "'!") 
	end

	local finalpass = Material("gwater2/finalpass")
	local mixer = vgui.Create("DColorMixer", self)
	mixer:SetPos(130, dock + 5)
	mixer:SetSize(210, 100)	
	mixer:SetPalette(false)  	
	mixer:SetLabel()
	mixer:SetAlphaBar(true)
	mixer:SetWangs(false)
	mixer:SetColor(options.color) 
	function mixer:ValueChanged(col)
		options.color = copy_color(col)	-- color returned by ValueChanged doesnt have any metatables
		finalpass:SetVector4D("$color2", col.r, col.g, col.b, col.a)
	end

	local button = vgui.Create("DButton", self)
	button:SetPos(355, dock)
	button:SetText("")
	button:SetSize(20, 20)
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
		options.solver:AddCube(Vector(x + 60, 0, y + 50), Vector(0, 0, 50), Vector(4, 1, 1), options.solver:GetParameter("radius") * 0.65, color_white)
		
		local radius = options.solver:GetParameter("radius")
		local function exp(v) return Vector(math.exp(v[1]), math.exp(v[2]), math.exp(v[3])) end
		local is_translucent = options.color.a < 255
		surface.SetMaterial(particle_material)
		options.solver:RenderParticles(function(pos)
			local depth = math.max((pos[3] - y) / 390, 0) * 20	-- ranges from 0 to 20 down
			local absorption = is_translucent and exp((options.color:ToVector() - Vector(1, 1, 1)) * options.color.a / 255 * depth) or options.color:ToVector()
			surface.SetDrawColor(absorption[1] * 255, absorption[2] * 255, absorption[3] * 255, 255)
			surface.DrawTexturedRect(pos[1] - x, pos[3] - y, radius, radius)
		end)
		
		average_fps = average_fps + (FrameTime() - average_fps) * 0.01

		-- main outline
		surface.SetDrawColor(255, 255, 255)
		surface.DrawOutlinedRect(0, 0, w, h)
		surface.DrawOutlinedRect(5, 30, 192, h - 35)

		draw.RoundedBox(5, 36, 35, 125, 30, Color(10, 10, 10, 230))
		draw.DrawText("Fluid Preview", "GWater2Title", 100, 40, color_white, TEXT_ALIGN_CENTER)
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
		mainFrame:Center()
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
    local function parameter_tab(tabs)
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

    local function performance_tab(tabs)
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
			Color(255, 127, 0),
			Color(255, 0, 0),
			Color(255, 0, 0),
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
		button:SetText("")
		button:SetSize(20, 20)
		button:SetImage("icon16/arrow_refresh.png")
		button.Paint = nil
		function button:DoClick()
			slider:SetValue(3)
			surface.PlaySound("buttons/button15.wav")
		end

		-- particle limit box
		local label = vgui.Create("DLabel", scrollPanel)
		label:SetPos(10, 140)
		label:SetSize(200, 20)
		label:SetText("Particle Limit")
		label:SetFont("GWater2Param")
		labels[6] = label

		local slider = vgui.Create("DNumSlider", scrollPanel)
		slider:SetPos(0, 140)
		slider:SetSize(330, 20)
		slider:SetMinMax(1, 1000000)
		slider:SetValue(gwater2.solver:GetMaxParticles())
		slider:SetDecimals(0)

		local button = vgui.Create("DButton", scrollPanel)
		button:SetPos(355, 140)
		button:SetText("")
		button:SetSize(20, 20)
		button:SetImage("icon16/arrow_refresh.png")
		button.Paint = nil
		function button:DoClick()
			slider:SetValue(100000)
			surface.PlaySound("buttons/button15.wav")
		end

		-- 'confirm' particle limit button. Creates another DFrame
		local button = vgui.Create("DButton", scrollPanel)
		button:SetPos(330, 140)
		button:SetText("")
		button:SetSize(20, 20)
		button:SetImage("icon16/accept.png")
		button.Paint = nil
		function button:DoClick()
			local x, y = mainFrame:GetPos() x = x + 200 y = y + 100
			local frame = vgui.Create("DFrame", mainFrame)
			frame:SetSize(400, 200)
			frame:SetPos(x, y)
			frame:SetTitle("gwater2 (v" .. version .. ")")
			frame:MakePopup()
			frame:SetBackgroundBlur(true)
			frame:SetScreenLock(true)
			function frame:Paint(w, h)
				-- Blur background
				render.UpdateScreenEffectTexture()
				render.BlurRenderTarget(render.GetScreenEffectTexture(), 5, 5, 1)
				render.SetRenderTarget()
				render.DrawScreenQuad()

				-- dark background around 2d water sim
				surface.SetDrawColor(0, 0, 0, 255)
				surface.DrawRect(0, 0, w, h)

				-- main outline
				surface.SetDrawColor(255, 255, 255)
				surface.DrawOutlinedRect(0, 0, w, h)
	
				draw.DrawText("You are about to change the limit to " .. slider:GetValue() .. ".\nAre you sure?", "GWater2Title", 200, 30, color_white, TEXT_ALIGN_CENTER)
				draw.DrawText([[This can be dangerous, because all particles must be allocated on the GPU.
DO NOT set the limit to a number higher then you think your computer can handle.
I DO NOT take responsiblity for any hardware damage this may cause]], "DermaDefault", 200, 90, color_white, TEXT_ALIGN_CENTER)
			
			end

			local confirm = vgui.Create("DButton", frame)
			confirm:SetPos(260, 150)
			confirm:SetText("")
			confirm:SetSize(20, 20)
			confirm:SetImage("icon16/accept.png")
			confirm.Paint = nil
			function confirm:DoClick()
				gwater2.solver:Destroy()
				gwater2.solver = FlexSolver(slider:GetValue())
				gwater2.meshes = {}
				gwater2.reset_solver(true)
				frame:Close()
				surface.PlaySound("buttons/button15.wav")
			end

			local deny = vgui.Create("DButton", frame)
			deny:SetPos(110, 150)
			deny:SetText("")
			deny:SetSize(20, 20)
			deny:SetImage("icon16/cross.png")
			deny.Paint = nil
			function deny:DoClick() 
				frame:Close()
				surface.PlaySound("buttons/button15.wav")
			end

			surface.PlaySound("buttons/button15.wav")
		end

		-- Absorption checkbox & label
		local label = vgui.Create("DLabel", scrollPanel)	
		label:SetPos(10, 170)
		label:SetSize(100, 100)
		label:SetFont("GWater2Param")
		label:SetText("Absorption")
		label:SetContentAlignment(7)
		labels[4] = label

		local box = vgui.Create("DCheckBox", scrollPanel)
		box:SetPos(132, 170)
		box:SetSize(20, 20)
		box:SetChecked(options.absorption:GetBool())
		local water_volumetric = Material("gwater2/volumetric")
		function box:OnChange(val)
			options.absorption:SetBool(val)
			water_volumetric:SetFloat("$alpha", val and 0.025 or 0)
		end

		-- Depth fix checkbox & label
		local label = vgui.Create("DLabel", scrollPanel)	
		label:SetPos(10, 200)
		label:SetSize(100, 100)
		label:SetFont("GWater2Param")
		label:SetText("Depth Fix")
		label:SetContentAlignment(7)
		labels[5] = label

		local box = vgui.Create("DCheckBox", scrollPanel)
		box:SetPos(132, 200)
		box:SetSize(20, 20)
		box:SetChecked(options.depth_fix:GetBool())
		local water_normals = Material("gwater2/normals")
		function box:OnChange(val)
			options.depth_fix:SetBool(val)
			water_normals:SetInt("$depthfix", val and 1 or 0)
		end

		-- light up & change explanation area
		function scrollPanel:AnimationThink()
			if !mainFrame:HasFocus() then return end
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

	local function about_tab(tabs)
        local scrollPanel = vgui.Create("GF_ScrollPanel", tabs)
        local scrollEditTab = tabs:AddSheet("About", scrollPanel, "icon16/exclamation.png").Tab
		scrollEditTab.Paint = draw_tabs

		local label = vgui.Create("DLabel", scrollPanel)
		label:SetPos(0, 0)
		label:SetSize(383, 800)
		label:SetText([[
			Thank you for downloading gwater2 beta! This menu is the interface that you will be using to control everything about gwater. So get used to it! :D

			Make sure to read 'Changelog (v0.2b)' to see what has been updated!

			Changelog (v0.2b):
			- Performance improvements (I noticed about a 30% increase in fps, though it may depend on your hardware)
			- Added Depth Fix option in performance tab
			- Added editable particle limit in performance tab
			- Added watergun box visual
			- Added compatibility for Hammer++ maps
			- Added patron tab in menu
			- Fixed door collision
			- Fixed the water anisotropy occasionally flickering
			- Made HDR lighting more consistent
			- Changed water surface estimation to grant smoother results
			- Lots of backend code changes
			- Internally start forcing MSAA to be disabled, as it breaks the water surface
			- Removed multi-color water, as it was inconsistent with other parameters

			Changelog (v0.1b): 
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

	local function patron_tab(tabs)
        local scrollPanel = vgui.Create("DScrollPanel", tabs)
        local scrollEditTab = tabs:AddSheet("Patrons", scrollPanel, "icon16/award_star_gold_3.png").Tab
		scrollEditTab.Paint = draw_tabs

		local patrons = file.Read("gwater2_patrons.lua", "LUA") or "<Failed to load patron data!>"
		local patrons_table = string.Split(patrons, "\n")

		local label = vgui.Create("DLabel", scrollPanel)
		label:SetPos(0, 0)
		label:SetSize(383, 10800)
		label:SetText([[
			Thanks to everyone here who supported me throughout the development of GWater2!
			
			All revenue generated from this project goes directly to my college fund. Thanks so much guys :)
			-----------------------------------------
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

			draw.DrawText("Patrons", "GWater2Title", 6, 6, Color(0, 0, 0), TEXT_ALIGN_LEFT)
			draw.DrawText("Patrons", "GWater2Title", 5, 5, Color(187, 245, 255), TEXT_ALIGN_LEFT)
			
			local patron_color = Color(171, 255, 163)
			for k, v in ipairs(patrons_table) do
				draw.DrawText(v, "GWater2Param", 6, 150 + k * 20, patron_color, TEXT_ALIGN_LEFT)
			end
		end

		-- explanation area 
		local explanation = create_explanation(scrollPanel)
		explanation:SetSize(175, 320)
		explanation:SetPos(390, 0)
		explanation:SetText(options.patron_tab_text)
		function explanation:Paint(w, h)
			self:SetPos(390, scrollPanel:GetVBar():GetScroll())
			surface.SetDrawColor(0, 0, 0, 100)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(255, 255, 255)
			surface.DrawOutlinedRect(0, 0, w, h)
			draw.DrawText(options.patron_tab_header, "GWater2Title", 6, 6, Color(0, 0, 0), TEXT_ALIGN_LEFT)
			draw.DrawText(options.patron_tab_header, "GWater2Title", 5, 5, Color(187, 245, 255), TEXT_ALIGN_LEFT)
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

	about_tab(tabs)
    parameter_tab(tabs)
    performance_tab(tabs)
	patron_tab(tabs)

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

-- TODO: Rewrite, this sucks
-- of course playerbutton down (the only hook which runs when a button is pressed) doesnt work in singleplayer.
local changed = false
hook.Add("Think", "gwater2_menu", function()
	if IsValid(LocalPlayer()) and LocalPlayer():IsTyping() then return end

	if input.IsKeyDown(options.menu_key:GetInt()) and !IsValid(mainFrame) then
		if changed then return end

		if just_closed then 
			just_closed = false
		else
			RunConsoleCommand("gwater2_menu")
		end

		changed = true
	else
		changed = false
	end
end)