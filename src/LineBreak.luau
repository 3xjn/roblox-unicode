--!strict

-- Adapted from @cto.af/linebreak 4.0.3, commit 088ff02569c5f213951e819a0578f164455f1075.
-- See LICENSE.upstream. Rule numbers refer to Unicode 17 UAX #14.
-- Combining sequences are grouped before boundary evaluation (LB9/10).
-- Physical trailing ZWJ is retained independently for the earlier LB8a rule.
local Properties = require(script.Parent.Properties)

export type Break = { position: number, required: boolean }
type Character = { cls: string, cp: number, tail: number, flags: number, first: number, last: number }
type State = {
	chars: { Character },
	spaces: boolean,
	zeroWidth: boolean,
	regional: number,
	work: number,
	failure: string?,
}
local start: Character = { cls = "sot", cp = -1, tail = -1, flags = 0, first = 0, last = 0 }
local finish: Character = { cls = "eot", cp = -1, tail = -1, flags = 0, first = 0, last = 0 }

local function set(names: string): { [string]: boolean }
	local result = {}
	for name in names:gmatch("%S+") do
		result[name] = true
	end
	return result
end
local hard = set("BK CR LF NL")
local notBase = set("BK CR LF NL SP ZW")
local spaceExceptions = set("ZW OP QU CL CP B2")
local quoteBefore = set("sot BK CR LF NL OP QU GL SP ZW")
local quoteAfter = set("SP GL WJ CL QU CP EX IS SY BK CR LF NL ZW eot")
local wordInitial = set("sot BK CR LF NL SP ZW CB GL")
local alpha = set("AL HL")
local alphaNumber = set("AL HL NU")
local ideograph = set("ID EB EM")
local hangul = set("JL JV JT H2 H3")
local prefixes = set("PR PO")

local function flag(char: Character, mask: number): boolean
	return bit32.band(char.flags, mask) ~= 0
end
local function character(state: State, index: number): Character
	return if index < 1 then start elseif index > #state.chars then finish else state.chars[index]
end
local function spend(state: State): boolean
	state.work += 1
	if state.work > 1000000 then
		state.failure = "unicode-line-break-work-budget-exceeded"
		return false
	end
	return true
end
local function afterSpaces(state: State, index: number): string
	while index <= #state.chars do
		if not spend(state) then
			return "eot"
		end
		local cls = state.chars[index].cls
		if cls ~= "SP" then
			return cls
		end
		index += 1
	end
	return "eot"
end
local function brahmic(char: Character): boolean
	return char.cls == "AK" or char.cls == "AS" or char.cp == 0x25CC
end

local function boundary(state: State, index: number): (boolean, boolean)
	local a, b, prev = character(state, index), character(state, index + 1), character(state, index - 1)
	local ac, bc = a.cls, b.cls
	-- LB2/3: the empty string has one required end boundary at byte zero.
	if bc == "eot" then
		return true, true
	end
	if ac == "sot" then
		return false, false
	end
	-- LB4/5/6.
	if ac == "BK" then
		return true, true
	end
	if ac == "CR" then
		return bc ~= "LF", bc ~= "LF"
	end
	if ac == "LF" or ac == "NL" then
		return true, true
	end
	if hard[bc] then
		return false, false
	end
	if ac ~= "RI" then
		state.regional = 0
	end
	if state.spaces then
		if bc ~= "SP" then
			state.spaces = false
		end
		return false, false
	end
	-- LB7/8/8a. LB9/10 were applied while grouping input, but not to tail.
	if bc == "ZW" or (bc == "SP" and not spaceExceptions[ac]) then
		return false, false
	end
	if state.zeroWidth then
		state.zeroWidth = false
		return true, false
	end
	if ac == "ZW" then
		if bc == "SP" then
			state.zeroWidth = true
			return false, false
		end
		return true, false
	end
	if a.tail == 0x200D then
		return false, false
	end
	-- LB11/12/12a/13.
	if ac == "WJ" or bc == "WJ" or ac == "GL" then
		return false, false
	end
	if bc == "GL" and ac ~= "SP" and ac ~= "BA" and ac ~= "HY" and ac ~= "HH" then
		return false, false
	end
	if bc == "CL" or bc == "CP" or bc == "EX" or bc == "SY" then
		return false, false
	end
	-- LB14/15a: only carry the space-run state when spaces actually follow.
	if ac == "OP" then
		state.spaces = bc == "SP"
		return false, false
	end
	if quoteBefore[prev.cls] and ac == "QU" and flag(a, 4) then
		state.spaces = bc == "SP"
		return false, false
	end
	local after = character(state, index + 2)
	-- LB15b/c/d.
	if bc == "QU" and flag(b, 8) and quoteAfter[after.cls] then
		return false, false
	end
	if ac == "SP" and bc == "IS" and after.cls == "NU" then
		return true, false
	end
	if bc == "IS" then
		return false, false
	end
	-- LB16/17.
	if ac == "CL" or ac == "CP" then
		if afterSpaces(state, index + 1) == "NS" then
			state.spaces = bc == "SP"
			return false, false
		end
		if bc == "SP" then
			return false, false
		end
	end
	if ac == "B2" then
		if afterSpaces(state, index + 1) == "B2" then
			state.spaces = bc == "SP"
			return false, false
		end
		if bc == "SP" then
			return false, false
		end
	end
	-- LB18/19/19a/20.
	if ac == "SP" then
		return true, false
	end
	if (bc == "QU" and not flag(b, 4)) or (ac == "QU" and not flag(a, 8)) then
		return false, false
	end
	if bc == "QU" and (not flag(a, 1) or after.cls == "eot" or not flag(after, 1)) then
		return false, false
	end
	if ac == "QU" and (not flag(b, 1) or prev.cls == "sot" or not flag(prev, 1)) then
		return false, false
	end
	if ac == "CB" or bc == "CB" then
		return true, false
	end
	-- LB20a/21a/21/21b/22.
	if wordInitial[prev.cls] and (ac == "HY" or ac == "HH") and alpha[bc] then
		return false, false
	end
	if prev.cls == "HL" and (ac == "HY" or ac == "HH") and bc ~= "HL" then
		return false, false
	end
	if ac == "BB" or bc == "BA" or bc == "HH" or bc == "HY" or bc == "NS" then
		return false, false
	end
	if ac == "SY" and bc == "HL" then
		return false, false
	end
	if bc == "IN" then
		return false, false
	end
	-- LB23/23a/24.
	if (alpha[ac] and bc == "NU") or (ac == "NU" and alpha[bc]) then
		return false, false
	end
	if (ac == "PR" and ideograph[bc]) or (bc == "PO" and ideograph[ac]) then
		return false, false
	end
	if (prefixes[ac] and alpha[bc]) or (alpha[ac] and prefixes[bc]) then
		return false, false
	end
	-- LB25. Scan resolved groups, so ignored combining marks cannot interrupt a number.
	local numeric: number? = nil
	if prefixes[bc] then
		numeric = if ac == "CL" or ac == "CP" then index - 1 else index
	elseif bc == "NU" then
		numeric = index
	end
	if numeric then
		for cursor = numeric, 1, -1 do
			if not spend(state) then
				return false, false
			end
			local cls = state.chars[cursor].cls
			if cls == "NU" then
				return false, false
			end
			if cls ~= "SY" and cls ~= "IS" then
				break
			end
		end
	end
	if prefixes[ac] then
		if bc == "NU" then
			return false, false
		end
		if bc == "OP" and (after.cls == "NU" or (after.cls == "IS" and character(state, index + 3).cls == "NU")) then
			return false, false
		end
	end
	if (ac == "HY" or ac == "IS") and bc == "NU" then
		return false, false
	end
	-- LB26/27.
	if ac == "JL" and (bc == "JL" or bc == "JV" or bc == "H2" or bc == "H3") then
		return false, false
	end
	if (ac == "JV" or ac == "H2") and (bc == "JV" or bc == "JT") then
		return false, false
	end
	if (ac == "JT" or ac == "H3") and bc == "JT" then
		return false, false
	end
	if (hangul[ac] and bc == "PO") or (ac == "PR" and hangul[bc]) then
		return false, false
	end
	-- LB28/28a/29.
	if alpha[ac] and alpha[bc] then
		return false, false
	end
	if ac == "AP" and brahmic(b) then
		return false, false
	end
	if brahmic(a) and (bc == "VF" or bc == "VI") then
		return false, false
	end
	if brahmic(prev) and ac == "VI" and (bc == "AK" or b.cp == 0x25CC) then
		return false, false
	end
	if brahmic(a) and brahmic(b) and after.cls == "VF" then
		return false, false
	end
	if ac == "IS" and alpha[bc] then
		return false, false
	end
	-- LB30/30a/30b/31.
	if alphaNumber[ac] and bc == "OP" and not flag(b, 1) then
		return false, false
	end
	if ac == "CP" and not flag(a, 1) and alphaNumber[bc] then
		return false, false
	end
	if ac == "RI" and bc == "RI" then
		state.regional += 1
		if state.regional % 2 ~= 0 then
			return false, false
		end
	end
	if bc == "EM" and (ac == "EB" or (flag(a, 32) and flag(a, 16))) then
		return false, false
	end
	return true, false
end

local function lineBreaks(text: string): ({ Break }?, string?)
	if #text > 65536 then
		return nil, "unicode-line-break-byte-budget-exceeded"
	end
	local length = utf8.len(text)
	if not length then
		return nil, "invalid-unicode-text-utf8"
	end
	if length > 16384 then
		return nil, "unicode-line-break-codepoint-budget-exceeded"
	end
	local groups: { Character } = {}
	for offset, cp in utf8.codes(text) do
		if cp > 0x10FFFF or cp >= 0xD800 and cp <= 0xDFFF then
			return nil, "invalid-unicode-scalar"
		end
		local cls, flags = Properties.get(cp)
		-- LB1 default resolution; language dictionary segmentation is separate.
		if cls == "AI" or cls == "SG" or cls == "XX" then
			cls = "AL"
		elseif cls == "CJ" then
			cls = "NS"
		elseif cls == "SA" then
			cls = if bit32.band(flags, 2) ~= 0 then "CM" else "AL"
		end
		local previous = groups[#groups]
		local last = offset + #utf8.char(cp) - 1
		if (cls == "CM" or cls == "ZWJ") and previous and not notBase[previous.cls] then
			previous.last, previous.tail = last, cp
		else
			table.insert(
				groups,
				{
					cls = if cls == "CM" or cls == "ZWJ" then "AL" else cls,
					cp = cp,
					tail = cp,
					flags = flags,
					first = offset,
					last = last,
				}
			)
		end
	end
	local state: State = { chars = groups, spaces = false, zeroWidth = false, regional = 0, work = 0 }
	local result: { Break } = {}
	for boundaryIndex = 1, #groups + 1 do
		local index = boundaryIndex - 1
		spend(state)
		local allowed, required = boundary(state, index)
		if state.failure then
			return nil, state.failure
		end
		if allowed then
			table.insert(result, { position = if index == 0 then 0 else groups[index].last, required = required })
			if required then
				state.spaces, state.zeroWidth, state.regional = false, false, 0
			end
		end
	end
	return result, nil
end

return lineBreaks
