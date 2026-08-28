local Shell = {}

Shell.GITHUB_BASE = "https://raw.githubusercontent.com/kynox-devx/ui-lib/main/Obsidian/"
Shell.LOCAL_ROOT = "Ui/Obsidian/"

function Shell.fetch(rel)
	if type(readfile) == "function" and type(isfile) == "function" then
		local localPath = Shell.LOCAL_ROOT .. rel
		if isfile(localPath) then
			return readfile(localPath)
		end
	end
	return game:HttpGet(Shell.GITHUB_BASE .. rel)
end

function Shell.run(rel)
	local src = Shell.fetch(rel)
	local fn = loadstring(src)
	if not fn then
		error("Obsidian UI load failed: " .. tostring(rel))
	end
	fn()
end

function Shell.install()
	Shell.run("bootstrap.lua")
	Shell.run("config_ui.lua")
	Shell.run("lang.lua")
	Shell.run("layout.lua")
	Shell.run("window.lua")
	return Shell
end

return Shell
