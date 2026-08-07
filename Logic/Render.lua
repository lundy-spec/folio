-- Flattens a category tree + assigned items into an ordered list of
-- display rows (category headers and items, interleaved and indented),
-- skipping any subtree with nothing in it and collapsing any subtree
-- whose header is collapsed. Pure Lua (T1) -- UI/ListView.lua feeds the
-- result straight into the ScrollBox's data provider.

local Tree
local _, Folio = ...
if type(Folio) == "table" then
	Tree = Folio.Tree
else
	Tree = require("Logic.Tree")
end

local Render = {}

local function SubtreeItemCount(tree, itemsByCategory, nodeId)
	local total = #(itemsByCategory[nodeId] or {})
	for _, child in ipairs(Tree.GetChildren(tree, nodeId)) do
		total = total + SubtreeItemCount(tree, itemsByCategory, child.id)
	end
	return total
end

local function AppendItemRows(rows, items, depth)
	for _, item in ipairs(items) do
		local row = {}
		for k, v in pairs(item) do
			row[k] = v
		end
		row.depth = depth
		table.insert(rows, row)
	end
end

-- itemsByCategory: categoryID -> array of already-`kind = "item"` entries
-- (see Data/Scanner.lua), keyed by the id Data/Assign.lua resolved each
-- item to (with an "uncategorized"-style fallback applied by the caller).
function Render.BuildRows(tree, itemsByCategory)
	local rows = {}

	local function walk(parentId, depth)
		for _, node in ipairs(Tree.GetChildren(tree, parentId)) do
			local total = SubtreeItemCount(tree, itemsByCategory, node.id)
			if total > 0 then
				table.insert(rows, {
					kind = "header",
					categoryID = node.id,
					name = node.name,
					depth = depth,
					collapsed = node.collapsed,
					count = total,
				})
				if not node.collapsed then
					AppendItemRows(rows, itemsByCategory[node.id] or {}, depth + 1)
					walk(node.id, depth + 1)
				end
			end
		end
	end

	walk(Tree.ROOT, 0)
	return rows
end

if type(Folio) == "table" then
	Folio.Render = Render
end

return Render
