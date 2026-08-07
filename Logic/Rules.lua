-- Pure Lua rule-based auto-assignment engine (§4.2, T1: zero WoW API refs).
--
-- A category's `rules` field (see Logic/Tree.lua's node shape) is a flat
-- list of predicates, AND'd together, with `exclude = true` predicates
-- inverted -- so { {field="itemClass",...}, {field="quality",...,exclude=true} }
-- reads as "itemClass matches, AND quality does NOT match" (R3's
-- "Consumables, but not Junk" example).
--
-- R5 (nested categories scope rules to their ancestors) and R2 (a manual
-- override is sticky and skips rule evaluation entirely) are the caller's
-- responsibility -- this module only evaluates whatever rule list it's
-- given. Merge a category's rules with its ancestors' (e.g. via
-- Tree.GetPath) before calling Resolve to get R5's scoping; don't call
-- Resolve at all for items with a manual override to get R2.

local Rules = {}

local function EvalPredicate(item, predicate)
	local value = item[predicate.field]
	local op = predicate.op

	if op == "eq" then
		return value == predicate.value
	elseif op == "neq" then
		return value ~= predicate.value
	elseif op == "gte" then
		return value ~= nil and value >= predicate.value
	elseif op == "lte" then
		return value ~= nil and value <= predicate.value
	elseif op == "between" then
		return value ~= nil and value >= predicate.value[1] and value <= predicate.value[2]
	elseif op == "in" then
		if value == nil then return false end
		for _, candidate in ipairs(predicate.value) do
			if value == candidate then return true end
		end
		return false
	end

	error("Rules: unknown predicate op '" .. tostring(op) .. "'")
end

-- Does `item` satisfy this single composite rule (one category's own
-- rules, unscoped)? A nil/empty rule list never matches -- a category
-- with no rules is manual-only.
function Rules.Matches(item, rules)
	if not rules or #rules == 0 then
		return false
	end
	for _, predicate in ipairs(rules) do
		local matched = EvalPredicate(item, predicate)
		if predicate.exclude then
			if matched then return false end
		elseif not matched then
			return false
		end
	end
	return true
end

-- R1: first-match-wins across an ordered list of candidates, each
-- `{ id = <categoryId>, rules = <predicate list> }`. Pass already
-- ancestor-merged rules per candidate to get R5's nesting scope.
function Rules.Resolve(item, candidates)
	for _, candidate in ipairs(candidates) do
		if Rules.Matches(item, candidate.rules) then
			return candidate.id
		end
	end
	return nil
end

local _, Folio = ...
if type(Folio) == "table" then
	Folio.Rules = Rules
end

return Rules
