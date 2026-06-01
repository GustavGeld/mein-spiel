--!strict
-- Locale-Service. Client & Server safe. Client subscribed sich auf LanguageChanged.

local Signal = require(script.Parent.Parent.utils.Signal)

local Tables: { [string]: { [string]: string } } = {
	en = require(script.Parent.en),
	de = require(script.Parent.de),
}

local Locale = {}
Locale.LanguageChanged = Signal.new() -- fires (newLang: string)
Locale.current = "en"

function Locale.setLanguage(lang: string)
	if not Tables[lang] then
		warn("[Locale] Unknown language: " .. lang)
		return
	end
	if Locale.current == lang then return end
	Locale.current = lang
	Locale.LanguageChanged:Fire(lang)
end

function Locale.t(key: string, ...: any): string
	local tbl = Tables[Locale.current] or Tables.en
	local raw = tbl[key] or Tables.en[key]
	if not raw then
		return "[" .. key .. "]"
	end
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, raw, ...)
		if ok then return formatted end
	end
	return raw
end

function Locale.has(key: string): boolean
	return (Tables[Locale.current] and Tables[Locale.current][key] ~= nil)
		or (Tables.en[key] ~= nil)
end

function Locale.languages(): { string }
	local out = {}
	for k in pairs(Tables) do table.insert(out, k) end
	table.sort(out)
	return out
end

return Locale
