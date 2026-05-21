--[[
    Kynox bootstrap – logic หลักของ hub
    Template/Kynox.lua ควรเหลือแค่ CONFIG + เรียกใช้ฟังก์ชันจากไฟล์นี้
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Kynox = {}

function Kynox.detectPlatform()
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        return "Mobile/Tablet"
    elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
        return "Console"
    end
    return "PC"
end

function Kynox.detectWindowSize(pcSize, mobileSize)
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        return mobileSize
    end
    return pcSize
end

function Kynox.guardDuplicate(coreGui)
    coreGui = coreGui or game:GetService("CoreGui")
    if getgenv().Fluent and getgenv().Fluent.Window and not getgenv().Fluent.Unloaded then
        TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
        return true
    end
    for _, gui in ipairs(coreGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Name == "ToggleGui" then
            TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
            return true
        end
    end
    return false
end

function Kynox.loadModule(fileName, github)
    github = github or {}
    local url = github[fileName]
    assert(url, "Unknown UI file: " .. tostring(fileName))
    return loadstring(game:HttpGet(url))()
end

function Kynox.rawHttpRequest(opts)
    local req = (syn and syn.request)
        or http_request
        or (http and http.request)
        or request

    if type(req) == "function" then
        return req(opts)
    elseif opts.Method == "GET" then
        local ok, body = pcall(function()
            return game:HttpGet(opts.Url)
        end)
        if ok then
            return { StatusCode = 200, Body = body }
        end
    end
    return nil
end

function Kynox.openDiscordInvite(inviteUrl, notify)
    if setclipboard then
        setclipboard(inviteUrl)
    end

    local code = string.match(inviteUrl, "discord%.com/invite/(%w+)")
        or string.match(inviteUrl, "discord%.gg/(%w+)")

    if code and Kynox.rawHttpRequest({
        Url = "http://127.0.0.1:6463/rpc?v=1",
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["Origin"] = "https://discord.com",
        },
        Body = HttpService:JSONEncode({
            cmd = "INVITE_BROWSER",
            args = { code = code },
            nonce = HttpService:GenerateGUID(false),
        }),
    }) then
        if notify then
            notify({
                Title = "Discord",
                Content = "Copied link & opening Discord...",
                Duration = 4,
            })
        end
        return
    end

    if notify then
        notify({
            Title = "Discord",
            Content = "Copied! Open Discord manually: " .. inviteUrl,
            Duration = 5,
        })
    end
end

function Kynox.bindDiscordParagraph(paragraph, inviteUrl, notify)
    if paragraph and paragraph.Frame then
        paragraph.Frame.MouseButton1Click:Connect(function()
            Kynox.openDiscordInvite(inviteUrl, notify)
        end)
    end
end

function Kynox.addTitleBarLogo(window, imageId, size)
    size = size or 20
    local titleBar = window.TitleBar
    if not titleBar then
        return
    end

    local holder
    for _, child in ipairs(titleBar.Frame:GetChildren()) do
        if child:IsA("Frame") and child:FindFirstChildOfClass("UIListLayout") then
            holder = child
            break
        end
    end
    if not holder then
        return
    end

    local list = holder:FindFirstChildOfClass("UIListLayout")
    if list then
        list.VerticalAlignment = Enum.VerticalAlignment.Center
    end

    local id = tostring(imageId):gsub("rbxassetid://", "")
    local wrap = Instance.new("Frame")
    wrap.Name = "LogoWrap"
    wrap.LayoutOrder = 0
    wrap.Size = UDim2.new(0, size, 1, 0)
    wrap.BackgroundTransparency = 1
    wrap.Parent = holder

    local logo = Instance.new("ImageLabel")
    logo.Name = "Logo"
    logo.AnchorPoint = Vector2.new(0.5, 0.5)
    logo.Position = UDim2.fromScale(0.5, 0.5)
    logo.Image = "rbxassetid://" .. id
    logo.Size = UDim2.fromOffset(size, size)
    logo.BackgroundTransparency = 1
    logo.ScaleType = Enum.ScaleType.Fit
    logo.Parent = wrap

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = logo

    for _, child in ipairs(holder:GetChildren()) do
        if child:IsA("TextLabel") then
            child.LayoutOrder = child.LayoutOrder + 1
        end
    end
end

function Kynox.setTitleBarFontSize(window, titleSize, subTitleSize)
    titleSize = titleSize or 15
    subTitleSize = subTitleSize or 12
    local titleBar = window.TitleBar
    if not titleBar then
        return
    end

    local titleFont = Font.new(
        "rbxasset://fonts/families/GothamSSm.json",
        Enum.FontWeight.SemiBold,
        Enum.FontStyle.Normal
    )

    for _, child in ipairs(titleBar.Frame:GetChildren()) do
        if child:IsA("Frame") and child:FindFirstChildOfClass("UIListLayout") then
            for _, label in ipairs(child:GetChildren()) do
                if label:IsA("TextLabel") then
                    if label.TextTransparency >= 0.3 then
                        label.TextSize = subTitleSize
                    else
                        label.TextSize = titleSize
                        label.FontFace = titleFont
                    end
                end
            end
            break
        end
    end
end

function Kynox.setupBranding(window, branding, fluent)
    branding = branding or {}
    if branding.Logo then
        Kynox.addTitleBarLogo(window, branding.Logo, branding.LogoSize or 20)
    end
    if branding.TitleSize or branding.SubTitleSize then
        Kynox.setTitleBarFontSize(window, branding.TitleSize, branding.SubTitleSize)
    end
    if fluent and branding.Transparency == false then
        fluent:ToggleTransparency(false)
    end
end

function Kynox.setWindowVisible(window, visible)
    if visible then
        if window.Minimized then
            window:Minimize()
        end
    elseif not window.Minimized then
        window:Minimize()
    end
end

function Kynox.createToggleGui(parent, window, toggle)
    toggle = toggle or {}
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ToggleGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = parent

    local toggleButton = Instance.new("ImageButton")
    toggleButton.Name = "ToggleButton"
    toggleButton.Image = toggle.Image or "rbxassetid://78756412031557"
    toggleButton.ScaleType = Enum.ScaleType.Fit
    toggleButton.Size = UDim2.fromOffset(toggle.Size or 50, toggle.Size or 50)
    toggleButton.Position = toggle.Position or UDim2.new(0.06, 0, 0.08, 0)
    toggleButton.BorderSizePixel = 0
    toggleButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    toggleButton.AnchorPoint = Vector2.new(0.5, 0.5)
    toggleButton.Parent = screenGui

    Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0, 6)

    local stroke = Instance.new("UIStroke", toggleButton)
    stroke.Thickness = 2
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.LineJoinMode = Enum.LineJoinMode.Round
    stroke.Color = Color3.fromRGB(0, 0, 0)

    local gradient = Instance.new("UIGradient", stroke)
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 60, 60)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 120, 120)),
    })
    gradient.Rotation = 45

    toggleButton.MouseButton1Down:Connect(function()
        toggleButton:TweenSize(
            UDim2.fromOffset((toggle.Size or 50) - 4, (toggle.Size or 50) - 4),
            Enum.EasingDirection.Out,
            Enum.EasingStyle.Quad,
            0.06,
            true
        )
    end)

    toggleButton.MouseButton1Up:Connect(function()
        toggleButton:TweenSize(
            UDim2.fromOffset(toggle.Size or 50, toggle.Size or 50),
            Enum.EasingDirection.Out,
            Enum.EasingStyle.Quad,
            0.08,
            true
        )
    end)

    local uiVisible = true
    toggleButton.MouseButton1Click:Connect(function()
        uiVisible = not uiVisible
        Kynox.setWindowVisible(window, uiVisible)
    end)

    return screenGui, toggleButton
end

function Kynox.applyForcedInterfaceSettings(fluent, interfaceManager)
    if interfaceManager and interfaceManager.ApplyForcedVisuals then
        interfaceManager.Library = interfaceManager.Library or fluent
        interfaceManager:ApplyForcedVisuals()
        return
    end

    fluent:SetTheme("Dark")
    if fluent.UseAcrylic then
        fluent:ToggleAcrylic(false)
    end
    fluent:ToggleTransparency(false)
end

function Kynox.applyDefaultTheme(fluent, interfaceManager)
    Kynox.applyForcedInterfaceSettings(fluent, interfaceManager)
end

-- โครงสร้างโฟลเดอร์:
--   KynoxConfigs/
--     KeySystem/     -> key.txt (license)
--     games/         -> Dueling Grounds.json, ...
--     interface/     -> options.json (Minimize Bind ฯลฯ)
Kynox.CONFIG_ROOT = "KynoxConfigs"
Kynox.KEY_FOLDER = "KynoxConfigs/KeySystem"
Kynox.GAMES_FOLDER = "KynoxConfigs/games"
Kynox.INTERFACE_FOLDER = "KynoxConfigs/interface"

function Kynox.shallowCopy(t)
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = v
    end
    return copy
end

-- Multi Dropdown ของ Fluent ใช้ table แบบ { optionName = true/false } -> JSON object ปลอดภัย
function Kynox.copyMultiDropdownValue(value)
    local out = {}
    if type(value) ~= "table" then
        return out
    end
    for key, on in pairs(value) do
        if type(key) == "string" and type(on) == "boolean" then
            out[key] = on
        end
    end
    return out
end

function Kynox.ensureConfigFolders()
    if type(isfolder) ~= "function" or type(makefolder) ~= "function" then
        return
    end
    for _, path in ipairs({
        Kynox.CONFIG_ROOT,
        Kynox.KEY_FOLDER,
        Kynox.GAMES_FOLDER,
        Kynox.INTERFACE_FOLDER,
    }) do
        if not isfolder(path) then
            makefolder(path)
        end
    end
end

function Kynox.resolveKeyPath(keyFile)
    keyFile = keyFile or "key.txt"
    if keyFile:find("/") or keyFile:find("\\") then
        return keyFile
    end
    return Kynox.KEY_FOLDER .. "/" .. keyFile
end

function Kynox.resolveGameConfigPath(gameName)
    return Kynox.GAMES_FOLDER .. "/" .. gameName .. ".json"
end

local function mergeGameConfig(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" and type(target[k]) == "table" then
            mergeGameConfig(target[k], v)
        else
            target[k] = v
        end
    end
end

local function isExcludedKey(key, exclude)
    if exclude[key] then
        return true
    end
    for _, name in ipairs(exclude) do
        if name == key then
            return true
        end
    end
    return false
end

local function sanitizeConfigTable(tbl, exclude)
    exclude = exclude or {}
    local out = {}
    for k, v in pairs(tbl) do
        if not isExcludedKey(k, exclude) then
            local t = type(v)
            if t == "table" then
                out[k] = sanitizeConfigTable(v, exclude)
            elseif t == "boolean" or t == "number" or t == "string" then
                out[k] = v
            end
        end
    end
    return out
end

--[[
    เซฟ/โหลด config เกม (แบบ getgenv().JinkX.Configs + SaveConfig/LoadConfig)
    cfg.Game = "Dueling Grounds"
    cfg.Configs = getgenv().Kynox.Configs
    cfg.Exclude = { PlayersESP = true }  -- คีย์ที่ไม่เซฟ (Color3 / userdata)
    เรียก SaveConfig() เองใน Callback ของ UI
]]
function Kynox.setupGameConfig(cfg, notify)
    cfg = cfg or {}
    notify = notify or function() end

    local configs = cfg.Configs
    assert(type(configs) == "table", "setupGameConfig: cfg.Configs must be a table")

    local gameName = cfg.Game or "Default"
    local path = cfg.Path or Kynox.resolveGameConfigPath(gameName)
    local exclude = cfg.Exclude or {}

    Kynox.ensureConfigFolders()

    local defaultsSnapshot = sanitizeConfigTable(Kynox.shallowCopy(configs), exclude)

    local function SaveConfig()
        if type(writefile) ~= "function" then
            return false, "writefile unavailable"
        end
        local payload = sanitizeConfigTable(Kynox.shallowCopy(configs), exclude)
        local ok, encoded = pcall(function()
            return HttpService:JSONEncode(payload)
        end)
        if not ok then
            return false, "encode failed"
        end
        writefile(path, encoded)
        return true
    end

    local function LoadConfig()
        if type(isfile) ~= "function" or type(readfile) ~= "function" then
            return false, "readfile unavailable"
        end

        if isfile(path) then
            local ok, decoded = pcall(function()
                return HttpService:JSONDecode(readfile(path))
            end)
            if ok and type(decoded) == "table" then
                mergeGameConfig(configs, decoded)
                if cfg.AfterLoad then
                    cfg.AfterLoad(decoded)
                end
                notify({
                    Title = cfg.NotifyTitle or "Kynox Hub",
                    Content = "Config loaded.",
                    Duration = 4,
                })
                return true, "loaded"
            end
            notify({
                Title = cfg.NotifyTitle or "Kynox Hub",
                Content = "Config load failed.",
                Duration = 5,
            })
            return false, "decode failed"
        end

        SaveConfig()
        notify({
            Title = cfg.NotifyTitle or "Kynox Hub",
            Content = "Default config created.",
            Duration = 4,
        })
        return true, "created"
    end

    local function ResetConfig()
        for k in pairs(configs) do
            configs[k] = nil
        end
        mergeGameConfig(configs, sanitizeConfigTable(defaultsSnapshot, exclude))
        SaveConfig()
        if cfg.AfterReset then
            cfg.AfterReset(configs)
        end
        notify({
            Title = cfg.NotifyTitle or "Kynox Hub",
            Content = "Config reset.",
            Duration = 4,
        })
        return true
    end

    return {
        Path = path,
        Game = gameName,
        Defaults = defaultsSnapshot,
        SaveConfig = SaveConfig,
        LoadConfig = LoadConfig,
        ResetConfig = ResetConfig,
    }
end

function Kynox.buildWindowOptions(windowCfg)
    windowCfg = windowCfg or {}
    return {
        Title = windowCfg.Title or "Kynox Hub",
        SubTitle = windowCfg.SubTitle or "",
        TabWidth = windowCfg.TabWidth or 150,
        Size = Kynox.detectWindowSize(
            windowCfg.PcSize or UDim2.fromOffset(720, 480),
            windowCfg.MobileSize or UDim2.fromOffset(480, 380)
        ),
        Acrylic = false,
        Theme = "Dark",
        MinimizeKey = windowCfg.MinimizeKey or Enum.KeyCode.LeftControl,
    }
end

-- ============ Key System Loader (ธีม Dark = ui หลัก) ============

local KEY_THEME = {
    AcrylicMain = Color3.fromRGB(16, 16, 18),
    AcrylicBorder = Color3.fromRGB(38, 38, 42),
    TitleBarLine = Color3.fromRGB(28, 28, 30),
    Accent = Color3.fromRGB(96, 205, 255),
    Element = Color3.fromRGB(46, 46, 50),
    ElementBorder = Color3.fromRGB(12, 12, 14),
    InElementBorder = Color3.fromRGB(36, 36, 40),
    InputFocused = Color3.fromRGB(6, 6, 8),
    Text = Color3.fromRGB(235, 235, 238),
    SubText = Color3.fromRGB(125, 125, 132),
    Error = Color3.fromRGB(255, 110, 110),
    ElementTransparency = 0.82,
}

local KEY_BTN_TWEEN = {
    Hover = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    Press = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Release = TweenInfo.new(0.14, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
}

local function bindKeyButtonAnim(btn, accent)
    local stroke = btn:FindFirstChildOfClass("UIStroke")
    local baseBg = btn.BackgroundColor3
    local baseTrans = btn.BackgroundTransparency
    local baseText = btn.TextColor3
    local baseStrokeTrans = stroke and stroke.Transparency or 0.5

    local scale = Instance.new("UIScale")
    scale.Scale = 1
    scale.Parent = btn

    local hover = Instance.new("Frame")
    hover.Name = "Hover"
    hover.Size = UDim2.fromScale(1, 1)
    hover.BackgroundColor3 = accent and Color3.fromRGB(255, 255, 255) or KEY_THEME.Text
    hover.BackgroundTransparency = 1
    hover.BorderSizePixel = 0
    hover.ZIndex = 0
    hover.Parent = btn
    Instance.new("UICorner", hover).CornerRadius = UDim.new(0, 4)

    local activeTweens = {}

    local function stopTweens()
        for _, tw in ipairs(activeTweens) do
            tw:Cancel()
        end
        table.clear(activeTweens)
    end

    local function play(inst, props, info)
        local tw = TweenService:Create(inst, info, props)
        activeTweens[#activeTweens + 1] = tw
        tw:Play()
        return tw
    end

    local function setHover()
        stopTweens()
        play(scale, { Scale = 1.04 }, KEY_BTN_TWEEN.Hover)
        play(hover, { BackgroundTransparency = accent and 0.82 or 0.9 }, KEY_BTN_TWEEN.Hover)
        if stroke then
            play(stroke, { Transparency = accent and 0 or 0.2 }, KEY_BTN_TWEEN.Hover)
        end
        if accent then
            play(btn, {
                BackgroundColor3 = baseBg:Lerp(Color3.fromRGB(255, 255, 255), 0.14),
            }, KEY_BTN_TWEEN.Hover)
        else
            play(btn, {
                BackgroundTransparency = math.clamp(baseTrans - 0.22, 0, 1),
                TextColor3 = KEY_THEME.Text,
            }, KEY_BTN_TWEEN.Hover)
        end
    end

    local function setIdle()
        stopTweens()
        play(scale, { Scale = 1 }, KEY_BTN_TWEEN.Hover)
        play(hover, { BackgroundTransparency = 1 }, KEY_BTN_TWEEN.Hover)
        if stroke then
            play(stroke, { Transparency = baseStrokeTrans }, KEY_BTN_TWEEN.Hover)
        end
        play(btn, {
            BackgroundColor3 = baseBg,
            BackgroundTransparency = baseTrans,
            TextColor3 = baseText,
        }, KEY_BTN_TWEEN.Hover)
    end

    local hovering = false

    btn.MouseEnter:Connect(function()
        hovering = true
        setHover()
    end)
    btn.MouseLeave:Connect(function()
        hovering = false
        setIdle()
    end)

    btn.MouseButton1Down:Connect(function()
        stopTweens()
        play(scale, { Scale = 0.96 }, KEY_BTN_TWEEN.Press)
        play(hover, { BackgroundTransparency = accent and 0.9 or 0.94 }, KEY_BTN_TWEEN.Press)
        if accent then
            play(btn, {
                BackgroundColor3 = baseBg:Lerp(Color3.fromRGB(0, 0, 0), 0.12),
            }, KEY_BTN_TWEEN.Press)
        else
            play(btn, { BackgroundTransparency = math.min(1, baseTrans + 0.06) }, KEY_BTN_TWEEN.Press)
        end
    end)

    btn.MouseButton1Up:Connect(function()
        if hovering then
            setHover()
        else
            setIdle()
        end
    end)
end

local KEY_CLOSE_TWEEN = {
    Out = TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.In),
    Fade = TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    In = TweenInfo.new(0.48, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

local function startLogoAnim(logo)
    local scale = Instance.new("UIScale")
    scale.Scale = 1
    scale.Parent = logo

    local t0 = os.clock()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not logo.Parent then
            conn:Disconnect()
            return
        end
        local t = os.clock() - t0
        local wave = math.sin(t * 1.35)
        local wave2 = math.cos(t * 0.9)
        scale.Scale = 1 + wave * 0.035
        logo.Rotation = wave2 * 2.5
        logo.ImageColor3 = Color3.fromRGB(255, 255, 255):Lerp(KEY_THEME.Accent, 0.06 + (wave + 1) * 0.04)
    end)

    return function()
        conn:Disconnect()
        logo.ImageColor3 = Color3.fromRGB(255, 255, 255)
    end
end

local function startTitleTypewriter(label, fullText)
    fullText = fullText or "Kynox Hub"
    label.Text = ""

    local alive = true
    task.spawn(function()
        while alive and label.Parent do
            for i = 1, #fullText do
                if not alive or not label.Parent then
                    return
                end
                label.Text = string.sub(fullText, 1, i)
                task.wait(0.07)
            end
            task.wait(4)

            for i = #fullText - 1, 0, -1 do
                if not alive or not label.Parent then
                    return
                end
                label.Text = string.sub(fullText, 1, i)
                task.wait(0.05)
            end
            task.wait(0.5)
        end
    end)

    return function()
        alive = false
        if label.Parent then
            label.Text = fullText
        end
    end
end

local function bindAlphanumericKeyBox(keyBox)
    local function sanitize(text)
        return (text or ""):gsub("[^A-Za-z0-9]", "")
    end

    keyBox:GetPropertyChangedSignal("Text"):Connect(function()
        local raw = keyBox.Text
        local cleaned = sanitize(raw)
        if cleaned ~= raw then
            local cursor = keyBox.CursorPosition
            keyBox.Text = cleaned
            pcall(function()
                keyBox.CursorPosition = math.clamp(cursor - (#raw - #cleaned), 1, #cleaned + 1)
            end)
        end
    end)
end

-- ลากแบบเดียวกับ Fluent (InputBegan บน handle + UIS.InputChanged)
local function bindDrag(frame, handles)
    local UIS = UserInputService
    local dragging, dragInput, dragStart, startPos

    local function onInputBegan(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                dragInput = nil
            end
        end)
    end

    local function onInputChanged(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        then
            dragInput = input
        end
    end

    for _, handle in ipairs(handles) do
        handle.InputBegan:Connect(onInputBegan)
        handle.InputChanged:Connect(onInputChanged)
    end

    UIS.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

function Kynox.formatSessionTime(seconds)
    seconds = math.max(0, math.floor(seconds))
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

function Kynox.destroyExistingSessionTimer(parent)
    local function sweep(container)
        if not container then
            return
        end
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("ScreenGui") and child.Name == "KynoxSessionTimer" then
                child:Destroy()
            end
        end
    end
    sweep(parent)
    sweep(game:GetService("CoreGui"))
    local player = Players.LocalPlayer
    if player then
        sweep(player:FindFirstChild("PlayerGui"))
    end
end

function Kynox.createSessionTimer(opts)
    opts = opts or {}
    local parent = opts.Parent or game:GetService("CoreGui")
    Kynox.destroyExistingSessionTimer(parent)

    local sessionStart = opts.StartTime or tick()
    local visible = opts.Visible ~= false

    local gui = Instance.new("ScreenGui")
    gui.Name = "KynoxSessionTimer"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 998
    gui.IgnoreGuiInset = true
    gui.Enabled = visible
    gui.Parent = parent

    local barH = opts.Height or 34

    local card = Instance.new("Frame")
    card.Name = "Card"
    card.AnchorPoint = Vector2.new(1, 0)
    card.AutomaticSize = Enum.AutomaticSize.X
    card.Size = UDim2.fromOffset(0, barH)
    card.Position = opts.Position or UDim2.new(1, -10, 0, 16)
    card.BackgroundColor3 = KEY_THEME.AcrylicMain
    card.BackgroundTransparency = 0
    card.BorderSizePixel = 0
    card.Parent = gui

    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local cardStroke = Instance.new("UIStroke", card)
    cardStroke.Color = KEY_THEME.AcrylicBorder
    cardStroke.Thickness = 1
    cardStroke.Transparency = 0.5

    local accentLine = Instance.new("Frame")
    accentLine.Name = "AccentLine"
    accentLine.Size = UDim2.new(0, 3, 1, -10)
    accentLine.Position = UDim2.new(0, 0, 0, 4)
    accentLine.BackgroundColor3 = KEY_THEME.Accent
    accentLine.BorderSizePixel = 0
    accentLine.ZIndex = 2
    accentLine.Parent = card
    Instance.new("UICorner", accentLine).CornerRadius = UDim.new(0, 2)

    local accentGlow = Instance.new("UIStroke", accentLine)
    accentGlow.Color = KEY_THEME.Accent
    accentGlow.Thickness = 1
    accentGlow.Transparency = 0.35

    local row = Instance.new("Frame")
    row.Name = "Row"
    row.AutomaticSize = Enum.AutomaticSize.X
    row.Size = UDim2.new(0, 0, 1, 0)
    row.Position = UDim2.fromOffset(8, 0)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Parent = card

    local pad = Instance.new("UIPadding", row)
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 12)
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 4)

    local timeLabel = Instance.new("TextLabel")
    timeLabel.Name = "Time"
    timeLabel.AutomaticSize = Enum.AutomaticSize.X
    timeLabel.Size = UDim2.fromOffset(0, barH - 8)
    timeLabel.BackgroundTransparency = 1
    timeLabel.FontFace = Font.new(
        "rbxasset://fonts/families/GothamSSm.json",
        Enum.FontWeight.SemiBold,
        Enum.FontStyle.Normal
    )
    timeLabel.Text = "00:00:00"
    timeLabel.TextColor3 = KEY_THEME.Text
    timeLabel.TextSize = 15
    timeLabel.TextXAlignment = Enum.TextXAlignment.Center
    timeLabel.Parent = row

    local sizeLimit = Instance.new("UISizeConstraint", card)
    sizeLimit.MinSize = Vector2.new(96, barH)
    sizeLimit.MaxSize = Vector2.new(200, barH)

    local alive = true
    local tickConn
    tickConn = RunService.Heartbeat:Connect(function()
        if not alive or not timeLabel.Parent then
            tickConn:Disconnect()
            return
        end
        timeLabel.Text = Kynox.formatSessionTime(tick() - sessionStart)
    end)

    local api = {
        Gui = gui,
        Card = card,
        TimeLabel = timeLabel,
    }

    function api.setVisible(state)
        gui.Enabled = state == true
    end

    function api.destroy()
        alive = false
        if tickConn then
            tickConn:Disconnect()
        end
        gui:Destroy()
    end

    return api
end

function Kynox.verifyKey(key, cfg)
    key = type(key) == "string" and key:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if key == "" then
        return false, "Please enter a key."
    end
    if cfg.Verify then
        local ok, msg = cfg.Verify(key)
        if ok == false then
            return false, msg or "Invalid key."
        end
        return true
    end
    if #key < 8 then
        return false, "Key is too short."
    end
    return true
end

function Kynox.loadSavedKey(cfg)
    if not cfg.SaveKey or type(isfile) ~= "function" or type(readfile) ~= "function" then
        return nil
    end
    Kynox.ensureConfigFolders()
    local path = Kynox.resolveKeyPath(cfg.KeyFile)
    if isfile(path) then
        return readfile(path):gsub("%s+", "")
    end
    return nil
end

function Kynox.saveKey(cfg, key)
    if not cfg.SaveKey or type(writefile) ~= "function" then
        return
    end
    Kynox.ensureConfigFolders()
    writefile(Kynox.resolveKeyPath(cfg.KeyFile), key)
end

function Kynox.destroyExistingKeyLoader(parent)
    local function sweep(container)
        if not container then
            return
        end
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("ScreenGui") and child.Name == "KynoxKeyLoader" then
                child:Destroy()
            end
        end
    end

    sweep(parent)
    sweep(game:GetService("CoreGui"))
    local player = Players.LocalPlayer
    if player then
        sweep(player:FindFirstChild("PlayerGui"))
    end
end

function Kynox.createKeyLoader(cfg, notify)
    cfg = cfg or {}
    notify = notify or function() end

    local parent = cfg.Parent or game:GetService("CoreGui")
    Kynox.destroyExistingKeyLoader(parent)

    local cardW = cfg.Width or 400

    local gui = Instance.new("ScreenGui")
    gui.Name = "KynoxKeyLoader"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999
    gui.Parent = parent

    local root = Instance.new("Frame")
    root.Name = "Root"
    root.Size = UDim2.fromScale(1, 1)
    root.BackgroundTransparency = 1
    root.BorderSizePixel = 0
    root.Parent = gui

    local shell = Instance.new("Frame")
    shell.Name = "CardShell"
    shell.AnchorPoint = Vector2.new(0, 0)
    shell.Position = UDim2.new(0.5, -math.floor(cardW / 2), 0.5, -200)
    shell.Size = UDim2.fromOffset(cardW, 0)
    shell.AutomaticSize = Enum.AutomaticSize.Y
    shell.BackgroundTransparency = 1
    shell.BorderSizePixel = 0
    shell.Parent = root

    local shellScale = Instance.new("UIScale")
    shellScale.Name = "ShellScale"
    shellScale.Scale = 0.88
    shellScale.Parent = shell

    local fadeGroup = Instance.new("CanvasGroup")
    fadeGroup.Name = "FadeGroup"
    fadeGroup.Size = UDim2.new(1, 0, 0, 0)
    fadeGroup.AutomaticSize = Enum.AutomaticSize.Y
    fadeGroup.BackgroundTransparency = 1
    fadeGroup.GroupTransparency = 0
    fadeGroup.Parent = shell

    local card = Instance.new("Frame")
    card.Name = "Card"
    card.Size = UDim2.fromOffset(cardW, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = KEY_THEME.AcrylicMain
    card.BackgroundTransparency = 0
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.Parent = fadeGroup

    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local cardStroke = Instance.new("UIStroke", card)
    cardStroke.Color = KEY_THEME.AcrylicBorder
    cardStroke.Thickness = 1
    cardStroke.Transparency = 0.5

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "Close"
    closeBtn.AnchorPoint = Vector2.new(1, 0)
    closeBtn.Position = UDim2.new(1, -10, 0, 8)
    closeBtn.Size = UDim2.fromOffset(26, 26)
    closeBtn.BackgroundColor3 = KEY_THEME.Element
    closeBtn.BackgroundTransparency = KEY_THEME.ElementTransparency
    closeBtn.BorderSizePixel = 0
    closeBtn.AutoButtonColor = false
    closeBtn.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = KEY_THEME.SubText
    closeBtn.TextSize = 14
    closeBtn.ZIndex = 20
    closeBtn.Parent = card
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
    local closeStroke = Instance.new("UIStroke", closeBtn)
    closeStroke.Color = KEY_THEME.ElementBorder
    closeStroke.Thickness = 1
    closeStroke.Transparency = 0.5

    closeBtn.MouseEnter:Connect(function()
        closeBtn.BackgroundTransparency = 0.5
        closeBtn.TextColor3 = KEY_THEME.Text
    end)
    closeBtn.MouseLeave:Connect(function()
        closeBtn.BackgroundTransparency = KEY_THEME.ElementTransparency
        closeBtn.TextColor3 = KEY_THEME.SubText
    end)

    local headerDrag = Instance.new("TextButton")
    headerDrag.Name = "HeaderDrag"
    headerDrag.Size = UDim2.new(1, -44, 0, 108)
    headerDrag.Position = UDim2.fromOffset(0, 0)
    headerDrag.BackgroundTransparency = 1
    headerDrag.BorderSizePixel = 0
    headerDrag.AutoButtonColor = false
    headerDrag.Text = ""
    headerDrag.ZIndex = 12
    headerDrag.Parent = card

    local dragBar = Instance.new("TextButton")
    dragBar.Name = "DragBar"
    dragBar.Size = UDim2.fromScale(1, 1)
    dragBar.BackgroundTransparency = 1
    dragBar.BorderSizePixel = 0
    dragBar.AutoButtonColor = false
    dragBar.Text = ""
    dragBar.ZIndex = 1
    dragBar.Parent = card

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, 0, 0, 0)
    content.AutomaticSize = Enum.AutomaticSize.Y
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ZIndex = 5
    content.Parent = card

    local pad = Instance.new("UIPadding", content)
    pad.PaddingTop = UDim.new(0, 20)
    pad.PaddingBottom = UDim.new(0, 20)
    pad.PaddingLeft = UDim.new(0, 24)
    pad.PaddingRight = UDim.new(0, 24)

    local layout = Instance.new("UIListLayout", content)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 12)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local dragHandles = { dragBar, headerDrag }
    local logo

    local animStopList = {}

    TweenService:Create(shellScale, KEY_CLOSE_TWEEN.In, { Scale = 1 }):Play()

    if cfg.Logo then
        local logoId = tostring(cfg.Logo):gsub("rbxassetid://", "")
        local logoWrap = Instance.new("Frame")
        logoWrap.Name = "LogoWrap"
        logoWrap.LayoutOrder = 0
        logoWrap.Size = UDim2.fromOffset(52, 52)
        logoWrap.BackgroundTransparency = 1
        logoWrap.ZIndex = 6
        logoWrap.Parent = content

        logo = Instance.new("ImageLabel")
        logo.Name = "Logo"
        logo.AnchorPoint = Vector2.new(0.5, 0.5)
        logo.Position = UDim2.fromScale(0.5, 0.5)
        logo.BackgroundTransparency = 1
        logo.Image = "rbxassetid://" .. logoId
        logo.Size = UDim2.fromOffset(48, 48)
        logo.ScaleType = Enum.ScaleType.Fit
        logo.Active = true
        logo.ZIndex = 6
        logo.Parent = logoWrap
        table.insert(dragHandles, logoWrap)
        animStopList[#animStopList + 1] = startLogoAnim(logo)
    end

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.LayoutOrder = 1
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 22)
    title.FontFace = Font.new(
        "rbxasset://fonts/families/GothamSSm.json",
        Enum.FontWeight.SemiBold,
        Enum.FontStyle.Normal
    )
    local titleFull = cfg.Title or "Kynox Hub"
    title.Text = ""
    title.TextColor3 = KEY_THEME.Text
    title.TextSize = 18
    title.Active = true
    title.ZIndex = 6
    title.Parent = content
    table.insert(dragHandles, title)
    animStopList[#animStopList + 1] = startTitleTypewriter(title, titleFull)

    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.LayoutOrder = 2
    subtitle.BackgroundTransparency = 1
    subtitle.Size = UDim2.new(1, 0, 0, 16)
    subtitle.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
    subtitle.Text = cfg.Subtitle or "Enter your license key"
    subtitle.TextColor3 = KEY_THEME.SubText
    subtitle.TextSize = 13
    subtitle.Active = true
    subtitle.ZIndex = 6
    subtitle.Parent = content
    table.insert(dragHandles, subtitle)

    local inputWrap = Instance.new("Frame")
    inputWrap.Name = "InputWrap"
    inputWrap.LayoutOrder = 3
    inputWrap.Size = UDim2.new(1, 0, 0, 40)
    inputWrap.BackgroundColor3 = KEY_THEME.Element
    inputWrap.BackgroundTransparency = KEY_THEME.ElementTransparency
    inputWrap.BorderSizePixel = 0
    inputWrap.ZIndex = 2
    inputWrap.Parent = content
    Instance.new("UICorner", inputWrap).CornerRadius = UDim.new(0, 4)
    local inputStroke = Instance.new("UIStroke", inputWrap)
    inputStroke.Color = KEY_THEME.ElementBorder
    inputStroke.Thickness = 1
    inputStroke.Transparency = 0.5

    local keyBox = Instance.new("TextBox")
    keyBox.Name = "KeyInput"
    keyBox.Size = UDim2.new(1, -16, 1, 0)
    keyBox.Position = UDim2.fromOffset(8, 0)
    keyBox.BackgroundTransparency = 1
    keyBox.ClearTextOnFocus = false
    keyBox.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
    keyBox.PlaceholderText = cfg.Placeholder or "Paste your key here..."
    keyBox.PlaceholderColor3 = KEY_THEME.SubText
    keyBox.Text = ""
    keyBox.TextColor3 = KEY_THEME.Text
    keyBox.TextSize = 14
    keyBox.TextXAlignment = Enum.TextXAlignment.Left
    keyBox.Parent = inputWrap
    bindAlphanumericKeyBox(keyBox)

    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.LayoutOrder = 4
    status.BackgroundTransparency = 1
    status.Size = UDim2.new(1, 0, 0, 14)
    status.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json")
    status.Text = ""
    status.TextColor3 = KEY_THEME.SubText
    status.TextSize = 12
    status.TextWrapped = true
    status.ZIndex = 2
    status.Parent = content

    local btnRow = Instance.new("Frame")
    btnRow.Name = "Buttons"
    btnRow.LayoutOrder = 5
    btnRow.Size = UDim2.new(1, 0, 0, 38)
    btnRow.BackgroundTransparency = 1
    btnRow.ZIndex = 2
    btnRow.Parent = content

    local btnLayout = Instance.new("UIListLayout", btnRow)
    btnLayout.FillDirection = Enum.FillDirection.Horizontal
    btnLayout.Padding = UDim.new(0, 10)
    btnLayout.SortOrder = Enum.SortOrder.LayoutOrder
    btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local function makeButton(name, label, accent, order)
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.LayoutOrder = order
        btn.Size = UDim2.new(0.5, -5, 1, 0)
        btn.BackgroundColor3 = accent and KEY_THEME.Accent or KEY_THEME.Element
        btn.BackgroundTransparency = accent and 0 or KEY_THEME.ElementTransparency
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.ZIndex = 3
        btn.FontFace = Font.new(
            "rbxasset://fonts/families/GothamSSm.json",
            Enum.FontWeight.Medium,
            Enum.FontStyle.Normal
        )
        btn.Text = label
        btn.TextColor3 = accent and Color3.fromRGB(0, 0, 0) or KEY_THEME.Text
        btn.TextSize = 14
        btn.Parent = btnRow
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        local s = Instance.new("UIStroke", btn)
        s.Color = accent and KEY_THEME.Accent or KEY_THEME.ElementBorder
        s.Thickness = 1
        s.Transparency = accent and 0 or 0.5
        bindKeyButtonAnim(btn, accent)
        return btn
    end

    local getKeyBtn = makeButton("GetKey", cfg.GetKeyText or "Get Key", false, 0)
    local submitBtn = makeButton("Submit", cfg.SubmitText or "Submit", true, 1)

    local centered = false
    local function centerCard()
        if centered then
            return
        end
        local h = layout.AbsoluteContentSize.Y
        if h <= 0 then
            return
        end
        centered = true
        shell.Position = UDim2.new(0.5, -math.floor(cardW / 2), 0.5, -math.floor(h / 2 + 24))
    end
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(centerCard)
    task.defer(centerCard)

    bindDrag(shell, dragHandles)

    local loader = {
        Gui = gui,
        Shell = shell,
        Card = card,
        KeyBox = keyBox,
        Status = status,
        CloseButton = closeBtn,
        SubmitButton = submitBtn,
        GetKeyButton = getKeyBtn,
    }

    function loader.setStatus(text, isError)
        status.Text = text or ""
        status.TextColor3 = isError and KEY_THEME.Error or KEY_THEME.SubText
    end

    function loader.getKey()
        return keyBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
    end

    function loader.destroy()
        for _, stop in ipairs(animStopList) do
            stop()
        end
        gui:Destroy()
    end

    function loader.playCloseAnim(onDone)
        for _, stop in ipairs(animStopList) do
            stop()
        end
        table.clear(animStopList)

        local scale = shell:FindFirstChild("ShellScale")
        if scale then
            TweenService:Create(scale, KEY_CLOSE_TWEEN.Out, { Scale = 0.84 }):Play()
        end
        TweenService:Create(fadeGroup, KEY_CLOSE_TWEEN.Fade, { GroupTransparency = 1 }):Play()

        task.delay(0.36, function()
            if gui.Parent then
                gui:Destroy()
            end
            if onDone then
                onDone()
            end
        end)
    end

    getKeyBtn.MouseButton1Click:Connect(function()
        local url = cfg.GetKeyUrl or ""
        if url == "" then
            loader.setStatus("Get Key URL is not configured.", true)
            return
        end
        if setclipboard then
            setclipboard(url)
        end
        if url:find("discord") then
            Kynox.openDiscordInvite(url, notify)
        else
            notify({
                Title = "Get Key",
                Content = "Link copied to clipboard.",
                Duration = 4,
            })
        end
    end)

    return loader
end

--[[
    แสดง Key Loader จนกว่าจะผ่านหรือยกเลิก
    onSuccess(key) เรียกเมื่อ key ถูกต้อง
    คืนค่า true = ผ่าน, false = ปิด/ยกเลิก
]]
function Kynox.runKeySystem(cfg, notify)
    cfg = cfg or {}
    if cfg.Enabled == false then
        return true
    end

    getgenv()._KynoxKeySystemRunId = (getgenv()._KynoxKeySystemRunId or 0) + 1
    local runId = getgenv()._KynoxKeySystemRunId

    Kynox.destroyExistingKeyLoader(cfg.Parent)

    local finished, passed, cancelled = false, false, false

    local function succeed(key)
        Kynox.saveKey(cfg, key)
        passed = true
        finished = true
        if cfg.onSuccess then
            cfg.onSuccess(key)
        end
    end

    local saved = Kynox.loadSavedKey(cfg)
    if saved then
        local ok = Kynox.verifyKey(saved, cfg)
        if ok == true then
            succeed(saved)
            return true
        end
    end

    local loader = Kynox.createKeyLoader(cfg, notify)

    local closing = false
    loader.CloseButton.MouseButton1Click:Connect(function()
        if closing then
            return
        end
        closing = true
        cancelled = true
        passed = false
        loader.playCloseAnim(function()
            finished = true
            if cfg.onCancel then
                cfg.onCancel()
            end
        end)
    end)

    local function trySubmit()
        local key = loader.getKey()
        local ok, err = Kynox.verifyKey(key, cfg)
        if ok == true then
            loader.setStatus("Success! Loading...", false)
            task.wait(0.15)
            loader.destroy()
            succeed(key)
            return
        end
        loader.setStatus(err or "Invalid key.", true)
        notify({
            Title = "Key System",
            Content = err or "Invalid key.",
            Duration = 4,
        })
    end

    loader.SubmitButton.MouseButton1Click:Connect(trySubmit)

    loader.KeyBox.FocusLost:Connect(function(enter)
        if enter then
            trySubmit()
        end
    end)

    while not finished and getgenv()._KynoxKeySystemRunId == runId do
        task.wait()
    end

    if getgenv()._KynoxKeySystemRunId ~= runId then
        return false
    end

    if cancelled and cfg.KickOnClose == true then
        local player = Players.LocalPlayer
        if player then
            player:Kick(cfg.KickMessage or "You need a valid key to use this script.")
        end
    end

    return passed
end

return Kynox
