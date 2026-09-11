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

-- Which expansion introduced this item (Enum.ExpansionLevel, e.g. 9 =
-- Dragonflight, 11 = Midnight). C_Item.GetItemInfo can return incomplete
-- data on an item the client hasn't cached yet, hence nilable.
-- pcall-guarded (confirmed live: something in this call chain threw for
-- some equipped-gear item links, silently aborting that item's whole
-- Scanner.lua entry -- name and all -- before this was wrapped).
function API.GetItemExpansion(itemLink)
	if not itemLink then return nil end
	local ok, expansionID = pcall(function()
		return select(15, C_Item.GetItemInfo(itemLink))
	end)
	if ok then return expansionID end
	return nil
end

-- Trade Goods/reagent crafting quality (Bronze/Silver/Gold pre-Midnight,
-- Silver/Gold from Midnight on -- distinct from item rarity, already
-- conveyed via ITEM_QUALITY_COLORS name coloring in UI/Row.lua). Most
-- items don't have one at all, hence nilable per Blizzard's own
-- generated API docs. pcall-guarded for the same reason as
-- GetItemExpansion above.
function API.GetCraftingQuality(itemLink)
	if not itemLink then return nil end
	local ok, quality = pcall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, itemLink)
	if ok then return quality end
	return nil
end

-- The actual small icon atlas Blizzard's own tooltip uses for this
-- specific item's quality tier -- read dynamically rather than
-- hardcoded, since the exact atlas name (and even the visual convention
-- it represents -- stacked pips pre-Midnight, a single diamond/pentagon
-- shape from Midnight on) varies by which expansion introduced the
-- reagent, and this API already returns whichever one is correct for
-- that specific item. pcall-guarded for the same reason as
-- GetItemExpansion above.
function API.GetCraftingQualityIcon(itemLink)
	if not itemLink then return nil end
	local ok, info = pcall(C_TradeSkillUI.GetItemReagentQualityInfo, itemLink)
	return ok and info and info.iconSmall or nil
end

-- Q42: a character can only ever carry ONE Mythic Keystone (item 180653)
-- at a time -- upgrading/downgrading replaces it in place -- so there's
-- nothing to decode per-item-instance; the OWNED keystone API always
-- describes whichever single one is currently in bags. nil/nil if the
-- player doesn't currently have one, or the level is somehow 0
-- (shouldn't happen for an item that exists at all, but a bare 0 isn't a
-- real key). pcall-guarded for the same reason as GetItemExpansion above
-- -- confirmed-live API, but a fresh keystone right after receiving one
-- could plausibly still be resolving.
function API.GetOwnedKeystoneInfo()
	local ok, mapID, level = pcall(function()
		return C_MythicPlus.GetOwnedKeystoneChallengeMapID(), C_MythicPlus.GetOwnedKeystoneLevel()
	end)
	if not ok or not mapID or not level or level <= 0 then
		return nil, nil
	end
	local nameOk, name = pcall(C_ChallengeMode.GetMapUIInfo, mapID)
	if not nameOk then
		return nil, nil
	end
	return name, level
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
