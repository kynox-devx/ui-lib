local Shell = {}

Shell.GITHUB_BASE = "https://raw.githubusercontent.com/kynox-devx/ui-lib/main/Obsidian/"
Shell.REV = "ui-template-v4"

function Shell.fetch(rel)
	return game:HttpGet(Shell.GITHUB_BASE .. rel .. "?v=" .. Shell.REV)
end

function Shell.run(rel)
	local src = Shell.fetch(rel)
	local fn, err = loadstring(src, "@" .. rel)
	if not fn then
		error("Obsidian UI load failed: " .. tostring(rel) .. " (" .. tostring(err) .. ")")
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
