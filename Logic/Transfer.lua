-- Pure validation for a single item transfer (§4.3 S5). Narrowed first
-- pass: same-category subgroup-to-subgroup only -- cross-category
-- transfer+recategorize, stack modifiers (S6), and bulk queue/throttle
-- (S7) are deliberate follow-ups once this core move is proven live.
--
-- Live eligibility (soulbound vs warbound -- see Core/API.lua's
-- IsItemAllowedInBankType) and the destination slot (Core/API.lua's
-- FindEmptySlot) are computed by the caller and passed in; this module
-- only validates the structural shape of the request, so it stays pure
-- and testable without a WoW client (T1).

local Transfer = {}

-- request = { fromStorage, toStorage, eligible, destinationBag }
-- Returns ok, reason (reason only set when ok is false).
function Transfer.Validate(request)
	if request.fromStorage == request.toStorage then
		return false, "already there"
	end
	if request.eligible == false then
		return false, "not allowed in that storage"
	end
	if not request.destinationBag then
		return false, "no free slot"
	end
	return true
end

local _, Folio = ...
if type(Folio) == "table" then
	Folio.Transfer = Transfer
end

return Transfer
