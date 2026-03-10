-- Singularity_FusionReactor.lua
-- Radiation hazard: apply fallout to surrounding tiles when pillaged or hit by disaster
-- Power: grant +10 Power to cities with a Fusion Reactor district

local DISTRICT_FUSION_REACTOR = GameInfo.Districts["DISTRICT_FUSION_REACTOR"]
local FEATURE_FALLOUT = GameInfo.Features["FEATURE_FALLOUT"]
local FALLOUT_RADIUS = 1  -- tiles around the reactor
local FALLOUT_DURATION = 5  -- turns before fallout is cleaned up

-- ============================================================================
-- Track fallout tiles so we can remove them after FALLOUT_DURATION turns
-- Key: "x,y" => turn number when fallout was placed
-- ============================================================================
local g_FalloutTimers = {}

-- ============================================================================
-- Apply fallout to tiles surrounding a Fusion Reactor at (centerX, centerY)
-- ============================================================================
function ApplyRadiationFallout(centerX, centerY)
	if FEATURE_FALLOUT == nil then return end

	local centerPlot = Map.GetPlot(centerX, centerY)
	if centerPlot == nil then return end

	local currentTurn = Game.GetCurrentGameTurn()

	-- Apply fallout to adjacent tiles within radius
	for dx = -FALLOUT_RADIUS, FALLOUT_RADIUS do
		for dy = -FALLOUT_RADIUS, FALLOUT_RADIUS do
			local pPlot = Map.GetPlotXYWithRangeCheck(centerX, centerY, dx, dy, FALLOUT_RADIUS)
			if pPlot ~= nil then
				-- Don't place fallout on water or city center tiles
				if not pPlot:IsWater() and not pPlot:IsCity() then
					local featureIndex = FEATURE_FALLOUT.Index
					TerrainBuilder.SetFeatureType(pPlot, featureIndex)
					local key = pPlot:GetX() .. "," .. pPlot:GetY()
					g_FalloutTimers[key] = currentTurn
				end
			end
		end
	end

	print("Singularity: Radiation fallout applied around (" .. centerX .. "," .. centerY .. ")")
end

-- ============================================================================
-- Clean up expired fallout each turn
-- ============================================================================
function OnTurnBegin()
	if FEATURE_FALLOUT == nil then return end

	local currentTurn = Game.GetCurrentGameTurn()

	for key, placedTurn in pairs(g_FalloutTimers) do
		if currentTurn - placedTurn >= FALLOUT_DURATION then
			local x, y = key:match("(%d+),(%d+)")
			x = tonumber(x)
			y = tonumber(y)
			local pPlot = Map.GetPlot(x, y)
			if pPlot ~= nil and pPlot:GetFeatureType() == FEATURE_FALLOUT.Index then
				TerrainBuilder.SetFeatureType(pPlot, -1)  -- remove feature
				print("Singularity: Fallout cleared at (" .. x .. "," .. y .. ")")
			end
			g_FalloutTimers[key] = nil
		end
	end
end

-- ============================================================================
-- Listen for district pillage events
-- ============================================================================
function OnDistrictPillaged(playerID, districtID, cityID, x, y, districtType, percentComplete, isPillaged)
	if DISTRICT_FUSION_REACTOR == nil then return end
	if districtType == DISTRICT_FUSION_REACTOR.Index then
		print("Singularity: Fusion Reactor pillaged at (" .. x .. "," .. y .. ")")
		ApplyRadiationFallout(x, y)
	end
end

-- ============================================================================
-- Listen for natural disasters hitting Fusion Reactor tiles
-- ============================================================================
function OnRandomEventOccurred(eventType, severity, plotX, plotY, mitigationLevel, randomEventID, playbackEventID)
	if DISTRICT_FUSION_REACTOR == nil then return end

	-- Check plots around the disaster epicenter for Fusion Reactors
	-- Disasters can affect a wide area, so check a generous radius
	local checkRadius = 3
	for dx = -checkRadius, checkRadius do
		for dy = -checkRadius, checkRadius do
			local pPlot = Map.GetPlotXYWithRangeCheck(plotX, plotY, dx, dy, checkRadius)
			if pPlot ~= nil then
				local districtType = pPlot:GetDistrictType()
				if districtType == DISTRICT_FUSION_REACTOR.Index then
					-- Check if the district was actually damaged (pillaged) by the event
					local pDistrict = CityManager.GetDistrictAt(pPlot:GetX(), pPlot:GetY())
					if pDistrict ~= nil and pDistrict:IsPillaged() then
						print("Singularity: Fusion Reactor hit by natural disaster at (" .. pPlot:GetX() .. "," .. pPlot:GetY() .. ")")
						ApplyRadiationFallout(pPlot:GetX(), pPlot:GetY())
					end
				end
			end
		end
	end
end

-- ============================================================================
-- Consume 1 Uranium per Fusion Reactor per turn
-- ============================================================================
local RESOURCE_URANIUM = GameInfo.Resources["RESOURCE_URANIUM"]

function OnPlayerTurnActivated_FusionFuel(playerID, isFirstTime)
	if not isFirstTime then return end
	if DISTRICT_FUSION_REACTOR == nil then return end
	if RESOURCE_URANIUM == nil then return end

	local pPlayer = Players[playerID]
	if pPlayer == nil or not pPlayer:IsMajor() then return end

	local uraniumIndex = RESOURCE_URANIUM.Index
	local cities = pPlayer:GetCities()
	for _, city in cities:Members() do
		local districts = city:GetDistricts()
		if districts then
			for _, district in districts:Members() do
				if district:GetType() == DISTRICT_FUSION_REACTOR.Index and not district:IsPillaged() then
					local pResources = pPlayer:GetResources()
					if pResources then
						local stock = pResources:GetResourceAmount(uraniumIndex)
						if stock > 0 then
							pResources:ChangeResourceAmount(uraniumIndex, -1)
						end
					end
				end
			end
		end
	end
end

-- ============================================================================
-- Register event listeners
-- ============================================================================
Events.PlayerTurnActivated.Add(OnPlayerTurnActivated_FusionFuel)
Events.DistrictPillaged.Add(OnDistrictPillaged)
Events.TurnBegin.Add(OnTurnBegin)

-- RandomEventOccurred is only available with Gathering Storm
if Events.RandomEventOccurred then
	Events.RandomEventOccurred.Add(OnRandomEventOccurred)
end

print("Singularity: FusionReactor script loaded")
