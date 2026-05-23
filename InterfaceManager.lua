local httpService = game:GetService("HttpService")

local InterfaceManager = {} do
	InterfaceManager.Folder = "KynoxConfigs/interface"
    InterfaceManager.Settings = {
        Theme = "Dark",
        Acrylic = false,
        Transparency = false,
        MenuKeybind = "LeftControl",
        ShowSessionTimer = true,
    }

    function InterfaceManager:ApplyForcedVisuals()
        local Library = self.Library
        if not Library then
            return
        end

        self.Settings.Theme = "Dark"
        self.Settings.Acrylic = false
        self.Settings.Transparency = false

        Library:SetTheme("Dark")
        if Library.UseAcrylic then
            Library:ToggleAcrylic(false)
        end
        Library:ToggleTransparency(false)
    end

    function InterfaceManager:SetFolder(folder)
		self.Folder = folder;
		self:BuildFolderTree()
	end

    function InterfaceManager:SetLibrary(library)
		self.Library = library
	end

    function InterfaceManager:BuildFolderTree()
		local paths = {}

		local parts = self.Folder:split("/")
		for idx = 1, #parts do
			paths[#paths + 1] = table.concat(parts, "/", 1, idx)
		end

		table.insert(paths, self.Folder)
		table.insert(paths, self.Folder .. "/settings")

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

    function InterfaceManager:SaveSettings()
        writefile(self.Folder .. "/options.json", httpService:JSONEncode(InterfaceManager.Settings))
    end

    function InterfaceManager:LoadSettings()
        local path = self.Folder .. "/options.json"
        if isfile(path) then
            local data = readfile(path)
            local success, decoded = pcall(httpService.JSONDecode, httpService, data)

            if success then
                for i, v in next, decoded do
                    InterfaceManager.Settings[i] = v
                end
            end
        end
    end

    function InterfaceManager:BuildInterfaceSection(tab, opts)
        opts = opts or {}
        assert(self.Library, "Must set InterfaceManager.Library")
        local Library = self.Library
        local Settings = InterfaceManager.Settings

        InterfaceManager:LoadSettings()
        InterfaceManager:ApplyForcedVisuals()

        Settings.ShowSessionTimer = Settings.ShowSessionTimer == true

        local section = tab:AddSection("Interface")

        local MenuKeybind = section:AddKeybind("MenuKeybind", { Title = "Minimize Bind", Default = Settings.MenuKeybind })
        MenuKeybind:OnChanged(function()
            Settings.MenuKeybind = MenuKeybind.Value
            InterfaceManager:SaveSettings()
        end)
        Library.MinimizeKeybind = MenuKeybind

        local overlay = tab:AddSection("Overlay")
        local timerToggle = overlay:AddToggle("ShowSessionTimer", {
            Title = "Session timer",
            Description = "Show how long you've been in this session at the top of the screen (hours, minutes, seconds).",
            Default = Settings.ShowSessionTimer,
            Callback = function(v)
                Settings.ShowSessionTimer = v
                InterfaceManager:SaveSettings()
                if opts.onSessionTimerChanged then
                    opts.onSessionTimerChanged(v)
                end
            end,
        })
        timerToggle:SetValue(Settings.ShowSessionTimer)

        if opts.onSessionTimerChanged then
            opts.onSessionTimerChanged(Settings.ShowSessionTimer)
        end
    end
end

return InterfaceManager