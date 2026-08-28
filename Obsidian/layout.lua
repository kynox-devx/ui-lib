UiLayout = { _refreshToken = 0 }

function UiLayout.hookGroupbox(groupbox)
	if typeof(groupbox) ~= "table" or groupbox._uiLayoutHooked then
		return
	end
	groupbox._uiLayoutHooked = true

	local holder = groupbox.Holder
	local container = groupbox.Container
	if holder and holder:IsA("GuiObject") then
		holder.ClipsDescendants = true
	end
	if container and container:IsA("GuiObject") then
		container.ClipsDescendants = true
		local list = container:FindFirstChildWhichIsA("UIListLayout")
		if list and not groupbox._uiLayoutListHooked then
			groupbox._uiLayoutListHooked = true
			list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				if groupbox.Destroyed or typeof(groupbox.Resize) ~= "function" then
					return
				end
				pcall(groupbox.Resize, groupbox)
			end)
		end
	end
end

function UiLayout.hookTab(tab)
	if typeof(tab) ~= "table" or tab._uiLayoutTabHooked then
		return
	end
	tab._uiLayoutTabHooked = true
	if typeof(tab.Sides) == "table" then
		for _, side in pairs(tab.Sides) do
			if side then
				pcall(function()
					if side:IsA("ScrollingFrame") then
						side.ClipsDescendants = true
					end
				end)
			end
		end
	end
end

function UiLayout.refreshTabGroupboxes(tab)
	if typeof(tab) ~= "table" then
		return
	end
	UiLayout.hookTab(tab)
	if typeof(tab.Groupboxes) == "table" then
		for _, groupbox in pairs(tab.Groupboxes) do
			if typeof(groupbox) == "table" then
				UiLayout.hookGroupbox(groupbox)
				if typeof(groupbox.Resize) == "function" then
					pcall(groupbox.Resize, groupbox)
				end
			end
		end
	end
	if typeof(tab.Resize) == "function" then
		pcall(tab.Resize, tab)
	end
end

function UiLayout.refreshAllGroupboxes()
	for _, tab in pairs(asTable(Library.Tabs)) do
		UiLayout.refreshTabGroupboxes(tab)
	end
end

function UiLayout.scheduleRefresh()
	local token = UiLayout._refreshToken + 1
	UiLayout._refreshToken = token
	task.defer(function()
		for _ = 1, 5 do
			if UiLayout._refreshToken ~= token then
				return
			end
			UiLayout.refreshAllGroupboxes()
			task.wait()
		end
	end)
end
