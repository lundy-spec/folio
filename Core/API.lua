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

-- F14/Logic/Seed.lua's rule predicates: classID/subClassID, verified
-- against Blizzard's docs (C_Item.GetItemInfoInstant returns itemID,
-- itemType, itemSubType, itemEquipLoc, icon, classID, subClassID).
function API.GetItemClassInfo(itemLink)
	if not itemLink then return nil end
	local _, _, _, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(itemLink)
	if not classID then return nil end
	return { classID = classID, subClassID = subClassID, equipLoc = equipLoc }
end

function API.GetMoney()
	return GetMoney()
end

function API.GetMoneyString(money)
	return GetMoneyString(money, true)
end

-- CUR8: the user's existing Blizzard backpack-tracked currencies.
function API.GetBackpackCurrencyInfo(index)
	return C_CurrencyInfo.GetBackpackCurrencyInfo(index)
end

function API.GetCurrencyInfo(currencyID)
	return C_CurrencyInfo.GetCurrencyInfo(currencyID)
end

-- §4.3: bank tab ids are also just bagIDs -- C_Container.GetContainerNumSlots
-- / GetContainerItemInfo work on them exactly as they do for equipped bags
-- (verified against Blizzard's docs: FetchPurchasedBankTabIDs returns
-- Enum.BagIndex[]). pcall-guarded since warband access can plausibly be
-- unavailable (e.g. no warband bank unlocked) and this must degrade to
-- "no tabs" rather than error.
local function GetPurchasedBankTabIDs(bankType)
	local ok, ids = pcall(C_Bank.FetchPurchasedBankTabIDs, bankType)
	if ok and ids then return ids end
	return {}
end

function API.GetCharacterBankTabIDs()
	return GetPurchasedBankTabIDs(Enum.BankType.Character)
end

function API.GetWarbandBankTabIDs()
	return GetPurchasedBankTabIDs(Enum.BankType.Account)
end

-- §4.3 S5: soulbound-vs-warbound eligibility via Blizzard's own check,
-- rather than reimplementing binding rules from a raw isBound flag
-- (which doesn't distinguish "never transferable" from "warbound, fine
-- for the warband bank").
function API.IsItemAllowedInBankType(bag, slot, bankType)
	local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
	if not location or not location:IsValid() then return false end
	return C_Bank.IsItemAllowedInBankType(bankType, location)
end

-- The traditional pickup/place mechanic every bag addon uses for
-- drag-and-drop -- unlike C_Container.UseContainerItem (how right-click
-- deposit works), this is NOT a protected function, so it's safe to call
-- from ordinary addon code (verified against Blizzard's docs before
-- relying on it here).
function API.PickupContainerItem(bag, slot)
	C_Container.PickupContainerItem(bag, slot)
end

-- First open slot across the given bagIDs, or nil if all are full.
-- Deliberately never targets an occupied slot -- PickupContainerItem
-- swaps into one rather than stacking, which would silently misplace
-- whatever was already there.
function API.FindEmptySlot(bagIDs)
	for _, bag in ipairs(bagIDs) do
		local numSlots = C_Container.GetContainerNumSlots(bag)
		for slot = 1, numSlots do
			if not C_Container.GetContainerItemInfo(bag, slot) then
				return bag, slot
			end
		end
	end
	return nil
end

return API
