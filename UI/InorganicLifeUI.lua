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


-- ---------------------------------------------------------------------------
-- Power surplus calculation (UI context only)
-- ---------------------------------------------------------------------------
local POWER_PER_CITIZEN = 2
local DATA_CENTER_POWER_COST = 10
local DISTRICT_DATA_CENTER = GameInfo.Districts["DISTRICT_DATA_CENTER"]

function CountDataCentersInCity(pCity)
	if DISTRICT_DATA_CENTER == nil then return 0 end
	local count = 0
	local cityPlots = Map.GetCityPlots():GetPurchasedPlots(pCity)
	if cityPlots then
		for _, plotIdx in ipairs(cityPlots) do
			local pPlot = Map.GetPlotByIndex(plotIdx)
			if pPlot and pPlot:GetDistrictType() == DISTRICT_DATA_CENTER.Index then
				count = count + 1
			end
		end
	end
	return count
end

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
	local dcPowerDraw = CountDataCentersInCity(city) * DATA_CENTER_POWER_COST
	return totalSupply - required - popConsumption - dcPowerDraw
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
		m_TurnsToGrowth:SetText("[COLOR_RED]Population declining (-1/turn)[ENDCOLOR]")
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

-- Initial state
m_Panel:SetHide(true)
print("Singularity: InorganicLifeUI loaded (v6)")
