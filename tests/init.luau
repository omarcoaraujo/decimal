local decimal = require "@lib"
local tint = require "@pkg/tint"
local spec = {} :: { [string]: any }

local function fails(callback: () -> any, expected: string)
	local success, message = pcall(callback)
	assert(not success, `expected an error containing "{expected}"`)
	assert(string.find(tostring(message), expected, 1, true), `wrong error: {message}`)
end

local function converted(amount: string, rate: string): string
	return decimal.format(decimal.multiply(decimal.parse(amount), decimal.parse_rate(rate)))
end

local function percent_of(amount: string, percent: string): string
	return decimal.format(decimal.percentage(decimal.parse(amount), decimal.parse_percent(percent)))
end

-- parse
function spec.should_parse_amount_with_cents()
	assert(decimal.parse "123.45" == 12345)
end

function spec.should_parse_whole_amount()
	assert(decimal.parse "123" == 12300)
end

function spec.should_parse_single_decimal()
	assert(decimal.parse "0.5" == 50)
end

function spec.should_parse_negative_amount()
	assert(decimal.parse "-12.30" == -1230)
end

function spec.should_parse_explicit_plus_sign()
	assert(decimal.parse "+1.00" == 100)
end

function spec.should_parse_negative_zero_as_zero()
	assert(1 / decimal.parse "-0.00" == math.huge)
end

function spec.should_reject_more_than_two_decimals()
	fails(function()
		return decimal.parse "1.234"
	end, "more than 2 decimals")
end

function spec.should_reject_malformed_amounts()
	for _, text in { "", ".5", "5.", "1,50", "abc", "1.2.3", "--1", " 1.00", "1e3" } do
		fails(function()
			return decimal.parse(text)
		end, "invalid amount")
	end
end

function spec.should_reject_amount_beyond_exact_range()
	fails(function()
		return decimal.parse "90071992547409.92"
	end, "too large")
end

function spec.should_parse_largest_exact_amount()
	assert(decimal.parse "90071992547409.91" == 9007199254740991)
end

-- format
function spec.should_format_cents()
	assert(decimal.format(12345) == "123.45")
end

function spec.should_format_amounts_below_one()
	assert(decimal.format(5) == "0.05")
	assert(decimal.format(50) == "0.50")
	assert(decimal.format(0) == "0.00")
end

function spec.should_format_negative_amount()
	assert(decimal.format(-5) == "-0.05")
	assert(decimal.format(-12345) == "-123.45")
end

function spec.should_format_amount_above_fourteen_digits()
	assert(decimal.format(9007199254740991) == "90071992547409.91")
end

function spec.should_round_trip_parse_and_format()
	for _, text in { "0.00", "0.01", "1442.69", "-1250.00", "999999.99", "1000000.00" } do
		assert(decimal.format(decimal.parse(text)) == text)
	end
end

function spec.should_reject_fractional_cents_when_formatting()
	fails(function()
		return decimal.format(1.5)
	end, "not an exact integer")
end

function spec.should_reject_unsafe_cents_when_formatting()
	fails(function()
		return decimal.format(2 ^ 53)
	end, "not an exact integer")
end

function spec.should_reject_nan()
	fails(function()
		return decimal.format(0 / 0)
	end, "not an exact integer")
end

-- rates
function spec.should_parse_rate_with_fourteen_decimals()
	assert(decimal.parse_rate "5.12345678901234" == 512345678901234)
end

function spec.should_parse_rate_with_thirteen_decimals()
	assert(decimal.parse_rate "5.1859338271045" == 518593382710450)
end

function spec.should_parse_whole_rate()
	assert(decimal.parse_rate "5" == 500000000000000)
end

function spec.should_reject_rate_with_fifteen_decimals()
	fails(function()
		return decimal.parse_rate "5.123456789012345"
	end, "more than 14 decimals")
end

function spec.should_parse_largest_rate()
	assert(decimal.parse_rate "90.07199254740991" == 9007199254740991)
end

function spec.should_reject_rate_beyond_exact_range()
	fails(function()
		return decimal.parse_rate "90.07199254740992"
	end, "too large")
end

function spec.should_reject_malformed_rate()
	fails(function()
		return decimal.parse_rate "5,19"
	end, "invalid rate")
end

function spec.should_format_rate_without_trailing_zeros()
	assert(decimal.format_rate(decimal.parse_rate "5.1859338271045") == "5.1859338271045")
	assert(decimal.format_rate(decimal.parse_rate "5.19772") == "5.19772")
end

function spec.should_format_rate_with_at_least_two_decimals()
	assert(decimal.format_rate(decimal.parse_rate "5") == "5.00")
	assert(decimal.format_rate(decimal.parse_rate "5.1") == "5.10")
end

-- add, subtract, compare, sum
function spec.should_subtract_amounts()
	assert(decimal.format(decimal.subtract(decimal.parse "1442.69", decimal.parse "1250.00")) == "192.69")
end

function spec.should_subtract_into_negative()
	assert(decimal.format(decimal.subtract(decimal.parse "10.00", decimal.parse "10.01")) == "-0.01")
end

function spec.should_add_amounts()
	assert(decimal.format(decimal.add(decimal.parse "0.10", decimal.parse "0.20")) == "0.30")
end

function spec.should_not_drift_like_floating_point()
	local total = 0

	for _ = 1, 10 do
		total = decimal.add(total, decimal.parse "0.10")
	end

	assert(decimal.format(total) == "1.00")
end

function spec.should_reject_add_beyond_exact_range()
	fails(function()
		return decimal.add(9007199254740991, 1)
	end, "result")
end

function spec.should_reject_subtract_beyond_exact_range()
	fails(function()
		return decimal.subtract(-9007199254740991, 1)
	end, "result")
end

function spec.should_compare_amounts()
	assert(decimal.compare(decimal.parse "1.00", decimal.parse "2.00") == -1)
	assert(decimal.compare(decimal.parse "2.00", decimal.parse "1.00") == 1)
	assert(decimal.compare(decimal.parse "2.00", decimal.parse "2.0") == 0)
end

function spec.should_sum_list()
	local amounts = { decimal.parse "1442.69", decimal.parse "-1250.00", decimal.parse "0.31" }
	assert(decimal.format(decimal.sum(amounts)) == "193.00")
end

function spec.should_sum_empty_list_as_zero()
	assert(decimal.sum {} == 0)
end

-- multiply
function spec.should_convert_250_usd_at_5_19772()
	assert(converted("250.00", "5.19772") == "1299.43")
end

function spec.should_round_down_below_half()
	assert(converted("150.00", "5.11286915") == "766.93")
end

function spec.should_convert_1000_usd_at_5()
	assert(converted("1000.00", "5.00") == "5000.00")
end

function spec.should_round_half_up()
	assert(converted("0.05", "0.5") == "0.03")
	assert(converted("0.07", "0.5") == "0.04")
	assert(converted("0.01", "0.5") == "0.01")
end

function spec.should_round_half_away_from_zero_for_negatives()
	assert(converted("-0.05", "0.5") == "-0.03")
	assert(converted("0.05", "-0.5") == "-0.03")
	assert(converted("-0.05", "-0.5") == "0.03")
end

function spec.should_not_return_negative_zero()
	local result = decimal.multiply(-1, decimal.parse_rate "0.1")
	assert(result == 0 and 1 / result == math.huge)
end

function spec.should_round_at_the_fourteenth_decimal()
	assert(decimal.multiply(3, decimal.parse_rate "0.16666666666667") == 1)
	assert(decimal.multiply(3, decimal.parse_rate "0.16666666666666") == 0)

	assert(decimal.multiply(1, decimal.parse_rate "0.5") == 1)
	assert(decimal.multiply(1, decimal.parse_rate "0.49999999999999") == 0)
end

function spec.should_convert_one_million_with_fourteen_decimal_rate_exactly()
	assert(converted("1000000.00", "5.1859338271045") == "5185933.83")
	assert(converted("1000000.00", "5.12345678901234") == "5123456.79")
	assert(converted("999999.99", "5.1859338271045") == "5185933.78")
end

function spec.should_keep_exact_digits_beyond_double_precision()
	assert(converted("1000000.00", "5.00000000000001") == "5000000.00")
	assert(decimal.multiply(99999999999999, decimal.parse_rate "1.00000000000001") == 100000000000000)
end

function spec.should_multiply_by_one_and_zero()
	assert(converted("123.45", "1") == "123.45")
	assert(converted("123.45", "0") == "0.00")
	assert(converted("0.00", "5.19772") == "0.00")
end

function spec.should_reject_multiply_beyond_exact_range()
	fails(function()
		return decimal.multiply(9007199254740991, decimal.parse_rate "5")
	end, "too large")
end

-- percentage
function spec.should_take_percentage()
	assert(percent_of("1000.00", "10") == "100.00")
	assert(percent_of("250.00", "12.5") == "31.25")
	assert(percent_of("200.00", "100") == "200.00")
end

function spec.should_reject_percent_with_thirteen_decimals()
	fails(function()
		return decimal.parse_percent "1.0000000000001"
	end, "more than 12 decimals")
end

function spec.should_reject_percent_beyond_exact_range()
	assert(decimal.parse_percent "9007.199254740991" == 9007199254740991)
	fails(function()
		return decimal.parse_percent "9007.199254740992"
	end, "too large")
end

function spec.should_round_percentage_half_up()
	assert(percent_of("0.05", "10") == "0.01")
	assert(percent_of("19.99", "15") == "3.00")
	assert(percent_of("0.04", "10") == "0.00")
end

function spec.should_round_percentage_half_away_from_zero_for_negatives()
	assert(percent_of("-0.05", "10") == "-0.01")
	assert(percent_of("19.99", "-15") == "-3.00")
end

function spec.should_take_percentage_of_one_million()
	assert(percent_of("1000000.00", "0.5") == "5000.00")
	assert(percent_of("1000000.00", "33.333333333333") == "333333.33")
end

local function is_test(name: string, value: any)
	return typeof(value) == "function" and name:sub(1, 7) == "should_"
end

local function get_sorted_keys()
	local keys = {}

	for key, value in spec do
		if is_test(key, value) then table.insert(keys, key) end
	end

	table.sort(keys)
	return keys
end

local total = 0
local failed = 0

for _, name in get_sorted_keys() do
	total += 1

	local success, error_message = pcall(spec[name])
	if success then continue end

	failed += 1
	print(`  {tint.red.bold "✗"} {tint.dim(name)} {tint.red(error_message)}`)
end

if failed > 0 then error(`\n{tint.red.bold(`✗ {failed}/{total} tests failed!`)}`) end
print(`{tint.green.bold(`✓ {total}/{total}`)} all tests passed! \n`)
