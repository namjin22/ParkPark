--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config")
local Strings = require(Config:WaitForChild("Strings"))

-- English interface for players whose Roblox language is not Korean. Texts are written in Korean all over the
-- code (and arrive from the server already composed), so, like the number formatter, this watches the text
-- properties on the client and swaps a Korean text for its English entry in Strings (exact match, then a pattern
-- match for composed texts, then line by line and segment by segment). Anything without an entry stays Korean.
-- In Studio, setting the local player's attribute `DebugLocale` (for example "en-us") previews it.
local LocalizeController = {}

type Rule = { pattern: string, english: string, weight: number }

local exact: { [string]: string } = {}
local rules: { Rule } = {}

local MAGIC = "[%^%$%(%)%.%[%]%*%+%-%?]"

local function compile(korean: string, english: string)
	if not string.find(korean, "%%[ds]") and not string.find(korean, "%%%.1f") then
		exact[korean] = english
		return
	end
	local pattern = "^"
	local literal = 0
	local index = 1
	local length = #korean
	while index <= length do
		local two = string.sub(korean, index, index + 1)
		local four = string.sub(korean, index, index + 3)
		if four == "%.1f" then
			pattern ..= "(-?[%d,%.]+)"
			index += 4
		elseif two == "%d" then
			pattern ..= "(-?[%d,]+)"
			index += 2
		elseif two == "%s" then
			pattern ..= "(.-)"
			index += 2
		elseif two == "%%" then
			pattern ..= "%%"
			literal += 1
			index += 2
		else
			local char = string.sub(korean, index, index)
			if string.find(char, MAGIC) then
				pattern ..= "%" .. char
			else
				pattern ..= char
			end
			literal += 1
			index += 1
		end
	end
	table.insert(rules, { pattern = pattern .. "$", english = english, weight = literal })
end

for _, entry in Strings.Entries do
	compile(entry[1], entry[2])
end
-- More specific patterns (more literal characters) first.
table.sort(rules, function(a: Rule, b: Rule)
	return a.weight > b.weight
end)

local function hasKorean(text: string): boolean
	local ok, found = pcall(function()
		for _, codepoint in utf8.codes(text) do
			if (codepoint >= 0xAC00 and codepoint <= 0xD7A3) or (codepoint >= 0x1100 and codepoint <= 0x11FF) then
				return true
			end
		end
		return false
	end)
	return ok and found == true
end

local translate: (string, number) -> string

local function substitute(english: string, captures: { string }, depth: number): string
	local result = string.gsub(english, "{(%d+)}", function(number: string)
		local value = captures[tonumber(number) :: number]
		if value == nil then
			return ""
		end
		return translate(value, depth + 1)
	end)
	return result
end

translate = function(text: string, depth: number): string
	if depth > 4 or not hasKorean(text) then
		return text
	end
	local hit = exact[text]
	if hit then
		return hit
	end
	for _, rule in rules do
		local captures = { string.match(text, rule.pattern) }
		if #captures > 0 then
			return substitute(rule.english, captures, depth)
		end
	end
	if string.find(text, "\n", 1, true) then
		local parts = string.split(text, "\n")
		for index, part in parts do
			parts[index] = translate(part, depth + 1)
		end
		return table.concat(parts, "\n")
	end
	if string.find(text, " · ", 1, true) then
		local parts = string.split(text, " · ")
		for index, part in parts do
			parts[index] = translate(part, depth + 1)
		end
		return table.concat(parts, " · ")
	end
	return text
end

function LocalizeController.Translate(text: string): string
	return translate(text, 0)
end

local function isKorean(player: Player): boolean
	local locale = player.LocaleId
	if RunService:IsStudio() then
		local override = player:GetAttribute("DebugLocale")
		if type(override) == "string" and override ~= "" then
			locale = override
		end
	end
	return string.sub(string.lower(locale), 1, 2) == "ko"
end

function LocalizeController.Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local watched: { [Instance]: { string } } = {}

	local function apply(instance: Instance, property: string)
		if isKorean(player) then
			return
		end
		local ok, current = pcall(function()
			return (instance :: any)[property] :: string
		end)
		if not ok or type(current) ~= "string" then
			return
		end
		local updated = translate(current, 0)
		if updated ~= current then
			(instance :: any)[property] = updated
		end
	end

	local function watchText(instance: Instance, property: string)
		apply(instance, property)
		instance:GetPropertyChangedSignal(property):Connect(function()
			apply(instance, property)
		end)
		local list = watched[instance] or {}
		table.insert(list, property)
		watched[instance] = list
	end

	local function watch(instance: Instance)
		if instance:IsA("TextLabel") or instance:IsA("TextButton") then
			watchText(instance, "Text")
		elseif instance:IsA("ProximityPrompt") then
			watchText(instance, "ObjectText")
			watchText(instance, "ActionText")
		end
	end

	for _, root in { playerGui :: Instance, Workspace :: Instance } do
		for _, descendant in root:GetDescendants() do
			watch(descendant)
		end
		root.DescendantAdded:Connect(watch)
	end

	player:GetAttributeChangedSignal("DebugLocale"):Connect(function()
		for instance, properties in watched do
			for _, property in properties do
				apply(instance, property)
			end
		end
	end)
end

return LocalizeController
