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

-- Backpack + equipped bags + reagent bag. Bank/warband containers use a
-- different (and, as of Midnight, differently-indexed) scope — see F15/F16.
function API.GetBagIDs()
	local ids = {
		Enum.BagIndex.Backpack,
		Enum.BagIndex.Bag_1,
		Enum.BagIndex.Bag_2,
		Enum.BagIndex.Bag_3,
		Enum.BagIndex.Bag_4,
	}
	if Enum.BagIndex.ReagentBag then
		table.insert(ids, Enum.BagIndex.ReagentBag)
	end
	return ids
end

function API.GetItemLevel(itemLink)
	if not itemLink then return nil end
	return C_Item.GetDetailedItemLevelInfo(itemLink)
end

return API
