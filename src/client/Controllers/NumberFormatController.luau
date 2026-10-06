--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Puts thousands separators into every number of four or more digits that appears in the interface or on a
-- sign (20000 -> 20,000). Texts are set by many different scripts, so this watches the text properties on the
-- client instead of changing each call site; it only rewrites a text when it actually contains such a number.
local NumberFormatController = {}

local function group(run: string): string
	local lead = #run % 3
	local parts = {}
	if lead > 0 then
		table.insert(parts, string.sub(run, 1, lead))
	end
	for index = lead + 1, #run, 3 do
		table.insert(parts, string.sub(run, index, index + 2))
	end
	return table.concat(parts, ",")
end

local function format(text: string): string
	local result = string.gsub(text, "%d%d%d%d+", group)
	return result
end

local function watchText(instance: Instance, property: string)
	local function apply()
		local current = (instance :: any)[property] :: string
		local updated = format(current)
		if updated ~= current then
			(instance :: any)[property] = updated
		end
	end
	apply()
	instance:GetPropertyChangedSignal(property):Connect(apply)
end

local function watch(instance: Instance)
	if instance:IsA("TextLabel") or instance:IsA("TextButton") then
		watchText(instance, "Text")
	elseif instance:IsA("ProximityPrompt") then
		watchText(instance, "ObjectText")
		watchText(instance, "ActionText")
	end
end

function NumberFormatController.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, root in { playerGui :: Instance, Workspace :: Instance } do
		for _, descendant in root:GetDescendants() do
			watch(descendant)
		end
		root.DescendantAdded:Connect(watch)
	end
end

return NumberFormatController
