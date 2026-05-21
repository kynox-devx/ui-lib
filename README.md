# Kynox UI Library

Fork of [Fluent](https://github.com/dawid-scripts/Fluent) for Kynox scripts.

**Repo:** https://github.com/kynox-devx/ui-lib  
**Branch:** `main`

## โครงสร้าง repo

| Path | คำอธิบาย |
|------|----------|
| `Kynox.lua` | Bootstrap — `initHub`, config, key loader, session timer |
| `main.lua` | Fluent fork |
| `SaveManager.lua` | Fluent save (legacy) |
| `InterfaceManager.lua` | `KynoxConfigs/interface/options.json` |
| `Template/Kynox.lua` | สคริปต์ต้นแบบสร้างเกมใหม่ |

## ใช้ template

**แก้ไฟล์ในเครื่อง:** `KynoxScript/Template/Kynox.lua` (workspace)  
**หรือดึงจาก GitHub:**

```lua
loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/kynox-devx/ui-lib/main/Template/Kynox.lua"
))()
```

## Quick start (เขียนเอง)

```lua
local Kynox = loadstring(game:HttpGet("https://raw.githubusercontent.com/kynox-devx/ui-lib/main/Kynox.lua"))()
if Kynox.guardDuplicate() then return end

local hub = Kynox.initHub({
    Github = Kynox.buildGithubUrls(),
    CONFIG = CONFIG,
    ConfigDefaults = { MyToggle = false },
})

-- UI: Default = CFG.xxx แล้ว Callback -> CFG.xxx = v; hub.SaveConfig()
```

## Config (executor workspace)

```
KynoxConfigs/
  KeySystem/key.txt
  games/<Game>.json
  interface/options.json
```

## WindUI (เกมเก่า เช่น Dueling Grounds)

```lua
local Kynox = loadstring(game:HttpGet(Kynox.UI_LIB .. "Kynox.lua"))()
Kynox.setupGameConfig({
    Game = "Dueling Grounds",
    Configs = getgenv().JinkX.Configs,
    Exclude = { PlayersESP = true },
    LegacyPaths = { "JinkX/Dueling Grounds.json" },
}, notify)

local overlay = Kynox.attachOverlay()
```

## Publish

```bash
cd Ui
git add -A
git commit -m "your message"
git push origin main
```

รันสคริปต์ใหม่หลัง push (raw GitHub อาจ cache ~1 นาที)
