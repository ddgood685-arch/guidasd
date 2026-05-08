--[[
═══════════════════════════════════════════════════════════════════════════
   GLUTTONY UI LIBRARY v2.3
   Added: Discord Webhook System (Rich Embeds, Customizable, Per-Game)
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
-- MOBILE / SCREEN DETECTION
-- ════════════════════════════════════════════════════════════════

local _isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local _screenSize = workspace.CurrentCamera.ViewportSize

workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    _screenSize = workspace.CurrentCamera.ViewportSize
end)

local function RS(pcValue, mobileValue)
    return _isMobile and mobileValue or pcValue
end

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

    WindowWidth   = RS(620, math.floor(math.min(_screenSize.X * 0.97, 460))),
    WindowHeight  = RS(480, math.floor(math.min(_screenSize.Y * 0.88, 580))),
    SidebarWidth  = RS(150, 110),
    RowHeight     = RS(48, 52),
    TitleHeight   = RS(42, 50),
    FontSize      = RS(14, 15),
    FontSizeSmall = RS(13, 14),
    FontSizeLarge = RS(17, 18),
    TabFontSize   = RS(14, 13),
}

-- ════════════════════════════════════════════════════════════════
-- WEBHOOK SYSTEM
-- ════════════════════════════════════════════════════════════════

local WebhookSystem = {}
WebhookSystem._url = nil
WebhookSystem._config = {
    -- Branding
    Title       = "Gluttony Core",
    TitleIcon   = "https://i.imgur.com/cThW0xR.png", -- your logo url
    FooterText  = "Gluttony Core • Powered by Gluttony UI",
    FooterIcon  = "https://i.imgur.com/cThW0xR.png",
    -- Colors (Discord embed sidebar color as decimal)
    Color       = 14431557, -- #DC3C3C in decimal (matches Theme.Accent)
    -- Game info
    GameName    = "Unknown Game",
    -- Extra fields always included
    AlwaysFields = true,
}

-- Convert RGB to decimal for Discord embed color
function WebhookSystem.RGBToDecimal(r, g, b)
    return r * 65536 + g * 256 + b
end

-- Helper: get player info fields
local function GetPlayerFields()
    local plr = Players.LocalPlayer
    local fields = {}

    -- Username
    table.insert(fields, {
        name  = "👤 Player",
        value = string.format("**%s** (`%d`)", plr.DisplayName, plr.UserId),
        inline = true
    })

    -- Game
    local gameName = "Unknown"
    pcall(function()
        gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
    end)
    table.insert(fields, {
        name  = "🎮 Game",
        value = string.format("**%s**", gameName),
        inline = true
    })

    return fields
end

-- Core send function
function WebhookSystem:Send(options)
    if not self._url or self._url == "" then
        warn("[GluttonyUI][Webhook] No webhook URL set.")
        return false, "No webhook URL"
    end

    options = options or {}

    -- Build timestamp
    local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")

    -- Build fields
    local fields = {}

    -- Player info fields (always shown if AlwaysFields is true)
    if self._config.AlwaysFields then
        local pf = GetPlayerFields()
        for _, f in ipairs(pf) do
            table.insert(fields, f)
        end
    end

    -- Custom fields from caller
    if options.Fields then
        for _, f in ipairs(options.Fields) do
            table.insert(fields, f)
        end
    end

    -- Build embed
    local embed = {
        title       = options.Title or self._config.Title,
        description = options.Description or "",
        color       = options.Color or self._config.Color,
        timestamp   = timestamp,
        fields      = fields,
        footer = {
            text     = options.Footer or self._config.FooterText,
            icon_url = options.FooterIcon or self._config.FooterIcon,
        },
        author = {
            name     = options.Author or self._config.Title,
            icon_url = options.AuthorIcon or self._config.TitleIcon,
        },
    }

    -- Optional thumbnail
    if options.Thumbnail then
        embed.thumbnail = { url = options.Thumbnail }
    end

    -- Optional image
    if options.Image then
        embed.image = { url = options.Image }
    end

    -- Build payload
    local payload = {
        username   = options.Username or self._config.Title,
        avatar_url = options.AvatarUrl or self._config.TitleIcon,
        embeds     = { embed },
    }

    -- Optional content (plain text above embed)
    if options.Content then
        payload.content = options.Content
    end

    -- Encode and send
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, payload)
    if not ok then
        warn("[GluttonyUI][Webhook] JSON encode failed:", encoded)
        return false, "Encode failed"
    end

    local success, result = pcall(function()
        local requestFunc = syn and syn.request
            or (http_request and http_request)
            or (request and request)
            or nil

        if not requestFunc then
            error("No HTTP request function available")
        end

        local response = requestFunc({
            Url     = self._url,
            Method  = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
            },
            Body    = encoded,
        })

        return response
    end)

    if not success then
        warn("[GluttonyUI][Webhook] Request failed:", result)
        return false, tostring(result)
    end

    return true, result
end

-- Shortcut: send a nice pre-built "action" embed
function WebhookSystem:SendAction(actionTitle, description, fields, color)
    return self:Send({
        Title       = string.format("⚡ %s — %s", self._config.Title, actionTitle),
        Description = description or "",
        Color       = color or self._config.Color,
        Fields      = fields or {},
    })
end

-- Shortcut: send a startup / loaded embed
function WebhookSystem:SendLoaded(gameName, extraFields)
    return self:Send({
        Title       = string.format("✅ %s — Script Loaded", self._config.Title),
        Description = string.format(
            "**%s** has successfully loaded on **%s**.",
            Players.LocalPlayer.DisplayName,
            gameName or self._config.GameName
        ),
        Color       = WebhookSystem.RGBToDecimal(60, 180, 90), -- green
        Fields      = extraFields or {},
        Thumbnail   = self._config.TitleIcon,
    })
end

-- Shortcut: send an error embed
function WebhookSystem:SendError(errorTitle, errorMsg)
    return self:Send({
        Title       = string.format("❌ %s — Error", self._config.Title),
        Description = string.format("An error occurred:\n```\n%s\n```", tostring(errorMsg)),
        Color       = WebhookSystem.RGBToDecimal(220, 60, 60), -- red
        Fields      = {
            { name = "⚠️ Error", value = tostring(errorTitle), inline = false }
        },
    })
end

-- Configure the webhook system
function WebhookSystem:Configure(cfg)
    cfg = cfg or {}
    for k, v in pairs(cfg) do
        self._config[k] = v
    end
    -- Auto-convert Color3 to decimal if provided
    if cfg.AccentColor and typeof(cfg.AccentColor) == "Color3" then
        self._config.Color = self.RGBToDecimal(
            math.floor(cfg.AccentColor.R * 255),
            math.floor(cfg.AccentColor.G * 255),
            math.floor(cfg.AccentColor.B * 255)
        )
    end
end

function WebhookSystem:SetURL(url)
    self._url = url
end

function WebhookSystem:GetURL()
    return self._url
end

GluttonyUI.Webhook = WebhookSystem

-- ════════════════════════════════════════════════════════════════
-- NUMBER UTILITIES
-- ════════════════════════════════════════════════════════════════

local NumberSuffixes = {
    {"Dc",1e33},{"No",1e30},{"Oc",1e27},{"Sp",1e24},
    {"Sx",1e21},{"Qi",1e18},{"Qa",1e15},{"T",1e12},
    {"B",1e9},{"M",1e6},{"K",1e3},
}

function GluttonyUI.FormatNumber(n)
    if not n or n == 0 then return "0" end
    for _,p in ipairs(NumberSuffixes) do
        if math.abs(n) >= p[2] then return string.format("%.1f%s", n/p[2], p[1]) end
    end
    return tostring(math.floor(n))
end

function GluttonyUI.ParseNumber(input)
    if not input or input == "" then return 0 end
    input = tostring(input):gsub("%s+",""):gsub("%$",""):gsub(",","")
    local num = tonumber(input)
    if num then return num end
    local value, suffix = input:match("^([%d%.]+)(%a+)$")
    if value and suffix then
        suffix = suffix:upper()
        local m = {K=1e3,M=1e6,B=1e9,T=1e12,QA=1e15,QI=1e18,SX=1e21,SP=1e24,OC=1e27,NO=1e30,DC=1e33}
        if m[suffix] then local b = tonumber(value); if b then return b * m[suffix] end end
    end
    return tonumber(input) or 0
end

-- STATE
local StateStore = {}
function GluttonyUI:GetValue(n) return StateStore[n] end
function GluttonyUI:SetValue(n,v) StateStore[n] = v end

-- THREAD MANAGER
local ThreadManager = {}
local _activeThreads = {}
local _threadRunning = {}

function ThreadManager:Start(key, interval, callback)
    self:Stop(key)
    _threadRunning[key] = true
    _activeThreads[key] = task.spawn(function()
        while _threadRunning[key] do
            local ok, err = pcall(callback)
            if not ok then warn("[GluttonyUI][Thread]["..key.."]: "..tostring(err)) end
            if not _threadRunning[key] then break end
            local wt = (typeof(interval) == "function") and interval() or interval
            task.wait(wt or 1)
        end
        _activeThreads[key] = nil; _threadRunning[key] = false
    end)
end

function ThreadManager:Stop(key)
    _threadRunning[key] = false
    if _activeThreads[key] then pcall(task.cancel, _activeThreads[key]); _activeThreads[key] = nil end
end

function ThreadManager:StopAll()
    for key in pairs(_activeThreads) do self:Stop(key) end
end

function ThreadManager:IsRunning(key) return _threadRunning[key] == true end

GluttonyUI.ThreadManager = ThreadManager

-- CONFIG MANAGER
local ConfigManager = {}
ConfigManager._fileName = nil
ConfigManager._enabled = false
ConfigManager._dirty = false
ConfigManager._saveThread = nil
ConfigManager._debounce = 1.5
ConfigManager._uiUpdaters = {}
ConfigManager._toggleMeta = {}

local function HasFileSupport()
    local ok,r = pcall(function()
        return type(writefile)=="function" and type(readfile)=="function" and type(isfile)=="function"
    end)
    return ok and r
end

function ConfigManager:Init(fn)
    if not fn or fn=="" then self._enabled=false; return end
    if not HasFileSupport() then self._enabled=false; return end
    if not fn:match("%.json$") then fn = fn..".json" end
    self._fileName=fn; self._enabled=true
end

function ConfigManager:Load()
    if not self._enabled then return false end
    local exists=false; pcall(function() exists=isfile(self._fileName) end)
    if not exists then return false end
    local ok,content=pcall(readfile,self._fileName)
    if not ok or not content or content=="" then return false end
    local dok,data=pcall(HttpService.JSONDecode,HttpService,content)
    if not dok or type(data)~="table" then return false end
    for k,v in pairs(data) do StateStore[k]=v end
    return true
end

function ConfigManager:Save()
    if not self._enabled then return end
    local ok,enc=pcall(HttpService.JSONEncode,HttpService,StateStore)
    if not ok then return end
    pcall(writefile,self._fileName,enc)
    self._dirty=false
end

function ConfigManager:QueueSave()
    if not self._enabled then return end
    self._dirty=true
    if self._saveThread then pcall(task.cancel,self._saveThread); self._saveThread=nil end
    self._saveThread=task.delay(self._debounce,function() self:Save(); self._saveThread=nil end)
end

function ConfigManager:Flush()
    if not self._enabled then return end
    if self._saveThread then pcall(task.cancel,self._saveThread); self._saveThread=nil end
    if self._dirty then self:Save() end
end

function ConfigManager:Set(n,v) StateStore[n]=v; self:QueueSave() end
function ConfigManager:RegisterUpdater(n,f) self._uiUpdaters[n]=f end
function ConfigManager:ApplyToUI()
    for n,u in pairs(self._uiUpdaters) do
        local s=StateStore[n]; if s~=nil then pcall(u,s) end
    end
end

-- CONNECTIONS
local Connections = {}
local function AddConnection(c) table.insert(Connections,c); return c end
local function DisconnectAll()
    for _,c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    Connections={}
end

-- ANTI-AFK
local _antiAfkRunning = false
local _antiAfkThread = nil

local function StartAntiAFK()
    if _antiAfkRunning then return end
    _antiAfkRunning = true
    _antiAfkThread = task.spawn(function()
        while _antiAfkRunning do
            task.wait(10)
            if not _antiAfkRunning then break end
            pcall(function()
                if _isMobile then
                    VirtualInputManager:SendGamepadKeyEvent(
                        Enum.UserInputType.Gamepad1,Enum.KeyCode.ButtonB,true,1)
                    task.wait(0.1)
                    VirtualInputManager:SendGamepadKeyEvent(
                        Enum.UserInputType.Gamepad1,Enum.KeyCode.ButtonB,false,1)
                else
                    VirtualInputManager:SendKeyEvent(true,Enum.KeyCode.LeftControl,false,game)
                    task.wait(0.1)
                    VirtualInputManager:SendKeyEvent(false,Enum.KeyCode.LeftControl,false,game)
                end
            end)
        end
    end)
end

local function StopAntiAFK()
    _antiAfkRunning = false
    if _antiAfkThread then pcall(task.cancel,_antiAfkThread); _antiAfkThread=nil end
end

-- UTILITIES
local function Tween(obj,props,dur,style,dir)
    if not obj or not obj.Parent then return end
    TweenService:Create(obj,
        TweenInfo.new(dur or 0.25, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out),
        props):Play()
end

local function Corner(p,r)
    local c=Instance.new("UICorner"); c.CornerRadius=r or Theme.CornerRadius; c.Parent=p; return c
end

local function Stroke(p,col,th,tr)
    local s=Instance.new("UIStroke"); s.Color=col or Theme.Border
    s.Thickness=th or 1; s.Transparency=tr or 0.5
    s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; s.Parent=p; return s
end

local function Padding(p,t,b,l,r)
    local pd=Instance.new("UIPadding")
    pd.PaddingTop=UDim.new(0,t or 0); pd.PaddingBottom=UDim.new(0,b or 0)
    pd.PaddingLeft=UDim.new(0,l or 0); pd.PaddingRight=UDim.new(0,r or 0)
    pd.Parent=p; return pd
end

local function ListLayout(p,pad,dir)
    local l=Instance.new("UIListLayout")
    l.FillDirection=dir or Enum.FillDirection.Vertical
    l.SortOrder=Enum.SortOrder.LayoutOrder
    l.Padding=UDim.new(0,pad or 6)
    l.HorizontalAlignment=Enum.HorizontalAlignment.Center
    l.Parent=p; return l
end

local function HoverAccent(row)
    local bar=Instance.new("Frame"); bar.Name="HoverBar"
    bar.Size=UDim2.new(0,3,0.55,0); bar.Position=UDim2.new(0,0,0.225,0)
    bar.BackgroundColor3=Theme.Accent; bar.BackgroundTransparency=1
    bar.BorderSizePixel=0; bar.ZIndex=row.ZIndex+1; bar.Parent=row
    Corner(bar,UDim.new(1,0)); return bar
end

local function SetupHover(row,baseColor,accentBar)
    if _isMobile then return end
    AddConnection(row.MouseEnter:Connect(function()
        Tween(row,{BackgroundColor3=Theme.Hover},0.15)
        if accentBar then Tween(accentBar,{BackgroundTransparency=0.2},0.15) end
    end))
    AddConnection(row.MouseLeave:Connect(function()
        Tween(row,{BackgroundColor3=baseColor},0.15)
        if accentBar then Tween(accentBar,{BackgroundTransparency=1},0.15) end
    end))
end

local function RowColor(i) return (i%2==0) and Theme.Row or Theme.RowAlt end

-- ════════════════════════════════════════════════════════════════
-- NOTIFICATIONS
-- ════════════════════════════════════════════════════════════════

local NotifContainer = nil
local function EnsureNotifContainer(sg)
    if NotifContainer and NotifContainer.Parent then return end
    NotifContainer = Instance.new("Frame")
    NotifContainer.Name = "Notifications"
    if _isMobile then
        local nw = math.floor(_screenSize.X * 0.92)
        NotifContainer.Size     = UDim2.new(0, nw, 1, -20)
        NotifContainer.Position = UDim2.new(0.5, -math.floor(nw/2), 0, 10)
    else
        NotifContainer.Size     = UDim2.new(0, 280, 1, -20)
        NotifContainer.Position = UDim2.new(1, -290, 0, 10)
    end
    NotifContainer.BackgroundTransparency=1
    NotifContainer.ZIndex=200
    NotifContainer.Parent=sg
    local l=Instance.new("UIListLayout")
    l.FillDirection=Enum.FillDirection.Vertical
    l.VerticalAlignment=Enum.VerticalAlignment.Bottom
    l.SortOrder=Enum.SortOrder.LayoutOrder
    l.Padding=UDim.new(0,8)
    l.Parent=NotifContainer
end

function GluttonyUI:Notify(title,message,notifType,duration)
    if not NotifContainer then return end
    duration=duration or 3; notifType=notifType or "info"
    local ac=Theme.NotifInfo
    if notifType=="success" then ac=Theme.NotifSuccess
    elseif notifType=="warning" then ac=Theme.NotifWarning
    elseif notifType=="error" then ac=Theme.NotifError end

    local notifHeight = _isMobile and 72 or 62
    local n=Instance.new("Frame")
    n.Size=UDim2.new(1,0,0,0)
    n.BackgroundColor3=Theme.TitleBar
    n.BorderSizePixel=0; n.ClipsDescendants=true; n.ZIndex=201; n.Parent=NotifContainer
    Corner(n,Theme.CornerRadius); Stroke(n,ac,1,0.4)

    local bar=Instance.new("Frame"); bar.Size=UDim2.new(0,4,1,-12); bar.Position=UDim2.new(0,6,0,6)
    bar.BackgroundColor3=ac; bar.BorderSizePixel=0; bar.ZIndex=202; bar.Parent=n; Corner(bar,UDim.new(1,0))

    local dot=Instance.new("Frame"); dot.Size=UDim2.new(0,8,0,8); dot.Position=UDim2.new(0,18,0,16)
    dot.BackgroundColor3=ac; dot.BorderSizePixel=0; dot.ZIndex=203; dot.Parent=n; Corner(dot,UDim.new(1,0))

    local tl=Instance.new("TextLabel"); tl.Size=UDim2.new(1,-44,0,20); tl.Position=UDim2.new(0,34,0,8)
    tl.BackgroundTransparency=1; tl.Text=title or "Notification"; tl.TextColor3=Theme.Text
    tl.TextSize=RS(14,15); tl.Font=Theme.Font; tl.TextXAlignment=Enum.TextXAlignment.Left
    tl.TextTruncate=Enum.TextTruncate.AtEnd; tl.ZIndex=203; tl.Parent=n

    local ml=Instance.new("TextLabel"); ml.Size=UDim2.new(1,-44,0,34); ml.Position=UDim2.new(0,34,0,28)
    ml.BackgroundTransparency=1; ml.Text=message or ""; ml.TextColor3=Theme.TextDim
    ml.TextSize=RS(12,13); ml.Font=Theme.FontLight; ml.TextXAlignment=Enum.TextXAlignment.Left
    ml.TextWrapped=true; ml.ZIndex=203; ml.Parent=n

    Tween(n,{Size=UDim2.new(1,0,0,notifHeight)},0.3,Enum.EasingStyle.Back)
    task.delay(duration,function()
        if n and n.Parent then
            Tween(n,{Size=UDim2.new(1,0,0,0),BackgroundTransparency=1},0.3)
            task.wait(0.35)
            if n and n.Parent then n:Destroy() end
        end
    end)
end

-- LOGO
local function CreateLogo(parent, titleH)
    local logoSize = RS(32, 36)
    local c=Instance.new("Frame")
    c.Size=UDim2.new(0,logoSize,0,logoSize)
    c.Position=UDim2.new(0,12,0.5,-logoSize/2)
    c.BackgroundTransparency=1; c.ZIndex=12; c.Parent=parent
    local il=Instance.new("ImageLabel"); il.Size=UDim2.new(1,0,1,0)
    il.BackgroundTransparency=1; il.ScaleType=Enum.ScaleType.Fit; il.ZIndex=13; il.Parent=c
    Corner(il,UDim.new(1,0))
    local loaded=false
    pcall(function()
        local url="https://i.imgur.com/cThW0xR.png"; local fn="logo_v2.png"
        if isfile and isfile(fn) then if delfile then delfile(fn) end end
        local resp=nil
        if syn and syn.request then resp=syn.request({Url=url,Method="GET"})
        elseif http_request then resp=http_request({Url=url,Method="GET"})
        elseif request then resp=request({Url=url,Method="GET"}) end
        if resp and resp.Body and #resp.Body>0 then
            if writefile then writefile(fn,resp.Body) end
            if getcustomasset then il.Image=getcustomasset(fn); loaded=true
            elseif getsynasset then il.Image=getsynasset(fn); loaded=true end
        end
    end)
    if not loaded then
        il:Destroy()
        local r=Instance.new("Frame"); r.Size=UDim2.new(1,0,1,0)
        r.BackgroundColor3=Theme.Accent; r.BackgroundTransparency=0.6
        r.BorderSizePixel=0; r.ZIndex=12; r.Parent=c; Corner(r,UDim.new(1,0))
        local i=Instance.new("Frame"); i.Size=UDim2.new(0,18,0,18); i.AnchorPoint=Vector2.new(0.5,0.5)
        i.Position=UDim2.new(0.5,0,0.5,0); i.BackgroundColor3=Theme.Accent
        i.BorderSizePixel=0; i.ZIndex=13; i.Parent=c; Corner(i,UDim.new(1,0))
        local g=Instance.new("Frame"); g.Size=UDim2.new(0,10,0,10); g.AnchorPoint=Vector2.new(0.5,0.5)
        g.Position=UDim2.new(0.5,0,0.5,0); g.BackgroundColor3=Color3.fromRGB(255,255,255)
        g.BackgroundTransparency=0.4; g.BorderSizePixel=0; g.ZIndex=14; g.Parent=c; Corner(g,UDim.new(1,0))
    end
end

-- TAB ICONS
local function CreateTabIcon(parent, iconType, sbWidth, iconColor)
    local sz = RS(20, 18)
    local xOff = RS(18, 12)
    local c=Instance.new("Frame"); c.Size=UDim2.new(0,sz,0,sz)
    c.Position=UDim2.new(0,xOff,0.5,-sz/2)
    c.BackgroundTransparency=1; c.ZIndex=9; c.Parent=parent
    local m={
        circle="●",square="■",diamond="◆",bars="≡",triangle="▶",
        ["dot-grid"]="⊞",settings="⚙",bolt="⚡",shield="⛨",star="★",
        coin="$",trash="✕",["arrow-up"]="▲",fire="◈",list="☰",
        refresh="⟳",target="◎",crown="♛",skull="☠",webhook="🔗",
    }
    local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,0,1,0)
    l.BackgroundTransparency=1; l.Text=m[iconType] or "●"
    l.TextColor3=iconColor or Theme.Accent; l.TextSize=RS(16,14)
    l.Font=Enum.Font.GothamBold
    l.ZIndex=10; l.Parent=c
end

local IconTypes={"circle","square","diamond","bars","triangle","dot-grid","bolt","star","shield"}

-- ════════════════════════════════════════════════════════════════
-- CREATE WINDOW
-- ════════════════════════════════════════════════════════════════

function GluttonyUI:CreateWindow(options)
    if type(options)=="string" then options={Title=options} end
    options=options or {}
    local title      = options.Title or "Gluttony Core"
    local configName = options.ConfigName
    local antiAfk    = options.AntiAFK

    -- Configure webhook if options provided
    if options.Webhook then
        local wh = options.Webhook
        if wh.URL then WebhookSystem:SetURL(wh.URL) end
        WebhookSystem:Configure({
            Title       = wh.Title       or title,
            TitleIcon   = wh.TitleIcon   or WebhookSystem._config.TitleIcon,
            FooterText  = wh.FooterText  or (title .. " • Gluttony UI"),
            FooterIcon  = wh.FooterIcon  or WebhookSystem._config.FooterIcon,
            GameName    = wh.GameName    or options.GameName or "Unknown Game",
            Color       = wh.Color       or WebhookSystem._config.Color,
            AccentColor = wh.AccentColor or nil,
        })
    end

    for _,v in pairs(playerGui:GetChildren()) do
        if v.Name=="GluttonyUILib" then v:Destroy() end
    end
    DisconnectAll(); ThreadManager:StopAll(); StopAntiAFK()
    StateStore={}; ConfigManager._uiUpdaters={}; ConfigManager._toggleMeta={}
    ConfigManager:Init(configName); ConfigManager:Load()
    if antiAfk then StartAntiAFK() end

    _screenSize = workspace.CurrentCamera.ViewportSize
    _isMobile   = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

    local WW = RS(620, math.floor(math.min(_screenSize.X * 0.97, 460)))
    local WH = RS(480, math.floor(math.min(_screenSize.Y * 0.88, 580)))
    local SW = RS(150, 110)
    local TH = RS(42, 50)
    local RH = RS(48, 52)

    local screenGui=Instance.new("ScreenGui"); screenGui.Name="GluttonyUILib"
    screenGui.ResetOnSpawn=false
    screenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    screenGui.Parent=playerGui
    EnsureNotifContainer(screenGui)

    -- MAIN FRAME
    local main=Instance.new("Frame"); main.Name="Main"
    main.Size=UDim2.new(0,WW,0,WH)
    if _isMobile then
        main.Position = UDim2.new(0, math.floor((_screenSize.X - WW) / 2), 0, math.floor((_screenSize.Y - WH) / 2))
    else
        main.Position = UDim2.new(0.5, -WW/2, 0.5, -WH/2)
    end
    main.BackgroundColor3=Theme.Background; main.BorderSizePixel=0
    main.ClipsDescendants=true; main.Parent=screenGui
    Corner(main,Theme.CornerLarge); Stroke(main,Theme.Border,1.5,0.3)

    local shadow=Instance.new("ImageLabel"); shadow.AnchorPoint=Vector2.new(0.5,0.5)
    shadow.BackgroundTransparency=1; shadow.Position=UDim2.new(0.5,0,0.5,0)
    shadow.Size=UDim2.new(1,60,1,60); shadow.ZIndex=-1
    shadow.Image="rbxassetid://5554236805"; shadow.ImageColor3=Theme.Shadow
    shadow.ImageTransparency=0.4; shadow.ScaleType=Enum.ScaleType.Slice
    shadow.SliceCenter=Rect.new(23,23,277,277); shadow.Parent=main

    local inner=Instance.new("Frame"); inner.Name="Inner"
    inner.Size=UDim2.new(1,0,1,0); inner.BackgroundTransparency=1
    inner.ClipsDescendants=true; inner.ZIndex=2; inner.Parent=main
    Corner(inner,Theme.CornerLarge)

    -- TITLE BAR
    local titleBar=Instance.new("Frame"); titleBar.Size=UDim2.new(1,0,0,TH)
    titleBar.BackgroundColor3=Theme.TitleBar; titleBar.BorderSizePixel=0
    titleBar.ZIndex=10; titleBar.Parent=inner
    Corner(titleBar,Theme.CornerLarge)

    local titleCover=Instance.new("Frame"); titleCover.Size=UDim2.new(1,0,0,14)
    titleCover.Position=UDim2.new(0,0,1,-14); titleCover.BackgroundColor3=Theme.TitleBar
    titleCover.BorderSizePixel=0; titleCover.ZIndex=10; titleCover.Parent=titleBar

    CreateLogo(titleBar, TH)

    local logoOffset = RS(52, 58)
    local titleLabel=Instance.new("TextLabel")
    titleLabel.Size=UDim2.new(1,-140,1,0)
    titleLabel.Position=UDim2.new(0,logoOffset,0,0)
    titleLabel.BackgroundTransparency=1; titleLabel.Text=title
    titleLabel.TextColor3=Theme.Text; titleLabel.TextSize=Theme.FontSizeLarge
    titleLabel.Font=Theme.Font; titleLabel.TextXAlignment=Enum.TextXAlignment.Left
    titleLabel.ZIndex=11; titleLabel.Parent=titleBar

    local btnSz = RS(28, 34)
    local btnGap = RS(38, 44)
    local btn2Gap = RS(74, 84)

    -- CLOSE BUTTON
    local closeBtn=Instance.new("TextButton")
    closeBtn.Size=UDim2.new(0,btnSz,0,btnSz)
    closeBtn.Position=UDim2.new(1,-btnGap,0.5,-btnSz/2)
    closeBtn.BackgroundColor3=Color3.fromRGB(60,35,35)
    closeBtn.Text=""; closeBtn.BorderSizePixel=0
    closeBtn.AutoButtonColor=false; closeBtn.ZIndex=12; closeBtn.Parent=titleBar
    Corner(closeBtn,Theme.CornerRadius)

    local x1=Instance.new("Frame"); x1.Size=UDim2.new(0,12,0,2)
    x1.AnchorPoint=Vector2.new(0.5,0.5); x1.Position=UDim2.new(0.5,0,0.5,0)
    x1.BackgroundColor3=Theme.Accent; x1.Rotation=45; x1.BorderSizePixel=0
    x1.ZIndex=13; x1.Parent=closeBtn; Corner(x1,UDim.new(1,0))
    local x2=x1:Clone(); x2.Rotation=-45; x2.Parent=closeBtn

    if not _isMobile then
        AddConnection(closeBtn.MouseEnter:Connect(function()
            Tween(closeBtn,{BackgroundColor3=Theme.Accent},0.15)
            Tween(x1,{BackgroundColor3=Theme.Text},0.15)
            Tween(x2,{BackgroundColor3=Theme.Text},0.15)
        end))
        AddConnection(closeBtn.MouseLeave:Connect(function()
            Tween(closeBtn,{BackgroundColor3=Color3.fromRGB(60,35,35)},0.15)
            Tween(x1,{BackgroundColor3=Theme.Accent},0.15)
            Tween(x2,{BackgroundColor3=Theme.Accent},0.15)
        end))
    end
    AddConnection(closeBtn.MouseButton1Click:Connect(function()
        ConfigManager:Flush(); ThreadManager:StopAll(); StopAntiAFK()
        DisconnectAll(); screenGui:Destroy()
    end))

    -- MINIMIZE BUTTON
    local minBtn=Instance.new("TextButton")
    minBtn.Size=UDim2.new(0,btnSz,0,btnSz)
    minBtn.Position=UDim2.new(1,-btn2Gap,0.5,-btnSz/2)
    minBtn.BackgroundColor3=Color3.fromRGB(45,45,55)
    minBtn.Text=""; minBtn.BorderSizePixel=0
    minBtn.AutoButtonColor=false; minBtn.ZIndex=12; minBtn.Parent=titleBar
    minBtn.Active=true
    Corner(minBtn,Theme.CornerRadius)

    local minLine=Instance.new("Frame"); minLine.Size=UDim2.new(0,12,0,2)
    minLine.Position=UDim2.new(0.5,-6,0.5,-1); minLine.BackgroundColor3=Theme.TextDim
    minLine.BorderSizePixel=0; minLine.ZIndex=13; minLine.Parent=minBtn
    Corner(minLine,UDim.new(1,0))

    local minimized = false
    local guiVisible = true

    if not _isMobile then
        AddConnection(minBtn.MouseEnter:Connect(function()
            Tween(minBtn,{BackgroundColor3=Color3.fromRGB(60,60,75)},0.15)
            Tween(minLine,{BackgroundColor3=Theme.Text},0.15)
        end))
        AddConnection(minBtn.MouseLeave:Connect(function()
            Tween(minBtn,{BackgroundColor3=Color3.fromRGB(45,45,55)},0.15)
            Tween(minLine,{BackgroundColor3=Theme.TextDim},0.15)
        end))
    end

    AddConnection(minBtn.MouseButton1Click:Connect(function()
        if guiVisible then
            guiVisible = false; minimized = true
            Tween(main, {Size=UDim2.new(0,WW,0,0)}, 0.3)
            task.delay(0.3, function()
                if main and main.Parent then main.Visible=false end
            end)
        else
            guiVisible = true; minimized = false
            main.Visible=true; main.Size=UDim2.new(0,WW,0,0)
            Tween(main, {Size=UDim2.new(0,WW,0,WH)}, 0.35, Enum.EasingStyle.Back)
        end
    end))

    -- DRAG (PC only)
    if not _isMobile then
        local dragging=false; local dragStartInput=nil; local startPos=nil
        AddConnection(titleBar.InputBegan:Connect(function(input)
            if input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
            dragging=true; dragStartInput=Vector2.new(input.Position.X,input.Position.Y)
            local absPos=main.AbsolutePosition
            startPos=UDim2.new(0,absPos.X,0,absPos.Y)
        end))
        AddConnection(UserInputService.InputChanged:Connect(function(input)
            if not dragging or not dragStartInput or not startPos then return end
            if input.UserInputType~=Enum.UserInputType.MouseMovement then return end
            local current=Vector2.new(input.Position.X,input.Position.Y)
            local d=current-dragStartInput
            main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,
                startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end))
        AddConnection(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
            dragging=false; dragStartInput=nil; startPos=nil
        end))
    end

    -- SIDEBAR
    local sidebar=Instance.new("Frame")
    sidebar.Size=UDim2.new(0,SW,1,-TH)
    sidebar.Position=UDim2.new(0,0,0,TH)
    sidebar.BackgroundColor3=Theme.Sidebar; sidebar.BorderSizePixel=0
    sidebar.ZIndex=5; sidebar.Parent=inner; Corner(sidebar,Theme.CornerLarge)

    local divider=Instance.new("Frame"); divider.Size=UDim2.new(0,1,1,-20)
    divider.Position=UDim2.new(1,0,0,10); divider.BackgroundColor3=Theme.Border
    divider.BackgroundTransparency=0.5; divider.BorderSizePixel=0
    divider.ZIndex=6; divider.Parent=sidebar

    local tabContainer=Instance.new("Frame"); tabContainer.Size=UDim2.new(1,0,1,-20)
    tabContainer.Position=UDim2.new(0,0,0,10); tabContainer.BackgroundTransparency=1
    tabContainer.ZIndex=6; tabContainer.Parent=sidebar; ListLayout(tabContainer,RS(5,4))

    -- CONTENT AREA
    local content=Instance.new("Frame")
    content.Size=UDim2.new(1,-SW-1,1,-TH-10)
    content.Position=UDim2.new(0,SW+1,0,TH)
    content.BackgroundColor3=Theme.Background; content.BorderSizePixel=0
    content.ClipsDescendants=false; content.ZIndex=5; content.Parent=inner
    Corner(content,Theme.CornerLarge)

    -- KEYBIND
    if not _isMobile then
        AddConnection(UserInputService.InputBegan:Connect(function(input,processed)
            if processed then return end
            if input.KeyCode==Enum.KeyCode.RightShift then
                if main.Visible then
                    Tween(main,{Size=UDim2.new(0,WW,0,0)},0.3)
                    task.wait(0.3); main.Visible=false
                else
                    main.Visible=true; main.Size=UDim2.new(0,WW,0,0)
                    Tween(main,{Size=UDim2.new(0,WW,0,WH)},0.4,Enum.EasingStyle.Back)
                end
            end
        end))
    end

    AddConnection(Players.PlayerRemoving:Connect(function(plr)
        if plr==player then
            ConfigManager:Flush(); ThreadManager:StopAll(); StopAntiAFK()
        end
    end))

    -- WINDOW OBJECT
    local Window={}
    Window._pages={}; Window._tabButtons={}
    Window._currentTab=nil; Window._tabCount=0
    local activeDropdownPanel=nil

    local function SwitchTab(tabName)
        if activeDropdownPanel and activeDropdownPanel.Parent then
            activeDropdownPanel.Visible=false
            activeDropdownPanel.Size=UDim2.new(0,0,0,0)
            activeDropdownPanel=nil
        end
        Window._currentTab=tabName
        for name,pg in pairs(Window._pages) do pg.Visible=(name==tabName) end
        for name,btn in pairs(Window._tabButtons) do
            local ind=btn:FindFirstChild("Indicator")
            local lbl=btn:FindFirstChild("Label")
            if name==tabName then
                Tween(btn,{BackgroundColor3=Theme.SelectedTab},0.2)
                if ind then Tween(ind,{BackgroundTransparency=0,Size=UDim2.new(0,4,0,26)},0.2) end
                if lbl then Tween(lbl,{TextColor3=Theme.Text},0.2) end
            else
                Tween(btn,{BackgroundColor3=Theme.Sidebar},0.2)
                if ind then Tween(ind,{BackgroundTransparency=1,Size=UDim2.new(0,4,0,22)},0.2) end
                if lbl then Tween(lbl,{TextColor3=Theme.TextDim},0.15) end
            end
        end
    end

    -- ADD TAB
    function Window:AddTab(name, iconType, iconColor)
        Window._tabCount=Window._tabCount+1
        local isFirst=Window._tabCount==1
        iconType=iconType or IconTypes[((Window._tabCount-1)%#IconTypes)+1]

        local tabBtnH=RS(42,46)
        local tabBtn=Instance.new("TextButton"); tabBtn.Name="Tab_"..name
        tabBtn.Size=UDim2.new(1,-RS(14,10),0,tabBtnH)
        tabBtn.BackgroundColor3=isFirst and Theme.SelectedTab or Theme.Sidebar
        tabBtn.BorderSizePixel=0; tabBtn.Text=""; tabBtn.AutoButtonColor=false
        tabBtn.LayoutOrder=Window._tabCount; tabBtn.ZIndex=7; tabBtn.Parent=tabContainer
        Corner(tabBtn,Theme.CornerRadius)

        local indicator=Instance.new("Frame"); indicator.Name="Indicator"
        indicator.Size=isFirst and UDim2.new(0,4,0,26) or UDim2.new(0,4,0,22)
        indicator.Position=UDim2.new(0,5,0.5,-11)
        indicator.BackgroundColor3=Theme.Accent
        indicator.BackgroundTransparency=isFirst and 0 or 1
        indicator.BorderSizePixel=0; indicator.ZIndex=8; indicator.Parent=tabBtn
        Corner(indicator,UDim.new(1,0))

        CreateTabIcon(tabBtn, iconType, SW, iconColor)

        local iconW=RS(44,38)
        local tabLabel=Instance.new("TextLabel"); tabLabel.Name="Label"
        tabLabel.Size=UDim2.new(1,-iconW,1,0)
        tabLabel.Position=UDim2.new(0,iconW,0,0)
        tabLabel.BackgroundTransparency=1; tabLabel.Text=name
        tabLabel.TextColor3=isFirst and Theme.Text or Theme.TextDim
        tabLabel.TextSize=Theme.TabFontSize; tabLabel.Font=Theme.FontLight
        tabLabel.TextXAlignment=Enum.TextXAlignment.Left
        tabLabel.TextTruncate=Enum.TextTruncate.AtEnd
        tabLabel.ZIndex=8; tabLabel.Parent=tabBtn

        if not _isMobile then
            AddConnection(tabBtn.MouseEnter:Connect(function()
                if Window._currentTab~=name then
                    Tween(tabBtn,{BackgroundColor3=Theme.Hover},0.15)
                    Tween(tabLabel,{TextColor3=Theme.Text},0.15)
                end
            end))
            AddConnection(tabBtn.MouseLeave:Connect(function()
                if Window._currentTab~=name then
                    Tween(tabBtn,{BackgroundColor3=Theme.Sidebar},0.15)
                    Tween(tabLabel,{TextColor3=Theme.TextDim},0.15)
                end
            end))
        end
        AddConnection(tabBtn.MouseButton1Click:Connect(function() SwitchTab(name) end))
        Window._tabButtons[name]=tabBtn

        local pagePadH=RS(18,14); local pagePadS=RS(22,16)
        local page=Instance.new("ScrollingFrame"); page.Name="Page_"..name
        page.Size=UDim2.new(1,0,1,0); page.BackgroundTransparency=1
        page.BorderSizePixel=0; page.ScrollBarThickness=RS(4,5)
        page.ScrollBarImageColor3=Theme.Accent; page.ScrollBarImageTransparency=0.3
        page.CanvasSize=UDim2.new(0,0,0,0); page.Visible=isFirst; page.ZIndex=6
        page.Parent=content
        Padding(page,pagePadH,pagePadH,pagePadS,pagePadS)

        local pageLayout=ListLayout(page,RS(8,10))

        local titleFrame=Instance.new("Frame"); titleFrame.Size=UDim2.new(1,0,0,42)
        titleFrame.BackgroundTransparency=1; titleFrame.LayoutOrder=0
        titleFrame.ZIndex=7; titleFrame.Parent=page

        local ptl=Instance.new("TextLabel"); ptl.Size=UDim2.new(1,0,0,34)
        ptl.BackgroundTransparency=1; ptl.Text=name; ptl.TextColor3=Theme.Text
        ptl.TextSize=RS(24,22); ptl.Font=Theme.Font
        ptl.TextXAlignment=Enum.TextXAlignment.Left; ptl.ZIndex=7; ptl.Parent=titleFrame

        local ul=Instance.new("Frame"); ul.Size=UDim2.new(0.25,0,0,2)
        ul.Position=UDim2.new(0,0,1,-2); ul.BackgroundColor3=Theme.Accent
        ul.BackgroundTransparency=0.3; ul.BorderSizePixel=0; ul.ZIndex=8; ul.Parent=titleFrame
        Corner(ul,UDim.new(1,0))
        local ulg=Instance.new("UIGradient")
        ulg.Transparency=NumberSequence.new({
            NumberSequenceKeypoint.new(0,0),
            NumberSequenceKeypoint.new(0.7,0),
            NumberSequenceKeypoint.new(1,1)
        })
        ulg.Parent=ul

        AddConnection(pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            page.CanvasSize=UDim2.new(0,0,0,pageLayout.AbsoluteContentSize.Y+40)
        end))

        Window._pages[name]=page
        if isFirst then Window._currentTab=name end

        -- TAB OBJECT
        local Tab={}; Tab._itemCount=0
        local function NextOrder() Tab._itemCount=Tab._itemCount+1; return Tab._itemCount end

        function Tab:AddSection(t)
            local o=NextOrder()
            local sl=Instance.new("TextLabel"); sl.Size=UDim2.new(1,0,0,30)
            sl.BackgroundTransparency=1; sl.Text=t; sl.TextColor3=Theme.Accent
            sl.TextSize=RS(15,16); sl.Font=Theme.Font
            sl.TextXAlignment=Enum.TextXAlignment.Left; sl.LayoutOrder=o
            sl.ZIndex=7; sl.Parent=page
            local sc=Instance.new("Frame"); sc.Size=UDim2.new(1,0,0,8)
            sc.BackgroundTransparency=1; sc.LayoutOrder=o+0.5; sc.Parent=page
            local sep=Instance.new("Frame"); sep.Size=UDim2.new(0.4,0,0,1)
            sep.Position=UDim2.new(0,0,0.5,0); sep.BackgroundColor3=Theme.Accent
            sep.BackgroundTransparency=0.5; sep.BorderSizePixel=0
            sep.ZIndex=7; sep.Parent=sc; Corner(sep,UDim.new(1,0))
            local sg=Instance.new("UIGradient")
            sg.Transparency=NumberSequence.new({
                NumberSequenceKeypoint.new(0,0),
                NumberSequenceKeypoint.new(0.5,0.3),
                NumberSequenceKeypoint.new(1,1)
            })
            sg.Parent=sep
        end

        function Tab:AddLabel(t)
            local o=NextOrder()
            local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,0,0,28)
            l.BackgroundTransparency=1; l.Text=t; l.TextColor3=Theme.TextDim
            l.TextSize=RS(13,14); l.Font=Theme.FontLight
            l.TextXAlignment=Enum.TextXAlignment.Left; l.TextWrapped=true
            l.LayoutOrder=o; l.ZIndex=7; l.Parent=page; return l
        end

        function Tab:AddSpacer(h)
            local o=NextOrder()
            local s=Instance.new("Frame"); s.Size=UDim2.new(1,0,0,h or 16)
            s.BackgroundTransparency=1; s.LayoutOrder=o; s.Parent=page
        end

        function Tab:AddHint(t)
            local o=NextOrder()
            local hh=RS(56,64)
            local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,hh)
            f.BackgroundColor3=Theme.HintBg; f.BorderSizePixel=0
            f.LayoutOrder=o; f.ZIndex=6; f.Parent=page
            Corner(f,Theme.CornerRadius); Stroke(f,Theme.HintColor,1,0.5)
            local ib=Instance.new("Frame"); ib.Size=UDim2.new(0,32,0,32)
            ib.Position=UDim2.new(0,12,0.5,-16); ib.BackgroundColor3=Theme.HintColor
            ib.BackgroundTransparency=0.85; ib.BorderSizePixel=0; ib.ZIndex=7; ib.Parent=f
            Corner(ib,UDim.new(0,6))
            local il=Instance.new("TextLabel"); il.Size=UDim2.new(1,0,1,0)
            il.BackgroundTransparency=1; il.Text="💡"; il.TextSize=16; il.ZIndex=8; il.Parent=ib
            local ht=Instance.new("TextLabel"); ht.Size=UDim2.new(1,-60,1,-16)
            ht.Position=UDim2.new(0,52,0,8); ht.BackgroundTransparency=1; ht.Text=t
            ht.TextColor3=Theme.HintColor; ht.TextSize=RS(13,14); ht.Font=Theme.FontLight
            ht.TextXAlignment=Enum.TextXAlignment.Left; ht.TextWrapped=true
            ht.ZIndex=7; ht.Parent=f; return f
        end

        function Tab:AddWarning(t)
            local o=NextOrder()
            local wh=RS(56,64)
            local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,wh)
            f.BackgroundColor3=Theme.WarningBg; f.BorderSizePixel=0
            f.LayoutOrder=o; f.ZIndex=6; f.Parent=page
            Corner(f,Theme.CornerRadius); Stroke(f,Theme.WarningColor,1,0.5)
            local ib=Instance.new("Frame"); ib.Size=UDim2.new(0,32,0,32)
            ib.Position=UDim2.new(0,12,0.5,-16); ib.BackgroundColor3=Theme.WarningColor
            ib.BackgroundTransparency=0.85; ib.BorderSizePixel=0; ib.ZIndex=7; ib.Parent=f
            Corner(ib,UDim.new(0,6))
            local il=Instance.new("TextLabel"); il.Size=UDim2.new(1,0,1,0)
            il.BackgroundTransparency=1; il.Text="⚠️"; il.TextSize=16; il.ZIndex=8; il.Parent=ib
            local wt=Instance.new("TextLabel"); wt.Size=UDim2.new(1,-60,1,-16)
            wt.Position=UDim2.new(0,52,0,8); wt.BackgroundTransparency=1; wt.Text=t
            wt.TextColor3=Theme.WarningColor; wt.TextSize=RS(13,14); wt.Font=Theme.FontLight
            wt.TextXAlignment=Enum.TextXAlignment.Left; wt.TextWrapped=true
            wt.ZIndex=7; wt.Parent=f; return f
        end

        -- INTERVAL TOGGLE
        function Tab:AddIntervalToggle(labelText, default, callback, intervalDefault)
            local order=NextOrder()
            local savedState=StateStore[labelText]
            local state=(savedState~=nil) and savedState or (default or false)
            StateStore[labelText]=state

            local intervalKey=labelText.."_interval"
            local savedInterval=StateStore[intervalKey]
            local intervalValue=math.max(1,math.floor(
                tonumber(tostring(savedInterval~=nil and savedInterval or (intervalDefault or 1))) or 1))
            StateStore[intervalKey]=intervalValue

            local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,RH)
            row.BackgroundColor3=RowColor(order); row.BorderSizePixel=0
            row.LayoutOrder=order; row.ZIndex=6; row.ClipsDescendants=true
            row.Parent=page; Corner(row,Theme.CornerRadius)
            local ab=HoverAccent(row)

            local lblW=_isMobile and -190 or -180
            local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,lblW,1,0)
            lbl.Position=UDim2.new(0,18,0,0); lbl.BackgroundTransparency=1
            lbl.Text=labelText; lbl.TextColor3=Theme.Text; lbl.TextSize=Theme.FontSize
            lbl.Font=Theme.FontLight; lbl.TextXAlignment=Enum.TextXAlignment.Left
            lbl.TextTruncate=Enum.TextTruncate.AtEnd; lbl.ZIndex=7; lbl.Parent=row

            local ibW=RS(50,46); local ibX=RS(-115,-118)
            local ibg=Instance.new("Frame"); ibg.Size=UDim2.new(0,ibW,0,RS(26,30))
            ibg.Position=UDim2.new(1,ibX,0.5,-RS(13,15))
            ibg.BackgroundColor3=Theme.InputBg; ibg.BorderSizePixel=0
            ibg.ZIndex=8; ibg.Parent=row; Corner(ibg,UDim.new(0,6))
            local gs=Stroke(ibg,Theme.Accent,1.5,1)

            local input=Instance.new("TextBox"); input.Size=UDim2.new(1,0,1,0)
            input.BackgroundTransparency=1; input.Text=tostring(intervalValue)
            input.PlaceholderText="sec"; input.PlaceholderColor3=Theme.TextDim
            input.TextColor3=Theme.Text; input.TextSize=RS(12,13); input.Font=Theme.FontLight
            input.ClearTextOnFocus=true; input.TextXAlignment=Enum.TextXAlignment.Center
            input.ZIndex=9; input.Parent=ibg

            local tbW=RS(46,48); local tbX=RS(-60,-64)
            local tbg=Instance.new("Frame"); tbg.Size=UDim2.new(0,tbW,0,RS(24,28))
            tbg.Position=UDim2.new(1,tbX,0.5,-RS(12,14))
            tbg.BackgroundColor3=state and Theme.ToggleOn or Theme.ToggleOff
            tbg.BorderSizePixel=0; tbg.ZIndex=8; tbg.Parent=row; Corner(tbg,UDim.new(1,0))

            local circSz=RS(20,24)
            local circle=Instance.new("Frame"); circle.Size=UDim2.new(0,circSz,0,circSz)
            circle.Position=state and UDim2.new(1,-(circSz+2),0.5,-circSz/2) or UDim2.new(0,2,0.5,-circSz/2)
            circle.BackgroundColor3=Theme.Text; circle.BorderSizePixel=0
            circle.ZIndex=9; circle.Parent=tbg; Corner(circle,UDim.new(1,0))

            local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,1,0)
            btn.BackgroundTransparency=1; btn.Text=""; btn.ZIndex=10; btn.Parent=tbg

            local function StartLoop()
                if state and callback then
                    local safeInterval=math.max(1,math.floor(tonumber(tostring(intervalValue)) or 1))
                    ThreadManager:Start(labelText,safeInterval,function() callback() end)
                end
            end

            AddConnection(input.FocusLost:Connect(function()
                local val=math.floor(tonumber(tostring(input.Text)) or 0)
                if val and val>=1 then
                    intervalValue=val; ConfigManager:Set(intervalKey,val)
                    input.Text=tostring(val)
                    if state then StartLoop() end
                else input.Text=tostring(intervalValue) end
                Tween(gs,{Transparency=1},0.2)
            end))
            AddConnection(input.Focused:Connect(function() Tween(gs,{Transparency=0.4},0.2) end))
            AddConnection(btn.MouseButton1Click:Connect(function()
                state=not state; ConfigManager:Set(labelText,state)
                Tween(tbg,{BackgroundColor3=state and Theme.ToggleOn or Theme.ToggleOff},0.2)
                Tween(circle,{Position=state
                    and UDim2.new(1,-(circSz+2),0.5,-circSz/2)
                    or UDim2.new(0,2,0.5,-circSz/2)},0.2,Enum.EasingStyle.Back)
                if state then StartLoop() else ThreadManager:Stop(labelText) end
            end))
            if state then task.defer(StartLoop) end
            SetupHover(row,RowColor(order),ab)
            return {
                Set=function(_,v)
                    state=v; ConfigManager:Set(labelText,v)
                    Tween(tbg,{BackgroundColor3=state and Theme.ToggleOn or Theme.ToggleOff},0.2)
                    Tween(circle,{Position=state
                        and UDim2.new(1,-(circSz+2),0.5,-circSz/2)
                        or UDim2.new(0,2,0.5,-circSz/2)},0.2)
                    if state then StartLoop() else ThreadManager:Stop(labelText) end
                end,
                Get=function() return state end
            }
        end

        -- TOGGLE
        function Tab:AddToggle(labelText,default,intervalOrCallback,callbackOrNil)
            local order=NextOrder(); local interval,callback
            if type(intervalOrCallback)=="function" then
                interval=nil; callback=intervalOrCallback
            else interval=intervalOrCallback; callback=callbackOrNil end

            local saved=StateStore[labelText]
            local state=(saved~=nil) and saved or (default or false)
            StateStore[labelText]=state
            if interval and callback then
                ConfigManager._toggleMeta[labelText]={interval=interval,callback=callback}
            end

            local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,RH)
            row.BackgroundColor3=RowColor(order); row.BorderSizePixel=0
            row.LayoutOrder=order; row.ZIndex=6; row.ClipsDescendants=true
            row.Parent=page; Corner(row,Theme.CornerRadius)
            local ab=HoverAccent(row)

            local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-80,1,0)
            lbl.Position=UDim2.new(0,18,0,0); lbl.BackgroundTransparency=1
            lbl.Text=labelText; lbl.TextColor3=Theme.Text; lbl.TextSize=Theme.FontSize
            lbl.Font=Theme.FontLight; lbl.TextXAlignment=Enum.TextXAlignment.Left
            lbl.TextTruncate=Enum.TextTruncate.AtEnd; lbl.ZIndex=7; lbl.Parent=row

            local tbW=RS(46,50); local tbH=RS(24,28); local tbX=RS(-60,-66)
            local tbg=Instance.new("Frame"); tbg.Size=UDim2.new(0,tbW,0,tbH)
            tbg.Position=UDim2.new(1,tbX,0.5,-tbH/2)
            tbg.BackgroundColor3=state and Theme.ToggleOn or Theme.ToggleOff
            tbg.BorderSizePixel=0; tbg.ZIndex=8; tbg.Parent=row; Corner(tbg,UDim.new(1,0))

            local circSz=RS(20,24)
            local circle=Instance.new("Frame"); circle.Size=UDim2.new(0,circSz,0,circSz)
            circle.Position=state
                and UDim2.new(1,-(circSz+2),0.5,-circSz/2)
                or UDim2.new(0,2,0.5,-circSz/2)
            circle.BackgroundColor3=Theme.Text; circle.BorderSizePixel=0
            circle.ZIndex=9; circle.Parent=tbg; Corner(circle,UDim.new(1,0))
            Stroke(circle,Theme.Shadow,1,0.7)

            local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,1,0)
            btn.BackgroundTransparency=1; btn.Text=""; btn.ZIndex=10; btn.Parent=tbg

            local function UV(v)
                state=v; tbg.BackgroundColor3=v and Theme.ToggleOn or Theme.ToggleOff
                circle.Position=v
                    and UDim2.new(1,-(circSz+2),0.5,-circSz/2)
                    or UDim2.new(0,2,0.5,-circSz/2)
            end

            ConfigManager:RegisterUpdater(labelText,function(v)
                if type(v)=="boolean" then UV(v) end
            end)

            local function SS(ns)
                state=ns; ConfigManager:Set(labelText,state)
                Tween(tbg,{BackgroundColor3=state and Theme.ToggleOn or Theme.ToggleOff},0.25)
                Tween(circle,{Position=state
                    and UDim2.new(1,-(circSz+2),0.5,-circSz/2)
                    or UDim2.new(0,2,0.5,-circSz/2)},0.25,Enum.EasingStyle.Back)
                Tween(circle,{Size=UDim2.new(0,circSz+2,0,circSz+2)},0.08)
                task.delay(0.08,function()
                    Tween(circle,{Size=UDim2.new(0,circSz,0,circSz)},0.12)
                end)
                if interval and callback then
                    if state then ThreadManager:Start(labelText,interval,callback)
                    else ThreadManager:Stop(labelText) end
                elseif callback then task.spawn(callback,state) end
            end

            AddConnection(btn.MouseButton1Click:Connect(function() SS(not state) end))
            SetupHover(row,RowColor(order),ab)
            if state then
                if interval and callback then
                    task.defer(function() ThreadManager:Start(labelText,interval,callback) end)
                elseif callback then task.defer(callback,state) end
            end
            return {
                Set=function(_,v) SS(v) end,
                Get=function() return state end
            }
        end

        -- SLIDER
        function Tab:AddSlider(labelText,min,max,default,callback)
            local order=NextOrder()
            local saved=StateStore[labelText]
            local value=(saved~=nil and type(saved)=="number")
                and math.clamp(saved,min,max)
                or math.clamp(default or min,min,max)
            StateStore[labelText]=value

            local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,RH+4)
            row.BackgroundColor3=RowColor(order); row.BorderSizePixel=0
            row.LayoutOrder=order; row.ZIndex=6; row.ClipsDescendants=true
            row.Parent=page; Corner(row,Theme.CornerRadius)
            local ab=HoverAccent(row)

            local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0,RS(170,120),1,0)
            lbl.Position=UDim2.new(0,18,0,0); lbl.BackgroundTransparency=1
            lbl.Text=labelText; lbl.TextColor3=Theme.Text; lbl.TextSize=Theme.FontSize
            lbl.Font=Theme.FontLight; lbl.TextXAlignment=Enum.TextXAlignment.Left
            lbl.TextTruncate=Enum.TextTruncate.AtEnd; lbl.ZIndex=7; lbl.Parent=row

            local vbW=RS(42,38); local vbX=RS(-158,-150)
            local vb=Instance.new("Frame"); vb.Size=UDim2.new(0,vbW,0,22)
            vb.Position=UDim2.new(1,vbX,0.5,-11)
            vb.BackgroundColor3=Theme.Accent; vb.BackgroundTransparency=0.85
            vb.BorderSizePixel=0; vb.ZIndex=7; vb.Parent=row; Corner(vb,UDim.new(0,5))

            local vl=Instance.new("TextLabel"); vl.Size=UDim2.new(1,0,1,0)
            vl.BackgroundTransparency=1; vl.Text=tostring(math.floor(value))
            vl.TextColor3=Theme.Accent; vl.TextSize=13; vl.Font=Theme.Font
            vl.ZIndex=8; vl.Parent=vb

            local trackW=RS(100,90); local trackH=RS(6,8)
            local track=Instance.new("Frame"); track.Size=UDim2.new(0,trackW,0,trackH)
            track.Position=UDim2.new(1,-(trackW+RS(12,10)),0.5,-trackH/2)
            track.BackgroundColor3=Theme.SliderBg; track.BorderSizePixel=0
            track.ZIndex=8; track.Parent=row; Corner(track,UDim.new(1,0))

            local pct=(value-min)/math.max(max-min,1)
            local fill=Instance.new("Frame"); fill.Size=UDim2.new(pct,0,1,0)
            fill.BackgroundColor3=Theme.SliderFill; fill.BorderSizePixel=0
            fill.ZIndex=9; fill.Parent=track; Corner(fill,UDim.new(1,0))

            local knobSz=RS(16,20)
            local knob=Instance.new("Frame"); knob.Size=UDim2.new(0,knobSz,0,knobSz)
            knob.Position=UDim2.new(pct,-knobSz/2,0.5,-knobSz/2)
            knob.BackgroundColor3=Theme.Text; knob.BorderSizePixel=0
            knob.ZIndex=10; knob.Parent=track; Corner(knob,UDim.new(1,0))
            Stroke(knob,Theme.Shadow,1,0.75)

            local sliding=false
            local hitPad=RS(7,14)
            local hit=Instance.new("TextButton")
            hit.Size=UDim2.new(1,hitPad*2,1,hitPad*2)
            hit.Position=UDim2.new(0,-hitPad,0,-hitPad)
            hit.BackgroundTransparency=1; hit.Text=""
            hit.ZIndex=11; hit.Parent=track

            local function UV(v)
                local p=(v-min)/math.max(max-min,1)
                vl.Text=tostring(math.floor(v))
                fill.Size=UDim2.new(p,0,1,0)
                knob.Position=UDim2.new(p,-knobSz/2,0.5,-knobSz/2)
            end

            ConfigManager:RegisterUpdater(labelText,function(v)
                if type(v)=="number" then
                    v=math.clamp(v,min,max); value=v; UV(v)
                end
            end)

            local function PI(input)
                local x=math.clamp(
                    (input.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
                local v=math.floor(min+(max-min)*x)
                value=v; ConfigManager:Set(labelText,v); UV(v)
                if callback then task.spawn(callback,v) end
            end

            AddConnection(hit.InputBegan:Connect(function(i)
                if i.UserInputType==Enum.UserInputType.MouseButton1
                    or i.UserInputType==Enum.UserInputType.Touch then
                    sliding=true; PI(i)
                end
            end))
            AddConnection(hit.InputEnded:Connect(function(i)
                if i.UserInputType==Enum.UserInputType.MouseButton1
                    or i.UserInputType==Enum.UserInputType.Touch then
                    sliding=false
                end
            end))
            AddConnection(UserInputService.InputChanged:Connect(function(i)
                if sliding and (i.UserInputType==Enum.UserInputType.MouseMovement
                    or i.UserInputType==Enum.UserInputType.Touch) then
                    PI(i)
                end
            end))
            SetupHover(row,RowColor(order),ab)
            return {
                Set=function(_,v)
                    v=math.clamp(v,min,max); value=v
                    ConfigManager:Set(labelText,v); UV(v)
                end,
                Get=function() return value end
            }
        end

        -- BUTTON
        function Tab:AddButton(labelText,callback)
            local order=NextOrder()
            local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,RH)
            row.BackgroundColor3=RowColor(order); row.BorderSizePixel=0
            row.LayoutOrder=order; row.ZIndex=6; row.ClipsDescendants=true
            row.Parent=page; Corner(row,Theme.CornerRadius)
            local ab=HoverAccent(row)

            local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-130,1,0)
            lbl.Position=UDim2.new(0,18,0,0); lbl.BackgroundTransparency=1
            lbl.Text=labelText; lbl.TextColor3=Theme.Text; lbl.TextSize=Theme.FontSize
            lbl.Font=Theme.FontLight; lbl.TextXAlignment=Enum.TextXAlignment.Left
            lbl.TextTruncate=Enum.TextTruncate.AtEnd; lbl.ZIndex=7; lbl.Parent=row

            local bfW=RS(100,90); local bfX=RS(-114,-104)
            local bf=Instance.new("Frame"); bf.Size=UDim2.new(0,bfW,0,RS(32,36))
            bf.Position=UDim2.new(1,bfX,0.5,-RS(16,18))
            bf.BackgroundTransparency=1; bf.ZIndex=7; bf.Parent=row

            local bs=Instance.new("Frame"); bs.Size=UDim2.new(1,2,1,2)
            bs.Position=UDim2.new(0,-1,0,2); bs.BackgroundColor3=Theme.Shadow
            bs.BackgroundTransparency=0.82; bs.BorderSizePixel=0
            bs.ZIndex=7; bs.Parent=bf; Corner(bs,Theme.CornerRadius)

            local button=Instance.new("TextButton"); button.Size=UDim2.new(1,-2,1,-2)
            button.Position=UDim2.new(0,1,0,0); button.BackgroundColor3=Theme.Accent
            button.Text="Execute"; button.TextColor3=Theme.Text
            button.TextSize=Theme.FontSizeSmall; button.Font=Theme.Font
            button.BorderSizePixel=0; button.AutoButtonColor=false
            button.ZIndex=8; button.Parent=bf; Corner(button,Theme.CornerRadius)

            local gs=Stroke(button,Theme.Accent,1.5,1)
            if not _isMobile then
                AddConnection(button.MouseEnter:Connect(function()
                    Tween(button,{BackgroundColor3=Theme.AccentLight},0.15)
                    Tween(gs,{Transparency=0.5},0.2)
                end))
                AddConnection(button.MouseLeave:Connect(function()
                    Tween(button,{BackgroundColor3=Theme.Accent},0.15)
                    Tween(gs,{Transparency=1},0.2)
                end))
            end
            AddConnection(button.MouseButton1Click:Connect(function()
                Tween(button,{Size=UDim2.new(1,-6,1,-4)},0.06)
                task.delay(0.06,function()
                    Tween(button,{Size=UDim2.new(1,-2,1,-2)},0.1,Enum.EasingStyle.Back)
                end)
                if callback then task.spawn(callback) end
            end))
            SetupHover(row,RowColor(order),ab)
        end

        -- STATUS BUTTON
        function Tab:AddStatusButton(labelText,callback)
            local order=NextOrder()
            local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,RH)
            row.BackgroundColor3=RowColor(order); row.BorderSizePixel=0
            row.LayoutOrder=order; row.ZIndex=6; row.ClipsDescendants=true
            row.Parent=page; Corner(row,Theme.CornerRadius)
            local ab=HoverAccent(row)

            local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-130,1,0)
            lbl.Position=UDim2.new(0,18,0,0); lbl.BackgroundTransparency=1
            lbl.Text=labelText; lbl.TextColor3=Theme.Text; lbl.TextSize=Theme.FontSize
            lbl.Font=Theme.FontLight; lbl.TextXAlignment=Enum.TextXAlignment.Left
            lbl.TextTruncate=Enum.TextTruncate.AtEnd; lbl.ZIndex=7; lbl.Parent=row

            local bfW=RS(100,90)
            local bf=Instance.new("Frame"); bf.Size=UDim2.new(0,bfW,0,RS(32,36))
            bf.Position=UDim2.new(1,RS(-114,-104),0.5,-RS(16,18))
            bf.BackgroundTransparency=1; bf.ZIndex=7; bf.Parent=row

            local bs=Instance.new("Frame"); bs.Size=UDim2.new(1,2,1,2)
            bs.Position=UDim2.new(0,-1,0,2); bs.BackgroundColor3=Theme.Shadow
            bs.BackgroundTransparency=0.82; bs.BorderSizePixel=0
            bs.ZIndex=7; bs.Parent=bf; Corner(bs,Theme.CornerRadius)

            local button=Instance.new("TextButton"); button.Size=UDim2.new(1,-2,1,-2)
            button.Position=UDim2.new(0,1,0,0); button.BackgroundColor3=Theme.Accent
            button.Text="Execute"; button.TextColor3=Theme.Text
            button.TextSize=Theme.FontSizeSmall; button.Font=Theme.Font
            button.BorderSizePixel=0; button.AutoButtonColor=false
            button.ZIndex=8; button.Parent=bf; Corner(button,Theme.CornerRadius)

            local gs=Stroke(button,Theme.Accent,1.5,1); local busy=false
            local function SetStatus(st,msg)
                if st=="loading" then
                    button.Text="..."
                    Tween(button,{BackgroundColor3=Color3.fromRGB(100,100,100)},0.15)
                elseif st=="success" then
                    button.Text="✅ "..(msg or "Done")
                    Tween(button,{BackgroundColor3=Theme.NotifSuccess},0.2)
                    task.delay(1.5,function()
                        if button and button.Parent then
                            button.Text="Execute"
                            Tween(button,{BackgroundColor3=Theme.Accent},0.2); busy=false
                        end
                    end)
                elseif st=="error" then
                    button.Text="❌ "..(msg or "Failed")
                    Tween(button,{BackgroundColor3=Theme.NotifError},0.2)
                    task.delay(1.5,function()
                        if button and button.Parent then
                            button.Text="Execute"
                            Tween(button,{BackgroundColor3=Theme.Accent},0.2); busy=false
                        end
                    end)
                else
                    button.Text=msg or "Execute"
                    Tween(button,{BackgroundColor3=Theme.Accent},0.2); busy=false
                end
            end
            if not _isMobile then
                AddConnection(button.MouseEnter:Connect(function()
                    if not busy then
                        Tween(button,{BackgroundColor3=Theme.AccentLight},0.15)
                        Tween(gs,{Transparency=0.5},0.2)
                    end
                end))
                AddConnection(button.MouseLeave:Connect(function()
                    if not busy then
                        Tween(button,{BackgroundColor3=Theme.Accent},0.15)
                        Tween(gs,{Transparency=1},0.2)
                    end
                end))
            end
            AddConnection(button.MouseButton1Click:Connect(function()
                if busy then return end; busy=true
                Tween(button,{Size=UDim2.new(1,-6,1,-4)},0.06)
                task.delay(0.06,function()
                    Tween(button,{Size=UDim2.new(1,-2,1,-2)},0.1,Enum.EasingStyle.Back)
                end)
                if callback then task.spawn(callback,SetStatus) end
            end))
            SetupHover(row,RowColor(order),ab)
        end

        -- INPUT
        function Tab:AddInput(labelText,placeholder,callback)
            local order=NextOrder()
            local saved=StateStore[labelText]
            local ct=(saved~=nil and type(saved)=="string") and saved or ""
            StateStore[labelText]=ct

            local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,RH)
            row.BackgroundColor3=RowColor(order); row.BorderSizePixel=0
            row.LayoutOrder=order; row.ZIndex=6; row.ClipsDescendants=true
            row.Parent=page; Corner(row,Theme.CornerRadius)
            local ab=HoverAccent(row)

            local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0,RS(140,110),1,0)
            lbl.Position=UDim2.new(0,18,0,0); lbl.BackgroundTransparency=1
            lbl.Text=labelText; lbl.TextColor3=Theme.Text; lbl.TextSize=Theme.FontSize
            lbl.Font=Theme.FontLight; lbl.TextXAlignment=Enum.TextXAlignment.Left
            lbl.TextTruncate=Enum.TextTruncate.AtEnd; lbl.ZIndex=7; lbl.Parent=row

            local ibW=RS(180,160)
            local ibg=Instance.new("Frame"); ibg.Size=UDim2.new(0,ibW,0,RS(30,34))
            ibg.Position=UDim2.new(1,-(ibW+RS(16,14)),0.5,-RS(15,17))
            ibg.BackgroundColor3=Theme.InputBg; ibg.BorderSizePixel=0
            ibg.ZIndex=8; ibg.Parent=row; Corner(ibg,UDim.new(0,6))
            local gs=Stroke(ibg,Theme.Accent,1.5,1)

            local input=Instance.new("TextBox"); input.Size=UDim2.new(1,-16,1,0)
            input.Position=UDim2.new(0,8,0,0); input.BackgroundTransparency=1
            input.Text=ct; input.PlaceholderText=placeholder or "Type here..."
            input.PlaceholderColor3=Theme.TextDim; input.TextColor3=Theme.Text
            input.TextSize=Theme.FontSizeSmall; input.Font=Theme.FontLight
            input.ClearTextOnFocus=false; input.TextXAlignment=Enum.TextXAlignment.Left
            input.ZIndex=9; input.Parent=ibg

            ConfigManager:RegisterUpdater(labelText,function(v)
                if type(v)=="string" then input.Text=v end
            end)
            AddConnection(input.Focused:Connect(function() Tween(gs,{Transparency=0.4},0.2) end))
            AddConnection(input.FocusLost:Connect(function(ep)
                Tween(gs,{Transparency=1},0.2); ConfigManager:Set(labelText,input.Text)
                if callback then task.spawn(callback,input.Text,ep) end
            end))
            SetupHover(row,RowColor(order),ab)
            return {
                Set=function(_,v) input.Text=v; ConfigManager:Set(labelText,v) end,
                Get=function() return input.Text end
            }
        end

        -- NUMBER INPUT
        function Tab:AddNumberInput(labelText,default,callback)
            local order=NextOrder()
            local saved=StateStore[labelText]
            local value=(saved~=nil and type(saved)=="number") and saved or (default or 0)
            StateStore[labelText]=value

            local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,RH)
            row.BackgroundColor3=RowColor(order); row.BorderSizePixel=0
            row.LayoutOrder=order; row.ZIndex=6; row.ClipsDescendants=true
            row.Parent=page; Corner(row,Theme.CornerRadius)
            local ab=HoverAccent(row)

            local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0,RS(140,110),1,0)
            lbl.Position=UDim2.new(0,18,0,0); lbl.BackgroundTransparency=1
            lbl.Text=labelText; lbl.TextColor3=Theme.Text; lbl.TextSize=Theme.FontSize
            lbl.Font=Theme.FontLight; lbl.TextXAlignment=Enum.TextXAlignment.Left
            lbl.TextTruncate=Enum.TextTruncate.AtEnd; lbl.ZIndex=7; lbl.Parent=row

            local ibW=RS(120,110)
            local ibg=Instance.new("Frame"); ibg.Size=UDim2.new(0,ibW,0,RS(30,34))
            ibg.Position=UDim2.new(1,-(ibW+RS(16,14)),0.5,-RS(15,17))
            ibg.BackgroundColor3=Theme.InputBg; ibg.BorderSizePixel=0
            ibg.ZIndex=8; ibg.Parent=row; Corner(ibg,UDim.new(0,6))
            local gs=Stroke(ibg,Theme.Accent,1.5,1)

            local input=Instance.new("TextBox"); input.Size=UDim2.new(1,-16,1,0)
            input.Position=UDim2.new(0,8,0,0); input.BackgroundTransparency=1
            input.Text=value>0 and GluttonyUI.FormatNumber(value) or "0"
            input.PlaceholderText="e.g. 5M"; input.PlaceholderColor3=Theme.TextDim
            input.TextColor3=Theme.Text; input.TextSize=Theme.FontSizeSmall
            input.Font=Theme.FontLight; input.ClearTextOnFocus=false
            input.TextXAlignment=Enum.TextXAlignment.Center; input.ZIndex=9; input.Parent=ibg

            ConfigManager:RegisterUpdater(labelText,function(v)
                if type(v)=="number" then
                    value=v; input.Text=v>0 and GluttonyUI.FormatNumber(v) or "0"
                end
            end)
            AddConnection(input.Focused:Connect(function() Tween(gs,{Transparency=0.4},0.2) end))
            AddConnection(input.FocusLost:Connect(function()
                Tween(gs,{Transparency=1},0.2)
                local p=GluttonyUI.ParseNumber(input.Text)
                value=p; ConfigManager:Set(labelText,p)
                input.Text=p>0 and GluttonyUI.FormatNumber(p) or "0"
                if callback then task.spawn(callback,p) end
            end))
            SetupHover(row,RowColor(order),ab)
            return {
                Set=function(_,v)
                    value=v; ConfigManager:Set(labelText,v)
                    input.Text=v>0 and GluttonyUI.FormatNumber(v) or "0"
                end,
                Get=function() return value end
            }
        end

        -- THRESHOLD ROW
        function Tab:AddThresholdRow(labelText,opts)
            opts=opts or {}; local order=NextOrder()
            local threshDefault=opts.Default or 0
            local interval=opts.Interval or 1
            local buttonText=opts.ButtonText or "Sell"
            local onLoop=opts.OnLoop; local onButton=opts.OnButton
            local toggleKey=labelText.."_enabled"
            local threshKey=labelText.."_threshold"

            local savedT=StateStore[toggleKey]
            local toggleState=(savedT~=nil) and savedT or false
            StateStore[toggleKey]=toggleState
            local savedTh=StateStore[threshKey]
            local threshValue=(savedTh~=nil and type(savedTh)=="number") and savedTh or threshDefault
            StateStore[threshKey]=threshValue

            local rowH=RS(56,62)
            local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,rowH)
            row.BackgroundColor3=RowColor(order); row.BorderSizePixel=0
            row.LayoutOrder=order; row.ZIndex=6; row.ClipsDescendants=true
            row.Parent=page; Corner(row,Theme.CornerRadius)
            Stroke(row,Theme.Border,1,0.5)
            local ab=HoverAccent(row)

            local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0,RS(90,80),1,0)
            lbl.Position=UDim2.new(0,18,0,0); lbl.BackgroundTransparency=1
            lbl.Text=labelText; lbl.TextColor3=Theme.Text; lbl.TextSize=Theme.FontSize
            lbl.Font=Theme.Font; lbl.TextXAlignment=Enum.TextXAlignment.Left
            lbl.TextTruncate=Enum.TextTruncate.AtEnd; lbl.ZIndex=7; lbl.Parent=row

            local tbW=RS(42,46); local tbH=RS(22,26)
            local tbg=Instance.new("Frame"); tbg.Size=UDim2.new(0,tbW,0,tbH)
            tbg.Position=UDim2.new(0,RS(110,100),0.5,-tbH/2)
            tbg.BackgroundColor3=toggleState and Theme.ToggleOn or Theme.ToggleOff
            tbg.BorderSizePixel=0; tbg.ZIndex=8; tbg.Parent=row; Corner(tbg,UDim.new(1,0))

            local circSz=RS(18,22)
            local tc=Instance.new("Frame"); tc.Size=UDim2.new(0,circSz,0,circSz)
            tc.Position=toggleState
                and UDim2.new(1,-(circSz+2),0.5,-circSz/2)
                or UDim2.new(0,2,0.5,-circSz/2)
            tc.BackgroundColor3=Theme.Text; tc.BorderSizePixel=0
            tc.ZIndex=9; tc.Parent=tbg; Corner(tc,UDim.new(1,0))
            Stroke(tc,Theme.Shadow,1,0.7)

            local tbtn=Instance.new("TextButton"); tbtn.Size=UDim2.new(1,0,1,0)
            tbtn.BackgroundTransparency=1; tbtn.Text=""; tbtn.ZIndex=10; tbtn.Parent=tbg

            local thW=RS(80,74)
            local thBg=Instance.new("Frame"); thBg.Size=UDim2.new(0,thW,0,RS(30,34))
            thBg.Position=UDim2.new(0,RS(164,156),0.5,-RS(15,17))
            thBg.BackgroundColor3=Theme.InputBg; thBg.BorderSizePixel=0
            thBg.ZIndex=8; thBg.Parent=row; Corner(thBg,UDim.new(0,6))
            local thGlow=Stroke(thBg,Theme.Accent,1.5,1)

            local thInput=Instance.new("TextBox"); thInput.Size=UDim2.new(1,-12,1,0)
            thInput.Position=UDim2.new(0,6,0,0); thInput.BackgroundTransparency=1
            thInput.Text=threshValue>0 and GluttonyUI.FormatNumber(threshValue) or "0"
            thInput.PlaceholderText="e.g. 5M"; thInput.PlaceholderColor3=Theme.TextDim
            thInput.TextColor3=Theme.Text; thInput.TextSize=RS(13,14); thInput.Font=Theme.FontLight
            thInput.ClearTextOnFocus=false; thInput.TextXAlignment=Enum.TextXAlignment.Center
            thInput.ZIndex=9; thInput.Parent=thBg

            AddConnection(thInput.Focused:Connect(function() Tween(thGlow,{Transparency=0.4},0.2) end))
            AddConnection(thInput.FocusLost:Connect(function()
                Tween(thGlow,{Transparency=1},0.2)
                local p=GluttonyUI.ParseNumber(thInput.Text)
                threshValue=p; ConfigManager:Set(threshKey,p)
                thInput.Text=p>0 and GluttonyUI.FormatNumber(p) or "0"
                if toggleState and onLoop then
                    ThreadManager:Start(toggleKey,interval,function() onLoop(threshValue) end)
                end
            end))

            local afW=RS(72,68)
            local af=Instance.new("Frame"); af.Size=UDim2.new(0,afW,0,RS(32,36))
            af.Position=UDim2.new(1,-(afW+RS(14,12)),0.5,-RS(16,18))
            af.BackgroundTransparency=1; af.ZIndex=7; af.Parent=row

            local ash=Instance.new("Frame"); ash.Size=UDim2.new(1,2,1,2)
            ash.Position=UDim2.new(0,-1,0,2); ash.BackgroundColor3=Theme.Shadow
            ash.BackgroundTransparency=0.82; ash.BorderSizePixel=0
            ash.ZIndex=7; ash.Parent=af; Corner(ash,UDim.new(0,6))

            local abtn=Instance.new("TextButton"); abtn.Size=UDim2.new(1,-2,1,-2)
            abtn.Position=UDim2.new(0,1,0,0); abtn.BackgroundColor3=Color3.fromRGB(200,30,30)
            abtn.Text=buttonText; abtn.TextColor3=Theme.Text
            abtn.TextSize=RS(13,14); abtn.Font=Theme.Font
            abtn.BorderSizePixel=0; abtn.AutoButtonColor=false
            abtn.ZIndex=8; abtn.Parent=af; Corner(abtn,UDim.new(0,6))
            Stroke(abtn,Color3.fromRGB(200,30,30),1.5,0.6)

            local abusy=false
            local function SetAS(st,msg)
                if st=="loading" then
                    abtn.Text="..."
                    Tween(abtn,{BackgroundColor3=Color3.fromRGB(100,100,100)},0.15)
                elseif st=="success" then
                    abtn.Text="✅ "..(msg or "")
                    Tween(abtn,{BackgroundColor3=Theme.NotifSuccess},0.2)
                    task.delay(1.5,function()
                        if abtn and abtn.Parent then
                            abtn.Text=buttonText
                            Tween(abtn,{BackgroundColor3=Color3.fromRGB(200,30,30)},0.2)
                            abusy=false
                        end
                    end)
                elseif st=="error" then
                    abtn.Text="❌"
                    Tween(abtn,{BackgroundColor3=Theme.NotifError},0.2)
                    task.delay(1.5,function()
                        if abtn and abtn.Parent then
                            abtn.Text=buttonText
                            Tween(abtn,{BackgroundColor3=Color3.fromRGB(200,30,30)},0.2)
                            abusy=false
                        end
                    end)
                else
                    abtn.Text=buttonText
                    Tween(abtn,{BackgroundColor3=Color3.fromRGB(200,30,30)},0.2)
                    abusy=false
                end
            end

            if not _isMobile then
                AddConnection(abtn.MouseEnter:Connect(function()
                    if not abusy then Tween(abtn,{BackgroundColor3=Color3.fromRGB(220,50,50)},0.15) end
                end))
                AddConnection(abtn.MouseLeave:Connect(function()
                    if not abusy then Tween(abtn,{BackgroundColor3=Color3.fromRGB(200,30,30)},0.15) end
                end))
            end
            AddConnection(abtn.MouseButton1Click:Connect(function()
                if abusy then return end; abusy=true
                Tween(abtn,{Size=UDim2.new(1,-6,1,-4)},0.06)
                task.delay(0.06,function()
                    Tween(abtn,{Size=UDim2.new(1,-2,1,-2)},0.1,Enum.EasingStyle.Back)
                end)
                if onButton then task.spawn(onButton,threshValue,SetAS) end
            end))

            AddConnection(tbtn.MouseButton1Click:Connect(function()
                toggleState=not toggleState
                ConfigManager:Set(toggleKey,toggleState)
                Tween(tbg,{BackgroundColor3=toggleState and Theme.ToggleOn or Theme.ToggleOff},0.25)
                Tween(tc,{Position=toggleState
                    and UDim2.new(1,-(circSz+2),0.5,-circSz/2)
                    or UDim2.new(0,2,0.5,-circSz/2)},0.25,Enum.EasingStyle.Back)
                if toggleState then
                    if threshValue<=0 then
                        toggleState=false; ConfigManager:Set(toggleKey,false)
                        Tween(tbg,{BackgroundColor3=Theme.ToggleOff},0.2)
                        Tween(tc,{Position=UDim2.new(0,2,0.5,-circSz/2)},0.2)
                        return
                    end
                    if onLoop then
                        ThreadManager:Start(toggleKey,interval,function() onLoop(threshValue) end)
                    end
                else ThreadManager:Stop(toggleKey) end
            end))
            SetupHover(row,RowColor(order),ab)
            if toggleState and threshValue>0 and onLoop then
                task.defer(function()
                    ThreadManager:Start(toggleKey,interval,function() onLoop(threshValue) end)
                end)
            end
            return {
                GetThreshold=function() return threshValue end,
                GetToggle=function() return toggleState end,
                SetThreshold=function(_,v)
                    threshValue=v; ConfigManager:Set(threshKey,v)
                    thInput.Text=v>0 and GluttonyUI.FormatNumber(v) or "0"
                end
            }
        end

        -- DROPDOWN
        function Tab:AddDropdown(labelText,options,callback)
            local order=NextOrder(); local isOpen=false
            local saved=StateStore[labelText]; local selected=nil
            if saved~=nil and type(saved)=="string" then
                for _,o in ipairs(options) do if o==saved then selected=saved; break end end
            end
            StateStore[labelText]=selected

            local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,RH)
            row.BackgroundColor3=RowColor(order); row.BorderSizePixel=0
            row.LayoutOrder=order; row.ZIndex=10; row.ClipsDescendants=false
            row.Parent=page; Corner(row,Theme.CornerRadius)
            local ab=HoverAccent(row)

            local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0,RS(140,110),1,0)
            lbl.Position=UDim2.new(0,18,0,0); lbl.BackgroundTransparency=1
            lbl.Text=labelText; lbl.TextColor3=Theme.Text; lbl.TextSize=Theme.FontSize
            lbl.Font=Theme.FontLight; lbl.TextXAlignment=Enum.TextXAlignment.Left
            lbl.ZIndex=11; lbl.Parent=row

            local ddW=RS(180,160)
            local ddBtn=Instance.new("Frame"); ddBtn.Size=UDim2.new(0,ddW,0,RS(30,34))
            ddBtn.Position=UDim2.new(1,-(ddW+RS(16,12)),0.5,-RS(15,17))
            ddBtn.BackgroundColor3=Theme.InputBg; ddBtn.BorderSizePixel=0
            ddBtn.ZIndex=12; ddBtn.Parent=row
            Corner(ddBtn,UDim.new(0,6)); Stroke(ddBtn,Theme.Border,1,0.5)

            local ddLabel=Instance.new("TextLabel"); ddLabel.Size=UDim2.new(1,-32,1,0)
            ddLabel.Position=UDim2.new(0,10,0,0); ddLabel.BackgroundTransparency=1
            ddLabel.Text=selected or "Select..."
            ddLabel.TextColor3=selected and Theme.Text or Theme.TextDim
            ddLabel.TextSize=Theme.FontSizeSmall; ddLabel.Font=Theme.FontLight
            ddLabel.TextXAlignment=Enum.TextXAlignment.Left
            ddLabel.TextTruncate=Enum.TextTruncate.AtEnd
            ddLabel.ZIndex=13; ddLabel.Parent=ddBtn

            local af=Instance.new("Frame"); af.Size=UDim2.new(0,12,0,12)
            af.Position=UDim2.new(1,-22,0.5,-6); af.BackgroundTransparency=1
            af.ZIndex=13; af.Parent=ddBtn
            local al=Instance.new("Frame"); al.Size=UDim2.new(0,7,0,2)
            al.Position=UDim2.new(0,0,0.5,-1); al.AnchorPoint=Vector2.new(0,0.5)
            al.BackgroundColor3=Theme.Accent; al.Rotation=35; al.BorderSizePixel=0
            al.Parent=af; Corner(al,UDim.new(1,0))
            local ar=Instance.new("Frame"); ar.Size=UDim2.new(0,7,0,2)
            ar.Position=UDim2.new(1,0,0.5,-1); ar.AnchorPoint=Vector2.new(1,0.5)
            ar.BackgroundColor3=Theme.Accent; ar.Rotation=-35; ar.BorderSizePixel=0
            ar.Parent=af; Corner(ar,UDim.new(1,0))

            local ddClick=Instance.new("TextButton"); ddClick.Size=UDim2.new(1,0,1,0)
            ddClick.BackgroundTransparency=1; ddClick.Text=""
            ddClick.ZIndex=14; ddClick.Parent=ddBtn

            local maxPanelH=_isMobile and 140 or 160
            local panel=Instance.new("ScrollingFrame")
            panel.Size=UDim2.new(0,0,0,0)
            panel.BackgroundColor3=Theme.DropdownBg; panel.BorderSizePixel=0
            panel.ClipsDescendants=true; panel.ScrollBarThickness=3
            panel.ScrollBarImageColor3=Theme.Accent; panel.ZIndex=500
            panel.Visible=false; panel.Parent=inner
            Corner(panel,UDim.new(0,6)); Stroke(panel,Theme.Accent,1,0.6)

            local pl=ListLayout(panel,2); Padding(panel,4,4,4,4)
            local trackConn=nil; local flippedUp=false; local currentTH=0

            local function GetPP(th)
                local da=ddBtn.AbsolutePosition; local ds=ddBtn.AbsoluteSize
                local ia=inner.AbsolutePosition; local is=inner.AbsoluteSize
                local rx=da.X-ia.X
                local ryB=da.Y-ia.Y+ds.Y+4
                local ryA=da.Y-ia.Y-th-4
                if ryB+th>is.Y and ryA>=0 then
                    flippedUp=true; return UDim2.new(0,rx,0,ryA)
                else flippedUp=false; return UDim2.new(0,rx,0,ryB) end
            end
            local function GPS(th) return UDim2.new(0,ddBtn.AbsoluteSize.X,0,th) end
            local function STP(th)
                if trackConn then return end
                trackConn=RunService.Heartbeat:Connect(function()
                    if isOpen and panel.Visible then panel.Position=GetPP(th) end
                end)
            end
            local function StTP()
                if trackConn then trackConn:Disconnect(); trackConn=nil end
            end

            ConfigManager:RegisterUpdater(labelText,function(v)
                if type(v)=="string" then
                    selected=v; ddLabel.Text=v; ddLabel.TextColor3=Theme.Text
                end
            end)

            local function BO()
                for _,ch in pairs(panel:GetChildren()) do
                    if ch:IsA("TextButton") then ch:Destroy() end
                end
                for i,opt in ipairs(options) do
                    local ob=Instance.new("TextButton")
                    ob.Size=UDim2.new(1,0,0,RS(30,34))
                    ob.BackgroundColor3=(selected==opt)
                        and Color3.fromRGB(40,50,65) or Theme.DropdownBg
                    ob.Text=opt
                    ob.TextColor3=(selected==opt) and Theme.Accent or Theme.Text
                    ob.TextSize=RS(13,14); ob.Font=Theme.FontLight
                    ob.BorderSizePixel=0; ob.AutoButtonColor=false
                    ob.LayoutOrder=i; ob.ZIndex=501; ob.Parent=panel
                    Corner(ob,UDim.new(0,5))
                    if not _isMobile then
                        AddConnection(ob.MouseEnter:Connect(function()
                            if selected~=opt then
                                Tween(ob,{BackgroundColor3=Theme.DropdownHover},0.1)
                            end
                        end))
                        AddConnection(ob.MouseLeave:Connect(function()
                            if selected~=opt then
                                Tween(ob,{BackgroundColor3=Theme.DropdownBg},0.1)
                            end
                        end))
                    end
                    AddConnection(ob.MouseButton1Click:Connect(function()
                        selected=opt; ConfigManager:Set(labelText,opt)
                        ddLabel.Text=opt; ddLabel.TextColor3=Theme.Text
                        isOpen=false; activeDropdownPanel=nil; StTP()
                        Tween(panel,{Size=GPS(0)},0.2); Tween(af,{Rotation=0},0.2)
                        task.delay(0.2,function() panel.Visible=false end)
                        if callback then task.spawn(callback,opt) end
                    end))
                end
                panel.CanvasSize=UDim2.new(0,0,0,pl.AbsoluteContentSize.Y+10)
                currentTH=math.min(#options*RS(32,36)+10, maxPanelH)
                return currentTH
            end

            AddConnection(ddClick.MouseButton1Click:Connect(function()
                isOpen=not isOpen
                if isOpen then
                    if activeDropdownPanel and activeDropdownPanel~=panel then
                        activeDropdownPanel.Visible=false
                        activeDropdownPanel.Size=UDim2.new(0,0,0,0)
                    end
                    activeDropdownPanel=panel; local th=BO()
                    panel.Position=GetPP(th); panel.Size=GPS(0)
                    panel.Visible=true
                    Tween(panel,{Size=GPS(th)},0.25)
                    Tween(af,{Rotation=flippedUp and 0 or 180},0.25)
                    STP(th)
                else
                    activeDropdownPanel=nil; StTP()
                    Tween(panel,{Size=GPS(0)},0.2); Tween(af,{Rotation=0},0.2)
                    task.delay(0.2,function() panel.Visible=false end)
                end
            end))
            SetupHover(row,RowColor(order),ab)
            if selected and callback then task.defer(callback,selected) end
            return {
                Set=function(_,v)
                    selected=v; ConfigManager:Set(labelText,v)
                    ddLabel.Text=v or "Select..."
                    ddLabel.TextColor3=v and Theme.Text or Theme.TextDim
                end,
                Get=function() return selected end,
                Refresh=function(_,no) options=no; if isOpen then BO() end end
            }
        end

        -- RADIO SELECT
        function Tab:AddRadioSelect(labelText,radioOptions,callback)
            local order=NextOrder()
            local saved=StateStore[labelText]
            local selected=saved or (radioOptions[1] and radioOptions[1].Name) or nil
            StateStore[labelText]=selected

            local itemH=RS(58,64)
            local ch=#radioOptions*itemH+10
            local container=Instance.new("Frame"); container.Size=UDim2.new(1,0,0,ch)
            container.BackgroundColor3=Color3.fromRGB(24,24,32); container.BorderSizePixel=0
            container.LayoutOrder=order; container.ZIndex=6; container.Parent=page
            Corner(container,Theme.CornerRadius); Stroke(container,Theme.Border,1,0.3)

            local rf={}
            for i,opt in ipairs(radioOptions) do
                local oc=opt.Color or Theme.Accent
                local of=Instance.new("Frame"); of.Size=UDim2.new(1,-16,0,RS(50,56))
                of.Position=UDim2.new(0,8,0,8+(i-1)*itemH)
                of.BackgroundColor3=(selected==opt.Name) and Color3.fromRGB(35,50,40) or Theme.Row
                of.BorderSizePixel=0; of.ZIndex=7; of.Parent=container; Corner(of,UDim.new(0,8))

                local os=Stroke(of,oc,1.5,(selected==opt.Name) and 0.3 or 1)
                local radio=Instance.new("Frame"); radio.Size=UDim2.new(0,RS(22,26),0,RS(22,26))
                radio.Position=UDim2.new(0,14,0.5,-RS(11,13))
                radio.BackgroundColor3=(selected==opt.Name) and oc or Theme.ToggleOff
                radio.BorderSizePixel=0; radio.ZIndex=8; radio.Parent=of; Corner(radio,UDim.new(1,0))

                local ri=Instance.new("Frame"); ri.Size=UDim2.new(0,8,0,8)
                ri.Position=UDim2.new(0.5,-4,0.5,-4)
                ri.BackgroundColor3=Color3.fromRGB(255,255,255)
                ri.BackgroundTransparency=(selected==opt.Name) and 0 or 1
                ri.BorderSizePixel=0; ri.ZIndex=9; ri.Parent=radio; Corner(ri,UDim.new(1,0))

                local ot=Instance.new("TextLabel"); ot.Size=UDim2.new(1,-48,0,22)
                ot.Position=UDim2.new(0,44,0,6); ot.BackgroundTransparency=1
                ot.Text=opt.Name; ot.TextColor3=oc; ot.TextSize=RS(14,15)
                ot.Font=Theme.Font; ot.TextXAlignment=Enum.TextXAlignment.Left
                ot.ZIndex=9; ot.Parent=of

                local od=Instance.new("TextLabel"); od.Size=UDim2.new(1,-48,0,RS(16,18))
                od.Position=UDim2.new(0,44,0,RS(28,30)); od.BackgroundTransparency=1
                od.Text=opt.Desc or ""; od.TextColor3=Theme.TextDim; od.TextSize=RS(11,12)
                od.Font=Theme.FontLight; od.TextXAlignment=Enum.TextXAlignment.Left
                od.ZIndex=9; od.Parent=of

                local ob=Instance.new("TextButton"); ob.Size=UDim2.new(1,0,1,0)
                ob.BackgroundTransparency=1; ob.Text=""; ob.ZIndex=10; ob.Parent=of

                rf[opt.Name]={Frame=of,Stroke=os,Radio=radio,RadioInner=ri,Color=oc}

                AddConnection(ob.MouseButton1Click:Connect(function()
                    selected=opt.Name; ConfigManager:Set(labelText,opt.Name)
                    for on,r in pairs(rf) do
                        if on==opt.Name then
                            Tween(r.Frame,{BackgroundColor3=Color3.fromRGB(35,50,40)},0.25)
                            Tween(r.Radio,{BackgroundColor3=r.Color},0.25)
                            Tween(r.RadioInner,{BackgroundTransparency=0},0.2)
                            Tween(r.Stroke,{Transparency=0.3},0.25)
                        else
                            Tween(r.Frame,{BackgroundColor3=Theme.Row},0.25)
                            Tween(r.Radio,{BackgroundColor3=Theme.ToggleOff},0.25)
                            Tween(r.RadioInner,{BackgroundTransparency=1},0.2)
                            Tween(r.Stroke,{Transparency=1},0.25)
                        end
                    end
                    if callback then task.spawn(callback,opt.Name) end
                end))
                if not _isMobile then
                    AddConnection(ob.MouseEnter:Connect(function()
                        if selected~=opt.Name then Tween(of,{BackgroundColor3=Theme.Hover},0.15) end
                    end))
                    AddConnection(ob.MouseLeave:Connect(function()
                        if selected~=opt.Name then Tween(of,{BackgroundColor3=Theme.Row},0.15) end
                    end))
                end
            end

            ConfigManager:RegisterUpdater(labelText,function(v)
                if type(v)=="string" and rf[v] then
                    selected=v
                    for on,r in pairs(rf) do local s=on==v
                        r.Frame.BackgroundColor3=s and Color3.fromRGB(35,50,40) or Theme.Row
                        r.Radio.BackgroundColor3=s and r.Color or Theme.ToggleOff
                        r.RadioInner.BackgroundTransparency=s and 0 or 1
                        r.Stroke.Transparency=s and 0.3 or 1
                    end
                end
            end)
            if selected and callback then task.defer(callback,selected) end
            return {
                Set=function(_,v) selected=v; ConfigManager:Set(labelText,v) end,
                Get=function() return selected end
            }
        end

        -- PRIORITY LIST
        function Tab:AddPriorityList(labelText,items,callback)
            local order=NextOrder()
            local saved=StateStore[labelText]
            local list=(saved and type(saved)=="table") and saved or items
            StateStore[labelText]=list

            local sl=Instance.new("TextLabel"); sl.Size=UDim2.new(1,0,0,24)
            sl.BackgroundTransparency=1; sl.Text=labelText; sl.TextColor3=Theme.Accent
            sl.TextSize=RS(15,16); sl.Font=Theme.Font
            sl.TextXAlignment=Enum.TextXAlignment.Left; sl.LayoutOrder=order
            sl.ZIndex=7; sl.Parent=page

            local co=NextOrder()
            local itemRowH=RS(40,46)
            local cf=Instance.new("Frame"); cf.Size=UDim2.new(1,0,0,#list*itemRowH+16)
            cf.BackgroundColor3=Color3.fromRGB(24,24,32); cf.BorderSizePixel=0
            cf.LayoutOrder=co; cf.ZIndex=6; cf.ClipsDescendants=true; cf.Parent=page
            Corner(cf,Theme.CornerRadius); Stroke(cf,Theme.Border,1,0.3)

            local ll=Instance.new("UIListLayout"); ll.FillDirection=Enum.FillDirection.Vertical
            ll.SortOrder=Enum.SortOrder.LayoutOrder; ll.Padding=UDim.new(0,4); ll.Parent=cf
            Padding(cf,8,8,8,8)

            local re={}
            local function RR()
                for _,r in ipairs(re) do if r and r.Parent then r:Destroy() end end; re={}
                for rank,item in ipairs(list) do
                    local mr=Instance.new("Frame"); mr.Size=UDim2.new(1,0,0,itemRowH-4)
                    mr.BackgroundColor3=(rank%2==0) and Theme.Row or Theme.RowAlt
                    mr.BorderSizePixel=0; mr.LayoutOrder=rank; mr.ZIndex=8; mr.Parent=cf
                    Corner(mr,UDim.new(0,6)); table.insert(re,mr)

                    local rb=Instance.new("Frame"); rb.Size=UDim2.new(0,RS(22,26),0,RS(22,26))
                    rb.Position=UDim2.new(0,10,0.5,-RS(11,13))
                    rb.BackgroundColor3=Theme.Accent; rb.BackgroundTransparency=0.8
                    rb.BorderSizePixel=0; rb.ZIndex=9; rb.Parent=mr; Corner(rb,UDim.new(0,5))
                    local rl=Instance.new("TextLabel"); rl.Size=UDim2.new(1,0,1,0)
                    rl.BackgroundTransparency=1; rl.Text=tostring(rank)
                    rl.TextColor3=Theme.Accent; rl.TextSize=RS(13,14); rl.Font=Theme.Font
                    rl.ZIndex=10; rl.Parent=rb

                    local il=Instance.new("TextLabel"); il.Size=UDim2.new(1,-RS(120,130),1,0)
                    il.Position=UDim2.new(0,42,0,0); il.BackgroundTransparency=1
                    il.Text=tostring(item); il.TextColor3=Theme.Text; il.TextSize=Theme.FontSize
                    il.Font=Theme.FontLight; il.TextXAlignment=Enum.TextXAlignment.Left
                    il.TextTruncate=Enum.TextTruncate.AtEnd; il.ZIndex=9; il.Parent=mr

                    local btnSzR=RS(28,34)
                    local ub=Instance.new("TextButton"); ub.Size=UDim2.new(0,btnSzR,0,btnSzR-2)
                    ub.Position=UDim2.new(1,-RS(64,72),0.5,-(btnSzR-2)/2)
                    ub.BackgroundColor3=Theme.SliderBg; ub.Text="▲"
                    ub.TextColor3=Theme.Text; ub.TextSize=RS(12,14)
                    ub.Font=Theme.Font; ub.BorderSizePixel=0; ub.AutoButtonColor=false
                    ub.ZIndex=10; ub.Parent=mr; Corner(ub,UDim.new(0,5))

                    local db=Instance.new("TextButton"); db.Size=UDim2.new(0,btnSzR,0,btnSzR-2)
                    db.Position=UDim2.new(1,-RS(32,36),0.5,-(btnSzR-2)/2)
                    db.BackgroundColor3=Theme.SliderBg; db.Text="▼"
                    db.TextColor3=Theme.Text; db.TextSize=RS(12,14)
                    db.Font=Theme.Font; db.BorderSizePixel=0; db.AutoButtonColor=false
                    db.ZIndex=10; db.Parent=mr; Corner(db,UDim.new(0,5))

                    AddConnection(ub.MouseButton1Click:Connect(function()
                        if rank<=1 then return end
                        list[rank],list[rank-1]=list[rank-1],list[rank]
                        ConfigManager:Set(labelText,list); RR()
                        if callback then task.spawn(callback,list) end
                    end))
                    AddConnection(db.MouseButton1Click:Connect(function()
                        if rank>=#list then return end
                        list[rank],list[rank+1]=list[rank+1],list[rank]
                        ConfigManager:Set(labelText,list); RR()
                        if callback then task.spawn(callback,list) end
                    end))
                    if not _isMobile then
                        AddConnection(ub.MouseEnter:Connect(function()
                            Tween(ub,{BackgroundColor3=Theme.Hover},0.1)
                        end))
                        AddConnection(ub.MouseLeave:Connect(function()
                            Tween(ub,{BackgroundColor3=Theme.SliderBg},0.1)
                        end))
                        AddConnection(db.MouseEnter:Connect(function()
                            Tween(db,{BackgroundColor3=Theme.Hover},0.1)
                        end))
                        AddConnection(db.MouseLeave:Connect(function()
                            Tween(db,{BackgroundColor3=Theme.SliderBg},0.1)
                        end))
                    end
                end
                cf.Size=UDim2.new(1,0,0,#list*itemRowH+16)
            end
            RR()
            return {
                Get=function() return list end,
                Set=function(_,nl)
                    list=nl; ConfigManager:Set(labelText,list); RR()
                end
            }
        end

        -- MULTI SELECT
        function Tab:AddMultiSelect(labelText,items,optsOrCallback,callbackOrNil)
            local opts,callback
            if type(optsOrCallback)=="function" then
                callback=optsOrCallback; opts={}
            else opts=optsOrCallback or {}; callback=callbackOrNil end

            local order=NextOrder()
            local configKey="_multiselect_"..labelText
            local saved=StateStore[configKey]
            local selected=(saved and type(saved)=="table") and saved or {}
            StateStore[configKey]=selected

            local sortConfigKey="_multisort_"..labelText
            local savedSort=StateStore[sortConfigKey]
            local currentSort=savedSort or opts.DefaultSort or "selected"
            StateStore[sortConfigKey]=currentSort

            local columns=opts.Columns or {}
            local rowDropdown=opts.RowDropdown or nil
            local normalizedItems={}
            for i,item in ipairs(items) do
                normalizedItems[i]=(type(item)=="string") and {Name=item} or item
            end

            local sl=Instance.new("TextLabel"); sl.Size=UDim2.new(1,0,0,24)
            sl.BackgroundTransparency=1; sl.Text=labelText; sl.TextColor3=Theme.Accent
            sl.TextSize=RS(15,16); sl.Font=Theme.Font
            sl.TextXAlignment=Enum.TextXAlignment.Left; sl.LayoutOrder=order
            sl.ZIndex=7; sl.Parent=page

            local co=NextOrder()
            local msH=RS(280,320)
            local cf=Instance.new("Frame"); cf.Size=UDim2.new(1,0,0,msH)
            cf.BackgroundColor3=Color3.fromRGB(24,24,32); cf.BorderSizePixel=0
            cf.LayoutOrder=co; cf.ZIndex=6; cf.Parent=page
            Corner(cf,Theme.CornerRadius); Stroke(cf,Theme.Border,1,0.3)

            local headerH=RS(46,52)
            local header=Instance.new("Frame"); header.Size=UDim2.new(1,0,0,headerH)
            header.BackgroundColor3=Theme.Sidebar; header.BorderSizePixel=0
            header.ZIndex=7; header.Parent=cf; Corner(header,Theme.CornerRadius)
            local hf=Instance.new("Frame"); hf.Size=UDim2.new(1,0,0,14)
            hf.Position=UDim2.new(0,0,1,-14); hf.BackgroundColor3=Theme.Sidebar
            hf.BorderSizePixel=0; hf.ZIndex=7; hf.Parent=header

            local countLabel=Instance.new("TextLabel"); countLabel.Size=UDim2.new(0,80,1,0)
            countLabel.Position=UDim2.new(0,14,0,0); countLabel.BackgroundTransparency=1
            countLabel.TextColor3=Theme.TextDim; countLabel.TextSize=RS(13,14)
            countLabel.Font=Theme.FontLight; countLabel.TextXAlignment=Enum.TextXAlignment.Left
            countLabel.ZIndex=8; countLabel.Parent=header

            local function UC()
                local c=0; for _ in pairs(selected) do c=c+1 end
                countLabel.Text=c.." selected"
            end; UC()

            local sortOptions={"selected","alpha"}
            for _,col in ipairs(columns) do table.insert(sortOptions,col.Name) end

            local sortBtn=Instance.new("TextButton"); sortBtn.Size=UDim2.new(0,RS(80,72),0,RS(26,30))
            sortBtn.Position=UDim2.new(0,96,0.5,-RS(13,15))
            sortBtn.BackgroundColor3=Theme.InputBg; sortBtn.Text="⇅ "..currentSort
            sortBtn.TextColor3=Theme.Accent; sortBtn.TextSize=RS(11,12)
            sortBtn.Font=Theme.Font; sortBtn.BorderSizePixel=0; sortBtn.AutoButtonColor=false
            sortBtn.ZIndex=8; sortBtn.Parent=header; Corner(sortBtn,UDim.new(0,5))

            local sbW=RS(150,130)
            local sbg=Instance.new("Frame"); sbg.Size=UDim2.new(0,sbW,0,RS(30,34))
            sbg.Position=UDim2.new(1,-(sbW+RS(14,12)),0.5,-RS(15,17))
            sbg.BackgroundColor3=Theme.InputBg; sbg.BorderSizePixel=0
            sbg.ZIndex=8; sbg.Parent=header; Corner(sbg,UDim.new(0,6))
            local sgl=Stroke(sbg,Theme.Accent,1.5,1)

            local si=Instance.new("TextBox"); si.Size=UDim2.new(1,-16,1,0)
            si.Position=UDim2.new(0,8,0,0); si.BackgroundTransparency=1
            si.Text=""; si.PlaceholderText="Search..."
            si.PlaceholderColor3=Theme.TextDim; si.TextColor3=Theme.Text
            si.TextSize=RS(13,14); si.Font=Theme.FontLight
            si.ClearTextOnFocus=false; si.TextXAlignment=Enum.TextXAlignment.Left
            si.ZIndex=9; si.Parent=sbg

            AddConnection(si.Focused:Connect(function() Tween(sgl,{Transparency=0.4},0.2) end))
            AddConnection(si.FocusLost:Connect(function() Tween(sgl,{Transparency=1},0.2) end))

            local sf=Instance.new("ScrollingFrame")
            sf.Size=UDim2.new(1,-14,1,-headerH-6)
            sf.Position=UDim2.new(0,7,0,headerH+4)
            sf.BackgroundTransparency=1; sf.BorderSizePixel=0
            sf.ScrollBarThickness=RS(4,5); sf.ScrollBarImageColor3=Theme.Accent
            sf.ScrollBarImageTransparency=0.3; sf.CanvasSize=UDim2.new(0,0,0,0)
            sf.ZIndex=7; sf.Parent=cf

            local sfl=Instance.new("UIListLayout"); sfl.FillDirection=Enum.FillDirection.Vertical
            sfl.SortOrder=Enum.SortOrder.LayoutOrder; sfl.Padding=UDim.new(0,4); sfl.Parent=sf
            Padding(sf,4,4,4,4)

            local itemRows={}
            local activeRowDropdown=nil
            local tcSz=RS(18,22)

            local function GSI()
                local indices={}
                for i,item in ipairs(normalizedItems) do
                    local rd=itemRows[item.Name]
                    if rd and rd.Frame.Visible then table.insert(indices,i) end
                end
                if currentSort=="selected" then
                    table.sort(indices,function(a,b)
                        local an=normalizedItems[a].Name; local bn=normalizedItems[b].Name
                        local ao=selected[an]==true; local bo=selected[bn]==true
                        if ao~=bo then return ao end; return a<b
                    end)
                elseif currentSort=="alpha" then
                    table.sort(indices,function(a,b)
                        local an=normalizedItems[a].Name; local bn=normalizedItems[b].Name
                        local ao=selected[an]==true; local bo=selected[bn]==true
                        if ao~=bo then return ao end; return an:lower()<bn:lower()
                    end)
                else
                    local cn=currentSort
                    table.sort(indices,function(a,b)
                        local ai=normalizedItems[a]; local bi=normalizedItems[b]
                        local ao=selected[ai.Name]==true; local bo=selected[bi.Name]==true
                        if ao~=bo then return ao end
                        local av=ai[cn] or 0; local bv=bi[cn] or 0
                        if type(av)=="number" and type(bv)=="number" then return av>bv end
                        return tostring(av)<tostring(bv)
                    end)
                end
                return indices
            end

            local function SortList()
                local sorted=GSI()
                for lp,ii in ipairs(sorted) do
                    local in_=normalizedItems[ii].Name; local rd=itemRows[in_]
                    if rd then
                        rd.Frame.LayoutOrder=lp
                        local nc=(lp%2==0) and Theme.Row or Theme.RowAlt
                        rd.Frame.BackgroundColor3=nc; rd.OriginalColor=nc
                    end
                end
            end

            local totalColWidth=0
            for _,col in ipairs(columns) do totalColWidth=totalColWidth+(col.Width or 70)+6 end
            local ddWidth=rowDropdown and (rowDropdown.Width or RS(55,48)) or 0
            local ddGap=rowDropdown and 6 or 0
            local msRowH=RS(38,44)

            for i,item in ipairs(normalizedItems) do
                local in_=item.Name; local isOn=selected[in_]==true

                local ir=Instance.new("Frame"); ir.Name="Item_"..in_
                ir.Size=UDim2.new(1,-8,0,msRowH)
                ir.BackgroundColor3=(i%2==0) and Theme.Row or Theme.RowAlt
                ir.BorderSizePixel=0; ir.LayoutOrder=i; ir.ZIndex=8; ir.Parent=sf
                Corner(ir,UDim.new(0,6))

                local nlw=-(RS(70,60)+totalColWidth+ddWidth+ddGap+14)
                local il2=Instance.new("TextLabel"); il2.Size=UDim2.new(1,nlw,1,0)
                il2.Position=UDim2.new(0,14,0,0); il2.BackgroundTransparency=1
                il2.Text=in_; il2.TextColor3=Theme.Text; il2.TextSize=RS(13,14)
                il2.Font=Theme.FontLight; il2.TextXAlignment=Enum.TextXAlignment.Left
                il2.TextTruncate=Enum.TextTruncate.AtEnd; il2.ZIndex=9; il2.Parent=ir

                for ci,col in ipairs(columns) do
                    local cw=col.Width or 70; local pw=0
                    for pi=1,ci-1 do pw=pw+(columns[pi].Width or 70)+6 end
                    local xOff=RS(52,46)+totalColWidth-pw+ddWidth+ddGap
                    local cb=Instance.new("Frame"); cb.Size=UDim2.new(0,cw,0,22)
                    cb.Position=UDim2.new(1,-xOff,0.5,-11)
                    cb.BackgroundColor3=col.Color or Theme.Accent
                    cb.BackgroundTransparency=0.85; cb.BorderSizePixel=0
                    cb.ZIndex=9; cb.Parent=ir; Corner(cb,UDim.new(0,5))
                    local cv=Instance.new("TextLabel"); cv.Size=UDim2.new(1,0,1,0)
                    cv.BackgroundTransparency=1; cv.ZIndex=10; cv.Parent=cb
                    if col.Format then cv.Text=col.Format(item)
                    elseif item[col.Name] then
                        local v=item[col.Name]
                        cv.Text=(type(v)=="number") and GluttonyUI.FormatNumber(v) or tostring(v)
                    else cv.Text="-" end
                    cv.TextColor3=col.Color or Theme.Accent
                    cv.TextSize=RS(11,12); cv.Font=Theme.Font
                end

                local ddBtnLabel2=nil
                if rowDropdown then
                    local ddOpts=rowDropdown.Options or {}
                    local ddDefault=rowDropdown.Default or "NONE"
                    local ddGetVal=rowDropdown.GetValue or function() return ddDefault end
                    local ddSetVal=rowDropdown.SetValue or function() end
                    local currentVal=ddGetVal(in_) or ddDefault

                    local ddFrame=Instance.new("Frame")
                    ddFrame.Size=UDim2.new(0,ddWidth,0,RS(24,28))
                    ddFrame.Position=UDim2.new(1,-(RS(58,54)+ddWidth),0.5,-RS(12,14))
                    ddFrame.BackgroundColor3=Theme.InputBg; ddFrame.BorderSizePixel=0
                    ddFrame.ZIndex=10; ddFrame.Parent=ir; Corner(ddFrame,UDim.new(0,5))
                    Stroke(ddFrame,Theme.Border,1,0.5)

                    ddBtnLabel2=Instance.new("TextLabel")
                    ddBtnLabel2.Size=UDim2.new(1,-18,1,0)
                    ddBtnLabel2.Position=UDim2.new(0,4,0,0); ddBtnLabel2.BackgroundTransparency=1
                    ddBtnLabel2.Text=currentVal; ddBtnLabel2.TextColor3=Theme.Accent
                    ddBtnLabel2.TextSize=RS(10,11); ddBtnLabel2.Font=Theme.Font
                    ddBtnLabel2.TextXAlignment=Enum.TextXAlignment.Left
                    ddBtnLabel2.TextTruncate=Enum.TextTruncate.AtEnd
                    ddBtnLabel2.ZIndex=11; ddBtnLabel2.Parent=ddFrame

                    local ddArrow=Instance.new("TextLabel")
                    ddArrow.Size=UDim2.new(0,12,0,24); ddArrow.Position=UDim2.new(1,-14,0,0)
                    ddArrow.BackgroundTransparency=1; ddArrow.Text="›"; ddArrow.Rotation=90
                    ddArrow.TextColor3=Theme.TextDim; ddArrow.TextSize=14; ddArrow.Font=Theme.Font
                    ddArrow.ZIndex=11; ddArrow.Parent=ddFrame

                    local ddClickBtn=Instance.new("TextButton")
                    ddClickBtn.Size=UDim2.new(1,0,1,0); ddClickBtn.BackgroundTransparency=1
                    ddClickBtn.Text=""; ddClickBtn.ZIndex=13; ddClickBtn.Parent=ddFrame

                    local ddPanelWidth=math.max(ddWidth+30,RS(90,80))
                    local ddPanel=Instance.new("ScrollingFrame")
                    ddPanel.Size=UDim2.new(0,ddPanelWidth,0,0)
                    ddPanel.BackgroundColor3=Theme.DropdownBg; ddPanel.BorderSizePixel=0
                    ddPanel.ClipsDescendants=true; ddPanel.ScrollBarThickness=3
                    ddPanel.ScrollBarImageColor3=Theme.Accent
                    ddPanel.ScrollBarImageTransparency=0.3; ddPanel.Visible=false
                    ddPanel.ZIndex=500; ddPanel.Parent=inner
                    Corner(ddPanel,UDim.new(0,6)); Stroke(ddPanel,Theme.Accent,1,0.6)

                    local ddPanelLayout=Instance.new("UIListLayout")
                    ddPanelLayout.FillDirection=Enum.FillDirection.Vertical
                    ddPanelLayout.SortOrder=Enum.SortOrder.LayoutOrder
                    ddPanelLayout.Padding=UDim.new(0,2); ddPanelLayout.Parent=ddPanel
                    Padding(ddPanel,4,4,4,4)

                    local ddIsOpen=false; local ddFlipped=false
                    local ddTrackConn=nil; local ddTargetH=0

                    local function GetDDPosition(targetH)
                        local ddAbsPos=ddFrame.AbsolutePosition
                        local ddAbsSize=ddFrame.AbsoluteSize
                        local innerAbsPos=inner.AbsolutePosition
                        local innerAbsSize=inner.AbsoluteSize
                        local relX=ddAbsPos.X-innerAbsPos.X
                        local relYBelow=ddAbsPos.Y-innerAbsPos.Y+ddAbsSize.Y+4
                        local relYAbove=ddAbsPos.Y-innerAbsPos.Y-targetH-4
                        if relYBelow+targetH>innerAbsSize.Y and relYAbove>=0 then
                            ddFlipped=true; return UDim2.new(0,relX,0,relYAbove)
                        else ddFlipped=false; return UDim2.new(0,relX,0,relYBelow) end
                    end

                    local function StartDDTracking(targetH)
                        if ddTrackConn then return end
                        ddTrackConn=RunService.Heartbeat:Connect(function()
                            if ddIsOpen and ddPanel.Visible then
                                local rowAbsPos=ir.AbsolutePosition
                                local sfAbsPos=sf.AbsolutePosition
                                local sfAbsSize=sf.AbsoluteSize
                                local rowTop=rowAbsPos.Y
                                local rowBot=rowAbsPos.Y+ir.AbsoluteSize.Y
                                local sfTop=sfAbsPos.Y
                                local sfBot=sfAbsPos.Y+sfAbsSize.Y
                                if rowBot<sfTop or rowTop>sfBot then
                                    ddIsOpen=false
                                    if ddTrackConn then ddTrackConn:Disconnect(); ddTrackConn=nil end
                                    ddPanel.Visible=false
                                    ddPanel.Size=UDim2.new(0,ddPanelWidth,0,0)
                                    Tween(ddArrow,{Rotation=90,TextColor3=Theme.TextDim},0.15)
                                    if activeRowDropdown==ddPanel then activeRowDropdown=nil end
                                    return
                                end
                                ddPanel.Position=GetDDPosition(targetH)
                            end
                        end)
                    end

                    local function StopDDTracking()
                        if ddTrackConn then ddTrackConn:Disconnect(); ddTrackConn=nil end
                    end

                    local function closeDD()
                        if not ddIsOpen then return end; ddIsOpen=false
                        StopDDTracking()
                        Tween(ddPanel,{Size=UDim2.new(0,ddPanelWidth,0,0)},0.2)
                        Tween(ddArrow,{Rotation=90,TextColor3=Theme.TextDim},0.2)
                        task.delay(0.2,function()
                            if not ddIsOpen then ddPanel.Visible=false end
                        end)
                        if activeRowDropdown==ddPanel then activeRowDropdown=nil end
                    end

                    local function openDD()
                        if activeRowDropdown and activeRowDropdown~=ddPanel then
                            activeRowDropdown.Visible=false
                            activeRowDropdown.Size=UDim2.new(0,ddPanelWidth,0,0)
                            activeRowDropdown=nil
                        end
                        if activeDropdownPanel and activeDropdownPanel.Parent then
                            activeDropdownPanel.Visible=false
                            activeDropdownPanel.Size=UDim2.new(0,0,0,0)
                            activeDropdownPanel=nil
                        end
                        activeRowDropdown=ddPanel; ddIsOpen=true

                        for _,ch in pairs(ddPanel:GetChildren()) do
                            if ch:IsA("TextButton") then ch:Destroy() end
                        end

                        for oi,optName in ipairs(ddOpts) do
                            local optBtn=Instance.new("TextButton")
                            optBtn.Size=UDim2.new(1,0,0,RS(26,30))
                            optBtn.BackgroundColor3=(currentVal==optName)
                                and Color3.fromRGB(40,50,65) or Theme.DropdownBg
                            optBtn.Text=optName
                            optBtn.TextColor3=(currentVal==optName) and Theme.Accent or Theme.Text
                            optBtn.TextSize=RS(11,12); optBtn.Font=Theme.FontLight
                            optBtn.BorderSizePixel=0; optBtn.AutoButtonColor=false
                            optBtn.LayoutOrder=oi; optBtn.ZIndex=501; optBtn.Parent=ddPanel
                            Corner(optBtn,UDim.new(0,4))

                            if not _isMobile then
                                AddConnection(optBtn.MouseEnter:Connect(function()
                                    if currentVal~=optName then
                                        Tween(optBtn,{BackgroundColor3=Theme.DropdownHover},0.1)
                                    end
                                end))
                                AddConnection(optBtn.MouseLeave:Connect(function()
                                    if currentVal~=optName then
                                        Tween(optBtn,{BackgroundColor3=Theme.DropdownBg},0.1)
                                    end
                                end))
                            end

                            AddConnection(optBtn.MouseButton1Click:Connect(function()
                                currentVal=optName; ddSetVal(in_,optName)
                                ddBtnLabel2.Text=optName
                                for _,ch2 in pairs(ddPanel:GetChildren()) do
                                    if ch2:IsA("TextButton") then
                                        local isSel=(ch2.Text==optName)
                                        Tween(ch2,{
                                            BackgroundColor3=isSel
                                                and Color3.fromRGB(40,50,65) or Theme.DropdownBg,
                                            TextColor3=isSel and Theme.Accent or Theme.Text
                                        },0.15)
                                    end
                                end
                                closeDD()
                            end))
                        end

                        ddTargetH=math.min(#ddOpts*RS(28,32)+10,RS(180,160))
                        ddPanel.CanvasSize=UDim2.new(0,0,0,ddPanelLayout.AbsoluteContentSize.Y+10)
                        ddPanel.Position=GetDDPosition(ddTargetH)
                        ddPanel.Size=UDim2.new(0,ddPanelWidth,0,0)
                        ddPanel.Visible=true
                        Tween(ddPanel,{Size=UDim2.new(0,ddPanelWidth,0,ddTargetH)},0.25,Enum.EasingStyle.Back)
                        Tween(ddArrow,{Rotation=ddFlipped and -90 or 270,TextColor3=Theme.Accent},0.2)
                        StartDDTracking(ddTargetH)
                    end

                    AddConnection(ddClickBtn.MouseButton1Click:Connect(function()
                        if ddIsOpen then closeDD() else openDD() end
                    end))

                    local ddGlow2=Stroke(ddFrame,Theme.Accent,1.5,1)
                    if not _isMobile then
                        AddConnection(ddClickBtn.MouseEnter:Connect(function()
                            Tween(ddFrame,{BackgroundColor3=Theme.Hover},0.1)
                            Tween(ddGlow2,{Transparency=0.4},0.15)
                            Tween(ddArrow,{TextColor3=Theme.Accent},0.1)
                        end))
                        AddConnection(ddClickBtn.MouseLeave:Connect(function()
                            Tween(ddFrame,{BackgroundColor3=Theme.InputBg},0.1)
                            Tween(ddGlow2,{Transparency=1},0.15)
                            if not ddIsOpen then
                                Tween(ddArrow,{TextColor3=Theme.TextDim},0.1)
                            end
                        end))
                    end
                end

                local tbgW=RS(40,44); local tbgH=RS(22,26); local tbgX=RS(-52,-58)
                local tbg=Instance.new("Frame"); tbg.Size=UDim2.new(0,tbgW,0,tbgH)
                tbg.Position=UDim2.new(1,tbgX,0.5,-tbgH/2)
                tbg.BackgroundColor3=isOn and Theme.Accent or Theme.ProtectedOff
                tbg.BorderSizePixel=0; tbg.ZIndex=10; tbg.Parent=ir; Corner(tbg,UDim.new(1,0))

                local tc=Instance.new("Frame"); tc.Size=UDim2.new(0,tcSz,0,tcSz)
                tc.Position=isOn
                    and UDim2.new(1,-(tcSz+2),0.5,-tcSz/2)
                    or UDim2.new(0,2,0.5,-tcSz/2)
                tc.BackgroundColor3=Theme.Text; tc.BorderSizePixel=0
                tc.ZIndex=11; tc.Parent=tbg; Corner(tc,UDim.new(1,0))

                local tb=Instance.new("TextButton"); tb.Size=UDim2.new(1,0,1,0)
                tb.BackgroundTransparency=1; tb.Text=""; tb.ZIndex=12; tb.Parent=tbg

                itemRows[in_]={
                    Frame=ir, ToggleBg=tbg, ToggleCircle=tc,
                    OriginalColor=(i%2==0) and Theme.Row or Theme.RowAlt,
                    DdLabel=ddBtnLabel2
                }

                AddConnection(tb.MouseButton1Click:Connect(function()
                    local no=not(selected[in_]==true)
                    if no then selected[in_]=true else selected[in_]=nil end
                    ConfigManager:Set(configKey,selected)
                    Tween(tbg,{BackgroundColor3=no and Theme.Accent or Theme.ProtectedOff},0.25)
                    Tween(tc,{Position=no
                        and UDim2.new(1,-(tcSz+2),0.5,-tcSz/2)
                        or UDim2.new(0,2,0.5,-tcSz/2)},0.25,Enum.EasingStyle.Back)
                    Tween(tc,{Size=UDim2.new(0,tcSz+2,0,tcSz+2)},0.08)
                    task.delay(0.08,function()
                        Tween(tc,{Size=UDim2.new(0,tcSz,0,tcSz)},0.12)
                    end)
                    UC(); task.delay(0.3,function() SortList() end)
                    if callback then task.spawn(callback,selected) end
                end))

                local ra=HoverAccent(ir)
                if not _isMobile then
                    AddConnection(ir.MouseEnter:Connect(function()
                        Tween(ir,{BackgroundColor3=Theme.Hover},0.15)
                        if ra then Tween(ra,{BackgroundTransparency=0.2},0.15) end
                    end))
                    AddConnection(ir.MouseLeave:Connect(function()
                        Tween(ir,{BackgroundColor3=itemRows[in_].OriginalColor},0.15)
                        if ra then Tween(ra,{BackgroundTransparency=1},0.15) end
                    end))
                end
            end

            AddConnection(sortBtn.MouseButton1Click:Connect(function()
                local ci=1
                for si2,so in ipairs(sortOptions) do
                    if so==currentSort then ci=si2; break end
                end
                ci=(ci%#sortOptions)+1; currentSort=sortOptions[ci]
                ConfigManager:Set(sortConfigKey,currentSort)
                sortBtn.Text="⇅ "..currentSort; SortList()
            end))
            if not _isMobile then
                AddConnection(sortBtn.MouseEnter:Connect(function()
                    Tween(sortBtn,{BackgroundColor3=Theme.Hover},0.15)
                end))
                AddConnection(sortBtn.MouseLeave:Connect(function()
                    Tween(sortBtn,{BackgroundColor3=Theme.InputBg},0.15)
                end))
            end

            AddConnection(si:GetPropertyChangedSignal("Text"):Connect(function()
                local f=si.Text:lower()
                for _,item in ipairs(normalizedItems) do
                    local rd=itemRows[item.Name]
                    if rd then
                        rd.Frame.Visible=(f=="" or item.Name:lower():find(f,1,true))
                    end
                end
                SortList()
            end))

            AddConnection(sfl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                sf.CanvasSize=UDim2.new(0,0,0,sfl.AbsoluteContentSize.Y+16)
            end))
            sf.CanvasSize=UDim2.new(0,0,0,sfl.AbsoluteContentSize.Y+16)

            -- ════════════════════════════════════════════════════════
            -- MOBILE SCROLL PASSTHROUGH FIX
            -- When inner list is at top and user swipes down,
            -- or at bottom and user swipes up, pass scroll to parent page
            -- ════════════════════════════════════════════════════════
            if _isMobile then
                local touchStartY = 0
                local touchStartCanvasY = 0

                AddConnection(sf.InputBegan:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.Touch then return end
                    touchStartY = input.Position.Y
                    touchStartCanvasY = sf.CanvasPosition.Y

                    local maxScroll = math.max(0, sf.CanvasSize.Y.Offset - sf.AbsoluteSize.Y)
                    local atTop    = touchStartCanvasY <= 1
                    local atBottom = touchStartCanvasY >= (maxScroll - 1)

                    -- If already at a boundary, disable inner scroll immediately
                    -- so the parent page can catch the touch from the start
                    if atTop or atBottom then
                        sf.ScrollingEnabled = false
                    else
                        sf.ScrollingEnabled = true
                    end
                end))

                AddConnection(sf.InputChanged:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.Touch then return end

                    local dy = input.Position.Y - touchStartY
                    local maxScroll = math.max(0, sf.CanvasSize.Y.Offset - sf.AbsoluteSize.Y)
                    local atTop    = sf.CanvasPosition.Y <= 1
                    local atBottom = sf.CanvasPosition.Y >= (maxScroll - 1)

                    -- Swiping down (positive dy) while at top → escape to parent
                    -- Swiping up  (negative dy) while at bottom → escape to parent
                    if (atTop and dy > 0) or (atBottom and dy < 0) then
                        sf.ScrollingEnabled = false
                    elseif not atTop and not atBottom then
                        sf.ScrollingEnabled = true
                    end
                end))

                AddConnection(sf.InputEnded:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.Touch then return end
                    -- Re-enable after a short delay so next touch starts fresh
                    task.delay(0.12, function()
                        if sf and sf.Parent then
                            sf.ScrollingEnabled = true
                        end
                    end)
                end))
            end

            task.defer(function() SortList() end)

            return {
                Get=function() return selected end,
                Set=function(_,ns)
                    selected=ns; ConfigManager:Set(configKey,selected)
                    for _,item in ipairs(normalizedItems) do
                        local rd=itemRows[item.Name]
                        if rd then
                            local isOn2=selected[item.Name]==true
                            rd.ToggleBg.BackgroundColor3=isOn2 and Theme.Accent or Theme.ProtectedOff
                            rd.ToggleCircle.Position=isOn2
                                and UDim2.new(1,-(tcSz+2),0.5,-tcSz/2)
                                or UDim2.new(0,2,0.5,-tcSz/2)
                        end
                    end; UC(); SortList()
                end,
                SetSort=function(_,sm)
                    currentSort=sm; ConfigManager:Set(sortConfigKey,currentSort)
                    sortBtn.Text="⇅ "..currentSort; SortList()
                end
            }
        end

        -- SEARCH
        function Tab:AddSearch(placeholder,callback)
            local order=NextOrder()
            local sf2=Instance.new("Frame"); sf2.Size=UDim2.new(1,0,0,RS(40,46))
            sf2.BackgroundColor3=Theme.InputBg; sf2.BorderSizePixel=0
            sf2.LayoutOrder=order; sf2.ZIndex=6; sf2.Parent=page; Corner(sf2,Theme.CornerRadius)
            local gs=Stroke(sf2,Theme.Accent,1.5,1)

            local ifr=Instance.new("Frame"); ifr.Size=UDim2.new(0,16,0,16)
            ifr.Position=UDim2.new(0,14,0.5,-8); ifr.BackgroundTransparency=1
            ifr.ZIndex=8; ifr.Parent=sf2
            local ic=Instance.new("Frame"); ic.Size=UDim2.new(0,11,0,11)
            ic.BackgroundColor3=Theme.TextDim; ic.BackgroundTransparency=0.6
            ic.BorderSizePixel=0; ic.ZIndex=9; ic.Parent=ifr; Corner(ic,UDim.new(1,0))
            local ih=Instance.new("Frame"); ih.Size=UDim2.new(0,6,0,2)
            ih.Position=UDim2.new(0,9,0,11); ih.BackgroundColor3=Theme.TextDim
            ih.BackgroundTransparency=0.4; ih.Rotation=45; ih.BorderSizePixel=0
            ih.ZIndex=9; ih.Parent=ifr; Corner(ih,UDim.new(1,0))

            local sinput=Instance.new("TextBox"); sinput.Size=UDim2.new(1,-50,1,0)
            sinput.Position=UDim2.new(0,38,0,0); sinput.BackgroundTransparency=1
            sinput.Text=""; sinput.PlaceholderText=placeholder or "Search..."
            sinput.PlaceholderColor3=Theme.TextDim; sinput.TextColor3=Theme.Text
            sinput.TextSize=RS(14,15); sinput.Font=Theme.FontLight
            sinput.ClearTextOnFocus=false; sinput.TextXAlignment=Enum.TextXAlignment.Left
            sinput.ZIndex=7; sinput.Parent=sf2

            AddConnection(sinput.Focused:Connect(function() Tween(gs,{Transparency=0.4},0.2) end))
            AddConnection(sinput.FocusLost:Connect(function() Tween(gs,{Transparency=1},0.2) end))
            AddConnection(sinput:GetPropertyChangedSignal("Text"):Connect(function()
                if callback then task.spawn(callback,sinput.Text) end
            end))
            return {
                Get=function() return sinput.Text end,
                Set=function(_,v) sinput.Text=v end,
                Clear=function() sinput.Text="" end
            }
        end

        -- ════════════════════════════════════════════════════════════════
        -- WEBHOOK INPUT (new Tab element)
        -- ════════════════════════════════════════════════════════════════
        function Tab:AddWebhookInput(opts)
            opts = opts or {}
            local order = NextOrder()
            local labelText  = opts.Label       or "Webhook URL"
            local placeholder= opts.Placeholder or "https://discord.com/api/webhooks/..."
            local configKey  = opts.ConfigKey   or "_webhook_url"
            local onSave     = opts.OnSave
            local testTitle  = opts.TestTitle   or "🔗 Webhook Test"
            local testDesc   = opts.TestDescription or "This is a test message from **Gluttony Core**.\nWebhook is working correctly! ✅"
            local testColor  = opts.TestColor   or WebhookSystem._config.Color
            local testFields = opts.TestFields  or {}

            -- Load saved URL
            local savedUrl = StateStore[configKey] or ""
            WebhookSystem:SetURL(savedUrl)

            -- URL Input row
            local urlOrder = order
            local urlRow = Instance.new("Frame")
            urlRow.Size = UDim2.new(1,0,0,RH)
            urlRow.BackgroundColor3 = RowColor(urlOrder)
            urlRow.BorderSizePixel = 0
            urlRow.LayoutOrder = urlOrder
            urlRow.ZIndex = 6; urlRow.ClipsDescendants = true
            urlRow.Parent = page
            Corner(urlRow, Theme.CornerRadius)
            local urlAb = HoverAccent(urlRow)

            local urlLbl = Instance.new("TextLabel")
            urlLbl.Size = UDim2.new(0,RS(90,75),1,0)
            urlLbl.Position = UDim2.new(0,18,0,0)
            urlLbl.BackgroundTransparency = 1
            urlLbl.Text = "🔗 " .. labelText
            urlLbl.TextColor3 = Theme.Text; urlLbl.TextSize = Theme.FontSize
            urlLbl.Font = Theme.FontLight
            urlLbl.TextXAlignment = Enum.TextXAlignment.Left
            urlLbl.ZIndex = 7; urlLbl.Parent = urlRow

            local urlInputW = RS(310,240)
            local urlInputBg = Instance.new("Frame")
            urlInputBg.Size = UDim2.new(0,urlInputW,0,RS(30,34))
            urlInputBg.Position = UDim2.new(1,-(urlInputW+RS(14,12)),0.5,-RS(15,17))
            urlInputBg.BackgroundColor3 = Theme.InputBg
            urlInputBg.BorderSizePixel = 0; urlInputBg.ZIndex = 8; urlInputBg.Parent = urlRow
            urlInputBg.ClipsDescendants = true
            Corner(urlInputBg, UDim.new(0,6))
            local urlGlow = Stroke(urlInputBg, Color3.fromRGB(88,101,242), 1.5, 1)

            local urlInput = Instance.new("TextBox")
            urlInput.Size = UDim2.new(1,-28,1,0)
            urlInput.Position = UDim2.new(0,8,0,0)
            urlInput.BackgroundTransparency = 1
            urlInput.Text = savedUrl
            urlInput.PlaceholderText = placeholder
            urlInput.PlaceholderColor3 = Theme.TextDim
            urlInput.TextColor3 = Theme.Text
            urlInput.TextSize = RS(11,12); urlInput.Font = Theme.FontLight
            urlInput.ClearTextOnFocus = false
            urlInput.TextXAlignment = Enum.TextXAlignment.Left
            urlInput.ClipsDescendants = true
            urlInput.TextTruncate = Enum.TextTruncate.AtEnd
            urlInput.ZIndex = 9; urlInput.Parent = urlInputBg

            local statusDot = Instance.new("Frame")
            statusDot.Size = UDim2.new(0,10,0,10)
            statusDot.Position = UDim2.new(1,-(RS(14,12)+6),0.5,-5)
            statusDot.BackgroundColor3 = savedUrl ~= "" and Theme.NotifSuccess or Theme.ToggleOff
            statusDot.BorderSizePixel = 0; statusDot.ZIndex = 10; statusDot.Parent = urlInputBg
            Corner(statusDot, UDim.new(1,0))

            AddConnection(urlInput.Focused:Connect(function()
                Tween(urlGlow,{Transparency=0.3},0.2)
            end))
            AddConnection(urlInput.FocusLost:Connect(function()
                Tween(urlGlow,{Transparency=1},0.2)
                local url = urlInput.Text
                StateStore[configKey] = url
                ConfigManager:Set(configKey, url)
                WebhookSystem:SetURL(url)
                Tween(statusDot,{
                    BackgroundColor3 = url ~= "" and Theme.NotifSuccess or Theme.ToggleOff
                },0.3)
                if onSave then task.spawn(onSave, url) end
            end))
            SetupHover(urlRow, RowColor(urlOrder), urlAb)

            -- Test button row
            local btnRowOrder = NextOrder()
            local btnRow = Instance.new("Frame")
            btnRow.Size = UDim2.new(1,0,0,RH)
            btnRow.BackgroundColor3 = RowColor(btnRowOrder)
            btnRow.BorderSizePixel = 0
            btnRow.LayoutOrder = btnRowOrder
            btnRow.ZIndex = 6; btnRow.ClipsDescendants = true
            btnRow.Parent = page
            Corner(btnRow, Theme.CornerRadius)
            local btnAb = HoverAccent(btnRow)

            local btnLbl = Instance.new("TextLabel")
            btnLbl.Size = UDim2.new(1,-220,1,0)
            btnLbl.Position = UDim2.new(0,18,0,0)
            btnLbl.BackgroundTransparency = 1
            btnLbl.Text = "Test Webhook"
            btnLbl.TextColor3 = Theme.Text; btnLbl.TextSize = Theme.FontSize
            btnLbl.Font = Theme.FontLight
            btnLbl.TextXAlignment = Enum.TextXAlignment.Left
            btnLbl.ZIndex = 7; btnLbl.Parent = btnRow

            local testBtnW = RS(100,90)
            local testBtnFrame = Instance.new("Frame")
            testBtnFrame.Size = UDim2.new(0,testBtnW,0,RS(32,36))
            testBtnFrame.Position = UDim2.new(1,-(testBtnW+RS(14,12)),0.5,-RS(16,18))
            testBtnFrame.BackgroundTransparency = 1
            testBtnFrame.ZIndex = 7; testBtnFrame.Parent = btnRow

            local testBtnShadow = Instance.new("Frame")
            testBtnShadow.Size = UDim2.new(1,2,1,2)
            testBtnShadow.Position = UDim2.new(0,-1,0,2)
            testBtnShadow.BackgroundColor3 = Theme.Shadow
            testBtnShadow.BackgroundTransparency = 0.82
            testBtnShadow.BorderSizePixel = 0; testBtnShadow.ZIndex = 7
            testBtnShadow.Parent = testBtnFrame
            Corner(testBtnShadow, Theme.CornerRadius)

            local discordColor = Color3.fromRGB(88,101,242)
            local testBtn = Instance.new("TextButton")
            testBtn.Size = UDim2.new(1,-2,1,-2)
            testBtn.Position = UDim2.new(0,1,0,0)
            testBtn.BackgroundColor3 = discordColor
            testBtn.Text = "Send Test"
            testBtn.TextColor3 = Theme.Text
            testBtn.TextSize = Theme.FontSizeSmall; testBtn.Font = Theme.Font
            testBtn.BorderSizePixel = 0; testBtn.AutoButtonColor = false
            testBtn.ZIndex = 8; testBtn.Parent = testBtnFrame
            Corner(testBtn, Theme.CornerRadius)
            local testGlow = Stroke(testBtn, discordColor, 1.5, 0.6)

            local testBusy = false
            if not _isMobile then
                AddConnection(testBtn.MouseEnter:Connect(function()
                    if not testBusy then
                        Tween(testBtn,{BackgroundColor3=Color3.fromRGB(108,121,255)},0.15)
                        Tween(testGlow,{Transparency=0.3},0.2)
                    end
                end))
                AddConnection(testBtn.MouseLeave:Connect(function()
                    if not testBusy then
                        Tween(testBtn,{BackgroundColor3=discordColor},0.15)
                        Tween(testGlow,{Transparency=0.6},0.2)
                    end
                end))
            end

            AddConnection(testBtn.MouseButton1Click:Connect(function()
                if testBusy then return end
                local url = urlInput.Text
                if url == "" then
                    GluttonyUI:Notify("Webhook", "Please enter a webhook URL first.", "warning", 3)
                    Tween(urlGlow,{Transparency=0.2,Color=Theme.NotifWarning},0.2)
                    task.delay(1.5,function()
                        Tween(urlGlow,{Transparency=1,Color=Color3.fromRGB(88,101,242)},0.3)
                    end)
                    return
                end
                testBusy = true
                WebhookSystem:SetURL(url)
                StateStore[configKey] = url
                ConfigManager:Set(configKey, url)

                testBtn.Text = "Sending..."
                Tween(testBtn,{BackgroundColor3=Color3.fromRGB(100,100,120)},0.15)
                Tween(testBtn,{Size=UDim2.new(1,-6,1,-4)},0.06)
                task.delay(0.06,function()
                    Tween(testBtn,{Size=UDim2.new(1,-2,1,-2)},0.1,Enum.EasingStyle.Back)
                end)

                task.spawn(function()
                    local ok, result = WebhookSystem:Send({
                        Title       = testTitle,
                        Description = testDesc,
                        Color       = testColor,
                        Fields      = testFields,
                    })

                    if ok then
                        testBtn.Text = "✅ Sent!"
                        Tween(testBtn,{BackgroundColor3=Theme.NotifSuccess},0.2)
                        Tween(statusDot,{BackgroundColor3=Theme.NotifSuccess},0.3)
                        GluttonyUI:Notify("Webhook", "Test message sent successfully!", "success", 3)
                    else
                        testBtn.Text = "❌ Failed"
                        Tween(testBtn,{BackgroundColor3=Theme.NotifError},0.2)
                        Tween(statusDot,{BackgroundColor3=Theme.NotifError},0.3)
                        GluttonyUI:Notify("Webhook", "Failed to send. Check your URL.", "error", 4)
                    end

                    task.delay(2.5, function()
                        if testBtn and testBtn.Parent then
                            testBtn.Text = "Send Test"
                            Tween(testBtn,{BackgroundColor3=discordColor},0.2)
                            testBusy = false
                        end
                    end)
                end)
            end))
            SetupHover(btnRow, RowColor(btnRowOrder), btnAb)

            return {
                GetURL = function() return urlInput.Text end,
                SetURL = function(_, url)
                    urlInput.Text = url
                    StateStore[configKey] = url
                    ConfigManager:Set(configKey, url)
                    WebhookSystem:SetURL(url)
                    Tween(statusDot,{
                        BackgroundColor3 = url ~= "" and Theme.NotifSuccess or Theme.ToggleOff
                    },0.3)
                end,
                Send = function(_, sendOpts) return WebhookSystem:Send(sendOpts) end,
            }
        end

        return Tab
    end -- end Window:AddTab

    -- WINDOW METHODS
    function Window:Destroy()
        ConfigManager:Flush(); ThreadManager:StopAll()
        StopAntiAFK(); DisconnectAll()
        if screenGui then screenGui:Destroy() end
    end
    function Window:Notify(t,m,nt,d) GluttonyUI:Notify(t,m,nt,d) end
    function Window:GetValue(n) return StateStore[n] end
    function Window:SetValue(n,v) ConfigManager:Set(n,v) end
    function Window:SaveConfig() ConfigManager:Save() end
    function Window:ClearConfig() StateStore={}; ConfigManager:Save() end
    function Window:SendWebhook(opts) return WebhookSystem:Send(opts) end
    function Window:GetWebhook() return WebhookSystem end

    task.defer(function() ConfigManager:ApplyToUI() end)

    -- ════════════════════════════════════════════════════════════════
    -- SETTINGS TAB (with built-in Webhook section)
    -- ════════════════════════════════════════════════════════════════

    local function BuildSettingsTab()
        local so=999
        local sb=Instance.new("TextButton"); sb.Name="Tab_Settings"
        sb.Size=UDim2.new(1,-RS(14,10),0,RS(42,46))
        sb.BackgroundColor3=Theme.Sidebar; sb.BorderSizePixel=0
        sb.Text=""; sb.AutoButtonColor=false; sb.LayoutOrder=so
        sb.ZIndex=7; sb.Parent=tabContainer; Corner(sb,Theme.CornerRadius)

        local si=Instance.new("Frame"); si.Name="Indicator"
        si.Size=UDim2.new(0,4,0,22); si.Position=UDim2.new(0,5,0.5,-11)
        si.BackgroundColor3=Theme.Accent; si.BackgroundTransparency=1
        si.BorderSizePixel=0; si.ZIndex=8; si.Parent=sb; Corner(si,UDim.new(1,0))
        CreateTabIcon(sb,"settings",SW)

        local iconW2=RS(44,38)
        local sl=Instance.new("TextLabel"); sl.Name="Label"
        sl.Size=UDim2.new(1,-iconW2,1,0); sl.Position=UDim2.new(0,iconW2,0,0)
        sl.BackgroundTransparency=1; sl.Text="Settings"
        sl.TextColor3=Theme.TextDim; sl.TextSize=Theme.TabFontSize
        sl.Font=Theme.FontLight; sl.TextXAlignment=Enum.TextXAlignment.Left
        sl.TextTruncate=Enum.TextTruncate.AtEnd; sl.ZIndex=8; sl.Parent=sb

        if not _isMobile then
            AddConnection(sb.MouseEnter:Connect(function()
                if Window._currentTab~="Settings" then
                    Tween(sb,{BackgroundColor3=Theme.Hover},0.15)
                    Tween(sl,{TextColor3=Theme.Text},0.15)
                end
            end))
            AddConnection(sb.MouseLeave:Connect(function()
                if Window._currentTab~="Settings" then
                    Tween(sb,{BackgroundColor3=Theme.Sidebar},0.15)
                    Tween(sl,{TextColor3=Theme.TextDim},0.15)
                end
            end))
        end
        AddConnection(sb.MouseButton1Click:Connect(function() SwitchTab("Settings") end))
        Window._tabButtons["Settings"]=sb

        local sp=Instance.new("ScrollingFrame"); sp.Name="Page_Settings"
        sp.Size=UDim2.new(1,0,1,0); sp.BackgroundTransparency=1
        sp.BorderSizePixel=0; sp.ScrollBarThickness=RS(4,5)
        sp.ScrollBarImageColor3=Theme.Accent; sp.ScrollBarImageTransparency=0.3
        sp.CanvasSize=UDim2.new(0,0,0,0); sp.Visible=false
        sp.ZIndex=6; sp.Parent=content
        Padding(sp,RS(18,14),RS(18,14),RS(22,16),RS(22,16))

        local spl=ListLayout(sp,RS(8,10))
        AddConnection(spl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            sp.CanvasSize=UDim2.new(0,0,0,spl.AbsoluteContentSize.Y+40)
        end))
        Window._pages["Settings"]=sp

        -- Title
        local tf=Instance.new("Frame"); tf.Size=UDim2.new(1,0,0,42)
        tf.BackgroundTransparency=1; tf.LayoutOrder=0; tf.ZIndex=7; tf.Parent=sp
        local ptl=Instance.new("TextLabel"); ptl.Size=UDim2.new(1,0,0,34)
        ptl.BackgroundTransparency=1; ptl.Text="Settings"; ptl.TextColor3=Theme.Text
        ptl.TextSize=RS(24,22); ptl.Font=Theme.Font
        ptl.TextXAlignment=Enum.TextXAlignment.Left; ptl.ZIndex=7; ptl.Parent=tf
        local ul=Instance.new("Frame"); ul.Size=UDim2.new(0.25,0,0,2)
        ul.Position=UDim2.new(0,0,1,-2); ul.BackgroundColor3=Theme.Accent
        ul.BackgroundTransparency=0.3; ul.BorderSizePixel=0; ul.ZIndex=8; ul.Parent=tf
        Corner(ul,UDim.new(1,0))
        local ulg=Instance.new("UIGradient")
        ulg.Transparency=NumberSequence.new({
            NumberSequenceKeypoint.new(0,0),
            NumberSequenceKeypoint.new(0.7,0),
            NumberSequenceKeypoint.new(1,1)
        }); ulg.Parent=ul

        local lo=0; local function NSO() lo=lo+1; return lo end

        -- ── Interface section ──
        local il2=Instance.new("TextLabel"); il2.Size=UDim2.new(1,0,0,30)
        il2.BackgroundTransparency=1; il2.Text="Interface"
        il2.TextColor3=Theme.Accent; il2.TextSize=RS(15,16); il2.Font=Theme.Font
        il2.TextXAlignment=Enum.TextXAlignment.Left; il2.LayoutOrder=NSO()
        il2.ZIndex=7; il2.Parent=sp

        -- Opacity Slider
        local oo=NSO(); local ov=StateStore["GUI Opacity"] or 100
        local or_=Instance.new("Frame"); or_.Size=UDim2.new(1,0,0,RH+4)
        or_.BackgroundColor3=RowColor(oo); or_.BorderSizePixel=0; or_.LayoutOrder=oo
        or_.ZIndex=6; or_.ClipsDescendants=true; or_.Parent=sp; Corner(or_,Theme.CornerRadius)
        local oa=HoverAccent(or_)

        local ol=Instance.new("TextLabel"); ol.Size=UDim2.new(0,RS(170,130),1,0)
        ol.Position=UDim2.new(0,18,0,0); ol.BackgroundTransparency=1
        ol.Text="GUI Opacity"; ol.TextColor3=Theme.Text; ol.TextSize=Theme.FontSize
        ol.Font=Theme.FontLight; ol.TextXAlignment=Enum.TextXAlignment.Left
        ol.ZIndex=7; ol.Parent=or_

        local ob=Instance.new("Frame"); ob.Size=UDim2.new(0,RS(42,38),0,22)
        ob.Position=UDim2.new(1,-RS(158,150),0.5,-11)
        ob.BackgroundColor3=Theme.Accent; ob.BackgroundTransparency=0.85
        ob.BorderSizePixel=0; ob.ZIndex=7; ob.Parent=or_; Corner(ob,UDim.new(0,5))
        local ovl=Instance.new("TextLabel"); ovl.Size=UDim2.new(1,0,1,0)
        ovl.BackgroundTransparency=1; ovl.Text=tostring(math.floor(ov))
        ovl.TextColor3=Theme.Accent; ovl.TextSize=13; ovl.Font=Theme.Font
        ovl.ZIndex=8; ovl.Parent=ob

        local trackW2=RS(100,90); local trackH2=RS(6,8)
        local ot=Instance.new("Frame"); ot.Size=UDim2.new(0,trackW2,0,trackH2)
        ot.Position=UDim2.new(1,-(trackW2+RS(12,10)),0.5,-trackH2/2)
        ot.BackgroundColor3=Theme.SliderBg; ot.BorderSizePixel=0
        ot.ZIndex=8; ot.Parent=or_; Corner(ot,UDim.new(1,0))

        local op=(ov-10)/90
        local of2=Instance.new("Frame"); of2.Size=UDim2.new(op,0,1,0)
        of2.BackgroundColor3=Theme.SliderFill; of2.BorderSizePixel=0
        of2.ZIndex=9; of2.Parent=ot; Corner(of2,UDim.new(1,0))
        local knobSz2=RS(16,20)
        local ok2=Instance.new("Frame"); ok2.Size=UDim2.new(0,knobSz2,0,knobSz2)
        ok2.Position=UDim2.new(op,-knobSz2/2,0.5,-knobSz2/2)
        ok2.BackgroundColor3=Theme.Text; ok2.BorderSizePixel=0
        ok2.ZIndex=10; ok2.Parent=ot; Corner(ok2,UDim.new(1,0)); Stroke(ok2,Theme.Shadow,1,0.75)

        local osl=false
        local hitPad2=RS(7,14)
        local oh=Instance.new("TextButton")
        oh.Size=UDim2.new(1,hitPad2*2,1,hitPad2*2)
        oh.Position=UDim2.new(0,-hitPad2,0,-hitPad2)
        oh.BackgroundTransparency=1; oh.Text=""; oh.ZIndex=11; oh.Parent=ot

        local function AO(v)
            local t=1-(v/100); main.BackgroundTransparency=t
            if titleBar then titleBar.BackgroundTransparency=t end
            if sidebar then sidebar.BackgroundTransparency=t end
            if content then content.BackgroundTransparency=t end
        end

        local function UO(input2)
            local x=math.clamp(
                (input2.Position.X-ot.AbsolutePosition.X)/ot.AbsoluteSize.X,0,1)
            local v=math.floor(10+90*x); ov=v; ConfigManager:Set("GUI Opacity",v)
            ovl.Text=tostring(v); of2.Size=UDim2.new(x,0,1,0)
            ok2.Position=UDim2.new(x,-knobSz2/2,0.5,-knobSz2/2); AO(v)
        end

        AddConnection(oh.InputBegan:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1
                or i.UserInputType==Enum.UserInputType.Touch then
                osl=true; UO(i)
            end
        end))
        AddConnection(oh.InputEnded:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1
                or i.UserInputType==Enum.UserInputType.Touch then
                osl=false
            end
        end))
        AddConnection(UserInputService.InputChanged:Connect(function(i)
            if osl and (i.UserInputType==Enum.UserInputType.MouseMovement
                or i.UserInputType==Enum.UserInputType.Touch) then
                UO(i)
            end
        end))
        SetupHover(or_,RowColor(oo),oa); AO(ov)

        -- ── Spacer ──
        local sp2=Instance.new("Frame"); sp2.Size=UDim2.new(1,0,0,16)
        sp2.BackgroundTransparency=1; sp2.LayoutOrder=NSO(); sp2.Parent=sp

        -- ── Community section ──
        local cl=Instance.new("TextLabel"); cl.Size=UDim2.new(1,0,0,30)
        cl.BackgroundTransparency=1; cl.Text="Community"
        cl.TextColor3=Theme.Accent; cl.TextSize=RS(15,16); cl.Font=Theme.Font
        cl.TextXAlignment=Enum.TextXAlignment.Left; cl.LayoutOrder=NSO()
        cl.ZIndex=7; cl.Parent=sp

        local ic2=Instance.new("Frame"); ic2.Size=UDim2.new(1,0,0,RS(80,90))
        ic2.BackgroundColor3=Color3.fromRGB(28,30,38); ic2.BorderSizePixel=0
        ic2.LayoutOrder=NSO(); ic2.ZIndex=6; ic2.Parent=sp
        Corner(ic2,Theme.CornerRadius); Stroke(ic2,Theme.Border,1,0.4)
        local iab=Instance.new("Frame"); iab.Size=UDim2.new(0,4,1,-16)
        iab.Position=UDim2.new(0,10,0,8); iab.BackgroundColor3=Theme.Accent
        iab.BackgroundTransparency=0.3; iab.BorderSizePixel=0
        iab.ZIndex=7; iab.Parent=ic2; Corner(iab,UDim.new(1,0))
        local it=Instance.new("TextLabel"); it.Size=UDim2.new(1,-40,1,-20)
        it.Position=UDim2.new(0,28,0,10); it.BackgroundTransparency=1
        it.Text="Join our Discord for updates, feature requests, and support."
        it.TextColor3=Theme.TextDim; it.TextSize=RS(13,14); it.Font=Theme.FontLight
        it.TextXAlignment=Enum.TextXAlignment.Left; it.TextYAlignment=Enum.TextYAlignment.Center
        it.TextWrapped=true; it.ZIndex=7; it.Parent=ic2

        local dro=NSO()
        local dr=Instance.new("Frame"); dr.Size=UDim2.new(1,0,0,RH)
        dr.BackgroundColor3=RowColor(dro); dr.BorderSizePixel=0; dr.LayoutOrder=dro
        dr.ZIndex=6; dr.ClipsDescendants=true; dr.Parent=sp; Corner(dr,Theme.CornerRadius)
        local da=HoverAccent(dr)

        local dl=Instance.new("TextLabel"); dl.Size=UDim2.new(1,-130,1,0)
        dl.Position=UDim2.new(0,18,0,0); dl.BackgroundTransparency=1
        dl.Text="Discord Server"; dl.TextColor3=Theme.Text; dl.TextSize=Theme.FontSize
        dl.Font=Theme.FontLight; dl.TextXAlignment=Enum.TextXAlignment.Left
        dl.ZIndex=7; dl.Parent=dr

        local dbW=RS(100,90)
        local dbf=Instance.new("Frame"); dbf.Size=UDim2.new(0,dbW,0,RS(32,36))
        dbf.Position=UDim2.new(1,-(dbW+RS(14,12)),0.5,-RS(16,18))
        dbf.BackgroundTransparency=1; dbf.ZIndex=7; dbf.Parent=dr
        local dsh=Instance.new("Frame"); dsh.Size=UDim2.new(1,2,1,2)
        dsh.Position=UDim2.new(0,-1,0,2); dsh.BackgroundColor3=Theme.Shadow
        dsh.BackgroundTransparency=0.82; dsh.BorderSizePixel=0
        dsh.ZIndex=7; dsh.Parent=dbf; Corner(dsh,Theme.CornerRadius)

        local dc2c=Color3.fromRGB(88,101,242); local dh2=Color3.fromRGB(108,121,255)
        local sc2=Color3.fromRGB(50,180,80)
        local db=Instance.new("TextButton"); db.Size=UDim2.new(1,-2,1,-2)
        db.Position=UDim2.new(0,1,0,0); db.BackgroundColor3=dc2c
        db.Text="Copy Link"; db.TextColor3=Theme.Text; db.TextSize=RS(13,14)
        db.Font=Theme.Font; db.BorderSizePixel=0; db.AutoButtonColor=false
        db.ZIndex=8; db.Parent=dbf; Corner(db,Theme.CornerRadius)
        local dg=Stroke(db,dc2c,1.5,0.6)

        if not _isMobile then
            AddConnection(db.MouseEnter:Connect(function()
                Tween(db,{BackgroundColor3=dh2},0.15); Tween(dg,{Transparency=0.3},0.2)
            end))
            AddConnection(db.MouseLeave:Connect(function()
                Tween(db,{BackgroundColor3=dc2c},0.15); Tween(dg,{Transparency=0.6},0.2)
            end))
        end
        AddConnection(db.MouseButton1Click:Connect(function()
            Tween(db,{Size=UDim2.new(1,-6,1,-4)},0.06)
            task.delay(0.06,function()
                Tween(db,{Size=UDim2.new(1,-2,1,-2)},0.1,Enum.EasingStyle.Back)
            end)
            local url="https://discord.gg/6KmxCWU6Dc"
            local ok3=pcall(function()
                if setclipboard then setclipboard(url)
                elseif toclipboard then toclipboard(url)
                else error() end
            end)
            if ok3 then
                local ot2=db.Text; db.Text="Copied!"
                Tween(db,{BackgroundColor3=sc2},0.2)
                Tween(dg,{Color=sc2,Transparency=0.3},0.2)
                task.delay(1.5,function()
                    if db and db.Parent then
                        db.Text=ot2
                        Tween(db,{BackgroundColor3=dc2c},0.2)
                        Tween(dg,{Color=dc2c,Transparency=0.6},0.2)
                    end
                end)
            end
        end))
        SetupHover(dr,RowColor(dro),da)

        -- Version label
        local vl=Instance.new("TextLabel"); vl.Size=UDim2.new(0,40,0,16)
        vl.Position=UDim2.new(1,-50,1,-22); vl.BackgroundTransparency=1
        vl.Text="v2.3"; vl.TextColor3=Theme.TextDim; vl.TextTransparency=0.5
        vl.TextSize=RS(11,12); vl.Font=Theme.FontLight
        vl.TextXAlignment=Enum.TextXAlignment.Right; vl.ZIndex=15; vl.Parent=inner
    end
    BuildSettingsTab()

    -- ════════════════════════════════════════════════════════════════
    -- TOGGLE BUTTON (sidebar tab, draggable)
    -- ════════════════════════════════════════════════════════════════

    local tbW2=RS(36,44); local tbH2=RS(90,100)
    local TB=Instance.new("Frame"); TB.Name="ToggleButton"
    TB.Size=UDim2.new(0,tbW2,0,tbH2)

    local initX=_isMobile and (_screenSize.X-tbW2+4) or 8
    local initY=math.floor(_screenSize.Y*0.5-tbH2/2)
    TB.Position=UDim2.new(0,initX,0,initY)
    TB.BackgroundColor3=Theme.Background; TB.BorderSizePixel=0
    TB.ZIndex=100; TB.Parent=screenGui
    Corner(TB,UDim.new(0,12))

    local lc=Instance.new("Frame")
    lc.Size=UDim2.new(0,12,1,0)
    lc.Position=_isMobile and UDim2.new(1,-12,0,0) or UDim2.new(0,0,0,0)
    lc.BackgroundColor3=Theme.Background; lc.BorderSizePixel=0
    lc.ZIndex=101; lc.Parent=TB

    local tab2=Instance.new("Frame"); tab2.Name="AccentBar"
    tab2.AnchorPoint=Vector2.new(0.5,0.5)
    tab2.Size=UDim2.new(0,3,0,35)
    tab2.Position=_isMobile and UDim2.new(0,5,0.5,0) or UDim2.new(1,-5,0.5,0)
    tab2.BackgroundColor3=Theme.Accent; tab2.BorderSizePixel=0
    tab2.ZIndex=105; tab2.Parent=TB
    Corner(tab2,UDim.new(1,0))

    local dc3=Instance.new("Frame"); dc3.Size=UDim2.new(0,12,0,50)
    dc3.Position=UDim2.new(0.5,-6,0.5,-25); dc3.BackgroundTransparency=1
    dc3.ZIndex=105; dc3.Parent=TB

    local dots2={}
    for i=1,5 do
        local d=Instance.new("Frame")
        d.Size=UDim2.new(0,RS(6,8),0,RS(6,8))
        d.Position=UDim2.new(0.5,-RS(3,4),0,(i-1)*RS(11,13))
        d.BackgroundColor3=Theme.TextDim; d.BackgroundTransparency=0.3
        d.BorderSizePixel=0; d.ZIndex=106; d.Parent=dc3
        Corner(d,UDim.new(1,0)); table.insert(dots2,d)
    end

    local tcb2=Instance.new("TextButton"); tcb2.Size=UDim2.new(1,0,1,0)
    tcb2.BackgroundTransparency=1; tcb2.Text=""; tcb2.ZIndex=110; tcb2.Parent=TB

    -- Pulse animation
    local pr=true
    task.spawn(function()
        while pr do
            if not TB or not TB.Parent then break end
            Tween(tab2,{BackgroundTransparency=0.3},1.2,Enum.EasingStyle.Sine)
            task.wait(1.2)
            if not TB or not TB.Parent then break end
            Tween(tab2,{BackgroundTransparency=0},1.2,Enum.EasingStyle.Sine)
            task.wait(1.2)
        end
    end)

    -- Drag logic
    local tbDragActive=false; local tbMoved=false
    local tbClickDebounce=false; local tbDragStartY=0
    local tbStartOffsetX=0; local tbStartOffsetY=0

    AddConnection(tcb2.InputBegan:Connect(function(input)
        if input.UserInputType~=Enum.UserInputType.MouseButton1
        and input.UserInputType~=Enum.UserInputType.Touch then return end
        if tbClickDebounce then return end
        tbDragActive=true; tbMoved=false
        tbDragStartY=input.Position.Y
        tbStartOffsetX=TB.AbsolutePosition.X
        tbStartOffsetY=TB.AbsolutePosition.Y
    end))

    AddConnection(UserInputService.InputChanged:Connect(function(input)
        if not tbDragActive then return end
        if input.UserInputType~=Enum.UserInputType.MouseMovement
        and input.UserInputType~=Enum.UserInputType.Touch then return end
        local dy=input.Position.Y-tbDragStartY
        if math.abs(dy)>6 then tbMoved=true end
        if tbMoved then
            local screenY=workspace.CurrentCamera.ViewportSize.Y
            local newY=math.clamp(tbStartOffsetY+dy,0,screenY-TB.AbsoluteSize.Y)
            TB.Position=UDim2.new(0,tbStartOffsetX,0,newY)
        end
    end))

    AddConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType~=Enum.UserInputType.MouseButton1
        and input.UserInputType~=Enum.UserInputType.Touch then return end
        if not tbDragActive then return end
        tbDragActive=false
        local wasMoved=tbMoved; tbMoved=false
        if not wasMoved and not tbClickDebounce then
            tbClickDebounce=true
            if guiVisible then
                guiVisible=false; minimized=true
                Tween(main,{Size=UDim2.new(0,WW,0,0)},0.3)
                Tween(tab2,{Size=UDim2.new(0,3,0,35)},0.25)
                task.delay(0.3,function()
                    if main and main.Parent then main.Visible=false end
                    tbClickDebounce=false
                end)
            else
                guiVisible=true; minimized=false
                main.Visible=true; main.Size=UDim2.new(0,WW,0,0)
                Tween(main,{Size=UDim2.new(0,WW,0,WH)},0.35,Enum.EasingStyle.Back)
                Tween(tab2,{Size=UDim2.new(0,3,0,55)},0.25)
                task.delay(0.35,function() tbClickDebounce=false end)
            end
        end
    end))

    -- Hover effects (PC only)
    if not _isMobile then
        AddConnection(tcb2.MouseEnter:Connect(function()
            Tween(TB,{BackgroundColor3=Theme.Hover},0.2)
            Tween(lc,{BackgroundColor3=Theme.Hover},0.2)
            for i2,d in ipairs(dots2) do
                task.delay(i2*0.04,function()
                    if d and d.Parent then
                        Tween(d,{
                            BackgroundColor3=Theme.Accent,
                            BackgroundTransparency=0,
                            Size=UDim2.new(0,8,0,8),
                            Position=UDim2.new(0.5,-4,0,(i2-1)*11-1)
                        },0.15)
                    end
                end)
            end
        end))
        AddConnection(tcb2.MouseLeave:Connect(function()
            Tween(TB,{BackgroundColor3=Theme.Background},0.2)
            Tween(lc,{BackgroundColor3=Theme.Background},0.2)
            for i2,d in ipairs(dots2) do
                task.delay(i2*0.04,function()
                    if d and d.Parent then
                        Tween(d,{
                            BackgroundColor3=Theme.TextDim,
                            BackgroundTransparency=0.3,
                            Size=UDim2.new(0,6,0,6),
                            Position=UDim2.new(0.5,-3,0,(i2-1)*11)
                        },0.15)
                    end
                end)
            end
        end))
    end

    local od=Window.Destroy
    function Window:Destroy()
        pr=false; od(self)
    end

    return Window
end -- end CreateWindow

return GluttonyUI