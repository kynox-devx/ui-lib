Lang = {
	current = "en",
	entries = {},
	cache = {},
	_collected = false,
	_seen = {},
	loading = false,
	requestId = 0,
	dropdown = nil,
	notify = nil,
	_suppressDropdown = false,
	_namecallHooked = false,
	_tagged = false,
}

function Lang.repairMojibake(text)
	if typeof(text) ~= "string" or text == "" then
		return text
	end
	if not text:find("[\195-\244]") and not text:find("ÃƒÆ’") and not text:find("Ãƒâ€š") then
		return text
	end

	local bytes = {}
	for _, cp in utf8.codes(text) do
		if cp > 255 then
			return text
		end
		table.insert(bytes, cp)
	end
	if #bytes == 0 then
		return text
	end

	local ok, repaired = pcall(function()
		return string.char(table.unpack(bytes))
	end)
	if not ok or typeof(repaired) ~= "string" or repaired == "" or not utf8.len(repaired) then
		return text
	end
	if not repaired:find("ÃƒÂ Ã‚Â¸") and not repaired:find("ÃƒÆ’") and not repaired:find("Ãƒâ€š") then
		return repaired
	end
	return text
end

function Lang.isBadTranslation(text, langCode)
	if typeof(text) ~= "string" or text == "" then
		return true
	end
	if langCode == "en" or langCode == CONFIG.Lang.Source then
		return false
	end
	if text:find("ÃƒÂ Ã‚Â¸") or text:find("ÃƒÆ’") or text:find("Ãƒâ€š") or text:find("ÃƒÂ¢Ã¢â€šÂ¬") then
		return true
	end

	if text:find("Ã Â¸Â­Ã Â¸Â±Ã Â¸ÂÃ Â¸â€šÃ Â¸Â£Ã Â¸Â°Ã Â¸Å¾Ã Â¸Â´Ã Â¹â‚¬Ã Â¸Â¨Ã Â¸Â©") or text:find("Ã Â¸Â­Ã Â¸Â±Ã Â¸ÂÃ Â¸â€šÃ Â¸Â£Ã Â¸Â²Ã Â¸Â§Ã Â¸Â´Ã Â¹â‚¬Ã Â¸Â¨Ã Â¸Â©") then
		return true
	end
	local lower = text:lower()
	if lower:find("special char") or lower:find("invalid char") or lower:find("query length") then
		return true
	end
	return false
end

Lang.API_HINTS = {
	["Outline color"] = "Border color",
}

function Lang.normalizeTranslation(text, langCode)
	if typeof(text) ~= "string" or text == "" then
		return nil
	end
	local repaired = Lang.repairMojibake(text)
	if Lang.isBadTranslation(repaired, langCode) then
		return nil
	end
	return repaired
end

Lang.LANGUAGES = {
	en = "English",
	th = "Thai",
	["zh-cn"] = "Chinese Simplified",
	["zh-tw"] = "Chinese Traditional",
	es = "Spanish",
	fr = "French",
	de = "German",
	ja = "Japanese",
	ko = "Korean",
	pt = "Portuguese",
	vi = "Vietnamese",
	ru = "Russian",
	ar = "Arabic",
	id = "Indonesian",
	hi = "Hindi",
	it = "Italian",
	tr = "Turkish",
	pl = "Polish",
	nl = "Dutch",
	sv = "Swedish",
	tl = "Filipino",
	ms = "Malay",
}

Lang.DISPLAY_NAMES = {}
Lang.CODE_BY_NAME = {}
for code, name in pairs(Lang.LANGUAGES) do
	Lang.CODE_BY_NAME[name] = code
	if name ~= "English" then
		table.insert(Lang.DISPLAY_NAMES, name)
	end
end
table.sort(Lang.DISPLAY_NAMES)
table.insert(Lang.DISPLAY_NAMES, 1, "English")

Lang.SKIP_SOURCES = {}
for _, name in pairs(Lang.LANGUAGES) do
	Lang.SKIP_SOURCES[name] = true
end

function obsidianElements(owner)
	if typeof(owner) ~= "table" then
		return nil
	end
	local elements = owner.Elements
	if type(elements) == "table" then
		return elements
	end
	return nil
end

function asTable(value)
	if type(value) == "table" then
		return value
	end
	return {}
end

function asArray(value)
	return asTable(value)
end

function eachInstanceDescendants(root, callback)
	if typeof(root) ~= "Instance" then
		return
	end
	for _, desc in ipairs(root:GetDescendants()) do
		callback(desc)
	end
end

function langHttpRequest(opts)
	local req = (syn and syn.request) or request or (http and http.request) or (fluxus and fluxus.request)
	if not req then
		return nil
	end
	return req(opts)
end

function langFetch(url, method, body, headers)
	method = method or "GET"
	headers = headers or {}

	local res = langHttpRequest({
		Url = url,
		Method = method,
		Headers = headers,
		Body = body,
	})
	if res and res.Body and res.Body ~= "" then
		return res.Body
	end

	if method == "GET" then
		local ok, result = pcall(function()
			return game:HttpGet(url, true)
		end)
		if ok and result and result ~= "" then
			return result
		end

		local ok2, result2 = pcall(function()
			return HttpService:GetAsync(url)
		end)
		if ok2 and result2 and result2 ~= "" then
			return result2
		end
	end

	return nil
end

function Lang.toApiCode(code)
	local map = {
		["zh-cn"] = "zh-CN",
		["zh-tw"] = "zh-TW",
	}
	return map[code] or code
end

function translateViaMyMemory(text, toCode)
	local from = Lang.toApiCode(CONFIG.Lang.Source)
	local to = Lang.toApiCode(toCode)
	local url = ("https://api.mymemory.translated.net/get?q=%s&langpair=%s|%s"):format(
		HttpService:UrlEncode(text),
		HttpService:UrlEncode(from),
		HttpService:UrlEncode(to)
	)
	local body = langFetch(url)
	if not body then
		error("mymemory empty response")
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if not ok or typeof(data) ~= "table" then
		error("mymemory json error")
	end
	if tonumber(data.responseStatus) ~= 200 then
		error(data.responseDetails or "mymemory status error")
	end
	local translated = data.responseData and data.responseData.translatedText
	if typeof(translated) ~= "string" or translated == "" then
		error("mymemory empty translation")
	end
	return translated
end

function translateViaLingva(text, toCode)
	local from = Lang.toApiCode(CONFIG.Lang.Source)
	local to = Lang.toApiCode(toCode)
	local bases = {
		"https://lingva.ml",
		"https://translate.plausibility.cloud",
		"https://lingva.garudalinux.org",
	}
	for _, base in ipairs(bases) do
		local url = ("%s/api/v1/%s/%s/%s"):format(base, from, to, HttpService:UrlEncode(text))
		local body = langFetch(url)
		if body then
			local ok, data = pcall(function()
				return HttpService:JSONDecode(body)
			end)
			if ok and data and typeof(data.translation) == "string" and data.translation ~= "" then
				return data.translation
			end
		end
	end
	error("lingva failed")
end

local googlev = (isfile and isfile(CONFIG.Lang.ConsentFile) and readfile(CONFIG.Lang.ConsentFile)) or ""

function googleConsent(body)
	for match in body:gmatch('<input type="hidden" name=".-" value=".-">') do
		local k, v = match:match('<input type="hidden" name="(.-)" value="(.-)">')
		if k and v then
			if k == "v" then
				googlev = v
				if writefile then
					writefile(CONFIG.Lang.ConsentFile, v)
				end
			end
		end
	end
end

function langGot(url, method, body)
	method = method or "GET"
	local res = langHttpRequest({
		Url = url,
		Method = method,
		Headers = { cookie = "CONSENT=YES+" .. googlev },
		Body = body,
	})
	if not res then
		return nil
	end
	if res.Body and res.Body:match("https://consent.google.com/s") then
		googleConsent(res.Body)
		res = langHttpRequest({
			Url = url,
			Method = method,
			Headers = { cookie = "CONSENT=YES+" .. googlev },
			Body = body,
		})
	end
	return res
end

function stringifyQuery(dataFields)
	local data = ""
	for k, v in pairs(dataFields) do
		data ..= ("&%s=%s"):format(HttpService:UrlEncode(k), HttpService:UrlEncode(v))
	end
	return data:sub(2)
end

local gReqId = math.random(1000, 9999)
local gFsid, gBl
local gTranslateReady = false

function translateViaGtx(text, toCode)
	local from = Lang.toApiCode(CONFIG.Lang.Source)
	local to = Lang.toApiCode(toCode)
	local url = ("https://translate.googleapis.com/translate_a/single?client=gtx&sl=%s&tl=%s&dt=t&q=%s"):format(
		from,
		to,
		HttpService:UrlEncode(text)
	)

	local body = langFetch(url)
	if not body or body == "" then
		error("gtx empty response")
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if not ok or typeof(decoded) ~= "table" or typeof(decoded[1]) ~= "table" then
		error("gtx json parse failed")
	end

	local translated = ""
	for _, segment in ipairs(decoded[1]) do
		if typeof(segment) == "table" and segment[1] then
			translated ..= segment[1]
		end
	end

	if translated == "" then
		error("gtx empty translated text")
	end

	return translated
end

function Lang.codeFromDisplay(name)
	return Lang.CODE_BY_NAME[name] or "en"
end

function Lang.displayFromCode(code)
	return Lang.LANGUAGES[code] or "English"
end

function Lang.loadCache()
	if not (isfile and readfile and isfile(CONFIG.Lang.CacheFile)) then
		return
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(readfile(CONFIG.Lang.CacheFile))
	end)
	if ok and typeof(decoded) == "table" then
		Lang.cache = decoded
		for langCode, entries in pairs(Lang.cache) do
			if typeof(entries) == "table" then
				for source, text in pairs(entries) do
					if typeof(Lang.SKIP_SOURCES) == "table" and Lang.SKIP_SOURCES[source] then
						entries[source] = nil
						continue
					end
					local normalized = Lang.normalizeTranslation(text, langCode)
					if normalized then
						entries[source] = normalized
					else
						entries[source] = nil
					end
				end
			end
		end
	end
end

function Lang.saveCache()
	if not writefile then
		return
	end
	pcall(function()
		writefile(CONFIG.Lang.CacheFile, HttpService:JSONEncode(Lang.cache))
	end)
end

function Lang.translate(text, toCode)
	if not text or text == "" then
		return text
	end

	local apiText = Lang.API_HINTS[text] or text

	local providers = {
		translateViaGtx,
		translateViaLingva,
		translateViaMyMemory,
	}

	for _, provider in ipairs(providers) do
		local ok, result = pcall(function()
			return provider(apiText, toCode)
		end)
		if ok and typeof(result) == "string" and result ~= "" and not result:match("^MYMEMORY WARNING") then
			local normalized = Lang.normalizeTranslation(result, toCode)
			if normalized then
				return normalized
			end
		end
	end

	if not gTranslateReady then
		local initial = langGot("https://translate.google.com/")
		if initial and initial.Body then
			gFsid = initial.Body:match('"FdrFJe":"(.-)"')
			gBl = initial.Body:match('"cfb2h":"(.-)"')
			gTranslateReady = gFsid ~= nil and gBl ~= nil
		end
	end
	if gTranslateReady then
		gReqId += 10000
		local payload = { { { apiText, CONFIG.Lang.Source, toCode, true }, { nil } } }
		local freq = { { { "MkEWBc", HttpService:JSONEncode(payload), nil, "generic" } } }
		local url = "https://translate.google.com/_/TranslateWebserverUi/data/batchexecute?"
			.. stringifyQuery({
				rpcids = "MkEWBc",
				["f.sid"] = gFsid,
				bl = gBl,
				hl = "en",
				_reqid = gReqId - 10000,
				rt = "c",
			})
		local req = langGot(url, "POST", stringifyQuery({ ["f.req"] = HttpService:JSONEncode(freq) }))
		if req and req.Body then
			local chunk = req.Body:match("%[.-%]\n")
			if chunk then
				local outer = HttpService:JSONDecode(chunk)
				local translationData = HttpService:JSONDecode(outer[1][3])
				local out = translationData[2][1][1][6][1][1]
				if typeof(out) == "string" and out ~= "" then
					local normalized = Lang.normalizeTranslation(out, toCode)
					if normalized then
						return normalized
					end
				end
			end
		end
	end

	error("all translate providers failed")
end

function resolveLangSource(element, fallback)
	if typeof(element) ~= "table" then
		return nil
	end
	if typeof(element._langSource) == "string" and element._langSource ~= "" then
		return element._langSource
	end
	if typeof(element.Text) == "string" and element.Text ~= "" then
		return element.Text
	end
	if typeof(fallback) == "string" and fallback ~= "" then
		return fallback
	end
	return nil
end

function getElementTextLabel(element)
	if typeof(element) ~= "table" then
		return nil
	end
	if element.TextLabel and element.TextLabel:IsA("TextLabel") then
		return element.TextLabel
	end
	if element.Holder then
		for _, child in ipairs(element.Holder:GetChildren()) do
			if child:IsA("TextLabel") then
				return child
			end
		end
		for _, desc in ipairs(element.Holder:GetDescendants()) do
			if desc:IsA("TextLabel") and desc.Size.Y.Offset <= 18 then
				return desc
			end
		end
	end
	return nil
end

function Lang.stampSource(instance, source)
	if not instance or typeof(source) ~= "string" or source == "" then
		return source
	end
	local existing = instance:GetAttribute("LangSource")
	if typeof(existing) == "string" and existing ~= "" then
		return existing
	end
	instance:SetAttribute("LangSource", source)
	return source
end

function Lang.findGroupboxTitleLabel(groupbox)
	if typeof(groupbox) ~= "table" then
		return nil
	end
	if groupbox._langTitleLabel and groupbox._langTitleLabel.Parent then
		return groupbox._langTitleLabel
	end
	local holder = groupbox and groupbox.Holder
	if not holder then
		return nil
	end
	for _, child in ipairs(holder:GetChildren()) do
		if child:IsA("TextLabel") and child.Size.Y.Offset >= 30 then
			groupbox._langTitleLabel = child
			return child
		end
	end
	for _, child in ipairs(holder:GetChildren()) do
		if child:IsA("TextLabel") and child.Position.Y.Offset <= 1 then
			groupbox._langTitleLabel = child
			return child
		end
	end
	return nil
end

local LANG_SKIP_TEXT = {
	MB1 = true,
	MB2 = true,
	MB3 = true,
}

local LANG_SKIP_SOURCES = Lang.SKIP_SOURCES

function Lang.shouldTagText(text)
	if typeof(text) ~= "string" or text == "" then
		return false
	end
	if LANG_SKIP_TEXT[text] or LANG_SKIP_SOURCES[text] then
		return false
	end
	if text:match("^[%d%%%s%/:%-%.]+$") then
		return false
	end
	return true
end

function Lang.tagElementLabels()
	if UiSafe.uiOpacityMutate == false then
		return
	end
	pcall(function()
		Lang.eachGroupboxElement(function(element)
			local source = element._langSource
			if typeof(source) ~= "string" or source == "" then
				source = resolveLangSource(element)
			end
			if typeof(source) ~= "string" or source == "" or LANG_SKIP_SOURCES[source] then
				return
			end
			if not Lang.shouldTagText(source) then
				return
			end

			element._langSource = source
			local textLabel = element.TextLabel or getElementTextLabel(element)
			if textLabel then
				pcall(Lang.stampSource, textLabel, source)
			end
			if element.Base then
				pcall(function()
					if element.Base:IsA("TextButton") then
						Lang.stampSource(element.Base, source)
					end
				end)
			end
		end)
	end)
end

function Lang.tagSearchField()
	local main = Library.ScreenGui and Library.ScreenGui:FindFirstChild("Main")
	if not main then
		return
	end
	for _, desc in ipairs(main:GetDescendants()) do
		if desc:IsA("TextBox") and desc.PlaceholderText == "Search" then
			desc:SetAttribute("LangSource", "Search")
			desc:SetAttribute("LangPlaceholder", true)
			break
		end
	end
end

function Lang.tagTranslatableInstances()
	if Lang._tagged then
		return
	end

	local root = Library.ScreenGui
	if not root then
		return
	end

	for _, tab in pairs(asTable(Library.Tabs)) do
		if tab.Groupboxes then
			for groupName, groupbox in pairs(tab.Groupboxes) do
				if typeof(groupbox) ~= "table" then
					continue
				end
				if typeof(groupName) == "string" and groupName ~= "" then
					local holder = groupbox.Holder
					if holder then
						for _, child in ipairs(holder:GetChildren()) do
							if child:IsA("TextLabel") and child.Position.Y.Offset <= 1 then
								child:SetAttribute("LangSource", groupName)
								break
							end
						end
					end
				end
			end
		end
		if tab.Tabboxes then
			for _, tabbox in pairs(tab.Tabboxes) do
				if typeof(tabbox) ~= "table" then
					continue
				end
				for subName, subTab in pairs(asTable(tabbox.Tabs)) do
					if typeof(subTab) ~= "table" then
						continue
					end
					if typeof(subName) == "string" and subName ~= "" then
						local holder = subTab.ButtonHolder
						if holder then
							local label = holder:FindFirstChildWhichIsA("TextLabel", true)
							if label then
								label:SetAttribute("LangSource", subName)
							end
						end
					end
				end
			end
		end
	end

	for _, tabButton in ipairs(asArray(Library.TabButtons)) do
		local label = tabButton.Label
		local src = tabButton._langSource
		if label and typeof(src) == "string" and src ~= "" then
			Lang.stampSource(label, src)
		end
	end

	Lang.tagElementLabels()
	Lang.tagSearchField()
	Lang._tagged = true
end

function Lang.applyChrome(resolveText)
	for _, tabButton in ipairs(asArray(Library.TabButtons)) do
		local label = tabButton.Label
		if not label then
			continue
		end
		local src = tabButton._langSource or label:GetAttribute("LangSource")
		if typeof(src) ~= "string" or src == "" then
			continue
		end
		label.Text = resolveText(src)
	end

	for _, tab in pairs(asTable(Library.Tabs)) do
		if tab.Groupboxes then
			for groupName, groupbox in pairs(tab.Groupboxes) do
				if typeof(groupbox) ~= "table" then
					continue
				end
				local label = Lang.findGroupboxTitleLabel(groupbox)
				if label then
					label.Text = resolveText(groupName)
				end
			end
		end
		if tab.Tabboxes then
			for _, tabbox in pairs(tab.Tabboxes) do
				if typeof(tabbox) ~= "table" then
					continue
				end
				for subName, subTab in pairs(asTable(tabbox.Tabs)) do
					if typeof(subTab) ~= "table" then
						continue
					end
					local holder = subTab.ButtonHolder
					if holder then
						pcall(function()
							for _, desc in ipairs(holder:GetDescendants()) do
								if desc:IsA("TextLabel") then
									desc.Text = resolveText(subName)
									break
								end
							end
						end)
					end
				end
			end
		end
	end

	for _, toggle in pairs(asTable(Library.Toggles)) do
		local src = toggle._langSource or resolveLangSource(toggle)
		if typeof(src) ~= "string" or src == "" or LANG_SKIP_SOURCES[src] then
			continue
		end
		toggle._langSource = src
		Lang.applyTextToElement(toggle, resolveText(src))
		local tipSrc = toggle._langTooltipSource
		if typeof(tipSrc) == "string" and tipSrc ~= "" and not LANG_SKIP_SOURCES[tipSrc] then
			local tipText = resolveText(tipSrc)
			toggle.Tooltip = tipText
			if toggle.TooltipTable and UiSafe.fluentMethods ~= false then
				pcall(function()
					if typeof(toggle.TooltipTable.SetText) == "function" then
						toggle.TooltipTable:SetText(tipText)
					elseif typeof(toggle.TooltipTable.Update) == "function" then
						toggle.TooltipTable:Update(tipText)
					end
				end)
			end
		end
	end

	for _, option in pairs(asTable(Library.Options)) do
		local src = option._langSource or resolveLangSource(option)
		if typeof(src) ~= "string" or src == "" or LANG_SKIP_SOURCES[src] then
			continue
		end
		option._langSource = src
		if option.Type == "Slider" or option.Type == "Dropdown" or option.Type == "Input" then
			Lang.applyTextToElement(option, resolveText(src))
		end
		if option.Type == "Input" and typeof(option.Placeholder) == "string" and option.Placeholder ~= "" then
			local ps = option._langPlaceholderSource or option.Placeholder
			option._langPlaceholderSource = ps
			local translated = resolveText(ps)
			option.Placeholder = translated
			if option.Holder then
				local box = option.Holder:FindFirstChildWhichIsA("TextBox", true)
				if box then
					box.PlaceholderText = translated
				end
			end
		end
	end

	Lang.eachGroupboxElement(function(element)
		local src = element._langSource or resolveLangSource(element)
		if typeof(src) ~= "string" or src == "" or LANG_SKIP_SOURCES[src] then
			return
		end
		element._langSource = src
		Lang.applyTextToElement(element, resolveText(src))
	end)

	local main = Library.ScreenGui and Library.ScreenGui:FindFirstChild("Main")
	if main then
		for _, desc in ipairs(main:GetDescendants()) do
			if desc:IsA("TextBox") and desc:GetAttribute("LangPlaceholder") then
				local src = desc:GetAttribute("LangSource") or "Search"
				desc.PlaceholderText = resolveText(src)
				break
			end
		end
	end
end

function Lang.bindTextLabel(label, fallback)
	if not (label and label:IsA("TextLabel")) then
		return
	end
	local source = label:GetAttribute("LangSource")
	if not source or source == "" then
		source = fallback or (label.Text ~= "" and label.Text)
	end
	if typeof(source) ~= "string" or source == "" then
		return
	end
	source = Lang.stampSource(label, source)
	Lang.register(source, function(text)
		label.Text = text
	end)
end

function Lang.applyTextToElement(element, text)
	if typeof(element) ~= "table" or typeof(text) ~= "string" then
		return
	end

	local elementType = element.Type
	element.Text = text
	local useFluent = UiSafe.fluentMethods ~= false

	if elementType == "Toggle" or element.Variant == "Checkbox" then
		pcall(function()
			if element.TextLabel and element.TextLabel:IsA("TextLabel") then
				element.TextLabel.Text = text
			end
		end)
		if useFluent and typeof(element.SetText) == "function" then
			pcall(function()
				element:SetText(text)
			end)
		end
		return
	end

	if elementType == "Slider" then
		if useFluent and typeof(element.SetText) == "function" then
			pcall(function()
				element:SetText(text)
			end)
		elseif element.Holder then
			pcall(function()
				for _, child in ipairs(element.Holder:GetChildren()) do
					if child:IsA("TextLabel") and child.Size.Y.Offset <= 16 then
						child.Text = text
						break
					end
				end
			end)
		end
		return
	end

	if elementType == "Dropdown" then
		if useFluent and typeof(element.SetText) == "function" then
			pcall(function()
				element:SetText(text)
			end)
		elseif element.Holder then
			pcall(function()
				for _, child in ipairs(element.Holder:GetChildren()) do
					if child:IsA("TextLabel") then
						child.Text = text
						break
					end
				end
			end)
		end
		return
	end

	if elementType == "Label" then
		if useFluent and typeof(element.SetText) == "function" then
			pcall(function()
				element:SetText(text)
			end)
		else
			pcall(function()
				if element.TextLabel and element.TextLabel:IsA("TextLabel") then
					element.TextLabel.Text = text
				end
			end)
		end
		return
	end

	if useFluent and typeof(element.SetText) == "function" then
		pcall(function()
			element:SetText(text)
		end)
	end
	pcall(function()
		if element.TextLabel and element.TextLabel:IsA("TextLabel") then
			element.TextLabel.Text = text
		end
	end)
	local textLabel = getElementTextLabel(element)
	if textLabel and textLabel.Parent then
		textLabel.Text = text
	end
	if element.Base and element.Base:IsA("TextButton") then
		element.Base.Text = text
	end
end

function Lang.eachGroupboxElement(callback)
	for _, tab in pairs(asTable(Library.Tabs)) do
		if tab.Groupboxes then
			for _, groupbox in pairs(tab.Groupboxes) do
				if typeof(groupbox) ~= "table" then
					continue
				end
				local elements = obsidianElements(groupbox)
				if elements then
					for _, element in elements do
						callback(element)
					end
				end
			end
		end
		if tab.Tabboxes then
			for _, tabbox in pairs(tab.Tabboxes) do
				if typeof(tabbox) ~= "table" then
					continue
				end
				for _, subTab in pairs(asTable(tabbox.Tabs)) do
					local elements = obsidianElements(subTab)
					if elements then
						for _, element in elements do
							callback(element)
						end
					end
				end
			end
		end
	end
end

function Lang.gatherAllSources(unique)
	function add(src)
		if typeof(src) ~= "string" or src == "" or LANG_SKIP_SOURCES[src] then
			return
		end
		if not Lang.shouldTagText(src) and src ~= CONFIG.Window.Title and src ~= CONFIG.Window.SubTitle and src ~= "Search" then
			return
		end
		unique[src] = true
	end

	add(CONFIG.Window.Title)
	add(CONFIG.Window.SubTitle)
	add("Search")

	for _, entry in ipairs(asArray(Lang.entries)) do
		add(entry.source)
	end

	for _, tabButton in ipairs(asArray(Library.TabButtons)) do
		if tabButton.Label then
			add(tabButton.Label:GetAttribute("LangSource"))
		end
	end

	for _, tab in pairs(asTable(Library.Tabs)) do
		if tab.Groupboxes then
			for groupName in pairs(tab.Groupboxes) do
				add(groupName)
			end
		end
		if tab.Tabboxes then
			for _, tabbox in pairs(tab.Tabboxes) do
				if typeof(tabbox) ~= "table" then
					continue
				end
				for subName in pairs(asTable(tabbox.Tabs)) do
					add(subName)
				end
			end
		end
	end

	for _, toggle in pairs(asTable(Library.Toggles)) do
		local src = toggle._langSource or resolveLangSource(toggle)
		if typeof(src) == "string" and src ~= "" then
			toggle._langSource = src
			add(src)
		end
		if typeof(toggle.Tooltip) == "string" then
			add(toggle._langTooltipSource or toggle.Tooltip)
		end
	end

	for _, option in pairs(asTable(Library.Options)) do
		local src = option._langSource or resolveLangSource(option)
		if typeof(src) == "string" and src ~= "" then
			option._langSource = src
			add(src)
		end
		if typeof(option.Tooltip) == "string" then
			add(option._langTooltipSource or option.Tooltip)
		end
		if option.Type == "Input" and typeof(option.Placeholder) == "string" then
			add(option._langPlaceholderSource or option.Placeholder)
		end
	end

	if Library.Labels then
		for _, label in pairs(Library.Labels) do
			local src = label._langSource or resolveLangSource(label)
			if typeof(src) == "string" and src ~= "" then
				label._langSource = src
				add(src)
			end
		end
	end

	Lang.eachGroupboxElement(function(element)
		local src = element._langSource or resolveLangSource(element)
		if typeof(src) == "string" and src ~= "" then
			element._langSource = src
			add(src)
		end
		if typeof(element.Tooltip) == "string" then
			add(element._langTooltipSource or element.Tooltip)
		end
		if element.Type == "Input" and typeof(element.Placeholder) == "string" then
			add(element._langPlaceholderSource or element.Placeholder)
		end
	end)
end

function Lang.bindObsidianElement(element, fallback)
	if typeof(element) ~= "table" or Lang._seen[element] then
		return
	end

	local elementType = element.Type
	local textLabel = getElementTextLabel(element)
	local source = resolveLangSource(element, fallback)
	if (not source or source == "") and textLabel and textLabel.Text ~= "" then
		source = textLabel:GetAttribute("LangSource") or textLabel.Text
	end
	if typeof(source) ~= "string" or source == "" then
		return
	end

	Lang._seen[element] = true
	element._langSource = element._langSource or source
	source = element._langSource
	if textLabel then
		Lang.stampSource(textLabel, source)
	end

	Lang.register(source, function(text)
		Lang.applyTextToElement(element, text)
	end)

	if Lang.current ~= "en" and Lang.current ~= CONFIG.Lang.Source then
		local cached = Lang.cache[Lang.current] and Lang.cache[Lang.current][source]
		if cached then
			local normalized = Lang.normalizeTranslation(cached, Lang.current)
			if normalized then
				Lang.applyTextToElement(element, normalized)
			end
		end
	end

	if elementType == "Input" and typeof(element.Placeholder) == "string" and element.Placeholder ~= "" then
		local placeholderSource = element._langPlaceholderSource or element.Placeholder
		element._langPlaceholderSource = placeholderSource
		Lang.register(placeholderSource, function(text)
			element.Placeholder = text
			if element.Holder then
				local box = element.Holder:FindFirstChildWhichIsA("TextBox", true)
				if box then
					box.PlaceholderText = text
				end
			end
		end)
	end

	if typeof(element.Tooltip) == "string" and element.Tooltip ~= "" and not element._langTooltipBound then
		element._langTooltipBound = true
		local tipSource = element._langTooltipSource or element.Tooltip
		element._langTooltipSource = tipSource
		Lang.register(tipSource, function(text)
			element.Tooltip = text
			if element.TooltipTable then
				if typeof(element.TooltipTable.SetText) == "function" then
					element.TooltipTable:SetText(text)
				elseif typeof(element.TooltipTable.Update) == "function" then
					element.TooltipTable:Update(text)
				end
			end
		end)
	end
end

function Lang.bindGroupboxTitle(groupName, groupbox)
	if typeof(groupName) ~= "string" or groupName == "" or typeof(groupbox) ~= "table" then
		return
	end

	groupbox._langName = groupName
	if groupbox._langGroupTitleBound then
		return
	end
	groupbox._langGroupTitleBound = true
	Lang.register(groupName, function(text)
			local label = Lang.findGroupboxTitleLabel(groupbox)
		if label then
			label.Text = text
			Lang.stampSource(label, groupName)
		end
	end)

end

function Lang.bindSearchField()
	local main = Library.ScreenGui and Library.ScreenGui:FindFirstChild("Main")
	if not main then
		return
	end

	for _, child in ipairs(main:GetDescendants()) do
		if child:IsA("TextBox") and child.PlaceholderText == "Search" then
			Lang.register("Search", function(text)
				child.PlaceholderText = text
			end)
			break
		end
	end
end

function Lang.register(source, applyFn)
	if typeof(source) ~= "string" or source == "" or typeof(applyFn) ~= "function" then
		return
	end
	table.insert(Lang.entries, { source = source, apply = applyFn })
end

function parseTabName(...)
	if select("#", ...) == 1 and typeof(select(1, ...)) == "table" then
		return select(1, ...).Name or "Tab"
	end
	return select(1, ...) or "Tab"
end

function Lang.bindTabboxSubTabLabel(subTab, name)
	if typeof(subTab) ~= "table" or subTab._langSubTabBound then
		return
	end
	subTab._langSubTabBound = true
	Lang.register(name, function(text)
			local holder = subTab.ButtonHolder
		if not holder then
			return
		end
		local label = holder:FindFirstChildWhichIsA("TextLabel", true)
		if label then
			Lang.stampSource(label, name)
			label.Text = text
		end
	end)

end

function Lang.hookTabboxObject(tabbox)
	if not tabbox or tabbox._langHooked then
		return
	end
	tabbox._langHooked = true

	local origAddTab = tabbox.AddTab
	if typeof(origAddTab) ~= "function" then
		return
	end

	tabbox.AddTab = function(self, name, ...)
		local subTab = origAddTab(self, name, ...)
		Lang.bindTabboxSubTabLabel(subTab, name)
		return subTab
	end
end

function Lang.hookTabTabboxMethods(tab)
	if not tab or tab._langTabboxHooked then
		return
	end
	tab._langTabboxHooked = true

	function wrap(methodName)
		local orig = tab[methodName]
		if typeof(orig) ~= "function" then
			return
		end
		tab[methodName] = function(self, ...)
			local result = orig(self, ...)
			Lang.hookTabboxObject(result)
			return result
		end
	end

	wrap("AddLeftTabbox")
	wrap("AddRightTabbox")
	wrap("AddTabbox")
end

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

function findObsidianGroupbox(element)
	if typeof(element) ~= "table" then
		return nil
	end
	local cursor = element
	for _ = 1, 14 do
		if typeof(cursor) ~= "table" then
			break
		end
		if typeof(cursor.Resize) == "function" and cursor.Container and cursor.Holder then
			return cursor
		end
		if typeof(cursor.Groupbox) == "table" then
			cursor = cursor.Groupbox
		elseif typeof(cursor.Parent) == "table" then
			cursor = cursor.Parent
		else
			break
		end
	end
	return nil
end

function safeResizeObsidianLayout(element)
	if element == nil then
		return
	end
	pcall(function()
		if typeof(element) == "table" and typeof(element.Resize) == "function" and element.Container then
			element:Resize()
		end
	end)
	local groupbox = findObsidianGroupbox(element)
	if groupbox then
		UiLayout.hookGroupbox(groupbox)
		pcall(function()
			groupbox:Resize()
		end)
	end
	UiLayout.scheduleRefresh()
end

function Lang.hookTabObject(tab)
	if not tab or tab._langTabHooked then
		return
	end
	tab._langTabHooked = true

	Lang.hookTabTabboxMethods(tab)

	function wrapGroupboxMethod(methodName, isTableInfo)
		local orig = tab[methodName]
		if typeof(orig) ~= "function" then
			return
		end
		tab[methodName] = function(self, ...)
			local result = orig(self, ...)
			local groupName
			if isTableInfo then
				local info = select(1, ...)
				groupName = typeof(info) == "table" and info.Name or nil
			else
				groupName = select(1, ...)
			end
			if groupName and result then
				Lang.bindGroupboxTitle(groupName, result)
				Lang.installGroupboxNamecallHook(result)
				UiLayout.hookGroupbox(result)
			end
			return result
		end
	end

	wrapGroupboxMethod("AddLeftGroupbox", false)
	wrapGroupboxMethod("AddRightGroupbox", false)
	wrapGroupboxMethod("AddGroupbox", true)
end

function Lang.installGroupboxNamecallHook(groupbox)
	if Lang._groupboxNamecallHooked or typeof(groupbox) ~= "table" then
		return
	end
	local mt = getmetatable(groupbox)
	if not mt or typeof(mt.__namecall) ~= "function" then
		return
	end

	local origNamecall = mt.__namecall
	mt.__namecall = function(obj, key, ...)
		local result = origNamecall(obj, key, ...)
		if typeof(result) == "table" then
			local bindAfter = {
				AddToggle = true,
				AddCheckbox = true,
				AddSlider = true,
				AddDropdown = true,
				AddInput = true,
				AddLabel = true,
				AddButton = true,
			}
			if bindAfter[key] then
				Lang.bindObsidianElement(result)
			end
			if key == "AddSlider" then
				SliderUi.attachValueClickInput(result)
			end
		end
		return result
	end

	Lang._groupboxNamecallHooked = true
end

function Lang.onTabCreated(name)
	local tabButton = Library.TabButtons and Library.TabButtons[#Library.TabButtons]
	if tabButton then
		tabButton._langSource = name
		if tabButton.Label then
			Lang.bindTextLabel(tabButton.Label, name)
		end
	end
end

function Lang.refreshElementSources()
	for _, toggle in pairs(asTable(Library.Toggles)) do
		if typeof(toggle.Text) == "string" and toggle.Text ~= "" then
			toggle._langSource = toggle._langSource or toggle.Text
		end
	end
	for _, option in pairs(asTable(Library.Options)) do
		if typeof(option.Text) == "string" and option.Text ~= "" then
			option._langSource = option._langSource or option.Text
		end
	end
end

function Lang.installWindowHooks(window)
	if not window or window._langHooked then
		return
	end
	window._langHooked = true

	local origAddTab = window.AddTab
	if typeof(origAddTab) ~= "function" then
		return
	end

	window.AddTab = function(...)
		local tabName = parseTabName(...)
		local tab = origAddTab(...)
		Lang.hookTabObject(tab)
		Lang.installGroupboxNamecallHook(tab)
		Lang.onTabCreated(tabName)
		return tab
	end
end

function Lang.collect(window)
	if Lang._collected then
		return
	end
	Lang._collected = true

	if window then
		Lang.register(CONFIG.Window.Title, function(text)
			window:ChangeTitle(text)
		end)
		Lang.register(CONFIG.Window.SubTitle, function(text)
			window:SetFooter(text)
		end)
	end

	for _, tabButton in ipairs(asArray(Library.TabButtons)) do
		if not tabButton._langSource and tabButton.Label then
			tabButton._langSource = tabButton.Label:GetAttribute("LangSource") or tabButton.Label.Text
		end
		Lang.bindTextLabel(tabButton.Label, tabButton._langSource)
	end

	Lang.bindSearchField()

	for _, tab in pairs(asTable(Library.Tabs)) do
		if tab.Groupboxes then
			for groupName, groupbox in pairs(tab.Groupboxes) do
				if typeof(groupbox) ~= "table" then
					continue
				end
				Lang.bindGroupboxTitle(groupName, groupbox)
				local elements = obsidianElements(groupbox)
				if elements then
					for _, element in elements do
						Lang.bindObsidianElement(element)
					end
				end
			end
		end
		if tab.Tabboxes then
			for _, tabbox in pairs(tab.Tabboxes) do
				if typeof(tabbox) ~= "table" then
					continue
				end
				for subName, subTab in pairs(asTable(tabbox.Tabs)) do
					if typeof(subTab) ~= "table" then
						continue
					end
					Lang.bindTabboxSubTabLabel(subTab, subName)
					local elements = obsidianElements(subTab)
					if elements then
						for _, element in elements do
							Lang.bindObsidianElement(element)
						end
					end
				end
			end
		end
	end

	for _, option in pairs(Options) do
		Lang.bindObsidianElement(option)
	end

	for _, toggle in pairs(Toggles) do
		Lang.bindObsidianElement(toggle)
	end

	if Library.Labels then
		for _, label in pairs(Library.Labels) do
			Lang.bindObsidianElement(label)
		end
	end
end

function Lang.setDropdownLocked(locked)
	local dropdown = Lang.dropdown
	if dropdown and typeof(dropdown.SetDisabled) == "function" then
		dropdown:SetDisabled(locked)
	end
end

function Lang.setDropdownDisplay(displayName)
	if Lang._suppressDropdown or not Lang.dropdown then
		return
	end
	Lang._suppressDropdown = true
	Lang.dropdown:SetValue(displayName or Lang.displayFromCode(Lang.current))
	Lang._suppressDropdown = false
end

function Lang.dismissLoadingNotify()
	if Lang.notify and typeof(Lang.notify.Destroy) == "function" then
		Lang.notify:Destroy()
	end
	Lang.notify = nil
end

function Lang.countUniqueSources()
	local unique = {}
	Lang.gatherAllSources(unique)
	local total = 0
	for _ in pairs(unique) do
		total += 1
	end
	return total
end

function Lang.requestApply(langCode, window, displayName)
	langCode = langCode or "en"
	displayName = displayName or Lang.displayFromCode(langCode)

	if Lang.loading then
		Lang.setDropdownDisplay()
		return false
	end

	if langCode == Lang.current then
		return true
	end

	local needsTranslation = langCode ~= "en" and langCode ~= CONFIG.Lang.Source
	if not needsTranslation then
		Lang.apply(langCode, window, { silent = true })
		Library:Notify({
			Title = "Language",
			Description = "Language updated",
			Time = 2,
		})
		return true
	end

	Lang.loading = true
	Lang.requestId += 1
	local requestId = Lang.requestId

	Lang.setDropdownLocked(true)
	Lang.notify = Library:Notify({
		Title = "Language",
		Description = ("Loading %s… Please wait"):format(displayName),
		Persist = true,
		Steps = 100,
	})

	local applyOk, success, failCount = pcall(function()
		return Lang.apply(langCode, window, {
			silent = true,
			requestId = requestId,
			onProgress = function(done, total)
				if Lang.requestId ~= requestId or not Lang.notify then
					return
				end
				local pct = total > 0 and math.floor((done / total) * 100) or 100
				local line = total > 0
					and ("Translating %s… %d/%d"):format(displayName, done, total)
					or ("Translating %s…"):format(displayName)
				Lang.notify:ChangeDescription(line)
				Lang.notify:ChangeStep(pct)
			end,
		})
	end)

	if Lang.requestId == requestId then
		Lang.dismissLoadingNotify()
		Lang.setDropdownLocked(false)
		Lang.loading = false
	end

	if Lang.requestId ~= requestId then
		return false
	end

	if not applyOk then
		Lang.setDropdownDisplay()
		Library:Notify({
			Title = "Language",
			Description = "Failed to load language. Please try again.",
			Time = 5,
		})
		return false
	end

	if not success and failCount == 0 then
		Lang.setDropdownDisplay()
		return false
	end

	if failCount > 0 then
		Library:Notify({
			Title = "Language",
			Description = ("Done with %d translation error(s)"):format(failCount),
			Time = 6,
		})
	else
		Library:Notify({
			Title = "Language",
			Description = "Language updated",
			Time = 3,
		})
	end

	return failCount == 0
end

function Lang.apply(langCode, window, opts)
	langCode = langCode or "en"
	opts = opts or {}

	if window then
		Lang.collect(window)
	end

	if not Lang._tagged then
		Lang.tagTranslatableInstances()
	end

	local uniqueSources = {}
	Lang.gatherAllSources(uniqueSources)
	local sourceCount = 0
	for _ in pairs(uniqueSources) do
		sourceCount += 1
	end

	if sourceCount == 0 then
		if not opts.silent then
			Library:Notify({
				Title = "Language",
				Description = "No UI text found to translate",
				Time = 4,
			})
		end
		return false, 0
	end

	function isActive()
		return not opts.requestId or Lang.requestId == opts.requestId
	end

	function resolveFromMap(source)
		return source
	end

	if langCode == "en" or langCode == CONFIG.Lang.Source then
		for _, entry in ipairs(asArray(Lang.entries)) do
			entry.apply(entry.source)
		end
		Lang.applyChrome(resolveFromMap)
		if window then
			window:ChangeTitle(CONFIG.Window.Title)
			window:SetFooter(CONFIG.Window.SubTitle)
		end
		Lang.current = "en"
		UiLayout.scheduleRefresh()
		return true, 0
	end

	local total = sourceCount
	local apiDone = 0
	function reportApiProgress()
		apiDone += 1
		if opts.onProgress then
			opts.onProgress(apiDone, total)
		end
	end

	if not opts.silent then
		Library:Notify({
			Title = "Language",
			Description = ("Translating %d strings…"):format(total),
			Time = 3,
		})
	end

	Lang.cache[langCode] = Lang.cache[langCode] or {}
	local translatedBySource = {}
	local failCount = 0

	for source in pairs(uniqueSources) do
		local cached = Lang.cache[langCode][source]
		if cached then
			local normalized = Lang.normalizeTranslation(cached, langCode)
			if normalized then
				translatedBySource[source] = normalized
				if normalized ~= cached then
					Lang.cache[langCode][source] = normalized
				end
			else
				Lang.cache[langCode][source] = nil
			end
		end
	end

	local apiQueue = {}
	for source in pairs(uniqueSources) do
		if not translatedBySource[source] then
			table.insert(apiQueue, source)
		end
	end
	total = #apiQueue

	for _, source in ipairs(apiQueue) do
		if not isActive() then
			return false, failCount
		end

		local ok, result = pcall(function()
			return Lang.translate(source, langCode)
		end)
		if ok and result and result ~= "" then
			local normalized = Lang.normalizeTranslation(result, langCode)
			if normalized then
				translatedBySource[source] = normalized
				Lang.cache[langCode][source] = normalized
			else
				failCount += 1
				translatedBySource[source] = source
			end
		else
			failCount += 1
			translatedBySource[source] = source
		end
		reportApiProgress()
		task.wait(0.04)
	end

	if not isActive() then
		return false, failCount
	end

	function resolveText(source)
		return translatedBySource[source] or source
	end

	for _, entry in ipairs(asArray(Lang.entries)) do
		entry.apply(resolveText(entry.source))
	end

	Lang.applyChrome(resolveText)

	if window then
		window:ChangeTitle(resolveText(CONFIG.Window.Title))
		window:SetFooter(resolveText(CONFIG.Window.SubTitle))
	end

	Lang.saveCache()
	Lang.current = langCode

	if not opts.silent then
		if failCount > 0 then
			Library:Notify({
				Title = "Language",
				Description = ("Translation finished with %d error(s)"):format(failCount),
				Time = 6,
			})
		else
			Library:Notify({
				Title = "Language",
				Description = "Language updated",
				Time = 3,
			})
		end
	end

	UiLayout.scheduleRefresh()
	return failCount == 0, failCount
end
Lang.loadCache()
