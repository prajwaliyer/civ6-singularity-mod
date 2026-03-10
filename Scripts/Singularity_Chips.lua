-- Singularity_Chips.lua
-- Chip Fabs consume Silicon and produce Chips each turn.
-- XML modifiers handle chip production display (+chips/turn).
-- XML modifiers show silicon consumption in extraction rate (for UI).
-- This script:
--   1. Actually consumes silicon from stockpile each turn
--   2. Guards against zero-silicon (undoes XML chip production)
--   3. Stores consumption rates as player properties for UI tooltip

local BUILDING_CHIP_FAB          = GameInfo.Buildings["BUILDING_CHIP_FAB"]
local BUILDING_ADVANCED_CHIP_FAB = GameInfo.Buildings["BUILDING_ADVANCED_CHIP_FAB"]
local BUILDING_EXPERT_CHIP_FAB   = GameInfo.Buildings["BUILDING_EXPERT_CHIP_FAB"]
local RESOURCE_SILICON           = GameInfo.Resources["RESOURCE_SILICON"]
local RESOURCE_CHIPS             = GameInfo.Resources["RESOURCE_CHIPS"]

-- Calculate total chip production and silicon cost across all cities
function GetChipFabTotals(playerID)
	local pPlayer = Players[playerID]
	if pPlayer == nil then return 0, 0 end

	local totalChips = 0
	local totalSiliconCost = 0

	local pCities = pPlayer:GetCities()
	for i, pCity in pCities:Members() do
		local pBuildings = pCity:GetBuildings()
		if pBuildings:HasBuilding(BUILDING_CHIP_FAB.Index) then
			totalChips = totalChips + 1
			totalSiliconCost = totalSiliconCost + 1
		end
		if pBuildings:HasBuilding(BUILDING_ADVANCED_CHIP_FAB.Index) then
			totalChips = totalChips + 2
			totalSiliconCost = totalSiliconCost + 2
		end
		if pBuildings:HasBuilding(BUILDING_EXPERT_CHIP_FAB.Index) then
			totalChips = totalChips + 2
			totalSiliconCost = totalSiliconCost + 2
		end
	end

	return totalChips, totalSiliconCost
end

function OnPlayerTurnActivated_ChipProduction(playerID, isFirstTime)
	if not isFirstTime then return end
	if RESOURCE_SILICON == nil or RESOURCE_CHIPS == nil then return end
	if BUILDING_CHIP_FAB == nil then return end

	local pPlayer = Players[playerID]
	if pPlayer == nil or not pPlayer:IsMajor() then return end

	local totalChips, totalSiliconCost = GetChipFabTotals(playerID)

	if totalChips == 0 then
		pPlayer:SetProperty("SINGULARITY_SILICON_CONSUMPTION", 0)
		pPlayer:SetProperty("SINGULARITY_CHIPS_BLOCKED", 0)
		return
	end

	local pResources = pPlayer:GetResources()
	local siliconStockpile = pResources:GetResourceAmount(RESOURCE_SILICON.Index)

	if siliconStockpile <= 0 then
		-- No silicon: undo the chips that XML produced, mark all blocked
		pResources:ChangeResourceAmount(RESOURCE_CHIPS.Index, -totalChips)
		pPlayer:SetProperty("SINGULARITY_SILICON_CONSUMPTION", 0)
		pPlayer:SetProperty("SINGULARITY_CHIPS_BLOCKED", totalChips)

		-- Notify player
		pcall(function()
			if NotificationManager and NotificationTypes then
				local chipFabCity = FindFirstChipFabCity(playerID)
				if chipFabCity then
					NotificationManager.SendNotification(
						playerID,
						NotificationTypes.DEFAULT,
						"Chip Fabs Idle",
						"Your Chip Fabs have stopped production — no Silicon available.",
						chipFabCity:GetX(),
						chipFabCity:GetY()
					)
				end
			end
		end)
		return
	end

	-- Have silicon: consume it
	local siliconToConsume = math.min(totalSiliconCost, siliconStockpile)
	pResources:ChangeResourceAmount(RESOURCE_SILICON.Index, -siliconToConsume)

	-- If not enough silicon for full production, scale back chips
	local chipsBlocked = 0
	if siliconToConsume < totalSiliconCost then
		chipsBlocked = totalChips - math.floor(totalChips * (siliconToConsume / totalSiliconCost))
		if chipsBlocked > 0 then
			pResources:ChangeResourceAmount(RESOURCE_CHIPS.Index, -chipsBlocked)
		end
	end

	pPlayer:SetProperty("SINGULARITY_SILICON_CONSUMPTION", siliconToConsume)
	pPlayer:SetProperty("SINGULARITY_CHIPS_BLOCKED", chipsBlocked)
end

function FindFirstChipFabCity(playerID)
	local pPlayer = Players[playerID]
	if pPlayer == nil then return nil end
	local pCities = pPlayer:GetCities()
	for i, pCity in pCities:Members() do
		local pBuildings = pCity:GetBuildings()
		if pBuildings:HasBuilding(BUILDING_CHIP_FAB.Index) or
		   pBuildings:HasBuilding(BUILDING_ADVANCED_CHIP_FAB.Index) or
		   pBuildings:HasBuilding(BUILDING_EXPERT_CHIP_FAB.Index) then
			return pCity
		end
	end
	return nil
end

Events.PlayerTurnActivated.Add(OnPlayerTurnActivated_ChipProduction)
print("Singularity: Chips module loaded")
