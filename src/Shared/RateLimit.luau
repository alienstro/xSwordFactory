--!strict
-- A token bucket that limits how fast a player can send requests.

export type Bucket = { rate: number, burst: number, tokens: number, last: number? }

local RateLimit = {}

function RateLimit.new(rate: number, burst: number): Bucket
	return { rate = rate, burst = burst, tokens = burst, last = nil }
end

-- Returns true if the request can go on. `now` is a time in seconds.
function RateLimit.allow(bucket: Bucket, now: number): boolean
	if bucket.last then
		local refill = (now - bucket.last) * bucket.rate
		bucket.tokens = math.min(bucket.burst, bucket.tokens + refill)
	end
	bucket.last = now
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

return RateLimit
