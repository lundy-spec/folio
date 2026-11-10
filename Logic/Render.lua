-- Flattens a category tree + assigned items into an ordered list of
-- display rows: category headers and items, collapsing anything whose
-- collapsed state is set. Pure Lua (T1) -- UI/ListView.lua feeds the
-- result straight into the ScrollBox's data provider.
--
-- Every category always renders, even at zero items: categories are a
-- fixed, user-organized filing structure now (empty shells the player
-- drags items into), not an emergent view of auto-sorted content -- and
-- you can't drag into a category you can't see.
--
-- Q43: single-storage in, single-storage out -- bags and bank no longer
-- share one combined view with inline sub-group headers (§4.3 S1-S4,
-- retired). The main window always renders "bags"; the bank drawer
-- (UI/BankFrame.lua) renders "bank". `itemsByCategory` still carries
-- every storage's items (Data/Scanner.lua tags each one), `storage` just
-- says which key to read.

local Tree
local _, Folio = ...
if type(Folio) == "table" then
	Tree = Folio.Tree
else
	Tree = require("Logic.Tree")
end

local Render = {}

-- Q53: collapse state is per-window/section now, not one shared value on
-- the tree node -- expanding a category in the bank drawer shouldn't
-- also expand it in the main bags window. `overrides` (a categoryID ->
-- bool map, one per storage -- Core/Init.lua's db.collapsedByStorage)
-- holds only what's been EXPLICITLY toggled for THIS storage; anything
-- not in there yet falls back to the node's own `collapsed` (its
-- original default -- Logic/Seed.lua starts every seeded category
-- collapsed, UI11), so a category no window has touched yet still opens
-- collapsed everywhere, exactly as before this per-window split existed.
local function IsCollapsed(node, overrides)
	if overrides and overrides[node.id] ~= nil then
		return overrides[node.id]
	end
	return node.collapsed
end

local function SubtreeItemCount(tree, itemsByCategory, nodeId, storage)
	local total = 0
	local own = itemsByCategory[nodeId]
	if own and own[storage] then
		total = total + #own[storage]
	end
	for _, child in ipairs(Tree.GetChildren(tree, nodeId)) do
		total = total + SubtreeItemCount(tree, itemsByCategory, child.id, storage)
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

-- itemsByCategory: categoryID -> { bags = {...}, bank = {...} } (see
-- Data/Scanner.lua's `storage` field, tagged per scan). `storage`
-- (default "bags") picks which one this call renders.
--
-- Anything bucketed under a categoryID with no real tree node -- the
-- fallback for items nothing's been manually sorted into yet, or an
-- override pointing at a since-deleted category -- lists flat, with no
-- header of its own, after every real category. No "Uncategorized"
-- folder: it's just wherever the leftovers are, so there's always
-- somewhere to see and grab an unsorted item without expanding anything.
-- `collapsedOverrides` (Q53, optional -- nil means every category uses
-- its own node.collapsed default) is this storage's slice of
-- db.collapsedByStorage.
function Render.BuildRows(tree, itemsByCategory, storage, collapsedOverrides)
	storage = storage or "bags"
	local rows = {}

	local function walk(parentId, depth)
		for _, node in ipairs(Tree.GetChildren(tree, parentId)) do
			local total = SubtreeItemCount(tree, itemsByCategory, node.id, storage)
			local collapsed = IsCollapsed(node, collapsedOverrides)
			table.insert(rows, {
				kind = "header",
				categoryID = node.id,
				name = node.name,
				depth = depth,
				collapsed = collapsed,
				count = total,
			})
			if not collapsed then
				-- Sub-categories render before this category's own items,
				-- not after -- a folder's child folders read as part of
				-- its structure, above the loose items filed directly
				-- in it.
				walk(node.id, depth + 1)
				local own = itemsByCategory[node.id] or {}
				AppendItemRows(rows, own[storage] or {}, depth + 1)
			end
		end
	end

	walk(Tree.ROOT, 0)

	-- Checked against the tree directly rather than tracked during the
	-- walk above -- a collapsed category's children are never walked
	-- into, which would otherwise wrongly count them as leftovers too.
	local leftoverIDs = {}
	for categoryID in pairs(itemsByCategory) do
		if not Tree.GetNode(tree, categoryID) then
			table.insert(leftoverIDs, categoryID)
		end
	end
	table.sort(leftoverIDs) -- deterministic order

	for _, categoryID in ipairs(leftoverIDs) do
		local byStorage = itemsByCategory[categoryID]
		AppendItemRows(rows, byStorage[storage] or {}, 0)
	end

	return rows
end

local function AppendMatchingItemRows(rows, items, needle)
	for _, item in ipairs(items) do
		-- plain=true: item names can contain Lua pattern metacharacters
		-- ("%", "(", ")", ...) that would otherwise need escaping.
		if item.name and item.name:lower():find(needle, 1, true) then
			local row = {}
			for k, v in pairs(item) do
				row[k] = v
			end
			row.depth = 0
			table.insert(rows, row)
		end
	end
end

-- Live search (Q39): same category-tree traversal order as BuildRows, so
-- results don't jump around relative to the normal view, but deliberately
-- ignores collapsed state entirely -- a collapsed category's items still
-- have to be findable -- and drops all structure (headers, indentation)
-- down to a flat list of just the matching items. `storage` -- same
-- single-storage-per-call contract as BuildRows (Q43); the main window's
-- search always uses "bags", the bank drawer would use "bank" if it grows
-- its own search box later. Case-insensitive substring match on name only
-- for now (no quality/ilvl/etc filters, unlike Blizzard's own search
-- syntax).
function Render.BuildSearchRows(tree, itemsByCategory, storage, searchText)
	storage = storage or "bags"
	local needle = searchText:lower()
	local rows = {}

	local function walk(parentId)
		for _, node in ipairs(Tree.GetChildren(tree, parentId)) do
			walk(node.id)
			local own = itemsByCategory[node.id] or {}
			AppendMatchingItemRows(rows, own[storage] or {}, needle)
		end
	end

	walk(Tree.ROOT)

	-- Leftovers (an itemCategoryID with no real tree node) -- same
	-- deterministic-id-order handling as BuildRows.
	local leftoverIDs = {}
	for categoryID in pairs(itemsByCategory) do
		if not Tree.GetNode(tree, categoryID) then
			table.insert(leftoverIDs, categoryID)
		end
	end
	table.sort(leftoverIDs)

	for _, categoryID in ipairs(leftoverIDs) do
		local byStorage = itemsByCategory[categoryID]
		AppendMatchingItemRows(rows, byStorage[storage] or {}, needle)
	end

	return rows
end

if type(Folio) == "table" then
	Folio.Render = Render
end

return Render
