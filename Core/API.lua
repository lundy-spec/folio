local _, Folio = ...

-- The only file in this addon allowed to reference WoW globals (T2).
-- Every function here returns a plain table/value — never a WoW userdata —
-- so Logic/ and Data/ can be tested against a fake of this module.
local API = {}
Folio.API = API

function API.GetContainerNumSlots(bag)
	return C_Container.GetContainerNumSlots(bag)
end

function API.GetContainerItemInfo(bag, slot)
	return C_Container.GetContainerItemInfo(bag, slot)
end

return API
