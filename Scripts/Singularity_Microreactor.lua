-- Singularity_Microreactor.lua
-- Radiation hazard: apply fallout to the Microreactor tile when pillaged or hit by disaster

local IMPROVEMENT_MICROREACTOR = GameInfo.Improvements["IMPROVEMENT_MICROREACTOR"]
local FEATURE_FALLOUT = GameInfo.Features["FEATURE_FALLOUT"]
local FALLOUT_DURATION = 5  -- turns before fallout is cleaned up

-- ============================================================================
-- Track fallout tiles so we can remove them after FALLOUT_DURATION turns
-- Key: "x,y" => turn number when fallout was placed
-- ============================================================================
local g_FalloutTimers = {}

-- ============================================================================
-- Apply fallout to the Microreactor tile itself
-- ============================================================================
function ApplyMicroreactorFallout(x, y)
	if FEATURE_FALLOUT == nil then return end

	local pPlot = Map.GetPlot(x, y)
	if pPlot == nil then return end
	if pPlot:IsWater() or pPlot:IsCity() then return end

	TerrainBuilder.SetFeatureType(pPlot, FEATURE_FALLOUT.Index)
	local key = x .. "," .. y
	g_FalloutTimers[key] = Game.GetCurrentGameTurn()

	print("Singularity: Microreactor fallout applied at (" .. x .. "," .. y .. ")")
end

-- ============================================================================
-- Clean up expired fallout each turn
-- ============================================================================
function OnTurnBegin_Microreactor()
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
				print("Singularity: Microreactor fallout cleared at (" .. x .. "," .. y .. ")")
			end
			g_FalloutTimers[key] = nil
		end
	end
end

-- ============================================================================
-- Listen for improvement pillage events
-- ============================================================================
function OnImprovementPillaged(playerID, plotX, plotY, improvementType)
	if IMPROVEMENT_MICROREACTOR == nil then return end
	if improvementType == IMPROVEMENT_MICROREACTOR.Index then
		print("Singularity: Microreactor pillaged at (" .. plotX .. "," .. plotY .. ")")
		ApplyMicroreactorFallout(plotX, plotY)
	end
end

-- ============================================================================
-- Listen for natural disasters hitting Microreactor tiles
-- ============================================================================
function OnRandomEventOccurred_Microreactor(eventType, severity, plotX, plotY, mitigationLevel, randomEventID, playbackEventID)
	if IMPROVEMENT_MICROREACTOR == nil then return end

	-- Check plots around the disaster epicenter for Microreactors
	local checkRadius = 3
	for dx = -checkRadius, checkRadius do
		for dy = -checkRadius, checkRadius do
			local pPlot = Map.GetPlotXYWithRangeCheck(plotX, plotY, dx, dy, checkRadius)
			if pPlot ~= nil then
				local improvementType = pPlot:GetImprovementType()
				if improvementType == IMPROVEMENT_MICROREACTOR.Index then
					-- Check if the improvement was pillaged by the event
					if pPlot:IsImprovementPillaged() then
						print("Singularity: Microreactor hit by natural disaster at (" .. pPlot:GetX() .. "," .. pPlot:GetY() .. ")")
						ApplyMicroreactorFallout(pPlot:GetX(), pPlot:GetY())
					end
				end
			end
		end
	end
end

-- ============================================================================
-- Register event listeners
-- ============================================================================
Events.ImprovementPillaged.Add(OnImprovementPillaged)
Events.TurnBegin.Add(OnTurnBegin_Microreactor)

-- RandomEventOccurred is only available with Gathering Storm
if Events.RandomEventOccurred then
	Events.RandomEventOccurred.Add(OnRandomEventOccurred_Microreactor)
end

print("Singularity: Microreactor script loaded")
