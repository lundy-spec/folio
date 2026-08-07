-- Starter category tree for first-run onboarding (F11): "Categorize by
-- Type" from the original, run automatically on first load. Pure Lua
-- (T1) -- itemClass values are Enum.ItemClass IDs, hardcoded rather than
-- referenced (Enum is a WoW global, off-limits in Logic/), verified
-- against Blizzard's docs: Consumable=0, Weapon=2, Armor=4, Tradegoods=7,
-- Questitem=12, Miscellaneous=15.

local Tree
local _, Folio = ...
if type(Folio) == "table" then
	Tree = Folio.Tree
else
	Tree = require("Logic.Tree")
end

local ITEM_CLASS = {
	CONSUMABLE = 0,
	WEAPON = 2,
	ARMOR = 4,
	TRADEGOODS = 7,
	QUESTITEM = 12,
	MISCELLANEOUS = 15,
}

local Seed = {}

-- "Equipment" carries no rules of its own -- it's a pure grouping folder
-- for Weapons/Armor. Data/Assign.lua resolves most-specific-match-first
-- (R5), so this isn't load-bearing for correctness, but it keeps
-- "Equipment" from ever being a real match target on its own.
function Seed.BuildDefaultTree()
	local tree = Tree.New()

	Tree.AddNode(tree, "consumables", {
		name = "Consumables",
		rules = { { field = "itemClass", op = "eq", value = ITEM_CLASS.CONSUMABLE } },
	})
	Tree.AddNode(tree, "tradegoods", {
		name = "Trade Goods",
		rules = { { field = "itemClass", op = "eq", value = ITEM_CLASS.TRADEGOODS } },
	})
	Tree.AddNode(tree, "questitems", {
		name = "Quest Items",
		rules = { { field = "itemClass", op = "eq", value = ITEM_CLASS.QUESTITEM } },
	})

	Tree.AddNode(tree, "equipment", { name = "Equipment" })
	Tree.AddNode(tree, "weapons", {
		name = "Weapons",
		parent = "equipment",
		rules = { { field = "itemClass", op = "eq", value = ITEM_CLASS.WEAPON } },
	})
	Tree.AddNode(tree, "armor", {
		name = "Armor",
		parent = "equipment",
		rules = { { field = "itemClass", op = "eq", value = ITEM_CLASS.ARMOR } },
	})

	Tree.AddNode(tree, "junk", {
		name = "Junk",
		rules = { { field = "itemClass", op = "eq", value = ITEM_CLASS.MISCELLANEOUS } },
	})

	-- Manual-only fallback: no rules, so it never auto-matches (Rules.lua
	-- treats an empty rule list as never-match) -- it only ever holds
	-- items nothing else claimed, once manual assignment lands.
	Tree.AddNode(tree, "uncategorized", { name = "Uncategorized" })

	return tree
end

if type(Folio) == "table" then
	Folio.Seed = Seed
end

return Seed
