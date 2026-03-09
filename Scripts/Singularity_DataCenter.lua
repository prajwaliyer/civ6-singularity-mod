-- Singularity_DataCenter.lua
-- Notifies the player when Data Centers are offline due to empty Chip stockpile.
-- Chip consumption and yield gating are handled by XML modifiers:
--   - Each Data Center reduces Chip extraction by 1/turn
--   - Yields are gated by REQUIREMENT_PLAYER_HAS_RESOURCE_OWNED (Chips)

local DISTRICT_DATA_CENTER = GameInfo.Districts["DISTRICT_DATA_CENTER"]
local RESOURCE_CHIPS       = GameInfo.Resources["RESOURCE_CHIPS"]

-- Check if a player has any Data Center district
function FindFirstDataCenterCity(playerID)
	if DISTRICT_DATA_CENTER == nil then return nil end
	local pPlayer = Players[playerID]
	if pPlayer == nil then return nil end

	local pCities = pPlayer:GetCities()
	for i, pCity in pCities:Members() do
		local pDistricts = pCity:GetDistricts()
		for j = 0, pDistricts:GetNumDistricts() - 1 do
			local districtType = pDistricts:GetDistrictTypeAtIndex(j)
			if districtType == DISTRICT_DATA_CENTER.Index then
				return pCity
			end
		end
	end
	return nil
end

function OnPlayerTurnActivated_DataCenterCheck(playerID, isFirstTime)
	if not isFirstTime then return end
	if DISTRICT_DATA_CENTER == nil or RESOURCE_CHIPS == nil then return end

	local pPlayer = Players[playerID]
	if pPlayer == nil or not pPlayer:IsMajor() then return end

	-- Find a city with a Data Center
	local dcCity = FindFirstDataCenterCity(playerID)
	if dcCity == nil then return end -- No Data Centers, nothing to warn about

	-- Check if player has Chips in stockpile
	local pResources = pPlayer:GetResources()
	local chipCount = pResources:GetResourceAmount(RESOURCE_CHIPS.Index)
	if chipCount > 0 then return end -- Chips available, Data Centers are fine

	-- Player has Data Centers but no Chips — notify
	NotificationManager.SendNotification(
		playerID,
		NotificationTypes.DEFAULT,
		"LOC_NOTIFICATION_DATA_CENTER_OFFLINE_TITLE",
		"LOC_NOTIFICATION_DATA_CENTER_OFFLINE_BODY",
		dcCity:GetX(),
		dcCity:GetY()
	)
end

Events.PlayerTurnActivated.Add(OnPlayerTurnActivated_DataCenterCheck)
print("Singularity: DataCenter module loaded")
