local Seed = require("Logic.Seed")
local Tree = require("Logic.Tree")
local Rules = require("Logic.Rules")

describe("Logic.Seed", function()
	describe("BuildDefaultTree", function()
		it("creates the expected top-level categories", function()
			local tree = Seed.BuildDefaultTree()
			local ids = {}
			for _, node in ipairs(Tree.GetChildren(tree, Tree.ROOT)) do
				table.insert(ids, node.id)
			end
			table.sort(ids)
			assert.are.same(
				{ "consumables", "equipment", "junk", "questitems", "tradegoods", "uncategorized" },
				ids
			)
		end)

		it("nests Weapons and Armor under Equipment", function()
			local tree = Seed.BuildDefaultTree()
			local ids = {}
			for _, node in ipairs(Tree.GetChildren(tree, "equipment")) do
				table.insert(ids, node.id)
			end
			table.sort(ids)
			assert.are.same({ "armor", "weapons" }, ids)
		end)

		it("gives Equipment no rules of its own (pure grouping)", function()
			local tree = Seed.BuildDefaultTree()
			local equipment = Tree.GetNode(tree, "equipment")
			assert.is_true(equipment.rules == nil or #equipment.rules == 0)
		end)

		it("gives Uncategorized no rules (manual-only fallback)", function()
			local tree = Seed.BuildDefaultTree()
			local uncategorized = Tree.GetNode(tree, "uncategorized")
			assert.is_true(uncategorized.rules == nil or #uncategorized.rules == 0)
		end)

		it("matches items by the documented itemClass on each rule-bearing category", function()
			local tree = Seed.BuildDefaultTree()
			assert.is_true(Rules.Matches({ itemClass = 0 }, Tree.GetNode(tree, "consumables").rules))
			assert.is_true(Rules.Matches({ itemClass = 7 }, Tree.GetNode(tree, "tradegoods").rules))
			assert.is_true(Rules.Matches({ itemClass = 12 }, Tree.GetNode(tree, "questitems").rules))
			assert.is_true(Rules.Matches({ itemClass = 2 }, Tree.GetNode(tree, "weapons").rules))
			assert.is_true(Rules.Matches({ itemClass = 4 }, Tree.GetNode(tree, "armor").rules))
			assert.is_true(Rules.Matches({ itemClass = 15 }, Tree.GetNode(tree, "junk").rules))
		end)
	end)
end)
