-- Pure validation for a single item transfer (§4.3 S5). Storage-move
-- validity only -- whether a category changed too (recategorize, R2) is
-- Core/Init.lua's concern and doesn't affect this check at all, so the
-- same validator covers both same-category and cross-category drops.
-- Stack modifiers (S6) and bulk queue/throttle (S7) are still deliberate
-- follow-ups.
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
