--!strict
-- Token-Bucket Rate-Limiter pro (Player, Key).
-- Verwende: if not RateLimit.consume(player, "BuyPack", 5, 1) then return end

local Players = game:GetService("Players")

local RateLimit = {}

type Bucket = { tokens: number, last: number, capacity: number, refillPerSec: number }
local buckets: { [Player]: { [string]: Bucket } } = {}

function RateLimit.consume(player: Player, key: string, capacity: number, refillPerSec: number): boolean
	local byKey = buckets[player]
	if not byKey then
		byKey = {}
		buckets[player] = byKey
	end
	local bucket = byKey[key]
	local now = os.clock()
	if not bucket then
		bucket = { tokens = capacity, last = now, capacity = capacity, refillPerSec = refillPerSec }
		byKey[key] = bucket
	end
	local delta = now - bucket.last
	bucket.last = now
	bucket.tokens = math.min(bucket.capacity, bucket.tokens + delta * bucket.refillPerSec)
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

return RateLimit
