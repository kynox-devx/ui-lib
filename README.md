# Kynox UI Library

Fork of [Fluent](https://github.com/dawid-scripts/Fluent) for Kynox scripts.

**Repo:** https://github.com/kynox-devx/ui-lib  
**Branch:** `main`

## Quick start (template)

```lua
local Kynox = loadstring(game:HttpGet("https://raw.githubusercontent.com/kynox-devx/ui-lib/main/Kynox.lua"))()
local UI_GITHUB = Kynox.buildGithubUrls()

if Kynox.guardDuplicate() then return end

local hub = Kynox.initHub({
    Github = UI_GITHUB,
    CONFIG = CONFIG,              -- Window, Branding, Toggle, Game, Tabs, KeySystem
    ConfigDefaults = { ... },     -- getgenv().Kynox.Configs defaults
    ConfigExclude = { PlayersESP = true },
    LegacyPaths = { "JinkX/old.json" },  -- optional migrate
})

local Window, Tabs, CFG = hub.Window, hub.Tabs, hub.CFG
-- เติมแท็บฟีเจอร์เกมที่นี่
```

ดูตัวอย่างเต็ม: `Template/Kynox.lua`

## WindUI / legacy scripts

```lua
local Kynox = loadstring(game:HttpGet(Kynox.UI_LIB .. "Kynox.lua"))()
local cfg = Kynox.setupGameConfig({
    Game = "Dueling Grounds",
    Configs = getgenv().JinkX.Configs,
    Exclude = { PlayersESP = true },
    LegacyPaths = { "JinkX/Dueling Grounds.json" },
}, notify)

local overlay = Kynox.attachOverlay()  -- session timer + interface/options.json
```

## Files

| File | Description |
|------|-------------|
| `Kynox.lua` | Bootstrap — `initHub`, config, key loader, session timer, overlay |
| `main.lua` | Fluent fork |
| `SaveManager.lua` | Fluent option save (legacy) |
| `InterfaceManager.lua` | `interface/options.json` |

## Config folders

```
KynoxConfigs/
  KeySystem/key.txt
  games/<Game>.json
  interface/options.json
```

## Key verify (optional)

```lua
KeySystem = {
    VerifyUrl = "https://api.example/verify",
    VerifyMethod = "POST",
    -- หรือ Verify = function(key) return true end
}
```

## Publish

```bash
cd Ui
git add -A
git commit -m "your message"
git push origin main
```
