local Assign = require("Data.Assign")
local Tree = require("Logic.Tree")

-- Seed.lua's starter categories carry no rules by design (product
-- direction: empty shells, manual sort) -- these specs build their own
-- small rule-bearing trees to exercise Assign's rule-matching machinery,
-- which is unchanged and still fully supported for whenever a future
-- opt-in auto-sort feature uses it.

local function TreeWithClassRules()
	local tree = Tree.New()
	Tree.AddNode(tree, "consumables", {
		name = "Consumables",
		rules = { { field = "itemClass", op = "eq", value = 0 } },
	})
	Tree.AddNode(tree, "equipment", { name = "Equipment" })
	Tree.AddNode(tree, "weapons", {
		name = "Weapons",
		parent = "equipment",
		rules = { { field = "itemClass", op = "eq", value = 2 } },
	})
	Tree.AddNode(tree, "armor", {
		name = "Armor",
		parent = "equipment",
		rules = { { field = "itemClass", op = "eq", value = 4 } },
	})
	return tree
end

describe("Data.Assign", function()
	describe("CategoryFor", function()
		it("resolves a top-level match directly", function()
			local tree = TreeWithClassRules()
			assert.are.equal("consumables", Assign.CategoryFor(tree, { itemClass = 0 }))
		end)

		it("resolves into the specific nested child rather than the grouping parent", function()
			local tree = TreeWithClassRules()
			assert.are.equal("weapons", Assign.CategoryFor(tree, { itemClass = 2 }))
			assert.are.equal("armor", Assign.CategoryFor(tree, { itemClass = 4 }))
		end)

		it("returns nil when nothing matches, leaving the fallback to the caller", function()
			local tree = TreeWithClassRules()
			assert.is_nil(Assign.CategoryFor(tree, { itemClass = 999 }))
		end)

		it("R2: a manual override wins outright, without even attempting rule resolution", function()
			local tree = TreeWithClassRules()
			-- Would otherwise resolve to "consumables" via its rule.
			assert.are.equal("junk", Assign.CategoryFor(tree, { itemClass = 0 }, "junk"))
		end)

		it("R5: a nested category's rules apply within its parent's scope", function()
			local tree = Tree.New()
			Tree.AddNode(tree, "consumables", {
				name = "Consumables",
				rules = { { field = "itemClass", op = "eq", value = 0 } },
			})
			Tree.AddNode(tree, "food", {
				name = "Food",
				parent = "consumables",
				rules = { { field = "subClass", op = "eq", value = "Food" } },
			})

			-- Matches Food's own rule AND (via R5 scoping) Consumables' ->
			-- the specific nested category.
			assert.are.equal("food", Assign.CategoryFor(tree, { itemClass = 0, subClass = "Food" }))

			-- Matches Consumables but not Food's own rule -> falls back to
			-- the broader parent instead of being unresolved.
			assert.are.equal("consumables", Assign.CategoryFor(tree, { itemClass = 0, subClass = "Potion" }))

			-- Matches neither -> unresolved.
			assert.is_nil(Assign.CategoryFor(tree, { itemClass = 2, subClass = "Food" }))
		end)

		it("would NOT resolve Food if it only checked ancestors in pre-order (regression guard)", function()
			-- If a parent with a real matching rule were checked before its
			-- child, the parent would always win first and the child's
			-- more specific rule would be unreachable. This is exactly
			-- what post-order resolution (Tree.Walk's postOrder flag)
			-- exists to prevent.
			local tree = Tree.New()
			Tree.AddNode(tree, "parent", {
				rules = { { field = "itemClass", op = "eq", value = 0 } },
			})
			Tree.AddNode(tree, "child", {
				parent = "parent",
				rules = { { field = "subClass", op = "eq", value = "X" } },
			})
			assert.are.equal("child", Assign.CategoryFor(tree, { itemClass = 0, subClass = "X" }))
		end)
	end)

	describe("ResolveAll", function()
		it("resolves every item against the same candidate set, in order", function()
			local tree = TreeWithClassRules()
			local items = {
				{ itemID = 1, itemClass = 0 }, -- consumables
				{ itemID = 2, itemClass = 2 }, -- weapons
				{ itemID = 3, itemClass = 999 }, -- unmatched
			}
			local results = Assign.ResolveAll(tree, items)
			assert.are.equal("consumables", results[1])
			assert.are.equal("weapons", results[2])
			assert.is_nil(results[3])
		end)

		it("returns an empty table for an empty item list", function()
			local tree = TreeWithClassRules()
			assert.are.same({}, Assign.ResolveAll(tree, {}))
		end)

		it("R2: an override for an item's id wins over what its rules would otherwise match", function()
			local tree = TreeWithClassRules()
			local items = {
				{ itemID = 111, itemClass = 0 }, -- would rule-match "consumables"
				{ itemID = 222, itemClass = 0 }, -- no override -> rule-matches normally
			}
			local results = Assign.ResolveAll(tree, items, { [111] = "junk" })
			assert.are.equal("junk", results[1])
			assert.are.equal("consumables", results[2])
		end)
	end)
end)
