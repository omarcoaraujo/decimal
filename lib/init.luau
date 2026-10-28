--// Constants
local AMOUNT_DECIMALS = 2
local RATE_DECIMALS = 14
local PERCENT_DECIMALS = 12

local MAX_SAFE = 9007199254740991
local LIMB = 10000000
local HALF_RATE_SCALE = 50000000000000

--// Types
export type cents = number
export type rate = number

--// Functions
local function fail(message: string): never
	error(`decimal: {message}`, 0)
end

local function check_safe(value: number, label: string)
	if not (math.abs(value) <= MAX_SAFE) or value % 1 ~= 0 then
		fail(`{label} is not an exact integer inside ±{MAX_SAFE}`)
	end
end

local function check_exact(value: number)
	if value > MAX_SAFE then fail "result is too large to be computed exactly" end
end

local function with_sign(magnitude: number, negative: boolean)
	if negative and magnitude ~= 0 then return -magnitude end
	return magnitude
end

local function parse_scaled(text: string, decimals: number, label: string): number
	local sign, whole, dot, fraction = text:match "^([+-]?)(%d+)(%.?)(%d*)$"

	if not sign or not whole or not dot or not fraction then return fail(`invalid {label} "{text}"`) end
	if dot ~= "" and fraction == "" then return fail(`invalid {label} "{text}"`) end
	if #fraction > decimals then fail(`{label} "{text}" has more than {decimals} decimals`) end

	local magnitude = tonumber(whole .. fraction .. string.rep("0", decimals - #fraction)) :: number
	if magnitude > MAX_SAFE then fail(`{label} "{text}" is too large to be represented exactly`) end

	return with_sign(magnitude, sign == "-")
end

local function split_scaled(value: number, decimals: number)
	local digits = string.format("%.0f", math.abs(value))
	digits = string.rep("0", decimals + 1 - #digits) .. digits

	local sign = value < 0 and "-" or ""
	return sign .. digits:sub(1, #digits - decimals), digits:sub(#digits - decimals + 1)
end

local function multiply_exact(magnitude: number, factor: number)
	local magnitude_high, magnitude_low = magnitude // LIMB, magnitude % LIMB
	local factor_high, factor_low = factor // LIMB, factor % LIMB

	local cross_high = magnitude_high * factor_low
	local cross_low = magnitude_low * factor_high

	check_exact(cross_high)
	check_exact(cross_low)

	local high = magnitude_high * factor_high
	local middle = cross_high + cross_low
	local low = magnitude_low * factor_low

	check_exact(high)
	check_exact(middle)

	middle += low // LIMB
	check_exact(middle)

	high += middle // LIMB
	check_exact(high)

	return high, (middle % LIMB) * LIMB + low % LIMB
end

local function parse(text: string)
	return parse_scaled(text, AMOUNT_DECIMALS, "amount")
end

local function format(amount: cents)
	check_safe(amount, "amount")
	local whole, fraction = split_scaled(amount, AMOUNT_DECIMALS)
	return `{whole}.{fraction}`
end

local function parse_rate(text: string)
	return parse_scaled(text, RATE_DECIMALS, "rate")
end

local function parse_percent(text: string)
	return parse_scaled(text, PERCENT_DECIMALS, "percent")
end

local function format_rate(value: rate)
	check_safe(value, "rate")

	local whole, fraction = split_scaled(value, RATE_DECIMALS)
	local trimmed = fraction:gsub("0+$", "")

	trimmed ..= string.rep("0", AMOUNT_DECIMALS - #trimmed)
	return `{whole}.{trimmed}`
end

local function add(left: cents, right: cents)
	check_safe(left, "amount")
	check_safe(right, "amount")

	local total = left + right
	check_safe(total, "result")
	return total
end

local function subtract(left: cents, right: cents)
	check_safe(left, "amount")
	check_safe(right, "amount")

	local difference = left - right
	check_safe(difference, "result")
	return difference
end

local function compare(left: cents, right: cents)
	check_safe(left, "amount")
	check_safe(right, "amount")

	if left < right then return -1 end
	if left > right then return 1 end

	return 0
end

local function sum(amounts: { cents }): cents
	local total = 0

	for _, amount in amounts do
		total = add(total, amount)
	end

	return total
end

local function multiply(amount: cents, value: rate)
	check_safe(amount, "amount")
	check_safe(value, "rate")

	local magnitude, remainder = multiply_exact(math.abs(amount), math.abs(value))
	if remainder >= HALF_RATE_SCALE then
		magnitude += 1
	end

	check_exact(magnitude)
	return with_sign(magnitude, (amount < 0) ~= (value < 0))
end

local function percentage(amount: cents, percent: rate)
	return multiply(amount, percent)
end

--// End
return table.freeze {
	parse = parse,
	format = format,

	parse_rate = parse_rate,
	parse_percent = parse_percent,

	format_rate = format_rate,
	add = add,

	subtract = subtract,
	compare = compare,

	sum = sum,
	multiply = multiply,
	percentage = percentage,
}
