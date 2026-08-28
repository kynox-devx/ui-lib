local KYNOX_COLORS = {
	Accent = Color3.fromRGB(96, 205, 255),
	Background = Color3.fromHex("0c0b0e"),
	Main = Color3.fromHex("131217"),
	Outline = Color3.fromHex("09090a"),
	Font = Color3.fromHex("ebebee"),
}

local KYNOX_THEME = {
	FontColor = KYNOX_COLORS.Font,
	MainColor = KYNOX_COLORS.Main,
	AccentColor = KYNOX_COLORS.Accent,
	BackgroundColor = KYNOX_COLORS.Background,
	OutlineColor = KYNOX_COLORS.Outline,
}

function applyKynoxScheme()
	for key, value in pairs(KYNOX_THEME) do
		Library.Scheme[key] = value
	end
	Library:UpdateColorsUsingRegistry()
end

ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("KynoxHub")
ThemeManager:SetDefaultTheme(KYNOX_THEME)
ThemeManager.BuiltInThemes = {
	Kynox = {
		1,
		{
			FontColor = "ebebee",
			MainColor = "131217",
			AccentColor = "60cdff",
			BackgroundColor = "0c0b0e",
			OutlineColor = "09090a",
		},
	},
}
applyKynoxScheme()

local TOGGLE = CONFIG.Toggle
local UiLoops = { SessionTimer = 0 }
local BrandingUi = {
	toggleButton = nil,
	toggleIcon = nil,
	toggleStroke = nil,
	toggleStrokeGradient = nil,
	moveIcon = nil,
}

function getHubWindowVisible()
	if typeof(Library) ~= "table" then
		return nil
	end
	local main = Library.ScreenGui and Library.ScreenGui:FindFirstChild("Main")
	if main and main:IsA("GuiObject") then
		return main.Visible == true
	end
	return nil
end

function getToggleParent()
	if typeof(gethui) == "function" then
		return gethui()
	end
	return game:GetService("CoreGui")
end

function createToggleGui(parent, onToggle, toggle)
	toggle = toggle or {}
	local size = toggle.Size or 50
	local cornerRadius = toggle.CornerRadius or 6
	local TweenService = game:GetService("TweenService")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ToggleGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = parent

	local toggleButton = Instance.new("ImageButton")
	toggleButton.Name = "ToggleButton"
	toggleButton.Image = ""
	toggleButton.Size = UDim2.fromOffset(size, size)
	toggleButton.Position = toggle.Position or UDim2.new(0.06, 0, 0.08, 0)
	toggleButton.AnchorPoint = Vector2.new(0.5, 0.5)
	toggleButton.BackgroundColor3 = toggle.BackgroundColor or KYNOX_COLORS.Main
	toggleButton.BackgroundTransparency = toggle.BackgroundTransparency or 0
	toggleButton.BorderSizePixel = 0
	toggleButton.AutoButtonColor = false
	toggleButton.Parent = screenGui
	BrandingUi.toggleButton = toggleButton

	Instance.new("UICorner", toggleButton).CornerRadius = UDim.new(0, cornerRadius)

	local toggleIcon = Instance.new("ImageLabel")
	toggleIcon.Name = "Icon"
	toggleIcon.Image = toggle.Image or "rbxassetid://78756412031557"
	toggleIcon.ScaleType = Enum.ScaleType.Fit
	toggleIcon.BackgroundTransparency = 1
	toggleIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	toggleIcon.Position = UDim2.fromScale(0.5, 0.5)
	local iconSize = math.max(20, math.floor(size * 0.62))
	toggleIcon.Size = UDim2.fromOffset(iconSize, iconSize)
	toggleIcon.Parent = toggleButton
	BrandingUi.toggleIcon = toggleIcon

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Color = KYNOX_COLORS.Outline
	stroke.Parent = toggleButton
	BrandingUi.toggleStroke = stroke

	local strokeGradient = Instance.new("UIGradient")
	strokeGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, KYNOX_COLORS.Outline),
		ColorSequenceKeypoint.new(0.5, KYNOX_COLORS.Main),
		ColorSequenceKeypoint.new(1, KYNOX_COLORS.Accent),
	})
	strokeGradient.Rotation = 45
	strokeGradient.Parent = stroke
	BrandingUi.toggleStrokeGradient = strokeGradient

	local buttonScale = Instance.new("UIScale")
	buttonScale.Scale = 1
	buttonScale.Parent = toggleButton

	local hoverTweenIn = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local hoverTweenOut = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local activeHoverTween

	function tweenScale(targetScale, tweenInfo)
		if activeHoverTween then
			activeHoverTween:Cancel()
		end
		activeHoverTween = TweenService:Create(buttonScale, tweenInfo or hoverTweenIn, { Scale = targetScale })
		activeHoverTween:Play()
	end

	toggleButton.MouseEnter:Connect(function()
		tweenScale(1.05, hoverTweenIn)
	end)

	toggleButton.MouseLeave:Connect(function()
		tweenScale(1, hoverTweenOut)
	end)

	local UserInputService = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")
	local dragSmooth = 5.5
	local dragThreshold = 8
	local dragging = false
	local dragMoved = false
	local dragStartMouse
	local dragTargetPos
	local dragCurrentPos
	local dragLoopConn

	local function clampTogglePos(center, size)
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		local half = size * 0.5
		return Vector2.new(
			math.clamp(center.X, half.X, viewport.X - half.X),
			math.clamp(center.Y, half.Y, viewport.Y - half.Y)
		)
	end

	local function captureToggleCenter()
		local absolutePos = toggleButton.AbsolutePosition
		local absoluteSize = toggleButton.AbsoluteSize
		return Vector2.new(absolutePos.X + absoluteSize.X * 0.5, absolutePos.Y + absoluteSize.Y * 0.5)
	end

	local function applyToggleCenter(center)
		toggleButton.AnchorPoint = Vector2.new(0.5, 0.5)
		toggleButton.Position = UDim2.fromOffset(center.X, center.Y)
	end

	local function stopDragLoop()
		if dragLoopConn then
			dragLoopConn:Disconnect()
			dragLoopConn = nil
		end
	end

	local function startDragLoop()
		if dragLoopConn then
			return
		end
		dragLoopConn = RunService.RenderStepped:Connect(function(dt)
			if not dragging or not dragCurrentPos or not dragTargetPos then
				return
			end
			local alpha = 1 - math.exp(-dragSmooth * dt)
			dragCurrentPos = dragCurrentPos:Lerp(dragTargetPos, alpha)
			applyToggleCenter(dragCurrentPos)
		end)
	end

	toggleButton.InputBegan:Connect(function(input)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		dragging = true
		dragMoved = false
		dragStartMouse = UserInputService:GetMouseLocation()
		dragCurrentPos = captureToggleCenter()
		dragTargetPos = dragCurrentPos
		startDragLoop()
	end)

	local function finishDrag(input)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		if not dragging then
			return
		end
		dragging = false
		stopDragLoop()
		if not dragMoved then
			setHubVisible(not HubToggle.visible)
		end
	end

	toggleButton.InputEnded:Connect(finishDrag)
	UserInputService.InputEnded:Connect(finishDrag)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		if (mouse - dragStartMouse).Magnitude >= dragThreshold then
			dragMoved = true
		end
		dragTargetPos = clampTogglePos(mouse, toggleButton.AbsoluteSize)
	end)

	HubToggle.visible = CONFIG.Intro.Enabled ~= true

	local function setHubVisible(visible)
		HubToggle.visible = visible == true
		onToggle(HubToggle.visible)
	end

	function HubToggle.syncFromLibrary()
		local open = getHubWindowVisible()
		if open ~= nil then
			HubToggle.visible = open
		end
	end

	return screenGui, toggleButton
end

function playKynoxIntroReveal(toggleGui, toggleButton)
	local intro = CONFIG.Intro or {}
	local TweenService = game:GetService("TweenService")

	local mainFrame = Library.ScreenGui and Library.ScreenGui:FindFirstChild("Main")
	local windowScale = mainFrame and mainFrame:FindFirstChildOfClass("UIScale")
	local toggleScale = toggleButton and toggleButton:FindFirstChildOfClass("UIScale")
	local targetWindowScale = windowScale and windowScale.Scale or 1
	local popFrom = intro.PopFrom or 0.9
	local popDuration = intro.PopDuration or 0.5
	local pop = TweenInfo.new(popDuration, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	if windowScale then
		windowScale.Scale = popFrom
	end
	if toggleScale then
		toggleScale.Scale = popFrom
	end

	Library:Toggle(true)
	if toggleGui then
		toggleGui.Enabled = true
	end

	if windowScale then
		TweenService:Create(windowScale, pop, { Scale = targetWindowScale }):Play()
	end
	if toggleScale then
		TweenService:Create(toggleScale, pop, { Scale = 1 }):Play()
	end
end

function formatSessionTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	return string.format("%d:%02d:%02d", hours, minutes, secs)
end

function formatShortCountdown(seconds)
	seconds = math.max(0, math.floor((seconds or 0) + 0.5))
	if seconds >= 3600 then
		return formatSessionTime(seconds)
	end
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%d:%02d", minutes, secs)
end

function setupSessionTimer()
	local mainFrame = Library.ScreenGui and Library.ScreenGui:FindFirstChild("Main")
	if not mainFrame then
		return
	end

	local bottomBar
	for _, child in ipairs(mainFrame:GetChildren()) do
		if
			child:IsA("Frame")
			and child.AnchorPoint == Vector2.new(0, 1)
			and child.BackgroundTransparency == 1
			and child.Size.Y.Offset == 20
		then
			bottomBar = child
			break
		end
	end
	if not bottomBar then
		return
	end

	local footerLabel = bottomBar:FindFirstChildWhichIsA("TextLabel")
	if not footerLabel then
		return
	end

	local sessionStart = tick()

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "SessionTimer"
	timerLabel.BackgroundTransparency = 1
	timerLabel.Size = UDim2.new(0.5, -8, 1, 0)
	timerLabel.Position = UDim2.fromOffset(8, 0)
	timerLabel.TextXAlignment = Enum.TextXAlignment.Left
	timerLabel.TextYAlignment = Enum.TextYAlignment.Center
	timerLabel.TextSize = footerLabel.TextSize
	timerLabel.TextTransparency = footerLabel.TextTransparency
	timerLabel.TextColor3 = footerLabel.TextColor3
	timerLabel.FontFace = footerLabel.FontFace
	timerLabel.Text = "0:00:00"
	timerLabel.Parent = bottomBar

	UiLoops.SessionTimer += 1
	local token = UiLoops.SessionTimer
	task.spawn(function()
		while token == UiLoops.SessionTimer and timerLabel.Parent and Library.Unloaded ~= true do
			timerLabel.Text = formatSessionTime(tick() - sessionStart)
			task.wait(1)
		end
	end)
end

Library.ForceCheckbox = false 
Library.ShowToggleFrameInKeybinds = true 

local function lerpUDim2(a, b, t)
	return UDim2.new(
		a.X.Scale + (b.X.Scale - a.X.Scale) * t,
		a.X.Offset + (b.X.Offset - a.X.Offset) * t,
		a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t,
		a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t
	)
end

function installSmoothWindowDrag(library)
	if typeof(library) ~= "table" or library._kynoxSmoothDragInstalled then
		return
	end
	library._kynoxSmoothDragInstalled = true

	local baseMakeDraggable = library.MakeDraggable
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local dragSmooth = 5.5

	library.MakeDraggable = function(self, ui, dragFrame, ignoreToggled, isMainWindow)
		if isMainWindow ~= true then
			return baseMakeDraggable(self, ui, dragFrame, ignoreToggled, isMainWindow)
		end

		local startPos
		local framePos
		local dragging = false
		local targetPos
		local currentPos
		local dragLoopConn

		local function isClickInput(input)
			return input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
		end

		local function isMoveInput(input)
			return input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
		end

		local function stopDragLoop()
			if dragLoopConn then
				dragLoopConn:Disconnect()
				dragLoopConn = nil
			end
		end

		local function startDragLoop()
			if dragLoopConn then
				return
			end
			dragLoopConn = RunService.RenderStepped:Connect(function(dt)
				if not currentPos or not targetPos then
					return
				end
				local alpha = 1 - math.exp(-dragSmooth * dt)
				currentPos = lerpUDim2(currentPos, targetPos, alpha)
				ui.Position = currentPos
			end)
		end

		local changedConn
		dragFrame.InputBegan:Connect(function(input)
			if not isClickInput(input) or library.CantDragForced then
				return
			end
			startPos = input.Position
			framePos = ui.Position
			currentPos = ui.Position
			targetPos = ui.Position
			dragging = true
			startDragLoop()

			if changedConn then
				changedConn:Disconnect()
				changedConn = nil
			end
			changedConn = input.Changed:Connect(function()
				if input.UserInputState ~= Enum.UserInputState.End then
					return
				end
				dragging = false
				if changedConn then
					changedConn:Disconnect()
					changedConn = nil
				end
			end)
		end)

		local inputChangedConn = UserInputService.InputChanged:Connect(function(input)
			if (not ignoreToggled and not library.Toggled) or library.CantDragForced then
				dragging = false
				return
			end
			if dragging and isMoveInput(input) then
				local delta = input.Position - startPos
				targetPos = UDim2.new(
					framePos.X.Scale,
					framePos.X.Offset + delta.X,
					framePos.Y.Scale,
					framePos.Y.Offset + delta.Y
				)
			end
		end)

		ui.Destroying:Once(function()
			dragging = false
			stopDragLoop()
			if changedConn then
				changedConn:Disconnect()
			end
			if inputChangedConn then
				inputChangedConn:Disconnect()
			end
		end)
	end
end

installSmoothWindowDrag(Library)

local windowSize = CONFIG.Window.PcSize
if Library.IsMobile then
	windowSize = CONFIG.Window.MobileSize
end

Window = Library:CreateWindow({
	Title = CONFIG.Window.Title,
	Footer = CONFIG.Window.Footer or CONFIG.Window.SubTitle,
	Icon = tonumber(CONFIG.Branding.Logo:match("%d+")),
	IconSize = UDim2.fromOffset(CONFIG.Branding.LogoSize, CONFIG.Branding.LogoSize),
	Size = windowSize,
	Center = true,
	AutoShow = not CONFIG.Intro.Enabled,
	NotifySide = "Right",
	ShowCustomCursor = false,
	ShowMobileButtons = false,
	ToggleKeybind = CONFIG.Window.MinimizeKey,
	SidebarMinWidth = CONFIG.Window.SidebarWidth,
	Font = Enum.Font.Code,
})

Library.ShowCustomCursor = false
Window:SetSidebarWidth(CONFIG.Window.SidebarWidth)

local TextService = game:GetService("TextService")

function findWindowTopBar()
	local main = Library.ScreenGui and Library.ScreenGui:FindFirstChild("Main")
	if not main then
		return nil
	end
	for _, child in ipairs(main:GetChildren()) do
		if child:IsA("Frame") and child.Size.Y.Offset == 48 then
			return child
		end
	end
	return nil
end

function findWindowTitleHolder()
	local main = Library.ScreenGui and Library.ScreenGui:FindFirstChild("Main")
	if not main then
		return nil, nil
	end
	for _, topBar in ipairs(main:GetChildren()) do
		if topBar:IsA("Frame") and topBar.Size.Y.Offset == 48 then
			for _, holder in ipairs(topBar:GetChildren()) do
				if holder:IsA("Frame") then
					local layout = holder:FindFirstChildWhichIsA("UIListLayout")
					if layout and layout.FillDirection == Enum.FillDirection.Horizontal then
						return holder, layout
					end
				end
			end
		end
	end
	return nil, nil
end

function getBrandingSchemeColors()
	local scheme = typeof(Library) == "table" and Library.Scheme or nil
	return {
		accent = (scheme and scheme.AccentColor) or KYNOX_COLORS.Accent,
		main = (scheme and scheme.MainColor) or KYNOX_COLORS.Main,
		outline = (scheme and scheme.OutlineColor) or KYNOX_COLORS.Outline,
		font = (scheme and scheme.FontColor) or KYNOX_COLORS.Font,
	}
end

function styleWindowMoveIcon()
	local topBar = findWindowTopBar()
	if not topBar then
		return
	end
	local colors = getBrandingSchemeColors()
	for _, child in ipairs(topBar:GetChildren()) do
		if child:IsA("ImageLabel") and child.AnchorPoint == Vector2.new(1, 0.5) then
			child.ImageColor3 = colors.main
			BrandingUi.moveIcon = child
			return
		end
	end
end

function applyBrandedLogoTheme()
	local colors = getBrandingSchemeColors()
	local tint = colors.accent

	local holder = select(1, findWindowTitleHolder())
	if holder then
		for _, child in ipairs(holder:GetChildren()) do
			if child:IsA("ImageLabel") then
				child.ImageColor3 = tint
			end
		end
	end

	styleWindowMoveIcon()

	if BrandingUi.moveIcon and BrandingUi.moveIcon.Parent then
		pcall(function()
			BrandingUi.moveIcon.ImageColor3 = colors.main
		end)
	else
		BrandingUi.moveIcon = nil
		styleWindowMoveIcon()
	end

	if BrandingUi.toggleButton then
		pcall(function()
			if BrandingUi.toggleButton.Parent ~= nil then
				BrandingUi.toggleButton.BackgroundColor3 = colors.main
			end
		end)
	end

	if BrandingUi.toggleIcon then
		local ok = pcall(function()
			if BrandingUi.toggleIcon.Parent ~= nil then
				BrandingUi.toggleIcon.ImageColor3 = tint
			end
		end)
		if not ok then
			BrandingUi.toggleIcon = nil
		end
	end

	if BrandingUi.toggleStroke then
		pcall(function()
			if BrandingUi.toggleStroke.Parent ~= nil then
				BrandingUi.toggleStroke.Color = colors.outline
			end
		end)
	end

	if BrandingUi.toggleStrokeGradient then
		pcall(function()
			if BrandingUi.toggleStrokeGradient.Parent ~= nil then
				BrandingUi.toggleStrokeGradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, colors.outline),
					ColorSequenceKeypoint.new(0.5, colors.main),
					ColorSequenceKeypoint.new(1, colors.accent),
				})
			end
		end)
	end
end

function styleWindowHeader()
	local holder, layout = findWindowTitleHolder()
	if not holder or not layout then
		return
	end

	local icon, title
	for _, child in ipairs(holder:GetChildren()) do
		if child:IsA("ImageLabel") then
			icon = child
		elseif child:IsA("TextLabel") and (child:GetAttribute("KynoxWindowTitle") or child.TextSize >= 18) then
			title = child
		end
	end
	if not title then
		return
	end

	local branding = CONFIG.Branding or {}
	local rowHeight = branding.LogoSize or 26
	local titleSize = branding.TitleTextSize or 20
	local titleGap = branding.TitleGap or 8
	local baseFont = Library.Scheme.Font

	if typeof(baseFont) == "Font" then
		title.FontFace = Font.new(baseFont.Family, Enum.FontWeight.Bold, baseFont.Style)
	else
		local codeFont = Font.fromEnum(Enum.Font.Code)
		title.FontFace = Font.new(codeFont.Family, Enum.FontWeight.Bold, codeFont.Style)
	end

	title:SetAttribute("KynoxWindowTitle", true)
	title.TextSize = titleSize
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.RichText = false

	local textWidth = title.Size.X.Offset
	local ok, bounds = pcall(function()
		return TextService:GetTextSize(title.Text, titleSize, title.FontFace, Vector2.new(512, rowHeight))
	end)
	if ok and bounds then
		textWidth = math.ceil(bounds.X)
	end
	title.Size = UDim2.fromOffset(textWidth, rowHeight)

	if icon then
		icon.LayoutOrder = 1
		icon.Size = UDim2.fromOffset(rowHeight, rowHeight)
		icon.ScaleType = Enum.ScaleType.Fit
	end

	applyBrandedLogoTheme()

	title.LayoutOrder = 2
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, titleGap)
end

if not Library._kynoxTitleFontHook then
	Library._kynoxTitleFontHook = true
	local origSetFont = Library.SetFont
	function Library:SetFont(...)
		pcall(origSetFont, self, ...)
		pcall(styleWindowHeader)
	end
	local origUpdateColors = Library.UpdateColorsUsingRegistry
	function Library:UpdateColorsUsingRegistry(...)
		pcall(origUpdateColors, self, ...)
		pcall(styleWindowHeader)
	end
end

local origChangeTitle = Window.ChangeTitle
function Window:ChangeTitle(text)
	origChangeTitle(self, text)
	styleWindowHeader()
end

styleWindowHeader()

Lang.installWindowHooks(Window)

setupSessionTimer()

toggleGui, toggleButton = createToggleGui(getToggleParent(), function(visible)
	Library:Toggle(visible)
end, TOGGLE)
applyBrandedLogoTheme()

if CONFIG.Intro.Enabled then
	toggleGui.Enabled = false
end

NotifySafe = { disabled = false }
UiSafe = {
	checked = false,
	fluentMethods = true,
	instanceMutate = true,
	uiOpacityMutate = true,
}

function isPluginCapabilityError(err)
	return type(err) == "string" and string.find(err, "lacking capability", 1, true) ~= nil
end

function safeObsidianSetValueFallback(element, value)
	if typeof(element) ~= "table" then
		return
	end
	rawset(element, "Value", value)
	if element.Type == "Toggle" then
		local display = element._kynoxOrigDisplay
		if type(display) == "function" then
			pcall(display, element)
		end
		if type(element.Addons) == "table" then
			for _, addon in ipairs(element.Addons) do
				if addon.Type == "KeyPicker" and addon.SyncToggleState then
					addon.Toggled = element.Value
					pcall(function()
						if type(addon.Update) == "function" then
							addon:Update()
						end
					end)
				end
			end
		end
		pcall(function()
			if Library and type(Library.UpdateDependencyBoxes) == "function" then
				Library:UpdateDependencyBoxes()
			end
		end)
		if element.AnyKeyPickerPicking ~= true then
			pcall(element.Callback, element.Value)
			pcall(element.Changed, element.Value)
		end
	elseif element.Type == "Dropdown" then
		if type(element.BuildDropdownList) == "function" then
			pcall(function()
				element:BuildDropdownList()
			end)
		end
		local display = element._kynoxOrigDisplay
		if type(display) == "function" then
			pcall(display, element)
		end
		pcall(element.Callback, element.Value)
		pcall(element.Changed, element.Value)
	elseif element.Type == "Input" then
		local display = element._kynoxOrigDisplay
		if type(display) == "function" then
			pcall(display, element)
		end
		pcall(element.Callback, element.Value)
		pcall(element.Changed, element.Value)
	end
	task.defer(function()
		safeResizeObsidianLayout(element)
	end)
end

function wrapObsidianElementFluentMethods(element)
	if typeof(element) ~= "table" or element._kynoxObsidianSafe then
		return
	end
	element._kynoxObsidianSafe = true

	for _, methodName in ipairs({ "Display", "Update" }) do
		local orig = element[methodName]
		if type(orig) == "function" then
			element["_kynoxOrig" .. methodName] = orig
			element[methodName] = function(self, ...)
				local ok, err = pcall(orig, self, ...)
				if not ok and isPluginCapabilityError(err) then
					UiSafe.fluentMethods = false
				end
			end
		end
	end

	local origSetValue = element.SetValue
	if type(origSetValue) == "function" then
		element._kynoxOrigSetValue = origSetValue
		function element:SetValue(value, ...)
			if self.Disabled then
				return
			end
			local ok, err = pcall(origSetValue, self, value, ...)
			if ok then
				return
			end
			if isPluginCapabilityError(err) then
				UiSafe.fluentMethods = false
			end
			safeObsidianSetValueFallback(self, value)
		end
	end

	local origSetValueRGB = element.SetValueRGB
	if type(origSetValueRGB) == "function" then
		element.SetValueRGB = function(self, ...)
			local ok, err = pcall(origSetValueRGB, self, ...)
			if not ok and isPluginCapabilityError(err) then
				UiSafe.fluentMethods = false
			end
		end
	end
end

function installObsidianSafeSetValueShims(library)
	if typeof(library) ~= "table" then
		return
	end
	for idx, toggle in pairs(library.Toggles or {}) do
		if not ConfigAuto.shouldPersistInUiFile(idx) then
			wrapObsidianElementFluentMethods(toggle)
		end
	end
	for idx, option in pairs(library.Options or {}) do
		if not ConfigAuto.shouldPersistInUiFile(idx) then
			wrapObsidianElementFluentMethods(option)
		end
	end
end

function probeExecutorUiCapability()
	if UiSafe.checked then
		return
	end
	UiSafe.checked = true
	local char = LocalPlayer.Character
	local part = char and char:FindFirstChildWhichIsA("BasePart")
	if part then
		local ok, err = pcall(function()
			local _ = part.CanCollide
		end)
		if not ok and isPluginCapabilityError(err) then
			UiSafe.instanceMutate = false
			UiSafe.fluentMethods = false
		end
	end
end

probeExecutorUiCapability()

function notify(opts)
	if NotifySafe.disabled or not Library or type(Library.Notify) ~= "function" then
		return
	end
	local ok, err = pcall(function()
		if typeof(opts) == "string" then
			Library:Notify({ Title = "Kynox", Description = opts, Time = 3 })
			return
		end
		Library:Notify({
			Title = opts.Title or "Kynox",
			Description = opts.Content or opts.Description or "",
			Time = opts.Duration or opts.Time or 3,
		})
	end)
	if not ok and type(err) == "string" and string.find(err, "lacking capability", 1, true) then
		NotifySafe.disabled = true
	end
end

Library:OnUnload(function()
	UiLoops.SessionTimer += 1
	if type(Lang) == "table" and type(Lang.dismissLoadingNotify) == "function" then
		Lang.dismissLoadingNotify()
	end
	if type(SaveUiConfig) == "function" then
		SaveUiConfig()
	end
	Hub.Runtime:unload("ui_unload")
end)

Tabs = {}
for _, tabDef in ipairs(CONFIG.Tabs) do
	local icon = tabDef.Icon
	if tabDef.Id == "Settings" then
		Tabs["UI Settings"] = Window:AddTab(tabDef.Title, icon)
	else
		Tabs[tabDef.Id] = Window:AddTab(tabDef.Title, icon)
	end
end
refreshObsidianLucideIcons(Library)
function buildSettingsTab()
	local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu")

	MenuGroup:AddDropdown("UILanguage", {
		Text = "UI Language",
		Values = Lang.DISPLAY_NAMES,
		Default = "English",
	})

	MenuGroup:AddDropdown("NotificationSide", {
		Values = { "Left", "Right" },
		Default = "Right",

		Text = "Notification Side",

		Callback = function(Value)
			Library:SetNotifySide(Value)
		end,
	})
	MenuGroup:AddDropdown("DPIDropdown", {
		Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
		Default = "100%",

		Text = "DPI Scale",

		Callback = function(Value)
			Value = Value:gsub("%%", "")
			local DPI = tonumber(Value)

			Library:SetDPIScale(DPI)
			UiLayout.scheduleRefresh()
		end,
	})
	MenuGroup:AddDivider()
	MenuGroup:AddLabel("Menu bind")
		:AddKeyPicker("MenuKeybind", {
			Default = CONFIG.Window.MinimizeKey.Name,
			NoUI = true,
			Text = "Menu keybind",
			Mode = "Toggle",
			Modes = { "Toggle" },
			SyncToggleState = false,
			DefaultModifiers = {},
			Blacklisted = { "MB1", "MB2", "MB3" },
			BlacklistedModifiers = MenuBind.MODIFIER_KEYS,
			Callback = function() end,
		})

	MenuGroup:AddDivider()
	MenuGroup:AddLabel("Settings auto-save enabled.")
	MenuGroup:AddButton("Reset config", function()
		ConfigAuto.reset(Library)
		applyAppearance()
		applyUIOpacity(Options.UIOpacity and Options.UIOpacity.Value or 100)
		if Options.FontFace and typeof(Options.FontFace.Value) == "string" and Enum.Font[Options.FontFace.Value] then
			pcall(function()
				Library:SetFont(Enum.Font[Options.FontFace.Value])
			end)
		end
		Library:Notify("Config reset to defaults.", 3)
	end)

	local AppearanceGroup = Tabs["UI Settings"]:AddRightGroupbox("Appearance", "palette")
	AppearanceGroup:AddLabel("Background color"):AddColorPicker("BackgroundColor", {
		Default = KYNOX_COLORS.Background,
	})
	AppearanceGroup:AddLabel("Main color"):AddColorPicker("MainColor", {
		Default = KYNOX_COLORS.Main,
	})
	AppearanceGroup:AddLabel("Accent color"):AddColorPicker("AccentColor", {
		Default = KYNOX_COLORS.Accent,
	})
	AppearanceGroup:AddLabel("Outline color"):AddColorPicker("OutlineColor", {
		Default = KYNOX_COLORS.Outline,
	})
	AppearanceGroup:AddLabel("Font color"):AddColorPicker("FontColor", {
		Default = KYNOX_COLORS.Font,
	})
	AppearanceGroup:AddDropdown("FontFace", {
		Text = "Font",
		Default = "Code",
		Values = { "BuilderSans", "Code", "Fantasy", "Gotham", "Jura", "Roboto", "RobotoMono", "SourceSans" },
	})
	AppearanceGroup:AddDivider()
	AppearanceGroup:AddSlider("UIOpacity", {
		Text = "UI opacity",
		Default = 100,
		Min = 25,
		Max = 100,
		Rounding = 0,
		Suffix = "%",
	})
	SaveManager:SetLibrary(Library)
	SaveManager:SetIgnoreIndexes({ "UILanguage" })
	MenuBind.install(Library, Options.MenuKeybind, CONFIG.Window.MinimizeKey.Name, "Menu bind")
	ConfigAuto.setup(SaveManager, Library)
	AppearanceGroup:AddButton("Reset appearance", resetAppearance)
end

local DEFAULT_UI_OPACITY = 100
local opacityBase = {}

function isOpacityGuiInstance(inst)
	if inst == nil then
		return false
	end
	local ok, alive = pcall(function()
		return inst.Parent ~= nil
	end)
	return ok and alive == true
end

function rememberOpacityNode(inst)
	if opacityBase[inst] then
		return
	end
	if inst == nil then
		return
	end
	local entry = {}
	local okGui, isGuiObject = pcall(function()
		return inst:IsA("GuiObject")
	end)
	if okGui and isGuiObject then
		entry.bg = inst.BackgroundTransparency
	end
	local okText, isText = pcall(function()
		return inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox")
	end)
	if okText and isText then
		entry.text = inst.TextTransparency
	end
	local okImage, isImage = pcall(function()
		return inst:IsA("ImageLabel") or inst:IsA("ImageButton")
	end)
	if okImage and isImage then
		entry.image = inst.ImageTransparency
	end
	local okStroke, isStroke = pcall(function()
		return inst:IsA("UIStroke")
	end)
	if okStroke and isStroke then
		entry.stroke = inst.Transparency
	end
	if next(entry) ~= nil then
		opacityBase[inst] = entry
	end
end

function captureOpacityTree(root)
	if not root then
		return
	end
	rememberOpacityNode(root)
	for _, desc in ipairs(root:GetDescendants()) do
		rememberOpacityNode(desc)
	end
end

function applyUIOpacity(percent)
	if UiSafe.uiOpacityMutate == false then
		return
	end
	local ok, err = pcall(function()
		local main = Library.ScreenGui and Library.ScreenGui:FindFirstChild("Main")
		if not main then
			return
		end
		if not opacityBase[main] then
			captureOpacityTree(main)
		end

		local alpha = math.clamp((tonumber(percent) or DEFAULT_UI_OPACITY) / 100, 0.25, 1)
		local fade = 1 - alpha

		for inst, entry in pairs(opacityBase) do
			if not isOpacityGuiInstance(inst) then
				opacityBase[inst] = nil
				continue
			end
			if entry.bg ~= nil then
				inst.BackgroundTransparency = math.clamp(entry.bg + fade * (1 - entry.bg), 0, 1)
			end
			if entry.text ~= nil then
				inst.TextTransparency = math.clamp(entry.text + fade * (1 - entry.text), 0, 1)
			end
			if entry.image ~= nil then
				inst.ImageTransparency = math.clamp(entry.image + fade * (1 - entry.image), 0, 1)
			end
			if entry.stroke ~= nil then
				inst.Transparency = math.clamp(entry.stroke + fade * (1 - entry.stroke), 0, 1)
			end
		end

		if alpha >= 1 and main:IsA("GuiObject") then
			main.BackgroundTransparency = opacityBase[main] and opacityBase[main].bg or 0
		end
	end)
	if not ok and isPluginCapabilityError(err) then
		UiSafe.uiOpacityMutate = false
	end
end

function applyAppearance()
	for _, colorKey in ipairs({ "BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor" }) do
		local opt = Options[colorKey]
		if opt and typeof(opt.Value) == "Color3" then
			Library.Scheme[colorKey] = opt.Value
		end
	end
	pcall(function()
		Library:UpdateColorsUsingRegistry()
	end)
	if Options and Options.UIOpacity then
		applyUIOpacity(Options.UIOpacity.Value)
	end
	applyBrandedLogoTheme()
end

function resetAppearance()
	ConfigAuto._loading = true
	for _, colorKey in ipairs(ConfigAuto.UI_COLOR_KEYS) do
		local value = KYNOX_THEME[colorKey]
		local opt = Options[colorKey]
		if value and opt then
			if type(opt.SetValueRGB) == "function" then
				pcall(function()
					opt:SetValueRGB(value, 0)
				end)
			elseif type(opt.SetValue) == "function" then
				pcall(function()
					opt:SetValue(value)
				end)
			end
			Library.Scheme[colorKey] = value
		end
	end
	if Options.FontFace then
		pcall(function()
			Options.FontFace:SetValue("Code")
		end)
	end
	if Options.UIOpacity then
		pcall(function()
			Options.UIOpacity:SetValue(DEFAULT_UI_OPACITY)
		end)
	end
	table.clear(opacityBase)
	ConfigAuto._loading = false
	applyAppearance()
	applyUIOpacity(DEFAULT_UI_OPACITY)
	pcall(function()
		Library:SetFont(Enum.Font.Code)
	end)
	pcall(styleWindowHeader)
	pcall(applyBrandedLogoTheme)
	SaveUiConfig()
	Library:Notify("Appearance reset to Kynox defaults.", 3)
end

buildSettingsTab()

function bindAppearanceOptions()
	local function onColorChanged()
		if ConfigAuto._loading then
			return
		end
		applyAppearance()
		SaveUiConfig()
	end

	for _, colorKey in ipairs({ "BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor" }) do
		local opt = Options[colorKey]
		if opt then
			opt.Callback = onColorChanged
			opt:OnChanged(onColorChanged)
		end
	end
	if Options.FontFace then
		Options.FontFace:OnChanged(function(value)
			if ConfigAuto._loading then
				return
			end
			if typeof(value) == "string" and Enum.Font[value] then
				pcall(function()
					Library:SetFont(Enum.Font[value])
				end)
				pcall(styleWindowHeader)
			end
			SaveUiConfig()
		end)
	end
	if Options.UIOpacity then
		Options.UIOpacity:OnChanged(function(value)
			if ConfigAuto._loading then
				return
			end
			applyUIOpacity(value)
			SaveUiConfig()
		end)
	end
end

task.defer(function()
	task.wait()
	installObsidianSafeSetValueShims(Library)
	applyAppearance()
	applyUIOpacity(Options.UIOpacity and Options.UIOpacity.Value or DEFAULT_UI_OPACITY)
	if Options.FontFace and typeof(Options.FontFace.Value) == "string" and Enum.Font[Options.FontFace.Value] then
		pcall(function()
			Library:SetFont(Enum.Font[Options.FontFace.Value])
		end)
	end
	applyBrandedLogoTheme()
end)
