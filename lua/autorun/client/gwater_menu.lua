AddCSLuaFile()
--[[{name = "Physics Iterations", min = 1, value = 3, max = 10, advanced = true, integer = true,
    description = "Sets how accurate the simulation is. This helps with particles clipping through objects and other particles."
},]]
local gwaterParameters = {
    {name = "Gravity", min = -100, value = -9.81, max = 100,
        description = "Sets the gravity for the particles."
    },
    {name = "Radius", min = 0, value = 10, max = 1000,
        description = "Sets the radius of the particles."
    },
    {name = "Viscosity", min = 0, value = 0, max = 10,
        description = "Sets how thick the fluid is."
    },
    {name = "Dynamic Friction", min = 0, value = 0.1, max = 1, advanced = true,
        description = "Sets the friction between dynamic objects."
    },
    {name = "Static Friction", min = 0, value = 0.1, max = 1, advanced = true,
        description = "Sets the friction between static objects."
    },
    {name = "Particle Friction", min = 0, value = 0.01, max = 1, advanced = true,
        description = "Sets the overall friction between particles."
    },
    {name = "Collision Distance", min = 0, value = 5, max = 20, advanced = true,
        description = "Sets the collision distance between particles and shapes."
    },
    {name = "Drag", min = 0, max = 1, value = 0, description = "Sets the drag force applied to the particles."},
    {name = "Fluid Rest Distance", min = 0, value = 7.5, max = 100, advanced = true,
        description = [[
The distance fluid particles are spaced at the rest density,
must be in the range (0, radius], for fluids this should generally be 50-70% of Radius,
for rigids this can simply be the same as the particle radius.
        ]]
    },
    {name = "Solid Rest Distance", min = 0, value = 7.5, max = 100, advanced = true,
        description = "The distance non-fluid particles attempt to maintain from each other, must be in the range (0, radius]"
    },
    {name = "Dissipation", min = 0, value = 0.01, max = 1,
        description = "Damps particle velocity based on how many contacts it has."
    },
    {name = "Damping", min = 0, value = 0, max = 1,
        description = "Viscous drag force. Applies a force proportional to "
    },
    {name = "Restitution", min = 0, value = 1, max = 1,
        description = "Coefficient of restitution used when colliding against shapes, particle collisions are always inelastic."
    },
    {name = "Adhesion", min = 0, value = 0, max = 1,
        description = "Controls how strongly particles stick to surfaces they hit."
    },
    {name = "Cohesion", min = 0, value = 0, max = 1,
        description = "Control how strongly particles hold each other together."
    },
    {name = "Surface Tension", min = 0, value = 0, max = 1,
        description = "Controls how strongly particles attempt to minimize surface area."
    },
    {name = "Vorticity Confinement", min = 0, value = 0, max = 100,
        description = "Increases vorticity by applying rotational forces to particles."
    }
}

local function GetParameterByName(name)
    for k, para in pairs(gwaterParameters) do
        if gwaterParameters[k].name == name then
            return k
        end
    end
end

local function map(in_min, in_max, out_min, out_max, x)
    return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end

local sliders = {}

local function GenerateDefaults()
    for k, para in pairs(gwaterParameters) do
        para.default = para.value
    end
end

GenerateDefaults() -- Generate the default values and push them to their respective parameter

local function UpdateSlider(title, value)
    local chosenSlider = nil
    for k, slider in pairs(sliders) do
        if slider.Title == title then
            chosenSlider = slider
            break
        end
    end
    if chosenSlider then
        chosenSlider:SetValue(math.Round(value, 4))
        chosenSlider.NumberSelector:SetText(chosenSlider:GetValue())
    end
end

local function SetParameter(parameter, value)
    if parameter == "Radius" then
        UpdateSlider("Fluid Rest Distance", value * 0.7)
        UpdateSlider("Solid Rest Distance", value * 0.7)
        UpdateSlider("Collision Distance", value * 0.5)
        gwater2.solver:SetParameter("fluid_rest_distance", value * 0.7)
        gwater2.solver:SetParameter("solid_rest_distance", value * 0.7)
        gwater2.solver:SetParameter("collision_distance", value * 0.5)
    end
    local para_ind = GetParameterByName(parameter)
    gwaterParameters[para_ind].value = value
    UpdateSlider(parameter, value)
    parameter = string.lower(parameter)
    parameter = string.Replace(parameter, " ", "_")
    gwater2.solver:SetParameter(parameter, value)
end

local function GetParameter(parameter)
    local para_ind = GetParameterByName(parameter)
    return gwaterParameters[para_ind].value
end

-- v GLOBAL FUNCTIONS FOR PUBLIC USE v --
function SetGwaterParameter(parameter, value)
    SetParameter(parameter, value)
end

function GetGwaterParameter(parameter)
    return GetParameter(parameter)
end

-- ^ GLOBAL FUNCTIONS FOR PUBLIC USE ^ --

//for k, para in ipairs(gwaterParameters) do
//    SetParameter(para.name, para.value)
//end

surface.CreateFont( "TitleFont", {
    font = "Space Mono Regular", --  Use the font-name which is shown to you by your operating system Font Viewer, not the file name
    extended = false,
    size = 24,
    weight = 500,
    blursize = 0,
    scanlines = 2,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = false,
    additive = false,
    outline = false,
} )

surface.CreateFont( "TitleFontShadow", {
    font = "Space Mono Regular", --  Use the font-name which is shown to you by your operating system Font Viewer, not the file name
    extended = false,
    size = 24,
    weight = 500,
    blursize = 1,
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
} )

surface.CreateFont( "DescTitleFont", {
    font = "Space Mono Regular", --  Use the font-name which is shown to you by your operating system Font Viewer, not the file name
    extended = false,
    size = 32,
    weight = 500,
    blursize = 0,
    scanlines = 2,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = false,
    additive = false,
    outline = false,
} )

surface.CreateFont( "DescTitleFontShadow", {
    font = "Space Mono Regular", --  Use the font-name which is shown to you by your operating system Font Viewer, not the file name
    extended = false,
    size = 32,
    weight = 500,
    blursize = 1,
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
} )

local function CreateTab(tabsPanel, name, icon, hasDesc)
    local tabPanel = vgui.Create("DPanel")
    tabPanel:SetBackgroundColor(Color(0,0,0,0))
    tabPanel:DockPadding(0,0,0,0)
    tabPanel:DockMargin(0,0,0,0)

    local tab = tabsPanel:AddSheet(name, tabPanel, icon)

    local scrollPanel = vgui.Create("DScrollPanel", tabPanel)
    scrollPanel:Dock(FILL)
    scrollPanel:InvalidateParent(true)

    function tabPanel:Paint(w, h)
        
    end

    function scrollPanel:Paint(w, h)
        
    end

    local scrollBar = scrollPanel:GetVBar()
    --scrollBar:SetHideButtons(true)

    function scrollBar:Paint(w, h)
        draw.RoundedBox(100, 4, 15, 8, h - 30, Color(0,15,44, 180))
    end

    function scrollBar.btnUp:Paint() end
    function scrollBar.btnDown:Paint() end

    function scrollBar.btnGrip:Paint(w, h)
        draw.RoundedBox(100, 4, 0, 8, h, Color(0,110,255, 230))
    end
    if hasDesc then
        local description = vgui.Create("DTextEntry", scrollPanel)
        description:SetMultiline(true)
        description:SetX(ScrW() * 0.495)
        description:SetY(20)
        description:SetSize(ScrW() / 4.6 - 8, ScrH() / 1.65)
        description:SetEditable(false)
        description.name = ""
        local descriptionTextColor = Color(0,34,126, 255)
        local descriptionNameColor = Color(0,48,180, 255)
        function description:Paint(w, h)
            draw.RoundedBox(5, 0, 0, w, h, descriptionTextColor)
            local txt = description:GetText()
            local parsed = markup.Parse(
                "<font=TitleFont>" .. txt .. "</font>"
            , w)
            local parsedShadow = markup.Parse(
                "<font=TitleFontShadow><color=0,0,0,255>" .. txt .. "</color></font>"
            , w)
            draw.RoundedBoxEx(5, 0, 0, w, 32, descriptionNameColor, true, true, false, false)
            draw.DrawText(description.name, "DescTitleFontShadow", 4, 2, Color(0,0,0))
            draw.DrawText(description.name, "DescTitleFont", 2, 0, Color(255,255,255))
            parsedShadow:Draw(7,34)
            parsed:Draw(5,32)
        end

        scrollPanel.Description = description
    end

    return scrollPanel
end

local function IsHovered(panel)
    local container = panel:GetParent():GetParent():GetParent()
    local tab = panel:GetParent():GetParent():GetParent():GetParent():GetActiveTab()

    if tab:GetPanel() ~= container then return false end

    local localX, localY = panel:ScreenToLocal(gui.MouseX(), gui.MouseY())

    local state = localX < panel:GetWide() and localX > 0 and
    localY < panel:GetTall() and localY > 0

    return state
end

sound.Add( {
	name = "gwater_button_click",
	channel = CHAN_STATIC,
	volume = 1.0,
	level = 80,
	pitch = {95, 110},
	sound = "ambient/water/water_splash1.wav"
} )

local function CreateResetButton(parent, x, y, advanced)
    local settingsResetButton = vgui.Create("DButton", parent)
    settingsResetButton:SetX(x)
    settingsResetButton:SetY(y)
    settingsResetButton:SetWide(200)
    settingsResetButton:SetTall(75)
    settingsResetButton:SetText("")
    settingsResetButton:SetFont("TitleFont")
    settingsResetButton.WaterHeight = 0.3
    settingsResetButton.WaterX = 0
    local target_vel = 4
    settingsResetButton.WaterVel = target_vel
    settingsResetButton.Brightness = 0
    settingsResetButton.Pressed = false
    settingsResetButton.Hovering = false
    settingsResetButton:SetMouseInputEnabled(false)
    function settingsResetButton:Paint(w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0 + self.Brightness,153 + self.Brightness,255 + self.Brightness))
        draw.RoundedBox(0, 2, 2, w - 4, h - 4, Color(25,25,75))
        local water_height = self.WaterHeight
        if IsHovered(self) then
            self.Hovering = true
            self.WaterHeight = water_height + (0.8 - water_height) * 0.05
            if input.IsMouseDown(MOUSE_LEFT) and not self.Pressed and not self.Locked then
                self.WaterVel = self.WaterVel + 30
                for k, para in ipairs(gwaterParameters) do
                    if para.advanced and advanced then
                        SetParameter(para.name, para.default)
                    end
                    if not advanced and not para.advanced then
                        SetParameter(para.name, para.default)
                    end
                end
                sound.PlayFile("sound/ambient/water/water_splash1.wav", "noplay", function(snd)
                    snd:SetPlaybackRate(math.Rand(0.9, 1.1), 0)
                    snd:SetVolume(0.3)
                    snd:Play()
                end)
                self.Brightness = 100
                self.Pressed = true
            end
        else
            self.WaterHeight = water_height + (0.3 - water_height) * 0.05
            self.Hovering = false
        end
        if input.IsMouseDown(MOUSE_LEFT) and not self.Pressed then
            self.Locked = true
        else
            self.Locked = false
        end
        if not input.IsMouseDown(MOUSE_LEFT) and self.Pressed then
            self.Pressed = false
        end
        self.Brightness = self.Brightness * 0.98
        water_height = self.WaterHeight
        self.WaterVel = self.WaterVel + (target_vel - self.WaterVel) * 0.01
        self.WaterX = self.WaterX + self.WaterVel * FrameTime()
        local water_verts = {}
        water_verts[#water_verts + 1] = {x = 0, y = h}
        for i = 0, 1 + 0.02, 0.02 do
            local wave = (math.sin(self.WaterX + i * math.pi * 5) * 0.5 + 0.5) * 5
            water_verts[#water_verts + 1] = {x = i * w, y = h * (1-self.WaterHeight) + wave}
        end

        water_verts[#water_verts + 1] = {x = w, y = h}
        draw.NoTexture()
        surface.SetDrawColor(0 + self.Brightness,153 + self.Brightness,255 + self.Brightness,255)
        surface.DrawPoly(water_verts)
        draw.DrawText("Reset To Defaults", "TitleFontShadow", w / 2 + 2, h / 2 - 12 + 2, Color(0,0,0),TEXT_ALIGN_CENTER)
        draw.DrawText("Reset To Defaults", "TitleFont", w / 2, h / 2 - 12, Color(255,255,255),TEXT_ALIGN_CENTER)
    end
end

local function GenerateAboutSection(scrollpanel)
    local aboutText = vgui.Create("DPanel", scrollpanel)
    aboutText:SetX(0)
    aboutText:SetY(0)
    local txt = [[
    Welcome to Gwater! A revolutionary addon powered by NVIDIA's Flex library!
Dive into a whole new level of physics and joy as you explore the dynamic and exciting world of particle simulation.
    ]]
    function aboutText:Paint(w, h)
        aboutText:SetWide(scrollpanel:GetWide())
        aboutText:SetTall(scrollpanel:GetTall())
        local parsed = markup.Parse(
                "<font=TitleFont>" .. txt .. "</font>"
            , w)
        parsed:Draw(0,0)
    end

end

local function OpenMenu()
    local scrw, scrh = ScrW(), ScrH()

    local panel = vgui.Create("DFrame")

    panel:SetSize(scrw * 0.75, scrh * 0.75)
    panel:MakePopup()
    panel:DoModal()
    panel:Center()
    panel:ShowCloseButton(false)
    panel:SetTitle("")
    panel:SetSizable(true)

    local panelW, _ = panel:GetSize()

    local titleColor = Color(255, 255, 255)
    local titleShadowColor = Color(0, 0, 0, 255)

    local title = "GWater Settings [Current Version: 1.0]"
    function panel:Paint(w, h)
        --draw.RoundedBox(8, 0, 0, w, h, Color(0,162,255, 230)) -- Panel Outline

        surface.SetDrawColor(0,5,29, 255)
        surface.DrawOutlinedRect(10 - 31 + 1, 57 - 30, w - 20 + 62 - 2, h - 89 + 60, 30)
        draw.RoundedBox(0, 10, 57, w - 20, h - 89, Color(0,23,66, 253))

        draw.RoundedBoxEx(8, 0, 1, w, 28, Color(0,42,97, 255), true, true, false, false) -- Navigation Bar
        draw.RoundedBoxEx(0, 0, h - 24, w, 23, Color(0,42,97, 255), false, false, true, true) -- Bottom Bar

        draw.RoundedBox(0, w - 16, h - 17, 14, 14, Color(255, 255, 255, 10)) -- Resize Corner


        draw.DrawText(title, "TitleFontShadow", 8, 5, titleShadowColor) -- Title Shadow
        draw.DrawText(title, "TitleFont", 6, 3, titleColor)
    end

    local closeButton = vgui.Create("DButton", panel)
    closeButton:SetText("")
    closeButton:SetSize(30, 20)
    closeButton:SetY(5)
    closeButton:SetX(panelW - 34)

    function panel:OnSizeChanged(w, h)
        panelW, panelH = w, h -- Update the size variables to the size of the panel
        closeButton:SetX(w - 34)
    end

    local closeButtonColor = Color(230,68,68)
    local closeButtonPressedColor = Color(128,0,0)

    function closeButton:Paint(w, h)
        local color = closeButton:IsDown() and closeButtonPressedColor or closeButtonColor
        draw.RoundedBoxEx(6, 0, 0, w, h, color, true, true, false, false)
        draw.RoundedBoxEx(3, 2, 2, w - 4, h - 4, closeButtonPressedColor, true, true, false, false)
    end

    function closeButton:DoClick()
        panel:Close()
    end

    local tabsPanel = vgui.Create("DPropertySheet", panel)
    tabsPanel:Dock(FILL)
    tabsPanel:DockPadding(0,0,0,0)
    tabsPanel:DockMargin(0,0,0,19)
    tabsPanel:SetFadeTime(0)
    function tabsPanel:Paint(w, h)
        --draw.RoundedBox(0, 0, 0, w, h, Color(255,255,255, 5))
    end

    local settingsScrollPanel = CreateTab(tabsPanel, "Settings", "icon16/cog.png", true)

    CreateResetButton(settingsScrollPanel, 425, 150, false)

    local advSettingsScrollPanel = CreateTab(tabsPanel, "Advanced Settings", "icon16/cog_error.png", true)
    CreateResetButton(advSettingsScrollPanel, 425, 20, true)

    local aboutScrollPanel = CreateTab(tabsPanel, "About", "icon16/exclamation.png", false)

    GenerateAboutSection(aboutScrollPanel)

    for k, tab in pairs(tabsPanel:GetItems()) do
        local tab_verts = {
            {x = 0, y = 0},
            {x = tab.Tab:GetWide() - 3, y = 0},
            {x = tab.Tab:GetWide() - 5 - 3, y = 20},
            {x = 5, y = 20}
        }
        function tab.Tab:Paint(w, h)
            if tab.Tab:IsActive() then
                surface.SetDrawColor(Color(0,92,212))
            else
                surface.SetDrawColor(Color(0,42,97))
            end
            draw.NoTexture()
            surface.DrawPoly(tab_verts)
        end
    end

    -- Parameter GUI
    surface.SetFont("TitleFont")
    local column = 0
    local row = 0
    local advColumn = 0
    local advRow = 0
    for k, para in ipairs(gwaterParameters) do
        local wide = surface.GetTextSize(para.name) + 60
        local parent = para.advanced and advSettingsScrollPanel or settingsScrollPanel
        local slider = vgui.Create("GwaterSlider", parent)
        slider:SetTitle(para.name)
        slider:SetSize(280, 20)
        slider:SetMinValue(para.min)
        slider:SetMaxValue(para.max)
        slider:SetIsInteger(para.integer)
        slider:SetValue(para.value)
        slider.Description = para.description
        slider.NumberSelector:SetText(math.Round(slider:GetValue(), 4))

        sliders[#sliders + 1] = slider
        if parent == settingsScrollPanel then
            slider:SetX(50 + (column * 340))
            slider:SetY(40 + (60 * row))
            row = row + 1
            if row % 9 == 0 then
                column = column + 1
                row = 0
            end
        else
            slider:SetX(50 + (advColumn * 340))
            slider:SetY(40 + (60 * advRow))
            advRow = advRow + 1
            if advRow % 9 == 0 then
                advColumn = advColumn + 1
                advRow = 0
            end
        end
    end

    local function UpdateDescriptions(scrollpanel)
        for k, slider in ipairs(sliders) do
            if slider == nil or not slider:IsValid() then continue end
            --local tabActive = scrollpanel:GetParent():GetParent():GetActiveTab()
            if IsHovered(slider) then
                scrollpanel.Description:SetText(slider.Description)
                scrollpanel.Description.name = slider.Title
            elseif scrollpanel.Description:GetText() == slider.Description then
                scrollpanel.Description:SetText("")
                scrollpanel.Description.name = ""
            end
        end
    end

    settingsScrollPanel.Think = UpdateDescriptions
    advSettingsScrollPanel.Think = UpdateDescriptions
end

concommand.Add("gwater2_menu", function()
    OpenMenu()
end)