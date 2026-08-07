-- Pure Lua category tree (T1: zero WoW API references).
--
-- tree = { nodes = { [id] = node, ... } } — fully SavedVariables-safe.
-- Each node stores its own `parent` id; children are derived by filtering
-- rather than duplicated in a nested array, so there is exactly one source
-- of truth for structure. A literal nested `children` array would drift
-- out of sync with `parent` — that's the "subtle corruption" §7 warns
-- nesting logic is prone to.
--
-- node = {
--   id, name, parent (id or Tree.ROOT), order,
--   collapsed = false,
--   rules = {},
--   storages = { bags = true, bank = true, warband = true },      -- F18
--   subCollapsed = { bags = false, bank = false, warband = false }, -- S4
-- }
--
-- Ids are supplied by the caller (not generated here) so this module has
-- no hidden randomness or clock dependency — see T3.

local Tree = {}

local ROOT = "root"
Tree.ROOT = ROOT

local function defaultStorages()
	return { bags = true, bank = true, warband = true }
end

local function defaultSubCollapsed()
	return { bags = false, bank = false, warband = false }
end

function Tree.New()
	return { nodes = {} }
end

local function nextOrder(tree, parent)
	local max = 0
	for _, node in pairs(tree.nodes) do
		if node.parent == parent and node.order > max then
			max = node.order
		end
	end
	return max + 1
end

function Tree.AddNode(tree, id, opts)
	if id == nil or id == ROOT then
		return nil, "invalid id"
	end
	if tree.nodes[id] then
		return nil, "id already exists"
	end
	opts = opts or {}
	local parent = opts.parent or ROOT
	if parent ~= ROOT and not tree.nodes[parent] then
		return nil, "parent does not exist"
	end

	local node = {
		id = id,
		name = opts.name or id,
		parent = parent,
		order = opts.order or nextOrder(tree, parent),
		collapsed = opts.collapsed or false,
		rules = opts.rules or {},
		storages = opts.storages or defaultStorages(),
		subCollapsed = opts.subCollapsed or defaultSubCollapsed(),
	}
	tree.nodes[id] = node
	return node
end

function Tree.GetNode(tree, id)
	if id == ROOT then return nil end
	return tree.nodes[id]
end

function Tree.GetChildren(tree, parentId)
	parentId = parentId or ROOT
	local children = {}
	for _, node in pairs(tree.nodes) do
		if node.parent == parentId then
			table.insert(children, node)
		end
	end
	table.sort(children, function(a, b)
		if a.order == b.order then return a.id < b.id end
		return a.order < b.order
	end)
	return children
end

function Tree.RenameNode(tree, id, newName)
	local node = tree.nodes[id]
	if not node then return nil, "not found" end
	node.name = newName
	return true
end

local function collectDescendants(tree, id, out)
	out = out or {}
	for _, node in pairs(tree.nodes) do
		if node.parent == id then
			table.insert(out, node.id)
			collectDescendants(tree, node.id, out)
		end
	end
	return out
end

-- Is `id` a descendant of `ancestorId`?
function Tree.IsDescendantOf(tree, id, ancestorId)
	local node = tree.nodes[id]
	while node do
		if node.parent == ancestorId then return true end
		if node.parent == ROOT then return false end
		node = tree.nodes[node.parent]
	end
	return false
end

-- Cascading delete — removing a category removes its whole subtree,
-- mirroring the filesystem metaphor. Returns the ids removed (id first).
function Tree.RemoveNode(tree, id)
	if not tree.nodes[id] then return nil, "not found" end
	local descendants = collectDescendants(tree, id)
	for _, descId in ipairs(descendants) do
		tree.nodes[descId] = nil
	end
	tree.nodes[id] = nil
	table.insert(descendants, 1, id)
	return descendants
end

function Tree.MoveNode(tree, id, newParent, newOrder)
	local node = tree.nodes[id]
	if not node then return nil, "not found" end
	newParent = newParent or ROOT
	if newParent ~= ROOT then
		if not tree.nodes[newParent] then return nil, "parent does not exist" end
		if newParent == id or Tree.IsDescendantOf(tree, newParent, id) then
			return nil, "would create a cycle"
		end
	end
	node.parent = newParent
	node.order = newOrder or nextOrder(tree, newParent)
	return true
end

function Tree.ReorderChildren(tree, parentId, orderedIds)
	parentId = parentId or ROOT
	local current = Tree.GetChildren(tree, parentId)
	if #current ~= #orderedIds then
		return nil, "orderedIds does not match current children"
	end
	local currentSet = {}
	for _, node in ipairs(current) do
		currentSet[node.id] = true
	end
	local seen = {}
	for _, id in ipairs(orderedIds) do
		if not currentSet[id] or seen[id] then
			return nil, "orderedIds does not match current children"
		end
		seen[id] = true
	end
	for index, id in ipairs(orderedIds) do
		tree.nodes[id].order = index
	end
	return true
end

-- Root-to-node id chain, inclusive of `id`, exclusive of the implicit root.
function Tree.GetPath(tree, id)
	local node = tree.nodes[id]
	if not node then return nil end
	local path = { id }
	while node.parent ~= ROOT do
		table.insert(path, 1, node.parent)
		node = tree.nodes[node.parent]
		if not node then return nil end
	end
	return path
end

-- Depth-first pre-order traversal, respecting sibling order.
function Tree.Walk(tree, parentId, fn, depth)
	parentId = parentId or ROOT
	depth = depth or 0
	for _, node in ipairs(Tree.GetChildren(tree, parentId)) do
		fn(node, depth)
		Tree.Walk(tree, node.id, fn, depth + 1)
	end
end

return Tree
