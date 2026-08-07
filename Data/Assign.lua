-- Glue between Logic/Tree.lua and Logic/Rules.lua. Rules.lua is
-- deliberately Tree-agnostic (see its header) -- this is where R5
-- (nested categories scope rules to their ancestors) actually gets
-- implemented, by merging each node's rules with its ancestors' before
-- handing the candidate list to Rules.Resolve.

local Tree, Rules
local _, Folio = ...
if type(Folio) == "table" then
	Tree, Rules = Folio.Tree, Folio.Rules
else
	Tree, Rules = require("Logic.Tree"), require("Logic.Rules")
end

local Assign = {}

local function BuildCandidates(tree)
	local candidates = {}
	-- Post-order: a node's children are candidates before the node itself,
	-- so the most specific matching category wins over a broader ancestor
	-- (R5) instead of the first-visited ancestor always winning first.
	Tree.Walk(tree, Tree.ROOT, function(node)
		local mergedRules = {}
		for _, id in ipairs(Tree.GetPath(tree, node.id)) do
			local ancestor = Tree.GetNode(tree, id)
			for _, predicate in ipairs(ancestor.rules or {}) do
				table.insert(mergedRules, predicate)
			end
		end
		table.insert(candidates, { id = node.id, rules = mergedRules })
	end, true)
	return candidates
end

-- R1/R5: first-match-wins over the tree, most-specific-first, each
-- candidate's rules pre-merged with its ancestors'. Returns nil if
-- nothing matches; the caller decides the fallback (typically an
-- "uncategorized" category id). `override`, if given, wins outright
-- (R2: a manual assignment is a sticky override no rule can move) --
-- rule resolution is never even attempted.
function Assign.CategoryFor(tree, item, override)
	if override then
		return override
	end
	return Rules.Resolve(item, BuildCandidates(tree))
end

-- Batch form: builds the candidate list once and reuses it for every
-- item, instead of re-walking the tree per item (R4's spirit -- full
-- item->category caching across refreshes can come later if it's ever
-- actually the bottleneck). Returns a parallel array of category ids
-- (or nil per slot where nothing matched). `overrides` (itemID ->
-- categoryID, R2) is checked before rule resolution per item.
function Assign.ResolveAll(tree, items, overrides)
	local candidates = BuildCandidates(tree)
	local results = {}
	for i, item in ipairs(items) do
		local override = overrides and overrides[item.itemID]
		if override then
			results[i] = override
		else
			results[i] = Rules.Resolve(item, candidates)
		end
	end
	return results
end

if type(Folio) == "table" then
	Folio.Data = Folio.Data or {}
	Folio.Data.Assign = Assign
end

return Assign
