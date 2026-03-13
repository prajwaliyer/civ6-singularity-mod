-- Singularity_InorganicLife.lua
-- Receives power surplus and growth threshold from UI script via ExposedMembers.
-- Handles accumulation and ChangePopulation (gameplay-only APIs).

local PROJECT_INORGANIC  = nil
local BUILDING_INORGANIC = nil

function Initialize()
	local projInfo = GameInfo.Projects["PROJECT_CONVERT_INORGANIC_LIFE"]
	if projInfo then
		PROJECT_INORGANIC = projInfo.Index
	end

	local bldgInfo = GameInfo.Buildings["BUILDING_INORGANIC_CITY"]
	if bldgInfo then
		BUILDING_INORGANIC = bldgInfo.Index
	end
end

-- ---------------------------------------------------------------------------
-- Read power surplus from ExposedMembers (written by UI script)
-- ---------------------------------------------------------------------------
function GetCityPowerSurplus(cityID)
	if ExposedMembers and ExposedMembers.SingularityPower then
		return ExposedMembers.SingularityPower[cityID] or 0
	end
	return 0
end

function GetCityGrowthThreshold(cityID)
	if ExposedMembers and ExposedMembers.SingularityThreshold then
		return ExposedMembers.SingularityThreshold[cityID] or 0
	end
	return 0
end

-- ---------------------------------------------------------------------------
-- Project completion: mark city as converted
-- ---------------------------------------------------------------------------
function OnCityProjectCompleted(playerID, cityID, projectID)
	if PROJECT_INORGANIC == nil then return end
	if projectID ~= PROJECT_INORGANIC then return end

	local pPlayer = Players[playerID]
	if pPlayer == nil then return end

	local city = pPlayer:GetCities():FindID(cityID)
	if city == nil then return end

	-- Already converted — no effect
	if city:GetProperty("INORGANIC_LIFE") == 1 then return end
	if BUILDING_INORGANIC ~= nil then
		local pB = city:GetBuildings()
		if pB and pB:HasBuilding(BUILDING_INORGANIC) then return end
	end

	city:SetProperty("INORGANIC_LIFE", 1)
	city:SetProperty("POWER_GROWTH", 0)
end

-- ---------------------------------------------------------------------------
-- Per-turn: accumulate power and apply population changes
-- ---------------------------------------------------------------------------
function OnPlayerTurnActivated(playerID, isFirstTime)
	if not isFirstTime then return end

	local pPlayer = Players[playerID]
	if pPlayer == nil or not pPlayer:IsMajor() then return end

	local cities = pPlayer:GetCities()
	for _, city in cities:Members() do
		if city:GetProperty("INORGANIC_LIFE") == 1 then
			local cityID = city:GetID()
			local powerSurplus = GetCityPowerSurplus(cityID)
			local threshold = GetCityGrowthThreshold(cityID)
			local accumulated = city:GetProperty("POWER_GROWTH") or 0
			local currentPop = city:GetPopulation()
			if powerSurplus < 0 then
				-- Deficit: immediately lose 1 pop per turn, reset accumulator
				if currentPop > 1 then
					city:ChangePopulation(-1)
				end
				accumulated = 0
			else
				-- Surplus: accumulate toward next pop
				accumulated = accumulated + powerSurplus
				if accumulated >= threshold and threshold > 0 then
					city:ChangePopulation(1)
					accumulated = accumulated - threshold
				end
			end

			city:SetProperty("POWER_GROWTH", accumulated)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Bootstrap
-- ---------------------------------------------------------------------------
Initialize()
Events.CityProjectCompleted.Add(OnCityProjectCompleted)
Events.PlayerTurnActivated.Add(OnPlayerTurnActivated)
print("Singularity: InorganicLife gameplay loaded (v4 - LuaEvents)")
