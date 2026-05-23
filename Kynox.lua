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

function Kynox.patchFluentMainSource(src)
    if not src or src:find("_KynoxFluentPatched", 1, true) then
        return src
    end
    src = "-- _KynoxFluentPatched\n" .. src
    -- ลด re-entrant UpdateTheme ตอนสร้าง UI (ช่วยกัน Plugin/capability error บาง executor)
    src = src:gsub(
        "k%.Registry%[m%] = p\n            k%.UpdateTheme%(%)",
        [[k.Registry[m] = p
            if not k._themeScheduled then
                k._themeScheduled = true
                task.defer(function()
                    k._themeScheduled = false
                    pcall(k.UpdateTheme)
                end)
            end]],
        1
    )
    src = src:gsub(
        "k%.Registry%[m%]%.Properties = n\n            k%.UpdateTheme%(%)",
        [[k.Registry[m].Properties = n
            if not k._themeScheduled then
                k._themeScheduled = true
                task.defer(function()
                    k._themeScheduled = false
                    pcall(k.UpdateTheme)
                end)
            end]],
        1
    )
    src = src:gsub(
        "function k%.New%(m, n, o%)\n            local p = Instance%.new%(m%)",
        [[function k.New(m, n, o)
            local instNew = (clonefunction and clonefunction(Instance.new)) or Instance.new
            local p
            local ok, inst = pcall(instNew, m)
            p = ok and inst or instNew(m)]]
    )
    -- ปิด dropdown ลอยเมื่อพับ UI (popup parent = Library.GUI ไม่ใช่ Root)
    if not src:find("CloseAllOpenFrames", 1, true) then
        src = src:gsub(
            "function x%.Destroy%(C%)",
            [[function x.CloseAllOpenFrames(C)
            for i = #C.OpenFrames, 1, -1 do
                local entry = C.OpenFrames[i]
                if type(entry) == "table" and type(entry.Close) == "function" and entry.Opened then
                    entry:Close()
                elseif typeof(entry) == "Instance" then
                    entry.Visible = false
                end
            end
        end
        function x.Destroy(C)]],
            1
        )
        src = src:gsub(
            "function v%.Minimize%(M%)\n                v%.Minimized = not v%.Minimized\n                v%.Root%.Visible = not v%.Minimized",
            [[function v.Minimize(M)
                v.Minimized = not v.Minimized
                v.Root.Visible = not v.Minimized
                if v.Minimized then
                    u:CloseAllOpenFrames()
                end]],
            1
        )
        src = src:gsub("table%.insert%(k%.OpenFrames, v%)\n", "", 1)
        src = src:gsub(
            "function l%.Open%(B%)\n                l%.Opened = true",
            [[function l.Open(B)
                if not table.find(k.OpenFrames, l) then
                    table.insert(k.OpenFrames, l)
                end
                l.Opened = true]],
            1
        )
        src = src:gsub(
            "function l%.Close%(B%)\n                l%.Opened = false\n                A%.ScrollingEnabled = true",
            [[function l.Close(B)
                l.Opened = false
                local idx = table.find(k.OpenFrames, l)
                if idx then
                    table.remove(k.OpenFrames, idx)
                end
                A.ScrollingEnabled = true]],
            1
        )
        src = src:gsub(
            "{v%.AcrylicPaint%.Frame, v%.TabDisplay, v%.ContainerHolder, F, E}\n            %)\n            v%.TitleBar =",
            [[{v.AcrylicPaint.Frame, v.TabDisplay, v.ContainerHolder, F, E}
            )
            m.AddSignal(
                v.Root:GetPropertyChangedSignal("Visible"),
                function()
                    if not v.Root.Visible then
                        u:CloseAllOpenFrames()
                    end
                end
            )
            v.TitleBar =]],
            1
        )
    end
    if not src:find("formatBulletText", 1, true) then
        src = src:gsub(
            "return function%(m, n, o, p%)\n            local q = {}\n            q%.TitleLabel =",
            [[local function formatBulletText(text)
            if type(text) ~= "string" or text == "" then
                return text or ""
            end
            if text:match("^%s*%-%s") then
                return text
            end
            local openFont, inner, closeFont = text:match("^(<font[^>]*>)(.*)(</font>%s*)$")
            if openFont and inner and not inner:find("<", 1, true) then
                inner = inner:match("^%s*(.*)$") or inner
                return openFont .. "- " .. inner .. closeFont
            end
            if text:match("^%s*<") then
                return text
            end
            return "- " .. (text:match("^%s*(.*)$") or text)
        end
        return function(m, n, o, p)
            local q = {}
            q.TitleLabel =]],
            1
        )
        src = src:gsub(
            "function q%.SetDesc%(r, s%)\n                if s == nil then\n                    s = \"\"\n                end\n                if s == \"\" then",
            "function q.SetDesc(r, s)\n                if s == nil then\n                    s = \"\"\n                end\n                s = formatBulletText(s)\n                if s == \"\" then",
            1
        )
    end
    return src
end

function Kynox.loadFluentMain(github)
    github = github or Kynox.buildGithubUrls()
    local url = github["main.lua"]
    assert(url, "Unknown UI file: main.lua")
    local src = game:HttpGet(url)
    src = Kynox.patchFluentMainSource(src)
    return loadstring(src)()
end

function Kynox.loadModule(fileName, github)
    github = github or {}
    if fileName == "main.lua" then
        return Kynox.loadFluentMain(github)
    end
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

function Kynox.normalizeHttpUrl(url)
    if type(url) ~= "string" or url == "" then
        return nil
    end
    url = url:match("^%s*(.-)%s*$")
    if url == "" then
        return nil
    end
    if not url:find("^https?://", 1) then
        url = "https://" .. url:gsub("^//", "")
    end
    return url
end

function Kynox.openBrowserUrl(url)
    url = Kynox.normalizeHttpUrl(url)
    if not url then
        return false
    end

    local function tryCall(fn)
        if type(fn) ~= "function" then
            return false
        end
        local ok = pcall(fn)
        return ok == true or ok == nil
    end

    if tryCall(function()
        if type(openurl) == "function" then
            openurl(url)
        end
    end) then
        return true
    end
    if tryCall(function()
        if type(OpenURL) == "function" then
            OpenURL(url)
        end
    end) then
        return true
    end
    if syn and tryCall(function()
        syn.open_url(url)
    end) then
        return true
    end
    if fluxus and tryCall(function()
        fluxus.open_url(url)
    end) then
        return true
    end
    if Krnl and tryCall(function()
        if type(Krnl.open_url) == "function" then
            Krnl.open_url(url)
        elseif type(Krnl.OpenURL) == "function" then
            Krnl.OpenURL(url)
        end
    end) then
        return true
    end
    if http and tryCall(function()
        if type(http.open) == "function" then
            http.open(url)
        end
    end) then
        return true
    end

    return tryCall(function()
        game:GetService("StarterGui"):SetCore("OpenBrowserWindow", url)
    end)
end

function Kynox.openDiscordDesktopInvite(inviteUrl)
    local code = string.match(inviteUrl or "", "discord%.com/invite/([%w%-]+)")
        or string.match(inviteUrl or "", "discord%.gg/([%w%-]+)")
    if not code then
        return false
    end
    local resp = Kynox.rawHttpRequest({
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
    })
    return resp ~= nil
end

function Kynox.openDiscordInvite(inviteUrl, notify)
    inviteUrl = Kynox.normalizeHttpUrl(inviteUrl) or inviteUrl
    if setclipboard and inviteUrl then
        setclipboard(inviteUrl)
    end

    local openedBrowser = Kynox.openBrowserUrl(inviteUrl)
    local openedDesktop = (not openedBrowser) and Kynox.openDiscordDesktopInvite(inviteUrl)

    if notify then
        if openedBrowser then
            notify({
                Title = "Discord",
                Content = "Opening invite in your browser...",
                Duration = 4,
            })
        elseif openedDesktop then
            notify({
                Title = "Discord",
                Content = "Opening Discord app...",
                Duration = 4,
            })
        else
            notify({
                Title = "Discord",
                Content = "Link copied to clipboard. Paste in your browser: " .. tostring(inviteUrl),
                Duration = 5,
            })
        end
    end

    return openedBrowser or openedDesktop
end

function Kynox.applyDiscordCallout(paragraph, opts)
    opts = opts or {}
    if not paragraph or not paragraph.Frame then
        return
    end
    local accent = opts.AccentColor or Color3.fromRGB(237, 66, 69)
    local bg = opts.BackgroundColor or accent
    local bgTrans = opts.BackgroundTransparency or 0.86
    paragraph.TitleLabel.Visible = false
    paragraph.TitleLabel.Size = UDim2.new(1, 0, 0, 0)
    local frame = paragraph.Frame
    frame.BackgroundColor3 = bg
    frame.BackgroundTransparency = bgTrans
    if paragraph.Border then
        paragraph.Border.Color = accent
        paragraph.Border.Transparency = 0.72
    end
    local existing = frame:FindFirstChild("CalloutAccent")
    if existing then
        existing:Destroy()
    end
    local accentBar = Instance.new("Frame")
    accentBar.Name = "CalloutAccent"
    accentBar.BackgroundColor3 = accent
    accentBar.BorderSizePixel = 0
    accentBar.Size = UDim2.new(0, 4, 1, 0)
    accentBar.ZIndex = frame.ZIndex + 2
    accentBar.Parent = frame
    local holder = paragraph.LabelHolder
    if holder then
        holder.Position = UDim2.fromOffset(12, 0)
        holder.Size = UDim2.new(1, -24, 0, 0)
        local icon = holder:FindFirstChild("Icon")
        local iconSize = opts.IconSize or 22
        if icon and icon:IsA("ImageLabel") and not holder:FindFirstChild("IconBadge") then
            local badge = Instance.new("Frame")
            badge.Name = "IconBadge"
            badge.LayoutOrder = icon.LayoutOrder
            badge.Size = UDim2.fromOffset(iconSize + 8, iconSize + 8)
            badge.BackgroundColor3 = opts.IconBadgeColor or accent
            badge.BackgroundTransparency = opts.IconBadgeTransparency or 0.78
            badge.BorderSizePixel = 0
            Instance.new("UICorner", badge).CornerRadius = UDim.new(1, 0)
            icon.Parent = badge
            icon.AnchorPoint = Vector2.new(0.5, 0.5)
            icon.Position = UDim2.fromScale(0.5, 0.5)
            icon.Size = UDim2.fromOffset(iconSize, iconSize)
            icon.ImageColor3 = opts.IconColor or accent
            badge.Parent = holder
        end
    end
    if paragraph.DescLabel then
        paragraph.DescLabel.LineHeight = 1.15
        paragraph.DescLabel.TextSize = 13
    end
end

function Kynox.bindDiscordParagraph(paragraph, inviteUrl, notify)
    if not paragraph or not paragraph.Frame then
        return
    end
    local frame = paragraph.Frame
    frame.Active = true
    for _, child in ipairs(frame:GetDescendants()) do
        if child:IsA("GuiObject") and child ~= frame then
            child.Active = false
        end
    end
    frame.MouseButton1Click:Connect(function()
        Kynox.openDiscordInvite(inviteUrl, notify)
    end)
end

function Kynox.getTitleBarHolder(titleBar)
    if not titleBar or not titleBar.Frame then
        return nil
    end
    for _, child in ipairs(titleBar.Frame:GetChildren()) do
        if child:IsA("Frame") and child:FindFirstChildOfClass("UIListLayout") then
            return child
        end
    end
    return nil
end

function Kynox.groupTitleBarLabels(holder)
    if not holder or holder:FindFirstChild("TitleGroup") then
        return holder and holder:FindFirstChild("TitleGroup")
    end
    local labels = {}
    for _, child in ipairs(holder:GetChildren()) do
        if child:IsA("TextLabel") then
            table.insert(labels, child)
        end
    end
    if #labels == 0 then
        return nil
    end
    table.sort(labels, function(a, b)
        return (a.TextTransparency or 0) < (b.TextTransparency or 0)
    end)
    local group = Instance.new("Frame")
    group.Name = "TitleGroup"
    group.BackgroundTransparency = 1
    group.AutomaticSize = Enum.AutomaticSize.XY
    group.Size = UDim2.fromScale(0, 0)
    group.LayoutOrder = 1
    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Horizontal
    list.VerticalAlignment = Enum.VerticalAlignment.Center
    list.HorizontalAlignment = Enum.HorizontalAlignment.Left
    list.Padding = UDim.new(0, 6)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = group
    for i, label in ipairs(labels) do
        label.Parent = group
        label.LayoutOrder = i
    end
    group.Parent = holder
    return group
end

function Kynox.alignTitleBar(window, branding)
    branding = branding or {}
    local holder = Kynox.getTitleBarHolder(window and window.TitleBar)
    if not holder then
        return
    end

    Kynox.groupTitleBarLabels(holder)

    local logoSize = branding.LogoSize or 24
    local titleSize = branding.TitleSize or 15
    local subTitleSize = branding.SubTitleSize or 12
    local rowHeight = math.max(logoSize, titleSize + 2, subTitleSize + 4)

    local list = holder:FindFirstChildOfClass("UIListLayout")
    if list then
        list.FillDirection = Enum.FillDirection.Horizontal
        list.VerticalAlignment = Enum.VerticalAlignment.Center
        list.HorizontalAlignment = Enum.HorizontalAlignment.Left
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Padding = UDim.new(0, 8)
    end

    local function styleTextLabel(label)
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.AutomaticSize = Enum.AutomaticSize.X
        label.Size = UDim2.new(0, 0, 0, rowHeight)
    end

    for _, child in ipairs(holder:GetChildren()) do
        if child.Name == "LogoWrap" then
            child.Size = UDim2.fromOffset(logoSize, rowHeight)
            local logo = child:FindFirstChild("Logo")
            if logo and logo:IsA("ImageLabel") then
                logo.AnchorPoint = Vector2.new(0.5, 0.5)
                logo.Position = UDim2.fromScale(0.5, 0.5)
                logo.Size = UDim2.fromOffset(logoSize, logoSize)
            end
        elseif child.Name == "TitleGroup" then
            child.Size = UDim2.new(0, 0, 0, rowHeight)
            child.AutomaticSize = Enum.AutomaticSize.X
            for _, label in ipairs(child:GetChildren()) do
                if label:IsA("TextLabel") then
                    styleTextLabel(label)
                end
            end
        elseif child:IsA("TextLabel") then
            styleTextLabel(child)
        end
    end
end

function Kynox.addTitleBarLogo(window, imageId, size)
    size = size or 20
    local titleBar = window.TitleBar
    if not titleBar then
        return
    end

    local holder = Kynox.getTitleBarHolder(titleBar)
    if not holder then
        return
    end

    local id = tostring(imageId):gsub("rbxassetid://", "")
    local wrap = Instance.new("Frame")
    wrap.Name = "LogoWrap"
    wrap.LayoutOrder = 0
    wrap.Size = UDim2.fromOffset(size, size)
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
    local holder = Kynox.getTitleBarHolder(window and window.TitleBar)
    if not holder then
        return
    end

    local titleFont = Font.new(
        "rbxasset://fonts/families/GothamSSm.json",
        Enum.FontWeight.SemiBold,
        Enum.FontStyle.Normal
    )

    for _, label in ipairs(holder:GetChildren()) do
        if label:IsA("TextLabel") then
            if label.TextTransparency >= 0.3 then
                label.TextSize = subTitleSize
            else
                label.TextSize = titleSize
                label.FontFace = titleFont
            end
        end
    end
    local titleGroup = holder:FindFirstChild("TitleGroup")
    if titleGroup then
        for _, label in ipairs(titleGroup:GetChildren()) do
            if label:IsA("TextLabel") then
                if label.TextTransparency >= 0.3 then
                    label.TextSize = subTitleSize
                else
                    label.TextSize = titleSize
                    label.FontFace = titleFont
                end
            end
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
    Kynox.alignTitleBar(window, branding)
    task.defer(function()
        Kynox.alignTitleBar(window, branding)
    end)
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
Kynox.UI_LIB = "https://raw.githubusercontent.com/kynox-devx/ui-lib/main/"

function Kynox.buildGithubUrls(base)
    base = base or Kynox.UI_LIB
    if base:sub(-1) ~= "/" then
        base = base .. "/"
    end
    return {
        ["Kynox.lua"] = base .. "Kynox.lua",
        ["main.lua"] = base .. "main.lua",
        ["SaveManager.lua"] = base .. "SaveManager.lua",
        ["InterfaceManager.lua"] = base .. "InterfaceManager.lua",
    }
end

function Kynox.loadInterfaceSettings()
    local defaults = {
        Theme = "Dark",
        Acrylic = false,
        Transparency = false,
        MenuKeybind = "LeftControl",
        ShowSessionTimer = true,
    }
    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        return defaults
    end
    Kynox.ensureConfigFolders()
    local path = Kynox.INTERFACE_FOLDER .. "/options.json"
    if not isfile(path) then
        return defaults
    end
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if ok and type(decoded) == "table" then
        for k, v in pairs(decoded) do
            defaults[k] = v
        end
        if decoded.ShowSessionTimer ~= nil then
            defaults.ShowSessionTimer = decoded.ShowSessionTimer == true
        end
    end
    return defaults
end

function Kynox.saveInterfaceSettings(settings)
    if type(writefile) ~= "function" then
        return false
    end
    Kynox.ensureConfigFolders()
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(settings)
    end)
    if not ok then
        return false
    end
    writefile(Kynox.INTERFACE_FOLDER .. "/options.json", encoded)
    return true
end

function Kynox.attachOverlay(opts)
    opts = opts or {}
    local settings = Kynox.loadInterfaceSettings()
    local timer = Kynox.createSessionTimer({
        StartTime = opts.StartTime or tick(),
        Visible = settings.ShowSessionTimer,
        Position = opts.Position,
    })

    local function setSessionTimerVisible(v)
        settings.ShowSessionTimer = v == true
        Kynox.saveInterfaceSettings(settings)
        timer.setVisible(settings.ShowSessionTimer)
    end

    return {
        Settings = settings,
        SessionTimer = timer,
        setSessionTimerVisible = setSessionTimerVisible,
        reloadSettings = function()
            settings = Kynox.loadInterfaceSettings()
            timer.setVisible(settings.ShowSessionTimer)
            return settings
        end,
    }
end

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
                if v.__color3 == true then
                    out[k] = { __color3 = true, R = v.R, G = v.G, B = v.B }
                else
                    out[k] = sanitizeConfigTable(v, exclude)
                end
            elseif typeof(v) == "Color3" then
                out[k] = { __color3 = true, R = v.R, G = v.G, B = v.B }
            elseif t == "boolean" or t == "string" then
                out[k] = v
            elseif t == "number" then
                if v == math.huge then
                    out[k] = "__huge__"
                elseif v == -math.huge then
                    out[k] = "__neg_huge__"
                else
                    out[k] = v
                end
            end
        end
    end
    return out
end

function Kynox.restoreConfigTable(tbl)
    if type(tbl) ~= "table" then
        return
    end
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            if v.__color3 == true then
                tbl[k] = Color3.new(tonumber(v.R) or 0, tonumber(v.G) or 0, tonumber(v.B) or 0)
            else
                Kynox.restoreConfigTable(v)
            end
        elseif v == "__huge__" then
            tbl[k] = math.huge
        elseif v == "__neg_huge__" then
            tbl[k] = -math.huge
        end
    end
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

    local function migrateLegacyConfig()
        local legacyPaths = cfg.LegacyPaths
        if type(legacyPaths) ~= "table" then
            return
        end
        if type(isfile) ~= "function" or type(readfile) ~= "function" or type(writefile) ~= "function" then
            return
        end
        if isfile(path) then
            return
        end
        for _, legacy in ipairs(legacyPaths) do
            if type(legacy) == "string" and isfile(legacy) then
                writefile(path, readfile(legacy))
                notify({
                    Title = cfg.NotifyTitle or "Kynox Hub",
                    Content = "Migrated config from legacy path.",
                    Duration = 4,
                })
                return
            end
        end
    end

    migrateLegacyConfig()

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
                Kynox.restoreConfigTable(decoded)
                mergeGameConfig(configs, decoded)
                Kynox.restoreConfigTable(configs)
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
        Kynox.restoreConfigTable(configs)
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

function Kynox.verifyKeyHttp(key, cfg)
    local url = cfg.VerifyUrl
    if not url or url == "" then
        return nil
    end

    local body
    if cfg.VerifyBody then
        body = cfg.VerifyBody(key)
    else
        local ok, encoded = pcall(function()
            return HttpService:JSONEncode({ key = key })
        end)
        body = ok and encoded or ('{"key":"' .. key:gsub('"', '\\"') .. '"}')
    end

    local method = (cfg.VerifyMethod or "POST"):upper()
    local headers = cfg.VerifyHeaders or { ["Content-Type"] = "application/json" }
    local req = (syn and syn.request) or http_request or (http and http.request) or request

    if type(req) ~= "function" then
        return false, "HTTP unavailable on this executor."
    end

    local ok, resp = pcall(function()
        return req({
            Url = url,
            Method = method,
            Headers = headers,
            Body = method == "GET" and nil or body,
        })
    end)

    if not ok or not resp then
        return false, "Could not reach key server."
    end

    if cfg.VerifyResponse then
        return cfg.VerifyResponse(resp, key)
    end

    local status = resp.StatusCode or resp.status or 0
    if status >= 200 and status < 300 then
        return true
    end
    return false, "Invalid key."
end

function Kynox.verifyKey(key, cfg)
    cfg = cfg or {}
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
    local httpResult, httpMsg = Kynox.verifyKeyHttp(key, cfg)
    if httpResult ~= nil then
        if httpResult == true then
            return true
        end
        return false, httpMsg or "Invalid key."
    end
    if cfg.RequireKey == false then
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

--[[
    Bootstrap hub ครั้งเดียว (โหลด lib, key, window, config, interface, timer, toggle)
    คืนค่า hub table — เกม/template เหลือแค่เติมแท็บฟีเจอร์
]]
function Kynox.initHub(cfg)
    cfg = cfg or {}
    local github = cfg.Github or Kynox.buildGithubUrls(cfg.UiLib)

    local Fluent = Kynox.loadModule("main.lua", github)
    local SaveManager = Kynox.loadModule("SaveManager.lua", github)
    local InterfaceManager = Kynox.loadModule("InterfaceManager.lua", github)

    getgenv().Kynox = getgenv().Kynox or {}
    if cfg.ConfigDefaults then
        getgenv().Kynox.Configs = getgenv().Kynox.Configs or cfg.ConfigDefaults
        for k, v in pairs(cfg.ConfigDefaults) do
            if getgenv().Kynox.Configs[k] == nil then
                getgenv().Kynox.Configs[k] = v
            end
        end
    else
        getgenv().Kynox.Configs = getgenv().Kynox.Configs or {}
    end

    local configs = getgenv().Kynox.Configs
    local hubCfg = cfg.CONFIG or cfg.Config or {}

    local function notify(data)
        if cfg.Notify then
            cfg.Notify(data)
        elseif Fluent then
            Fluent:Notify(data)
        end
    end

    if hubCfg.KeySystem and hubCfg.KeySystem.Enabled ~= false and cfg.SkipKey ~= true then
        local keyOk = Kynox.runKeySystem(hubCfg.KeySystem, notify)
        if not keyOk then
            return nil, "key_cancelled"
        end
    end

    local Window = Fluent:CreateWindow(Kynox.buildWindowOptions(hubCfg.Window))
    Kynox.setupBranding(Window, hubCfg.Branding, Fluent)

    local Tabs = {}
    local tabList = hubCfg.Tabs or {}
    for _, tab in ipairs(tabList) do
        Tabs[tab.Id] = Window:AddTab({ Title = tab.Title, Icon = tab.Icon })
    end

    local GameConfig = Kynox.setupGameConfig({
        Game = hubCfg.Game or cfg.Game or "Default",
        Configs = configs,
        Exclude = cfg.ConfigExclude,
        LegacyPaths = cfg.LegacyPaths,
        AfterLoad = cfg.AfterLoad,
        AfterReset = cfg.AfterReset,
        NotifyTitle = hubCfg.Window and hubCfg.Window.Title or "Kynox Hub",
    }, notify)

    getgenv().KynoxSaveConfig = GameConfig.SaveConfig
    GameConfig.LoadConfig()

    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes(cfg.SaveIgnoreIndexes or { "ShowSessionTimer" })
    InterfaceManager:SetFolder(Kynox.INTERFACE_FOLDER)

    local interfaceSettings = Kynox.loadInterfaceSettings()
    local SessionTimer = Kynox.createSessionTimer({
        StartTime = cfg.SessionStart or tick(),
        Visible = interfaceSettings.ShowSessionTimer == true,
    })

    if Tabs.Settings and cfg.SkipInterface ~= true then
        InterfaceManager:BuildInterfaceSection(Tabs.Settings, {
            onSessionTimerChanged = function(v)
                SessionTimer.setVisible(v)
            end,
        })

        if cfg.AutoResetButton ~= false then
            local settingsConfig = Tabs.Settings:AddSection("Config")
            settingsConfig:AddButton({
                Title = "Reset config",
                Description = "Restore defaults",
                Callback = function()
                    Window:Dialog({
                        Title = "Reset config?",
                        Content = "Overwrite:\n" .. GameConfig.Path,
                        Buttons = {
                            {
                                Title = "Reset",
                                Callback = function()
                                    GameConfig.ResetConfig()
                                end,
                            },
                            {
                                Title = "Cancel",
                                Callback = function() end,
                            },
                        },
                    })
                end,
            })
        end
    end

    Kynox.applyForcedInterfaceSettings(Fluent, InterfaceManager)

    if cfg.SelectTab ~= false then
        Window:SelectTab(1)
    end

    if cfg.SkipLoadedNotify ~= true then
        notify({
            Title = hubCfg.Window and hubCfg.Window.Title or "Kynox Hub",
            Content = "Loaded.",
            Duration = 5,
        })
    end

    if hubCfg.Toggle and cfg.SkipToggle ~= true then
        Kynox.createToggleGui(
            cfg.ToggleParent or game:GetService("CoreGui"),
            Window,
            hubCfg.Toggle
        )
    end

    if cfg.SkipPlatformLog ~= true then
        print("[Kynox UI] Platform:", Kynox.detectPlatform())
    end

    local hub = {
        Kynox = Kynox,
        Fluent = Fluent,
        SaveManager = SaveManager,
        InterfaceManager = InterfaceManager,
        Window = Window,
        Tabs = Tabs,
        Options = Fluent.Options,
        CFG = configs,
        Configs = configs,
        GameConfig = GameConfig,
        SessionTimer = SessionTimer,
        Github = github,
        notify = notify,
        SaveConfig = GameConfig.SaveConfig,
        LoadConfig = GameConfig.LoadConfig,
        ResetConfig = GameConfig.ResetConfig,
    }

    if cfg.OnReady then
        cfg.OnReady(hub)
    end

    return hub
end

return Kynox
