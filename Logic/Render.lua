-- Flattens a category tree + assigned items into an ordered list of
-- display rows: category headers, optionally storage sub-group headers
-- (Bags/Bank/Warband, §4.3 S1-S4) when at a banker, and items --
-- collapsing anything whose collapsed state is set. Pure Lua (T1) --
-- UI/ListView.lua feeds the result straight into the ScrollBox's data
-- provider.
--
-- Every category always renders, even at zero items: categories are a
-- fixed, user-organized filing structure now (empty shells the player
-- drags items into), not an emergent view of auto-sorted content --
-- and you can't drag into a category you can't see. Sub-groups
-- (Bags/Bank/Warband within a category) are a different concern and
-- still hide when empty (S3) -- those are a bank-context convenience,
-- not a place a user files things directly.

local Tree
local _, Folio = ...
if type(Folio) == "table" then
	Tree = Folio.Tree
else
	Tree = require("Logic.Tree")
end

local Render = {}

-- S2: fixed order so a drag destination is unambiguous.
local STORAGE_ORDER = { "bags", "bank", "warband" }
local STORAGE_LABELS = { bags = "Bags", bank = "Bank", warband = "Warband" }

-- itemsByCategory[categoryID] = { bags = {...}, bank = {...}, warband = {...} }
local function SubtreeItemCount(tree, itemsByCategory, nodeId)
	local total = 0
	local own = itemsByCategory[nodeId]
	if own then
		for _, storageItems in pairs(own) do
			total = total + #storageItems
		end
	end
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

-- itemsByCategory: categoryID -> { bags = {...}, bank = {...}, warband = {...} }
-- (see Data/Scanner.lua's `storage` field, tagged per scan). `bankerOpen`
-- (S1) switches between the flat away-from-banker layout and the
-- Bags/Bank/Warband sub-group layout; F18's per-category storages table
-- (already on every Tree node -- see Logic/Tree.lua) gates which
-- sub-groups a category even considers.
function Render.BuildRows(tree, itemsByCategory, bankerOpen)
	local rows = {}

	local function walk(parentId, depth)
		for _, node in ipairs(Tree.GetChildren(tree, parentId)) do
			local total = SubtreeItemCount(tree, itemsByCategory, node.id)
			table.insert(rows, {
				kind = "header",
				categoryID = node.id,
				name = node.name,
				depth = depth,
				collapsed = node.collapsed,
				count = total,
			})
			if not node.collapsed then
				local own = itemsByCategory[node.id] or {}
				if bankerOpen then
					for _, storage in ipairs(STORAGE_ORDER) do
						local items = own[storage]
						-- S3: only when non-empty and the category opts in.
						if items and #items > 0 and node.storages[storage] then
							table.insert(rows, {
								kind = "header",
								categoryID = node.id,
								subgroup = storage,
								name = STORAGE_LABELS[storage],
								depth = depth + 1,
								collapsed = node.subCollapsed[storage],
								count = #items,
							})
							if not node.subCollapsed[storage] then
								AppendItemRows(rows, items, depth + 2)
							end
						end
					end
				else
					AppendItemRows(rows, own.bags or {}, depth + 1)
				end
				walk(node.id, depth + 1)
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
