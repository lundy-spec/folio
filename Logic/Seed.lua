-- Starter category tree for first-run onboarding (F11). Per product
-- direction: ships as flat, empty, RULE-LESS organizational shells the
-- user fills manually -- most players want to self-organize rather than
-- receive an opinionated auto-sorted taxonomy. A one-shot "auto-sort"
-- helper (closer to Baud Manifest's original one-time "Categorize by
-- Type" than a live rule engine) is a planned first-run experience, not
-- this file's job -- nothing here ever auto-matches an item.

local Tree
local _, Folio = ...
if type(Folio) == "table" then
	Tree = Folio.Tree
else
	Tree = require("Logic.Tree")
end

local Seed = {}

local STARTER_CATEGORIES = {
	{ id = "consumables", name = "Consumables" },
	{ id = "miscellaneous", name = "Miscellaneous" },
	{ id = "tradegoods", name = "Trade Goods" },
	{ id = "equipment", name = "Equipment" },
	{ id = "questitems", name = "Quest Items" },
	{ id = "junk", name = "Junk" },
}

-- UI11: default new categories to collapsed.
function Seed.BuildDefaultTree()
	local tree = Tree.New()

	for _, category in ipairs(STARTER_CATEGORIES) do
		Tree.AddNode(tree, category.id, { name = category.name, collapsed = true })
	end

	-- Everything nothing's been manually sorted into yet lands here --
	-- no rules, so (like every other starter category) it never
	-- auto-matches; it's just where unclaimed items are found by default.
	Tree.AddNode(tree, "uncategorized", { name = "Uncategorized", collapsed = true })

	return tree
end

if type(Folio) == "table" then
	Folio.Seed = Seed
end

return Seed
