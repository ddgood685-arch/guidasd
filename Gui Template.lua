--[[
═══════════════════════════════════════════════════════════════════════════
   GLUTTONY UI LIBRARY v2.1
   Built-in: Thread Manager, Auto-Resume, Anti-AFK, Number Parsing,
             PriorityList, RadioSelect, MultiSelect, StatusButton,
             NumberInput, ThresholdRow, Hint/Warning, Dropdown Flip
═══════════════════════════════════════════════════════════════════════════
]]

local GluttonyUI = {}

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local RunService       = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

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
    HintBg        = Color3.fromRGB(45, 40, 30),
    HintColor     = Color3.fromRGB(255, 200, 100),
    WarningBg     = Color3.fromRGB(50, 35, 30),
    WarningColor  = Color3.fromRGB(255, 120, 80),
    ProtectedOn   = Color3.fromRGB(60, 180, 90),
    ProtectedOff  = Color3.fromRGB(55, 55, 65),
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
-- NUMBER UTILITIES
-- ════════════════════════════════════════════════════════════════

local NumberSuffixes = {
    {"Dc", 1e33}, {"No", 1e30}, {"Oc", 1e27}, {"Sp", 1e24},
    {"Sx", 1e21}, {"Qi", 1e18}, {"Qa", 1e15}, {"T",  1e12},
    {"B",  1e9},  {"M",  1e6},  {"K",  1e3},
}

function GluttonyUI.FormatNumber(n)
    if not n or n == 0 then return "0" end
    for _, pair in ipairs(NumberSuffixes) do
        if math.abs(n) >= pair[2] then
            return string.format("%.1f%s", n / pair[2], pair[1])
        end
    end
    return tostring(math.floor(n))
end

function GluttonyUI.ParseNumber(input)
    if not input or input == "" then return 0 end
    input = tostring(input):gsub("%s+", ""):gsub("%$", ""):gsub(",", "")
    local num = tonumber(input)
    if num then return num end
    local value, suffix = input:match("^([%d%.]+)(%a+)$")
    if value and suffix then
        suffix = suffix:upper()
        local multipliers = {
            K=1e3, M=1e6, B=1e9, T=1e12,
            QA=1e15, QI=1e18, SX=1e21, SP=1e24,
            OC=1e27, NO=1e30, DC=1e33,
        }
        local mult = multipliers[suffix]
        if mult then
            local base = tonumber(value)
            if base then return base * mult end
        end
    end
    return tonumber(input) or 0
end

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
-- THREAD MANAGER
-- ════════════════════════════════════════════════════════════════

local ThreadManager = {}
local _activeThreads = {}
local _threadRunning = {}

function ThreadManager:Start(key, interval, callback)
    self:Stop(key)
    _threadRunning[key] = true
    _activeThreads[key] = task.spawn(function()
        while _threadRunning[key] do
            local success, err = pcall(callback)
            if not success then
                warn(string.format("[GluttonyUI][Thread][%s]: %s", key, tostring(err)))
            end
            if not _threadRunning[key] then break end
            local waitTime = (typeof(interval) == "function") and interval() or interval
            task.wait(waitTime or 1)
        end
        _activeThreads[key] = nil
        _threadRunning[key] = false
    end)
end

function ThreadManager:Stop(key)
    _threadRunning[key] = false
    if _activeThreads[key] then
        pcall(task.cancel, _activeThreads[key])
        _activeThreads[key] = nil
    end
end

function ThreadManager:StopAll()
    for key in pairs(_activeThreads) do
        self:Stop(key)
    end
end

function ThreadManager:IsRunning(key)
    return _threadRunning[key] == true
end

GluttonyUI.ThreadManager = ThreadManager

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
ConfigManager._toggleMeta = {}

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
-- ANTI-AFK
-- ════════════════════════════════════════════════════════════════

local _antiAfkRunning = false
local _antiAfkThread  = nil

local function StartAntiAFK()
    if _antiAfkRunning then return end
    _antiAfkRunning = true
    _antiAfkThread = task.spawn(function()
        local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
        while _antiAfkRunning do
            task.wait(10)
            if not _antiAfkRunning then break end
            pcall(function()
                if isMobile then
                    VirtualInputManager:SendGamepadKeyEvent(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonB, true, 1)
                    task.wait(0.1)
                    VirtualInputManager:SendGamepadKeyEvent(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonB, false, 1)
                else
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
                    task.wait(0.1)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
                end
            end)
        end
    end)
end

local function StopAntiAFK()
    _antiAfkRunning = false
    if _antiAfkThread then
        pcall(task.cancel, _antiAfkThread)
        _antiAfkThread = nil
    end
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
    l.FillDirection       = direction or Enum.FillDirection.Vertical
    l.SortOrder           = Enum.SortOrder.LayoutOrder
    l.Padding             = UDim.new(0, padding or 6)
    l.HorizontalAlignment = Enum.HorizontalAlignment.Center
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
    layout.FillDirection     = Enum.FillDirection.Vertical
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    layout.SortOrder         = Enum.SortOrder.LayoutOrder
    layout.Padding           = UDim.new(0, 8)
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

    local imageLabel = Instance.new("ImageLabel")
    imageLabel.Size = UDim2.new(1, 0, 1, 0)
    imageLabel.BackgroundTransparency = 1
    imageLabel.ScaleType = Enum.ScaleType.Fit
    imageLabel.ZIndex = 13
    imageLabel.Parent = container
    Corner(imageLabel, UDim.new(1, 0))

    local logoLoaded = false
    pcall(function()
        local imageUrl = "https://i.imgur.com/cThW0xR.png"
        local fileName = "logo_v2.png"
        if isfile and isfile(fileName) then
            if delfile then delfile(fileName) end
        end
        local response = nil
        if syn and syn.request then
            response = syn.request({Url = imageUrl, Method = "GET"})
        elseif http_request then
            response = http_request({Url = imageUrl, Method = "GET"})
        elseif request then
            response = request({Url = imageUrl, Method = "GET"})
        end
        if response and response.Body and #response.Body > 0 then
            if writefile then writefile(fileName, response.Body) end
            if getcustomasset then
                imageLabel.Image = getcustomasset(fileName)
                logoLoaded = true
            elseif getsynasset then
                imageLabel.Image = getsynasset(fileName)
                logoLoaded = true
            end
        end
    end)

    if not logoLoaded then
        imageLabel:Destroy()
        local ring = Instance.new("Frame")
        ring.Size = UDim2.new(1, 0, 1, 0)
        ring.BackgroundColor3 = Theme.Accent
        ring.BackgroundTransparency = 0.6
        ring.BorderSizePixel = 0
        ring.ZIndex = 12
        ring.Parent = container
        Corner(ring, UDim.new(1, 0))

        local innerDot = Instance.new("Frame")
        innerDot.Size = UDim2.new(0, 18, 0, 18)
        innerDot.AnchorPoint = Vector2.new(0.5, 0.5)
        innerDot.Position = UDim2.new(0.5, 0, 0.5, 0)
        innerDot.BackgroundColor3 = Theme.Accent
        innerDot.BorderSizePixel = 0
        innerDot.ZIndex = 13
        innerDot.Parent = container
        Corner(innerDot, UDim.new(1, 0))

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

    local iconMap = {
        ["circle"]   = "●", ["square"]   = "■", ["diamond"]  = "◆",
        ["bars"]     = "≡", ["triangle"] = "▶", ["dot-grid"] = "⊞",
        ["settings"] = "⚙", ["bolt"]     = "⚡", ["shield"]   = "⛨",
        ["star"]     = "★",
    }

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(1, 0, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = iconMap[iconType] or "●"
    iconLabel.TextColor3 = Theme.Accent
    iconLabel.TextSize = 16
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.ZIndex = 10
    iconLabel.Parent = container
end

local IconTypes = {"circle", "square", "diamond", "bars", "triangle", "dot-grid", "bolt", "star", "shield"}

-- ════════════════════════════════════════════════════════════════
-- CREATE WINDOW
-- ════════════════════════════════════════════════════════════════

function GluttonyUI:CreateWindow(options)
    if type(options) == "string" then
        options = {Title = options}
    end
    options = options or {}

    local title      = options.Title or "Gluttony Core"
    local configName = options.ConfigName
    local antiAfk    = options.AntiAFK

    -- Cleanup previous
    for _, v in pairs(playerGui:GetChildren()) do
        if v.Name == "GluttonyUILib" then v:Destroy() end
    end
    DisconnectAll()
    ThreadManager:StopAll()
    StopAntiAFK()
    StateStore = {}
    ConfigManager._uiUpdaters = {}
    ConfigManager._toggleMeta = {}

    ConfigManager:Init(configName)
    ConfigManager:Load()

    if antiAfk then StartAntiAFK() end

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
    inner.Name = "Inner"
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
        ThreadManager:StopAll()
        StopAntiAFK()
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
    content.ClipsDescendants = false
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

    AddConnection(Players.PlayerRemoving:Connect(function(plr)
        if plr == player then
            ConfigManager:Flush()
            ThreadManager:StopAll()
            StopAntiAFK()
        end
    end))

    -- ════════════════════════════════════════════════════════
    -- WINDOW OBJECT
    -- ════════════════════════════════════════════════════════

    local Window = {}
    Window._pages      = {}
    Window._tabButtons = {}
    Window._currentTab = nil
    Window._tabCount   = 0

    local activeDropdownPanel = nil

    local function SwitchTab(tabName)
        if activeDropdownPanel and activeDropdownPanel.Parent then
            activeDropdownPanel.Visible = false
            activeDropdownPanel.Size = UDim2.new(0, 0, 0, 0)
            activeDropdownPanel = nil
        end
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
        ulGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.7,0),NumberSequenceKeypoint.new(1,1)})
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
            sepGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.5,0.3),NumberSequenceKeypoint.new(1,1)})
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

        -- ── SPACER ───────────────────────────────────────────
        function Tab:AddSpacer(height)
            local order = NextOrder()
            local spacer = Instance.new("Frame")
            spacer.Size = UDim2.new(1, 0, 0, height or 16)
            spacer.BackgroundTransparency = 1
            spacer.LayoutOrder = order
            spacer.Parent = page
        end

        -- ── HINT ─────────────────────────────────────────────
        function Tab:AddHint(text)
            local order = NextOrder()
            local hintFrame = Instance.new("Frame")
            hintFrame.Size = UDim2.new(1, 0, 0, 56)
            hintFrame.BackgroundColor3 = Theme.HintBg
            hintFrame.BorderSizePixel = 0
            hintFrame.LayoutOrder = order
            hintFrame.ZIndex = 6
            hintFrame.Parent = page
            Corner(hintFrame, Theme.CornerRadius)
            Stroke(hintFrame, Theme.HintColor, 1, 0.5)

            local iconBg = Instance.new("Frame")
            iconBg.Size = UDim2.new(0, 32, 0, 32)
            iconBg.Position = UDim2.new(0, 12, 0.5, -16)
            iconBg.BackgroundColor3 = Theme.HintColor
            iconBg.BackgroundTransparency = 0.85
            iconBg.BorderSizePixel = 0
            iconBg.ZIndex = 7
            iconBg.Parent = hintFrame
            Corner(iconBg, UDim.new(0, 6))

            local iconLabel = Instance.new("TextLabel")
            iconLabel.Size = UDim2.new(1, 0, 1, 0)
            iconLabel.BackgroundTransparency = 1
            iconLabel.Text = "💡"
            iconLabel.TextSize = 16
            iconLabel.ZIndex = 8
            iconLabel.Parent = iconBg

            local hintText = Instance.new("TextLabel")
            hintText.Size = UDim2.new(1, -60, 1, -16)
            hintText.Position = UDim2.new(0, 52, 0, 8)
            hintText.BackgroundTransparency = 1
            hintText.Text = text
            hintText.TextColor3 = Theme.HintColor
            hintText.TextSize = 13
            hintText.Font = Theme.FontLight
            hintText.TextXAlignment = Enum.TextXAlignment.Left
            hintText.TextWrapped = true
            hintText.ZIndex = 7
            hintText.Parent = hintFrame
            return hintFrame
        end

        -- ── WARNING ──────────────────────────────────────────
        function Tab:AddWarning(text)
            local order = NextOrder()
            local warnFrame = Instance.new("Frame")
            warnFrame.Size = UDim2.new(1, 0, 0, 56)
            warnFrame.BackgroundColor3 = Theme.WarningBg
            warnFrame.BorderSizePixel = 0
            warnFrame.LayoutOrder = order
            warnFrame.ZIndex = 6
            warnFrame.Parent = page
            Corner(warnFrame, Theme.CornerRadius)
            Stroke(warnFrame, Theme.WarningColor, 1, 0.5)

            local iconBg = Instance.new("Frame")
            iconBg.Size = UDim2.new(0, 32, 0, 32)
            iconBg.Position = UDim2.new(0, 12, 0.5, -16)
            iconBg.BackgroundColor3 = Theme.WarningColor
            iconBg.BackgroundTransparency = 0.85
            iconBg.BorderSizePixel = 0
            iconBg.ZIndex = 7
            iconBg.Parent = warnFrame
            Corner(iconBg, UDim.new(0, 6))

            local iconLabel = Instance.new("TextLabel")
            iconLabel.Size = UDim2.new(1, 0, 1, 0)
            iconLabel.BackgroundTransparency = 1
            iconLabel.Text = "⚠️"
            iconLabel.TextSize = 16
            iconLabel.ZIndex = 8
            iconLabel.Parent = iconBg

            local warnText = Instance.new("TextLabel")
            warnText.Size = UDim2.new(1, -60, 1, -16)
            warnText.Position = UDim2.new(0, 52, 0, 8)
            warnText.BackgroundTransparency = 1
            warnText.Text = text
            warnText.TextColor3 = Theme.WarningColor
            warnText.TextSize = 13
            warnText.Font = Theme.FontLight
            warnText.TextXAlignment = Enum.TextXAlignment.Left
            warnText.TextWrapped = true
            warnText.ZIndex = 7
            warnText.Parent = warnFrame
            return warnFrame
        end

        -- ── TOGGLE (with optional interval for thread manager) ──
        function Tab:AddToggle(labelText, default, intervalOrCallback, callbackOrNil)
            local order = NextOrder()
            local interval, callback

            if type(intervalOrCallback) == "function" then
                interval = nil
                callback = intervalOrCallback
            else
                interval = intervalOrCallback
                callback = callbackOrNil
            end

            local saved = StateStore[labelText]
            local state = (saved ~= nil) and saved or (default or false)
            StateStore[labelText] = state

            if interval and callback then
                ConfigManager._toggleMeta[labelText] = {interval = interval, callback = callback}
            end

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

            ConfigManager:RegisterUpdater(labelText, function(val)
                if type(val) == "boolean" then UpdateVisual(val) end
            end)

            local function SetState(newState)
                state = newState
                ConfigManager:Set(labelText, state)
                Tween(toggleBg, {BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff}, 0.25)
                Tween(circle, {Position = state and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)}, 0.25, Enum.EasingStyle.Back)
                Tween(circle, {Size = UDim2.new(0, 22, 0, 22)}, 0.08)
                task.delay(0.08, function() Tween(circle, {Size = UDim2.new(0, 20, 0, 20)}, 0.12) end)

                if interval and callback then
                    if state then
                        ThreadManager:Start(labelText, interval, callback)
                    else
                        ThreadManager:Stop(labelText)
                    end
                elseif callback then
                    task.spawn(callback, state)
                end
            end

            AddConnection(btn.MouseButton1Click:Connect(function()
                SetState(not state)
            end))

            SetupHover(row, RowColor(order), accentBar)

            if state then
                if interval and callback then
                    task.defer(function() ThreadManager:Start(labelText, interval, callback) end)
                elseif callback then
                    task.defer(callback, state)
                end
            end

            return {
                Set = function(_, val) SetState(val) end,
                Get = function() return state end,
            }
        end

        -- ── SLIDER ───────────────────────────────────────────
        function Tab:AddSlider(labelText, min, max, default, callback)
            local order = NextOrder()

            local saved = StateStore[labelText]
            local value = (saved ~= nil and type(saved) == "number") and math.clamp(saved, min, max) or math.clamp(default or min, min, max)
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

            ConfigManager:RegisterUpdater(labelText, function(val)
                if type(val) == "number" then val = math.clamp(val, min, max); value = val; UpdateVisual(val) end
            end)

            local function ProcessInput(input)
                local x = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                local v = math.floor(min + (max - min) * x)
                value = v; ConfigManager:Set(labelText, v); UpdateVisual(v)
                if callback then task.spawn(callback, v) end
            end

            AddConnection(hitArea.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    sliding = true; ProcessInput(input)
                end
            end))
            AddConnection(hitArea.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then sliding = false end
            end))
            AddConnection(UserInputService.InputChanged:Connect(function(input)
                if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then ProcessInput(input) end
            end))

            SetupHover(row, RowColor(order), accentBar)

            return {
                Set = function(_, val) val = math.clamp(val, min, max); value = val; ConfigManager:Set(labelText, val); UpdateVisual(val) end,
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
                task.delay(0.06, function() Tween(button, {Size = UDim2.new(1, -2, 1, -2)}, 0.1, Enum.EasingStyle.Back) end)
                if callback then task.spawn(callback) end
            end))

            SetupHover(row, RowColor(order), accentBar)
        end

        -- ── STATUS BUTTON ────────────────────────────────────
        function Tab:AddStatusButton(labelText, callback)
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
            local busy = false

            local function SetStatus(statusType, msg)
                if statusType == "loading" then
                    button.Text = "..."
                    Tween(button, {BackgroundColor3 = Color3.fromRGB(100, 100, 100)}, 0.15)
                elseif statusType == "success" then
                    button.Text = "✅ " .. (msg or "Done")
                    Tween(button, {BackgroundColor3 = Theme.NotifSuccess}, 0.2)
                    task.delay(1.5, function()
                        if button and button.Parent then
                            button.Text = "Execute"
                            Tween(button, {BackgroundColor3 = Theme.Accent}, 0.2)
                            busy = false
                        end
                    end)
                elseif statusType == "error" then
                    button.Text = "❌ " .. (msg or "Failed")
                    Tween(button, {BackgroundColor3 = Theme.NotifError}, 0.2)
                    task.delay(1.5, function()
                        if button and button.Parent then
                            button.Text = "Execute"
                            Tween(button, {BackgroundColor3 = Theme.Accent}, 0.2)
                            busy = false
                        end
                    end)
                else
                    button.Text = msg or "Execute"
                    Tween(button, {BackgroundColor3 = Theme.Accent}, 0.2)
                    busy = false
                end
            end

            AddConnection(button.MouseEnter:Connect(function()
                if not busy then Tween(button, {BackgroundColor3 = Theme.AccentLight}, 0.15); Tween(glowStroke, {Transparency = 0.5}, 0.2) end
            end))
            AddConnection(button.MouseLeave:Connect(function()
                if not busy then Tween(button, {BackgroundColor3 = Theme.Accent}, 0.15); Tween(glowStroke, {Transparency = 1}, 0.2) end
            end))
            AddConnection(button.MouseButton1Click:Connect(function()
                if busy then return end
                busy = true
                Tween(button, {Size = UDim2.new(1, -6, 1, -4)}, 0.06)
                task.delay(0.06, function() Tween(button, {Size = UDim2.new(1, -2, 1, -2)}, 0.1, Enum.EasingStyle.Back) end)
                if callback then task.spawn(callback, SetStatus) end
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

            ConfigManager:RegisterUpdater(labelText, function(val)
                if type(val) == "string" then input.Text = val end
            end)

            AddConnection(input.Focused:Connect(function() Tween(glowStroke, {Transparency = 0.4}, 0.2) end))
            AddConnection(input.FocusLost:Connect(function(enterPressed)
                Tween(glowStroke, {Transparency = 1}, 0.2)
                ConfigManager:Set(labelText, input.Text)
                if callback then task.spawn(callback, input.Text, enterPressed) end
            end))

            SetupHover(row, RowColor(order), accentBar)
            return { Set = function(_, val) input.Text = val; ConfigManager:Set(labelText, val) end, Get = function() return input.Text end }
        end

        -- ── NUMBER INPUT ─────────────────────────────────────
        function Tab:AddNumberInput(labelText, default, callback)
            local order = NextOrder()
            local saved = StateStore[labelText]
            local value = (saved ~= nil and type(saved) == "number") and saved or (default or 0)
            StateStore[labelText] = value

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
            inputBg.Size = UDim2.new(0, 120, 0, 30)
            inputBg.Position = UDim2.new(1, -136, 0.5, -15)
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
            input.Text = value > 0 and GluttonyUI.FormatNumber(value) or "0"
            input.PlaceholderText = "e.g. 5M"
            input.PlaceholderColor3 = Theme.TextDim
            input.TextColor3 = Theme.Text
            input.TextSize = 13
            input.Font = Theme.FontLight
            input.ClearTextOnFocus = false
            input.TextXAlignment = Enum.TextXAlignment.Center
            input.ZIndex = 9
            input.Parent = inputBg

            ConfigManager:RegisterUpdater(labelText, function(val)
                if type(val) == "number" then value = val; input.Text = val > 0 and GluttonyUI.FormatNumber(val) or "0" end
            end)

            AddConnection(input.Focused:Connect(function() Tween(glowStroke, {Transparency = 0.4}, 0.2) end))
            AddConnection(input.FocusLost:Connect(function()
                Tween(glowStroke, {Transparency = 1}, 0.2)
                local parsed = GluttonyUI.ParseNumber(input.Text)
                value = parsed; ConfigManager:Set(labelText, parsed)
                input.Text = parsed > 0 and GluttonyUI.FormatNumber(parsed) or "0"
                if callback then task.spawn(callback, parsed) end
            end))

            SetupHover(row, RowColor(order), accentBar)
            return {
                Set = function(_, val) value = val; ConfigManager:Set(labelText, val); input.Text = val > 0 and GluttonyUI.FormatNumber(val) or "0" end,
                Get = function() return value end,
            }
        end

        -- ── THRESHOLD ROW (Toggle + NumberInput + StatusButton in one row) ──
        function Tab:AddThresholdRow(labelText, opts)
            opts = opts or {}
            local order = NextOrder()
            local threshDefault = opts.Default or 0
            local interval      = opts.Interval or 1
            local buttonText    = opts.ButtonText or "Sell"
            local onLoop        = opts.OnLoop
            local onButton      = opts.OnButton

            local toggleKey = labelText .. "_enabled"
            local threshKey = labelText .. "_threshold"

            -- Restore saved
            local savedToggle = StateStore[toggleKey]
            local toggleState = (savedToggle ~= nil) and savedToggle or false
            StateStore[toggleKey] = toggleState

            local savedThresh = StateStore[threshKey]
            local threshValue = (savedThresh ~= nil and type(savedThresh) == "number") and savedThresh or threshDefault
            StateStore[threshKey] = threshValue

            -- Row (taller for 3 elements)
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 56)
            row.BackgroundColor3 = RowColor(order)
            row.BorderSizePixel = 0
            row.LayoutOrder = order
            row.ZIndex = 6
            row.ClipsDescendants = true
            row.Parent = page
            Corner(row, Theme.CornerRadius)
            Stroke(row, Theme.Border, 1, 0.5)

            local accentBar = HoverAccent(row)

            -- Label
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0, 90, 1, 0)
            lbl.Position = UDim2.new(0, 18, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = labelText
            lbl.TextColor3 = Theme.Text
            lbl.TextSize = 14
            lbl.Font = Theme.Font
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.ZIndex = 7
            lbl.Parent = row

            -- Toggle
            local toggleBg = Instance.new("Frame")
            toggleBg.Size = UDim2.new(0, 42, 0, 22)
            toggleBg.Position = UDim2.new(0, 110, 0.5, -11)
            toggleBg.BackgroundColor3 = toggleState and Theme.ToggleOn or Theme.ToggleOff
            toggleBg.BorderSizePixel = 0
            toggleBg.ZIndex = 8
            toggleBg.Parent = row
            Corner(toggleBg, UDim.new(1, 0))

            local toggleCircle = Instance.new("Frame")
            toggleCircle.Size = UDim2.new(0, 18, 0, 18)
            toggleCircle.Position = toggleState and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
            toggleCircle.BackgroundColor3 = Theme.Text
            toggleCircle.BorderSizePixel = 0
            toggleCircle.ZIndex = 9
            toggleCircle.Parent = toggleBg
            Corner(toggleCircle, UDim.new(1, 0))
            Stroke(toggleCircle, Theme.Shadow, 1, 0.7)

            local toggleBtn = Instance.new("TextButton")
            toggleBtn.Size = UDim2.new(1, 0, 1, 0)
            toggleBtn.BackgroundTransparency = 1
            toggleBtn.Text = ""
            toggleBtn.ZIndex = 10
            toggleBtn.Parent = toggleBg

            -- Threshold input
            local threshBg = Instance.new("Frame")
            threshBg.Size = UDim2.new(0, 80, 0, 30)
            threshBg.Position = UDim2.new(0, 164, 0.5, -15)
            threshBg.BackgroundColor3 = Theme.InputBg
            threshBg.BorderSizePixel = 0
            threshBg.ZIndex = 8
            threshBg.Parent = row
            Corner(threshBg, UDim.new(0, 6))

            local threshGlow = Stroke(threshBg, Theme.Accent, 1.5, 1)

            local threshInput = Instance.new("TextBox")
            threshInput.Size = UDim2.new(1, -12, 1, 0)
            threshInput.Position = UDim2.new(0, 6, 0, 0)
            threshInput.BackgroundTransparency = 1
            threshInput.Text = threshValue > 0 and GluttonyUI.FormatNumber(threshValue) or "0"
            threshInput.PlaceholderText = "e.g. 5M"
            threshInput.PlaceholderColor3 = Theme.TextDim
            threshInput.TextColor3 = Theme.Text
            threshInput.TextSize = 13
            threshInput.Font = Theme.FontLight
            threshInput.ClearTextOnFocus = false
            threshInput.TextXAlignment = Enum.TextXAlignment.Center
            threshInput.ZIndex = 9
            threshInput.Parent = threshBg

            AddConnection(threshInput.Focused:Connect(function() Tween(threshGlow, {Transparency = 0.4}, 0.2) end))
            AddConnection(threshInput.FocusLost:Connect(function()
                Tween(threshGlow, {Transparency = 1}, 0.2)
                local parsed = GluttonyUI.ParseNumber(threshInput.Text)
                threshValue = parsed
                ConfigManager:Set(threshKey, parsed)
                threshInput.Text = parsed > 0 and GluttonyUI.FormatNumber(parsed) or "0"
                -- Restart thread if running with new threshold
                if toggleState and onLoop then
                    ThreadManager:Start(toggleKey, interval, function() onLoop(threshValue) end)
                end
            end))

            -- Action button
            local actionFrame = Instance.new("Frame")
            actionFrame.Size = UDim2.new(0, 72, 0, 32)
            actionFrame.Position = UDim2.new(1, -86, 0.5, -16)
            actionFrame.BackgroundTransparency = 1
            actionFrame.ZIndex = 7
            actionFrame.Parent = row

            local actionShadow = Instance.new("Frame")
            actionShadow.Size = UDim2.new(1, 2, 1, 2)
            actionShadow.Position = UDim2.new(0, -1, 0, 2)
            actionShadow.BackgroundColor3 = Theme.Shadow
            actionShadow.BackgroundTransparency = 0.82
            actionShadow.BorderSizePixel = 0
            actionShadow.ZIndex = 7
            actionShadow.Parent = actionFrame
            Corner(actionShadow, UDim.new(0, 6))

            local actionBtn = Instance.new("TextButton")
            actionBtn.Size = UDim2.new(1, -2, 1, -2)
            actionBtn.Position = UDim2.new(0, 1, 0, 0)
            actionBtn.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
            actionBtn.Text = buttonText
            actionBtn.TextColor3 = Theme.Text
            actionBtn.TextSize = 13
            actionBtn.Font = Theme.Font
            actionBtn.BorderSizePixel = 0
            actionBtn.AutoButtonColor = false
            actionBtn.ZIndex = 8
            actionBtn.Parent = actionFrame
            Corner(actionBtn, UDim.new(0, 6))

            local actionGlow = Stroke(actionBtn, Color3.fromRGB(200, 30, 30), 1.5, 0.6)
            local actionBusy = false

            local function SetActionStatus(statusType, msg)
                if statusType == "loading" then
                    actionBtn.Text = "..."
                    Tween(actionBtn, {BackgroundColor3 = Color3.fromRGB(100, 100, 100)}, 0.15)
                elseif statusType == "success" then
                    actionBtn.Text = "✅ " .. (msg or "")
                    Tween(actionBtn, {BackgroundColor3 = Theme.NotifSuccess}, 0.2)
                    task.delay(1.5, function()
                        if actionBtn and actionBtn.Parent then
                            actionBtn.Text = buttonText
                            Tween(actionBtn, {BackgroundColor3 = Color3.fromRGB(200, 30, 30)}, 0.2)
                            actionBusy = false
                        end
                    end)
                elseif statusType == "error" then
                    actionBtn.Text = "❌"
                    Tween(actionBtn, {BackgroundColor3 = Theme.NotifError}, 0.2)
                    task.delay(1.5, function()
                        if actionBtn and actionBtn.Parent then
                            actionBtn.Text = buttonText
                            Tween(actionBtn, {BackgroundColor3 = Color3.fromRGB(200, 30, 30)}, 0.2)
                            actionBusy = false
                        end
                    end)
                else
                    actionBtn.Text = buttonText
                    Tween(actionBtn, {BackgroundColor3 = Color3.fromRGB(200, 30, 30)}, 0.2)
                    actionBusy = false
                end
            end

            AddConnection(actionBtn.MouseEnter:Connect(function()
                if not actionBusy then Tween(actionBtn, {BackgroundColor3 = Color3.fromRGB(220, 50, 50)}, 0.15) end
            end))
            AddConnection(actionBtn.MouseLeave:Connect(function()
                if not actionBusy then Tween(actionBtn, {BackgroundColor3 = Color3.fromRGB(200, 30, 30)}, 0.15) end
            end))
            AddConnection(actionBtn.MouseButton1Click:Connect(function()
                if actionBusy then return end
                actionBusy = true
                Tween(actionBtn, {Size = UDim2.new(1, -6, 1, -4)}, 0.06)
                task.delay(0.06, function() Tween(actionBtn, {Size = UDim2.new(1, -2, 1, -2)}, 0.1, Enum.EasingStyle.Back) end)
                if onButton then task.spawn(onButton, threshValue, SetActionStatus) end
            end))

            -- Toggle logic
            AddConnection(toggleBtn.MouseButton1Click:Connect(function()
                toggleState = not toggleState
                ConfigManager:Set(toggleKey, toggleState)

                Tween(toggleBg, {BackgroundColor3 = toggleState and Theme.ToggleOn or Theme.ToggleOff}, 0.25)
                Tween(toggleCircle, {Position = toggleState and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)}, 0.25, Enum.EasingStyle.Back)
                Tween(toggleCircle, {Size = UDim2.new(0, 20, 0, 20)}, 0.08)
                task.delay(0.08, function() Tween(toggleCircle, {Size = UDim2.new(0, 18, 0, 18)}, 0.12) end)

                if toggleState then
                    if threshValue <= 0 then
                        toggleState = false
                        ConfigManager:Set(toggleKey, false)
                        Tween(toggleBg, {BackgroundColor3 = Theme.ToggleOff}, 0.2)
                        Tween(toggleCircle, {Position = UDim2.new(0, 2, 0.5, -9)}, 0.2)
                        return
                    end
                    if onLoop then
                        ThreadManager:Start(toggleKey, interval, function() onLoop(threshValue) end)
                    end
                else
                    ThreadManager:Stop(toggleKey)
                end
            end))

            SetupHover(row, RowColor(order), accentBar)

            -- Auto-resume
            if toggleState and threshValue > 0 and onLoop then
                task.defer(function()
                    ThreadManager:Start(toggleKey, interval, function() onLoop(threshValue) end)
                end)
            end

            return {
                GetThreshold = function() return threshValue end,
                GetToggle = function() return toggleState end,
                SetThreshold = function(_, val)
                    threshValue = val
                    ConfigManager:Set(threshKey, val)
                    threshInput.Text = val > 0 and GluttonyUI.FormatNumber(val) or "0"
                end,
            }
        end

        -- ── DROPDOWN (with flip support) ─────────────────────
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
            row.ZIndex = 10
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
            lbl.ZIndex = 11
            lbl.Parent = row

            local ddBtn = Instance.new("Frame")
            ddBtn.Size = UDim2.new(0, 180, 0, 30)
            ddBtn.Position = UDim2.new(1, -196, 0.5, -15)
            ddBtn.BackgroundColor3 = Theme.InputBg
            ddBtn.BorderSizePixel = 0
            ddBtn.ZIndex = 12
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
            ddLabel.ZIndex = 13
            ddLabel.Parent = ddBtn

            local arrowFrame = Instance.new("Frame")
            arrowFrame.Size = UDim2.new(0, 12, 0, 12)
            arrowFrame.Position = UDim2.new(1, -22, 0.5, -6)
            arrowFrame.BackgroundTransparency = 1
            arrowFrame.ZIndex = 13
            arrowFrame.Parent = ddBtn

            local arrowLeft = Instance.new("Frame")
            arrowLeft.Size = UDim2.new(0, 7, 0, 2)
            arrowLeft.Position = UDim2.new(0, 0, 0.5, -1)
            arrowLeft.AnchorPoint = Vector2.new(0, 0.5)
            arrowLeft.BackgroundColor3 = Theme.Accent
            arrowLeft.Rotation = 35
            arrowLeft.BorderSizePixel = 0
            arrowLeft.Parent = arrowFrame
            Corner(arrowLeft, UDim.new(1, 0))

            local arrowRight = Instance.new("Frame")
            arrowRight.Size = UDim2.new(0, 7, 0, 2)
            arrowRight.Position = UDim2.new(1, 0, 0.5, -1)
            arrowRight.AnchorPoint = Vector2.new(1, 0.5)
            arrowRight.BackgroundColor3 = Theme.Accent
            arrowRight.Rotation = -35
            arrowRight.BorderSizePixel = 0
            arrowRight.Parent = arrowFrame
            Corner(arrowRight, UDim.new(1, 0))

            local ddClick = Instance.new("TextButton")
            ddClick.Size = UDim2.new(1, 0, 1, 0)
            ddClick.BackgroundTransparency = 1
            ddClick.Text = ""
            ddClick.ZIndex = 14
            ddClick.Parent = ddBtn

            local panel = Instance.new("ScrollingFrame")
            panel.Size = UDim2.new(0, 0, 0, 0)
            panel.BackgroundColor3 = Theme.DropdownBg
            panel.BorderSizePixel = 0
            panel.ClipsDescendants = true
            panel.ScrollBarThickness = 3
            panel.ScrollBarImageColor3 = Theme.Accent
            panel.ZIndex = 500
            panel.Visible = false
            panel.Parent = inner
            Corner(panel, UDim.new(0, 6))
            Stroke(panel, Theme.Accent, 1, 0.6)

            local panelLayout = ListLayout(panel, 2)
            Padding(panel, 4, 4, 4, 4)

            local trackingConnection = nil
            local flippedUp = false

            local function GetPanelPosition(targetH)
                local ddAbs = ddBtn.AbsolutePosition
                local ddSize = ddBtn.AbsoluteSize
                local innerAbs = inner.AbsolutePosition
                local innerSize = inner.AbsoluteSize

                local relX = ddAbs.X - innerAbs.X
                local relYBelow = ddAbs.Y - innerAbs.Y + ddSize.Y + 4
                local relYAbove = ddAbs.Y - innerAbs.Y - targetH - 4

                -- Check if dropdown goes below the inner frame
                local bottomEdge = relYBelow + targetH
                if bottomEdge > innerSize.Y and relYAbove >= 0 then
                    flippedUp = true
                    return UDim2.new(0, relX, 0, relYAbove)
                else
                    flippedUp = false
                    return UDim2.new(0, relX, 0, relYBelow)
                end
            end

            local function GetPanelSize(targetH)
                return UDim2.new(0, ddBtn.AbsoluteSize.X, 0, targetH)
            end

            local function StartTrackingPosition(targetH)
                if trackingConnection then return end
                trackingConnection = RunService.Heartbeat:Connect(function()
                    if isOpen and panel.Visible then
                        panel.Position = GetPanelPosition(targetH)
                    end
                end)
            end

            local function StopTrackingPosition()
                if trackingConnection then
                    trackingConnection:Disconnect()
                    trackingConnection = nil
                end
            end

            ConfigManager:RegisterUpdater(labelText, function(val)
                if type(val) == "string" then selected = val; ddLabel.Text = val; ddLabel.TextColor3 = Theme.Text end
            end)

            local currentTargetH = 0

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
                    optBtn.ZIndex = 501
                    optBtn.Parent = panel
                    Corner(optBtn, UDim.new(0, 5))

                    AddConnection(optBtn.MouseButton1Click:Connect(function()
                        selected = opt
                        ConfigManager:Set(labelText, opt)
                        ddLabel.Text = opt
                        ddLabel.TextColor3 = Theme.Text
                        isOpen = false
                        activeDropdownPanel = nil
                        StopTrackingPosition()
                        Tween(panel, {Size = GetPanelSize(0)}, 0.2)
                        Tween(arrowFrame, {Rotation = 0}, 0.2)
                        task.delay(0.2, function() panel.Visible = false end)
                        if callback then task.spawn(callback, opt) end
                    end))
                end
                panel.CanvasSize = UDim2.new(0, 0, 0, panelLayout.AbsoluteContentSize.Y + 10)
                currentTargetH = math.min(#options * 32 + 10, 160)
                return currentTargetH
            end

            AddConnection(ddClick.MouseButton1Click:Connect(function()
                isOpen = not isOpen
                if isOpen then
                    if activeDropdownPanel and activeDropdownPanel ~= panel then
                        activeDropdownPanel.Visible = false
                        activeDropdownPanel.Size = UDim2.new(0, 0, 0, 0)
                    end
                    activeDropdownPanel = panel
                    local targetH = BuildOptions()
                    panel.Position = GetPanelPosition(targetH)
                    panel.Size = GetPanelSize(0)
                    panel.Visible = true
                    Tween(panel, {Size = GetPanelSize(targetH)}, 0.25)
                    Tween(arrowFrame, {Rotation = flippedUp and 0 or 180}, 0.25)
                    StartTrackingPosition(targetH)
                else
                    activeDropdownPanel = nil
                    StopTrackingPosition()
                    Tween(panel, {Size = GetPanelSize(0)}, 0.2)
                    Tween(arrowFrame, {Rotation = 0}, 0.2)
                    task.delay(0.2, function() panel.Visible = false end)
                end
            end))

            SetupHover(row, RowColor(order), accentBar)

            if selected and callback then task.defer(callback, selected) end

            return {
                Set = function(_, val) selected = val; ConfigManager:Set(labelText, val); ddLabel.Text = val or "Select..."; ddLabel.TextColor3 = val and Theme.Text or Theme.TextDim end,
                Get = function() return selected end,
                Refresh = function(_, newOptions) options = newOptions; if isOpen then BuildOptions() end end,
            }
        end

        -- ── RADIO SELECT ─────────────────────────────────────
        function Tab:AddRadioSelect(labelText, radioOptions, callback)
            local order = NextOrder()
            local saved = StateStore[labelText]
            local selected = saved or (radioOptions[1] and radioOptions[1].Name) or nil
            StateStore[labelText] = selected

            local containerHeight = #radioOptions * 58 + 10
            local container = Instance.new("Frame")
            container.Size = UDim2.new(1, 0, 0, containerHeight)
            container.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
            container.BorderSizePixel = 0
            container.LayoutOrder = order
            container.ZIndex = 6
            container.Parent = page
            Corner(container, Theme.CornerRadius)
            Stroke(container, Theme.Border, 1, 0.3)

            local radioFrames = {}

            for i, opt in ipairs(radioOptions) do
                local optColor = opt.Color or Theme.Accent
                local optFrame = Instance.new("Frame")
                optFrame.Size = UDim2.new(1, -16, 0, 50)
                optFrame.Position = UDim2.new(0, 8, 0, 8 + (i - 1) * 58)
                optFrame.BackgroundColor3 = (selected == opt.Name) and Color3.fromRGB(35, 50, 40) or Theme.Row
                optFrame.BorderSizePixel = 0
                optFrame.ZIndex = 7
                optFrame.Parent = container
                Corner(optFrame, UDim.new(0, 8))

                local optStroke = Stroke(optFrame, optColor, 1.5, (selected == opt.Name) and 0.3 or 1)

                local radio = Instance.new("Frame")
                radio.Size = UDim2.new(0, 22, 0, 22)
                radio.Position = UDim2.new(0, 14, 0.5, -11)
                radio.BackgroundColor3 = (selected == opt.Name) and optColor or Theme.ToggleOff
                radio.BorderSizePixel = 0
                radio.ZIndex = 8
                radio.Parent = optFrame
                Corner(radio, UDim.new(1, 0))

                local radioInner = Instance.new("Frame")
                radioInner.Size = UDim2.new(0, 8, 0, 8)
                radioInner.Position = UDim2.new(0.5, -4, 0.5, -4)
                radioInner.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                radioInner.BackgroundTransparency = (selected == opt.Name) and 0 or 1
                radioInner.BorderSizePixel = 0
                radioInner.ZIndex = 9
                radioInner.Parent = radio
                Corner(radioInner, UDim.new(1, 0))

                local optTitle = Instance.new("TextLabel")
                optTitle.Size = UDim2.new(1, -48, 0, 22)
                optTitle.Position = UDim2.new(0, 44, 0, 6)
                optTitle.BackgroundTransparency = 1
                optTitle.Text = opt.Name
                optTitle.TextColor3 = optColor
                optTitle.TextSize = 14
                optTitle.Font = Theme.Font
                optTitle.TextXAlignment = Enum.TextXAlignment.Left
                optTitle.ZIndex = 9
                optTitle.Parent = optFrame

                local optDesc = Instance.new("TextLabel")
                optDesc.Size = UDim2.new(1, -48, 0, 16)
                optDesc.Position = UDim2.new(0, 44, 0, 28)
                optDesc.BackgroundTransparency = 1
                optDesc.Text = opt.Desc or ""
                optDesc.TextColor3 = Theme.TextDim
                optDesc.TextSize = 11
                optDesc.Font = Theme.FontLight
                optDesc.TextXAlignment = Enum.TextXAlignment.Left
                optDesc.ZIndex = 9
                optDesc.Parent = optFrame

                local optBtn = Instance.new("TextButton")
                optBtn.Size = UDim2.new(1, 0, 1, 0)
                optBtn.BackgroundTransparency = 1
                optBtn.Text = ""
                optBtn.ZIndex = 10
                optBtn.Parent = optFrame

                radioFrames[opt.Name] = {Frame = optFrame, Stroke = optStroke, Radio = radio, RadioInner = radioInner, Color = optColor}

                AddConnection(optBtn.MouseButton1Click:Connect(function()
                    selected = opt.Name
                    ConfigManager:Set(labelText, opt.Name)
                    for oName, rf in pairs(radioFrames) do
                        if oName == opt.Name then
                            Tween(rf.Frame, {BackgroundColor3 = Color3.fromRGB(35, 50, 40)}, 0.25)
                            Tween(rf.Radio, {BackgroundColor3 = rf.Color}, 0.25)
                            Tween(rf.RadioInner, {BackgroundTransparency = 0}, 0.2)
                            Tween(rf.Stroke, {Transparency = 0.3}, 0.25)
                        else
                            Tween(rf.Frame, {BackgroundColor3 = Theme.Row}, 0.25)
                            Tween(rf.Radio, {BackgroundColor3 = Theme.ToggleOff}, 0.25)
                            Tween(rf.RadioInner, {BackgroundTransparency = 1}, 0.2)
                            Tween(rf.Stroke, {Transparency = 1}, 0.25)
                        end
                    end
                    if callback then task.spawn(callback, opt.Name) end
                end))

                AddConnection(optBtn.MouseEnter:Connect(function()
                    if selected ~= opt.Name then Tween(optFrame, {BackgroundColor3 = Theme.Hover}, 0.15) end
                end))
                AddConnection(optBtn.MouseLeave:Connect(function()
                    if selected ~= opt.Name then Tween(optFrame, {BackgroundColor3 = Theme.Row}, 0.15) end
                end))
            end

            ConfigManager:RegisterUpdater(labelText, function(val)
                if type(val) == "string" and radioFrames[val] then
                    selected = val
                    for oName, rf in pairs(radioFrames) do
                        local isSelected = oName == val
                        rf.Frame.BackgroundColor3 = isSelected and Color3.fromRGB(35, 50, 40) or Theme.Row
                        rf.Radio.BackgroundColor3 = isSelected and rf.Color or Theme.ToggleOff
                        rf.RadioInner.BackgroundTransparency = isSelected and 0 or 1
                        rf.Stroke.Transparency = isSelected and 0.3 or 1
                    end
                end
            end)

            if selected and callback then task.defer(callback, selected) end

            return {
                Set = function(_, val) selected = val; ConfigManager:Set(labelText, val) end,
                Get = function() return selected end,
            }
        end

        -- ── PRIORITY LIST ────────────────────────────────────
        function Tab:AddPriorityList(labelText, items, callback)
            local order = NextOrder()
            local saved = StateStore[labelText]
            local list = (saved and type(saved) == "table") and saved or items
            StateStore[labelText] = list

            local sectionLabel = Instance.new("TextLabel")
            sectionLabel.Size = UDim2.new(1, 0, 0, 24)
            sectionLabel.BackgroundTransparency = 1
            sectionLabel.Text = labelText
            sectionLabel.TextColor3 = Theme.Accent
            sectionLabel.TextSize = 15
            sectionLabel.Font = Theme.Font
            sectionLabel.TextXAlignment = Enum.TextXAlignment.Left
            sectionLabel.LayoutOrder = order
            sectionLabel.ZIndex = 7
            sectionLabel.Parent = page

            local containerOrder = NextOrder()
            local containerFrame = Instance.new("Frame")
            containerFrame.Size = UDim2.new(1, 0, 0, #list * 40 + 16)
            containerFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
            containerFrame.BorderSizePixel = 0
            containerFrame.LayoutOrder = containerOrder
            containerFrame.ZIndex = 6
            containerFrame.ClipsDescendants = true
            containerFrame.Parent = page
            Corner(containerFrame, Theme.CornerRadius)
            Stroke(containerFrame, Theme.Border, 1, 0.3)

            local listLayout = Instance.new("UIListLayout")
            listLayout.FillDirection = Enum.FillDirection.Vertical
            listLayout.SortOrder = Enum.SortOrder.LayoutOrder
            listLayout.Padding = UDim.new(0, 4)
            listLayout.Parent = containerFrame
            Padding(containerFrame, 8, 8, 8, 8)

            local rowElements = {}

            local function RebuildRows()
                for _, r in ipairs(rowElements) do if r and r.Parent then r:Destroy() end end
                rowElements = {}

                for rank, item in ipairs(list) do
                    local mRow = Instance.new("Frame")
                    mRow.Size = UDim2.new(1, 0, 0, 36)
                    mRow.BackgroundColor3 = (rank % 2 == 0) and Theme.Row or Theme.RowAlt
                    mRow.BorderSizePixel = 0
                    mRow.LayoutOrder = rank
                    mRow.ZIndex = 8
                    mRow.Parent = containerFrame
                    Corner(mRow, UDim.new(0, 6))
                    table.insert(rowElements, mRow)

                    local rankBadge = Instance.new("Frame")
                    rankBadge.Size = UDim2.new(0, 22, 0, 22)
                    rankBadge.Position = UDim2.new(0, 10, 0.5, -11)
                    rankBadge.BackgroundColor3 = Theme.Accent
                    rankBadge.BackgroundTransparency = 0.8
                    rankBadge.BorderSizePixel = 0
                    rankBadge.ZIndex = 9
                    rankBadge.Parent = mRow
                    Corner(rankBadge, UDim.new(0, 5))

                    local rankLabel = Instance.new("TextLabel")
                    rankLabel.Size = UDim2.new(1, 0, 1, 0)
                    rankLabel.BackgroundTransparency = 1
                    rankLabel.Text = tostring(rank)
                    rankLabel.TextColor3 = Theme.Accent
                    rankLabel.TextSize = 13
                    rankLabel.Font = Theme.Font
                    rankLabel.ZIndex = 10
                    rankLabel.Parent = rankBadge

                    local itemLabel = Instance.new("TextLabel")
                    itemLabel.Size = UDim2.new(1, -120, 1, 0)
                    itemLabel.Position = UDim2.new(0, 42, 0, 0)
                    itemLabel.BackgroundTransparency = 1
                    itemLabel.Text = tostring(item)
                    itemLabel.TextColor3 = Theme.Text
                    itemLabel.TextSize = 14
                    itemLabel.Font = Theme.FontLight
                    itemLabel.TextXAlignment = Enum.TextXAlignment.Left
                    itemLabel.ZIndex = 9
                    itemLabel.Parent = mRow

                    local upBtn = Instance.new("TextButton")
                    upBtn.Size = UDim2.new(0, 28, 0, 26)
                    upBtn.Position = UDim2.new(1, -64, 0.5, -13)
                    upBtn.BackgroundColor3 = Theme.SliderBg
                    upBtn.Text = "▲"
                    upBtn.TextColor3 = Theme.Text
                    upBtn.TextSize = 12
                    upBtn.Font = Theme.Font
                    upBtn.BorderSizePixel = 0
                    upBtn.AutoButtonColor = false
                    upBtn.ZIndex = 10
                    upBtn.Parent = mRow
                    Corner(upBtn, UDim.new(0, 5))

                    local downBtn = Instance.new("TextButton")
                    downBtn.Size = UDim2.new(0, 28, 0, 26)
                    downBtn.Position = UDim2.new(1, -32, 0.5, -13)
                    downBtn.BackgroundColor3 = Theme.SliderBg
                    downBtn.Text = "▼"
                    downBtn.TextColor3 = Theme.Text
                    downBtn.TextSize = 12
                    downBtn.Font = Theme.Font
                    downBtn.BorderSizePixel = 0
                    downBtn.AutoButtonColor = false
                    downBtn.ZIndex = 10
                    downBtn.Parent = mRow
                    Corner(downBtn, UDim.new(0, 5))

                    AddConnection(upBtn.MouseButton1Click:Connect(function()
                        if rank <= 1 then return end
                        list[rank], list[rank-1] = list[rank-1], list[rank]
                        ConfigManager:Set(labelText, list); RebuildRows()
                        if callback then task.spawn(callback, list) end
                    end))
                    AddConnection(downBtn.MouseButton1Click:Connect(function()
                        if rank >= #list then return end
                        list[rank], list[rank+1] = list[rank+1], list[rank]
                        ConfigManager:Set(labelText, list); RebuildRows()
                        if callback then task.spawn(callback, list) end
                    end))

                    AddConnection(upBtn.MouseEnter:Connect(function() Tween(upBtn, {BackgroundColor3 = Theme.Hover}, 0.1) end))
                    AddConnection(upBtn.MouseLeave:Connect(function() Tween(upBtn, {BackgroundColor3 = Theme.SliderBg}, 0.1) end))
                    AddConnection(downBtn.MouseEnter:Connect(function() Tween(downBtn, {BackgroundColor3 = Theme.Hover}, 0.1) end))
                    AddConnection(downBtn.MouseLeave:Connect(function() Tween(downBtn, {BackgroundColor3 = Theme.SliderBg}, 0.1) end))
                end
                containerFrame.Size = UDim2.new(1, 0, 0, #list * 40 + 16)
            end

            RebuildRows()
            return { Get = function() return list end, Set = function(_, newList) list = newList; ConfigManager:Set(labelText, list); RebuildRows() end }
        end

        -- ── MULTI SELECT ─────────────────────────────────────
        function Tab:AddMultiSelect(labelText, items, callback)
            local order = NextOrder()
            local configKey = "_multiselect_" .. labelText
            local saved = StateStore[configKey]
            local selected = (saved and type(saved) == "table") and saved or {}
            StateStore[configKey] = selected

            local sectionLabel = Instance.new("TextLabel")
            sectionLabel.Size = UDim2.new(1, 0, 0, 24)
            sectionLabel.BackgroundTransparency = 1
            sectionLabel.Text = labelText
            sectionLabel.TextColor3 = Theme.Accent
            sectionLabel.TextSize = 15
            sectionLabel.Font = Theme.Font
            sectionLabel.TextXAlignment = Enum.TextXAlignment.Left
            sectionLabel.LayoutOrder = order
            sectionLabel.ZIndex = 7
            sectionLabel.Parent = page

            local containerOrder = NextOrder()
            local containerFrame = Instance.new("Frame")
            containerFrame.Size = UDim2.new(1, 0, 0, 260)
            containerFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
            containerFrame.BorderSizePixel = 0
            containerFrame.LayoutOrder = containerOrder
            containerFrame.ZIndex = 6
            containerFrame.Parent = page
            Corner(containerFrame, Theme.CornerRadius)
            Stroke(containerFrame, Theme.Border, 1, 0.3)

            local header = Instance.new("Frame")
            header.Size = UDim2.new(1, 0, 0, 46)
            header.BackgroundColor3 = Theme.Sidebar
            header.BorderSizePixel = 0
            header.ZIndex = 7
            header.Parent = containerFrame
            Corner(header, Theme.CornerRadius)

            local headerFix = Instance.new("Frame")
            headerFix.Size = UDim2.new(1, 0, 0, 14)
            headerFix.Position = UDim2.new(0, 0, 1, -14)
            headerFix.BackgroundColor3 = Theme.Sidebar
            headerFix.BorderSizePixel = 0
            headerFix.ZIndex = 7
            headerFix.Parent = header

            local countLabel = Instance.new("TextLabel")
            countLabel.Size = UDim2.new(0, 100, 1, 0)
            countLabel.Position = UDim2.new(0, 14, 0, 0)
            countLabel.BackgroundTransparency = 1
            countLabel.TextColor3 = Theme.TextDim
            countLabel.TextSize = 13
            countLabel.Font = Theme.FontLight
            countLabel.TextXAlignment = Enum.TextXAlignment.Left
            countLabel.ZIndex = 8
            countLabel.Parent = header

            local function UpdateCount()
                local count = 0
                for _ in pairs(selected) do count = count + 1 end
                countLabel.Text = count .. " selected"
            end
            UpdateCount()

            local searchBg = Instance.new("Frame")
            searchBg.Size = UDim2.new(0, 180, 0, 30)
            searchBg.Position = UDim2.new(1, -194, 0.5, -15)
            searchBg.BackgroundColor3 = Theme.InputBg
            searchBg.BorderSizePixel = 0
            searchBg.ZIndex = 8
            searchBg.Parent = header
            Corner(searchBg, UDim.new(0, 6))

            local searchGlow = Stroke(searchBg, Theme.Accent, 1.5, 1)

            local searchInput = Instance.new("TextBox")
            searchInput.Size = UDim2.new(1, -16, 1, 0)
            searchInput.Position = UDim2.new(0, 8, 0, 0)
            searchInput.BackgroundTransparency = 1
            searchInput.Text = ""
            searchInput.PlaceholderText = "Search..."
            searchInput.PlaceholderColor3 = Theme.TextDim
            searchInput.TextColor3 = Theme.Text
            searchInput.TextSize = 13
            searchInput.Font = Theme.FontLight
            searchInput.ClearTextOnFocus = false
            searchInput.TextXAlignment = Enum.TextXAlignment.Left
            searchInput.ZIndex = 9
            searchInput.Parent = searchBg

            AddConnection(searchInput.Focused:Connect(function() Tween(searchGlow, {Transparency = 0.4}, 0.2) end))
            AddConnection(searchInput.FocusLost:Connect(function() Tween(searchGlow, {Transparency = 1}, 0.2) end))

            local scrollFrame = Instance.new("ScrollingFrame")
            scrollFrame.Size = UDim2.new(1, -14, 1, -56)
            scrollFrame.Position = UDim2.new(0, 7, 0, 50)
            scrollFrame.BackgroundTransparency = 1
            scrollFrame.BorderSizePixel = 0
            scrollFrame.ScrollBarThickness = 4
            scrollFrame.ScrollBarImageColor3 = Theme.Accent
            scrollFrame.ScrollBarImageTransparency = 0.3
            scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
            scrollFrame.ZIndex = 7
            scrollFrame.Parent = containerFrame

            local scrollLayout = Instance.new("UIListLayout")
            scrollLayout.FillDirection = Enum.FillDirection.Vertical
            scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
            scrollLayout.Padding = UDim.new(0, 4)
            scrollLayout.Parent = scrollFrame
            Padding(scrollFrame, 4, 4, 4, 4)

            local itemRows = {}

            for i, item in ipairs(items) do
                local itemName = (type(item) == "table") and item.Name or tostring(item)
                local isOn = selected[itemName] == true

                local itemRow = Instance.new("Frame")
                itemRow.Name = "Item_" .. itemName
                itemRow.Size = UDim2.new(1, -8, 0, 38)
                itemRow.BackgroundColor3 = (i % 2 == 0) and Theme.Row or Theme.RowAlt
                itemRow.BorderSizePixel = 0
                itemRow.LayoutOrder = i
                itemRow.ZIndex = 8
                itemRow.Parent = scrollFrame
                Corner(itemRow, UDim.new(0, 6))

                local itemLabel = Instance.new("TextLabel")
                itemLabel.Size = UDim2.new(1, -70, 1, 0)
                itemLabel.Position = UDim2.new(0, 14, 0, 0)
                itemLabel.BackgroundTransparency = 1
                itemLabel.Text = itemName
                itemLabel.TextColor3 = Theme.Text
                itemLabel.TextSize = 13
                itemLabel.Font = Theme.FontLight
                itemLabel.TextXAlignment = Enum.TextXAlignment.Left
                itemLabel.TextTruncate = Enum.TextTruncate.AtEnd
                itemLabel.ZIndex = 9
                itemLabel.Parent = itemRow

                local toggleBg = Instance.new("Frame")
                toggleBg.Size = UDim2.new(0, 40, 0, 22)
                toggleBg.Position = UDim2.new(1, -52, 0.5, -11)
                toggleBg.BackgroundColor3 = isOn and Theme.Accent or Theme.ProtectedOff
                toggleBg.BorderSizePixel = 0
                toggleBg.ZIndex = 10
                toggleBg.Parent = itemRow
                Corner(toggleBg, UDim.new(1, 0))

                local toggleCircle = Instance.new("Frame")
                toggleCircle.Size = UDim2.new(0, 18, 0, 18)
                toggleCircle.Position = isOn and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
                toggleCircle.BackgroundColor3 = Theme.Text
                toggleCircle.BorderSizePixel = 0
                toggleCircle.ZIndex = 11
                toggleCircle.Parent = toggleBg
                Corner(toggleCircle, UDim.new(1, 0))

                local toggleBtn = Instance.new("TextButton")
                toggleBtn.Size = UDim2.new(1, 0, 1, 0)
                toggleBtn.BackgroundTransparency = 1
                toggleBtn.Text = ""
                toggleBtn.ZIndex = 12
                toggleBtn.Parent = toggleBg

                itemRows[itemName] = {Frame = itemRow, ToggleBg = toggleBg, ToggleCircle = toggleCircle}

                AddConnection(toggleBtn.MouseButton1Click:Connect(function()
                    local nowOn = not (selected[itemName] == true)
                    if nowOn then selected[itemName] = true else selected[itemName] = nil end
                    ConfigManager:Set(configKey, selected)
                    Tween(toggleBg, {BackgroundColor3 = nowOn and Theme.Accent or Theme.ProtectedOff}, 0.25)
                    Tween(toggleCircle, {Position = nowOn and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)}, 0.25, Enum.EasingStyle.Back)
                    Tween(toggleCircle, {Size = UDim2.new(0, 20, 0, 20)}, 0.08)
                    task.delay(0.08, function() Tween(toggleCircle, {Size = UDim2.new(0, 18, 0, 18)}, 0.12) end)
                    UpdateCount()
                    if callback then task.spawn(callback, selected) end
                end))

                local rowAccent = HoverAccent(itemRow)
                SetupHover(itemRow, (i % 2 == 0) and Theme.Row or Theme.RowAlt, rowAccent)
            end

            AddConnection(scrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollLayout.AbsoluteContentSize.Y + 16)
            end))
            scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollLayout.AbsoluteContentSize.Y + 16)

            AddConnection(searchInput:GetPropertyChangedSignal("Text"):Connect(function()
                local filter = searchInput.Text:lower()
                local visOrder = 1
                for _, item in ipairs(items) do
                    local itemName = (type(item) == "table") and item.Name or tostring(item)
                    local rd = itemRows[itemName]
                    if rd then
                        local visible = filter == "" or itemName:lower():find(filter, 1, true)
                        rd.Frame.Visible = visible
                        if visible then rd.Frame.LayoutOrder = visOrder; visOrder = visOrder + 1 end
                    end
                end
            end))

            return { Get = function() return selected end, Set = function(_, newSelected) selected = newSelected; ConfigManager:Set(configKey, selected) end }
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

            AddConnection(searchInput.Focused:Connect(function() Tween(glowStroke, {Transparency = 0.4}, 0.2) end))
            AddConnection(searchInput.FocusLost:Connect(function() Tween(glowStroke, {Transparency = 1}, 0.2) end))
            AddConnection(searchInput:GetPropertyChangedSignal("Text"):Connect(function()
                if callback then task.spawn(callback, searchInput.Text) end
            end))

            return { Get = function() return searchInput.Text end, Set = function(_, val) searchInput.Text = val end, Clear = function() searchInput.Text = "" end }
        end

        return Tab
    end

    -- ── WINDOW METHODS ───────────────────────────────────────
    function Window:Destroy()
        ConfigManager:Flush()
        ThreadManager:StopAll()
        StopAntiAFK()
        DisconnectAll()
        if screenGui then screenGui:Destroy() end
    end

    function Window:Notify(ntitle, message, notifType, duration)
        GluttonyUI:Notify(ntitle, message, notifType, duration)
    end

    function Window:GetValue(vname) return StateStore[vname] end
    function Window:SetValue(vname, vvalue) ConfigManager:Set(vname, vvalue) end
    function Window:SaveConfig() ConfigManager:Save() end
    function Window:ClearConfig() StateStore = {}; ConfigManager:Save() end

    task.defer(function() ConfigManager:ApplyToUI() end)

    -- ════════════════════════════════════════════════════════
    -- AUTO SETTINGS TAB
    -- ════════════════════════════════════════════════════════

    local function BuildSettingsTab()
        local settingsOrder = 999
        local settingsBtn = Instance.new("TextButton")
        settingsBtn.Name = "Tab_Settings"
        settingsBtn.Size = UDim2.new(1, -14, 0, 42)
        settingsBtn.BackgroundColor3 = Theme.Sidebar
        settingsBtn.BorderSizePixel = 0
        settingsBtn.Text = ""
        settingsBtn.AutoButtonColor = false
        settingsBtn.LayoutOrder = settingsOrder
        settingsBtn.ZIndex = 7
        settingsBtn.Parent = tabContainer
        Corner(settingsBtn, Theme.CornerRadius)

        local settingsIndicator = Instance.new("Frame")
        settingsIndicator.Name = "Indicator"
        settingsIndicator.Size = UDim2.new(0, 4, 0, 22)
        settingsIndicator.Position = UDim2.new(0, 5, 0.5, -11)
        settingsIndicator.BackgroundColor3 = Theme.Accent
        settingsIndicator.BackgroundTransparency = 1
        settingsIndicator.BorderSizePixel = 0
        settingsIndicator.ZIndex = 8
        settingsIndicator.Parent = settingsBtn
        Corner(settingsIndicator, UDim.new(1, 0))

        CreateTabIcon(settingsBtn, "settings")

        local settingsLabel = Instance.new("TextLabel")
        settingsLabel.Name = "Label"
        settingsLabel.Size = UDim2.new(1, -52, 1, 0)
        settingsLabel.Position = UDim2.new(0, 44, 0, 0)
        settingsLabel.BackgroundTransparency = 1
        settingsLabel.Text = "Settings"
        settingsLabel.TextColor3 = Theme.TextDim
        settingsLabel.TextSize = 14
        settingsLabel.Font = Theme.FontLight
        settingsLabel.TextXAlignment = Enum.TextXAlignment.Left
        settingsLabel.ZIndex = 8
        settingsLabel.Parent = settingsBtn

        AddConnection(settingsBtn.MouseEnter:Connect(function()
            if Window._currentTab ~= "Settings" then Tween(settingsBtn, {BackgroundColor3 = Theme.Hover}, 0.15); Tween(settingsLabel, {TextColor3 = Theme.Text}, 0.15) end
        end))
        AddConnection(settingsBtn.MouseLeave:Connect(function()
            if Window._currentTab ~= "Settings" then Tween(settingsBtn, {BackgroundColor3 = Theme.Sidebar}, 0.15); Tween(settingsLabel, {TextColor3 = Theme.TextDim}, 0.15) end
        end))
        AddConnection(settingsBtn.MouseButton1Click:Connect(function() SwitchTab("Settings") end))

        Window._tabButtons["Settings"] = settingsBtn

        local settingsPage = Instance.new("ScrollingFrame")
        settingsPage.Name = "Page_Settings"
        settingsPage.Size = UDim2.new(1, 0, 1, 0)
        settingsPage.BackgroundTransparency = 1
        settingsPage.BorderSizePixel = 0
        settingsPage.ScrollBarThickness = 4
        settingsPage.ScrollBarImageColor3 = Theme.Accent
        settingsPage.ScrollBarImageTransparency = 0.3
        settingsPage.CanvasSize = UDim2.new(0, 0, 0, 0)
        settingsPage.Visible = false
        settingsPage.ZIndex = 6
        settingsPage.Parent = content
        Padding(settingsPage, 18, 18, 22, 22)

        local settingsLayout = ListLayout(settingsPage, 8)
        AddConnection(settingsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            settingsPage.CanvasSize = UDim2.new(0, 0, 0, settingsLayout.AbsoluteContentSize.Y + 40)
        end))

        Window._pages["Settings"] = settingsPage

        -- Title
        local titleFrame = Instance.new("Frame")
        titleFrame.Size = UDim2.new(1, 0, 0, 42)
        titleFrame.BackgroundTransparency = 1
        titleFrame.LayoutOrder = 0
        titleFrame.ZIndex = 7
        titleFrame.Parent = settingsPage

        local ptl = Instance.new("TextLabel")
        ptl.Size = UDim2.new(1, 0, 0, 34)
        ptl.BackgroundTransparency = 1
        ptl.Text = "Settings"
        ptl.TextColor3 = Theme.Text
        ptl.TextSize = 24
        ptl.Font = Theme.Font
        ptl.TextXAlignment = Enum.TextXAlignment.Left
        ptl.ZIndex = 7
        ptl.Parent = titleFrame

        local ul = Instance.new("Frame")
        ul.Size = UDim2.new(0.25, 0, 0, 2)
        ul.Position = UDim2.new(0, 0, 1, -2)
        ul.BackgroundColor3 = Theme.Accent
        ul.BackgroundTransparency = 0.3
        ul.BorderSizePixel = 0
        ul.ZIndex = 8
        ul.Parent = titleFrame
        Corner(ul, UDim.new(1, 0))
        local ulg = Instance.new("UIGradient")
        ulg.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.7,0),NumberSequenceKeypoint.new(1,1)})
        ulg.Parent = ul

        local lo = 0
        local function NSO() lo = lo + 1; return lo end

        -- Interface section label
        local il = Instance.new("TextLabel")
        il.Size = UDim2.new(1, 0, 0, 30)
        il.BackgroundTransparency = 1
        il.Text = "Interface"
        il.TextColor3 = Theme.Accent
        il.TextSize = 15
        il.Font = Theme.Font
        il.TextXAlignment = Enum.TextXAlignment.Left
        il.LayoutOrder = NSO()
        il.ZIndex = 7
        il.Parent = settingsPage

        -- Opacity Slider (manual build since we're in settings tab)
        local opOrder = NSO()
        local opVal = StateStore["GUI Opacity"] or 100
        local opRow = Instance.new("Frame")
        opRow.Size = UDim2.new(1, 0, 0, Theme.RowHeight + 4)
        opRow.BackgroundColor3 = RowColor(opOrder)
        opRow.BorderSizePixel = 0
        opRow.LayoutOrder = opOrder
        opRow.ZIndex = 6
        opRow.ClipsDescendants = true
        opRow.Parent = settingsPage
        Corner(opRow, Theme.CornerRadius)

        local opAcc = HoverAccent(opRow)

        local opLbl = Instance.new("TextLabel")
        opLbl.Size = UDim2.new(0, 170, 1, 0)
        opLbl.Position = UDim2.new(0, 18, 0, 0)
        opLbl.BackgroundTransparency = 1
        opLbl.Text = "GUI Opacity"
        opLbl.TextColor3 = Theme.Text
        opLbl.TextSize = 14
        opLbl.Font = Theme.FontLight
        opLbl.TextXAlignment = Enum.TextXAlignment.Left
        opLbl.ZIndex = 7
        opLbl.Parent = opRow

        local opBadge = Instance.new("Frame")
        opBadge.Size = UDim2.new(0, 42, 0, 22)
        opBadge.Position = UDim2.new(1, -158, 0.5, -11)
        opBadge.BackgroundColor3 = Theme.Accent
        opBadge.BackgroundTransparency = 0.85
        opBadge.BorderSizePixel = 0
        opBadge.ZIndex = 7
        opBadge.Parent = opRow
        Corner(opBadge, UDim.new(0, 5))

        local opVL = Instance.new("TextLabel")
        opVL.Size = UDim2.new(1, 0, 1, 0)
        opVL.BackgroundTransparency = 1
        opVL.Text = tostring(math.floor(opVal))
        opVL.TextColor3 = Theme.Accent
        opVL.TextSize = 13
        opVL.Font = Theme.Font
        opVL.ZIndex = 8
        opVL.Parent = opBadge

        local opTrack = Instance.new("Frame")
        opTrack.Size = UDim2.new(0, 100, 0, 6)
        opTrack.Position = UDim2.new(1, -112, 0.5, -3)
        opTrack.BackgroundColor3 = Theme.SliderBg
        opTrack.BorderSizePixel = 0
        opTrack.ZIndex = 8
        opTrack.Parent = opRow
        Corner(opTrack, UDim.new(1, 0))

        local opP = (opVal - 10) / 90
        local opFill = Instance.new("Frame")
        opFill.Size = UDim2.new(opP, 0, 1, 0)
        opFill.BackgroundColor3 = Theme.SliderFill
        opFill.BorderSizePixel = 0
        opFill.ZIndex = 9
        opFill.Parent = opTrack
        Corner(opFill, UDim.new(1, 0))

        local opKnob = Instance.new("Frame")
        opKnob.Size = UDim2.new(0, 16, 0, 16)
        opKnob.Position = UDim2.new(opP, -8, 0.5, -8)
        opKnob.BackgroundColor3 = Theme.Text
        opKnob.BorderSizePixel = 0
        opKnob.ZIndex = 10
        opKnob.Parent = opTrack
        Corner(opKnob, UDim.new(1, 0))
        Stroke(opKnob, Theme.Shadow, 1, 0.75)

        local opSliding = false
        local opHit = Instance.new("TextButton")
        opHit.Size = UDim2.new(1, 14, 1, 18)
        opHit.Position = UDim2.new(0, -7, 0, -9)
        opHit.BackgroundTransparency = 1
        opHit.Text = ""
        opHit.ZIndex = 11
        opHit.Parent = opTrack

        local function ApplyOpacity(v)
            local t = 1 - (v / 100)
            main.BackgroundTransparency = t
            if titleBar then titleBar.BackgroundTransparency = t end
            if sidebar then sidebar.BackgroundTransparency = t end
            if content then content.BackgroundTransparency = t end
        end

        local function UpdateOp(input)
            local x = math.clamp((input.Position.X - opTrack.AbsolutePosition.X) / opTrack.AbsoluteSize.X, 0, 1)
            local v = math.floor(10 + 90 * x)
            opVal = v; ConfigManager:Set("GUI Opacity", v)
            opVL.Text = tostring(v)
            opFill.Size = UDim2.new(x, 0, 1, 0)
            opKnob.Position = UDim2.new(x, -8, 0.5, -8)
            ApplyOpacity(v)
        end

        AddConnection(opHit.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then opSliding = true; UpdateOp(i) end end))
        AddConnection(opHit.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then opSliding = false end end))
        AddConnection(UserInputService.InputChanged:Connect(function(i) if opSliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then UpdateOp(i) end end))

        SetupHover(opRow, RowColor(opOrder), opAcc)
        ApplyOpacity(opVal)

        -- Spacer
        local sp = Instance.new("Frame")
        sp.Size = UDim2.new(1, 0, 0, 20)
        sp.BackgroundTransparency = 1
        sp.LayoutOrder = NSO()
        sp.Parent = settingsPage

        -- Community
        local cl = Instance.new("TextLabel")
        cl.Size = UDim2.new(1, 0, 0, 30)
        cl.BackgroundTransparency = 1
        cl.Text = "Community"
        cl.TextColor3 = Theme.Accent
        cl.TextSize = 15
        cl.Font = Theme.Font
        cl.TextXAlignment = Enum.TextXAlignment.Left
        cl.LayoutOrder = NSO()
        cl.ZIndex = 7
        cl.Parent = settingsPage

        -- Info card
        local ic = Instance.new("Frame")
        ic.Size = UDim2.new(1, 0, 0, 80)
        ic.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
        ic.BorderSizePixel = 0
        ic.LayoutOrder = NSO()
        ic.ZIndex = 6
        ic.Parent = settingsPage
        Corner(ic, Theme.CornerRadius)
        Stroke(ic, Theme.Border, 1, 0.4)

        local iab = Instance.new("Frame")
        iab.Size = UDim2.new(0, 4, 1, -16)
        iab.Position = UDim2.new(0, 10, 0, 8)
        iab.BackgroundColor3 = Theme.Accent
        iab.BackgroundTransparency = 0.3
        iab.BorderSizePixel = 0
        iab.ZIndex = 7
        iab.Parent = ic
        Corner(iab, UDim.new(1, 0))

        local it = Instance.new("TextLabel")
        it.Size = UDim2.new(1, -40, 1, -20)
        it.Position = UDim2.new(0, 28, 0, 10)
        it.BackgroundTransparency = 1
        it.Text = "Join our Discord community for updates, feature requests, bug reports, and direct support."
        it.TextColor3 = Theme.TextDim
        it.TextSize = 13
        it.Font = Theme.FontLight
        it.TextXAlignment = Enum.TextXAlignment.Left
        it.TextYAlignment = Enum.TextYAlignment.Center
        it.TextWrapped = true
        it.ZIndex = 7
        it.Parent = ic

        -- Discord row
        local dOrder = NSO()
        local dRow = Instance.new("Frame")
        dRow.Size = UDim2.new(1, 0, 0, Theme.RowHeight)
        dRow.BackgroundColor3 = RowColor(dOrder)
        dRow.BorderSizePixel = 0
        dRow.LayoutOrder = dOrder
        dRow.ZIndex = 6
        dRow.ClipsDescendants = true
        dRow.Parent = settingsPage
        Corner(dRow, Theme.CornerRadius)

        local dAcc = HoverAccent(dRow)

        local dLbl = Instance.new("TextLabel")
        dLbl.Size = UDim2.new(1, -130, 1, 0)
        dLbl.Position = UDim2.new(0, 18, 0, 0)
        dLbl.BackgroundTransparency = 1
        dLbl.Text = "Discord Server"
        dLbl.TextColor3 = Theme.Text
        dLbl.TextSize = 14
        dLbl.Font = Theme.FontLight
        dLbl.TextXAlignment = Enum.TextXAlignment.Left
        dLbl.ZIndex = 7
        dLbl.Parent = dRow

        local dBF = Instance.new("Frame")
        dBF.Size = UDim2.new(0, 100, 0, 32)
        dBF.Position = UDim2.new(1, -114, 0.5, -16)
        dBF.BackgroundTransparency = 1
        dBF.ZIndex = 7
        dBF.Parent = dRow

        local dSh = Instance.new("Frame")
        dSh.Size = UDim2.new(1, 2, 1, 2)
        dSh.Position = UDim2.new(0, -1, 0, 2)
        dSh.BackgroundColor3 = Theme.Shadow
        dSh.BackgroundTransparency = 0.82
        dSh.BorderSizePixel = 0
        dSh.ZIndex = 7
        dSh.Parent = dBF
        Corner(dSh, Theme.CornerRadius)

        local dCol = Color3.fromRGB(88, 101, 242)
        local dHov = Color3.fromRGB(108, 121, 255)
        local sCol = Color3.fromRGB(50, 180, 80)

        local dBtn = Instance.new("TextButton")
        dBtn.Size = UDim2.new(1, -2, 1, -2)
        dBtn.Position = UDim2.new(0, 1, 0, 0)
        dBtn.BackgroundColor3 = dCol
        dBtn.Text = "Copy Link"
        dBtn.TextColor3 = Theme.Text
        dBtn.TextSize = 13
        dBtn.Font = Theme.Font
        dBtn.BorderSizePixel = 0
        dBtn.AutoButtonColor = false
        dBtn.ZIndex = 8
        dBtn.Parent = dBF
        Corner(dBtn, Theme.CornerRadius)

        local dGlow = Stroke(dBtn, dCol, 1.5, 0.6)

        AddConnection(dBtn.MouseEnter:Connect(function() Tween(dBtn, {BackgroundColor3 = dHov}, 0.15); Tween(dGlow, {Transparency = 0.3}, 0.2) end))
        AddConnection(dBtn.MouseLeave:Connect(function() Tween(dBtn, {BackgroundColor3 = dCol}, 0.15); Tween(dGlow, {Transparency = 0.6}, 0.2) end))
        AddConnection(dBtn.MouseButton1Click:Connect(function()
            Tween(dBtn, {Size = UDim2.new(1, -6, 1, -4)}, 0.06)
            task.delay(0.06, function() Tween(dBtn, {Size = UDim2.new(1, -2, 1, -2)}, 0.1, Enum.EasingStyle.Back) end)
            local url = "https://discord.gg/6KmxCWU6Dc"
            local ok = pcall(function() if setclipboard then setclipboard(url) elseif toclipboard then toclipboard(url) else error() end end)
            if ok then
                local ot = dBtn.Text; dBtn.Text = "Copied!"
                Tween(dBtn, {BackgroundColor3 = sCol}, 0.2); Tween(dGlow, {Color = sCol, Transparency = 0.3}, 0.2)
                task.delay(1.5, function()
                    if dBtn and dBtn.Parent then dBtn.Text = ot; Tween(dBtn, {BackgroundColor3 = dCol}, 0.2); Tween(dGlow, {Color = dCol, Transparency = 0.6}, 0.2) end
                end)
            end
        end))

        SetupHover(dRow, RowColor(dOrder), dAcc)

        local vl = Instance.new("TextLabel")
        vl.Size = UDim2.new(0, 40, 0, 16)
        vl.Position = UDim2.new(1, -50, 1, -22)
        vl.BackgroundTransparency = 1
        vl.Text = "v2.1"
        vl.TextColor3 = Theme.TextDim
        vl.TextTransparency = 0.5
        vl.TextSize = 11
        vl.Font = Theme.FontLight
        vl.TextXAlignment = Enum.TextXAlignment.Right
        vl.ZIndex = 15
        vl.Parent = inner
    end

    BuildSettingsTab()

    -- ════════════════════════════════════════════════════════
    -- TOGGLE BUTTON (left edge, draggable)
    -- ════════════════════════════════════════════════════════

    local ToggleButton = Instance.new("Frame")
    ToggleButton.Name = "ToggleButton"
    ToggleButton.Size = UDim2.new(0, 36, 0, 90)
    ToggleButton.Position = UDim2.new(0, -4, 0.5, -45)
    ToggleButton.BackgroundColor3 = Theme.Background
    ToggleButton.BorderSizePixel = 0
    ToggleButton.ZIndex = 100
    ToggleButton.Parent = screenGui
    Corner(ToggleButton, UDim.new(0, 12))
    Stroke(ToggleButton, Theme.Accent, 2, 0.5)

    local leftCover = Instance.new("Frame")
    leftCover.Size = UDim2.new(0, 12, 1, 0)
    leftCover.BackgroundColor3 = Theme.Background
    leftCover.BorderSizePixel = 0
    leftCover.ZIndex = 101
    leftCover.Parent = ToggleButton

    local tbAccentBar = Instance.new("Frame")
    tbAccentBar.Name = "AccentBar"
    tbAccentBar.AnchorPoint = Vector2.new(0.5, 0.5)
    tbAccentBar.Size = UDim2.new(0, 3, 0, 35)
    tbAccentBar.Position = UDim2.new(1, -5, 0.5, 0)
    tbAccentBar.BackgroundColor3 = Theme.Accent
    tbAccentBar.BorderSizePixel = 0
    tbAccentBar.ZIndex = 105
    tbAccentBar.Parent = ToggleButton
    Corner(tbAccentBar, UDim.new(1, 0))

    local dotsContainer = Instance.new("Frame")
    dotsContainer.Size = UDim2.new(0, 12, 0, 50)
    dotsContainer.Position = UDim2.new(0, 8, 0.5, -25)
    dotsContainer.BackgroundTransparency = 1
    dotsContainer.ZIndex = 105
    dotsContainer.Parent = ToggleButton

    local dots = {}
    for i = 1, 5 do
        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 6, 0, 6)
        dot.Position = UDim2.new(0.5, -3, 0, (i - 1) * 11)
        dot.BackgroundColor3 = Theme.TextDim
        dot.BackgroundTransparency = 0.3
        dot.BorderSizePixel = 0
        dot.ZIndex = 106
        dot.Parent = dotsContainer
        Corner(dot, UDim.new(1, 0))
        table.insert(dots, dot)
    end

    local toggleClickBtn = Instance.new("TextButton")
    toggleClickBtn.Size = UDim2.new(1, 0, 1, 0)
    toggleClickBtn.BackgroundTransparency = 1
    toggleClickBtn.Text = ""
    toggleClickBtn.ZIndex = 110
    toggleClickBtn.Parent = ToggleButton

    local pulseRunning = true
    task.spawn(function()
        while pulseRunning do
            if not ToggleButton or not ToggleButton.Parent then break end
            Tween(tbAccentBar, {BackgroundTransparency = 0.3}, 1.2, Enum.EasingStyle.Sine); task.wait(1.2)
            if not ToggleButton or not ToggleButton.Parent then break end
            Tween(tbAccentBar, {BackgroundTransparency = 0}, 1.2, Enum.EasingStyle.Sine); task.wait(1.2)
        end
    end)

    local tbDragging, tbDragStartY, tbButtonStartY, tbHasMoved, tbClickDebounce = false, 0, 0, false, false
    local guiOpen = true

    local function getTbYOffset() return ToggleButton.Position.Y.Offset end
    local function setTbY(yOffset)
        local sH = screenGui.AbsoluteSize.Y
        local bH = ToggleButton.AbsoluteSize.Y
        yOffset = math.clamp(yOffset, -sH/2 + bH/2 + 20, sH/2 - bH/2 - 20)
        ToggleButton.Position = UDim2.new(0, guiOpen and 0 or -4, 0.5, yOffset)
    end

    AddConnection(toggleClickBtn.MouseButton1Down:Connect(function()
        if tbClickDebounce then return end
        tbDragging = true; tbHasMoved = false
        tbDragStartY = UserInputService:GetMouseLocation().Y; tbButtonStartY = getTbYOffset()
    end))

    AddConnection(toggleClickBtn.MouseButton1Up:Connect(function()
        if not tbDragging then return end
        tbDragging = false
        if not tbHasMoved and not tbClickDebounce then
            tbClickDebounce = true
            local cy = getTbYOffset()
            if guiOpen then
                guiOpen = false
                Tween(main, {Size = UDim2.new(0, Theme.WindowWidth, 0, 0)}, 0.3)
                Tween(ToggleButton, {Position = UDim2.new(0, -4, 0.5, cy)}, 0.25)
                Tween(tbAccentBar, {Size = UDim2.new(0, 3, 0, 35)}, 0.25)
                task.delay(0.3, function() main.Visible = false; tbClickDebounce = false end)
            else
                guiOpen = true; main.Visible = true
                main.Size = UDim2.new(0, Theme.WindowWidth, 0, 0)
                Tween(main, {Size = UDim2.new(0, Theme.WindowWidth, 0, Theme.WindowHeight)}, 0.35, Enum.EasingStyle.Back)
                Tween(ToggleButton, {Position = UDim2.new(0, 0, 0.5, cy)}, 0.25)
                Tween(tbAccentBar, {Size = UDim2.new(0, 3, 0, 55)}, 0.25)
                task.delay(0.35, function() tbClickDebounce = false end)
            end
        end
    end))

    AddConnection(UserInputService.InputChanged:Connect(function(input)
        if not tbDragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local dy = UserInputService:GetMouseLocation().Y - tbDragStartY
        if math.abs(dy) > 5 then tbHasMoved = true end
        if tbHasMoved then setTbY(tbButtonStartY + dy) end
    end))

    AddConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then tbDragging = false end
    end))

    AddConnection(toggleClickBtn.MouseEnter:Connect(function()
        Tween(ToggleButton, {BackgroundColor3 = Theme.Hover}, 0.2); Tween(leftCover, {BackgroundColor3 = Theme.Hover}, 0.2)
        Tween(ToggleButton, {Position = UDim2.new(0, 0, 0.5, getTbYOffset())}, 0.2)
        for i, dot in ipairs(dots) do
            task.delay(i * 0.04, function() Tween(dot, {BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0, Size = UDim2.new(0, 8, 0, 8), Position = UDim2.new(0.5, -4, 0, (i-1)*11-1)}, 0.15) end)
        end
    end))

    AddConnection(toggleClickBtn.MouseLeave:Connect(function()
        Tween(ToggleButton, {BackgroundColor3 = Theme.Background}, 0.2); Tween(leftCover, {BackgroundColor3 = Theme.Background}, 0.2)
        if not guiOpen and not tbDragging then Tween(ToggleButton, {Position = UDim2.new(0, -4, 0.5, getTbYOffset())}, 0.2) end
        for i, dot in ipairs(dots) do
            task.delay(i * 0.04, function() Tween(dot, {BackgroundColor3 = Theme.TextDim, BackgroundTransparency = 0.3, Size = UDim2.new(0, 6, 0, 6), Position = UDim2.new(0.5, -3, 0, (i-1)*11)}, 0.15) end)
        end
    end))

    local origDestroy = Window.Destroy
    function Window:Destroy() pulseRunning = false; origDestroy(self) end

    return Window
end

return GluttonyUI