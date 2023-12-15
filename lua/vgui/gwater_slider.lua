local PANEL = {}

PANEL.Value = 50
PANEL.MinValue = 0
PANEL.MaxValue = 100
PANEL.Pressed = false
PANEL.PressAllowed = true -- this variable is for fixing the issue of dragging multiple sliders at once.
PANEL.IsInteger = false

local function map(in_min, in_max, out_min, out_max, x)
    return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end

surface.CreateFont( "ParameterFont", {
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

surface.CreateFont( "ParameterFontShadow", {
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

surface.CreateFont( "NumberFont", {
    font = "Space Mono Regular", --  Use the font-name which is shown to you by your operating system Font Viewer, not the file name
    extended = false,
    size = 18,
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
} )

function PANEL:Init()
    local this = self
    self.Brightness = 1
    self.LastValue = 0
    self.MousePressed = function() end
    self.MouseReleased = function() end
    self.Tick = function() end

    self:SetSize(100, 40)

    self.Title = "Sample Text"
    self.TitleText = vgui.Create("DPanel", self:GetParent())
    self.Description = ""
    self.TitleText:SetWide(self:GetWide() * 4)
    self.TitleText:SetTall(30)
    
    function self.TitleText:Paint(w, h)
        draw.DrawText(this.Title, "ParameterFontShadow", 2, 2, Color(0,0,0)) -- Title Shadow
        draw.DrawText(this.Title, "ParameterFont", 0, 0, Color(255,255,255)) -- Title Shadow
    end

    self.NumberSelector = vgui.Create("DTextEntry", self:GetParent())
    self.NumberSelector:SetSize(50,20)
    self.NumberSelector:SetNumeric(true)

    self.NumberSelector.FocusLost = function() end

    function self.NumberSelector:Paint(w, h)
        local value = self:GetValue()
        surface.SetFont("NumberFont")

        self:SetX(this:GetX() + this:GetWide() - 25 - self:GetWide() * 0.5)
        self:SetY(this:GetY() - 22)

        draw.RoundedBox(2, 0, 0, w, h, Color(0,103,177, 100))
        draw.DrawText(value, "NumberFont", w * 0.5 + 1, h * 0.5 - 9, Color(169,219,255), TEXT_ALIGN_CENTER)
    end

    function self.NumberSelector:OnGetFocus()
        self:SetText("")
    end

    function self.NumberSelector:OnLoseFocus()
        local num = self:GetFloat()
        this:SetValue(self.IsInteger and math.Round(num) or num)
        num = math.Clamp(num and num or 0, this:GetMinValue(), this:GetMaxValue())
        num = self.IsInteger and math.Round(num) or num
        self:SetText(num)
        SetGwaterParameter(this.Title, num)
        self.FocusLost()
    end
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

function PANEL:Think()
    if input.IsMouseDown(MOUSE_LEFT) and not self.Pressed and self.PressAllowed and IsHovered(self) then
        self.Pressed = true
        sound.PlayFile("sound/ambient/water/water_flow_loop1.wav", "noplay noblock", function(snd)
            snd:SetVolume(0)
            snd:EnableLooping(true)
            snd:Play()
            local vol = 0
            timer.Create(tostring(self) .. "CheckPressed", 0, 0, function()
                if not self.Pressed then
                    vol = vol + (0 - vol) * 0.1
                    snd:SetVolume(math.min(vol, 0.75))
                    if vol <= 0.01 then
                        snd:Stop()
                        timer.Remove(tostring(self) .. "CheckPressed")
                    end
                else
                    local vel = math.abs(self:GetValueChange())
                    local target_vol = map(0, self:GetMaxValue() - self:GetMinValue(), 0, 16, vel)
                    vol = vol + (target_vol - vol) * 0.1
                    snd:SetVolume(math.min(vol, 0.2))
                end
            end)
        end)
        self.MousePressed()
    elseif input.IsMouseDown(MOUSE_LEFT) and not IsHovered(self) and not self.Pressed then
        self.PressAllowed = false -- implementation of the fix for the multi-slider drag issue.
    end
    if self.Pressed then
        SetGwaterParameter(self.Title, self:GetValue())
    end
    if not input.IsMouseDown(MOUSE_LEFT) and self.Pressed then
        self.MouseReleased()
        self.Pressed = false
        self.PressAllowed = true
    end
    if not input.IsMouseDown(MOUSE_LEFT) then
        self.PressAllowed = true
    end
    self.Tick()
end

function PANEL:GetValue()
    return self.Value
end

function PANEL:OnValueChanged(value) -- Defined Event

end

function PANEL:SetValue(x)
    self.LastValue = self.Value
    self.Value = x and math.Clamp(self.IsInteger and math.Round(x) or x, self:GetMinValue(), self:GetMaxValue()) or 0
    self.NumberSelector:SetCaretPos(#self.NumberSelector:GetText())
    self:OnValueChanged(self.Value) -- Call Change Event
end

function PANEL:GetValueChange()
    return self.Value - self.LastValue
end

function PANEL:GetMaxValue()
    return self.MaxValue
end

function PANEL:SetMaxValue(x)
    self.MaxValue = x and x or 0
end

function PANEL:GetMinValue()
    return self.MinValue
end

function PANEL:SetMinValue(x)
    self.MinValue = x and x or 0
end

function PANEL:SetTitle(title)
    self.Title = title
end

function PANEL:SetIsInteger(state)
    self.IsInteger = state
end

function PANEL:Paint(w, h)
    self.Brightness = self.Brightness + (1 - self.Brightness) * 0.02
    self.TitleText:SetX(self:GetX())
    self.TitleText:SetY(self:GetY() - 23)
    local verts = { -- Initialize Vertex Table
        {x = 1, y = 1}
    }
    for i = 0, 1, 0.2 do -- Add Vertices To The Table
        verts[#verts + 1] = {
            x = math.min((w - 1) * map(self:GetMinValue(), self:GetMaxValue(), 0, 1, self:GetValue()) + math.sin(CurTime() * 5 + i * 8) * 1.5, w - 1),
            y = 1 + i * (h - 2)
        }
    end
    verts[#verts + 1] = {x = 1, y = h - 1} -- Add Last Vertex At The Bottom Left

    if self.Pressed then
        local localX, localY = self:ScreenToLocal(gui.MouseX(), gui.MouseY())
        self:SetValue(map(self:GetX(), self:GetX() + self:GetWide(), self:GetMinValue(), self:GetMaxValue(), localX + self:GetX()))
        local value = math.Round(self:GetValue(), 4)
        self.NumberSelector:SetText(value)
        if not IsHovered(self) and not input.IsMouseDown(MOUSE_LEFT) then
            self.Pressed = false
        end
        self.Brightness = 2
    end

    draw.RoundedBox(0, 0, 0, w, h, Color(0,141,241))
    draw.RoundedBox(0, 1, 1, w - 2, h - 2, Color(0,62,107))

    -- Water Wave Rendering
    surface.SetDrawColor(0 * self.Brightness,183 * self.Brightness,255 * self.Brightness,255)
    -- surface.SetDrawColor(0,183,255)
    draw.NoTexture()
    surface.DrawPoly(verts)
end

vgui.Register("GwaterSlider", PANEL, "Panel")