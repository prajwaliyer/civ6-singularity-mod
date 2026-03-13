-- InorganicLifeUI.lua
-- Calculates power surplus (UI-only API) and sends it to gameplay via LuaEvents.
-- Handles overlay display. Accumulation is tracked in a local Lua table for
-- display purposes (gameplay script does the authoritative accumulation).

ContextPtr:SetHide(false)

local m_Panel             = Controls.InorganicGrowthPanel
local m_TitleLabel        = Controls.TitleLabel
local m_PowerSurplusLabel = Controls.PowerSurplusLabel
local m_GrowthProgress    = Controls.GrowthProgressLabel
local m_TurnsToGrowth     = Controls.TurnsToGrowthLabel
local m_DebugLabel1       = Controls.DebugLabel1
local m_DebugLabel2       = Controls.DebugLabel2


-- ---------------------------------------------------------------------------
-- Power surplus calculation (UI context only)
-- ---------------------------------------------------------------------------
local POWER_PER_CITIZEN = 2

function GetCityPowerSurplus(city)
	local pPower = city:GetPower()
	if pPower == nil then return 0 end

	local free = pPower:GetFreePower() or 0
	local temp = pPower:GetTemporaryPower() or 0

	local generated = 0
	local sources = pPower:GetGeneratedPowerSources()
	if sources then
		for _, src in ipairs(sources) do
			generated = generated + (src.Amount or 0)
		end
	end

	local totalSupply = free + temp + generated
	local required    = pPower:GetRequiredPower() or 0
	local popConsumption = city:GetPopulation() * POWER_PER_CITIZEN
	return totalSupply - required - popConsumption
end

-- ---------------------------------------------------------------------------
-- Send power surplus data to gameplay script via LuaEvents.
-- Also update local accumulation table for overlay display.
-- ---------------------------------------------------------------------------
function SendPowerDataToGameplay()
	local localPlayerID = Game.GetLocalPlayer()
	if localPlayerID == nil or localPlayerID == -1 then return end
	local pPlayer = Players[localPlayerID]
	if pPlayer == nil then return end

	local cities = pPlayer:GetCities()
	for _, city in cities:Members() do
		if city:GetProperty("INORGANIC_LIFE") == 1 then
			local cityID       = city:GetID()
			local powerSurplus = GetCityPowerSurplus(city)

			-- Send to gameplay script via ExposedMembers (shared global table)
			local growth = city:GetGrowth()
			local threshold = 0
			if growth then
				threshold = growth:GetGrowthThreshold()
			end
			if ExposedMembers then
				if not ExposedMembers.SingularityPower then
					ExposedMembers.SingularityPower = {}
				end
				if not ExposedMembers.SingularityThreshold then
					ExposedMembers.SingularityThreshold = {}
				end
				ExposedMembers.SingularityPower[cityID] = powerSurplus
				ExposedMembers.SingularityThreshold[cityID] = threshold
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Refresh the overlay panel for the currently selected city
-- ---------------------------------------------------------------------------
function RefreshPanel()
	local selectedCity = UI.GetHeadSelectedCity()
	if selectedCity == nil then
		m_Panel:SetHide(true)
		return
	end

	if selectedCity:GetProperty("INORGANIC_LIFE") ~= 1 then
		m_Panel:SetHide(true)
		return
	end

	local growth = selectedCity:GetGrowth()
	if growth == nil then
		m_Panel:SetHide(true)
		return
	end

	local pop          = selectedCity:GetPopulation()
	local powerSurplus = GetCityPowerSurplus(selectedCity)
	local cityID       = selectedCity:GetID()
	local accumulated  = selectedCity:GetProperty("POWER_GROWTH") or 0
	local threshold    = growth:GetGrowthThreshold()

	-- Line 1: Population
	m_TitleLabel:SetText("[ICON_Citizen] Population: " .. pop)

	-- Line 2: Turns until growth/decline
	if powerSurplus > 0 then
		local remaining = threshold - accumulated
		if remaining <= 0 then
			m_TurnsToGrowth:SetText("1 turn until growth")
		else
			local turns = math.ceil(remaining / powerSurplus)
			m_TurnsToGrowth:SetText(turns .. " turns until growth")
		end
	elseif powerSurplus < 0 then
		local remaining = accumulated + threshold
		if remaining <= 0 then
			m_TurnsToGrowth:SetText("[COLOR_RED]Population is declining[ENDCOLOR]")
		else
			local turns = math.ceil(remaining / math.abs(powerSurplus))
			m_TurnsToGrowth:SetText("[COLOR_RED]" .. turns .. " turns until decline[ENDCOLOR]")
		end
	else
		m_TurnsToGrowth:SetText("Growth stalled")
	end

	-- Line 3: Surplus power
	if powerSurplus > 0 then
		m_PowerSurplusLabel:SetText("[COLOR_GREEN]+" .. powerSurplus .. "[ENDCOLOR] surplus [ICON_POWER] Power")
	elseif powerSurplus < 0 then
		m_PowerSurplusLabel:SetText("[COLOR_RED]" .. powerSurplus .. "[ENDCOLOR] deficit [ICON_POWER] Power")
	else
		m_PowerSurplusLabel:SetText("0 surplus [ICON_POWER] Power")
	end

	-- Line 4: Growth progress bar
	m_GrowthProgress:SetText("[ICON_POWER] " .. accumulated .. " / " .. threshold)

	-- Debug: raw power breakdown
	local pPower = selectedCity:GetPower()
	if pPower then
		local free = pPower:GetFreePower() or 0
		local temp = pPower:GetTemporaryPower() or 0
		local generated = 0
		local srcCount = 0
		local sources = pPower:GetGeneratedPowerSources()
		if sources then
			for _, src in ipairs(sources) do
				generated = generated + (src.Amount or 0)
				srcCount = srcCount + 1
			end
		end
		local required = pPower:GetRequiredPower() or 0
		local popCost = pop * POWER_PER_CITIZEN
		m_DebugLabel1:SetText("free=" .. free .. " temp=" .. temp .. " gen=" .. generated)
		m_DebugLabel2:SetText("req=" .. required .. " popCost=" .. popCost .. " net=" .. (free+temp+generated-required-popCost))
	else
		m_DebugLabel1:SetText("pPower=nil")
		m_DebugLabel2:SetText("")
	end

	m_Panel:SetHide(false)
end

-- ---------------------------------------------------------------------------
-- Event hooks
-- ---------------------------------------------------------------------------
function OnCitySelectionChanged(playerID, cityID, i, j, k, isSelected)
	RefreshPanel()
end

function OnCityWorkerChanged(playerID, cityID)
	local selectedCity = UI.GetHeadSelectedCity()
	if selectedCity and selectedCity:GetID() == cityID then
		RefreshPanel()
	end
end

function OnTurnBegin()
	SendPowerDataToGameplay()
	RefreshPanel()
end

function OnLocalPlayerTurnEnd()
	-- Only send data, don't accumulate display (TurnBegin handles that)
	local localPlayerID = Game.GetLocalPlayer()
	if localPlayerID == nil or localPlayerID == -1 then return end
	local pPlayer = Players[localPlayerID]
	if pPlayer == nil then return end

	local cities = pPlayer:GetCities()
	for _, city in cities:Members() do
		if city:GetProperty("INORGANIC_LIFE") == 1 then
			local cityID = city:GetID()
			local powerSurplus = GetCityPowerSurplus(city)
			local growth = city:GetGrowth()
			local threshold = 0
			if growth then
				threshold = growth:GetGrowthThreshold()
			end
			if ExposedMembers then
				if not ExposedMembers.SingularityPower then
					ExposedMembers.SingularityPower = {}
				end
				if not ExposedMembers.SingularityThreshold then
					ExposedMembers.SingularityThreshold = {}
				end
				ExposedMembers.SingularityPower[cityID] = powerSurplus
				ExposedMembers.SingularityThreshold[cityID] = threshold
			end
		end
	end
end

Events.CitySelectionChanged.Add(OnCitySelectionChanged)
Events.CityWorkerChanged.Add(OnCityWorkerChanged)
Events.TurnBegin.Add(OnTurnBegin)

if Events.LocalPlayerTurnEnd then
	Events.LocalPlayerTurnEnd.Add(OnLocalPlayerTurnEnd)
end

-- ---------------------------------------------------------------------------
-- ART DEBUG: Always-visible panel to diagnose district rendering
-- ---------------------------------------------------------------------------
local dbgLines = {}
for i = 1, 10 do
	dbgLines[i] = Controls["ArtDebugLine" .. i]
end

function ClearDebugLines()
	for i = 1, 10 do
		dbgLines[i]:SetText("")
	end
end

function SetDebugLine(n, text)
	if dbgLines[n] then
		dbgLines[n]:SetText(text)
	end
end

function RefreshArtDebug()
	ClearDebugLines()

	local ok, err = pcall(function()
		local localPlayerID = Game.GetLocalPlayer()
		if localPlayerID == nil or localPlayerID == -1 then
			SetDebugLine(1, "No local player")
			return
		end

		-- Check GameInfo
		local dcInfo = GameInfo.Districts["DISTRICT_DATA_CENTER"]
		if dcInfo then
			SetDebugLine(1, "GameInfo: DC Index=" .. dcInfo.Index .. " player=" .. localPlayerID)
		else
			SetDebugLine(1, "[COLOR_RED]DC NOT IN GAMEINFO[ENDCOLOR]")
			return
		end

		local pPlayer = Players[localPlayerID]
		if pPlayer == nil then
			SetDebugLine(2, "Player nil")
			return
		end

		local cities = pPlayer:GetCities()
		if cities == nil then
			SetDebugLine(2, "Cities nil")
			return
		end

		local cityCount = 0
		local dcCount = 0
		local line = 2

		for _, city in cities:Members() do
			cityCount = cityCount + 1
			local cityName = city:GetName() or "?"

			-- Check if this city has a DC by looking at the plot for each known district type
			local pDistricts = city:GetDistricts()
			local hasDC = false
			if pDistricts then
				hasDC = pDistricts:HasDistrict(dcInfo.Index)
			end

			if hasDC then
				dcCount = dcCount + 1
				-- Find the DC plot by scanning city plots
				local dcX, dcY = -1, -1
				local cityPlots = Map.GetCityPlots():GetPurchasedPlots(city)
				if cityPlots then
					for _, plotIdx in ipairs(cityPlots) do
						local pPlot = Map.GetPlotByIndex(plotIdx)
						if pPlot and pPlot:GetDistrictType() == dcInfo.Index then
							dcX = pPlot:GetX()
							dcY = pPlot:GetY()
							break
						end
					end
				end
				local pDistrict = pDistricts:GetDistrict(dcInfo.Index)
				local isComplete = false
				local isPillaged = false
				if pDistrict then
					isComplete = pDistrict:IsComplete()
					isPillaged = pDistrict:IsPillaged()
				end
				SetDebugLine(line, cityName .. ": HAS DC at(" .. dcX .. "," .. dcY .. ") complete=" .. tostring(isComplete) .. " pillaged=" .. tostring(isPillaged))
				line = line + 1

				if dcX >= 0 then
					local pPlot = Map.GetPlot(dcX, dcY)
					if pPlot then
						local plotDist = pPlot:GetDistrictType()
						local plotTerrain = pPlot:GetTerrainType()
						local plotFeature = pPlot:GetFeatureType()
						SetDebugLine(line, "  plotDist=" .. plotDist .. " terrain=" .. plotTerrain .. " feature=" .. plotFeature)
						line = line + 1
					end
				end
			else
				SetDebugLine(line, cityName .. ": no DC")
				line = line + 1
			end
			if line > 9 then break end
		end

		SetDebugLine(line, "cities=" .. cityCount .. " DCs=" .. dcCount)
	end)

	if not ok then
		SetDebugLine(10, "[COLOR_RED]ERR: " .. tostring(err) .. "[ENDCOLOR]")
	end
end

-- Refresh art debug on various events
function OnArtDebugRefresh()
	RefreshArtDebug()
end

Events.CitySelectionChanged.Add(OnArtDebugRefresh)
Events.TurnBegin.Add(OnArtDebugRefresh)
if Events.DistrictBuildProgressChanged then
	Events.DistrictBuildProgressChanged.Add(function(playerID, districtID, cityID, x, y, districtType, era, civilization, percentComplete)
		print("SINGULARITY_DEBUG: DistrictBuildProgress player=" .. tostring(playerID) .. " distType=" .. tostring(districtType) .. " at (" .. tostring(x) .. "," .. tostring(y) .. ") pct=" .. tostring(percentComplete))
		RefreshArtDebug()
	end)
end
if Events.DistrictCompleted then
	Events.DistrictCompleted.Add(function(playerID, districtID, cityID, x, y, districtType, era, civilization)
		print("SINGULARITY_DEBUG: DistrictCompleted player=" .. tostring(playerID) .. " distType=" .. tostring(districtType) .. " at (" .. tostring(x) .. "," .. tostring(y) .. ")")
		RefreshArtDebug()
	end)
end

-- Initial refresh
RefreshArtDebug()

-- Initial state
m_Panel:SetHide(true)
print("Singularity: InorganicLifeUI loaded (v5 - ArtDebug)")
