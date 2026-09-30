--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig =
	require(ReplicatedStorage:WaitForChild("ParkRebornShared"):WaitForChild("Config"):WaitForChild("GameConfig"))

-- The park's star rating. It is server-owned state on the park folder (`Rating`, `RatingScore`) that the HUD
-- shows, that gates the bumper cars and the Ferris wheel, and that raises how many guests visit.
local RatingService = {}

type RatingReferences = {
	ParkFolder: Folder,
	Carousel: Model,
	TeacupsRide: Model,
	BumperRide: Model,
	SnackStand: Model,
	FerrisRide: Model,
}

type Notify = (Player, string, string) -> ()

local UPDATE_SECONDS = 2

-- Attractions unlocked by a given star, for the congratulation text.
local UNLOCKED_AT_STAR: { [number]: string } = {}
for _, key in { "Bumper", "Ferris" } do
	local config = GameConfig.Rides[key]
	local stars = config.RequiredStars or 1
	local existing = UNLOCKED_AT_STAR[stars]
	UNLOCKED_AT_STAR[stars] = if existing then existing .. ", " .. config.DisplayName else config.DisplayName
end

function RatingService.Start(park: RatingReferences, notify: Notify)
	local attractions = { park.Carousel, park.TeacupsRide, park.BumperRide, park.SnackStand, park.FerrisRide }
	local litterFolder = park.ParkFolder:FindFirstChild("Litter")

	local function computeScore(): number
		local score = 0
		for _, attraction in attractions do
			if attraction:GetAttribute("IsRepaired") == true then
				score += 1
			end
		end

		local litter = if litterFolder then #litterFolder:GetChildren() else 0
		if litter <= GameConfig.RatingCleanLitter then
			score += 1
		elseif litter >= GameConfig.RatingDirtyLitter then
			score -= 1
		end

		local served = (park.ParkFolder:GetAttribute("GuestsBoarded") :: number?) or 0
		for _, milestone in GameConfig.RatingGuestMilestones do
			if served >= milestone then
				score += 1
			end
		end
		return score
	end

	local function starsFor(score: number): number
		local stars = 1
		for star, needed in GameConfig.RatingScoreForStar do
			if score >= needed then
				stars = star
			end
		end
		return stars
	end

	park.ParkFolder:SetAttribute("Rating", 1)
	park.ParkFolder:SetAttribute("RatingScore", 0)

	task.spawn(function()
		while park.ParkFolder.Parent ~= nil do
			local score = computeScore()
			local stars = starsFor(score)
			local previous = (park.ParkFolder:GetAttribute("Rating") :: number?) or 1
			park.ParkFolder:SetAttribute("RatingScore", score)
			if stars ~= previous then
				park.ParkFolder:SetAttribute("Rating", stars)
				if stars > previous then
					local unlocked = UNLOCKED_AT_STAR[stars]
					local detail = if unlocked
						then string.format("%s 해금 조건을 채웠어요", unlocked)
						else "손님이 더 많이, 더 빨리 찾아와요"
					for _, player in Players:GetPlayers() do
						notify(player, string.format("별점 %d단계!", stars), detail)
					end
				end
			end
			task.wait(UPDATE_SECONDS)
		end
	end)
end

return RatingService
