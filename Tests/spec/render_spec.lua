local Render = require("Logic.Render")
local Tree = require("Logic.Tree")

describe("Logic.Render", function()
	local tree

	before_each(function()
		tree = Tree.New()
	end)

	describe("BuildRows", function()
		it("returns nothing for an empty tree with no items", function()
			assert.are.same({}, Render.BuildRows(tree, {}, "bags"))
		end)

		it("still renders a category with no items anywhere in its subtree", function()
			-- Categories are a fixed, user-organized filing structure now
			-- (empty shells the player drags items into), not an emergent
			-- view of auto-sorted content -- you can't drag into a category
			-- you can't see.
			Tree.AddNode(tree, "empty", { name = "Empty" })
			local rows = Render.BuildRows(tree, {}, "bags")
			assert.are.equal(1, #rows)
			assert.are.equal("empty", rows[1].categoryID)
			assert.are.equal(0, rows[1].count)
		end)

		it("renders a header followed by its items, flat", function()
			Tree.AddNode(tree, "a", { name = "Consumables" })
			local groups = {
				a = { bags = { { kind = "item", itemID = 1 }, { kind = "item", itemID = 2 } } },
			}
			local rows = Render.BuildRows(tree, groups, "bags")

			assert.are.equal(3, #rows)
			assert.are.same(
				{ kind = "header", categoryID = "a", name = "Consumables", depth = 0, collapsed = false, count = 2 },
				rows[1]
			)
			assert.are.equal("item", rows[2].kind)
			assert.are.equal(1, rows[2].depth)
		end)

		it("defaults to bags when storage is omitted", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local groups = { a = { bags = { { kind = "item", itemID = 1 } } } }
			local rows = Render.BuildRows(tree, groups)

			assert.are.equal(1, rows[2].itemID)
		end)

		it("only reads the requested storage -- other storages present in the data are ignored", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local groups = {
				a = {
					bags = { { kind = "item", itemID = 1 } },
					bank = { { kind = "item", itemID = 2 } },
				},
			}
			local rows = Render.BuildRows(tree, groups, "bags")

			-- header + the one bags item only -- the bank item is neither
			-- rendered as a row NOR counted in the header total (Q43:
			-- counts are now storage-scoped too, matching what's actually
			-- reachable within this one call's window).
			assert.are.equal(2, #rows)
			assert.are.equal(1, rows[1].count)
			assert.are.equal(1, rows[2].itemID)
		end)

		it("renders the bank storage when asked for it instead", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local groups = {
				a = {
					bags = { { kind = "item", itemID = 1 } },
					bank = { { kind = "item", itemID = 2 } },
				},
			}
			local rows = Render.BuildRows(tree, groups, "bank")

			assert.are.equal(2, #rows)
			assert.are.equal(2, rows[2].itemID)
		end)

		it("does not mutate the source item tables", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local source = { kind = "item", itemID = 1 }
			Render.BuildRows(tree, { a = { bags = { source } } }, "bags")
			assert.is_nil(source.depth)
		end)
	end)

	describe("BuildRows with nested categories", function()
		it("keeps parent and child headers in pre-order with correct depth", function()
			Tree.AddNode(tree, "equipment", { name = "Equipment" })
			Tree.AddNode(tree, "weapons", { name = "Weapons", parent = "equipment" })
			local groups = { weapons = { bags = { { kind = "item", itemID = 1 } } } }
			local rows = Render.BuildRows(tree, groups, "bags")

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

		it("renders a sub-category before the parent's own items", function()
			Tree.AddNode(tree, "equipment", { name = "Equipment" })
			Tree.AddNode(tree, "weapons", { name = "Weapons", parent = "equipment" })
			local groups = {
				equipment = { bags = { { kind = "item", itemID = 1 } } },
				weapons = { bags = { { kind = "item", itemID = 2 } } },
			}
			local rows = Render.BuildRows(tree, groups, "bags")

			assert.are.equal("equipment", rows[1].categoryID)
			assert.are.equal("weapons", rows[2].categoryID)
			assert.are.equal(2, rows[3].itemID) -- weapons' own item
			assert.are.equal(1, rows[4].itemID) -- equipment's own item, last
		end)

		it("hides a collapsed category's items and descendants but keeps its own header", function()
			Tree.AddNode(tree, "equipment", { name = "Equipment", collapsed = true })
			Tree.AddNode(tree, "weapons", { name = "Weapons", parent = "equipment" })
			local groups = {
				equipment = { bags = { { kind = "item", itemID = 1 } } },
				weapons = { bags = { { kind = "item", itemID = 2 } } },
			}
			local rows = Render.BuildRows(tree, groups, "bags")

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
			local rows = Render.BuildRows(tree, groups, "bags")

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
			local rows = Render.BuildRows(tree, groups, "bags")

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
			local rows = Render.BuildRows(tree, groups, "bags")

			assert.are.equal(1, #rows)
			assert.are.equal("item", rows[1].kind)
		end)

		it("orders multiple leftover buckets deterministically by id", function()
			local groups = {
				zzz = { bags = { { kind = "item", itemID = 1 } } },
				aaa = { bags = { { kind = "item", itemID = 2 } } },
			}
			local rows = Render.BuildRows(tree, groups, "bags")

			assert.are.equal(2, #rows)
			assert.are.equal(2, rows[1].itemID) -- "aaa" sorts before "zzz"
			assert.are.equal(1, rows[2].itemID)
		end)

		it("only lists leftovers for the requested storage", function()
			local groups = {
				uncategorized = {
					bags = { { kind = "item", itemID = 1 } },
					bank = { { kind = "item", itemID = 2 } },
				},
			}
			local rows = Render.BuildRows(tree, groups, "bags")

			assert.are.equal(1, #rows)
			assert.are.equal(1, rows[1].itemID)
		end)
	end)

	describe("BuildRows collapse state (Q53)", function()
		it("falls back to the node's own collapsed default when no override is given", function()
			Tree.AddNode(tree, "a", { name = "A", collapsed = true })
			local rows = Render.BuildRows(tree, {}, "bags")
			assert.is_true(rows[1].collapsed)
		end)

		it("an override takes precedence over the node's own default", function()
			Tree.AddNode(tree, "a", { name = "A", collapsed = true })
			local rows = Render.BuildRows(tree, {}, "bags", nil, { a = false })
			assert.is_false(rows[1].collapsed)
		end)

		it("a category with no override yet uses the node default even when overrides exist for other categories", function()
			Tree.AddNode(tree, "a", { name = "A", collapsed = true })
			Tree.AddNode(tree, "b", { name = "B", collapsed = true, order = 2 })
			local rows = Render.BuildRows(tree, {}, "bags", nil, { a = false })

			assert.is_false(rows[1].collapsed) -- explicitly expanded
			assert.is_true(rows[2].collapsed) -- untouched, still its own default
		end)

		it("two different overrides tables give fully independent results for the same tree", function()
			Tree.AddNode(tree, "a", { name = "A", collapsed = true })
			local groups = { a = { bags = { { kind = "item", itemID = 1 } } } }

			local expandedRows = Render.BuildRows(tree, groups, "bags", nil, { a = false })
			local stillCollapsedRows = Render.BuildRows(tree, groups, "bags", nil, { b = true })

			assert.are.equal(2, #expandedRows) -- header + its item, visible
			assert.are.equal(1, #stillCollapsedRows) -- header only, still collapsed
		end)
	end)

	describe("BuildRows with pinned items (Q40)", function()
		it("does nothing when pinnedItemIDs is nil or empty", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local groups = { a = { bags = { { itemID = 1, name = "Widget" } } } }

			assert.are.same(Render.BuildRows(tree, groups, "bags"), Render.BuildRows(tree, groups, "bags", nil))
			assert.are.same(Render.BuildRows(tree, groups, "bags"), Render.BuildRows(tree, groups, "bags", {}))
		end)

		it("puts pinned items first, flat, with no header", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local groups = {
				a = { bags = { { itemID = 1, name = "One" }, { itemID = 2, name = "Two" } } },
			}
			local rows = Render.BuildRows(tree, groups, "bags", { 2 })

			assert.are.equal(2, rows[1].itemID)
			assert.are.equal(0, rows[1].depth)
			assert.is_nil(rows[1].kind)
		end)

		it("hides a pinned item from its normal category slot -- shows exactly once", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local groups = {
				a = { bags = { { itemID = 1, name = "One" }, { itemID = 2, name = "Two" } } },
			}
			local rows = Render.BuildRows(tree, groups, "bags", { 2 })

			local seenTwice = 0
			for _, row in ipairs(rows) do
				if row.itemID == 2 then
					seenTwice = seenTwice + 1
				end
			end
			assert.are.equal(1, seenTwice)
		end)

		it("orders multiple pinned items by pin order, not encounter order", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local groups = {
				a = { bags = { { itemID = 1, name = "One" }, { itemID = 2, name = "Two" } } },
			}
			local rows = Render.BuildRows(tree, groups, "bags", { 2, 1 })

			assert.are.equal(2, rows[1].itemID)
			assert.are.equal(1, rows[2].itemID)
		end)

		it("keeps category header counts as full ownership totals, unaffected by pinning", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local groups = {
				a = { bags = { { itemID = 1, name = "One" }, { itemID = 2, name = "Two" } } },
			}
			local rows = Render.BuildRows(tree, groups, "bags", { 2 })

			local header
			for _, row in ipairs(rows) do
				if row.kind == "header" then
					header = row
				end
			end
			assert.are.equal(2, header.count)
		end)

		it("ignores a pinned itemID that isn't currently owned", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local groups = { a = { bags = { { itemID = 1, name = "One" } } } }
			local rows = Render.BuildRows(tree, groups, "bags", { 999 })

			for _, row in ipairs(rows) do
				assert.are_not.equal(999, row.itemID)
			end
		end)

		it("only pins items belonging to the requested storage", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local groups = {
				a = {
					bags = { { itemID = 1, name = "InBags" } },
					bank = { { itemID = 1, name = "InBank" } },
				},
			}
			local bagsRows = Render.BuildRows(tree, groups, "bags", { 1 })
			local bankRows = Render.BuildRows(tree, groups, "bank", { 1 })

			assert.are.equal("InBags", bagsRows[1].name)
			assert.are.equal("InBank", bankRows[1].name)
		end)
	end)

	describe("BuildSearchRows", function()
		it("returns only items whose name contains the search text, case-insensitively", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local groups = {
				a = {
					bags = {
						{ itemID = 1, name = "Silvermoon Health Potion" },
						{ itemID = 2, name = "Flask of Thalassian Resistance" },
					},
				},
			}
			local rows = Render.BuildSearchRows(tree, groups, "bags", "health")

			assert.are.equal(1, #rows)
			assert.are.equal(1, rows[1].itemID)
		end)

		it("finds items inside a collapsed category -- search ignores collapse state", function()
			Tree.AddNode(tree, "a", { name = "A", collapsed = true })
			local groups = { a = { bags = { { itemID = 1, name = "Mysterious Egg" } } } }
			local rows = Render.BuildSearchRows(tree, groups, "bags", "egg")

			assert.are.equal(1, #rows)
			assert.are.equal(1, rows[1].itemID)
		end)

		it("returns no headers and zero depth on every row", function()
			Tree.AddNode(tree, "equipment", { name = "Equipment" })
			Tree.AddNode(tree, "weapons", { name = "Weapons", parent = "equipment" })
			local groups = { weapons = { bags = { { itemID = 1, name = "Sword of Testing" } } } }
			local rows = Render.BuildSearchRows(tree, groups, "bags", "sword")

			assert.are.equal(1, #rows)
			assert.is_nil(rows[1].kind)
			assert.are.equal(0, rows[1].depth)
		end)

		it("plain-matches literal text, not a Lua pattern", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local groups = { a = { bags = { { itemID = 1, name = "Rank 3 (Epic)" } } } }
			local rows = Render.BuildSearchRows(tree, groups, "bags", "3 (ep")

			assert.are.equal(1, #rows)
		end)

		it("defaults to bags when storage is omitted", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local groups = { a = { bags = { { itemID = 1, name = "Widget" } } } }
			local rows = Render.BuildSearchRows(tree, groups, nil, "widget")

			assert.are.equal(1, #rows)
		end)

		it("only searches the requested storage", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local groups = {
				a = {
					bags = { { itemID = 1, name = "Widget" } },
					bank = { { itemID = 2, name = "Widget" } },
				},
			}
			local rows = Render.BuildSearchRows(tree, groups, "bank", "widget")

			assert.are.equal(1, #rows)
			assert.are.equal(2, rows[1].itemID)
		end)

		it("includes leftover (uncategorized) items", function()
			local groups = { uncategorized = { bags = { { itemID = 1, name = "Loose Widget" } } } }
			local rows = Render.BuildSearchRows(tree, groups, "bags", "widget")

			assert.are.equal(1, #rows)
		end)

		it("returns nothing when nothing matches", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local groups = { a = { bags = { { itemID = 1, name = "Widget" } } } }
			assert.are.same({}, Render.BuildSearchRows(tree, groups, "bags", "nonexistent"))
		end)

		it("does not mutate the source item tables", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local source = { itemID = 1, name = "Widget" }
			Render.BuildSearchRows(tree, { a = { bags = { source } } }, "bags", "widget")
			assert.is_nil(source.depth)
		end)
	end)
end)
