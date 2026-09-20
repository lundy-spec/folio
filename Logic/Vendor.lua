-- Pure profit calculation for auto-selling junk to a vendor (T1). Item
-- shape and the actual sell call are Core/Init.lua's concern (T2) --
-- this only totals up what a batch of sales is worth.

local Vendor = {}

-- items: array of { sellPrice, count }. A stack sells for its full count
-- at once (how vendor-selling has always worked), so total value is
-- sellPrice * count, summed across every item.
function Vendor.CalculateProfit(items)
	local total = 0
	for _, item in ipairs(items) do
		total = total + (item.sellPrice or 0) * (item.count or 1)
	end
	return total
end

local _, Folio = ...
if type(Folio) == "table" then
	Folio.Vendor = Vendor
end

return Vendor
