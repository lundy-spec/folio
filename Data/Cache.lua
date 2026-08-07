-- In-memory current-character state (§5). Not persisted directly — Store.lua
-- (later) owns what actually lands in SavedVariables.

local Cache = {}

local state = { items = {} }

function Cache.SetItems(items)
	state.items = items
end

function Cache.GetItems()
	return state.items
end

function Cache.Clear()
	state.items = {}
end

local _, Folio = ...
if type(Folio) == "table" then
	Folio.Data = Folio.Data or {}
	Folio.Data.Cache = Cache
end

return Cache
