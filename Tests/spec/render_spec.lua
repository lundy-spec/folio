local Render = require("Logic.Render")
local Tree = require("Logic.Tree")

describe("Logic.Render", function()
	local tree

	before_each(function()
		tree = Tree.New()
	end)

	describe("BuildRows away from a banker (bankerOpen = false)", function()
		it("returns nothing for an empty tree with no items", function()
			assert.are.same({}, Render.BuildRows(tree, {}, false))
		end)

		it("still renders a category with no items anywhere in its subtree", function()
			-- Categories are a fixed, user-organized filing structure now
			-- (empty shells the player drags items into), not an emergent
			-- view of auto-sorted content -- you can't drag into a category
			-- you can't see.
			Tree.AddNode(tree, "empty", { name = "Empty" })
			local rows = Render.BuildRows(tree, {}, false)
			assert.are.equal(1, #rows)
			assert.are.equal("empty", rows[1].categoryID)
			assert.are.equal(0, rows[1].count)
		end)

		it("renders a header followed by its bag items, flat, no sub-groups", function()
			Tree.AddNode(tree, "a", { name = "Consumables" })
			local groups = {
				a = { bags = { { kind = "item", itemID = 1 }, { kind = "item", itemID = 2 } } },
			}
			local rows = Render.BuildRows(tree, groups, false)

			assert.are.equal(3, #rows)
			assert.are.same(
				{ kind = "header", categoryID = "a", name = "Consumables", depth = 0, collapsed = false, count = 2 },
				rows[1]
			)
			assert.are.equal("item", rows[2].kind)
			assert.is_nil(rows[2].subgroup)
			assert.are.equal(1, rows[2].depth)
		end)

		it("ignores bank/warband items entirely, even if present in the data", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local groups = {
				a = {
					bags = { { kind = "item", itemID = 1 } },
					bank = { { kind = "item", itemID = 2 } },
				},
			}
			local rows = Render.BuildRows(tree, groups, false)

			-- header + the one bag item only -- bank item counted in the
			-- header total (it's real data) but never rendered as a row.
			assert.are.equal(2, #rows)
			assert.are.equal(2, rows[1].count)
			assert.are.equal(1, rows[2].itemID)
		end)

		it("does not mutate the source item tables", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local source = { kind = "item", itemID = 1 }
			Render.BuildRows(tree, { a = { bags = { source } } }, false)
			assert.is_nil(source.depth)
		end)
	end)

	describe("BuildRows at a banker (bankerOpen = true)", function()
		it("adds a sub-group header per non-empty storage, in Bags/Bank/Warband order", function()
			Tree.AddNode(tree, "a", { name = "Consumables" })
			local groups = {
				a = {
					bags = { { kind = "item", itemID = 1 } },
					warband = { { kind = "item", itemID = 2 } },
					bank = { { kind = "item", itemID = 3 } },
				},
			}
			local rows = Render.BuildRows(tree, groups, true)

			assert.are.equal("header", rows[1].kind)
			assert.are.equal("a", rows[1].categoryID)
			assert.are.equal(3, rows[1].count)

			assert.are.equal("bags", rows[2].subgroup)
			assert.are.equal(1, rows[3].itemID)
			assert.are.equal("bank", rows[4].subgroup)
			assert.are.equal(3, rows[5].itemID)
			assert.are.equal("warband", rows[6].subgroup)
			assert.are.equal(2, rows[7].itemID)
		end)

		it("skips an empty storage (S3)", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local groups = { a = { bags = { { kind = "item", itemID = 1 } } } }
			local rows = Render.BuildRows(tree, groups, true)

			-- category header, bags sub-header, its item -- no bank/warband
			-- sub-headers since those storages have nothing in them.
			assert.are.equal(3, #rows)
			assert.are.equal("bags", rows[2].subgroup)
			for _, row in ipairs(rows) do
				assert.are_not.equal("bank", row.subgroup)
				assert.are_not.equal("warband", row.subgroup)
			end
		end)

		it("indents sub-group headers and their items one level past the category", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local rows = Render.BuildRows(tree, { a = { bags = { { kind = "item", itemID = 1 } } } }, true)

			assert.are.equal(0, rows[1].depth)
			assert.are.equal(1, rows[2].depth) -- sub-group header
			assert.are.equal(2, rows[3].depth) -- item under it
		end)

		it("respects F18: a category that opts out of a storage never shows that sub-group", function()
			Tree.AddNode(tree, "a", { name = "A", storages = { bags = true, bank = false, warband = true } })
			local groups = {
				a = {
					bags = { { kind = "item", itemID = 1 } },
					bank = { { kind = "item", itemID = 2 } },
				},
			}
			local rows = Render.BuildRows(tree, groups, true)

			for _, row in ipairs(rows) do
				assert.are_not.equal("bank", row.subgroup)
			end
		end)

		it("collapsing a sub-group hides only that sub-group's items", function()
			Tree.AddNode(tree, "a", {
				name = "A",
				subCollapsed = { bags = true, bank = false, warband = false },
			})
			local groups = {
				a = {
					bags = { { kind = "item", itemID = 1 } },
					bank = { { kind = "item", itemID = 2 } },
				},
			}
			local rows = Render.BuildRows(tree, groups, true)

			-- category header, bags sub-header (collapsed, no item row),
			-- bank sub-header, bank item row.
			assert.are.equal(4, #rows)
			assert.are.equal("bags", rows[2].subgroup)
			assert.is_true(rows[2].collapsed)
			assert.are.equal("bank", rows[3].subgroup)
			assert.are.equal(2, rows[4].itemID)
		end)
	end)

	describe("BuildRows with nested categories", function()
		it("keeps parent and child headers in pre-order with correct depth", function()
			Tree.AddNode(tree, "equipment", { name = "Equipment" })
			Tree.AddNode(tree, "weapons", { name = "Weapons", parent = "equipment" })
			local groups = { weapons = { bags = { { kind = "item", itemID = 1 } } } }
			local rows = Render.BuildRows(tree, groups, false)

			assert.are.equal("header", rows[1].kind)
			assert.are.equal("equipment", rows[1].categoryID)
			assert.are.equal(0, rows[1].depth)
			assert.are.equal(1, rows[1].count) -- total across the subtree

			assert.are.equal("header", rows[2].kind)
			assert.are.equal("weapons", rows[2].categoryID)
			assert.are.equal(1, rows[2].depth)

			assert.are.equal("item", rows[3].kind)
			assert.are.equal(2, rows[3].depth)
		end)

		it("hides a collapsed category's items and descendants but keeps its own header", function()
			Tree.AddNode(tree, "equipment", { name = "Equipment", collapsed = true })
			Tree.AddNode(tree, "weapons", { name = "Weapons", parent = "equipment" })
			local groups = {
				equipment = { bags = { { kind = "item", itemID = 1 } } },
				weapons = { bags = { { kind = "item", itemID = 2 } } },
			}
			local rows = Render.BuildRows(tree, groups, false)

			assert.are.equal(1, #rows)
			assert.are.equal("equipment", rows[1].categoryID)
			assert.is_true(rows[1].collapsed)
			assert.are.equal(2, rows[1].count) -- reflects true total, even hidden
		end)

		it("keeps unrelated sibling categories independent of a collapsed one", function()
			Tree.AddNode(tree, "a", { name = "A", collapsed = true, order = 1 })
			Tree.AddNode(tree, "b", { name = "B", order = 2 })
			local groups = {
				a = { bags = { { kind = "item", itemID = 1 } } },
				b = { bags = { { kind = "item", itemID = 2 } } },
			}
			local rows = Render.BuildRows(tree, groups, false)

			assert.are.equal(3, #rows) -- header a, header b, item under b
			assert.are.equal("a", rows[1].categoryID)
			assert.are.equal("b", rows[2].categoryID)
			assert.are.equal("item", rows[3].kind)
		end)
	end)

	describe("BuildRows leftover items (no matching tree node)", function()
		it("lists them flat, with no header, after every real category", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local groups = {
				a = { bags = { { kind = "item", itemID = 1 } } },
				uncategorized = { bags = { { kind = "item", itemID = 2 } } },
			}
			local rows = Render.BuildRows(tree, groups, false)

			assert.are.equal(3, #rows)
			assert.are.equal("header", rows[1].kind)
			assert.are.equal("a", rows[1].categoryID)
			assert.are.equal("item", rows[2].kind)
			assert.are.equal(1, rows[2].itemID)
			assert.are.equal("item", rows[3].kind)
			assert.are.equal(2, rows[3].itemID)
			assert.are.equal(0, rows[3].depth)
			assert.is_nil(rows[3].categoryID)
		end)

		it("still lists leftovers even when the tree has no categories at all", function()
			local groups = { uncategorized = { bags = { { kind = "item", itemID = 1 } } } }
			local rows = Render.BuildRows(tree, groups, false)

			assert.are.equal(1, #rows)
			assert.are.equal("item", rows[1].kind)
		end)

		it("orders multiple leftover buckets deterministically by id", function()
			local groups = {
				zzz = { bags = { { kind = "item", itemID = 1 } } },
				aaa = { bags = { { kind = "item", itemID = 2 } } },
			}
			local rows = Render.BuildRows(tree, groups, false)

			assert.are.equal(2, #rows)
			assert.are.equal(2, rows[1].itemID) -- "aaa" sorts before "zzz"
			assert.are.equal(1, rows[2].itemID)
		end)

		it("flattens across all storages regardless of bankerOpen", function()
			local groups = {
				uncategorized = {
					bags = { { kind = "item", itemID = 1 } },
					bank = { { kind = "item", itemID = 2 } },
				},
			}
			local rows = Render.BuildRows(tree, groups, true)

			assert.are.equal(2, #rows)
			assert.are.equal(1, rows[1].itemID)
			assert.are.equal(2, rows[2].itemID)
			assert.is_nil(rows[1].subgroup)
		end)
	end)
end)
