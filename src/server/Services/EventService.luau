--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- Now and then something lively happens in the park: a festival (every fare is higher) or a crowd of visitors
-- (more guests arrive). While one runs, the park folder carries `FareMultiplier` / `CrowdMultiplier` for
-- GuestService, plus `EventName` and `EventEnds` (os.time) for anyone who wants to show it.
local EventService = {}

type Notify = (Player, string, string) -> ()

local EVENTS = {
	{ Name = "축제", Detail = "모든 놀이기구 요금이 1.5배!", Fare = 1.5, Crowd = 1 },
	{ Name = "방문객 몰려옴", Detail = "손님이 평소보다 많이 찾아와요", Fare = 1, Crowd = 1.6 },
	{ Name = "대축제", Detail = "요금 1.3배에 손님도 북적여요", Fare = 1.3, Crowd = 1.3 },
}

function EventService.Start(park: { ParkFolder: Folder }, notify: Notify)
	local folder = park.ParkFolder
	folder:SetAttribute("FareMultiplier", 1)
	folder:SetAttribute("CrowdMultiplier", 1)
	local random = Random.new()

	local function broadcast(title: string, detail: string)
		for _, player in Players:GetPlayers() do
			notify(player, title, detail)
		end
	end

	task.spawn(function()
		while folder.Parent ~= nil do
			-- Set `ForceEvent` on the park folder to start one right away (for testing).
			local waited = 0
			local target = random:NextNumber(GameConfig.EventMinSeconds, GameConfig.EventMaxSeconds)
			while waited < target and folder:GetAttribute("ForceEvent") ~= true do
				waited += task.wait(1)
			end
			local forced = folder:GetAttribute("ForceEvent") == true
			folder:SetAttribute("ForceEvent", nil)
			-- Only a park that is open and has a few rides running gets events.
			local operating = 0
			for _, child in folder:GetChildren() do
				if child:IsA("Model") and child:GetAttribute("IsOperating") == true then
					operating += 1
				end
			end
			if folder:GetAttribute("ParkOpen") == true and (forced or operating >= GameConfig.EventMinRides) then
				local event = EVENTS[random:NextInteger(1, #EVENTS)]
				folder:SetAttribute("FareMultiplier", event.Fare)
				folder:SetAttribute("CrowdMultiplier", event.Crowd)
				folder:SetAttribute("EventName", event.Name)
				folder:SetAttribute("EventEnds", os.time() + GameConfig.EventSeconds)
				broadcast(event.Name .. " 시작!", event.Detail)
				task.wait(GameConfig.EventSeconds)
				folder:SetAttribute("FareMultiplier", 1)
				folder:SetAttribute("CrowdMultiplier", 1)
				folder:SetAttribute("EventName", nil)
				folder:SetAttribute("EventEnds", nil)
				broadcast(event.Name .. " 끝", "다음 행사를 기다려요")
			end
		end
	end)
end

return EventService
