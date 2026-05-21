# Kynox UI Library

Fork of [Fluent](https://github.com/dawid-scripts/Fluent) for Kynox scripts.

**Repo:** https://github.com/kynox-devx/ui-lib  
**Branch:** `main`

## Load (production)

สคริปต์เกมโหลดจาก GitHub raw — แก้ lib ที่ repo นี้แล้ว `git push` ผู้ใช้ได้เวอร์ชันใหม่ทันที

```lua
local UI_LIB = "https://raw.githubusercontent.com/kynox-devx/ui-lib/main/"
local UI_GITHUB = {
    ["Kynox.lua"] = UI_LIB .. "Kynox.lua",
    ["main.lua"] = UI_LIB .. "main.lua",
    ["SaveManager.lua"] = UI_LIB .. "SaveManager.lua",
    ["InterfaceManager.lua"] = UI_LIB .. "InterfaceManager.lua",
}

local Kynox = loadstring(game:HttpGet(UI_GITHUB["Kynox.lua"]))()
local Fluent = Kynox.loadModule("main.lua", UI_GITHUB)
local SaveManager = Kynox.loadModule("SaveManager.lua", UI_GITHUB)
local InterfaceManager = Kynox.loadModule("InterfaceManager.lua", UI_GITHUB)
```

ดูตัวอย่างเต็มใน `Template/Kynox.lua` (ใน workspace KynoxScript)

## Files

| File | Description |
|------|-------------|
| `Kynox.lua` | Bootstrap — platform, config paths, key loader, session timer, branding, toggle |
| `main.lua` | Core UI (Fluent fork) |
| `SaveManager.lua` | Fluent option save/load (legacy; เกมใช้ `Kynox.setupGameConfig` เป็นหลัก) |
| `InterfaceManager.lua` | `KynoxConfigs/interface/options.json` — minimize bind, session timer |

## Config folders (executor workspace)

```
KynoxConfigs/
  KeySystem/key.txt
  games/<Game>.json
  interface/options.json
```

## พัฒนา lib

1. แก้ไฟล์ในโฟลเดอร์ `Ui/`
2. `git add` → `git commit` → `git push origin main`
3. รันสคริปต์เกมใหม่ (HttpGet ดึง raw ล่าสุด)
