SliderUi = {}

function SliderUi.findSliderBar(holder)
	for _, child in ipairs(holder:GetChildren()) do
		if child:IsA("TextButton") then
			return child
		end
	end
	return nil
end

function SliderUi.findSliderDisplayLabel(bar)
	for _, child in ipairs(bar:GetChildren()) do
		if child:IsA("TextLabel") then
			return child
		end
	end
	return nil
end

function SliderUi.findSliderInputTextBox(bar)
	for _, child in ipairs(bar:GetChildren()) do
		if child:IsA("TextBox") then
			return child
		end
	end
	return nil
end

function SliderUi.openValueInput(slider, displayLabel, inputTextBox)
	if slider.Disabled or not inputTextBox or not displayLabel then
		return
	end
	inputTextBox.Text = tostring(slider.Value)
	inputTextBox.Visible = true
	displayLabel.Visible = false
	task.spawn(inputTextBox.CaptureFocus, inputTextBox)
end

function SliderUi.attachValueClickInput(slider)
	if typeof(slider) ~= "table" or slider.Type ~= "Slider" or slider._valueClickInputHooked then
		return
	end
	local holder = slider.Holder
	if not holder then
		return
	end
	local bar = SliderUi.findSliderBar(holder)
	if not bar then
		return
	end
	local displayLabel = SliderUi.findSliderDisplayLabel(bar)
	local inputTextBox = SliderUi.findSliderInputTextBox(bar)
	if not displayLabel or not inputTextBox then
		return
	end
	if bar:FindFirstChild("ValueClickInput") then
		return
	end

	slider._valueClickInputHooked = true

	local clickTarget = Instance.new("TextButton")
	clickTarget.Name = "ValueClickInput"
	clickTarget.BackgroundTransparency = 1
	clickTarget.BorderSizePixel = 0
	clickTarget.Text = ""
	clickTarget.AutoButtonColor = false
	clickTarget.ZIndex = 5
	clickTarget.AnchorPoint = Vector2.new(0.5, 0.5)
	clickTarget.Position = UDim2.fromScale(0.5, 0.5)
	clickTarget.Size = UDim2.new(0, 64, 1, 0)
	clickTarget.Parent = bar

	function syncClickTarget()
		local width = displayLabel.TextBounds.X
		if width > 0 then
			clickTarget.Size = UDim2.new(0, math.clamp(width + 10, 40, math.max(40, bar.AbsoluteSize.X - 8)), 1, 0)
		end
	end

	syncClickTarget()
	table.insert(slider.Connections, displayLabel:GetPropertyChangedSignal("Text"):Connect(syncClickTarget))
	table.insert(slider.Connections, displayLabel:GetPropertyChangedSignal("TextBounds"):Connect(syncClickTarget))
	table.insert(slider.Connections, clickTarget.MouseButton1Click:Connect(function()
		SliderUi.openValueInput(slider, displayLabel, inputTextBox)
	end))
end

function SliderUi.attachAllExisting()
	for _, option in pairs(Options) do
		if typeof(option) == "table" and option.Type == "Slider" then
			SliderUi.attachValueClickInput(option)
		end
	end
end

ConfigAuto = {
	Name = GAME_SLUG .. "-ui",
	_loading = false,
	_saveManager = nil,
}

function ConfigAuto.getFilePath()
	return GAME_CONFIG_UI_PATH
end

function ConfigAuto.isAppearanceIndex(idx)
	return ConfigAuto.APPEARANCE_KEYS[idx] == true or idx == "MenuKeybind"
end

function ConfigAuto.queueSave()
	if ConfigAuto._loading then
		return
	end
	if type(SaveUiConfig) == "function" then
		SaveUiConfig()
	end
end

function ConfigAuto.hookElement(element)
	if typeof(element) ~= "table" or typeof(element.OnChanged) ~= "function" then
		return
	end
	if element._configAutoHooked then
		return
	end
	element._configAutoHooked = true
	local prevChanged = element.Changed
	element:OnChanged(function(value)
		if ConfigAuto._loading then
			return
		end
		if type(prevChanged) == "function" then
			prevChanged(value)
		end
		ConfigAuto.queueSave()
	end)
end

ConfigAuto.APPEARANCE_KEYS = {
	BackgroundColor = true,
	MainColor = true,
	AccentColor = true,
	OutlineColor = true,
	FontColor = true,
	FontFace = true,
	UIOpacity = true,
}

ConfigAuto.UI_ONLY_KEYS = {
	NotificationSide = true,
	DPIDropdown = true,
	MenuKeybind = true,
}

ConfigAuto.UI_COLOR_KEYS = {
	"BackgroundColor",
	"MainColor",
	"AccentColor",
	"OutlineColor",
	"FontColor",
}

function ConfigAuto.captureUiSnapshot()
	local out = { rev = 1 }
	for _, key in ipairs(ConfigAuto.UI_COLOR_KEYS) do
		local opt = Options and Options[key]
		if opt and typeof(opt.Value) == "Color3" then
			out[key] = opt.Value:ToHex()
			if typeof(opt.Transparency) == "number" then
				out[key .. "_T"] = opt.Transparency
			end
		end
	end
	if Options and Options.FontFace then
		out.FontFace = Options.FontFace.Value
	end
	if Options and Options.UIOpacity then
		out.UIOpacity = Options.UIOpacity.Value
	end
	if Options and Options.MenuKeybind then
		out.MenuKeybind = {
			key = Options.MenuKeybind.Value,
			mode = Options.MenuKeybind.Mode or "Toggle",
			modifiers = Options.MenuKeybind.Modifiers or {},
		}
	end
	if Options and Options.NotificationSide then
		out.NotificationSide = Options.NotificationSide.Value
	end
	if Options and Options.DPIDropdown then
		out.DPIDropdown = Options.DPIDropdown.Value
	end
	return out
end

function ConfigAuto.applyUiSnapshot(data)
	if type(data) ~= "table" then
		return
	end

	ConfigAuto._loading = true
	for _, key in ipairs(ConfigAuto.UI_COLOR_KEYS) do
		local hex = data[key]
		local opt = Options and Options[key]
		if type(hex) == "string" and opt and type(opt.SetValueRGB) == "function" then
			pcall(function()
				local transparency = tonumber(data[key .. "_T"])
				if transparency == nil then
					transparency = 0
				end
				opt:SetValueRGB(Color3.fromHex(hex), transparency)
			end)
		end
	end
	if type(data.FontFace) == "string" and Options and Options.FontFace then
		pcall(function()
			Options.FontFace:SetValue(data.FontFace)
		end)
	end
	if data.UIOpacity ~= nil and Options and Options.UIOpacity then
		pcall(function()
			Options.UIOpacity:SetValue(tonumber(data.UIOpacity) or 100)
		end)
	end
	if type(data.MenuKeybind) == "table" and Options and Options.MenuKeybind then
		local bind = data.MenuKeybind
		local key = bind.key
		if type(key) == "string" and key ~= "" and key ~= "None" then
			pcall(function()
				Options.MenuKeybind:SetValue({
					key,
					bind.mode or "Toggle",
					type(bind.modifiers) == "table" and bind.modifiers or {},
				})
			end)
		end
	end
	if type(data.NotificationSide) == "string" and Options and Options.NotificationSide then
		pcall(function()
			Options.NotificationSide:SetValue(data.NotificationSide)
		end)
		if type(Library.SetNotifySide) == "function" then
			pcall(function()
				Library:SetNotifySide(data.NotificationSide)
			end)
		end
	end
	if type(data.DPIDropdown) == "string" and Options and Options.DPIDropdown then
		pcall(function()
			Options.DPIDropdown:SetValue(data.DPIDropdown)
		end)
		local dpiText = string.gsub(data.DPIDropdown, "%%", "")
		local dpi = tonumber(dpiText)
		if dpi and type(Library.SetDPIScale) == "function" then
			pcall(function()
				Library:SetDPIScale(dpi)
			end)
		end
	end
	ConfigAuto._loading = false
end

function ConfigAuto.applyUiObject(sm, obj)
	if type(obj) ~= "table" or type(obj.idx) ~= "string" then
		return
	end
	if CONFIG_DEFAULTS[obj.idx] ~= nil or obj.idx == "UILanguage" then
		return
	end
	local parser = type(sm.Parser) == "table" and sm.Parser or nil
	if not parser then
		return
	end
	local entryParser = parser[obj.type]
	if entryParser and entryParser.Load then
		entryParser.Load(obj.idx, obj)
	end
end

function ConfigAuto.loadObsidianUiFormat(decoded)
	if type(decoded) ~= "table" or type(decoded.objects) ~= "table" then
		return false
	end
	local sm = ConfigAuto._saveManager
	if not sm then
		return false
	end
	ConfigAuto._loading = true
	for _, obj in ipairs(decoded.objects) do
		ConfigAuto.applyUiObject(sm, obj)
	end
	ConfigAuto._loading = false
	return true
end

function SaveUiConfig()
	if ConfigAuto._loading or type(writefile) ~= "function" then
		return false
	end
	if makefolder then
		pcall(makefolder, "KynoxHub")
		pcall(makefolder, "KynoxHub/settings")
		pcall(makefolder, "KynoxHub/settings/Games")
	end
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(ConfigAuto.captureUiSnapshot())
	end)
	if not ok then
		return false
	end
	return pcall(writefile, GAME_CONFIG_UI_PATH, encoded) == true
end

function LoadUiConfig()
	if type(isfile) ~= "function" or type(readfile) ~= "function" or not isfile(GAME_CONFIG_UI_PATH) then
		return false
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(readfile(GAME_CONFIG_UI_PATH))
	end)
	if not ok or type(decoded) ~= "table" then
		return false
	end
	if type(decoded.objects) == "table" then
		return ConfigAuto.loadObsidianUiFormat(decoded)
	end
	ConfigAuto.applyUiSnapshot(decoded)
	return true
end

function ConfigAuto.shouldPersistInUiFile(idx)
	if CONFIG_DEFAULTS[idx] ~= nil or idx == "UILanguage" then
		return false
	end
	return ConfigAuto.isAppearanceIndex(idx) or ConfigAuto.UI_ONLY_KEYS[idx] == true
end

function ConfigAuto.installAllHooks(library, _saveManager)
	for idx, option in pairs(library.Options) do
		if ConfigAuto.shouldPersistInUiFile(idx) then
			ConfigAuto.hookElement(option)
		end
	end
	for idx, toggle in pairs(library.Toggles) do
		if ConfigAuto.shouldPersistInUiFile(idx) then
			ConfigAuto.hookElement(toggle)
		end
	end
end

function ConfigAuto.load()
	if not LoadUiConfig() then
		SaveUiConfig()
	end
end

function ConfigAuto.reset(library)
	if type(delfile) == "function" then
		pcall(delfile, GAME_CONFIG_UI_PATH)
	end
	ConfigAuto._loading = true
	for idx, option in pairs(library.Options) do
		if ConfigAuto.shouldPersistInUiFile(idx) and option.Default ~= nil and option.SetValue then
			option:SetValue(option.Default)
		end
	end
	for idx, toggle in pairs(library.Toggles) do
		if ConfigAuto.shouldPersistInUiFile(idx) and toggle.Default ~= nil and toggle.SetValue then
			toggle:SetValue(toggle.Default)
		end
	end
	ConfigAuto._loading = false
	SaveUiConfig()
end

function ConfigAuto.hookMenuKeybind()
	if typeof(Options) == "table" and typeof(Options.MenuKeybind) == "table" then
		ConfigAuto.hookElement(Options.MenuKeybind)
	end
end

HubToggle = { visible = true }

function ConfigAuto.applyMenuKeybind()
	if typeof(Options) ~= "table" or typeof(Options.MenuKeybind) ~= "table" then
		return
	end
	MenuBind.normalizeSingleKeyPicker(Options.MenuKeybind, CONFIG.Window.MinimizeKey.Name, Library, "Menu bind")
	Library.ToggleKeybind = Options.MenuKeybind
	pcall(function()
		Options.MenuKeybind:Update()
	end)
	task.defer(function()
		for _ = 1, 8 do
			if Options.MenuKeybind._menuBindHijacked then
				break
			end
			MenuBind.hijackKeyPicker(Options.MenuKeybind, Library, "Menu bind")
			task.wait(0.1)
		end
		pcall(function()
			Options.MenuKeybind:Update()
		end)
	end)
end

function ConfigAuto.setup(saveManager, library)
	ConfigAuto._saveManager = saveManager
	saveManager:SetFolder("KynoxHub")
	saveManager:SetSubFolder("Games")
	ConfigAuto.hookMenuKeybind()
end

function ConfigAuto.loadAfterUi()
	ConfigAuto.load()

	local function finish()
		applyAppearance()
		if Options and Options.UIOpacity then
			applyUIOpacity(Options.UIOpacity.Value)
		end
		if Options and Options.FontFace and typeof(Options.FontFace.Value) == "string" and Enum.Font[Options.FontFace.Value] then
			pcall(function()
				Library:SetFont(Enum.Font[Options.FontFace.Value])
			end)
		end
	end

	finish()
	task.defer(function()
		task.wait(0.08)
		ConfigAuto.applyMenuKeybind()
		finish()
	end)
end

MenuBind = {}

MenuBind.MOUSE_BINDS = {
	MB1 = true,
	MB2 = true,
	MB3 = true,
}

MenuBind.MODIFIER_KEYS = {
	"LAlt",
	"RAlt",
	"LShift",
	"RShift",
	"Tab",
	"CapsLock",
}

MenuBind.MODIFIER_AS_KEY = {
	LAlt = "LeftAlt",
	RAlt = "RightAlt",
	LCtrl = "LeftControl",
	RCtrl = "RightControl",
	LeftControl = "LeftControl",
	RightControl = "RightControl",
	LShift = "LeftShift",
	RShift = "RightShift",
	LeftShift = "LeftShift",
	RightShift = "RightShift",
	Tab = "Tab",
	CapsLock = "CapsLock",
}

MenuBind.INPUT_MOUSE_NAMES = {
	[Enum.UserInputType.MouseButton1] = "MB1",
	[Enum.UserInputType.MouseButton2] = "MB2",
	[Enum.UserInputType.MouseButton3] = "MB3",
}

function MenuBind.canonicalKey(key)
	if typeof(key) ~= "string" then
		return nil
	end
	return MenuBind.MODIFIER_AS_KEY[key] or key
end

function MenuBind.isKeyboardKey(key)
	key = MenuBind.canonicalKey(key)
	return typeof(key) == "string" and key ~= "" and key ~= "None" and key ~= "Unknown" and not MenuBind.MOUSE_BINDS[key]
end

function MenuBind.resolvePrimaryKey(key, modifiers)
	local canon = MenuBind.canonicalKey(key)
	if MenuBind.isKeyboardKey(canon) then
		return canon
	end
	if type(modifiers) == "table" then
		for _, mod in ipairs(modifiers) do
			local promoted = MenuBind.canonicalKey(mod)
			if promoted and MenuBind.MODIFIER_AS_KEY[mod] then
				return promoted
			end
		end
	end
	return nil
end

function MenuBind.keyNameFromInput(input)
	if typeof(input) ~= "Instance" or not input:IsA("InputObject") then
		return nil
	end

	local mouseName = MenuBind.INPUT_MOUSE_NAMES[input.UserInputType]
	if mouseName then
		return mouseName
	end

	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.Escape then
			return "None"
		end
		return input.KeyCode.Name
	end

	return nil
end

function MenuBind.isInputDown(input)
	if typeof(input) ~= "Instance" or not input:IsA("InputObject") then
		return false
	end
	if MenuBind.INPUT_MOUSE_NAMES[input.UserInputType] then
		return UserInputService:IsMouseButtonPressed(input.UserInputType)
	end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		return UserInputService:IsKeyDown(input.KeyCode)
	end
	return false
end

function MenuBind.findPickerButton(library, labelText)
	local main = library.ScreenGui and library.ScreenGui:FindFirstChild("Main")
	if not main or typeof(labelText) ~= "string" then
		return nil
	end
	for _, inst in ipairs(main:GetDescendants()) do
		if inst:IsA("TextLabel") and inst.Text == labelText then
			for _, child in ipairs(inst:GetChildren()) do
				if child:IsA("TextButton") then
					return child
				end
			end
		end
	end
	if typeof(Options) == "table" and typeof(Options.MenuKeybind) == "table" then
		local picker = Options.MenuKeybind.Picker or Options.MenuKeybind.TextHolder
		if typeof(picker) == "Instance" and picker:IsA("TextButton") then
			return picker
		end
	end
	return nil
end

function MenuBind.runSingleKeyPick(keyPicker, picker, library)
	if library.IsPicking or keyPicker._menuBindPicking then
		return
	end

	keyPicker._menuBindPicking = true
	library.IsPicking = true
	picker.Text = "..."
	picker.Size = UDim2.fromOffset(29, 18)

	local captured
	local captureConn = UserInputService.InputBegan:Connect(function(input)
		if UserInputService:GetFocusedTextBox() then
			return
		end
		if not captured then
			captured = input
		end
	end)

	repeat
		task.wait()
	until captured ~= nil

	captureConn:Disconnect()
	keyPicker._menuBindPicking = false
	library.IsPicking = false

	local key = MenuBind.keyNameFromInput(captured)
	if key == "None" or not MenuBind.isKeyboardKey(key) then
		pcall(function()
			keyPicker:Update()
		end)
		return
	end

	keyPicker:SetValue({ MenuBind.canonicalKey(key), "Toggle", {} })

	repeat
		task.wait()
	until not MenuBind.isInputDown(captured) or UserInputService:GetFocusedTextBox()

	pcall(function()
		keyPicker:Update()
	end)
end

function MenuBind.hijackKeyPicker(keyPicker, library, labelText)
	if typeof(keyPicker) ~= "table" then
		return
	end

	task.defer(function()
		if keyPicker.Destroyed then
			return
		end
		if keyPicker._menuBindPicker and keyPicker._menuBindPicker.Parent then
			return
		end

		local picker = MenuBind.findPickerButton(library, labelText)
		if not picker then
			return
		end

		keyPicker._menuBindHijacked = true
		keyPicker._menuBindPicker = picker

		local connectionGetter = getconnections or get_signal_cons
		if typeof(connectionGetter) == "function" then
			for _, conn in connectionGetter(picker.MouseButton1Click) do
				if typeof(conn.Disable) == "function" then
					conn:Disable()
				elseif typeof(conn.Disconnect) == "function" then
					conn:Disconnect()
				end
			end
		end

		picker.MouseButton1Click:Connect(function()
			MenuBind.runSingleKeyPick(keyPicker, picker, library)
		end)
	end)
end

function MenuBind.disableModeMenu(keyPicker)
	if typeof(keyPicker) ~= "table" or keyPicker.Destroyed then
		return
	end
	pcall(function()
		if keyPicker.Menu then
			local menu = keyPicker.Menu
			if typeof(menu.Close) == "function" then
				menu:Close()
			end
			if typeof(menu.Open) == "function" then
				menu.Open = function() end
			end
			if typeof(menu.Toggle) == "function" then
				menu.Toggle = function() end
			end
		end
		if type(keyPicker.Modifiers) == "table" and #keyPicker.Modifiers > 0 then
			local key = MenuBind.resolvePrimaryKey(keyPicker.Value, keyPicker.Modifiers)
			if key then
				keyPicker:SetValue({ key, "Toggle", {} })
			end
		end
	end)
end

function MenuBind.normalizeSingleKeyPicker(keyPicker, fallbackKey, library, labelText)
	if typeof(keyPicker) ~= "table" then
		return
	end

	if not keyPicker._singleKeyOnly then
		keyPicker._singleKeyOnly = true

		local origSetValue = keyPicker.SetValue
		function keyPicker:SetValue(data)
			if typeof(data) == "table" then
				local key = MenuBind.resolvePrimaryKey(data[1], data[3])
				if not key then
					return
				end
				origSetValue(self, { key, "Toggle", {} })
				return
			end
			origSetValue(self, data)
		end

		if typeof(keyPicker.OnChanged) == "function" and not keyPicker._menuBindChangedHook then
			keyPicker._menuBindChangedHook = true
			keyPicker:OnChanged(function()
				local key = MenuBind.resolvePrimaryKey(keyPicker.Value, keyPicker.Modifiers)
				if not key then
					return
				end
				if key ~= MenuBind.canonicalKey(keyPicker.Value) or (type(keyPicker.Modifiers) == "table" and #keyPicker.Modifiers > 0) then
					keyPicker:SetValue({ key, "Toggle", {} })
				end
			end)
		end
	end

	keyPicker.Mode = "Toggle"
	keyPicker.BlacklistedModifiers = MenuBind.MODIFIER_KEYS

	local key = MenuBind.resolvePrimaryKey(keyPicker.Value, keyPicker.Modifiers)
	if not key or not MenuBind.isKeyboardKey(key) then
		key = MenuBind.canonicalKey(fallbackKey) or "P"
	end
	local currentKey = MenuBind.resolvePrimaryKey(keyPicker.Value, keyPicker.Modifiers)
	local hasModifiers = type(keyPicker.Modifiers) == "table" and #keyPicker.Modifiers > 0
	if not MenuBind.isKeyboardKey(currentKey) or hasModifiers or MenuBind.canonicalKey(keyPicker.Value) ~= key then
		keyPicker:SetValue({ key, "Toggle", {} })
	end
	MenuBind.disableModeMenu(keyPicker)

	if library and labelText then
		MenuBind.hijackKeyPicker(keyPicker, library, labelText)
	end
end

function MenuBind.install(library, menuKeybind, fallbackKey, labelText)
	if typeof(menuKeybind) ~= "table" then
		return
	end

	MenuBind.normalizeSingleKeyPicker(menuKeybind, fallbackKey, library, labelText or "Menu bind")
	library.ToggleKeybind = menuKeybind

	local baseToggle = library.Toggle
	local lastMenuToggleAt = 0
	library.Toggle = function(self, ...)
		if library.IsPicking then
			return
		end
		local now = tick()
		if now - lastMenuToggleAt < 0.05 then
			return
		end
		lastMenuToggleAt = now
		local result = baseToggle(self, ...)
		if type(HubToggle) == "table" and type(HubToggle.syncFromLibrary) == "function" then
			task.defer(HubToggle.syncFromLibrary)
		end
		return result
	end
end
