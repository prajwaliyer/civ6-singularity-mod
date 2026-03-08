-- Singularity_Chips.lua
-- Chips are a strategic resource produced by Chip Fab buildings.
-- Accumulation is handled by building modifiers (MODIFIER_PLAYER_ADJUST_FREE_RESOURCE_EXTRACTION).
-- This script notifies the player when Chip Fabs are idle due to lack of improved Silicon.

local BUILDING_CHIP_FAB          = GameInfo.Buildings["BUILDING_CHIP_FAB"]
local BUILDING_ADVANCED_CHIP_FAB = GameInfo.Buildings["BUILDING_ADVANCED_CHIP_FAB"]
local BUILDING_EXPERT_CHIP_FAB   = GameInfo.Buildings["BUILDING_EXPERT_CHIP_FAB"]
local RESOURCE_SILICON           = GameInfo.Resources["RESOURCE_SILICON"]

-- Check if a player has any improved Silicon tile
function PlayerHasImprovedSilicon(playerID)
	if RESOURCE_SILICON == nil then return false end
	local pPlayer = Players[playerID]
	if pPlayer == nil then return false end

	-- Iterate all cities and their owned plots
	local pCities = pPlayer:GetCities()
	for i, pCity in pCities:Members() do
		local pCityPlots = Map.GetCityPlots():GetPurchasedPlots(pCity)
		if pCityPlots then
			for _, plotID in ipairs(pCityPlots) do
				local pPlot = Map.GetPlotByIndex(plotID)
				if pPlot and pPlot:GetResourceType() == RESOURCE_SILICON.Index then
					if pPlot:IsResourceImproved() then
						return true
					end
				end
			end
		end
	end
	return false
end

-- Check if a player has any Chip Fab building, return the first city that has one
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

function OnPlayerTurnActivated_ChipCheck(playerID, isFirstTime)
	if not isFirstTime then return end
	if BUILDING_CHIP_FAB == nil or RESOURCE_SILICON == nil then return end

	local pPlayer = Players[playerID]
	if pPlayer == nil or not pPlayer:IsMajor() then return end

	-- Find a city with a Chip Fab
	local chipFabCity = FindFirstChipFabCity(playerID)
	if chipFabCity == nil then return end -- No Chip Fabs, nothing to warn about

	-- Check if player has improved Silicon
	if PlayerHasImprovedSilicon(playerID) then return end -- Silicon is fine

	-- Player has Chip Fabs but no improved Silicon — notify
	NotificationManager.SendNotification(
		playerID,
		NotificationTypes.DEFAULT,
		"LOC_NOTIFICATION_CHIP_FAB_IDLE_TITLE",
		"LOC_NOTIFICATION_CHIP_FAB_IDLE_BODY",
		chipFabCity:GetX(),
		chipFabCity:GetY()
	)
end

Events.PlayerTurnActivated.Add(OnPlayerTurnActivated_ChipCheck)
print("Singularity: Chips module loaded")
