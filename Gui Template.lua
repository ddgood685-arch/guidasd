--[[
═══════════════════════════════════════════════════════════════════════════
   GLUTTONY UI LIBRARY v2.1
   Built-in: Thread Manager, Auto-Resume, Anti-AFK, Number Parsing,
             PriorityList, RadioSelect, MultiSelect (with columns/sort),
             StatusButton, NumberInput, ThresholdRow, Hint/Warning,
             Dropdown Flip, Minimize Fix
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

-- NUMBER UTILITIES
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

-- CONFIG
local ConfigManager = {}
ConfigManager._fileName = nil
ConfigManager._enabled = false
ConfigManager._dirty = false
ConfigManager._saveThread = nil
ConfigManager._debounce = 1.5
ConfigManager._uiUpdaters = {}
ConfigManager._toggleMeta = {}

local function HasFileSupport()
    local ok,r = pcall(function() return type(writefile)=="function" and type(readfile)=="function" and type(isfile)=="function" end)
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
    for n,u in pairs(self._uiUpdaters) do local s=StateStore[n]; if s~=nil then pcall(u,s) end end
end

-- CONNECTIONS
local Connections = {}
local function AddConnection(c) table.insert(Connections,c); return c end
local function DisconnectAll() for _,c in ipairs(Connections) do pcall(function() c:Disconnect() end) end; Connections={} end

-- ANTI-AFK
local _antiAfkRunning = false
local _antiAfkThread = nil

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
                    VirtualInputManager:SendGamepadKeyEvent(Enum.UserInputType.Gamepad1,Enum.KeyCode.ButtonB,true,1)
                    task.wait(0.1)
                    VirtualInputManager:SendGamepadKeyEvent(Enum.UserInputType.Gamepad1,Enum.KeyCode.ButtonB,false,1)
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
    TweenService:Create(obj,TweenInfo.new(dur or 0.25,style or Enum.EasingStyle.Quart,dir or Enum.EasingDirection.Out),props):Play()
end

local function Corner(p,r) local c=Instance.new("UICorner"); c.CornerRadius=r or Theme.CornerRadius; c.Parent=p; return c end

local function Stroke(p,col,th,tr)
    local s=Instance.new("UIStroke"); s.Color=col or Theme.Border; s.Thickness=th or 1; s.Transparency=tr or 0.5
    s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; s.Parent=p; return s
end

local function Padding(p,t,b,l,r)
    local pd=Instance.new("UIPadding"); pd.PaddingTop=UDim.new(0,t or 0); pd.PaddingBottom=UDim.new(0,b or 0)
    pd.PaddingLeft=UDim.new(0,l or 0); pd.PaddingRight=UDim.new(0,r or 0); pd.Parent=p; return pd
end

local function ListLayout(p,pad,dir)
    local l=Instance.new("UIListLayout"); l.FillDirection=dir or Enum.FillDirection.Vertical
    l.SortOrder=Enum.SortOrder.LayoutOrder; l.Padding=UDim.new(0,pad or 6)
    l.HorizontalAlignment=Enum.HorizontalAlignment.Center; l.Parent=p; return l
end

local function HoverAccent(row)
    local bar=Instance.new("Frame"); bar.Name="HoverBar"; bar.Size=UDim2.new(0,3,0.55,0)
    bar.Position=UDim2.new(0,0,0.225,0); bar.BackgroundColor3=Theme.Accent; bar.BackgroundTransparency=1
    bar.BorderSizePixel=0; bar.ZIndex=row.ZIndex+1; bar.Parent=row; Corner(bar,UDim.new(1,0)); return bar
end

local function SetupHover(row,baseColor,accentBar)
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

-- NOTIFICATIONS
local NotifContainer = nil
local function EnsureNotifContainer(sg)
    if NotifContainer and NotifContainer.Parent then return end
    NotifContainer=Instance.new("Frame"); NotifContainer.Name="Notifications"
    NotifContainer.Size=UDim2.new(0,280,1,-20); NotifContainer.Position=UDim2.new(1,-290,0,10)
    NotifContainer.BackgroundTransparency=1; NotifContainer.ZIndex=200; NotifContainer.Parent=sg
    local l=Instance.new("UIListLayout"); l.FillDirection=Enum.FillDirection.Vertical
    l.VerticalAlignment=Enum.VerticalAlignment.Bottom; l.SortOrder=Enum.SortOrder.LayoutOrder
    l.Padding=UDim.new(0,8); l.Parent=NotifContainer
end

function GluttonyUI:Notify(title,message,notifType,duration)
    if not NotifContainer then return end
    duration=duration or 3; notifType=notifType or "info"
    local ac=Theme.NotifInfo
    if notifType=="success" then ac=Theme.NotifSuccess
    elseif notifType=="warning" then ac=Theme.NotifWarning
    elseif notifType=="error" then ac=Theme.NotifError end

    local n=Instance.new("Frame"); n.Size=UDim2.new(1,0,0,0); n.BackgroundColor3=Theme.TitleBar
    n.BorderSizePixel=0; n.ClipsDescendants=true; n.ZIndex=201; n.Parent=NotifContainer
    Corner(n,Theme.CornerRadius); Stroke(n,ac,1,0.4)

    local bar=Instance.new("Frame"); bar.Size=UDim2.new(0,4,1,-12); bar.Position=UDim2.new(0,6,0,6)
    bar.BackgroundColor3=ac; bar.BorderSizePixel=0; bar.ZIndex=202; bar.Parent=n; Corner(bar,UDim.new(1,0))

    local dot=Instance.new("Frame"); dot.Size=UDim2.new(0,8,0,8); dot.Position=UDim2.new(0,18,0,14)
    dot.BackgroundColor3=ac; dot.BorderSizePixel=0; dot.ZIndex=203; dot.Parent=n; Corner(dot,UDim.new(1,0))

    local tl=Instance.new("TextLabel"); tl.Size=UDim2.new(1,-44,0,18); tl.Position=UDim2.new(0,34,0,8)
    tl.BackgroundTransparency=1; tl.Text=title or "Notification"; tl.TextColor3=Theme.Text; tl.TextSize=14
    tl.Font=Theme.Font; tl.TextXAlignment=Enum.TextXAlignment.Left; tl.TextTruncate=Enum.TextTruncate.AtEnd
    tl.ZIndex=203; tl.Parent=n

    local ml=Instance.new("TextLabel"); ml.Size=UDim2.new(1,-44,0,30); ml.Position=UDim2.new(0,34,0,26)
    ml.BackgroundTransparency=1; ml.Text=message or ""; ml.TextColor3=Theme.TextDim; ml.TextSize=12
    ml.Font=Theme.FontLight; ml.TextXAlignment=Enum.TextXAlignment.Left; ml.TextWrapped=true
    ml.ZIndex=203; ml.Parent=n

    Tween(n,{Size=UDim2.new(1,0,0,62)},0.3,Enum.EasingStyle.Back)
    task.delay(duration,function()
        if n and n.Parent then Tween(n,{Size=UDim2.new(1,0,0,0),BackgroundTransparency=1},0.3); task.wait(0.35); if n and n.Parent then n:Destroy() end end
    end)
end

-- LOGO
local function CreateLogo(parent)
    local c=Instance.new("Frame"); c.Size=UDim2.new(0,32,0,32); c.Position=UDim2.new(0,12,0.5,-16)
    c.BackgroundTransparency=1; c.ZIndex=12; c.Parent=parent
    local il=Instance.new("ImageLabel"); il.Size=UDim2.new(1,0,1,0); il.BackgroundTransparency=1
    il.ScaleType=Enum.ScaleType.Fit; il.ZIndex=13; il.Parent=c; Corner(il,UDim.new(1,0))
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
        local r=Instance.new("Frame"); r.Size=UDim2.new(1,0,1,0); r.BackgroundColor3=Theme.Accent
        r.BackgroundTransparency=0.6; r.BorderSizePixel=0; r.ZIndex=12; r.Parent=c; Corner(r,UDim.new(1,0))
        local i=Instance.new("Frame"); i.Size=UDim2.new(0,18,0,18); i.AnchorPoint=Vector2.new(0.5,0.5)
        i.Position=UDim2.new(0.5,0,0.5,0); i.BackgroundColor3=Theme.Accent; i.BorderSizePixel=0
        i.ZIndex=13; i.Parent=c; Corner(i,UDim.new(1,0))
        local g=Instance.new("Frame"); g.Size=UDim2.new(0,10,0,10); g.AnchorPoint=Vector2.new(0.5,0.5)
        g.Position=UDim2.new(0.5,0,0.5,0); g.BackgroundColor3=Color3.fromRGB(255,255,255)
        g.BackgroundTransparency=0.4; g.BorderSizePixel=0; g.ZIndex=14; g.Parent=c; Corner(g,UDim.new(1,0))
    end
end

-- TAB ICONS
local function CreateTabIcon(parent,iconType)
    local c=Instance.new("Frame"); c.Size=UDim2.new(0,20,0,20); c.Position=UDim2.new(0,18,0.5,-10)
    c.BackgroundTransparency=1; c.ZIndex=9; c.Parent=parent
    local m={circle="●",square="■",diamond="◆",bars="≡",triangle="▶",["dot-grid"]="⊞",settings="⚙",bolt="⚡",shield="⛨",star="★"}
    local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,0,1,0); l.BackgroundTransparency=1
    l.Text=m[iconType] or "●"; l.TextColor3=Theme.Accent; l.TextSize=16; l.Font=Enum.Font.GothamBold
    l.ZIndex=10; l.Parent=c
end

local IconTypes={"circle","square","diamond","bars","triangle","dot-grid","bolt","star","shield"}

-- ════════════════════════════════════════════════════════════════
-- CREATE WINDOW
-- ════════════════════════════════════════════════════════════════

function GluttonyUI:CreateWindow(options)
    if type(options)=="string" then options={Title=options} end
    options=options or {}
    local title=options.Title or "Gluttony Core"
    local configName=options.ConfigName
    local antiAfk=options.AntiAFK

    for _,v in pairs(playerGui:GetChildren()) do if v.Name=="GluttonyUILib" then v:Destroy() end end
    DisconnectAll(); ThreadManager:StopAll(); StopAntiAFK()
    StateStore={}; ConfigManager._uiUpdaters={}; ConfigManager._toggleMeta={}
    ConfigManager:Init(configName); ConfigManager:Load()
    if antiAfk then StartAntiAFK() end

    local screenGui=Instance.new("ScreenGui"); screenGui.Name="GluttonyUILib"
    screenGui.ResetOnSpawn=false; screenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; screenGui.Parent=playerGui
    EnsureNotifContainer(screenGui)

    local main=Instance.new("Frame"); main.Name="Main"
    main.Size=UDim2.new(0,Theme.WindowWidth,0,Theme.WindowHeight)
    main.Position=UDim2.new(0.5,-Theme.WindowWidth/2,0.5,-Theme.WindowHeight/2)
    main.BackgroundColor3=Theme.Background; main.BorderSizePixel=0; main.ClipsDescendants=true
    main.Parent=screenGui; Corner(main,Theme.CornerLarge); Stroke(main,Theme.Border,1.5,0.3)

    local shadow=Instance.new("ImageLabel"); shadow.AnchorPoint=Vector2.new(0.5,0.5)
    shadow.BackgroundTransparency=1; shadow.Position=UDim2.new(0.5,0,0.5,0)
    shadow.Size=UDim2.new(1,60,1,60); shadow.ZIndex=-1; shadow.Image="rbxassetid://5554236805"
    shadow.ImageColor3=Theme.Shadow; shadow.ImageTransparency=0.4; shadow.ScaleType=Enum.ScaleType.Slice
    shadow.SliceCenter=Rect.new(23,23,277,277); shadow.Parent=main

    local inner=Instance.new("Frame"); inner.Name="Inner"; inner.Size=UDim2.new(1,0,1,0)
    inner.BackgroundTransparency=1; inner.ClipsDescendants=true; inner.ZIndex=2; inner.Parent=main
    Corner(inner,Theme.CornerLarge)

    -- TITLE BAR
    local titleBar=Instance.new("Frame"); titleBar.Size=UDim2.new(1,0,0,42)
    titleBar.BackgroundColor3=Theme.TitleBar; titleBar.BorderSizePixel=0; titleBar.ZIndex=10; titleBar.Parent=inner
    Corner(titleBar,Theme.CornerLarge)

    local titleCover=Instance.new("Frame"); titleCover.Size=UDim2.new(1,0,0,14)
    titleCover.Position=UDim2.new(0,0,1,-14); titleCover.BackgroundColor3=Theme.TitleBar
    titleCover.BorderSizePixel=0; titleCover.ZIndex=10; titleCover.Parent=titleBar

    CreateLogo(titleBar)

    local titleLabel=Instance.new("TextLabel"); titleLabel.Size=UDim2.new(1,-140,1,0)
    titleLabel.Position=UDim2.new(0,52,0,0); titleLabel.BackgroundTransparency=1; titleLabel.Text=title
    titleLabel.TextColor3=Theme.Text; titleLabel.TextSize=17; titleLabel.Font=Theme.Font
    titleLabel.TextXAlignment=Enum.TextXAlignment.Left; titleLabel.ZIndex=11; titleLabel.Parent=titleBar

    -- CLOSE
    local closeBtn=Instance.new("TextButton"); closeBtn.Size=UDim2.new(0,28,0,28)
    closeBtn.Position=UDim2.new(1,-38,0.5,-14); closeBtn.BackgroundColor3=Color3.fromRGB(60,35,35)
    closeBtn.Text=""; closeBtn.BorderSizePixel=0; closeBtn.AutoButtonColor=false; closeBtn.ZIndex=12
    closeBtn.Parent=titleBar; Corner(closeBtn,Theme.CornerRadius)

    local x1=Instance.new("Frame"); x1.Size=UDim2.new(0,12,0,2); x1.AnchorPoint=Vector2.new(0.5,0.5)
    x1.Position=UDim2.new(0.5,0,0.5,0); x1.BackgroundColor3=Theme.Accent; x1.Rotation=45
    x1.BorderSizePixel=0; x1.ZIndex=13; x1.Parent=closeBtn; Corner(x1,UDim.new(1,0))
    local x2=x1:Clone(); x2.Rotation=-45; x2.Parent=closeBtn

    AddConnection(closeBtn.MouseEnter:Connect(function()
        Tween(closeBtn,{BackgroundColor3=Theme.Accent},0.15); Tween(x1,{BackgroundColor3=Theme.Text},0.15); Tween(x2,{BackgroundColor3=Theme.Text},0.15)
    end))
    AddConnection(closeBtn.MouseLeave:Connect(function()
        Tween(closeBtn,{BackgroundColor3=Color3.fromRGB(60,35,35)},0.15); Tween(x1,{BackgroundColor3=Theme.Accent},0.15); Tween(x2,{BackgroundColor3=Theme.Accent},0.15)
    end))
    AddConnection(closeBtn.MouseButton1Click:Connect(function()
        ConfigManager:Flush(); ThreadManager:StopAll(); StopAntiAFK(); DisconnectAll(); screenGui:Destroy()
    end))

    -- MINIMIZE (FIXED)
    local minBtn=Instance.new("TextButton"); minBtn.Size=UDim2.new(0,28,0,28)
    minBtn.Position=UDim2.new(1,-74,0.5,-14); minBtn.BackgroundColor3=Color3.fromRGB(45,45,55)
    minBtn.Text=""; minBtn.BorderSizePixel=0; minBtn.AutoButtonColor=false; minBtn.ZIndex=12
    minBtn.Parent=titleBar; Corner(minBtn,Theme.CornerRadius)

    local minLine=Instance.new("Frame"); minLine.Size=UDim2.new(0,12,0,2)
    minLine.Position=UDim2.new(0.5,-6,0.5,-1); minLine.BackgroundColor3=Theme.TextDim
    minLine.BorderSizePixel=0; minLine.ZIndex=13; minLine.Parent=minBtn; Corner(minLine,UDim.new(1,0))

    local minimized=false
    AddConnection(minBtn.MouseEnter:Connect(function()
        Tween(minBtn,{BackgroundColor3=Color3.fromRGB(60,60,75)},0.15); Tween(minLine,{BackgroundColor3=Theme.Text},0.15)
    end))
    AddConnection(minBtn.MouseLeave:Connect(function()
        Tween(minBtn,{BackgroundColor3=Color3.fromRGB(45,45,55)},0.15); Tween(minLine,{BackgroundColor3=Theme.TextDim},0.15)
    end))
    AddConnection(minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            Tween(main,{Size=UDim2.new(0,Theme.WindowWidth,0,0)},0.3)
            task.delay(0.3, function() main.Visible = false end)
        else
            main.Visible = true
            main.Size = UDim2.new(0,Theme.WindowWidth,0,0)
            Tween(main,{Size=UDim2.new(0,Theme.WindowWidth,0,Theme.WindowHeight)},0.35,Enum.EasingStyle.Back)
        end
    end))

    -- DRAG
    local dragging,dragStart,startPos=false,nil,nil; local dragInput=nil
    AddConnection(titleBar.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=input.Position; startPos=main.Position
            local ec; ec=input.Changed:Connect(function()
                if input.UserInputState==Enum.UserInputState.End then dragging=false; if ec then ec:Disconnect() end end
            end)
        end
    end))
    AddConnection(titleBar.InputChanged:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then dragInput=input end
    end))
    AddConnection(UserInputService.InputChanged:Connect(function(input)
        if input==dragInput and dragging and startPos then
            local d=input.Position-dragStart
            main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end))

    -- SIDEBAR
    local sidebar=Instance.new("Frame"); sidebar.Size=UDim2.new(0,Theme.SidebarWidth,1,-42)
    sidebar.Position=UDim2.new(0,0,0,42); sidebar.BackgroundColor3=Theme.Sidebar; sidebar.BorderSizePixel=0
    sidebar.ZIndex=5; sidebar.Parent=inner; Corner(sidebar,Theme.CornerLarge)

    local divider=Instance.new("Frame"); divider.Size=UDim2.new(0,1,1,-20); divider.Position=UDim2.new(1,0,0,10)
    divider.BackgroundColor3=Theme.Border; divider.BackgroundTransparency=0.5; divider.BorderSizePixel=0
    divider.ZIndex=6; divider.Parent=sidebar

    local tabContainer=Instance.new("Frame"); tabContainer.Size=UDim2.new(1,0,1,-20)
    tabContainer.Position=UDim2.new(0,0,0,10); tabContainer.BackgroundTransparency=1; tabContainer.ZIndex=6
    tabContainer.Parent=sidebar; ListLayout(tabContainer,5)

    -- CONTENT
    local content=Instance.new("Frame"); content.Size=UDim2.new(1,-Theme.SidebarWidth-1,1,-52)
    content.Position=UDim2.new(0,Theme.SidebarWidth+1,0,42); content.BackgroundColor3=Theme.Background
    content.BorderSizePixel=0; content.ClipsDescendants=false; content.ZIndex=5; content.Parent=inner
    Corner(content,Theme.CornerLarge)

    -- KEYBIND
    AddConnection(UserInputService.InputBegan:Connect(function(input,processed)
        if processed then return end
        if input.KeyCode==Enum.KeyCode.RightShift then
            if main.Visible then
                Tween(main,{Size=UDim2.new(0,Theme.WindowWidth,0,0)},0.3)
                task.wait(0.3); main.Visible=false
            else
                main.Visible=true; main.Size=UDim2.new(0,Theme.WindowWidth,0,0)
                Tween(main,{Size=UDim2.new(0,Theme.WindowWidth,0,Theme.WindowHeight)},0.4,Enum.EasingStyle.Back)
            end
        end
    end))

    AddConnection(Players.PlayerRemoving:Connect(function(plr)
        if plr==player then ConfigManager:Flush(); ThreadManager:StopAll(); StopAntiAFK() end
    end))

    -- WINDOW OBJECT
    local Window={}
    Window._pages={}; Window._tabButtons={}; Window._currentTab=nil; Window._tabCount=0
    local activeDropdownPanel=nil

    local function SwitchTab(tabName)
        if activeDropdownPanel and activeDropdownPanel.Parent then
            activeDropdownPanel.Visible=false; activeDropdownPanel.Size=UDim2.new(0,0,0,0); activeDropdownPanel=nil
        end
        Window._currentTab=tabName
        for name,pg in pairs(Window._pages) do pg.Visible=(name==tabName) end
        for name,btn in pairs(Window._tabButtons) do
            local ind=btn:FindFirstChild("Indicator"); local lbl=btn:FindFirstChild("Label")
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
    function Window:AddTab(name,iconType)
        Window._tabCount=Window._tabCount+1
        local isFirst=Window._tabCount==1
        iconType=iconType or IconTypes[((Window._tabCount-1)%#IconTypes)+1]

        local tabBtn=Instance.new("TextButton"); tabBtn.Name="Tab_"..name
        tabBtn.Size=UDim2.new(1,-14,0,42); tabBtn.BackgroundColor3=isFirst and Theme.SelectedTab or Theme.Sidebar
        tabBtn.BorderSizePixel=0; tabBtn.Text=""; tabBtn.AutoButtonColor=false
        tabBtn.LayoutOrder=Window._tabCount; tabBtn.ZIndex=7; tabBtn.Parent=tabContainer
        Corner(tabBtn,Theme.CornerRadius)

        local indicator=Instance.new("Frame"); indicator.Name="Indicator"
        indicator.Size=isFirst and UDim2.new(0,4,0,26) or UDim2.new(0,4,0,22)
        indicator.Position=UDim2.new(0,5,0.5,-11); indicator.BackgroundColor3=Theme.Accent
        indicator.BackgroundTransparency=isFirst and 0 or 1; indicator.BorderSizePixel=0
        indicator.ZIndex=8; indicator.Parent=tabBtn; Corner(indicator,UDim.new(1,0))

        CreateTabIcon(tabBtn,iconType)

        local tabLabel=Instance.new("TextLabel"); tabLabel.Name="Label"
        tabLabel.Size=UDim2.new(1,-52,1,0); tabLabel.Position=UDim2.new(0,44,0,0)
        tabLabel.BackgroundTransparency=1; tabLabel.Text=name
        tabLabel.TextColor3=isFirst and Theme.Text or Theme.TextDim; tabLabel.TextSize=14
        tabLabel.Font=Theme.FontLight; tabLabel.TextXAlignment=Enum.TextXAlignment.Left
        tabLabel.ZIndex=8; tabLabel.Parent=tabBtn

        AddConnection(tabBtn.MouseEnter:Connect(function()
            if Window._currentTab~=name then Tween(tabBtn,{BackgroundColor3=Theme.Hover},0.15); Tween(tabLabel,{TextColor3=Theme.Text},0.15) end
        end))
        AddConnection(tabBtn.MouseLeave:Connect(function()
            if Window._currentTab~=name then Tween(tabBtn,{BackgroundColor3=Theme.Sidebar},0.15); Tween(tabLabel,{TextColor3=Theme.TextDim},0.15) end
        end))
        AddConnection(tabBtn.MouseButton1Click:Connect(function() SwitchTab(name) end))

        Window._tabButtons[name]=tabBtn

        local page=Instance.new("ScrollingFrame"); page.Name="Page_"..name
        page.Size=UDim2.new(1,0,1,0); page.BackgroundTransparency=1; page.BorderSizePixel=0
        page.ScrollBarThickness=4; page.ScrollBarImageColor3=Theme.Accent
        page.ScrollBarImageTransparency=0.3; page.CanvasSize=UDim2.new(0,0,0,0)
        page.Visible=isFirst; page.ZIndex=6; page.Parent=content
        Padding(page,18,18,22,22)

        local pageLayout=ListLayout(page,8)

        local titleFrame=Instance.new("Frame"); titleFrame.Size=UDim2.new(1,0,0,42)
        titleFrame.BackgroundTransparency=1; titleFrame.LayoutOrder=0; titleFrame.ZIndex=7; titleFrame.Parent=page

        local ptl=Instance.new("TextLabel"); ptl.Size=UDim2.new(1,0,0,34); ptl.BackgroundTransparency=1
        ptl.Text=name; ptl.TextColor3=Theme.Text; ptl.TextSize=24; ptl.Font=Theme.Font
        ptl.TextXAlignment=Enum.TextXAlignment.Left; ptl.ZIndex=7; ptl.Parent=titleFrame

        local ul=Instance.new("Frame"); ul.Size=UDim2.new(0.25,0,0,2); ul.Position=UDim2.new(0,0,1,-2)
        ul.BackgroundColor3=Theme.Accent; ul.BackgroundTransparency=0.3; ul.BorderSizePixel=0
        ul.ZIndex=8; ul.Parent=titleFrame; Corner(ul,UDim.new(1,0))
        local ulg=Instance.new("UIGradient")
        ulg.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.7,0),NumberSequenceKeypoint.new(1,1)})
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
            local sl=Instance.new("TextLabel"); sl.Size=UDim2.new(1,0,0,30); sl.BackgroundTransparency=1
            sl.Text=t; sl.TextColor3=Theme.Accent; sl.TextSize=15; sl.Font=Theme.Font
            sl.TextXAlignment=Enum.TextXAlignment.Left; sl.LayoutOrder=o; sl.ZIndex=7; sl.Parent=page
            local sc=Instance.new("Frame"); sc.Size=UDim2.new(1,0,0,8); sc.BackgroundTransparency=1
            sc.LayoutOrder=o+0.5; sc.Parent=page
            local sep=Instance.new("Frame"); sep.Size=UDim2.new(0.4,0,0,1); sep.Position=UDim2.new(0,0,0.5,0)
            sep.BackgroundColor3=Theme.Accent; sep.BackgroundTransparency=0.5; sep.BorderSizePixel=0
            sep.ZIndex=7; sep.Parent=sc; Corner(sep,UDim.new(1,0))
            local sg=Instance.new("UIGradient")
            sg.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.5,0.3),NumberSequenceKeypoint.new(1,1)})
            sg.Parent=sep
        end

        function Tab:AddLabel(t)
            local o=NextOrder()
            local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,0,0,28); l.BackgroundTransparency=1
            l.Text=t; l.TextColor3=Theme.TextDim; l.TextSize=13; l.Font=Theme.FontLight
            l.TextXAlignment=Enum.TextXAlignment.Left; l.TextWrapped=true; l.LayoutOrder=o; l.ZIndex=7; l.Parent=page
            return l
        end

        function Tab:AddSpacer(h)
            local o=NextOrder()
            local s=Instance.new("Frame"); s.Size=UDim2.new(1,0,0,h or 16); s.BackgroundTransparency=1
            s.LayoutOrder=o; s.Parent=page
        end

        function Tab:AddHint(t)
            local o=NextOrder()
            local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,56); f.BackgroundColor3=Theme.HintBg
            f.BorderSizePixel=0; f.LayoutOrder=o; f.ZIndex=6; f.Parent=page
            Corner(f,Theme.CornerRadius); Stroke(f,Theme.HintColor,1,0.5)
            local ib=Instance.new("Frame"); ib.Size=UDim2.new(0,32,0,32); ib.Position=UDim2.new(0,12,0.5,-16)
            ib.BackgroundColor3=Theme.HintColor; ib.BackgroundTransparency=0.85; ib.BorderSizePixel=0
            ib.ZIndex=7; ib.Parent=f; Corner(ib,UDim.new(0,6))
            local il=Instance.new("TextLabel"); il.Size=UDim2.new(1,0,1,0); il.BackgroundTransparency=1
            il.Text="💡"; il.TextSize=16; il.ZIndex=8; il.Parent=ib
            local ht=Instance.new("TextLabel"); ht.Size=UDim2.new(1,-60,1,-16); ht.Position=UDim2.new(0,52,0,8)
            ht.BackgroundTransparency=1; ht.Text=t; ht.TextColor3=Theme.HintColor; ht.TextSize=13
            ht.Font=Theme.FontLight; ht.TextXAlignment=Enum.TextXAlignment.Left; ht.TextWrapped=true
            ht.ZIndex=7; ht.Parent=f; return f
        end

        function Tab:AddWarning(t)
            local o=NextOrder()
            local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,56); f.BackgroundColor3=Theme.WarningBg
            f.BorderSizePixel=0; f.LayoutOrder=o; f.ZIndex=6; f.Parent=page
            Corner(f,Theme.CornerRadius); Stroke(f,Theme.WarningColor,1,0.5)
            local ib=Instance.new("Frame"); ib.Size=UDim2.new(0,32,0,32); ib.Position=UDim2.new(0,12,0.5,-16)
            ib.BackgroundColor3=Theme.WarningColor; ib.BackgroundTransparency=0.85; ib.BorderSizePixel=0
            ib.ZIndex=7; ib.Parent=f; Corner(ib,UDim.new(0,6))
            local il=Instance.new("TextLabel"); il.Size=UDim2.new(1,0,1,0); il.BackgroundTransparency=1
            il.Text="⚠️"; il.TextSize=16; il.ZIndex=8; il.Parent=ib
            local wt=Instance.new("TextLabel"); wt.Size=UDim2.new(1,-60,1,-16); wt.Position=UDim2.new(0,52,0,8)
            wt.BackgroundTransparency=1; wt.Text=t; wt.TextColor3=Theme.WarningColor; wt.TextSize=13
            wt.Font=Theme.FontLight; wt.TextXAlignment=Enum.TextXAlignment.Left; wt.TextWrapped=true
            wt.ZIndex=7; wt.Parent=f; return f
        end
        
                -- PROTECTION LIST (searchable list with toggle + mutation pills per item)
        function Tab:AddProtectionList(labelText, items, opts)
            --[[
                items = array of {
                    Name     = string,
                    Rarity   = string (optional),
                    CPS      = number or nil,
                    Special  = boolean (optional),
                    RarityColor = Color3 (optional),
                }
                opts = {
                    MutationPills = { {Key="ALL", Short="All", Color=Color3}, ... },
                    OnProtectionChanged = function(name, isProtected),
                    OnMutationChanged   = function(name, mutationKey),
                    GetProtected        = function(name) -> bool,
                    SetProtected        = function(name, bool),
                    GetMutationMode     = function(name) -> string,
                    SetMutationMode     = function(name, string),
                    FormatCPS           = function(number) -> string (optional),
                }
            ]]
            opts = opts or {}
            local order = NextOrder()

            local getProtected   = opts.GetProtected   or function() return false end
            local setProtected   = opts.SetProtected   or function() end
            local getMutMode     = opts.GetMutationMode or function() return "NONE" end
            local setMutMode     = opts.SetMutationMode or function() end
            local formatCPS      = opts.FormatCPS       or GluttonyUI.FormatNumber
            local pillDefs       = opts.MutationPills   or {}
            local onProtChanged  = opts.OnProtectionChanged
            local onMutChanged   = opts.OnMutationChanged

            -- Search bar
            local searchFrame = Instance.new("Frame")
            searchFrame.Size = UDim2.new(1, 0, 0, 38)
            searchFrame.BackgroundColor3 = Theme.InputBg
            searchFrame.BorderSizePixel = 0
            searchFrame.LayoutOrder = order
            searchFrame.ZIndex = 7
            searchFrame.Parent = page
            Corner(searchFrame)
            local searchGlow = Stroke(searchFrame, Theme.Accent, 1.5, 1)

            local searchIcon = Instance.new("TextLabel")
            searchIcon.Size = UDim2.new(0, 30, 1, 0)
            searchIcon.Position = UDim2.new(0, 8, 0, 0)
            searchIcon.BackgroundTransparency = 1
            searchIcon.Text = "🔍"
            searchIcon.TextSize = 14
            searchIcon.ZIndex = 8
            searchIcon.Parent = searchFrame

            local searchBox = Instance.new("TextBox")
            searchBox.Size = UDim2.new(1, -44, 1, 0)
            searchBox.Position = UDim2.new(0, 36, 0, 0)
            searchBox.BackgroundTransparency = 1
            searchBox.PlaceholderText = "Search..."
            searchBox.PlaceholderColor3 = Theme.TextDim
            searchBox.TextColor3 = Theme.Text
            searchBox.TextSize = 13
            searchBox.Font = Theme.FontLight
            searchBox.ClearTextOnFocus = false
            searchBox.TextXAlignment = Enum.TextXAlignment.Left
            searchBox.ZIndex = 8
            searchBox.Parent = searchFrame

            AddConnection(searchBox.Focused:Connect(function() Tween(searchGlow, {Transparency = 0.3}, 0.2) end))
            AddConnection(searchBox.FocusLost:Connect(function() Tween(searchGlow, {Transparency = 1}, 0.2) end))

            -- Count label
            local countOrder = NextOrder()
            local countLabel = Instance.new("TextLabel")
            countLabel.Size = UDim2.new(1, 0, 0, 20)
            countLabel.BackgroundTransparency = 1
            countLabel.TextColor3 = Theme.TextDim
            countLabel.TextSize = 12
            countLabel.Font = Theme.FontLight
            countLabel.TextXAlignment = Enum.TextXAlignment.Left
            countLabel.LayoutOrder = countOrder
            countLabel.ZIndex = 7
            countLabel.Parent = page

            -- List container
            local listOrder = NextOrder()
            local listContainer = Instance.new("Frame")
            listContainer.Name = "ProtectionList"
            listContainer.Size = UDim2.new(1, 0, 0, 0)
            listContainer.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
            listContainer.BorderSizePixel = 0
            listContainer.LayoutOrder = listOrder
            listContainer.ZIndex = 6
            listContainer.AutomaticSize = Enum.AutomaticSize.Y
            listContainer.Parent = page
            Corner(listContainer)
            Stroke(listContainer, Theme.Border, 1, 0.3)

            local listLayout = Instance.new("UIListLayout")
            listLayout.FillDirection = Enum.FillDirection.Vertical
            listLayout.SortOrder = Enum.SortOrder.LayoutOrder
            listLayout.Padding = UDim.new(0, 4)
            listLayout.Parent = listContainer
            Padding(listContainer, 6, 6, 6, 6)

            local rowElements = {}
            local hasPills = #pillDefs > 0
            local rowHeight = hasPills and 78 or 44

            local function updateCount()
                local vis = 0
                for _, rd in pairs(rowElements) do
                    if rd.Frame.Visible then vis = vis + 1 end
                end
                countLabel.Text = tostring(vis) .. " / " .. tostring(#items) .. " " .. labelText
            end

            for i, item in ipairs(items) do
                local isProtected = getProtected(item.Name)
                local baseColor = (i % 2 == 0) and Theme.Row or Theme.RowAlt
                local rarityColor = item.RarityColor or Theme.TextDim
                local cpsText = item.CPS and (formatCPS(item.CPS) .. "/s") or "⭐ Special"

                local row = Instance.new("Frame")
                row.Name = "Item_" .. item.Name
                row.Size = UDim2.new(1, -8, 0, rowHeight)
                row.BackgroundColor3 = baseColor
                row.BorderSizePixel = 0
                row.LayoutOrder = i
                row.ZIndex = 8
                row.ClipsDescendants = true
                row.Parent = listContainer
                Corner(row, UDim.new(0, 7))

                -- Hover bar
                local hbar = Instance.new("Frame")
                hbar.Size = UDim2.new(0, 3, 0.55, 0)
                hbar.Position = UDim2.new(0, 0, 0.225, 0)
                hbar.BackgroundColor3 = Theme.Accent
                hbar.BackgroundTransparency = 1
                hbar.BorderSizePixel = 0
                hbar.ZIndex = 9
                hbar.Parent = row
                Corner(hbar, UDim.new(1, 0))

                -- Rarity bar
                local rbar = Instance.new("Frame")
                rbar.Size = UDim2.new(0, 3, 0.65, 0)
                rbar.Position = UDim2.new(0, 4, 0.175, 0)
                rbar.BackgroundColor3 = rarityColor
                rbar.BorderSizePixel = 0
                rbar.ZIndex = 9
                rbar.Parent = row
                Corner(rbar, UDim.new(1, 0))

                -- Rarity dot
                local rdot = Instance.new("Frame")
                rdot.Size = UDim2.new(0, 10, 0, 10)
                rdot.Position = UDim2.new(0, 16, 0, 8)
                rdot.BackgroundColor3 = rarityColor
                rdot.BorderSizePixel = 0
                rdot.ZIndex = 9
                rdot.Parent = row
                Corner(rdot, UDim.new(1, 0))

                -- Special star
                if item.Special then
                    local star = Instance.new("TextLabel")
                    star.Size = UDim2.new(0, 18, 0, 18)
                    star.Position = UDim2.new(0, 30, 0, 3)
                    star.BackgroundTransparency = 1
                    star.Text = "⭐"
                    star.TextSize = 12
                    star.ZIndex = 10
                    star.Parent = row
                end

                -- Name
                local nameX = item.Special and 52 or 32
                local nameLabel = Instance.new("TextLabel")
                nameLabel.Size = UDim2.new(1, -160, 0, 22)
                nameLabel.Position = UDim2.new(0, nameX, 0, 4)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Text = item.Name
                nameLabel.TextColor3 = Theme.Text
                nameLabel.TextSize = 13
                nameLabel.Font = Theme.FontLight
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
                nameLabel.ZIndex = 9
                nameLabel.Parent = row

                -- CPS badge
                if item.CPS then
                    local cpsBadge = Instance.new("Frame")
                    cpsBadge.Size = UDim2.new(0, 72, 0, 20)
                    cpsBadge.Position = UDim2.new(1, -130, 0, 4)
                    cpsBadge.BackgroundColor3 = rarityColor
                    cpsBadge.BackgroundTransparency = 0.85
                    cpsBadge.BorderSizePixel = 0
                    cpsBadge.ZIndex = 9
                    cpsBadge.Parent = row
                    Corner(cpsBadge, UDim.new(0, 5))
                    local cpsLbl = Instance.new("TextLabel")
                    cpsLbl.Size = UDim2.new(1, 0, 1, 0)
                    cpsLbl.BackgroundTransparency = 1
                    cpsLbl.Text = cpsText
                    cpsLbl.TextColor3 = rarityColor
                    cpsLbl.TextSize = 11
                    cpsLbl.Font = Theme.Font
                    cpsLbl.ZIndex = 10
                    cpsLbl.Parent = cpsBadge
                end

                -- Protection toggle
                local protBg = Instance.new("Frame")
                protBg.Size = UDim2.new(0, 46, 0, 24)
                protBg.Position = UDim2.new(1, -56, 0, 2)
                protBg.BackgroundColor3 = isProtected and Theme.ProtectedOn or Theme.ProtectedOff
                protBg.BorderSizePixel = 0
                protBg.ZIndex = 10
                protBg.Parent = row
                Corner(protBg, UDim.new(1, 0))

                local protCircle = Instance.new("Frame")
                protCircle.Size = UDim2.new(0, 20, 0, 20)
                protCircle.Position = isProtected and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
                protCircle.BackgroundColor3 = Theme.Text
                protCircle.BorderSizePixel = 0
                protCircle.ZIndex = 11
                protCircle.Parent = protBg
                Corner(protCircle, UDim.new(1, 0))

                local protBtn = Instance.new("TextButton")
                protBtn.Size = UDim2.new(1, 0, 1, 0)
                protBtn.BackgroundTransparency = 1
                protBtn.Text = ""
                protBtn.ZIndex = 13
                protBtn.Parent = protBg

                AddConnection(protBtn.MouseButton1Click:Connect(function()
                    local newState = not getProtected(item.Name)
                    setProtected(item.Name, newState)
                    Tween(protBg, {BackgroundColor3 = newState and Theme.ProtectedOn or Theme.ProtectedOff}, 0.25)
                    Tween(protCircle, {Position = newState and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)}, 0.25, Enum.EasingStyle.Back)
                    Tween(protCircle, {Size = UDim2.new(0, 22, 0, 22)}, 0.08)
                    task.delay(0.08, function() Tween(protCircle, {Size = UDim2.new(0, 20, 0, 20)}, 0.12) end)
                    if onProtChanged then task.spawn(onProtChanged, item.Name, newState) end
                end))

                -- Mutation pills (if provided)
                local pillRefs = {}
                if hasPills then
                    local divider = Instance.new("Frame")
                    divider.Size = UDim2.new(1, -20, 0, 1)
                    divider.Position = UDim2.new(0, 10, 0, 33)
                    divider.BackgroundColor3 = Theme.Border
                    divider.BackgroundTransparency = 0.5
                    divider.BorderSizePixel = 0
                    divider.ZIndex = 9
                    divider.Parent = row

                    local mutIcon = Instance.new("TextLabel")
                    mutIcon.Size = UDim2.new(0, 20, 0, 30)
                    mutIcon.Position = UDim2.new(0, 10, 0, 36)
                    mutIcon.BackgroundTransparency = 1
                    mutIcon.Text = "🧬"
                    mutIcon.TextSize = 11
                    mutIcon.ZIndex = 9
                    mutIcon.Parent = row

                    local pillContainer = Instance.new("Frame")
                    pillContainer.Size = UDim2.new(1, -36, 0, 26)
                    pillContainer.Position = UDim2.new(0, 30, 0, 38)
                    pillContainer.BackgroundTransparency = 1
                    pillContainer.ZIndex = 9
                    pillContainer.Parent = row

                    local pillLayout2 = Instance.new("UIListLayout")
                    pillLayout2.FillDirection = Enum.FillDirection.Horizontal
                    pillLayout2.VerticalAlignment = Enum.VerticalAlignment.Center
                    pillLayout2.SortOrder = Enum.SortOrder.LayoutOrder
                    pillLayout2.Padding = UDim.new(0, 4)
                    pillLayout2.Parent = pillContainer

                    local currentMode = getMutMode(item.Name)

                    local function refreshPills(selectedKey)
                        for _, p in ipairs(pillRefs) do
                            local active = (p.Key == selectedKey)
                            Tween(p.Frame, {
                                BackgroundColor3 = active and p.Color or Theme.SliderBg,
                                BackgroundTransparency = active and 0.1 or 0,
                            }, 0.15)
                            Tween(p.Label, {TextColor3 = active and Color3.fromRGB(255,255,255) or Theme.TextDim}, 0.15)
                            Tween(p.Stroke, {Color = active and p.Color or Theme.Border, Transparency = active and 0.2 or 0.7}, 0.15)
                        end
                    end

                    for idx, def in ipairs(pillDefs) do
                        local isActive = (currentMode == def.Key)

                        local pill = Instance.new("Frame")
                        pill.Size = UDim2.new(0, 0, 0, 20)
                        pill.AutomaticSize = Enum.AutomaticSize.X
                        pill.BackgroundColor3 = isActive and def.Color or Theme.SliderBg
                        pill.BackgroundTransparency = isActive and 0.1 or 0
                        pill.BorderSizePixel = 0
                        pill.LayoutOrder = idx
                        pill.ZIndex = 10
                        pill.Parent = pillContainer
                        Corner(pill, UDim.new(0, 5))

                        local pillStroke = Stroke(pill, isActive and def.Color or Theme.Border, 1, isActive and 0.2 or 0.7)
                        Padding(pill, 0, 0, 6, 6)

                        local pillLabel = Instance.new("TextLabel")
                        pillLabel.Size = UDim2.new(0, 0, 1, 0)
                        pillLabel.AutomaticSize = Enum.AutomaticSize.X
                        pillLabel.BackgroundTransparency = 1
                        pillLabel.Text = def.Short
                        pillLabel.TextColor3 = isActive and Color3.fromRGB(255,255,255) or Theme.TextDim
                        pillLabel.TextSize = 10
                        pillLabel.Font = Theme.FontLight
                        pillLabel.ZIndex = 11
                        pillLabel.Parent = pill

                        local pillBtn = Instance.new("TextButton")
                        pillBtn.Size = UDim2.new(1, 0, 1, 0)
                        pillBtn.BackgroundTransparency = 1
                        pillBtn.Text = ""
                        pillBtn.ZIndex = 12
                        pillBtn.Parent = pill

                        table.insert(pillRefs, {Key = def.Key, Color = def.Color, Frame = pill, Label = pillLabel, Stroke = pillStroke})

                        AddConnection(pillBtn.MouseEnter:Connect(function()
                            if getMutMode(item.Name) ~= def.Key then Tween(pill, {BackgroundColor3 = Theme.Hover}, 0.1) end
                        end))
                        AddConnection(pillBtn.MouseLeave:Connect(function()
                            if getMutMode(item.Name) ~= def.Key then Tween(pill, {BackgroundColor3 = Theme.SliderBg}, 0.1) end
                        end))
                        AddConnection(pillBtn.MouseButton1Click:Connect(function()
                            local cur = getMutMode(item.Name)
                            local newKey = (cur == def.Key) and "NONE" or def.Key
                            setMutMode(item.Name, newKey)
                            refreshPills(newKey)
                            Tween(pill, {Size = UDim2.new(0, 0, 0, 22)}, 0.07)
                            task.delay(0.07, function() Tween(pill, {Size = UDim2.new(0, 0, 0, 20)}, 0.1) end)
                            if onMutChanged then task.spawn(onMutChanged, item.Name, newKey) end
                        end))
                    end
                end

                -- Row hover
                AddConnection(row.MouseEnter:Connect(function()
                    Tween(row, {BackgroundColor3 = Theme.Hover}, 0.15)
                    Tween(hbar, {BackgroundTransparency = 0.2}, 0.15)
                end))
                AddConnection(row.MouseLeave:Connect(function()
                    Tween(row, {BackgroundColor3 = baseColor}, 0.15)
                    Tween(hbar, {BackgroundTransparency = 1}, 0.15)
                end))

                rowElements[item.Name] = {Frame = row, OriginalColor = baseColor, PillRefs = pillRefs}
            end

            updateCount()

            -- Search filter
            AddConnection(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                local filter = searchBox.Text:lower()
                local visOrder = 1
                for _, item in ipairs(items) do
                    local rd = rowElements[item.Name]
                    if not rd then continue end
                    local visible = filter == ""
                        or item.Name:lower():find(filter, 1, true)
                        or (item.Rarity and item.Rarity:lower():find(filter, 1, true))
                    rd.Frame.Visible = visible
                    if visible then
                        rd.Frame.LayoutOrder = visOrder
                        local nc = (visOrder % 2 == 0) and Theme.Row or Theme.RowAlt
                        rd.Frame.BackgroundColor3 = nc
                        rd.OriginalColor = nc
                        visOrder = visOrder + 1
                    end
                end
                updateCount()
            end))

            return {
                GetRows = function() return rowElements end,
                Refresh = function()
                    for _, item in ipairs(items) do
                        local rd = rowElements[item.Name]
                        if not rd then continue end
                        local isProt = getProtected(item.Name)
                        -- update toggle visual
                    end
                end,
            }
        end

        -- INTERVAL TOGGLE (Toggle + TextBox for seconds)
        function Tab:AddIntervalToggle(labelText, default, callback, intervalDefault)
            local order = NextOrder()
            
            -- State
            local savedState = StateStore[labelText]
            local state = (savedState ~= nil) and savedState or (default or false)
            StateStore[labelText] = state
            
            local intervalKey = labelText .. "_interval"
            local savedInterval = StateStore[intervalKey]
            local intervalValue = math.max(1, math.floor(tonumber(tostring(savedInterval ~= nil and savedInterval or (intervalDefault or 1))) or 1))
            StateStore[intervalKey] = intervalValue

            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, Theme.RowHeight)
            row.BackgroundColor3 = RowColor(order)
            row.BorderSizePixel = 0
            row.LayoutOrder = order
            row.ZIndex = 6
            row.ClipsDescendants = true
            row.Parent = page
            Corner(row, Theme.CornerRadius)
            local ab = HoverAccent(row)

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -180, 1, 0)
            lbl.Position = UDim2.new(0, 18, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = labelText
            lbl.TextColor3 = Theme.Text
            lbl.TextSize = 14
            lbl.Font = Theme.FontLight
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.ZIndex = 7
            lbl.Parent = row

            -- Interval Input Box
            local ibg = Instance.new("Frame")
            ibg.Size = UDim2.new(0, 50, 0, 26)
            ibg.Position = UDim2.new(1, -115, 0.5, -13)
            ibg.BackgroundColor3 = Theme.InputBg
            ibg.BorderSizePixel = 0
            ibg.ZIndex = 8
            ibg.Parent = row
            Corner(ibg, UDim.new(0, 6))
            local gs = Stroke(ibg, Theme.Accent, 1.5, 1)

            local input = Instance.new("TextBox")
            input.Size = UDim2.new(1, 0, 1, 0)
            input.BackgroundTransparency = 1
            input.Text = tostring(intervalValue)
            input.PlaceholderText = "sec"
            input.PlaceholderColor3 = Theme.TextDim
            input.TextColor3 = Theme.Text
            input.TextSize = 12
            input.Font = Theme.FontLight
            input.ClearTextOnFocus = true
            input.TextXAlignment = Enum.TextXAlignment.Center
            input.ZIndex = 9
            input.Parent = ibg

            -- Toggle Switch
            local tbg = Instance.new("Frame")
            tbg.Size = UDim2.new(0, 46, 0, 24)
            tbg.Position = UDim2.new(1, -60, 0.5, -12)
            tbg.BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff
            tbg.BorderSizePixel = 0
            tbg.ZIndex = 8
            tbg.Parent = row
            Corner(tbg, UDim.new(1, 0))

            local circle = Instance.new("Frame")
            circle.Size = UDim2.new(0, 20, 0, 20)
            circle.Position = state and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
            circle.BackgroundColor3 = Theme.Text
            circle.BorderSizePixel = 0
            circle.ZIndex = 9
            circle.Parent = tbg
            Corner(circle, UDim.new(1, 0))

            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 1, 0)
            btn.BackgroundTransparency = 1
            btn.Text = ""
            btn.ZIndex = 10
            btn.Parent = tbg

            -- Functions
            local function StartLoop()
                if state and callback then
                    -- Force intervalValue to always be a clean number
                    local safeInterval = math.max(1, math.floor(tonumber(tostring(intervalValue)) or 1))
                    ThreadManager:Start(labelText, safeInterval, function()
                        callback()
                    end)
                end
            end

            AddConnection(input.FocusLost:Connect(function()
                local val = math.floor(tonumber(tostring(input.Text)) or 0)
                if val and val >= 1 then
                    intervalValue = val
                    ConfigManager:Set(intervalKey, val)
                    input.Text = tostring(val)
                    if state then StartLoop() end
                else
                    input.Text = tostring(intervalValue)
                end
                Tween(gs, {Transparency = 1}, 0.2)
            end))
            
            AddConnection(input.Focused:Connect(function() Tween(gs, {Transparency = 0.4}, 0.2) end))

            AddConnection(btn.MouseButton1Click:Connect(function()
                state = not state
                ConfigManager:Set(labelText, state)
                Tween(tbg, {BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff}, 0.2)
                Tween(circle, {Position = state and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)}, 0.2, Enum.EasingStyle.Back)
                if state then StartLoop() else ThreadManager:Stop(labelText) end
            end))

            if state then task.defer(StartLoop) end
            SetupHover(row, RowColor(order), ab)
            
            return {
                Set = function(_, v) 
                    state = v
                    ConfigManager:Set(labelText, v)
                    Tween(tbg, {BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff}, 0.2)
                    Tween(circle, {Position = state and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)}, 0.2)
                    if state then StartLoop() else ThreadManager:Stop(labelText) end
                end,
                Get = function() return state end
            }
        end

        -- TOGGLE
        function Tab:AddToggle(labelText,default,intervalOrCallback,callbackOrNil)
            local order=NextOrder(); local interval,callback
            if type(intervalOrCallback)=="function" then interval=nil; callback=intervalOrCallback
            else interval=intervalOrCallback; callback=callbackOrNil end

            local saved=StateStore[labelText]
            local state=(saved~=nil) and saved or (default or false)
            StateStore[labelText]=state
            if interval and callback then ConfigManager._toggleMeta[labelText]={interval=interval,callback=callback} end

            local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,Theme.RowHeight)
            row.BackgroundColor3=RowColor(order); row.BorderSizePixel=0; row.LayoutOrder=order
            row.ZIndex=6; row.ClipsDescendants=true; row.Parent=page; Corner(row,Theme.CornerRadius)
            local ab=HoverAccent(row)

            local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-80,1,0); lbl.Position=UDim2.new(0,18,0,0)
            lbl.BackgroundTransparency=1; lbl.Text=labelText; lbl.TextColor3=Theme.Text; lbl.TextSize=14
            lbl.Font=Theme.FontLight; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=7; lbl.Parent=row

            local tbg=Instance.new("Frame"); tbg.Size=UDim2.new(0,46,0,24); tbg.Position=UDim2.new(1,-60,0.5,-12)
            tbg.BackgroundColor3=state and Theme.ToggleOn or Theme.ToggleOff; tbg.BorderSizePixel=0
            tbg.ZIndex=8; tbg.Parent=row; Corner(tbg,UDim.new(1,0))

            local circle=Instance.new("Frame"); circle.Size=UDim2.new(0,20,0,20)
            circle.Position=state and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)
            circle.BackgroundColor3=Theme.Text; circle.BorderSizePixel=0; circle.ZIndex=9; circle.Parent=tbg
            Corner(circle,UDim.new(1,0)); Stroke(circle,Theme.Shadow,1,0.7)

            local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1
            btn.Text=""; btn.ZIndex=10; btn.Parent=tbg

            local function UV(v) state=v; tbg.BackgroundColor3=v and Theme.ToggleOn or Theme.ToggleOff
                circle.Position=v and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10) end

            ConfigManager:RegisterUpdater(labelText,function(v) if type(v)=="boolean" then UV(v) end end)

            local function SS(ns)
                state=ns; ConfigManager:Set(labelText,state)
                Tween(tbg,{BackgroundColor3=state and Theme.ToggleOn or Theme.ToggleOff},0.25)
                Tween(circle,{Position=state and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)},0.25,Enum.EasingStyle.Back)
                Tween(circle,{Size=UDim2.new(0,22,0,22)},0.08)
                task.delay(0.08,function() Tween(circle,{Size=UDim2.new(0,20,0,20)},0.12) end)
                if interval and callback then
                    if state then ThreadManager:Start(labelText,interval,callback) else ThreadManager:Stop(labelText) end
                elseif callback then task.spawn(callback,state) end
            end

            AddConnection(btn.MouseButton1Click:Connect(function() SS(not state) end))
            SetupHover(row,RowColor(order),ab)
            if state then
                if interval and callback then task.defer(function() ThreadManager:Start(labelText,interval,callback) end)
                elseif callback then task.defer(callback,state) end
            end
            return {Set=function(_,v) SS(v) end, Get=function() return state end}
        end

        -- SLIDER
        function Tab:AddSlider(labelText,min,max,default,callback)
            local order=NextOrder()
            local saved=StateStore[labelText]
            local value=(saved~=nil and type(saved)=="number") and math.clamp(saved,min,max) or math.clamp(default or min,min,max)
            StateStore[labelText]=value

            local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,Theme.RowHeight+4)
            row.BackgroundColor3=RowColor(order); row.BorderSizePixel=0; row.LayoutOrder=order
            row.ZIndex=6; row.ClipsDescendants=true; row.Parent=page; Corner(row,Theme.CornerRadius)
            local ab=HoverAccent(row)

            local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0,170,1,0); lbl.Position=UDim2.new(0,18,0,0)
            lbl.BackgroundTransparency=1; lbl.Text=labelText; lbl.TextColor3=Theme.Text; lbl.TextSize=14
            lbl.Font=Theme.FontLight; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=7; lbl.Parent=row

            local vb=Instance.new("Frame"); vb.Size=UDim2.new(0,42,0,22); vb.Position=UDim2.new(1,-158,0.5,-11)
            vb.BackgroundColor3=Theme.Accent; vb.BackgroundTransparency=0.85; vb.BorderSizePixel=0
            vb.ZIndex=7; vb.Parent=row; Corner(vb,UDim.new(0,5))

            local vl=Instance.new("TextLabel"); vl.Size=UDim2.new(1,0,1,0); vl.BackgroundTransparency=1
            vl.Text=tostring(math.floor(value)); vl.TextColor3=Theme.Accent; vl.TextSize=13; vl.Font=Theme.Font
            vl.ZIndex=8; vl.Parent=vb

            local track=Instance.new("Frame"); track.Size=UDim2.new(0,100,0,6); track.Position=UDim2.new(1,-112,0.5,-3)
            track.BackgroundColor3=Theme.SliderBg; track.BorderSizePixel=0; track.ZIndex=8; track.Parent=row
            Corner(track,UDim.new(1,0))

            local pct=(value-min)/math.max(max-min,1)
            local fill=Instance.new("Frame"); fill.Size=UDim2.new(pct,0,1,0); fill.BackgroundColor3=Theme.SliderFill
            fill.BorderSizePixel=0; fill.ZIndex=9; fill.Parent=track; Corner(fill,UDim.new(1,0))

            local knob=Instance.new("Frame"); knob.Size=UDim2.new(0,16,0,16); knob.Position=UDim2.new(pct,-8,0.5,-8)
            knob.BackgroundColor3=Theme.Text; knob.BorderSizePixel=0; knob.ZIndex=10; knob.Parent=track
            Corner(knob,UDim.new(1,0)); Stroke(knob,Theme.Shadow,1,0.75)

            local sliding=false
            local hit=Instance.new("TextButton"); hit.Size=UDim2.new(1,14,1,18); hit.Position=UDim2.new(0,-7,0,-9)
            hit.BackgroundTransparency=1; hit.Text=""; hit.ZIndex=11; hit.Parent=track

            local function UV(v) local p=(v-min)/math.max(max-min,1); vl.Text=tostring(math.floor(v))
                fill.Size=UDim2.new(p,0,1,0); knob.Position=UDim2.new(p,-8,0.5,-8) end

            ConfigManager:RegisterUpdater(labelText,function(v) if type(v)=="number" then v=math.clamp(v,min,max); value=v; UV(v) end end)

            local function PI(input)
                local x=math.clamp((input.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
                local v=math.floor(min+(max-min)*x); value=v; ConfigManager:Set(labelText,v); UV(v)
                if callback then task.spawn(callback,v) end
            end

            AddConnection(hit.InputBegan:Connect(function(i)
                if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliding=true; PI(i) end
            end))
            AddConnection(hit.InputEnded:Connect(function(i)
                if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliding=false end
            end))
            AddConnection(UserInputService.InputChanged:Connect(function(i)
                if sliding and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then PI(i) end
            end))
            SetupHover(row,RowColor(order),ab)
            return {Set=function(_,v) v=math.clamp(v,min,max); value=v; ConfigManager:Set(labelText,v); UV(v) end, Get=function() return value end}
        end

        -- BUTTON
        function Tab:AddButton(labelText,callback)
            local order=NextOrder()
            local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,Theme.RowHeight)
            row.BackgroundColor3=RowColor(order); row.BorderSizePixel=0; row.LayoutOrder=order
            row.ZIndex=6; row.ClipsDescendants=true; row.Parent=page; Corner(row,Theme.CornerRadius)
            local ab=HoverAccent(row)

            local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-130,1,0); lbl.Position=UDim2.new(0,18,0,0)
            lbl.BackgroundTransparency=1; lbl.Text=labelText; lbl.TextColor3=Theme.Text; lbl.TextSize=14
            lbl.Font=Theme.FontLight; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=7; lbl.Parent=row

            local bf=Instance.new("Frame"); bf.Size=UDim2.new(0,100,0,32); bf.Position=UDim2.new(1,-114,0.5,-16)
            bf.BackgroundTransparency=1; bf.ZIndex=7; bf.Parent=row

            local bs=Instance.new("Frame"); bs.Size=UDim2.new(1,2,1,2); bs.Position=UDim2.new(0,-1,0,2)
            bs.BackgroundColor3=Theme.Shadow; bs.BackgroundTransparency=0.82; bs.BorderSizePixel=0
            bs.ZIndex=7; bs.Parent=bf; Corner(bs,Theme.CornerRadius)

            local button=Instance.new("TextButton"); button.Size=UDim2.new(1,-2,1,-2); button.Position=UDim2.new(0,1,0,0)
            button.BackgroundColor3=Theme.Accent; button.Text="Execute"; button.TextColor3=Theme.Text
            button.TextSize=13; button.Font=Theme.Font; button.BorderSizePixel=0; button.AutoButtonColor=false
            button.ZIndex=8; button.Parent=bf; Corner(button,Theme.CornerRadius)

            local gs=Stroke(button,Theme.Accent,1.5,1)
            AddConnection(button.MouseEnter:Connect(function() Tween(button,{BackgroundColor3=Theme.AccentLight},0.15); Tween(gs,{Transparency=0.5},0.2) end))
            AddConnection(button.MouseLeave:Connect(function() Tween(button,{BackgroundColor3=Theme.Accent},0.15); Tween(gs,{Transparency=1},0.2) end))
            AddConnection(button.MouseButton1Click:Connect(function()
                Tween(button,{Size=UDim2.new(1,-6,1,-4)},0.06)
                task.delay(0.06,function() Tween(button,{Size=UDim2.new(1,-2,1,-2)},0.1,Enum.EasingStyle.Back) end)
                if callback then task.spawn(callback) end
            end))
            SetupHover(row,RowColor(order),ab)
        end

        -- STATUS BUTTON
        function Tab:AddStatusButton(labelText,callback)
            local order=NextOrder()
            local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,Theme.RowHeight)
            row.BackgroundColor3=RowColor(order); row.BorderSizePixel=0; row.LayoutOrder=order
            row.ZIndex=6; row.ClipsDescendants=true; row.Parent=page; Corner(row,Theme.CornerRadius)
            local ab=HoverAccent(row)

            local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-130,1,0); lbl.Position=UDim2.new(0,18,0,0)
            lbl.BackgroundTransparency=1; lbl.Text=labelText; lbl.TextColor3=Theme.Text; lbl.TextSize=14
            lbl.Font=Theme.FontLight; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=7; lbl.Parent=row

            local bf=Instance.new("Frame"); bf.Size=UDim2.new(0,100,0,32); bf.Position=UDim2.new(1,-114,0.5,-16)
            bf.BackgroundTransparency=1; bf.ZIndex=7; bf.Parent=row
            local bs=Instance.new("Frame"); bs.Size=UDim2.new(1,2,1,2); bs.Position=UDim2.new(0,-1,0,2)
            bs.BackgroundColor3=Theme.Shadow; bs.BackgroundTransparency=0.82; bs.BorderSizePixel=0
            bs.ZIndex=7; bs.Parent=bf; Corner(bs,Theme.CornerRadius)

            local button=Instance.new("TextButton"); button.Size=UDim2.new(1,-2,1,-2); button.Position=UDim2.new(0,1,0,0)
            button.BackgroundColor3=Theme.Accent; button.Text="Execute"; button.TextColor3=Theme.Text
            button.TextSize=13; button.Font=Theme.Font; button.BorderSizePixel=0; button.AutoButtonColor=false
            button.ZIndex=8; button.Parent=bf; Corner(button,Theme.CornerRadius)

            local gs=Stroke(button,Theme.Accent,1.5,1); local busy=false
            local function SetStatus(st,msg)
                if st=="loading" then button.Text="..."; Tween(button,{BackgroundColor3=Color3.fromRGB(100,100,100)},0.15)
                elseif st=="success" then button.Text="✅ "..(msg or "Done"); Tween(button,{BackgroundColor3=Theme.NotifSuccess},0.2)
                    task.delay(1.5,function() if button and button.Parent then button.Text="Execute"; Tween(button,{BackgroundColor3=Theme.Accent},0.2); busy=false end end)
                elseif st=="error" then button.Text="❌ "..(msg or "Failed"); Tween(button,{BackgroundColor3=Theme.NotifError},0.2)
                    task.delay(1.5,function() if button and button.Parent then button.Text="Execute"; Tween(button,{BackgroundColor3=Theme.Accent},0.2); busy=false end end)
                else button.Text=msg or "Execute"; Tween(button,{BackgroundColor3=Theme.Accent},0.2); busy=false end
            end
            AddConnection(button.MouseEnter:Connect(function() if not busy then Tween(button,{BackgroundColor3=Theme.AccentLight},0.15); Tween(gs,{Transparency=0.5},0.2) end end))
            AddConnection(button.MouseLeave:Connect(function() if not busy then Tween(button,{BackgroundColor3=Theme.Accent},0.15); Tween(gs,{Transparency=1},0.2) end end))
            AddConnection(button.MouseButton1Click:Connect(function()
                if busy then return end; busy=true
                Tween(button,{Size=UDim2.new(1,-6,1,-4)},0.06)
                task.delay(0.06,function() Tween(button,{Size=UDim2.new(1,-2,1,-2)},0.1,Enum.EasingStyle.Back) end)
                if callback then task.spawn(callback,SetStatus) end
            end))
            SetupHover(row,RowColor(order),ab)
        end

        -- INPUT
        function Tab:AddInput(labelText,placeholder,callback)
            local order=NextOrder()
            local saved=StateStore[labelText]; local ct=(saved~=nil and type(saved)=="string") and saved or ""
            StateStore[labelText]=ct

            local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,Theme.RowHeight)
            row.BackgroundColor3=RowColor(order); row.BorderSizePixel=0; row.LayoutOrder=order
            row.ZIndex=6; row.ClipsDescendants=true; row.Parent=page; Corner(row,Theme.CornerRadius)
            local ab=HoverAccent(row)

            local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0,140,1,0); lbl.Position=UDim2.new(0,18,0,0)
            lbl.BackgroundTransparency=1; lbl.Text=labelText; lbl.TextColor3=Theme.Text; lbl.TextSize=14
            lbl.Font=Theme.FontLight; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=7; lbl.Parent=row

            local ibg=Instance.new("Frame"); ibg.Size=UDim2.new(0,180,0,30); ibg.Position=UDim2.new(1,-196,0.5,-15)
            ibg.BackgroundColor3=Theme.InputBg; ibg.BorderSizePixel=0; ibg.ZIndex=8; ibg.Parent=row; Corner(ibg,UDim.new(0,6))
            local gs=Stroke(ibg,Theme.Accent,1.5,1)

            local input=Instance.new("TextBox"); input.Size=UDim2.new(1,-16,1,0); input.Position=UDim2.new(0,8,0,0)
            input.BackgroundTransparency=1; input.Text=ct; input.PlaceholderText=placeholder or "Type here..."
            input.PlaceholderColor3=Theme.TextDim; input.TextColor3=Theme.Text; input.TextSize=13
            input.Font=Theme.FontLight; input.ClearTextOnFocus=false; input.TextXAlignment=Enum.TextXAlignment.Left
            input.ZIndex=9; input.Parent=ibg

            ConfigManager:RegisterUpdater(labelText,function(v) if type(v)=="string" then input.Text=v end end)
            AddConnection(input.Focused:Connect(function() Tween(gs,{Transparency=0.4},0.2) end))
            AddConnection(input.FocusLost:Connect(function(ep) Tween(gs,{Transparency=1},0.2); ConfigManager:Set(labelText,input.Text)
                if callback then task.spawn(callback,input.Text,ep) end end))
            SetupHover(row,RowColor(order),ab)
            return {Set=function(_,v) input.Text=v; ConfigManager:Set(labelText,v) end, Get=function() return input.Text end}
        end

        -- NUMBER INPUT
        function Tab:AddNumberInput(labelText,default,callback)
            local order=NextOrder()
            local saved=StateStore[labelText]
            local value=(saved~=nil and type(saved)=="number") and saved or (default or 0)
            StateStore[labelText]=value

            local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,Theme.RowHeight)
            row.BackgroundColor3=RowColor(order); row.BorderSizePixel=0; row.LayoutOrder=order
            row.ZIndex=6; row.ClipsDescendants=true; row.Parent=page; Corner(row,Theme.CornerRadius)
            local ab=HoverAccent(row)

            local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0,140,1,0); lbl.Position=UDim2.new(0,18,0,0)
            lbl.BackgroundTransparency=1; lbl.Text=labelText; lbl.TextColor3=Theme.Text; lbl.TextSize=14
            lbl.Font=Theme.FontLight; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=7; lbl.Parent=row

            local ibg=Instance.new("Frame"); ibg.Size=UDim2.new(0,120,0,30); ibg.Position=UDim2.new(1,-136,0.5,-15)
            ibg.BackgroundColor3=Theme.InputBg; ibg.BorderSizePixel=0; ibg.ZIndex=8; ibg.Parent=row; Corner(ibg,UDim.new(0,6))
            local gs=Stroke(ibg,Theme.Accent,1.5,1)

            local input=Instance.new("TextBox"); input.Size=UDim2.new(1,-16,1,0); input.Position=UDim2.new(0,8,0,0)
            input.BackgroundTransparency=1; input.Text=value>0 and GluttonyUI.FormatNumber(value) or "0"
            input.PlaceholderText="e.g. 5M"; input.PlaceholderColor3=Theme.TextDim; input.TextColor3=Theme.Text
            input.TextSize=13; input.Font=Theme.FontLight; input.ClearTextOnFocus=false
            input.TextXAlignment=Enum.TextXAlignment.Center; input.ZIndex=9; input.Parent=ibg

            ConfigManager:RegisterUpdater(labelText,function(v) if type(v)=="number" then value=v; input.Text=v>0 and GluttonyUI.FormatNumber(v) or "0" end end)
            AddConnection(input.Focused:Connect(function() Tween(gs,{Transparency=0.4},0.2) end))
            AddConnection(input.FocusLost:Connect(function()
                Tween(gs,{Transparency=1},0.2); local p=GluttonyUI.ParseNumber(input.Text)
                value=p; ConfigManager:Set(labelText,p); input.Text=p>0 and GluttonyUI.FormatNumber(p) or "0"
                if callback then task.spawn(callback,p) end
            end))
            SetupHover(row,RowColor(order),ab)
            return {Set=function(_,v) value=v; ConfigManager:Set(labelText,v); input.Text=v>0 and GluttonyUI.FormatNumber(v) or "0" end, Get=function() return value end}
        end

        -- THRESHOLD ROW
        function Tab:AddThresholdRow(labelText,opts)
            opts=opts or {}; local order=NextOrder()
            local threshDefault=opts.Default or 0; local interval=opts.Interval or 1
            local buttonText=opts.ButtonText or "Sell"; local onLoop=opts.OnLoop; local onButton=opts.OnButton
            local toggleKey=labelText.."_enabled"; local threshKey=labelText.."_threshold"

            local savedT=StateStore[toggleKey]; local toggleState=(savedT~=nil) and savedT or false; StateStore[toggleKey]=toggleState
            local savedTh=StateStore[threshKey]; local threshValue=(savedTh~=nil and type(savedTh)=="number") and savedTh or threshDefault; StateStore[threshKey]=threshValue

            local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,56); row.BackgroundColor3=RowColor(order)
            row.BorderSizePixel=0; row.LayoutOrder=order; row.ZIndex=6; row.ClipsDescendants=true
            row.Parent=page; Corner(row,Theme.CornerRadius); Stroke(row,Theme.Border,1,0.5)
            local ab=HoverAccent(row)

            local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0,90,1,0); lbl.Position=UDim2.new(0,18,0,0)
            lbl.BackgroundTransparency=1; lbl.Text=labelText; lbl.TextColor3=Theme.Text; lbl.TextSize=14
            lbl.Font=Theme.Font; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=7; lbl.Parent=row

            local tbg=Instance.new("Frame"); tbg.Size=UDim2.new(0,42,0,22); tbg.Position=UDim2.new(0,110,0.5,-11)
            tbg.BackgroundColor3=toggleState and Theme.ToggleOn or Theme.ToggleOff; tbg.BorderSizePixel=0
            tbg.ZIndex=8; tbg.Parent=row; Corner(tbg,UDim.new(1,0))

            local tc=Instance.new("Frame"); tc.Size=UDim2.new(0,18,0,18)
            tc.Position=toggleState and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9)
            tc.BackgroundColor3=Theme.Text; tc.BorderSizePixel=0; tc.ZIndex=9; tc.Parent=tbg
            Corner(tc,UDim.new(1,0)); Stroke(tc,Theme.Shadow,1,0.7)

            local tbtn=Instance.new("TextButton"); tbtn.Size=UDim2.new(1,0,1,0); tbtn.BackgroundTransparency=1
            tbtn.Text=""; tbtn.ZIndex=10; tbtn.Parent=tbg

            local thBg=Instance.new("Frame"); thBg.Size=UDim2.new(0,80,0,30); thBg.Position=UDim2.new(0,164,0.5,-15)
            thBg.BackgroundColor3=Theme.InputBg; thBg.BorderSizePixel=0; thBg.ZIndex=8; thBg.Parent=row; Corner(thBg,UDim.new(0,6))
            local thGlow=Stroke(thBg,Theme.Accent,1.5,1)

            local thInput=Instance.new("TextBox"); thInput.Size=UDim2.new(1,-12,1,0); thInput.Position=UDim2.new(0,6,0,0)
            thInput.BackgroundTransparency=1; thInput.Text=threshValue>0 and GluttonyUI.FormatNumber(threshValue) or "0"
            thInput.PlaceholderText="e.g. 5M"; thInput.PlaceholderColor3=Theme.TextDim; thInput.TextColor3=Theme.Text
            thInput.TextSize=13; thInput.Font=Theme.FontLight; thInput.ClearTextOnFocus=false
            thInput.TextXAlignment=Enum.TextXAlignment.Center; thInput.ZIndex=9; thInput.Parent=thBg

            AddConnection(thInput.Focused:Connect(function() Tween(thGlow,{Transparency=0.4},0.2) end))
            AddConnection(thInput.FocusLost:Connect(function()
                Tween(thGlow,{Transparency=1},0.2); local p=GluttonyUI.ParseNumber(thInput.Text)
                threshValue=p; ConfigManager:Set(threshKey,p); thInput.Text=p>0 and GluttonyUI.FormatNumber(p) or "0"
                if toggleState and onLoop then ThreadManager:Start(toggleKey,interval,function() onLoop(threshValue) end) end
            end))

            local af=Instance.new("Frame"); af.Size=UDim2.new(0,72,0,32); af.Position=UDim2.new(1,-86,0.5,-16)
            af.BackgroundTransparency=1; af.ZIndex=7; af.Parent=row
            local ash=Instance.new("Frame"); ash.Size=UDim2.new(1,2,1,2); ash.Position=UDim2.new(0,-1,0,2)
            ash.BackgroundColor3=Theme.Shadow; ash.BackgroundTransparency=0.82; ash.BorderSizePixel=0
            ash.ZIndex=7; ash.Parent=af; Corner(ash,UDim.new(0,6))

            local abtn=Instance.new("TextButton"); abtn.Size=UDim2.new(1,-2,1,-2); abtn.Position=UDim2.new(0,1,0,0)
            abtn.BackgroundColor3=Color3.fromRGB(200,30,30); abtn.Text=buttonText; abtn.TextColor3=Theme.Text
            abtn.TextSize=13; abtn.Font=Theme.Font; abtn.BorderSizePixel=0; abtn.AutoButtonColor=false
            abtn.ZIndex=8; abtn.Parent=af; Corner(abtn,UDim.new(0,6))

            local aglow=Stroke(abtn,Color3.fromRGB(200,30,30),1.5,0.6); local abusy=false
            local function SetAS(st,msg)
                if st=="loading" then abtn.Text="..."; Tween(abtn,{BackgroundColor3=Color3.fromRGB(100,100,100)},0.15)
                elseif st=="success" then abtn.Text="✅ "..(msg or ""); Tween(abtn,{BackgroundColor3=Theme.NotifSuccess},0.2)
                    task.delay(1.5,function() if abtn and abtn.Parent then abtn.Text=buttonText; Tween(abtn,{BackgroundColor3=Color3.fromRGB(200,30,30)},0.2); abusy=false end end)
                elseif st=="error" then abtn.Text="❌"; Tween(abtn,{BackgroundColor3=Theme.NotifError},0.2)
                    task.delay(1.5,function() if abtn and abtn.Parent then abtn.Text=buttonText; Tween(abtn,{BackgroundColor3=Color3.fromRGB(200,30,30)},0.2); abusy=false end end)
                else abtn.Text=buttonText; Tween(abtn,{BackgroundColor3=Color3.fromRGB(200,30,30)},0.2); abusy=false end
            end

            AddConnection(abtn.MouseEnter:Connect(function() if not abusy then Tween(abtn,{BackgroundColor3=Color3.fromRGB(220,50,50)},0.15) end end))
            AddConnection(abtn.MouseLeave:Connect(function() if not abusy then Tween(abtn,{BackgroundColor3=Color3.fromRGB(200,30,30)},0.15) end end))
            AddConnection(abtn.MouseButton1Click:Connect(function()
                if abusy then return end; abusy=true
                Tween(abtn,{Size=UDim2.new(1,-6,1,-4)},0.06)
                task.delay(0.06,function() Tween(abtn,{Size=UDim2.new(1,-2,1,-2)},0.1,Enum.EasingStyle.Back) end)
                if onButton then task.spawn(onButton,threshValue,SetAS) end
            end))

            AddConnection(tbtn.MouseButton1Click:Connect(function()
                toggleState=not toggleState; ConfigManager:Set(toggleKey,toggleState)
                Tween(tbg,{BackgroundColor3=toggleState and Theme.ToggleOn or Theme.ToggleOff},0.25)
                Tween(tc,{Position=toggleState and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9)},0.25,Enum.EasingStyle.Back)
                Tween(tc,{Size=UDim2.new(0,20,0,20)},0.08)
                task.delay(0.08,function() Tween(tc,{Size=UDim2.new(0,18,0,18)},0.12) end)
                if toggleState then
                    if threshValue<=0 then toggleState=false; ConfigManager:Set(toggleKey,false)
                        Tween(tbg,{BackgroundColor3=Theme.ToggleOff},0.2); Tween(tc,{Position=UDim2.new(0,2,0.5,-9)},0.2); return end
                    if onLoop then ThreadManager:Start(toggleKey,interval,function() onLoop(threshValue) end) end
                else ThreadManager:Stop(toggleKey) end
            end))
            SetupHover(row,RowColor(order),ab)
            if toggleState and threshValue>0 and onLoop then
                task.defer(function() ThreadManager:Start(toggleKey,interval,function() onLoop(threshValue) end) end)
            end
            return {GetThreshold=function() return threshValue end, GetToggle=function() return toggleState end,
                SetThreshold=function(_,v) threshValue=v; ConfigManager:Set(threshKey,v); thInput.Text=v>0 and GluttonyUI.FormatNumber(v) or "0" end}
        end

        -- DROPDOWN (with flip)
        function Tab:AddDropdown(labelText,options,callback)
            local order=NextOrder(); local isOpen=false
            local saved=StateStore[labelText]; local selected=nil
            if saved~=nil and type(saved)=="string" then for _,o in ipairs(options) do if o==saved then selected=saved; break end end end
            StateStore[labelText]=selected

            local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,Theme.RowHeight)
            row.BackgroundColor3=RowColor(order); row.BorderSizePixel=0; row.LayoutOrder=order
            row.ZIndex=10; row.ClipsDescendants=false; row.Parent=page; Corner(row,Theme.CornerRadius)
            local ab=HoverAccent(row)

            local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0,140,1,0); lbl.Position=UDim2.new(0,18,0,0)
            lbl.BackgroundTransparency=1; lbl.Text=labelText; lbl.TextColor3=Theme.Text; lbl.TextSize=14
            lbl.Font=Theme.FontLight; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=11; lbl.Parent=row

            local ddBtn=Instance.new("Frame"); ddBtn.Size=UDim2.new(0,180,0,30); ddBtn.Position=UDim2.new(1,-196,0.5,-15)
            ddBtn.BackgroundColor3=Theme.InputBg; ddBtn.BorderSizePixel=0; ddBtn.ZIndex=12; ddBtn.Parent=row
            Corner(ddBtn,UDim.new(0,6)); Stroke(ddBtn,Theme.Border,1,0.5)

            local ddLabel=Instance.new("TextLabel"); ddLabel.Size=UDim2.new(1,-32,1,0); ddLabel.Position=UDim2.new(0,10,0,0)
            ddLabel.BackgroundTransparency=1; ddLabel.Text=selected or "Select..."
            ddLabel.TextColor3=selected and Theme.Text or Theme.TextDim; ddLabel.TextSize=13
            ddLabel.Font=Theme.FontLight; ddLabel.TextXAlignment=Enum.TextXAlignment.Left; ddLabel.ZIndex=13; ddLabel.Parent=ddBtn

            local af=Instance.new("Frame"); af.Size=UDim2.new(0,12,0,12); af.Position=UDim2.new(1,-22,0.5,-6)
            af.BackgroundTransparency=1; af.ZIndex=13; af.Parent=ddBtn
            local al=Instance.new("Frame"); al.Size=UDim2.new(0,7,0,2); al.Position=UDim2.new(0,0,0.5,-1)
            al.AnchorPoint=Vector2.new(0,0.5); al.BackgroundColor3=Theme.Accent; al.Rotation=35
            al.BorderSizePixel=0; al.Parent=af; Corner(al,UDim.new(1,0))
            local ar=Instance.new("Frame"); ar.Size=UDim2.new(0,7,0,2); ar.Position=UDim2.new(1,0,0.5,-1)
            ar.AnchorPoint=Vector2.new(1,0.5); ar.BackgroundColor3=Theme.Accent; ar.Rotation=-35
            ar.BorderSizePixel=0; ar.Parent=af; Corner(ar,UDim.new(1,0))

            local ddClick=Instance.new("TextButton"); ddClick.Size=UDim2.new(1,0,1,0); ddClick.BackgroundTransparency=1
            ddClick.Text=""; ddClick.ZIndex=14; ddClick.Parent=ddBtn

            local panel=Instance.new("ScrollingFrame"); panel.Size=UDim2.new(0,0,0,0)
            panel.BackgroundColor3=Theme.DropdownBg; panel.BorderSizePixel=0; panel.ClipsDescendants=true
            panel.ScrollBarThickness=3; panel.ScrollBarImageColor3=Theme.Accent; panel.ZIndex=500
            panel.Visible=false; panel.Parent=inner; Corner(panel,UDim.new(0,6)); Stroke(panel,Theme.Accent,1,0.6)

            local pl=ListLayout(panel,2); Padding(panel,4,4,4,4)
            local trackConn=nil; local flippedUp=false; local currentTH=0

            local function GetPP(th)
                local da=ddBtn.AbsolutePosition; local ds=ddBtn.AbsoluteSize; local ia=inner.AbsolutePosition; local is=inner.AbsoluteSize
                local rx=da.X-ia.X; local ryB=da.Y-ia.Y+ds.Y+4; local ryA=da.Y-ia.Y-th-4
                if ryB+th>is.Y and ryA>=0 then flippedUp=true; return UDim2.new(0,rx,0,ryA)
                else flippedUp=false; return UDim2.new(0,rx,0,ryB) end
            end
            local function GPS(th) return UDim2.new(0,ddBtn.AbsoluteSize.X,0,th) end
            local function STP(th)
                if trackConn then return end
                trackConn=RunService.Heartbeat:Connect(function()
                    if isOpen and panel.Visible then panel.Position=GetPP(th) end
                end)
            end
            local function StTP() if trackConn then trackConn:Disconnect(); trackConn=nil end end

            ConfigManager:RegisterUpdater(labelText,function(v) if type(v)=="string" then selected=v; ddLabel.Text=v; ddLabel.TextColor3=Theme.Text end end)

            local function BO()
                for _,ch in pairs(panel:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
                for i,opt in ipairs(options) do
                    local ob=Instance.new("TextButton"); ob.Size=UDim2.new(1,0,0,30)
                    ob.BackgroundColor3=(selected==opt) and Color3.fromRGB(40,50,65) or Theme.DropdownBg
                    ob.Text=opt; ob.TextColor3=(selected==opt) and Theme.Accent or Theme.Text
                    ob.TextSize=13; ob.Font=Theme.FontLight; ob.BorderSizePixel=0; ob.AutoButtonColor=false
                    ob.LayoutOrder=i; ob.ZIndex=501; ob.Parent=panel; Corner(ob,UDim.new(0,5))
                    AddConnection(ob.MouseButton1Click:Connect(function()
                        selected=opt; ConfigManager:Set(labelText,opt); ddLabel.Text=opt; ddLabel.TextColor3=Theme.Text
                        isOpen=false; activeDropdownPanel=nil; StTP()
                        Tween(panel,{Size=GPS(0)},0.2); Tween(af,{Rotation=0},0.2)
                        task.delay(0.2,function() panel.Visible=false end)
                        if callback then task.spawn(callback,opt) end
                    end))
                end
                panel.CanvasSize=UDim2.new(0,0,0,pl.AbsoluteContentSize.Y+10)
                currentTH=math.min(#options*32+10,160); return currentTH
            end

            AddConnection(ddClick.MouseButton1Click:Connect(function()
                isOpen=not isOpen
                if isOpen then
                    if activeDropdownPanel and activeDropdownPanel~=panel then activeDropdownPanel.Visible=false; activeDropdownPanel.Size=UDim2.new(0,0,0,0) end
                    activeDropdownPanel=panel; local th=BO()
                    panel.Position=GetPP(th); panel.Size=GPS(0); panel.Visible=true
                    Tween(panel,{Size=GPS(th)},0.25); Tween(af,{Rotation=flippedUp and 0 or 180},0.25); STP(th)
                else
                    activeDropdownPanel=nil; StTP(); Tween(panel,{Size=GPS(0)},0.2); Tween(af,{Rotation=0},0.2)
                    task.delay(0.2,function() panel.Visible=false end)
                end
            end))
            SetupHover(row,RowColor(order),ab)
            if selected and callback then task.defer(callback,selected) end
            return {Set=function(_,v) selected=v; ConfigManager:Set(labelText,v); ddLabel.Text=v or "Select..."; ddLabel.TextColor3=v and Theme.Text or Theme.TextDim end,
                Get=function() return selected end, Refresh=function(_,no) options=no; if isOpen then BO() end end}
        end

        -- RADIO SELECT
        function Tab:AddRadioSelect(labelText,radioOptions,callback)
            local order=NextOrder()
            local saved=StateStore[labelText]; local selected=saved or (radioOptions[1] and radioOptions[1].Name) or nil
            StateStore[labelText]=selected

            local ch=#radioOptions*58+10
            local container=Instance.new("Frame"); container.Size=UDim2.new(1,0,0,ch)
            container.BackgroundColor3=Color3.fromRGB(24,24,32); container.BorderSizePixel=0
            container.LayoutOrder=order; container.ZIndex=6; container.Parent=page
            Corner(container,Theme.CornerRadius); Stroke(container,Theme.Border,1,0.3)

            local rf={}
            for i,opt in ipairs(radioOptions) do
                local oc=opt.Color or Theme.Accent
                local of=Instance.new("Frame"); of.Size=UDim2.new(1,-16,0,50)
                of.Position=UDim2.new(0,8,0,8+(i-1)*58)
                of.BackgroundColor3=(selected==opt.Name) and Color3.fromRGB(35,50,40) or Theme.Row
                of.BorderSizePixel=0; of.ZIndex=7; of.Parent=container; Corner(of,UDim.new(0,8))

                local os=Stroke(of,oc,1.5,(selected==opt.Name) and 0.3 or 1)
                local radio=Instance.new("Frame"); radio.Size=UDim2.new(0,22,0,22); radio.Position=UDim2.new(0,14,0.5,-11)
                radio.BackgroundColor3=(selected==opt.Name) and oc or Theme.ToggleOff; radio.BorderSizePixel=0
                radio.ZIndex=8; radio.Parent=of; Corner(radio,UDim.new(1,0))

                local ri=Instance.new("Frame"); ri.Size=UDim2.new(0,8,0,8); ri.Position=UDim2.new(0.5,-4,0.5,-4)
                ri.BackgroundColor3=Color3.fromRGB(255,255,255); ri.BackgroundTransparency=(selected==opt.Name) and 0 or 1
                ri.BorderSizePixel=0; ri.ZIndex=9; ri.Parent=radio; Corner(ri,UDim.new(1,0))

                local ot=Instance.new("TextLabel"); ot.Size=UDim2.new(1,-48,0,22); ot.Position=UDim2.new(0,44,0,6)
                ot.BackgroundTransparency=1; ot.Text=opt.Name; ot.TextColor3=oc; ot.TextSize=14
                ot.Font=Theme.Font; ot.TextXAlignment=Enum.TextXAlignment.Left; ot.ZIndex=9; ot.Parent=of

                local od=Instance.new("TextLabel"); od.Size=UDim2.new(1,-48,0,16); od.Position=UDim2.new(0,44,0,28)
                od.BackgroundTransparency=1; od.Text=opt.Desc or ""; od.TextColor3=Theme.TextDim; od.TextSize=11
                od.Font=Theme.FontLight; od.TextXAlignment=Enum.TextXAlignment.Left; od.ZIndex=9; od.Parent=of

                local ob=Instance.new("TextButton"); ob.Size=UDim2.new(1,0,1,0); ob.BackgroundTransparency=1
                ob.Text=""; ob.ZIndex=10; ob.Parent=of

                rf[opt.Name]={Frame=of,Stroke=os,Radio=radio,RadioInner=ri,Color=oc}

                AddConnection(ob.MouseButton1Click:Connect(function()
                    selected=opt.Name; ConfigManager:Set(labelText,opt.Name)
                    for on,r in pairs(rf) do
                        if on==opt.Name then Tween(r.Frame,{BackgroundColor3=Color3.fromRGB(35,50,40)},0.25); Tween(r.Radio,{BackgroundColor3=r.Color},0.25)
                            Tween(r.RadioInner,{BackgroundTransparency=0},0.2); Tween(r.Stroke,{Transparency=0.3},0.25)
                        else Tween(r.Frame,{BackgroundColor3=Theme.Row},0.25); Tween(r.Radio,{BackgroundColor3=Theme.ToggleOff},0.25)
                            Tween(r.RadioInner,{BackgroundTransparency=1},0.2); Tween(r.Stroke,{Transparency=1},0.25) end
                    end
                    if callback then task.spawn(callback,opt.Name) end
                end))
                AddConnection(ob.MouseEnter:Connect(function() if selected~=opt.Name then Tween(of,{BackgroundColor3=Theme.Hover},0.15) end end))
                AddConnection(ob.MouseLeave:Connect(function() if selected~=opt.Name then Tween(of,{BackgroundColor3=Theme.Row},0.15) end end))
            end

            ConfigManager:RegisterUpdater(labelText,function(v)
                if type(v)=="string" and rf[v] then selected=v
                    for on,r in pairs(rf) do local s=on==v
                        r.Frame.BackgroundColor3=s and Color3.fromRGB(35,50,40) or Theme.Row
                        r.Radio.BackgroundColor3=s and r.Color or Theme.ToggleOff
                        r.RadioInner.BackgroundTransparency=s and 0 or 1; r.Stroke.Transparency=s and 0.3 or 1
                    end
                end
            end)
            if selected and callback then task.defer(callback,selected) end
            return {Set=function(_,v) selected=v; ConfigManager:Set(labelText,v) end, Get=function() return selected end}
        end

        -- PRIORITY LIST
        function Tab:AddPriorityList(labelText,items,callback)
            local order=NextOrder()
            local saved=StateStore[labelText]; local list=(saved and type(saved)=="table") and saved or items
            StateStore[labelText]=list

            local sl=Instance.new("TextLabel"); sl.Size=UDim2.new(1,0,0,24); sl.BackgroundTransparency=1
            sl.Text=labelText; sl.TextColor3=Theme.Accent; sl.TextSize=15; sl.Font=Theme.Font
            sl.TextXAlignment=Enum.TextXAlignment.Left; sl.LayoutOrder=order; sl.ZIndex=7; sl.Parent=page

            local co=NextOrder()
            local cf=Instance.new("Frame"); cf.Size=UDim2.new(1,0,0,#list*40+16)
            cf.BackgroundColor3=Color3.fromRGB(24,24,32); cf.BorderSizePixel=0; cf.LayoutOrder=co
            cf.ZIndex=6; cf.ClipsDescendants=true; cf.Parent=page
            Corner(cf,Theme.CornerRadius); Stroke(cf,Theme.Border,1,0.3)

            local ll=Instance.new("UIListLayout"); ll.FillDirection=Enum.FillDirection.Vertical
            ll.SortOrder=Enum.SortOrder.LayoutOrder; ll.Padding=UDim.new(0,4); ll.Parent=cf
            Padding(cf,8,8,8,8)

            local re={}
            local function RR()
                for _,r in ipairs(re) do if r and r.Parent then r:Destroy() end end; re={}
                for rank,item in ipairs(list) do
                    local mr=Instance.new("Frame"); mr.Size=UDim2.new(1,0,0,36)
                    mr.BackgroundColor3=(rank%2==0) and Theme.Row or Theme.RowAlt; mr.BorderSizePixel=0
                    mr.LayoutOrder=rank; mr.ZIndex=8; mr.Parent=cf; Corner(mr,UDim.new(0,6)); table.insert(re,mr)

                    local rb=Instance.new("Frame"); rb.Size=UDim2.new(0,22,0,22); rb.Position=UDim2.new(0,10,0.5,-11)
                    rb.BackgroundColor3=Theme.Accent; rb.BackgroundTransparency=0.8; rb.BorderSizePixel=0
                    rb.ZIndex=9; rb.Parent=mr; Corner(rb,UDim.new(0,5))
                    local rl=Instance.new("TextLabel"); rl.Size=UDim2.new(1,0,1,0); rl.BackgroundTransparency=1
                    rl.Text=tostring(rank); rl.TextColor3=Theme.Accent; rl.TextSize=13; rl.Font=Theme.Font
                    rl.ZIndex=10; rl.Parent=rb

                    local il=Instance.new("TextLabel"); il.Size=UDim2.new(1,-120,1,0); il.Position=UDim2.new(0,42,0,0)
                    il.BackgroundTransparency=1; il.Text=tostring(item); il.TextColor3=Theme.Text; il.TextSize=14
                    il.Font=Theme.FontLight; il.TextXAlignment=Enum.TextXAlignment.Left; il.ZIndex=9; il.Parent=mr

                    local ub=Instance.new("TextButton"); ub.Size=UDim2.new(0,28,0,26); ub.Position=UDim2.new(1,-64,0.5,-13)
                    ub.BackgroundColor3=Theme.SliderBg; ub.Text="▲"; ub.TextColor3=Theme.Text; ub.TextSize=12
                    ub.Font=Theme.Font; ub.BorderSizePixel=0; ub.AutoButtonColor=false; ub.ZIndex=10; ub.Parent=mr; Corner(ub,UDim.new(0,5))
                    local db=Instance.new("TextButton"); db.Size=UDim2.new(0,28,0,26); db.Position=UDim2.new(1,-32,0.5,-13)
                    db.BackgroundColor3=Theme.SliderBg; db.Text="▼"; db.TextColor3=Theme.Text; db.TextSize=12
                    db.Font=Theme.Font; db.BorderSizePixel=0; db.AutoButtonColor=false; db.ZIndex=10; db.Parent=mr; Corner(db,UDim.new(0,5))

                    AddConnection(ub.MouseButton1Click:Connect(function()
                        if rank<=1 then return end; list[rank],list[rank-1]=list[rank-1],list[rank]
                        ConfigManager:Set(labelText,list); RR(); if callback then task.spawn(callback,list) end
                    end))
                    AddConnection(db.MouseButton1Click:Connect(function()
                        if rank>=#list then return end; list[rank],list[rank+1]=list[rank+1],list[rank]
                        ConfigManager:Set(labelText,list); RR(); if callback then task.spawn(callback,list) end
                    end))
                    AddConnection(ub.MouseEnter:Connect(function() Tween(ub,{BackgroundColor3=Theme.Hover},0.1) end))
                    AddConnection(ub.MouseLeave:Connect(function() Tween(ub,{BackgroundColor3=Theme.SliderBg},0.1) end))
                    AddConnection(db.MouseEnter:Connect(function() Tween(db,{BackgroundColor3=Theme.Hover},0.1) end))
                    AddConnection(db.MouseLeave:Connect(function() Tween(db,{BackgroundColor3=Theme.SliderBg},0.1) end))
                end
                cf.Size=UDim2.new(1,0,0,#list*40+16)
            end
            RR()
            return {Get=function() return list end, Set=function(_,nl) list=nl; ConfigManager:Set(labelText,list); RR() end}
        end

        -- MULTI SELECT (with columns, sorting, search, float-to-top)
        function Tab:AddMultiSelect(labelText,items,optsOrCallback,callbackOrNil)
            local opts,callback
            if type(optsOrCallback)=="function" then callback=optsOrCallback; opts={}
            else opts=optsOrCallback or {}; callback=callbackOrNil end

            local order=NextOrder()
            local configKey="_multiselect_"..labelText
            local saved=StateStore[configKey]; local selected=(saved and type(saved)=="table") and saved or {}
            StateStore[configKey]=selected

            local sortConfigKey="_multisort_"..labelText
            local savedSort=StateStore[sortConfigKey]
            local currentSort=savedSort or opts.DefaultSort or "selected"
            StateStore[sortConfigKey]=currentSort

            local columns=opts.Columns or {}
            local normalizedItems={}
            for i,item in ipairs(items) do
                normalizedItems[i]=(type(item)=="string") and {Name=item} or item
            end

            local sl=Instance.new("TextLabel"); sl.Size=UDim2.new(1,0,0,24); sl.BackgroundTransparency=1
            sl.Text=labelText; sl.TextColor3=Theme.Accent; sl.TextSize=15; sl.Font=Theme.Font
            sl.TextXAlignment=Enum.TextXAlignment.Left; sl.LayoutOrder=order; sl.ZIndex=7; sl.Parent=page

            local co=NextOrder()
            local cf=Instance.new("Frame"); cf.Size=UDim2.new(1,0,0,280)
            cf.BackgroundColor3=Color3.fromRGB(24,24,32); cf.BorderSizePixel=0; cf.LayoutOrder=co
            cf.ZIndex=6; cf.Parent=page; Corner(cf,Theme.CornerRadius); Stroke(cf,Theme.Border,1,0.3)

            local header=Instance.new("Frame"); header.Size=UDim2.new(1,0,0,46)
            header.BackgroundColor3=Theme.Sidebar; header.BorderSizePixel=0; header.ZIndex=7; header.Parent=cf
            Corner(header,Theme.CornerRadius)
            local hf=Instance.new("Frame"); hf.Size=UDim2.new(1,0,0,14); hf.Position=UDim2.new(0,0,1,-14)
            hf.BackgroundColor3=Theme.Sidebar; hf.BorderSizePixel=0; hf.ZIndex=7; hf.Parent=header

            local countLabel=Instance.new("TextLabel"); countLabel.Size=UDim2.new(0,80,1,0)
            countLabel.Position=UDim2.new(0,14,0,0); countLabel.BackgroundTransparency=1
            countLabel.TextColor3=Theme.TextDim; countLabel.TextSize=13; countLabel.Font=Theme.FontLight
            countLabel.TextXAlignment=Enum.TextXAlignment.Left; countLabel.ZIndex=8; countLabel.Parent=header

            local function UC() local c=0; for _ in pairs(selected) do c=c+1 end; countLabel.Text=c.." selected" end; UC()

            local sortOptions={"selected","alpha"}
            for _,col in ipairs(columns) do table.insert(sortOptions,col.Name) end

            local sortBtn=Instance.new("TextButton"); sortBtn.Size=UDim2.new(0,80,0,26)
            sortBtn.Position=UDim2.new(0,96,0.5,-13); sortBtn.BackgroundColor3=Theme.InputBg
            sortBtn.Text="⇅ "..currentSort; sortBtn.TextColor3=Theme.Accent; sortBtn.TextSize=11
            sortBtn.Font=Theme.Font; sortBtn.BorderSizePixel=0; sortBtn.AutoButtonColor=false
            sortBtn.ZIndex=8; sortBtn.Parent=header; Corner(sortBtn,UDim.new(0,5))

            local sbg=Instance.new("Frame"); sbg.Size=UDim2.new(0,150,0,30)
            sbg.Position=UDim2.new(1,-164,0.5,-15); sbg.BackgroundColor3=Theme.InputBg
            sbg.BorderSizePixel=0; sbg.ZIndex=8; sbg.Parent=header; Corner(sbg,UDim.new(0,6))
            local sgl=Stroke(sbg,Theme.Accent,1.5,1)

            local si=Instance.new("TextBox"); si.Size=UDim2.new(1,-16,1,0); si.Position=UDim2.new(0,8,0,0)
            si.BackgroundTransparency=1; si.Text=""; si.PlaceholderText="Search..."
            si.PlaceholderColor3=Theme.TextDim; si.TextColor3=Theme.Text; si.TextSize=13
            si.Font=Theme.FontLight; si.ClearTextOnFocus=false; si.TextXAlignment=Enum.TextXAlignment.Left
            si.ZIndex=9; si.Parent=sbg

            AddConnection(si.Focused:Connect(function() Tween(sgl,{Transparency=0.4},0.2) end))
            AddConnection(si.FocusLost:Connect(function() Tween(sgl,{Transparency=1},0.2) end))

            local sf=Instance.new("ScrollingFrame"); sf.Size=UDim2.new(1,-14,1,-56)
            sf.Position=UDim2.new(0,7,0,50); sf.BackgroundTransparency=1; sf.BorderSizePixel=0
            sf.ScrollBarThickness=4; sf.ScrollBarImageColor3=Theme.Accent; sf.ScrollBarImageTransparency=0.3
            sf.CanvasSize=UDim2.new(0,0,0,0); sf.ZIndex=7; sf.Parent=cf

            local sfl=Instance.new("UIListLayout"); sfl.FillDirection=Enum.FillDirection.Vertical
            sfl.SortOrder=Enum.SortOrder.LayoutOrder; sfl.Padding=UDim.new(0,4); sfl.Parent=sf
            Padding(sf,4,4,4,4)

            local itemRows={}

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
                    if rd then rd.Frame.LayoutOrder=lp; local nc=(lp%2==0) and Theme.Row or Theme.RowAlt
                        rd.Frame.BackgroundColor3=nc; rd.OriginalColor=nc end
                end
            end

            local totalColWidth=0
            for _,col in ipairs(columns) do totalColWidth=totalColWidth+(col.Width or 70)+6 end

            for i,item in ipairs(normalizedItems) do
                local in_=item.Name; local isOn=selected[in_]==true

                local ir=Instance.new("Frame"); ir.Name="Item_"..in_; ir.Size=UDim2.new(1,-8,0,38)
                ir.BackgroundColor3=(i%2==0) and Theme.Row or Theme.RowAlt; ir.BorderSizePixel=0
                ir.LayoutOrder=i; ir.ZIndex=8; ir.Parent=sf; Corner(ir,UDim.new(0,6))

                local nlw=-(70+totalColWidth+14)
                local il=Instance.new("TextLabel"); il.Size=UDim2.new(1,nlw,1,0); il.Position=UDim2.new(0,14,0,0)
                il.BackgroundTransparency=1; il.Text=in_; il.TextColor3=Theme.Text; il.TextSize=13
                il.Font=Theme.FontLight; il.TextXAlignment=Enum.TextXAlignment.Left
                il.TextTruncate=Enum.TextTruncate.AtEnd; il.ZIndex=9; il.Parent=ir

                for ci,col in ipairs(columns) do
                    local cw=col.Width or 70; local pw=0
                    for pi=1,ci-1 do pw=pw+(columns[pi].Width or 70)+6 end
                    local cb=Instance.new("Frame"); cb.Size=UDim2.new(0,cw,0,22)
                    cb.Position=UDim2.new(1,-(52+totalColWidth-pw),0.5,-11)
                    cb.BackgroundColor3=col.Color or Theme.Accent; cb.BackgroundTransparency=0.85
                    cb.BorderSizePixel=0; cb.ZIndex=9; cb.Parent=ir; Corner(cb,UDim.new(0,5))
                    local cv=Instance.new("TextLabel"); cv.Size=UDim2.new(1,0,1,0); cv.BackgroundTransparency=1
                    cv.ZIndex=10; cv.Parent=cb
                    if col.Format then cv.Text=col.Format(item)
                    elseif item[col.Name] then local v=item[col.Name]; cv.Text=(type(v)=="number") and GluttonyUI.FormatNumber(v) or tostring(v)
                    else cv.Text="-" end
                    cv.TextColor3=col.Color or Theme.Accent; cv.TextSize=11; cv.Font=Theme.Font
                end

                local tbg=Instance.new("Frame"); tbg.Size=UDim2.new(0,40,0,22); tbg.Position=UDim2.new(1,-52,0.5,-11)
                tbg.BackgroundColor3=isOn and Theme.Accent or Theme.ProtectedOff; tbg.BorderSizePixel=0
                tbg.ZIndex=10; tbg.Parent=ir; Corner(tbg,UDim.new(1,0))

                local tc=Instance.new("Frame"); tc.Size=UDim2.new(0,18,0,18)
                tc.Position=isOn and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9)
                tc.BackgroundColor3=Theme.Text; tc.BorderSizePixel=0; tc.ZIndex=11; tc.Parent=tbg
                Corner(tc,UDim.new(1,0))

                local tb=Instance.new("TextButton"); tb.Size=UDim2.new(1,0,1,0); tb.BackgroundTransparency=1
                tb.Text=""; tb.ZIndex=12; tb.Parent=tbg

                itemRows[in_]={Frame=ir,ToggleBg=tbg,ToggleCircle=tc,OriginalColor=(i%2==0) and Theme.Row or Theme.RowAlt}

                AddConnection(tb.MouseButton1Click:Connect(function()
                    local no=not(selected[in_]==true)
                    if no then selected[in_]=true else selected[in_]=nil end
                    ConfigManager:Set(configKey,selected)
                    Tween(tbg,{BackgroundColor3=no and Theme.Accent or Theme.ProtectedOff},0.25)
                    Tween(tc,{Position=no and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9)},0.25,Enum.EasingStyle.Back)
                    Tween(tc,{Size=UDim2.new(0,20,0,20)},0.08)
                    task.delay(0.08,function() Tween(tc,{Size=UDim2.new(0,18,0,18)},0.12) end)
                    UC(); task.delay(0.3,function() SortList() end)
                    if callback then task.spawn(callback,selected) end
                end))

                local ra=HoverAccent(ir)
                AddConnection(ir.MouseEnter:Connect(function()
                    Tween(ir,{BackgroundColor3=Theme.Hover},0.15)
                    if ra then Tween(ra,{BackgroundTransparency=0.2},0.15) end
                end))
                AddConnection(ir.MouseLeave:Connect(function()
                    Tween(ir,{BackgroundColor3=itemRows[in_].OriginalColor},0.15)
                    if ra then Tween(ra,{BackgroundTransparency=1},0.15) end
                end))
            end

            AddConnection(sortBtn.MouseButton1Click:Connect(function()
                local ci=1; for si,so in ipairs(sortOptions) do if so==currentSort then ci=si; break end end
                ci=(ci%#sortOptions)+1; currentSort=sortOptions[ci]
                ConfigManager:Set(sortConfigKey,currentSort); sortBtn.Text="⇅ "..currentSort; SortList()
            end))
            AddConnection(sortBtn.MouseEnter:Connect(function() Tween(sortBtn,{BackgroundColor3=Theme.Hover},0.15) end))
            AddConnection(sortBtn.MouseLeave:Connect(function() Tween(sortBtn,{BackgroundColor3=Theme.InputBg},0.15) end))

            AddConnection(si:GetPropertyChangedSignal("Text"):Connect(function()
                local f=si.Text:lower()
                for _,item in ipairs(normalizedItems) do
                    local rd=itemRows[item.Name]
                    if rd then rd.Frame.Visible=(f=="" or item.Name:lower():find(f,1,true)) end
                end
                SortList()
            end))

            AddConnection(sfl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                sf.CanvasSize=UDim2.new(0,0,0,sfl.AbsoluteContentSize.Y+16)
            end))
            sf.CanvasSize=UDim2.new(0,0,0,sfl.AbsoluteContentSize.Y+16)
            task.defer(function() SortList() end)

            return {Get=function() return selected end,
                Set=function(_,ns) selected=ns; ConfigManager:Set(configKey,selected)
                    for _,item in ipairs(normalizedItems) do local rd=itemRows[item.Name]
                        if rd then local isOn=selected[item.Name]==true
                            rd.ToggleBg.BackgroundColor3=isOn and Theme.Accent or Theme.ProtectedOff
                            rd.ToggleCircle.Position=isOn and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9)
                        end end; UC(); SortList() end,
                SetSort=function(_,sm) currentSort=sm; ConfigManager:Set(sortConfigKey,currentSort)
                    sortBtn.Text="⇅ "..currentSort; SortList() end}
        end

        -- SEARCH
        function Tab:AddSearch(placeholder,callback)
            local order=NextOrder()
            local sf=Instance.new("Frame"); sf.Size=UDim2.new(1,0,0,40); sf.BackgroundColor3=Theme.InputBg
            sf.BorderSizePixel=0; sf.LayoutOrder=order; sf.ZIndex=6; sf.Parent=page; Corner(sf,Theme.CornerRadius)
            local gs=Stroke(sf,Theme.Accent,1.5,1)

            local ifr=Instance.new("Frame"); ifr.Size=UDim2.new(0,16,0,16); ifr.Position=UDim2.new(0,14,0.5,-8)
            ifr.BackgroundTransparency=1; ifr.ZIndex=8; ifr.Parent=sf
            local ic=Instance.new("Frame"); ic.Size=UDim2.new(0,11,0,11); ic.BackgroundColor3=Theme.TextDim
            ic.BackgroundTransparency=0.6; ic.BorderSizePixel=0; ic.ZIndex=9; ic.Parent=ifr; Corner(ic,UDim.new(1,0))
            local ih=Instance.new("Frame"); ih.Size=UDim2.new(0,6,0,2); ih.Position=UDim2.new(0,9,0,11)
            ih.BackgroundColor3=Theme.TextDim; ih.BackgroundTransparency=0.4; ih.Rotation=45
            ih.BorderSizePixel=0; ih.ZIndex=9; ih.Parent=ifr; Corner(ih,UDim.new(1,0))

            local si=Instance.new("TextBox"); si.Size=UDim2.new(1,-50,1,0); si.Position=UDim2.new(0,38,0,0)
            si.BackgroundTransparency=1; si.Text=""; si.PlaceholderText=placeholder or "Search..."
            si.PlaceholderColor3=Theme.TextDim; si.TextColor3=Theme.Text; si.TextSize=14
            si.Font=Theme.FontLight; si.ClearTextOnFocus=false; si.TextXAlignment=Enum.TextXAlignment.Left
            si.ZIndex=7; si.Parent=sf

            AddConnection(si.Focused:Connect(function() Tween(gs,{Transparency=0.4},0.2) end))
            AddConnection(si.FocusLost:Connect(function() Tween(gs,{Transparency=1},0.2) end))
            AddConnection(si:GetPropertyChangedSignal("Text"):Connect(function()
                if callback then task.spawn(callback,si.Text) end
            end))
            return {Get=function() return si.Text end, Set=function(_,v) si.Text=v end, Clear=function() si.Text="" end}
        end

        return Tab
    end

    -- WINDOW METHODS
    function Window:Destroy() ConfigManager:Flush(); ThreadManager:StopAll(); StopAntiAFK(); DisconnectAll(); if screenGui then screenGui:Destroy() end end
    function Window:Notify(t,m,nt,d) GluttonyUI:Notify(t,m,nt,d) end
    function Window:GetValue(n) return StateStore[n] end
    function Window:SetValue(n,v) ConfigManager:Set(n,v) end
    function Window:SaveConfig() ConfigManager:Save() end
    function Window:ClearConfig() StateStore={}; ConfigManager:Save() end
    task.defer(function() ConfigManager:ApplyToUI() end)

    -- SETTINGS TAB
    local function BuildSettingsTab()
        local so=999
        local sb=Instance.new("TextButton"); sb.Name="Tab_Settings"; sb.Size=UDim2.new(1,-14,0,42)
        sb.BackgroundColor3=Theme.Sidebar; sb.BorderSizePixel=0; sb.Text=""; sb.AutoButtonColor=false
        sb.LayoutOrder=so; sb.ZIndex=7; sb.Parent=tabContainer; Corner(sb,Theme.CornerRadius)

        local si=Instance.new("Frame"); si.Name="Indicator"; si.Size=UDim2.new(0,4,0,22)
        si.Position=UDim2.new(0,5,0.5,-11); si.BackgroundColor3=Theme.Accent; si.BackgroundTransparency=1
        si.BorderSizePixel=0; si.ZIndex=8; si.Parent=sb; Corner(si,UDim.new(1,0))
        CreateTabIcon(sb,"settings")

        local sl=Instance.new("TextLabel"); sl.Name="Label"; sl.Size=UDim2.new(1,-52,1,0)
        sl.Position=UDim2.new(0,44,0,0); sl.BackgroundTransparency=1; sl.Text="Settings"
        sl.TextColor3=Theme.TextDim; sl.TextSize=14; sl.Font=Theme.FontLight
        sl.TextXAlignment=Enum.TextXAlignment.Left; sl.ZIndex=8; sl.Parent=sb

        AddConnection(sb.MouseEnter:Connect(function()
            if Window._currentTab~="Settings" then Tween(sb,{BackgroundColor3=Theme.Hover},0.15); Tween(sl,{TextColor3=Theme.Text},0.15) end
        end))
        AddConnection(sb.MouseLeave:Connect(function()
            if Window._currentTab~="Settings" then Tween(sb,{BackgroundColor3=Theme.Sidebar},0.15); Tween(sl,{TextColor3=Theme.TextDim},0.15) end
        end))
        AddConnection(sb.MouseButton1Click:Connect(function() SwitchTab("Settings") end))
        Window._tabButtons["Settings"]=sb

        local sp=Instance.new("ScrollingFrame"); sp.Name="Page_Settings"; sp.Size=UDim2.new(1,0,1,0)
        sp.BackgroundTransparency=1; sp.BorderSizePixel=0; sp.ScrollBarThickness=4
        sp.ScrollBarImageColor3=Theme.Accent; sp.ScrollBarImageTransparency=0.3
        sp.CanvasSize=UDim2.new(0,0,0,0); sp.Visible=false; sp.ZIndex=6; sp.Parent=content
        Padding(sp,18,18,22,22)

        local spl=ListLayout(sp,8)
        AddConnection(spl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            sp.CanvasSize=UDim2.new(0,0,0,spl.AbsoluteContentSize.Y+40)
        end))
        Window._pages["Settings"]=sp

        local tf=Instance.new("Frame"); tf.Size=UDim2.new(1,0,0,42); tf.BackgroundTransparency=1
        tf.LayoutOrder=0; tf.ZIndex=7; tf.Parent=sp
        local ptl=Instance.new("TextLabel"); ptl.Size=UDim2.new(1,0,0,34); ptl.BackgroundTransparency=1
        ptl.Text="Settings"; ptl.TextColor3=Theme.Text; ptl.TextSize=24; ptl.Font=Theme.Font
        ptl.TextXAlignment=Enum.TextXAlignment.Left; ptl.ZIndex=7; ptl.Parent=tf
        local ul=Instance.new("Frame"); ul.Size=UDim2.new(0.25,0,0,2); ul.Position=UDim2.new(0,0,1,-2)
        ul.BackgroundColor3=Theme.Accent; ul.BackgroundTransparency=0.3; ul.BorderSizePixel=0
        ul.ZIndex=8; ul.Parent=tf; Corner(ul,UDim.new(1,0))
        local ulg=Instance.new("UIGradient")
        ulg.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.7,0),NumberSequenceKeypoint.new(1,1)})
        ulg.Parent=ul

        local lo=0; local function NSO() lo=lo+1; return lo end

        local il=Instance.new("TextLabel"); il.Size=UDim2.new(1,0,0,30); il.BackgroundTransparency=1
        il.Text="Interface"; il.TextColor3=Theme.Accent; il.TextSize=15; il.Font=Theme.Font
        il.TextXAlignment=Enum.TextXAlignment.Left; il.LayoutOrder=NSO(); il.ZIndex=7; il.Parent=sp

        -- Opacity
        local oo=NSO(); local ov=StateStore["GUI Opacity"] or 100
        local or_=Instance.new("Frame"); or_.Size=UDim2.new(1,0,0,Theme.RowHeight+4)
        or_.BackgroundColor3=RowColor(oo); or_.BorderSizePixel=0; or_.LayoutOrder=oo
        or_.ZIndex=6; or_.ClipsDescendants=true; or_.Parent=sp; Corner(or_,Theme.CornerRadius)
        local oa=HoverAccent(or_)

        local ol=Instance.new("TextLabel"); ol.Size=UDim2.new(0,170,1,0); ol.Position=UDim2.new(0,18,0,0)
        ol.BackgroundTransparency=1; ol.Text="GUI Opacity"; ol.TextColor3=Theme.Text; ol.TextSize=14
        ol.Font=Theme.FontLight; ol.TextXAlignment=Enum.TextXAlignment.Left; ol.ZIndex=7; ol.Parent=or_

        local ob=Instance.new("Frame"); ob.Size=UDim2.new(0,42,0,22); ob.Position=UDim2.new(1,-158,0.5,-11)
        ob.BackgroundColor3=Theme.Accent; ob.BackgroundTransparency=0.85; ob.BorderSizePixel=0
        ob.ZIndex=7; ob.Parent=or_; Corner(ob,UDim.new(0,5))
        local ovl=Instance.new("TextLabel"); ovl.Size=UDim2.new(1,0,1,0); ovl.BackgroundTransparency=1
        ovl.Text=tostring(math.floor(ov)); ovl.TextColor3=Theme.Accent; ovl.TextSize=13; ovl.Font=Theme.Font
        ovl.ZIndex=8; ovl.Parent=ob

        local ot=Instance.new("Frame"); ot.Size=UDim2.new(0,100,0,6); ot.Position=UDim2.new(1,-112,0.5,-3)
        ot.BackgroundColor3=Theme.SliderBg; ot.BorderSizePixel=0; ot.ZIndex=8; ot.Parent=or_; Corner(ot,UDim.new(1,0))

        local op=(ov-10)/90
        local of=Instance.new("Frame"); of.Size=UDim2.new(op,0,1,0); of.BackgroundColor3=Theme.SliderFill
        of.BorderSizePixel=0; of.ZIndex=9; of.Parent=ot; Corner(of,UDim.new(1,0))
        local ok=Instance.new("Frame"); ok.Size=UDim2.new(0,16,0,16); ok.Position=UDim2.new(op,-8,0.5,-8)
        ok.BackgroundColor3=Theme.Text; ok.BorderSizePixel=0; ok.ZIndex=10; ok.Parent=ot
        Corner(ok,UDim.new(1,0)); Stroke(ok,Theme.Shadow,1,0.75)

        local osl=false
        local oh=Instance.new("TextButton"); oh.Size=UDim2.new(1,14,1,18); oh.Position=UDim2.new(0,-7,0,-9)
        oh.BackgroundTransparency=1; oh.Text=""; oh.ZIndex=11; oh.Parent=ot

        local function AO(v) local t=1-(v/100); main.BackgroundTransparency=t
            if titleBar then titleBar.BackgroundTransparency=t end
            if sidebar then sidebar.BackgroundTransparency=t end
            if content then content.BackgroundTransparency=t end end

        local function UO(input)
            local x=math.clamp((input.Position.X-ot.AbsolutePosition.X)/ot.AbsoluteSize.X,0,1)
            local v=math.floor(10+90*x); ov=v; ConfigManager:Set("GUI Opacity",v)
            ovl.Text=tostring(v); of.Size=UDim2.new(x,0,1,0); ok.Position=UDim2.new(x,-8,0.5,-8); AO(v)
        end

        AddConnection(oh.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then osl=true; UO(i) end end))
        AddConnection(oh.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then osl=false end end))
        AddConnection(UserInputService.InputChanged:Connect(function(i) if osl and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then UO(i) end end))
        SetupHover(or_,RowColor(oo),oa); AO(ov)

        local spacer=Instance.new("Frame"); spacer.Size=UDim2.new(1,0,0,20); spacer.BackgroundTransparency=1
        spacer.LayoutOrder=NSO(); spacer.Parent=sp

        local cl=Instance.new("TextLabel"); cl.Size=UDim2.new(1,0,0,30); cl.BackgroundTransparency=1
        cl.Text="Community"; cl.TextColor3=Theme.Accent; cl.TextSize=15; cl.Font=Theme.Font
        cl.TextXAlignment=Enum.TextXAlignment.Left; cl.LayoutOrder=NSO(); cl.ZIndex=7; cl.Parent=sp

        local ic=Instance.new("Frame"); ic.Size=UDim2.new(1,0,0,80); ic.BackgroundColor3=Color3.fromRGB(28,30,38)
        ic.BorderSizePixel=0; ic.LayoutOrder=NSO(); ic.ZIndex=6; ic.Parent=sp
        Corner(ic,Theme.CornerRadius); Stroke(ic,Theme.Border,1,0.4)
        local iab=Instance.new("Frame"); iab.Size=UDim2.new(0,4,1,-16); iab.Position=UDim2.new(0,10,0,8)
        iab.BackgroundColor3=Theme.Accent; iab.BackgroundTransparency=0.3; iab.BorderSizePixel=0
        iab.ZIndex=7; iab.Parent=ic; Corner(iab,UDim.new(1,0))
        local it=Instance.new("TextLabel"); it.Size=UDim2.new(1,-40,1,-20); it.Position=UDim2.new(0,28,0,10)
        it.BackgroundTransparency=1; it.Text="Join our Discord for updates, feature requests, and support."
        it.TextColor3=Theme.TextDim; it.TextSize=13; it.Font=Theme.FontLight
        it.TextXAlignment=Enum.TextXAlignment.Left; it.TextYAlignment=Enum.TextYAlignment.Center
        it.TextWrapped=true; it.ZIndex=7; it.Parent=ic

        local dro=NSO()
        local dr=Instance.new("Frame"); dr.Size=UDim2.new(1,0,0,Theme.RowHeight)
        dr.BackgroundColor3=RowColor(dro); dr.BorderSizePixel=0; dr.LayoutOrder=dro
        dr.ZIndex=6; dr.ClipsDescendants=true; dr.Parent=sp; Corner(dr,Theme.CornerRadius)
        local da=HoverAccent(dr)

        local dl=Instance.new("TextLabel"); dl.Size=UDim2.new(1,-130,1,0); dl.Position=UDim2.new(0,18,0,0)
        dl.BackgroundTransparency=1; dl.Text="Discord Server"; dl.TextColor3=Theme.Text; dl.TextSize=14
        dl.Font=Theme.FontLight; dl.TextXAlignment=Enum.TextXAlignment.Left; dl.ZIndex=7; dl.Parent=dr

        local dbf=Instance.new("Frame"); dbf.Size=UDim2.new(0,100,0,32); dbf.Position=UDim2.new(1,-114,0.5,-16)
        dbf.BackgroundTransparency=1; dbf.ZIndex=7; dbf.Parent=dr
        local dsh=Instance.new("Frame"); dsh.Size=UDim2.new(1,2,1,2); dsh.Position=UDim2.new(0,-1,0,2)
        dsh.BackgroundColor3=Theme.Shadow; dsh.BackgroundTransparency=0.82; dsh.BorderSizePixel=0
        dsh.ZIndex=7; dsh.Parent=dbf; Corner(dsh,Theme.CornerRadius)

        local dc=Color3.fromRGB(88,101,242); local dh=Color3.fromRGB(108,121,255); local sc=Color3.fromRGB(50,180,80)
        local db=Instance.new("TextButton"); db.Size=UDim2.new(1,-2,1,-2); db.Position=UDim2.new(0,1,0,0)
        db.BackgroundColor3=dc; db.Text="Copy Link"; db.TextColor3=Theme.Text; db.TextSize=13; db.Font=Theme.Font
        db.BorderSizePixel=0; db.AutoButtonColor=false; db.ZIndex=8; db.Parent=dbf; Corner(db,Theme.CornerRadius)
        local dg=Stroke(db,dc,1.5,0.6)

        AddConnection(db.MouseEnter:Connect(function() Tween(db,{BackgroundColor3=dh},0.15); Tween(dg,{Transparency=0.3},0.2) end))
        AddConnection(db.MouseLeave:Connect(function() Tween(db,{BackgroundColor3=dc},0.15); Tween(dg,{Transparency=0.6},0.2) end))
        AddConnection(db.MouseButton1Click:Connect(function()
            Tween(db,{Size=UDim2.new(1,-6,1,-4)},0.06)
            task.delay(0.06,function() Tween(db,{Size=UDim2.new(1,-2,1,-2)},0.1,Enum.EasingStyle.Back) end)
            local url="https://discord.gg/6KmxCWU6Dc"
            local ok2=pcall(function() if setclipboard then setclipboard(url) elseif toclipboard then toclipboard(url) else error() end end)
            if ok2 then local ot2=db.Text; db.Text="Copied!"; Tween(db,{BackgroundColor3=sc},0.2); Tween(dg,{Color=sc,Transparency=0.3},0.2)
                task.delay(1.5,function() if db and db.Parent then db.Text=ot2; Tween(db,{BackgroundColor3=dc},0.2); Tween(dg,{Color=dc,Transparency=0.6},0.2) end end) end
        end))
        SetupHover(dr,RowColor(dro),da)

        local vl=Instance.new("TextLabel"); vl.Size=UDim2.new(0,40,0,16); vl.Position=UDim2.new(1,-50,1,-22)
        vl.BackgroundTransparency=1; vl.Text="v2.1"; vl.TextColor3=Theme.TextDim; vl.TextTransparency=0.5
        vl.TextSize=11; vl.Font=Theme.FontLight; vl.TextXAlignment=Enum.TextXAlignment.Right
        vl.ZIndex=15; vl.Parent=inner
    end
    BuildSettingsTab()

    -- TOGGLE BUTTON
    local TB=Instance.new("Frame"); TB.Name="ToggleButton"; TB.Size=UDim2.new(0,36,0,90)
    TB.Position=UDim2.new(0,-4,0.5,-45); TB.BackgroundColor3=Theme.Background; TB.BorderSizePixel=0
    TB.ZIndex=100; TB.Parent=screenGui; Corner(TB,UDim.new(0,12)); Stroke(TB,Theme.Accent,2,0.5)

    local lc=Instance.new("Frame"); lc.Size=UDim2.new(0,12,1,0); lc.BackgroundColor3=Theme.Background
    lc.BorderSizePixel=0; lc.ZIndex=101; lc.Parent=TB

    local tab=Instance.new("Frame"); tab.Name="AccentBar"; tab.AnchorPoint=Vector2.new(0.5,0.5)
    tab.Size=UDim2.new(0,3,0,35); tab.Position=UDim2.new(1,-5,0.5,0); tab.BackgroundColor3=Theme.Accent
    tab.BorderSizePixel=0; tab.ZIndex=105; tab.Parent=TB; Corner(tab,UDim.new(1,0))

    local dc2=Instance.new("Frame"); dc2.Size=UDim2.new(0,12,0,50); dc2.Position=UDim2.new(0,8,0.5,-25)
    dc2.BackgroundTransparency=1; dc2.ZIndex=105; dc2.Parent=TB
    local dots={}
    for i=1,5 do
        local d=Instance.new("Frame"); d.Size=UDim2.new(0,6,0,6); d.Position=UDim2.new(0.5,-3,0,(i-1)*11)
        d.BackgroundColor3=Theme.TextDim; d.BackgroundTransparency=0.3; d.BorderSizePixel=0
        d.ZIndex=106; d.Parent=dc2; Corner(d,UDim.new(1,0)); table.insert(dots,d)
    end

    local tcb=Instance.new("TextButton"); tcb.Size=UDim2.new(1,0,1,0); tcb.BackgroundTransparency=1
    tcb.Text=""; tcb.ZIndex=110; tcb.Parent=TB

    local pr=true
    task.spawn(function()
        while pr do
            if not TB or not TB.Parent then break end
            Tween(tab,{BackgroundTransparency=0.3},1.2,Enum.EasingStyle.Sine); task.wait(1.2)
            if not TB or not TB.Parent then break end
            Tween(tab,{BackgroundTransparency=0},1.2,Enum.EasingStyle.Sine); task.wait(1.2)
        end
    end)

    local tbd,tbds,tbbs,tbhm,tbcd=false,0,0,false,false; local go=true
    local function gty() return TB.Position.Y.Offset end
    local function sty(y)
        local sh=screenGui.AbsoluteSize.Y; local bh=TB.AbsoluteSize.Y
        y=math.clamp(y,-sh/2+bh/2+20,sh/2-bh/2-20)
        TB.Position=UDim2.new(0,go and 0 or -4,0.5,y)
    end

    AddConnection(tcb.MouseButton1Down:Connect(function()
        if tbcd then return end; tbd=true; tbhm=false
        tbds=UserInputService:GetMouseLocation().Y; tbbs=gty()
    end))
    AddConnection(tcb.MouseButton1Up:Connect(function()
        if not tbd then return end; tbd=false
        if not tbhm and not tbcd then
            tbcd=true; local cy=gty()
            if go then
                go=false; Tween(main,{Size=UDim2.new(0,Theme.WindowWidth,0,0)},0.3)
                Tween(TB,{Position=UDim2.new(0,-4,0.5,cy)},0.25); Tween(tab,{Size=UDim2.new(0,3,0,35)},0.25)
                task.delay(0.3,function() main.Visible=false; tbcd=false end)
            else
                go=true; main.Visible=true; main.Size=UDim2.new(0,Theme.WindowWidth,0,0)
                Tween(main,{Size=UDim2.new(0,Theme.WindowWidth,0,Theme.WindowHeight)},0.35,Enum.EasingStyle.Back)
                Tween(TB,{Position=UDim2.new(0,0,0.5,cy)},0.25); Tween(tab,{Size=UDim2.new(0,3,0,55)},0.25)
                task.delay(0.35,function() tbcd=false end)
            end
        end
    end))
    AddConnection(UserInputService.InputChanged:Connect(function(input)
        if not tbd then return end
        if input.UserInputType~=Enum.UserInputType.MouseMovement and input.UserInputType~=Enum.UserInputType.Touch then return end
        local dy=UserInputService:GetMouseLocation().Y-tbds
        if math.abs(dy)>5 then tbhm=true end; if tbhm then sty(tbbs+dy) end
    end))
    AddConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then tbd=false end
    end))
    AddConnection(tcb.MouseEnter:Connect(function()
        Tween(TB,{BackgroundColor3=Theme.Hover},0.2); Tween(lc,{BackgroundColor3=Theme.Hover},0.2)
        Tween(TB,{Position=UDim2.new(0,0,0.5,gty())},0.2)
        for i,d in ipairs(dots) do task.delay(i*0.04,function()
            Tween(d,{BackgroundColor3=Theme.Accent,BackgroundTransparency=0,Size=UDim2.new(0,8,0,8),Position=UDim2.new(0.5,-4,0,(i-1)*11-1)},0.15) end) end
    end))
    AddConnection(tcb.MouseLeave:Connect(function()
        Tween(TB,{BackgroundColor3=Theme.Background},0.2); Tween(lc,{BackgroundColor3=Theme.Background},0.2)
        if not go and not tbd then Tween(TB,{Position=UDim2.new(0,-4,0.5,gty())},0.2) end
        for i,d in ipairs(dots) do task.delay(i*0.04,function()
            Tween(d,{BackgroundColor3=Theme.TextDim,BackgroundTransparency=0.3,Size=UDim2.new(0,6,0,6),Position=UDim2.new(0.5,-3,0,(i-1)*11)},0.15) end) end
    end))

    local od=Window.Destroy
    function Window:Destroy() pr=false; od(self) end
    return Window
end

return GluttonyUI