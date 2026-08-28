do
	local g = (getgenv and getgenv()) or _G
	if rawget(g, "__KYNOX_HUB_READY") == true then
		warn("[Kynox] Hub already running")
		return
	end
end

local obsidianBase = "https://api.kynoxhub.pro/wl/obsidian/"
Library = loadstring(game:HttpGet(obsidianBase .. "Library.lua"))()
ThemeManager = loadstring(game:HttpGet(obsidianBase .. "addons/ThemeManager.lua"))()
SaveManager = loadstring(game:HttpGet(obsidianBase .. "addons/SaveManager.lua"))()

local KYNOX_LUCIDE_SOURCES = {
	"https://api.kynoxhub.pro/wl/lucide/source.lua",
	"https://gitlab.com/upio/lucide-roblox-direct/-/raw/main/source.lua",
}
local KYNOX_LUCIDE_SPRITESHEET_BASE = "https://api.kynoxhub.pro/wl/lucide/spritesheets/"
local KYNOX_LUCIDE_MIN_PNG_BYTES = 8192
local KYNOX_ICONIFY_BASE = "https://api.iconify.design/lucide/%s.png?width=64&height=64"

function kynoxLucideHttpRequest(opts)
	local req = (syn and syn.request) or request or (http and http.request) or (fluxus and fluxus.request)
	if not req then
		return nil
	end
	return req(opts)
end

function kynoxLucideFetchBinary(url)
	local res = kynoxLucideHttpRequest({ Url = url, Method = "GET" })
	if res and res.Body and #res.Body >= KYNOX_LUCIDE_MIN_PNG_BYTES then
		return res.Body
	end

	local ok, body = pcall(function()
		return game:HttpGet(url, true)
	end)
	if ok and body and #body >= KYNOX_LUCIDE_MIN_PNG_BYTES then
		return body
	end

	local ok2, body2 = pcall(function()
		return game:HttpGet(url)
	end)
	if ok2 and body2 and #body2 >= KYNOX_LUCIDE_MIN_PNG_BYTES then
		return body2
	end

	return nil
end

function createKynoxIconifyLucideModule()
	return {
		Icons = {},
		GetAsset = function(iconName)
			if type(iconName) ~= "string" or iconName == "" then
				return nil
			end
			return {
				IconName = iconName,
				Url = string.format(KYNOX_ICONIFY_BASE, iconName),
				ImageRectOffset = Vector2.new(0, 0),
				ImageRectSize = Vector2.new(0, 0),
			}
		end,
	}
end

function kynoxIconifyLucideAvailable()
	local req = kynoxLucideHttpRequest
	if not req then
		return false
	end
	local ok, res = pcall(function()
		return req({
			Url = string.format(KYNOX_ICONIFY_BASE, "check"),
			Method = "GET",
		})
	end)
	return ok and res and res.Body and #res.Body > 80
end

function ensureKynoxLucideSpritesheets()
	if not (writefile and isfolder and makefolder and isfile and readfile) then
		return false
	end

	local ok = pcall(function()
		if not isfolder("lucide-icons") then
			makefolder("lucide-icons")
		end

		for spritesheet = 1, 2 do
			local path = "lucide-icons/" .. spritesheet .. ".png"
			local needsDownload = true

			if isfile(path) then
				local existing = readfile(path)
				if existing and #existing >= KYNOX_LUCIDE_MIN_PNG_BYTES then
					needsDownload = false
				end
			end

			if needsDownload then
				local body = kynoxLucideFetchBinary(KYNOX_LUCIDE_SPRITESHEET_BASE .. spritesheet .. ".png")
				if body then
					writefile(path, body)
				end
			end
		end
	end)

	return ok
end

function refreshObsidianLucideIcons(library)
	if type(library) ~= "table" or type(library.TabButtons) ~= "table" then
		return
	end

	for i, tabDef in ipairs(CONFIG.Tabs) do
		local entry = library.TabButtons[i]
		local iconName = tabDef and tabDef.Icon
		if entry and entry.Icon and iconName and type(library.GetCustomIcon) == "function" then
			local custom = library:GetCustomIcon(iconName)
			if custom then
				entry.Icon.Image = custom.Url
				entry.Icon.ImageRectOffset = custom.ImageRectOffset
				entry.Icon.ImageRectSize = custom.ImageRectSize
			end
		end
	end
end

function applyKynoxObsidianLucideModule(library, iconsMod)
	if type(library) ~= "table" or type(iconsMod) ~= "table" or type(iconsMod.GetAsset) ~= "function" then
		return false
	end

	if type(library.SetIconModule) == "function" then
		library:SetIconModule(iconsMod)
	else
		library.GetIcon = function(_, iconName)
			local success, icon = pcall(iconsMod.GetAsset, iconName)
			return success and icon or nil
		end
	end

	refreshObsidianLucideIcons(library)
	return true
end

function installKynoxObsidianLucide(library)
	if type(library) ~= "table" then
		return false
	end

	if kynoxIconifyLucideAvailable() then
		return applyKynoxObsidianLucideModule(library, createKynoxIconifyLucideModule())
	end

	ensureKynoxLucideSpritesheets()

	for _, url in ipairs(KYNOX_LUCIDE_SOURCES) do
		local ok, iconsMod = pcall(function()
			return loadstring(game:HttpGet(url))()
		end)
		if ok and applyKynoxObsidianLucideModule(library, iconsMod) then
			return true
		end
	end

	warn("[Kynox] Lucide icons unavailable (Obsidian UI may show blank icons)")
	return false
end

installKynoxObsidianLucide(Library)

function extendObsidianSaveManager(saveManager)
	if type(saveManager) ~= "table" or type(saveManager.Parser) ~= "table" then
		return
	end
	local dropdownParser = saveManager.Parser.Dropdown
	if dropdownParser and dropdownParser._kynoxSafeMulti ~= true then
		dropdownParser.Load = function(idx, data)
			local option = saveManager.Options and saveManager.Options[idx]
			if not option or type(option.SetValue) ~= "function" then
				return
			end
			local value = data and data.value
			if idx == "WildPetTargetMode" and value == "Nearest" then
				value = "Location"
			end
			if option.Multi == true then
				if type(value) == "string" and value ~= "" then
					value = { [value] = true }
				elseif type(value) ~= "table" then
					value = {}
				else
					local out = {}
					for key, on in pairs(value) do
						if type(key) == "string" and key ~= "" and on == true then
							out[key] = true
						end
					end
					value = out
				end
			end
			option:SetValue(value)
		end
		dropdownParser._kynoxSafeMulti = true
	end
	if saveManager.Parser.KeyPicker then
		return
	end
	saveManager.Parser.KeyPicker = {
		Save = function(idx, object)
			return {
				type = "KeyPicker",
				idx = idx,
				mode = object.Mode or "Toggle",
				key = object.Value,
				modifiers = object.Modifiers,
			}
		end,
		Load = function(idx, data)
			local option = saveManager.Options and saveManager.Options[idx]
			if not option or type(option.SetValue) ~= "function" then
				return
			end
			local key = data.key
			if type(key) ~= "string" or key == "" or key == "None" then
				return
			end
			local mode = data.mode or "Toggle"
			local modifiers = type(data.modifiers) == "table" and data.modifiers or {}
			option:SetValue({ key, mode, modifiers })
		end,
	}
end

extendObsidianSaveManager(SaveManager)

Options = Library.Options
Toggles = Library.Toggles
