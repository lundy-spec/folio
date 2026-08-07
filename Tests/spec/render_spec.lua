local Render = require("Logic.Render")
local Tree = require("Logic.Tree")

describe("Logic.Render", function()
	local tree

	before_each(function()
		tree = Tree.New()
	end)

	describe("BuildRows", function()
		it("returns nothing for an empty tree with no items", function()
			assert.are.same({}, Render.BuildRows(tree, {}))
		end)

		it("skips a category with no items anywhere in its subtree", function()
			Tree.AddNode(tree, "empty", { name = "Empty" })
			assert.are.same({}, Render.BuildRows(tree, {}))
		end)

		it("renders a header followed by its items", function()
			Tree.AddNode(tree, "a", { name = "Consumables" })
			local items = {
				{ kind = "item", itemID = 1, name = "Potion" },
				{ kind = "item", itemID = 2, name = "Flask" },
			}
			local rows = Render.BuildRows(tree, { a = items })

			assert.are.equal(3, #rows)
			assert.are.same(
				{ kind = "header", categoryID = "a", name = "Consumables", depth = 0, collapsed = false, count = 2 },
				rows[1]
			)
			assert.are.equal("item", rows[2].kind)
			assert.are.equal(1, rows[2].itemID)
			assert.are.equal(1, rows[2].depth)
			assert.are.equal("item", rows[3].kind)
			assert.are.equal(2, rows[3].itemID)
		end)

		it("does not mutate the source item tables", function()
			Tree.AddNode(tree, "a", { name = "A" })
			local source = { kind = "item", itemID = 1 }
			Render.BuildRows(tree, { a = { source } })
			assert.is_nil(source.depth)
		end)

		it("indents nested category headers and their items by depth", function()
			Tree.AddNode(tree, "equipment", { name = "Equipment" })
			Tree.AddNode(tree, "weapons", { name = "Weapons", parent = "equipment" })
			local rows = Render.BuildRows(tree, {
				weapons = { { kind = "item", itemID = 1 } },
			})

			assert.are.equal(3, #rows)
			assert.are.equal("header", rows[1].kind)
			assert.are.equal("equipment", rows[1].categoryID)
			assert.are.equal(0, rows[1].depth)
			assert.are.equal(1, rows[1].count) -- total across the subtree

			assert.are.equal("header", rows[2].kind)
			assert.are.equal("weapons", rows[2].categoryID)
			assert.are.equal(1, rows[2].depth)
			assert.are.equal(1, rows[2].count)

			assert.are.equal("item", rows[3].kind)
			assert.are.equal(2, rows[3].depth)
		end)

		it("hides a collapsed category's items and descendants but keeps its header", function()
			Tree.AddNode(tree, "equipment", { name = "Equipment", collapsed = true })
			Tree.AddNode(tree, "weapons", { name = "Weapons", parent = "equipment" })
			local rows = Render.BuildRows(tree, {
				equipment = { { kind = "item", itemID = 1 } },
				weapons = { { kind = "item", itemID = 2 } },
			})

			assert.are.equal(1, #rows)
			assert.are.equal("header", rows[1].kind)
			assert.are.equal("equipment", rows[1].categoryID)
			assert.is_true(rows[1].collapsed)
			assert.are.equal(2, rows[1].count) -- reflects true total, even hidden
		end)

		it("keeps unrelated sibling categories independent of a collapsed one", function()
			Tree.AddNode(tree, "a", { name = "A", collapsed = true, order = 1 })
			Tree.AddNode(tree, "b", { name = "B", order = 2 })
			local rows = Render.BuildRows(tree, {
				a = { { kind = "item", itemID = 1 } },
				b = { { kind = "item", itemID = 2 } },
			})

			assert.are.equal(3, #rows) -- header a, header b, item under b
			assert.are.equal("a", rows[1].categoryID)
			assert.are.equal("b", rows[2].categoryID)
			assert.are.equal("item", rows[3].kind)
		end)
	end)
end)
