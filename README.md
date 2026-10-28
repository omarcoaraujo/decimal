# decimal

[Luau](https://luau.org) has no decimal type, so amounts are integer cents and exchange rates are integers with a fixed scale. Pure functions: no runtime APIs, so it runs on Lute, Lune and Zune.

## Installation

Add decimal to your `pesde.toml`:

```toml
[dependencies]
decimal = { name = "omarcoaraujo/decimal", version = "^0.1.0" }
```

Then require it:

```luau
local decimal = require("@pkg/decimal")
```

## Usage

```luau
local usd = decimal.parse("250.00")
local rate = decimal.parse_rate("5.19772")

local brl = decimal.multiply(usd, rate)
print(decimal.format(brl))

local balance = decimal.subtract(decimal.parse("1442.69"), decimal.parse("1250.00"))
print(decimal.format(balance))

local fee = decimal.percentage(brl, decimal.parse_percent("2.5"))
local total = decimal.sum({ brl, fee, balance })
```

| Function | Returns |
|---|---|
| `parse(text)` | cents from `"123.45"`; up to 2 decimals, optional sign |
| `format(cents)` | `"123.45"`, `"-0.05"` |
| `parse_rate(text)` | rate from `"5.1859338271045"`; up to 14 decimals |
| `format_rate(rate)` | the rate text without trailing zeros, at least 2 decimals |
| `parse_percent(text)` | a rate from `"12.5"` meaning 12.5%; up to 12 decimals |
| `add(a, b)` / `subtract(a, b)` | cents |
| `compare(a, b)` | `-1`, `0` or `1` |
| `sum(list)` | cents; `0` for an empty list |
| `multiply(cents, rate)` | cents, rounded |
| `percentage(cents, percent)` | cents, rounded; `percent` comes from `parse_percent` |

Cents, rates and percents are plain numbers holding integers. Never build them by hand from a float: go through `parse`, `parse_rate` and `parse_percent`.

## Rounding

One rule, **half up**: a result exactly halfway between two cents goes to the larger magnitude. Negative results mirror positive ones (`-0.5` cents becomes `-1`, not `0`).

```
250.00  x 5.19772     = 1299.43      (exactly 1299.43)
150.00  x 5.11286915  =  766.9303725 -> 766.93   (below half, rounds down)
0.05    x 0.5         =    0.025     -> 0.03     (exactly half, rounds up)
-0.05   x 0.5         =   -0.025     -> -0.03    (mirrors the positive case)
```

Rounding happens once, on the final cent. Nothing is rounded between steps.

## Precision and limits

Luau numbers are doubles, exact for integers up to 2^53 (9,007,199,254,740,991).

- **Amounts** are cents, so any amount up to about 90 trillion in currency units is exact. R$ 1,000,000.00 is 100,000,000 cents.
- **Rates** are scaled by 10^14, so the largest rate is `90.07199254740991`. A rate such as `5.1859338271045` is stored as `518593382710450`. Rates with more than 14 decimals are rejected, never rounded.
- **Percents** are scaled by 10^12 (the same integer as a rate divided by 100), so the largest percent is `9007.199254740991`.
- **Multiplication** does not multiply the two integers directly, which would need about 10^23 for R$ 1,000,000 at a 14-decimal rate. It splits both numbers into 7-digit limbs and carries between them, so every step stays an exact integer and the product is exact. A product that cannot be computed exactly raises an error.

The library never loses precision silently. Every input outside the limits above raises an error with a plain message: malformed text, too many decimals, a number past 2^53, a fractional or `NaN` cents value, or a sum that overflows.

## Development

```sh
pesde install
lute run tests
stylua --config-path stylua.toml --check lib tests
luau-lsp analyze --platform=standard lib tests
```

## License

MIT
