--!strict

-- Generated positional rows contain numbers and a class string. Keep their
-- large literal type out of consumers; this module supplies the typed boundary.
local Data: any = require(script.Parent.LineBreakData)
local Properties = {}

function Properties.get(codepoint: number): (string, number)
	assert(codepoint >= 0 and codepoint <= 0x10FFFF and codepoint % 1 == 0, "Expected a Unicode code point")
	local low, high = 1, #Data.ranges
	while low <= high do
		local middle = math.floor((low + high) / 2)
		local row = Data.ranges[middle]
		if codepoint < row[1] then
			high = middle - 1
		elseif codepoint > row[2] then
			low = middle + 1
		else
			return row[3], row[4]
		end
	end
	error("Unicode property table has an uncovered code point")
end

Properties.version = Data.version
return Properties
