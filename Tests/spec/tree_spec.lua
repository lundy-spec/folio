local Tree = require("Logic.Tree")

describe("Logic.Tree", function()
	local tree

	before_each(function()
		tree = Tree.New()
	end)

	describe("AddNode", function()
		it("adds a top-level node defaulting to root", function()
			local node = Tree.AddNode(tree, "a", { name = "Consumables" })
			assert.is_not_nil(node)
			assert.are.equal("Consumables", node.name)
			assert.are.equal(Tree.ROOT, node.parent)
		end)

		it("adds a nested node under an existing parent", function()
			Tree.AddNode(tree, "a", { name = "Consumables" })
			local child = Tree.AddNode(tree, "a1", { name = "Food", parent = "a" })
			assert.are.equal("a", child.parent)
		end)

		it("rejects a duplicate id", function()
			Tree.AddNode(tree, "a", {})
			local node, err = Tree.AddNode(tree, "a", {})
			assert.is_nil(node)
			assert.are.equal("id already exists", err)
		end)

		it("rejects a nonexistent parent", function()
			local node, err = Tree.AddNode(tree, "a", { parent = "ghost" })
			assert.is_nil(node)
			assert.are.equal("parent does not exist", err)
		end)

		it("rejects the reserved root id", function()
			local node, err = Tree.AddNode(tree, Tree.ROOT, {})
			assert.is_nil(node)
			assert.are.equal("invalid id", err)
		end)

		it("defaults storages and subCollapsed", function()
			local node = Tree.AddNode(tree, "a", {})
			assert.is_true(node.storages.bags)
			assert.is_true(node.storages.bank)
			assert.is_true(node.storages.warband)
			assert.is_false(node.subCollapsed.bags)
		end)
	end)

	describe("RenameNode", function()
		it("renames an existing node", function()
			Tree.AddNode(tree, "a", { name = "Old" })
			local ok = Tree.RenameNode(tree, "a", "New")
			assert.is_true(ok)
			assert.are.equal("New", Tree.GetNode(tree, "a").name)
		end)

		it("errors on a nonexistent node", function()
			local ok, err = Tree.RenameNode(tree, "ghost", "New")
			assert.is_nil(ok)
			assert.are.equal("not found", err)
		end)
	end)

	describe("RemoveNode", function()
		it("removes a leaf node", function()
			Tree.AddNode(tree, "a", {})
			local removed = Tree.RemoveNode(tree, "a")
			assert.are.same({ "a" }, removed)
			assert.is_nil(Tree.GetNode(tree, "a"))
		end)

		it("cascades to children and grandchildren, leaving no orphans", function()
			Tree.AddNode(tree, "a", {})
			Tree.AddNode(tree, "a1", { parent = "a" })
			Tree.AddNode(tree, "a1a", { parent = "a1" })
			Tree.AddNode(tree, "b", {}) -- unrelated sibling, must survive

			local removed = Tree.RemoveNode(tree, "a")
			table.sort(removed)
			assert.are.same({ "a", "a1", "a1a" }, removed)
			assert.is_nil(Tree.GetNode(tree, "a"))
			assert.is_nil(Tree.GetNode(tree, "a1"))
			assert.is_nil(Tree.GetNode(tree, "a1a"))
			assert.is_not_nil(Tree.GetNode(tree, "b"))
		end)

		it("errors on a nonexistent node", function()
			local removed, err = Tree.RemoveNode(tree, "ghost")
			assert.is_nil(removed)
			assert.are.equal("not found", err)
		end)
	end)

	describe("MoveNode", function()
		it("reparents a node to another existing category", function()
			Tree.AddNode(tree, "a", {})
			Tree.AddNode(tree, "b", {})
			local ok = Tree.MoveNode(tree, "b", "a")
			assert.is_true(ok)
			assert.are.equal("a", Tree.GetNode(tree, "b").parent)
		end)

		it("moves a node back to top level via root", function()
			Tree.AddNode(tree, "a", {})
			Tree.AddNode(tree, "a1", { parent = "a" })
			Tree.MoveNode(tree, "a1", Tree.ROOT)
			assert.are.equal(Tree.ROOT, Tree.GetNode(tree, "a1").parent)
		end)

		it("rejects moving a node into itself", function()
			Tree.AddNode(tree, "a", {})
			local ok, err = Tree.MoveNode(tree, "a", "a")
			assert.is_nil(ok)
			assert.are.equal("would create a cycle", err)
		end)

		it("rejects moving a node into its own descendant", function()
			Tree.AddNode(tree, "a", {})
			Tree.AddNode(tree, "a1", { parent = "a" })
			Tree.AddNode(tree, "a1a", { parent = "a1" })
			local ok, err = Tree.MoveNode(tree, "a", "a1a")
			assert.is_nil(ok)
			assert.are.equal("would create a cycle", err)
		end)

		it("errors on a nonexistent parent", function()
			Tree.AddNode(tree, "a", {})
			local ok, err = Tree.MoveNode(tree, "a", "ghost")
			assert.is_nil(ok)
			assert.are.equal("parent does not exist", err)
		end)

		it("errors on a nonexistent node", function()
			local ok, err = Tree.MoveNode(tree, "ghost", Tree.ROOT)
			assert.is_nil(ok)
			assert.are.equal("not found", err)
		end)
	end)

	describe("GetChildren", function()
		it("sorts by order", function()
			Tree.AddNode(tree, "a", { order = 2 })
			Tree.AddNode(tree, "b", { order = 1 })
			Tree.AddNode(tree, "c", { order = 3 })
			local children = Tree.GetChildren(tree, Tree.ROOT)
			local ids = {}
			for _, node in ipairs(children) do table.insert(ids, node.id) end
			assert.are.same({ "b", "a", "c" }, ids)
		end)

		it("appends new siblings after the current max order", function()
			Tree.AddNode(tree, "a", { order = 5 })
			local b = Tree.AddNode(tree, "b", {})
			assert.are.equal(6, b.order)
		end)

		it("only returns direct children of the given parent", function()
			Tree.AddNode(tree, "a", {})
			Tree.AddNode(tree, "a1", { parent = "a" })
			Tree.AddNode(tree, "b", {})
			local rootChildren = Tree.GetChildren(tree, Tree.ROOT)
			assert.are.equal(2, #rootChildren)
		end)
	end)

	describe("ReorderChildren", function()
		it("applies a new order to the given siblings", function()
			Tree.AddNode(tree, "a", {})
			Tree.AddNode(tree, "b", {})
			Tree.AddNode(tree, "c", {})
			local ok = Tree.ReorderChildren(tree, Tree.ROOT, { "c", "a", "b" })
			assert.is_true(ok)
			local ids = {}
			for _, node in ipairs(Tree.GetChildren(tree, Tree.ROOT)) do
				table.insert(ids, node.id)
			end
			assert.are.same({ "c", "a", "b" }, ids)
		end)

		it("rejects a set that omits a current child", function()
			Tree.AddNode(tree, "a", {})
			Tree.AddNode(tree, "b", {})
			local ok, err = Tree.ReorderChildren(tree, Tree.ROOT, { "a" })
			assert.is_nil(ok)
			assert.are.equal("orderedIds does not match current children", err)
		end)

		it("rejects a set with a duplicate id", function()
			Tree.AddNode(tree, "a", {})
			Tree.AddNode(tree, "b", {})
			local ok, err = Tree.ReorderChildren(tree, Tree.ROOT, { "a", "a" })
			assert.is_nil(ok)
			assert.are.equal("orderedIds does not match current children", err)
		end)

		it("rejects an id that isn't actually a child of this parent", function()
			Tree.AddNode(tree, "a", {})
			Tree.AddNode(tree, "b", {})
			Tree.AddNode(tree, "b1", { parent = "b" })
			local ok, err = Tree.ReorderChildren(tree, Tree.ROOT, { "a", "b1" })
			assert.is_nil(ok)
			assert.are.equal("orderedIds does not match current children", err)
		end)
	end)

	describe("GetPath", function()
		it("returns just the id for a top-level node", function()
			Tree.AddNode(tree, "a", {})
			assert.are.same({ "a" }, Tree.GetPath(tree, "a"))
		end)

		it("returns the full ancestor chain for a nested node", function()
			Tree.AddNode(tree, "a", {})
			Tree.AddNode(tree, "a1", { parent = "a" })
			Tree.AddNode(tree, "a1a", { parent = "a1" })
			assert.are.same({ "a", "a1", "a1a" }, Tree.GetPath(tree, "a1a"))
		end)

		it("returns nil for a nonexistent node", function()
			assert.is_nil(Tree.GetPath(tree, "ghost"))
		end)
	end)

	describe("IsDescendantOf", function()
		it("is true for a direct child", function()
			Tree.AddNode(tree, "a", {})
			Tree.AddNode(tree, "a1", { parent = "a" })
			assert.is_true(Tree.IsDescendantOf(tree, "a1", "a"))
		end)

		it("is true for a grandchild", function()
			Tree.AddNode(tree, "a", {})
			Tree.AddNode(tree, "a1", { parent = "a" })
			Tree.AddNode(tree, "a1a", { parent = "a1" })
			assert.is_true(Tree.IsDescendantOf(tree, "a1a", "a"))
		end)

		it("is false for unrelated nodes", function()
			Tree.AddNode(tree, "a", {})
			Tree.AddNode(tree, "b", {})
			assert.is_false(Tree.IsDescendantOf(tree, "b", "a"))
		end)
	end)

	describe("Walk", function()
		it("visits every node depth-first in sibling order", function()
			Tree.AddNode(tree, "a", { order = 1 })
			Tree.AddNode(tree, "a1", { parent = "a", order = 1 })
			Tree.AddNode(tree, "a2", { parent = "a", order = 2 })
			Tree.AddNode(tree, "b", { order = 2 })

			local visited = {}
			Tree.Walk(tree, Tree.ROOT, function(node, depth)
				table.insert(visited, { id = node.id, depth = depth })
			end)

			assert.are.same({
				{ id = "a", depth = 0 },
				{ id = "a1", depth = 1 },
				{ id = "a2", depth = 1 },
				{ id = "b", depth = 0 },
			}, visited)
		end)

		it("visits children before their parent in post-order mode", function()
			Tree.AddNode(tree, "a", { order = 1 })
			Tree.AddNode(tree, "a1", { parent = "a", order = 1 })
			Tree.AddNode(tree, "a2", { parent = "a", order = 2 })
			Tree.AddNode(tree, "b", { order = 2 })

			local visited = {}
			Tree.Walk(tree, Tree.ROOT, function(node, depth)
				table.insert(visited, { id = node.id, depth = depth })
			end, true)

			assert.are.same({
				{ id = "a1", depth = 1 },
				{ id = "a2", depth = 1 },
				{ id = "a", depth = 0 },
				{ id = "b", depth = 0 },
			}, visited)
		end)
	end)
end)
