--[[ Kynox Hub template – แก้ CONFIG + เติมฟีเจอร์ใน Main. Lib: github.com/kynox-devx/ui-lib ]]

-- ============ CONFIG ============
local CONFIG = {
    Window = {
        Title = "Kynox Hub",
        SubTitle = "Premium",
        TabWidth = 150,
        PcSize = UDim2.fromOffset(720, 480),
        MobileSize = UDim2.fromOffset(480, 380),
        Acrylic = false,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.LeftControl,
    },
    Branding = {
        Logo = "rbxassetid://88248132424560",
        LogoSize = 24,
        TitleSize = 13,
        SubTitleSize = 11,
        Transparency = false,
    },
    Discord = {
        Url = "https://discord.com/invite/tw9Zkc8j6b",
        Icon = "rbxassetid://84828491431270",
        IconColor = Color3.fromRGB(96, 205, 255),
        IconSize = 34,
        Title = '<font color="#60CDFF"><b>Discord</b></font><font color="#8A9199"> Community</font>',
        Content = '<font color="#E8EAED">- discord.gg/tw9Zkc8j6b</font>',
    },
    Toggle = {
        Image = "rbxassetid://78756412031557",
        Size = 50,
        Position = UDim2.new(0.06, 0, 0.08, 0),
    },
    Game = "Template Demo",
    Tabs = {
        { Id = "Main", Title = "Main", Icon = "home" },
        { Id = "Demo", Title = "Demo", Icon = "layout-grid" },
        { Id = "Settings", Title = "Settings", Icon = "settings" },
    },
    KeySystem = {
        Enabled = true,
        Title = "Kynox Hub",
        Subtitle = "Enter your license key",
        Placeholder = "Paste your key here...",
        Logo = "rbxassetid://88248132424560",
        GetKeyUrl = "https://discord.com/invite/tw9Zkc8j6b",
        GetKeyText = "Get Key",
        SubmitText = "Submit",
        SaveKey = true,
        KeyFile = "key.txt",
        KickOnClose = false,
        -- VerifyUrl = "https://your-api/verify",
        -- Verify = function(key) return true end,
    },
}

-- ค่าเริ่มต้น + เซฟลง KynoxConfigs/games/<Game>.json
local CONFIG_DEFAULTS = {
    ["DemoToggle"] = false,
    ["DemoSlider"] = 2,
    ["DemoDropdown"] = "two",
    ["DemoMulti"] = {
        ["one"] = false,
        ["two"] = true,
        ["three"] = true,
    },
}

-- ============ Load (GitHub) ============
local Kynox = loadstring(game:HttpGet("https://raw.githubusercontent.com/kynox-devx/ui-lib/main/Kynox.lua"))()

if Kynox.guardDuplicate() then
    return
end

local hub = Kynox.initHub({
    Github = Kynox.buildGithubUrls(),
    CONFIG = CONFIG,
    ConfigDefaults = CONFIG_DEFAULTS,
})

if not hub then
    return
end

local Window = hub.Window
local Tabs = hub.Tabs
local CFG = hub.CFG
local Options = hub.Options
local notify = hub.notify

-- ============ Main ============
do
    Tabs.Main:AddParagraph({
        Title = "Kynox Hub",
        Content = "Game features here. See Demo tab for UI samples.",
    })

    local community = Tabs.Main:AddSection("Community")
    local discordParagraph = community:AddParagraph({
        Icon = CONFIG.Discord.Icon,
        IconColor = CONFIG.Discord.IconColor,
        IconSize = CONFIG.Discord.IconSize,
        Title = CONFIG.Discord.Title,
        Content = CONFIG.Discord.Content,
    })
    Kynox.bindDiscordParagraph(discordParagraph, CONFIG.Discord.Url, notify)

    Tabs.Main:AddSection("Features"):AddParagraph({
        Title = "Your mods",
        Content = "Add toggles and sliders in this tab.",
    })
end

-- ============ Demo (ตัวอย่าง — ไม่ต้อง copy ทั้งแท็บไปเกมจริง) ============
do
    local configSection = Tabs.Demo:AddSection("Config & Save")
    configSection:AddParagraph({
        Title = "Config path",
        Content = "KynoxConfigs/games/" .. CONFIG.Game .. ".json",
    })

    configSection:AddToggle("DemoToggle", {
        Title = "Demo toggle",
        Description = "Default = CFG, Callback = SaveConfig",
        Default = CFG.DemoToggle,
        Callback = function(v)
            CFG.DemoToggle = v
            hub.SaveConfig()
        end,
    })

    configSection:AddSlider("DemoSlider", {
        Title = "Demo slider",
        Default = CFG.DemoSlider,
        Min = 0,
        Max = 10,
        Rounding = 1,
        Callback = function(v)
            CFG.DemoSlider = v
            hub.SaveConfig()
        end,
    })

    configSection:AddDropdown("DemoDropdown", {
        Title = "Demo dropdown",
        Values = { "one", "two", "three" },
        Default = CFG.DemoDropdown,
        Callback = function(v)
            CFG.DemoDropdown = v
            hub.SaveConfig()
        end,
    })

    configSection:AddDropdown("DemoMulti", {
        Title = "Demo multi dropdown",
        Values = { "one", "two", "three", "four" },
        Multi = true,
        Default = CFG.DemoMulti,
        Callback = function(v)
            CFG.DemoMulti = Kynox.copyMultiDropdownValue(v)
            hub.SaveConfig()
        end,
    })

    configSection:AddButton({
        Title = "Save now",
        Description = "Manual save",
        Callback = function()
            hub.SaveConfig()
            notify({
                Title = "Config",
                Content = "Saved to " .. hub.GameConfig.Path,
                Duration = 4,
            })
        end,
    })

    local uiSection = Tabs.Demo:AddSection("UI Components")
    uiSection:AddParagraph({
        Title = "UI samples",
        Content = "Not saved to config — copy patterns you need.",
    })

    uiSection:AddButton({
        Title = "Button",
        Description = "Opens a dialog",
        Callback = function()
            Window:Dialog({
                Title = "Dialog",
                Content = "Example dialog",
                Buttons = {
                    {
                        Title = "Confirm",
                        Callback = function()
                            print("Confirmed.")
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

    local Toggle = uiSection:AddToggle("MyToggle", { Title = "Toggle", Default = false })
    Toggle:OnChanged(function()
        print("MyToggle:", Options.MyToggle.Value)
    end)

    local Slider = uiSection:AddSlider("Slider", {
        Title = "Slider",
        Default = 2,
        Min = 0,
        Max = 5,
        Rounding = 1,
        Callback = function(v)
            print("Slider:", v)
        end,
    })
    Slider:SetValue(3)

    local Dropdown = uiSection:AddDropdown("Dropdown", {
        Title = "Dropdown",
        Values = { "one", "two", "three", "four", "five" },
        Default = 1,
    })
    Dropdown:SetValue("four")

    local MultiDropdown = uiSection:AddDropdown("MultiDropdown", {
        Title = "Multi dropdown",
        Values = { "one", "two", "three", "four", "five" },
        Multi = true,
        Default = { seven = false, twelve = false },
    })
    MultiDropdown:SetValue({ three = true, five = true })

    uiSection:AddColorpicker("Colorpicker", {
        Title = "Colorpicker",
        Default = Color3.fromRGB(96, 205, 255),
    })

    uiSection:AddColorpicker("TransparencyColorpicker", {
        Title = "Colorpicker (alpha)",
        Transparency = 0,
        Default = Color3.fromRGB(96, 205, 255),
    })

    local Keybind = uiSection:AddKeybind("Keybind", {
        Title = "Keybind",
        Mode = "Toggle",
        Default = "LeftControl",
    })
    Keybind:SetValue("MB2", "Toggle")

    uiSection:AddInput("Input", {
        Title = "Input",
        Default = "Default",
        Placeholder = "Placeholder",
        Finished = false,
    })
end
