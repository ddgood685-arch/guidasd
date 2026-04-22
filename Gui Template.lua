--[[
═══════════════════════════════════════════════════════════════════════════
   GLUTTONY UI LIBRARY v1.2
   Fixed: no double callback firing on load
═══════════════════════════════════════════════════════════════════════════
]]

local GluttonyUI = {}

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ════════════════════════════════════════════════════════════════
-- THEME
-- ════════════════════════════════════════════════════════════════

local Theme = {
    Background    = Color3.fromRGB(22, 22, 28),
    Sidebar       = Color3.fromRGB(18, 18, 24),
    TitleBar      = Color3.fromRGB(16, 16, 22),
    Accent        = Color3.fromRGB(220, 60, 60),
    AccentLight   = Color3.fromRGB(255, 90, 90),
    AccentDark    = Color3.fromRGB(180, 45, 45),
    Text          = Color3.fromRGB(235, 235, 240),
    TextDim       = Color3.fromRGB(140, 140, 155),
    Row           = Color3.fromRGB(32, 32, 40),
    RowAlt        = Color3.fromRGB(28, 28, 36),
    Hover         = Color3.fromRGB(42, 42, 52),
    SelectedTab   = Color3.fromRGB(40, 35, 38),
    ToggleOff     = Color3.fromRGB(55, 55, 65),
    ToggleOn      = Color3.fromRGB(220, 60, 60),
    SliderBg      = Color3.fromRGB(50, 50, 60),
    SliderFill    = Color3.fromRGB(220, 60, 60),
    InputBg       = Color3.fromRGB(38, 38, 48),
    Border        = Color3.fromRGB(50, 50, 60),
    Shadow        = Color3.fromRGB(0, 0, 0),
    DropdownBg    = Color3.fromRGB(28, 28, 36),
    DropdownHover = Color3.fromRGB(45, 45, 55),
    NotifSuccess  = Color3.fromRGB(60, 180, 90),
    NotifWarning  = Color3.fromRGB(255, 160, 60),
    NotifError    = Color3.fromRGB(220, 60, 60),
    NotifInfo     = Color3.fromRGB(80, 150, 255),
    Font          = Enum.Font.GothamBold,
    FontLight     = Enum.Font.GothamMedium,
    CornerRadius  = UDim.new(0, 8),
    CornerLarge   = UDim.new(0, 12),
    WindowWidth   = 620,
    WindowHeight  = 480,
    SidebarWidth  = 150,
    RowHeight     = 48,
}

-- ════════════════════════════════════════════════════════════════
-- STATE STORE
-- ════════════════════════════════════════════════════════════════

local StateStore = {}

function GluttonyUI:GetValue(name)
    return StateStore[name]
end

function GluttonyUI:SetValue(name, value)
    StateStore[name] = value
end

-- ════════════════════════════════════════════════════════════════
-- CONFIG SYSTEM
-- ════════════════════════════════════════════════════════════════

local ConfigManager = {}
ConfigManager._fileName   = nil
ConfigManager._enabled    = false
ConfigManager._dirty      = false
ConfigManager._saveThread = nil
ConfigManager._debounce   = 1.5
ConfigManager._uiUpdaters = {}

local function HasFileSupport()
    local ok, result = pcall(function()
        return type(writefile) == "function"
            and type(readfile)  == "function"
            and type(isfile)    == "function"
    end)
    return ok and result
end

function ConfigManager:Init(fileName)
    if not fileName or fileName == "" then
        self._enabled = false
        return
    end
    if not HasFileSupport() then
        self._enabled = false
        warn("[GluttonyUI] File system not available — config saving disabled")
        return
    end
    if not fileName:match("%.json$") then
        fileName = fileName .. ".json"
    end
    self._fileName = fileName
    self._enabled  = true
end

function ConfigManager:Load()
    if not self._enabled then return false end
    local exists = false
    pcall(function() exists = isfile(self._fileName) end)
    if not exists then return false end
    local ok, content = pcall(readfile, self._fileName)
    if not ok or not content or content == "" then return false end
    local decodeOk, data = pcall(HttpService.JSONDecode, HttpService, content)
    if not decodeOk or type(data) ~= "table" then
        warn("[GluttonyUI] Failed to decode config file")
        return false
    end
    for key, value in pairs(data) do
        StateStore[key] = value
    end
    return true
end

function ConfigManager:Save()
    if not self._enabled then return end
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, StateStore)
    if not ok then
        warn("[GluttonyUI] Failed to encode config:", encoded)
        return
    end
    local writeOk, err = pcall(writefile, self._fileName, encoded)
    if not writeOk then
        warn("[GluttonyUI] Failed to write config:", err)
    end
    self._dirty = false
end

function ConfigManager:QueueSave()
    if not self._enabled then return end
    self._dirty = true
    if self._saveThread then
        pcall(task.cancel, self._saveThread)
        self._saveThread = nil
    end
    self._saveThread = task.delay(self._debounce, function()
        self:Save()
        self._saveThread = nil
    end)
end

function ConfigManager:Flush()
    if not self._enabled then return end
    if self._saveThread then
        pcall(task.cancel, self._saveThread)
        self._saveThread = nil
    end
    if self._dirty then
        self:Save()
    end
end

function ConfigManager:Set(name, value)
    StateStore[name] = value
    self:QueueSave()
end

function ConfigManager:RegisterUpdater(name, updaterFn)
    self._uiUpdaters[name] = updaterFn
end

function ConfigManager:ApplyToUI()
    for name, updater in pairs(self._uiUpdaters) do
        local saved = StateStore[name]
        if saved ~= nil then
            pcall(updater, saved)
        end
    end
end

-- ════════════════════════════════════════════════════════════════
-- CONNECTION MANAGER
-- ════════════════════════════════════════════════════════════════

local Connections = {}

local function AddConnection(conn)
    table.insert(Connections, conn)
    return conn
end

local function DisconnectAll()
    for _, c in ipairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    Connections = {}
end

-- ════════════════════════════════════════════════════════════════
-- UTILITIES
-- ════════════════════════════════════════════════════════════════

local function Tween(obj, props, dur, style, dir)
    if not obj or not obj.Parent then return end
    local ti = TweenInfo.new(dur or 0.25, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out)
    TweenService:Create(obj, ti, props):Play()
end

local function Corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = radius or Theme.CornerRadius
    c.Parent = parent
    return c
end

local function Stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Border
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0.5
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function Padding(parent, t, b, l, r)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, t or 0)
    p.PaddingBottom = UDim.new(0, b or 0)
    p.PaddingLeft   = UDim.new(0, l or 0)
    p.PaddingRight  = UDim.new(0, r or 0)
    p.Parent = parent
    return p
end

local function ListLayout(parent, padding, direction)
    local l = Instance.new("UIListLayout")
    l.FillDirection        = direction or Enum.FillDirection.Vertical
    l.SortOrder            = Enum.SortOrder.LayoutOrder
    l.Padding              = UDim.new(0, padding or 6)
    l.HorizontalAlignment  = Enum.HorizontalAlignment.Center
    l.Parent = parent
    return l
end

local function HoverAccent(row)
    local bar = Instance.new("Frame")
    bar.Name = "HoverBar"
    bar.Size = UDim2.new(0, 3, 0.55, 0)
    bar.Position = UDim2.new(0, 0, 0.225, 0)
    bar.BackgroundColor3 = Theme.Accent
    bar.BackgroundTransparency = 1
    bar.BorderSizePixel = 0
    bar.ZIndex = row.ZIndex + 1
    bar.Parent = row
    Corner(bar, UDim.new(1, 0))
    return bar
end

local function SetupHover(row, baseColor, accentBar)
    AddConnection(row.MouseEnter:Connect(function()
        Tween(row, {BackgroundColor3 = Theme.Hover}, 0.15)
        if accentBar then Tween(accentBar, {BackgroundTransparency = 0.2}, 0.15) end
    end))
    AddConnection(row.MouseLeave:Connect(function()
        Tween(row, {BackgroundColor3 = baseColor}, 0.15)
        if accentBar then Tween(accentBar, {BackgroundTransparency = 1}, 0.15) end
    end))
end

local function RowColor(index)
    return (index % 2 == 0) and Theme.Row or Theme.RowAlt
end

-- ════════════════════════════════════════════════════════════════
-- NOTIFICATIONS
-- ════════════════════════════════════════════════════════════════

local NotifContainer = nil

local function EnsureNotifContainer(screenGui)
    if NotifContainer and NotifContainer.Parent then return end
    NotifContainer = Instance.new("Frame")
    NotifContainer.Name = "Notifications"
    NotifContainer.Size = UDim2.new(0, 280, 1, -20)
    NotifContainer.Position = UDim2.new(1, -290, 0, 10)
    NotifContainer.BackgroundTransparency = 1
    NotifContainer.ZIndex = 200
    NotifContainer.Parent = screenGui
    local layout = Instance.new("UIListLayout")
    layout.FillDirection      = Enum.FillDirection.Vertical
    layout.VerticalAlignment  = Enum.VerticalAlignment.Bottom
    layout.SortOrder          = Enum.SortOrder.LayoutOrder
    layout.Padding            = UDim.new(0, 8)
    layout.Parent = NotifContainer
end

function GluttonyUI:Notify(title, message, notifType, duration)
    if not NotifContainer then return end
    duration  = duration  or 3
    notifType = notifType or "info"

    local accentColor = Theme.NotifInfo
    if notifType == "success" then accentColor = Theme.NotifSuccess
    elseif notifType == "warning" then accentColor = Theme.NotifWarning
    elseif notifType == "error"   then accentColor = Theme.NotifError end

    local notif = Instance.new("Frame")
    notif.Size = UDim2.new(1, 0, 0, 0)
    notif.BackgroundColor3 = Theme.TitleBar
    notif.BorderSizePixel = 0
    notif.ClipsDescendants = true
    notif.ZIndex = 201
    notif.Parent = NotifContainer
    Corner(notif, Theme.CornerRadius)
    Stroke(notif, accentColor, 1, 0.4)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 4, 1, -12)
    bar.Position = UDim2.new(0, 6, 0, 6)
    bar.BackgroundColor3 = accentColor
    bar.BorderSizePixel = 0
    bar.ZIndex = 202
    bar.Parent = notif
    Corner(bar, UDim.new(1, 0))

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.Position = UDim2.new(0, 18, 0, 14)
    dot.BackgroundColor3 = accentColor
    dot.BorderSizePixel = 0
    dot.ZIndex = 203
    dot.Parent = notif
    Corner(dot, UDim.new(1, 0))

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -44, 0, 18)
    titleLabel.Position = UDim2.new(0, 34, 0, 8)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title or "Notification"
    titleLabel.TextColor3 = Theme.Text
    titleLabel.TextSize = 14
    titleLabel.Font = Theme.Font
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.ZIndex = 203
    titleLabel.Parent = notif

    local msgLabel = Instance.new("TextLabel")
    msgLabel.Size = UDim2.new(1, -44, 0, 30)
    msgLabel.Position = UDim2.new(0, 34, 0, 26)
    msgLabel.BackgroundTransparency = 1
    msgLabel.Text = message or ""
    msgLabel.TextColor3 = Theme.TextDim
    msgLabel.TextSize = 12
    msgLabel.Font = Theme.FontLight
    msgLabel.TextXAlignment = Enum.TextXAlignment.Left
    msgLabel.TextWrapped = true
    msgLabel.ZIndex = 203
    msgLabel.Parent = notif

    Tween(notif, {Size = UDim2.new(1, 0, 0, 62)}, 0.3, Enum.EasingStyle.Back)

    task.delay(duration, function()
        if notif and notif.Parent then
            Tween(notif, {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1}, 0.3)
            task.wait(0.35)
            if notif and notif.Parent then notif:Destroy() end
        end
    end)
end

-- ════════════════════════════════════════════════════════════════
-- LOGO
-- ════════════════════════════════════════════════════════════════

local function CreateLogo(parent)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(0, 32, 0, 32)
    container.Position = UDim2.new(0, 12, 0.5, -16)
    container.BackgroundTransparency = 1
    container.ZIndex = 12
    container.Parent = parent

    local ring = Instance.new("Frame")
    ring.Size = UDim2.new(1, 0, 1, 0)
    ring.BackgroundColor3 = Theme.Accent
    ring.BackgroundTransparency = 0.6
    ring.BorderSizePixel = 0
    ring.ZIndex = 12
    ring.Parent = container
    Corner(ring, UDim.new(1, 0))

    local inner = Instance.new("Frame")
    inner.Size = UDim2.new(0, 18, 0, 18)
    inner.AnchorPoint = Vector2.new(0.5, 0.5)
    inner.Position = UDim2.new(0.5, 0, 0.5, 0)
    inner.BackgroundColor3 = Theme.Accent
    inner.BorderSizePixel = 0
    inner.ZIndex = 13
    inner.Parent = container
    Corner(inner, UDim.new(1, 0))

    local glow = Instance.new("Frame")
    glow.Size = UDim2.new(0, 10, 0, 10)
    glow.AnchorPoint = Vector2.new(0.5, 0.5)
    glow.Position = UDim2.new(0.5, 0, 0.5, 0)
    glow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    glow.BackgroundTransparency = 0.4
    glow.BorderSizePixel = 0
    glow.ZIndex = 14
    glow.Parent = container
    Corner(glow, UDim.new(1, 0))
end

-- ════════════════════════════════════════════════════════════════
-- TAB ICONS
-- ════════════════════════════════════════════════════════════════

local function CreateTabIcon(parent, iconType)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(0, 20, 0, 20)
    container.Position = UDim2.new(0, 18, 0.5, -10)
    container.BackgroundTransparency = 1
    container.ZIndex = 9
    container.Parent = parent

    if iconType == "circle" then
        local c = Instance.new("Frame")
        c.Size = UDim2.new(0, 14, 0, 14)
        c.AnchorPoint = Vector2.new(0.5, 0.5)
        c.Position = UDim2.new(0.5, 0, 0.5, 0)
        c.BackgroundColor3 = Theme.Accent
        c.BackgroundTransparency = 0.3
        c.BorderSizePixel = 0
        c.ZIndex = 10
        c.Parent = container
        Corner(c, UDim.new(1, 0))

    elseif iconType == "square" then
        local s = Instance.new("Frame")
        s.Size = UDim2.new(0, 12, 0, 12)
        s.AnchorPoint = Vector2.new(0.5, 0.5)
        s.Position = UDim2.new(0.5, 0, 0.5, 0)
        s.BackgroundColor3 = Theme.Accent
        s.BackgroundTransparency = 0.3
        s.BorderSizePixel = 0
        s.ZIndex = 10
        s.Parent = container
        Corner(s, UDim.new(0, 3))

    elseif iconType == "diamond" then
        local d = Instance.new("Frame")
        d.Size = UDim2.new(0, 11, 0, 11)
        d.AnchorPoint = Vector2.new(0.5, 0.5)
        d.Position = UDim2.new(0.5, 0, 0.5, 0)
        d.BackgroundColor3 = Theme.Accent
        d.BackgroundTransparency = 0.3
        d.Rotation = 45
        d.BorderSizePixel = 0
        d.ZIndex = 10
        d.Parent = container
        Corner(d, UDim.new(0, 2))

    elseif iconType == "bars" then
        for i = 0, 2 do
            local b = Instance.new("Frame")
            b.Size = UDim2.new(0, 14, 0, 2)
            b.AnchorPoint = Vector2.new(0.5, 0.5)
            b.Position = UDim2.new(0.5, 0, 0.5, -5 + (i * 5))
            b.BackgroundColor3 = Theme.Accent
            b.BackgroundTransparency = 0.3
            b.BorderSizePixel = 0
            b.ZIndex = 10
            b.Parent = container
            Corner(b, UDim.new(1, 0))
        end

    elseif iconType == "triangle" then
        local t = Instance.new("Frame")
        t.Size = UDim2.new(0, 12, 0, 12)
        t.AnchorPoint = Vector2.new(0.5, 0.5)
        t.Position = UDim2.new(0.5, 0, 0.5, 1)
        t.BackgroundColor3 = Theme.Accent
        t.BackgroundTransparency = 0.3
        t.Rotation = 45
        t.BorderSizePixel = 0
        t.ZIndex = 10
        t.Parent = container
        Corner(t, UDim.new(0, 2))

    elseif iconType == "dot-grid" then
        for row = 0, 1 do
            for col = 0, 1 do
                local d = Instance.new("Frame")
                d.Size = UDim2.new(0, 5, 0, 5)
                d.Position = UDim2.new(0, 3 + col * 9, 0, 3 + row * 9)
                d.BackgroundColor3 = Theme.Accent
                d.BackgroundTransparency = 0.3
                d.BorderSizePixel = 0
                d.ZIndex = 10
                d.Parent = container
                Corner(d, UDim.new(1, 0))
            end
        end

    else
        local d = Instance.new("Frame")
        d.Size = UDim2.new(0, 8, 0, 8)
        d.AnchorPoint = Vector2.new(0.5, 0.5)
        d.Position = UDim2.new(0.5, 0, 0.5, 0)
        d.BackgroundColor3 = Theme.Accent
        d.BackgroundTransparency = 0.3
        d.BorderSizePixel = 0
        d.ZIndex = 10
        d.Parent = container
        Corner(d, UDim.new(1, 0))
    end
end

local IconTypes = {"circle", "square", "diamond", "bars", "triangle", "dot-grid"}

-- ════════════════════════════════════════════════════════════════
-- CREATE WINDOW
-- ════════════════════════════════════════════════════════════════

function GluttonyUI:CreateWindow(options)
    if type(options) == "string" then
        options = {Title = options}
    end
    options = options or {}

    local title      = options.Title or "Gluttony UI"
    local configName = options.ConfigName

    -- Cleanup any previous instance
    for _, v in pairs(playerGui:GetChildren()) do
        if v.Name == "GluttonyUILib" then v:Destroy() end
    end
    DisconnectAll()
    StateStore = {}
    ConfigManager._uiUpdaters = {}

    -- Init & load config BEFORE building UI
    ConfigManager:Init(configName)
    ConfigManager:Load()

    -- ── SCREEN GUI ───────────────────────────────────────────
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "GluttonyUILib"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    EnsureNotifContainer(screenGui)

    -- ── MAIN FRAME ───────────────────────────────────────────
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, Theme.WindowWidth, 0, Theme.WindowHeight)
    main.Position = UDim2.new(0.5, -Theme.WindowWidth/2, 0.5, -Theme.WindowHeight/2)
    main.BackgroundColor3 = Theme.Background
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.Parent = screenGui
    Corner(main, Theme.CornerLarge)
    Stroke(main, Theme.Border, 1.5, 0.3)

    local shadow = Instance.new("ImageLabel")
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.BackgroundTransparency = 1
    shadow.Position = UDim2.new(0.5, 0, 0.5, 0)
    shadow.Size = UDim2.new(1, 60, 1, 60)
    shadow.ZIndex = -1
    shadow.Image = "rbxassetid://5554236805"
    shadow.ImageColor3 = Theme.Shadow
    shadow.ImageTransparency = 0.4
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(23, 23, 277, 277)
    shadow.Parent = main

    local inner = Instance.new("Frame")
    inner.Size = UDim2.new(1, 0, 1, 0)
    inner.BackgroundTransparency = 1
    inner.ClipsDescendants = true
    inner.ZIndex = 2
    inner.Parent = main
    Corner(inner, Theme.CornerLarge)

    -- ── TITLE BAR ────────────────────────────────────────────
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 42)
    titleBar.BackgroundColor3 = Theme.TitleBar
    titleBar.BorderSizePixel = 0
    titleBar.ZIndex = 10
    titleBar.Parent = inner
    Corner(titleBar, Theme.CornerLarge)

    -- Cover the bottom corners of titlebar
    local titleCover = Instance.new("Frame")
    titleCover.Size = UDim2.new(1, 0, 0, 14)
    titleCover.Position = UDim2.new(0, 0, 1, -14)
    titleCover.BackgroundColor3 = Theme.TitleBar
    titleCover.BorderSizePixel = 0
    titleCover.ZIndex = 10
    titleCover.Parent = titleBar

    CreateLogo(titleBar)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -140, 1, 0)
    titleLabel.Position = UDim2.new(0, 52, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = Theme.Text
    titleLabel.TextSize = 17
    titleLabel.Font = Theme.Font
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 11
    titleLabel.Parent = titleBar

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -38, 0.5, -14)
    closeBtn.BackgroundColor3 = Color3.fromRGB(60, 35, 35)
    closeBtn.Text = ""
    closeBtn.BorderSizePixel = 0
    closeBtn.AutoButtonColor = false
    closeBtn.ZIndex = 12
    closeBtn.Parent = titleBar
    Corner(closeBtn, Theme.CornerRadius)

    local x1 = Instance.new("Frame")
    x1.Size = UDim2.new(0, 12, 0, 2)
    x1.AnchorPoint = Vector2.new(0.5, 0.5)
    x1.Position = UDim2.new(0.5, 0, 0.5, 0)
    x1.BackgroundColor3 = Theme.Accent
    x1.Rotation = 45
    x1.BorderSizePixel = 0
    x1.ZIndex = 13
    x1.Parent = closeBtn
    Corner(x1, UDim.new(1, 0))

    local x2 = x1:Clone()
    x2.Rotation = -45
    x2.Parent = closeBtn

    AddConnection(closeBtn.MouseEnter:Connect(function()
        Tween(closeBtn, {BackgroundColor3 = Theme.Accent}, 0.15)
        Tween(x1, {BackgroundColor3 = Theme.Text}, 0.15)
        Tween(x2, {BackgroundColor3 = Theme.Text}, 0.15)
    end))
    AddConnection(closeBtn.MouseLeave:Connect(function()
        Tween(closeBtn, {BackgroundColor3 = Color3.fromRGB(60, 35, 35)}, 0.15)
        Tween(x1, {BackgroundColor3 = Theme.Accent}, 0.15)
        Tween(x2, {BackgroundColor3 = Theme.Accent}, 0.15)
    end))
    AddConnection(closeBtn.MouseButton1Click:Connect(function()
        ConfigManager:Flush()
        DisconnectAll()
        screenGui:Destroy()
    end))

    -- Minimize button
    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 28, 0, 28)
    minBtn.Position = UDim2.new(1, -74, 0.5, -14)
    minBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    minBtn.Text = ""
    minBtn.BorderSizePixel = 0
    minBtn.AutoButtonColor = false
    minBtn.ZIndex = 12
    minBtn.Parent = titleBar
    Corner(minBtn, Theme.CornerRadius)

    local minLine = Instance.new("Frame")
    minLine.Size = UDim2.new(0, 12, 0, 2)
    minLine.Position = UDim2.new(0.5, -6, 0.5, -1)
    minLine.BackgroundColor3 = Theme.TextDim
    minLine.BorderSizePixel = 0
    minLine.ZIndex = 13
    minLine.Parent = minBtn
    Corner(minLine, UDim.new(1, 0))

    local minimized = false
    AddConnection(minBtn.MouseEnter:Connect(function()
        Tween(minBtn, {BackgroundColor3 = Color3.fromRGB(60, 60, 75)}, 0.15)
        Tween(minLine, {BackgroundColor3 = Theme.Text}, 0.15)
    end))
    AddConnection(minBtn.MouseLeave:Connect(function()
        Tween(minBtn, {BackgroundColor3 = Color3.fromRGB(45, 45, 55)}, 0.15)
        Tween(minLine, {BackgroundColor3 = Theme.TextDim}, 0.15)
    end))
    AddConnection(minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            Tween(main, {Size = UDim2.new(0, Theme.WindowWidth, 0, 42)}, 0.3)
        else
            Tween(main, {Size = UDim2.new(0, Theme.WindowWidth, 0, Theme.WindowHeight)}, 0.35, Enum.EasingStyle.Back)
        end
    end))

    -- ── DRAG ─────────────────────────────────────────────────
    local dragging, dragStart, startPos = false, nil, nil
    local dragInput = nil

    AddConnection(titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = main.Position
            local endConn
            endConn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if endConn then endConn:Disconnect() end
                end
            end)
        end
    end))
    AddConnection(titleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))
    AddConnection(UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging and startPos then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))

    -- ── SIDEBAR ──────────────────────────────────────────────
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, Theme.SidebarWidth, 1, -42)
    sidebar.Position = UDim2.new(0, 0, 0, 42)
    sidebar.BackgroundColor3 = Theme.Sidebar
    sidebar.BorderSizePixel = 0
    sidebar.ZIndex = 5
    sidebar.Parent = inner
    Corner(sidebar, Theme.CornerLarge)

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(0, 1, 1, -20)
    divider.Position = UDim2.new(1, 0, 0, 10)
    divider.BackgroundColor3 = Theme.Border
    divider.BackgroundTransparency = 0.5
    divider.BorderSizePixel = 0
    divider.ZIndex = 6
    divider.Parent = sidebar

    local tabContainer = Instance.new("Frame")
    tabContainer.Size = UDim2.new(1, 0, 1, -20)
    tabContainer.Position = UDim2.new(0, 0, 0, 10)
    tabContainer.BackgroundTransparency = 1
    tabContainer.ZIndex = 6
    tabContainer.Parent = sidebar
    ListLayout(tabContainer, 5)

    -- ── CONTENT ──────────────────────────────────────────────
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -Theme.SidebarWidth - 1, 1, -52)
    content.Position = UDim2.new(0, Theme.SidebarWidth + 1, 0, 42)
    content.BackgroundColor3 = Theme.Background
    content.BorderSizePixel = 0
    content.ClipsDescendants = true
    content.ZIndex = 5
    content.Parent = inner
    Corner(content, Theme.CornerLarge)

    -- ── KEYBIND ──────────────────────────────────────────────
    AddConnection(UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            if main.Visible then
                Tween(main, {Size = UDim2.new(0, Theme.WindowWidth, 0, 0)}, 0.3)
                task.wait(0.3)
                main.Visible = false
            else
                main.Visible = true
                main.Size = UDim2.new(0, Theme.WindowWidth, 0, 0)
                Tween(main, {Size = UDim2.new(0, Theme.WindowWidth, 0, Theme.WindowHeight)}, 0.4, Enum.EasingStyle.Back)
            end
        end
    end))

    -- Flush config on leave
    AddConnection(Players.PlayerRemoving:Connect(function(plr)
        if plr == player then ConfigManager:Flush() end
    end))

    -- ════════════════════════════════════════════════════════
    -- WINDOW OBJECT
    -- ════════════════════════════════════════════════════════

    local Window = {}
    Window._pages      = {}
    Window._tabButtons = {}
    Window._currentTab = nil
    Window._tabCount   = 0

    local function SwitchTab(tabName)
        Window._currentTab = tabName
        for name, pg in pairs(Window._pages) do
            pg.Visible = (name == tabName)
        end
        for name, btn in pairs(Window._tabButtons) do
            local ind = btn:FindFirstChild("Indicator")
            local lbl = btn:FindFirstChild("Label")
            if name == tabName then
                Tween(btn, {BackgroundColor3 = Theme.SelectedTab}, 0.2)
                if ind then Tween(ind, {BackgroundTransparency = 0, Size = UDim2.new(0, 4, 0, 26)}, 0.2) end
                if lbl then Tween(lbl, {TextColor3 = Theme.Text}, 0.2) end
            else
                Tween(btn, {BackgroundColor3 = Theme.Sidebar}, 0.2)
                if ind then Tween(ind, {BackgroundTransparency = 1, Size = UDim2.new(0, 4, 0, 22)}, 0.2) end
                if lbl then Tween(lbl, {TextColor3 = Theme.TextDim}, 0.15) end
            end
        end
    end

    -- ── ADD TAB ──────────────────────────────────────────────
    function Window:AddTab(name, iconType)
        Window._tabCount = Window._tabCount + 1
        local isFirst = Window._tabCount == 1
        iconType = iconType or IconTypes[((Window._tabCount - 1) % #IconTypes) + 1]

        local tabBtn = Instance.new("TextButton")
        tabBtn.Name = "Tab_" .. name
        tabBtn.Size = UDim2.new(1, -14, 0, 42)
        tabBtn.BackgroundColor3 = isFirst and Theme.SelectedTab or Theme.Sidebar
        tabBtn.BorderSizePixel = 0
        tabBtn.Text = ""
        tabBtn.AutoButtonColor = false
        tabBtn.LayoutOrder = Window._tabCount
        tabBtn.ZIndex = 7
        tabBtn.Parent = tabContainer
        Corner(tabBtn, Theme.CornerRadius)

        local indicator = Instance.new("Frame")
        indicator.Name = "Indicator"
        indicator.Size = isFirst and UDim2.new(0, 4, 0, 26) or UDim2.new(0, 4, 0, 22)
        indicator.Position = UDim2.new(0, 5, 0.5, -11)
        indicator.BackgroundColor3 = Theme.Accent
        indicator.BackgroundTransparency = isFirst and 0 or 1
        indicator.BorderSizePixel = 0
        indicator.ZIndex = 8
        indicator.Parent = tabBtn
        Corner(indicator, UDim.new(1, 0))

        CreateTabIcon(tabBtn, iconType)

        local tabLabel = Instance.new("TextLabel")
        tabLabel.Name = "Label"
        tabLabel.Size = UDim2.new(1, -52, 1, 0)
        tabLabel.Position = UDim2.new(0, 44, 0, 0)
        tabLabel.BackgroundTransparency = 1
        tabLabel.Text = name
        tabLabel.TextColor3 = isFirst and Theme.Text or Theme.TextDim
        tabLabel.TextSize = 14
        tabLabel.Font = Theme.FontLight
        tabLabel.TextXAlignment = Enum.TextXAlignment.Left
        tabLabel.ZIndex = 8
        tabLabel.Parent = tabBtn

        AddConnection(tabBtn.MouseEnter:Connect(function()
            if Window._currentTab ~= name then
                Tween(tabBtn, {BackgroundColor3 = Theme.Hover}, 0.15)
                Tween(tabLabel, {TextColor3 = Theme.Text}, 0.15)
            end
        end))
        AddConnection(tabBtn.MouseLeave:Connect(function()
            if Window._currentTab ~= name then
                Tween(tabBtn, {BackgroundColor3 = Theme.Sidebar}, 0.15)
                Tween(tabLabel, {TextColor3 = Theme.TextDim}, 0.15)
            end
        end))
        AddConnection(tabBtn.MouseButton1Click:Connect(function()
            SwitchTab(name)
        end))

        Window._tabButtons[name] = tabBtn

        -- Page scrollframe
        local page = Instance.new("ScrollingFrame")
        page.Name = "Page_" .. name
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 4
        page.ScrollBarImageColor3 = Theme.Accent
        page.ScrollBarImageTransparency = 0.3
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.Visible = isFirst
        page.ZIndex = 6
        page.Parent = content
        Padding(page, 18, 18, 22, 22)

        local pageLayout = ListLayout(page, 8)

        -- Page title
        local titleFrame = Instance.new("Frame")
        titleFrame.Size = UDim2.new(1, 0, 0, 42)
        titleFrame.BackgroundTransparency = 1
        titleFrame.LayoutOrder = 0
        titleFrame.ZIndex = 7
        titleFrame.Parent = page

        local pageTitleLabel = Instance.new("TextLabel")
        pageTitleLabel.Size = UDim2.new(1, 0, 0, 34)
        pageTitleLabel.BackgroundTransparency = 1
        pageTitleLabel.Text = name
        pageTitleLabel.TextColor3 = Theme.Text
        pageTitleLabel.TextSize = 24
        pageTitleLabel.Font = Theme.Font
        pageTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        pageTitleLabel.ZIndex = 7
        pageTitleLabel.Parent = titleFrame

        local underline = Instance.new("Frame")
        underline.Size = UDim2.new(0.25, 0, 0, 2)
        underline.Position = UDim2.new(0, 0, 1, -2)
        underline.BackgroundColor3 = Theme.Accent
        underline.BackgroundTransparency = 0.3
        underline.BorderSizePixel = 0
        underline.ZIndex = 8
        underline.Parent = titleFrame
        Corner(underline, UDim.new(1, 0))

        local ulGrad = Instance.new("UIGradient")
        ulGrad.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.7, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        ulGrad.Parent = underline

        AddConnection(pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            page.CanvasSize = UDim2.new(0, 0, 0, pageLayout.AbsoluteContentSize.Y + 40)
        end))

        Window._pages[name] = page
        if isFirst then Window._currentTab = name end

        -- ══════════════════════════════════════════════════════
        -- TAB OBJECT
        -- ══════════════════════════════════════════════════════

        local Tab = {}
        Tab._itemCount = 0

        local function NextOrder()
            Tab._itemCount = Tab._itemCount + 1
            return Tab._itemCount
        end

        -- ── SECTION ──────────────────────────────────────────

        function Tab:AddSection(sectionTitle)
            local order = NextOrder()

            local sectionLabel = Instance.new("TextLabel")
            sectionLabel.Size = UDim2.new(1, 0, 0, 30)
            sectionLabel.BackgroundTransparency = 1
            sectionLabel.Text = sectionTitle
            sectionLabel.TextColor3 = Theme.Accent
            sectionLabel.TextSize = 15
            sectionLabel.Font = Theme.Font
            sectionLabel.TextXAlignment = Enum.TextXAlignment.Left
            sectionLabel.LayoutOrder = order
            sectionLabel.ZIndex = 7
            sectionLabel.Parent = page

            local sepContainer = Instance.new("Frame")
            sepContainer.Size = UDim2.new(1, 0, 0, 8)
            sepContainer.BackgroundTransparency = 1
            sepContainer.LayoutOrder = order + 0.5
            sepContainer.Parent = page

            local sep = Instance.new("Frame")
            sep.Size = UDim2.new(0.4, 0, 0, 1)
            sep.Position = UDim2.new(0, 0, 0.5, 0)
            sep.BackgroundColor3 = Theme.Accent
            sep.BackgroundTransparency = 0.5
            sep.BorderSizePixel = 0
            sep.ZIndex = 7
            sep.Parent = sepContainer
            Corner(sep, UDim.new(1, 0))

            local sepGrad = Instance.new("UIGradient")
            sepGrad.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.5, 0.3),
                NumberSequenceKeypoint.new(1, 1),
            })
            sepGrad.Parent = sep
        end

        -- ── LABEL ────────────────────────────────────────────

        function Tab:AddLabel(text)
            local order = NextOrder()
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 0, 28)
            label.BackgroundTransparency = 1
            label.Text = text
            label.TextColor3 = Theme.TextDim
            label.TextSize = 13
            label.Font = Theme.FontLight
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.TextWrapped = true
            label.LayoutOrder = order
            label.ZIndex = 7
            label.Parent = page
            return label
        end

        -- ── TOGGLE ───────────────────────────────────────────
        -- FIX: RegisterUpdater only updates visuals, NOT fires callback
        -- FIX: initial callback only fires ONCE via task.defer below

        function Tab:AddToggle(labelText, default, callback)
            local order = NextOrder()

            local saved = StateStore[labelText]
            local state = (saved ~= nil) and saved or (default or false)
            StateStore[labelText] = state

            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, Theme.RowHeight)
            row.BackgroundColor3 = RowColor(order)
            row.BorderSizePixel = 0
            row.LayoutOrder = order
            row.ZIndex = 6
            row.ClipsDescendants = true
            row.Parent = page
            Corner(row, Theme.CornerRadius)

            local accentBar = HoverAccent(row)

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -80, 1, 0)
            lbl.Position = UDim2.new(0, 18, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = labelText
            lbl.TextColor3 = Theme.Text
            lbl.TextSize = 14
            lbl.Font = Theme.FontLight
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.ZIndex = 7
            lbl.Parent = row

            local toggleBg = Instance.new("Frame")
            toggleBg.Size = UDim2.new(0, 46, 0, 24)
            toggleBg.Position = UDim2.new(1, -60, 0.5, -12)
            toggleBg.BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff
            toggleBg.BorderSizePixel = 0
            toggleBg.ZIndex = 8
            toggleBg.Parent = row
            Corner(toggleBg, UDim.new(1, 0))

            local circle = Instance.new("Frame")
            circle.Size = UDim2.new(0, 20, 0, 20)
            circle.Position = state and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
            circle.BackgroundColor3 = Theme.Text
            circle.BorderSizePixel = 0
            circle.ZIndex = 9
            circle.Parent = toggleBg
            Corner(circle, UDim.new(1, 0))
            Stroke(circle, Theme.Shadow, 1, 0.7)

            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 1, 0)
            btn.BackgroundTransparency = 1
            btn.Text = ""
            btn.ZIndex = 10
            btn.Parent = toggleBg

            local function UpdateVisual(val)
                state = val
                toggleBg.BackgroundColor3 = val and Theme.ToggleOn or Theme.ToggleOff
                circle.Position = val and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
            end

            -- ✅ FIX: visuals only, no callback here
            ConfigManager:RegisterUpdater(labelText, function(val)
                if type(val) == "boolean" then
                    UpdateVisual(val)
                end
            end)

            AddConnection(btn.MouseButton1Click:Connect(function()
                state = not state
                ConfigManager:Set(labelText, state)
                Tween(toggleBg, {BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff}, 0.25)
                Tween(circle, {Position = state and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)}, 0.25, Enum.EasingStyle.Back)
                Tween(circle, {Size = UDim2.new(0, 22, 0, 22)}, 0.08)
                task.delay(0.08, function()
                    Tween(circle, {Size = UDim2.new(0, 20, 0, 20)}, 0.12)
                end)
                if callback then task.spawn(callback, state) end
            end))

            SetupHover(row, RowColor(order), accentBar)

            -- ✅ FIX: fires callback ONCE if saved state is true
            if state and callback then
                task.defer(callback, state)
            end

            return {
                Set = function(_, val)
                    state = val
                    ConfigManager:Set(labelText, val)
                    UpdateVisual(val)
                end,
                Get = function() return state end,
            }
        end

        -- ── SLIDER ───────────────────────────────────────────
        -- FIX: RegisterUpdater only updates visuals, NOT fires callback

        function Tab:AddSlider(labelText, min, max, default, callback)
            local order = NextOrder()

            local saved = StateStore[labelText]
            local value = (saved ~= nil and type(saved) == "number")
                and math.clamp(saved, min, max)
                or math.clamp(default or min, min, max)
            StateStore[labelText] = value

            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, Theme.RowHeight + 4)
            row.BackgroundColor3 = RowColor(order)
            row.BorderSizePixel = 0
            row.LayoutOrder = order
            row.ZIndex = 6
            row.ClipsDescendants = true
            row.Parent = page
            Corner(row, Theme.CornerRadius)

            local accentBar = HoverAccent(row)

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0, 170, 1, 0)
            lbl.Position = UDim2.new(0, 18, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = labelText
            lbl.TextColor3 = Theme.Text
            lbl.TextSize = 14
            lbl.Font = Theme.FontLight
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.ZIndex = 7
            lbl.Parent = row

            local valueBadge = Instance.new("Frame")
            valueBadge.Size = UDim2.new(0, 42, 0, 22)
            valueBadge.Position = UDim2.new(1, -158, 0.5, -11)
            valueBadge.BackgroundColor3 = Theme.Accent
            valueBadge.BackgroundTransparency = 0.85
            valueBadge.BorderSizePixel = 0
            valueBadge.ZIndex = 7
            valueBadge.Parent = row
            Corner(valueBadge, UDim.new(0, 5))

            local valueLabel = Instance.new("TextLabel")
            valueLabel.Size = UDim2.new(1, 0, 1, 0)
            valueLabel.BackgroundTransparency = 1
            valueLabel.Text = tostring(math.floor(value))
            valueLabel.TextColor3 = Theme.Accent
            valueLabel.TextSize = 13
            valueLabel.Font = Theme.Font
            valueLabel.ZIndex = 8
            valueLabel.Parent = valueBadge

            local track = Instance.new("Frame")
            track.Size = UDim2.new(0, 100, 0, 6)
            track.Position = UDim2.new(1, -112, 0.5, -3)
            track.BackgroundColor3 = Theme.SliderBg
            track.BorderSizePixel = 0
            track.ZIndex = 8
            track.Parent = row
            Corner(track, UDim.new(1, 0))

            local pct = (value - min) / math.max(max - min, 1)

            local fill = Instance.new("Frame")
            fill.Size = UDim2.new(pct, 0, 1, 0)
            fill.BackgroundColor3 = Theme.SliderFill
            fill.BorderSizePixel = 0
            fill.ZIndex = 9
            fill.Parent = track
            Corner(fill, UDim.new(1, 0))

            local knob = Instance.new("Frame")
            knob.Size = UDim2.new(0, 16, 0, 16)
            knob.Position = UDim2.new(pct, -8, 0.5, -8)
            knob.BackgroundColor3 = Theme.Text
            knob.BorderSizePixel = 0
            knob.ZIndex = 10
            knob.Parent = track
            Corner(knob, UDim.new(1, 0))
            Stroke(knob, Theme.Shadow, 1, 0.75)

            local sliding = false

            local hitArea = Instance.new("TextButton")
            hitArea.Size = UDim2.new(1, 14, 1, 18)
            hitArea.Position = UDim2.new(0, -7, 0, -9)
            hitArea.BackgroundTransparency = 1
            hitArea.Text = ""
            hitArea.ZIndex = 11
            hitArea.Parent = track

            local function UpdateVisual(val)
                local p = (val - min) / math.max(max - min, 1)
                valueLabel.Text = tostring(math.floor(val))
                fill.Size = UDim2.new(p, 0, 1, 0)
                knob.Position = UDim2.new(p, -8, 0.5, -8)
            end

            -- ✅ FIX: visuals only, no callback here
            ConfigManager:RegisterUpdater(labelText, function(val)
                if type(val) == "number" then
                    val = math.clamp(val, min, max)
                    value = val
                    UpdateVisual(val)
                end
            end)

            local function ProcessInput(input)
                local x = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                local v = math.floor(min + (max - min) * x)
                value = v
                ConfigManager:Set(labelText, v)
                UpdateVisual(v)
                if callback then task.spawn(callback, v) end
            end

            AddConnection(hitArea.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    sliding = true
                    ProcessInput(input)
                end
            end))
            AddConnection(hitArea.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    sliding = false
                end
            end))
            AddConnection(UserInputService.InputChanged:Connect(function(input)
                if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    ProcessInput(input)
                end
            end))

            SetupHover(row, RowColor(order), accentBar)

            return {
                Set = function(_, val)
                    val = math.clamp(val, min, max)
                    value = val
                    ConfigManager:Set(labelText, val)
                    UpdateVisual(val)
                end,
                Get = function() return value end,
            }
        end

        -- ── BUTTON ───────────────────────────────────────────

        function Tab:AddButton(labelText, callback)
            local order = NextOrder()

            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, Theme.RowHeight)
            row.BackgroundColor3 = RowColor(order)
            row.BorderSizePixel = 0
            row.LayoutOrder = order
            row.ZIndex = 6
            row.ClipsDescendants = true
            row.Parent = page
            Corner(row, Theme.CornerRadius)

            local accentBar = HoverAccent(row)

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -130, 1, 0)
            lbl.Position = UDim2.new(0, 18, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = labelText
            lbl.TextColor3 = Theme.Text
            lbl.TextSize = 14
            lbl.Font = Theme.FontLight
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.ZIndex = 7
            lbl.Parent = row

            local btnFrame = Instance.new("Frame")
            btnFrame.Size = UDim2.new(0, 100, 0, 32)
            btnFrame.Position = UDim2.new(1, -114, 0.5, -16)
            btnFrame.BackgroundTransparency = 1
            btnFrame.ZIndex = 7
            btnFrame.Parent = row

            local btnShadow = Instance.new("Frame")
            btnShadow.Size = UDim2.new(1, 2, 1, 2)
            btnShadow.Position = UDim2.new(0, -1, 0, 2)
            btnShadow.BackgroundColor3 = Theme.Shadow
            btnShadow.BackgroundTransparency = 0.82
            btnShadow.BorderSizePixel = 0
            btnShadow.ZIndex = 7
            btnShadow.Parent = btnFrame
            Corner(btnShadow, Theme.CornerRadius)

            local button = Instance.new("TextButton")
            button.Size = UDim2.new(1, -2, 1, -2)
            button.Position = UDim2.new(0, 1, 0, 0)
            button.BackgroundColor3 = Theme.Accent
            button.Text = "Execute"
            button.TextColor3 = Theme.Text
            button.TextSize = 13
            button.Font = Theme.Font
            button.BorderSizePixel = 0
            button.AutoButtonColor = false
            button.ZIndex = 8
            button.Parent = btnFrame
            Corner(button, Theme.CornerRadius)

            local glowStroke = Stroke(button, Theme.Accent, 1.5, 1)

            AddConnection(button.MouseEnter:Connect(function()
                Tween(button, {BackgroundColor3 = Theme.AccentLight}, 0.15)
                Tween(glowStroke, {Transparency = 0.5}, 0.2)
            end))
            AddConnection(button.MouseLeave:Connect(function()
                Tween(button, {BackgroundColor3 = Theme.Accent}, 0.15)
                Tween(glowStroke, {Transparency = 1}, 0.2)
            end))
            AddConnection(button.MouseButton1Click:Connect(function()
                Tween(button, {Size = UDim2.new(1, -6, 1, -4)}, 0.06)
                task.delay(0.06, function()
                    Tween(button, {Size = UDim2.new(1, -2, 1, -2)}, 0.1, Enum.EasingStyle.Back)
                end)
                if callback then task.spawn(callback) end
            end))

            SetupHover(row, RowColor(order), accentBar)
        end

        -- ── INPUT ────────────────────────────────────────────

        function Tab:AddInput(labelText, placeholder, callback)
            local order = NextOrder()

            local saved = StateStore[labelText]
            local currentText = (saved ~= nil and type(saved) == "string") and saved or ""
            StateStore[labelText] = currentText

            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, Theme.RowHeight)
            row.BackgroundColor3 = RowColor(order)
            row.BorderSizePixel = 0
            row.LayoutOrder = order
            row.ZIndex = 6
            row.ClipsDescendants = true
            row.Parent = page
            Corner(row, Theme.CornerRadius)

            local accentBar = HoverAccent(row)

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0, 140, 1, 0)
            lbl.Position = UDim2.new(0, 18, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = labelText
            lbl.TextColor3 = Theme.Text
            lbl.TextSize = 14
            lbl.Font = Theme.FontLight
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.ZIndex = 7
            lbl.Parent = row

            local inputBg = Instance.new("Frame")
            inputBg.Size = UDim2.new(0, 180, 0, 30)
            inputBg.Position = UDim2.new(1, -196, 0.5, -15)
            inputBg.BackgroundColor3 = Theme.InputBg
            inputBg.BorderSizePixel = 0
            inputBg.ZIndex = 8
            inputBg.Parent = row
            Corner(inputBg, UDim.new(0, 6))

            local glowStroke = Stroke(inputBg, Theme.Accent, 1.5, 1)

            local input = Instance.new("TextBox")
            input.Size = UDim2.new(1, -16, 1, 0)
            input.Position = UDim2.new(0, 8, 0, 0)
            input.BackgroundTransparency = 1
            input.Text = currentText
            input.PlaceholderText = placeholder or "Type here..."
            input.PlaceholderColor3 = Theme.TextDim
            input.TextColor3 = Theme.Text
            input.TextSize = 13
            input.Font = Theme.FontLight
            input.ClearTextOnFocus = false
            input.TextXAlignment = Enum.TextXAlignment.Left
            input.ZIndex = 9
            input.Parent = inputBg

            -- Input only needs visual restore (text is set directly)
            ConfigManager:RegisterUpdater(labelText, function(val)
                if type(val) == "string" then
                    input.Text = val
                end
            end)

            AddConnection(input.Focused:Connect(function()
                Tween(glowStroke, {Transparency = 0.4}, 0.2)
            end))
            AddConnection(input.FocusLost:Connect(function(enterPressed)
                Tween(glowStroke, {Transparency = 1}, 0.2)
                ConfigManager:Set(labelText, input.Text)
                if callback then task.spawn(callback, input.Text, enterPressed) end
            end))

            SetupHover(row, RowColor(order), accentBar)

            return {
                Set = function(_, val)
                    input.Text = val
                    ConfigManager:Set(labelText, val)
                end,
                Get = function() return input.Text end,
            }
        end

        -- ── DROPDOWN ─────────────────────────────────────────
        -- FIX: RegisterUpdater only updates visuals, NOT fires callback

        function Tab:AddDropdown(labelText, options, callback)
            local order = NextOrder()
            local isOpen = false

            local saved = StateStore[labelText]
            local selected = nil
            if saved ~= nil and type(saved) == "string" then
                for _, opt in ipairs(options) do
                    if opt == saved then selected = saved; break end
                end
            end
            StateStore[labelText] = selected

            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, Theme.RowHeight)
            row.BackgroundColor3 = RowColor(order)
            row.BorderSizePixel = 0
            row.LayoutOrder = order
            row.ZIndex = 6
            row.ClipsDescendants = false
            row.Parent = page
            Corner(row, Theme.CornerRadius)

            local accentBar = HoverAccent(row)

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0, 140, 1, 0)
            lbl.Position = UDim2.new(0, 18, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = labelText
            lbl.TextColor3 = Theme.Text
            lbl.TextSize = 14
            lbl.Font = Theme.FontLight
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.ZIndex = 7
            lbl.Parent = row

            local ddBtn = Instance.new("Frame")
            ddBtn.Size = UDim2.new(0, 180, 0, 30)
            ddBtn.Position = UDim2.new(1, -196, 0.5, -15)
            ddBtn.BackgroundColor3 = Theme.InputBg
            ddBtn.BorderSizePixel = 0
            ddBtn.ZIndex = 8
            ddBtn.Parent = row
            Corner(ddBtn, UDim.new(0, 6))
            Stroke(ddBtn, Theme.Border, 1, 0.5)

            local ddLabel = Instance.new("TextLabel")
            ddLabel.Size = UDim2.new(1, -32, 1, 0)
            ddLabel.Position = UDim2.new(0, 10, 0, 0)
            ddLabel.BackgroundTransparency = 1
            ddLabel.Text = selected or "Select..."
            ddLabel.TextColor3 = selected and Theme.Text or Theme.TextDim
            ddLabel.TextSize = 13
            ddLabel.Font = Theme.FontLight
            ddLabel.TextXAlignment = Enum.TextXAlignment.Left
            ddLabel.TextTruncate = Enum.TextTruncate.AtEnd
            ddLabel.ZIndex = 9
            ddLabel.Parent = ddBtn

            local arrow = Instance.new("TextLabel")
            arrow.Size = UDim2.new(0, 20, 1, 0)
            arrow.Position = UDim2.new(1, -24, 0, 0)
            arrow.BackgroundTransparency = 1
            arrow.Text = "▾"
            arrow.TextColor3 = Theme.Accent
            arrow.TextSize = 14
            arrow.Font = Theme.Font
            arrow.ZIndex = 9
            arrow.Parent = ddBtn

            local ddClick = Instance.new("TextButton")
            ddClick.Size = UDim2.new(1, 0, 1, 0)
            ddClick.BackgroundTransparency = 1
            ddClick.Text = ""
            ddClick.ZIndex = 10
            ddClick.Parent = ddBtn

            local panel = Instance.new("ScrollingFrame")
            panel.Size = UDim2.new(0, 180, 0, 0)
            panel.Position = UDim2.new(1, -196, 1, 4)
            panel.BackgroundColor3 = Theme.DropdownBg
            panel.BorderSizePixel = 0
            panel.ClipsDescendants = true
            panel.ScrollBarThickness = 3
            panel.ScrollBarImageColor3 = Theme.Accent
            panel.CanvasSize = UDim2.new(0, 0, 0, 0)
            panel.ZIndex = 50
            panel.Visible = false
            panel.Parent = row
            Corner(panel, UDim.new(0, 6))
            Stroke(panel, Theme.Accent, 1, 0.6)

            local panelLayout = ListLayout(panel, 2)
            Padding(panel, 4, 4, 4, 4)

            -- ✅ FIX: visuals only, no callback here
            ConfigManager:RegisterUpdater(labelText, function(val)
                if type(val) == "string" then
                    local valid = false
                    for _, opt in ipairs(options) do
                        if opt == val then valid = true; break end
                    end
                    if valid then
                        selected = val
                        ddLabel.Text = val
                        ddLabel.TextColor3 = Theme.Text
                    end
                end
            end)

            local function BuildOptions()
                for _, child in pairs(panel:GetChildren()) do
                    if child:IsA("TextButton") then child:Destroy() end
                end
                for i, opt in ipairs(options) do
                    local optBtn = Instance.new("TextButton")
                    optBtn.Size = UDim2.new(1, 0, 0, 30)
                    optBtn.BackgroundColor3 = (selected == opt) and Color3.fromRGB(40, 50, 65) or Theme.DropdownBg
                    optBtn.Text = opt
                    optBtn.TextColor3 = (selected == opt) and Theme.Accent or Theme.Text
                    optBtn.TextSize = 13
                    optBtn.Font = Theme.FontLight
                    optBtn.BorderSizePixel = 0
                    optBtn.AutoButtonColor = false
                    optBtn.LayoutOrder = i
                    optBtn.ZIndex = 51
                    optBtn.Parent = panel
                    Corner(optBtn, UDim.new(0, 5))

                    AddConnection(optBtn.MouseEnter:Connect(function()
                        if selected ~= opt then Tween(optBtn, {BackgroundColor3 = Theme.DropdownHover}, 0.1) end
                    end))
                    AddConnection(optBtn.MouseLeave:Connect(function()
                        if selected ~= opt then Tween(optBtn, {BackgroundColor3 = Theme.DropdownBg}, 0.1) end
                    end))
                    AddConnection(optBtn.MouseButton1Click:Connect(function()
                        selected = opt
                        ConfigManager:Set(labelText, opt)
                        ddLabel.Text = opt
                        ddLabel.TextColor3 = Theme.Text
                        isOpen = false
                        panel.Visible = false
                        panel.Size = UDim2.new(0, 180, 0, 0)
                        Tween(arrow, {Rotation = 0}, 0.2)
                        if callback then task.spawn(callback, opt) end
                    end))
                end
                panel.CanvasSize = UDim2.new(0, 0, 0, panelLayout.AbsoluteContentSize.Y + 10)
                return math.min(#options * 32 + 10, 160)
            end

            AddConnection(ddClick.MouseButton1Click:Connect(function()
                isOpen = not isOpen
                if isOpen then
                    local targetH = BuildOptions()
                    panel.Visible = true
                    panel.Size = UDim2.new(0, 180, 0, 0)
                    Tween(panel, {Size = UDim2.new(0, 180, 0, targetH)}, 0.25, Enum.EasingStyle.Quart)
                    Tween(arrow, {Rotation = 180}, 0.25)
                else
                    Tween(panel, {Size = UDim2.new(0, 180, 0, 0)}, 0.2)
                    Tween(arrow, {Rotation = 0}, 0.2)
                    task.delay(0.2, function() panel.Visible = false end)
                end
            end))

            SetupHover(row, RowColor(order), accentBar)

            -- ✅ FIX: fires callback ONCE if saved selection exists
            if selected and callback then
                task.defer(callback, selected)
            end

            return {
                Set = function(_, val)
                    selected = val
                    ConfigManager:Set(labelText, val)
                    ddLabel.Text = val or "Select..."
                    ddLabel.TextColor3 = val and Theme.Text or Theme.TextDim
                end,
                Get = function() return selected end,
                Refresh = function(_, newOptions)
                    options = newOptions
                    if isOpen then BuildOptions() end
                end,
            }
        end

        -- ── SEARCH BAR ───────────────────────────────────────

        function Tab:AddSearch(placeholder, callback)
            local order = NextOrder()

            local searchFrame = Instance.new("Frame")
            searchFrame.Size = UDim2.new(1, 0, 0, 40)
            searchFrame.BackgroundColor3 = Theme.InputBg
            searchFrame.BorderSizePixel = 0
            searchFrame.LayoutOrder = order
            searchFrame.ZIndex = 6
            searchFrame.Parent = page
            Corner(searchFrame, Theme.CornerRadius)

            local glowStroke = Stroke(searchFrame, Theme.Accent, 1.5, 1)

            local iconFrame = Instance.new("Frame")
            iconFrame.Size = UDim2.new(0, 16, 0, 16)
            iconFrame.Position = UDim2.new(0, 14, 0.5, -8)
            iconFrame.BackgroundTransparency = 1
            iconFrame.ZIndex = 8
            iconFrame.Parent = searchFrame

            local iconCircle = Instance.new("Frame")
            iconCircle.Size = UDim2.new(0, 11, 0, 11)
            iconCircle.BackgroundColor3 = Theme.TextDim
            iconCircle.BackgroundTransparency = 0.6
            iconCircle.BorderSizePixel = 0
            iconCircle.ZIndex = 9
            iconCircle.Parent = iconFrame
            Corner(iconCircle, UDim.new(1, 0))

            local iconHandle = Instance.new("Frame")
            iconHandle.Size = UDim2.new(0, 6, 0, 2)
            iconHandle.Position = UDim2.new(0, 9, 0, 11)
            iconHandle.BackgroundColor3 = Theme.TextDim
            iconHandle.BackgroundTransparency = 0.4
            iconHandle.Rotation = 45
            iconHandle.BorderSizePixel = 0
            iconHandle.ZIndex = 9
            iconHandle.Parent = iconFrame
            Corner(iconHandle, UDim.new(1, 0))

            local searchInput = Instance.new("TextBox")
            searchInput.Size = UDim2.new(1, -50, 1, 0)
            searchInput.Position = UDim2.new(0, 38, 0, 0)
            searchInput.BackgroundTransparency = 1
            searchInput.Text = ""
            searchInput.PlaceholderText = placeholder or "Search..."
            searchInput.PlaceholderColor3 = Theme.TextDim
            searchInput.TextColor3 = Theme.Text
            searchInput.TextSize = 14
            searchInput.Font = Theme.FontLight
            searchInput.ClearTextOnFocus = false
            searchInput.TextXAlignment = Enum.TextXAlignment.Left
            searchInput.ZIndex = 7
            searchInput.Parent = searchFrame

            AddConnection(searchInput.Focused:Connect(function()
                Tween(glowStroke, {Transparency = 0.4}, 0.2)
            end))
            AddConnection(searchInput.FocusLost:Connect(function()
                Tween(glowStroke, {Transparency = 1}, 0.2)
            end))
            AddConnection(searchInput:GetPropertyChangedSignal("Text"):Connect(function()
                if callback then task.spawn(callback, searchInput.Text) end
            end))

            return {
                Get   = function() return searchInput.Text end,
                Set   = function(_, val) searchInput.Text = val end,
                Clear = function() searchInput.Text = "" end,
            }
        end

        return Tab
    end

    -- ── WINDOW METHODS ───────────────────────────────────────

    function Window:Destroy()
        ConfigManager:Flush()
        DisconnectAll()
        if screenGui then screenGui:Destroy() end
    end

    function Window:Notify(ntitle, message, notifType, duration)
        GluttonyUI:Notify(ntitle, message, notifType, duration)
    end

    function Window:GetValue(vname)
        return StateStore[vname]
    end

    function Window:SetValue(vname, vvalue)
        ConfigManager:Set(vname, vvalue)
    end

    function Window:SaveConfig()
        ConfigManager:Save()
    end

    function Window:ClearConfig()
        StateStore = {}
        ConfigManager:Save()
    end

    -- Apply saved config to UI visuals after everything is built
    task.defer(function()
        ConfigManager:ApplyToUI()
    end)

    return Window
end

return GluttonyUI