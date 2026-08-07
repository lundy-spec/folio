local Seed = require("Logic.Seed")
local Tree = require("Logic.Tree")

describe("Logic.Seed", function()
	describe("BuildDefaultTree", function()
		it("creates the six flat starter categories plus Uncategorized", function()
			local tree = Seed.BuildDefaultTree()
			local ids = {}
			for _, node in ipairs(Tree.GetChildren(tree, Tree.ROOT)) do
				table.insert(ids, node.id)
			end
			table.sort(ids)
			assert.are.same({
				"consumables",
				"equipment",
				"junk",
				"miscellaneous",
				"questitems",
				"tradegoods",
				"uncategorized",
			}, ids)
		end)

		it("gives every category no rules -- nothing auto-sorts by default", function()
			local tree = Seed.BuildDefaultTree()
			for id in pairs(tree.nodes) do
				local rules = Tree.GetNode(tree, id).rules
				assert.is_true(rules == nil or #rules == 0, id .. " should have no rules")
			end
		end)

		it("creates no nesting -- every category is top-level", function()
			local tree = Seed.BuildDefaultTree()
			for id in pairs(tree.nodes) do
				assert.are.equal(Tree.ROOT, Tree.GetNode(tree, id).parent)
			end
		end)

		it("starts every category collapsed (UI11)", function()
			local tree = Seed.BuildDefaultTree()
			for id in pairs(tree.nodes) do
				assert.is_true(Tree.GetNode(tree, id).collapsed, id .. " should start collapsed")
			end
		end)
	end)
end)
