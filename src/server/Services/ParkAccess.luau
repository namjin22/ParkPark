--!strict

-- Who may change the park. With personal parks (one reserved server per owner) only the park's owner can unlock,
-- repair, upgrade, open zones, buy buildings, decor and staff; everyone else in that server is a visitor who rides,
-- earns coins at a reduced share, gathers, plays booths and so on. Where personal parks are not in use (Studio,
-- or a public server where the teleport failed) every player may manage, as before. Services ask `CanManage`
-- and tell a refused visitor with `Deny`.
local ParkAccess = {}

local personal = false
local owner: Player? = nil
local notifier: ((Player, string, string) -> ())? = nil
local lastDenied: { [Player]: number } = {}

function ParkAccess.Configure(isPersonal: boolean, send: (Player, string, string) -> ())
	personal = isPersonal
	notifier = send
end

function ParkAccess.SetOwner(player: Player?)
	owner = player
end

function ParkAccess.GetOwner(): Player?
	return owner
end

function ParkAccess.IsPersonal(): boolean
	return personal
end

function ParkAccess.CanManage(player: Player): boolean
	if not personal then
		return true
	end
	return owner ~= nil and player == owner
end

function ParkAccess.IsVisitor(player: Player): boolean
	return personal and (owner == nil or player ~= owner)
end

function ParkAccess.Deny(player: Player)
	local now = os.clock()
	if now - (lastDenied[player] or 0) < 3 then
		return
	end
	lastDenied[player] = now
	if notifier then
		local name = if owner then owner.DisplayName else "주인"
		notifier(
			player,
			"방문 중이에요",
			string.format("%s의 공원이라 관리는 주인만 할 수 있어요", name)
		)
	end
end

function ParkAccess.Forget(player: Player)
	lastDenied[player] = nil
end

return ParkAccess
