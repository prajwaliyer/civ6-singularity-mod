-- Singularity_DataCenter.lua
-- Notifies the player when Data Centers are offline due to empty GPU/DRAM stockpile.
-- GPU/DRAM consumption and yield gating are handled by XML modifiers:
--   - Each Data Center reduces GPU extraction by 1/turn and DRAM extraction by 1/turn
--   - Yields are gated by REQUIREMENT_PLAYER_HAS_RESOURCE_OWNED (GPU + DRAM)

local DISTRICT_DATA_CENTER = GameInfo.Districts["DISTRICT_DATA_CENTER"]
local RESOURCE_GPU         = GameInfo.Resources["RESOURCE_GPU"]
local RESOURCE_DRAM        = GameInfo.Resources["RESOURCE_DRAM"]

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
	if DISTRICT_DATA_CENTER == nil then return end

	local pPlayer = Players[playerID]
	if pPlayer == nil or not pPlayer:IsMajor() then return end

	-- Find a city with a Data Center
	local dcCity = FindFirstDataCenterCity(playerID)
	if dcCity == nil then return end -- No Data Centers, nothing to warn about

	-- Check if player has GPUs and DRAM in stockpile
	local pResources = pPlayer:GetResources()
	local gpuCount = RESOURCE_GPU and pResources:GetResourceAmount(RESOURCE_GPU.Index) or 0
	local dramCount = RESOURCE_DRAM and pResources:GetResourceAmount(RESOURCE_DRAM.Index) or 0
	if gpuCount > 0 and dramCount > 0 then return end -- Resources available, Data Centers are fine

	-- Player has Data Centers but no GPUs or DRAM — notify
	pcall(function()
		if NotificationManager and NotificationTypes then
			NotificationManager.SendNotification(
				playerID,
				NotificationTypes.DEFAULT,
				"LOC_NOTIFICATION_DATA_CENTER_OFFLINE_TITLE",
				"LOC_NOTIFICATION_DATA_CENTER_OFFLINE_BODY",
				dcCity:GetX(),
				dcCity:GetY()
			)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- When a Data Center district is completed, attach -10 Power to the city.
-- Each instance stacks, so 3 Data Centers = -30 Power.
-- ---------------------------------------------------------------------------
function OnDistrictBuildComplete(playerID, districtID, cityID, districtX, districtY, districtType, percentComplete)
	if DISTRICT_DATA_CENTER == nil then return end
	if districtType ~= DISTRICT_DATA_CENTER.Index then return end
	if percentComplete ~= 100 then return end

	local pPlayer = Players[playerID]
	if pPlayer == nil then return end
	local city = pPlayer:GetCities():FindID(cityID)
	if city == nil then return end

	city:AttachModifierByID("DATA_CENTER_CONSUME_POWER")
	print("Singularity: Attached DATA_CENTER_CONSUME_POWER to city " .. city:GetName())
end

Events.DistrictBuildProgressChanged.Add(OnDistrictBuildComplete)
Events.PlayerTurnActivated.Add(OnPlayerTurnActivated_DataCenterCheck)
print("Singularity: DataCenter module loaded")
