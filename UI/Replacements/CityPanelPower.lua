-- CityPanelPower.lua (Singularity override)
-- Base game power panel with Data Center / Fusion Reactor / Microreactor entries.

include("InstanceManager");
include("SupportFunctions");
include("EspionageViewManager");

local m_kPowerBreakdownIM:table = InstanceManager:new( "PowerLineInstance",	"Top");
local m_KeyStackIM:table = InstanceManager:new( "KeyEntry", "KeyColorImage", Controls.KeyStack );

local m_kEspionageViewManager = EspionageViewManager:CreateManager();

-- Singularity constants
local DISTRICT_DATA_CENTER   = GameInfo.Districts["DISTRICT_DATA_CENTER"]
local DISTRICT_FUSION_REACTOR = GameInfo.Districts["DISTRICT_FUSION_REACTOR"]
local BUILDING_FUSION_CORE   = GameInfo.Buildings["BUILDING_FUSION_CORE"]
local IMPROVEMENT_MICROREACTOR = GameInfo.Improvements["IMPROVEMENT_MICROREACTOR"]
local DATA_CENTER_POWER_COST = 10
local FUSION_CORE_POWER      = 48
local MICROREACTOR_POWER     = 10
local DYSON_QUARTER_POWER    = 50
local POWER_PER_CITIZEN      = 2
local DYSON_QUARTER_BUILDINGS = {
	GameInfo.Buildings["BUILDING_DYSON_Q1_POWER"],
	GameInfo.Buildings["BUILDING_DYSON_Q2_POWER"],
	GameInfo.Buildings["BUILDING_DYSON_Q3_POWER"],
	GameInfo.Buildings["BUILDING_DYSON_Q4_POWER"],
}

-- ===========================================================================
-- Count how many Dyson Swarm quarters this city has
-- ===========================================================================
function CountDysonQuartersInCity(pCity)
	local count = 0
	local pBuildings = pCity:GetBuildings()
	if pBuildings == nil then return 0 end
	for _, bldgInfo in ipairs(DYSON_QUARTER_BUILDINGS) do
		if bldgInfo and pBuildings:HasBuilding(bldgInfo.Index) then
			count = count + 1
		end
	end
	return count
end

-- ===========================================================================
-- Count completed Data Center districts in a city
-- ===========================================================================
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

-- ===========================================================================
-- Check if city has a Fusion Core building
-- ===========================================================================
function CityHasFusionCore(pCity)
	if BUILDING_FUSION_CORE == nil then return false end
	local pBuildings = pCity:GetBuildings()
	if pBuildings then
		return pBuildings:HasBuilding(BUILDING_FUSION_CORE.Index)
	end
	return false
end

-- ===========================================================================
-- Count Microreactor improvements in a city's territory
-- ===========================================================================
function CountMicroreactorsInCity(pCity)
	if IMPROVEMENT_MICROREACTOR == nil then return 0 end
	local count = 0
	local cityPlots = Map.GetCityPlots():GetPurchasedPlots(pCity)
	if cityPlots then
		for _, plotIdx in ipairs(cityPlots) do
			local pPlot = Map.GetPlotByIndex(plotIdx)
			if pPlot and pPlot:GetImprovementType() == IMPROVEMENT_MICROREACTOR.Index then
				if not pPlot:IsImprovementPillaged() then
					count = count + 1
				end
			end
		end
	end
	return count
end

-- ===========================================================================
function OnRefresh()
	if ContextPtr:IsHidden() then
		return;
	end

	local pCity = UI.GetHeadSelectedCity();
	if (pCity == nil) then
		pCity = m_kEspionageViewManager:GetEspionageViewCity();
		if pCity == nil then
			return;
		end
	else
		m_kEspionageViewManager:ClearEspionageViewCity();
	end

	local playerID = pCity:GetOwner();
	local pPlayer = Players[playerID];
	if (pPlayer == nil) then
		return;
	end

	if pPlayer == nil or pCity == nil then
		return;
	end

	local pCityPower = pCity:GetPower();
	if pCityPower == nil then
		return;
	end

	-- Count Data Centers for this city
	local dcCount = CountDataCentersInCity(pCity)
	local dcPowerDraw = dcCount * DATA_CENTER_POWER_COST

	-- Inorganic Life population power consumption
	local isInorganic = (pCity:GetProperty("INORGANIC_LIFE") == 1)
	local popPowerDraw = 0
	if isInorganic then
		popPowerDraw = pCity:GetPopulation() * POWER_PER_CITIZEN
	end

	-- Status
	local freePower:number = pCityPower:GetFreePower();
	local temporaryPower:number = pCityPower:GetTemporaryPower();
	local currentPower:number = freePower + temporaryPower;
	local requiredPower:number = pCityPower:GetRequiredPower() + dcPowerDraw + popPowerDraw;
	local powerStatusName:string = "LOC_POWER_STATUS_POWERED_NAME";
	local powerStatusDescription:string = "LOC_POWER_STATUS_POWERED_DESCRIPTION";
	if (requiredPower == 0) then
		powerStatusName = "LOC_POWER_STATUS_NO_POWER_NEEDED_NAME";
		powerStatusDescription = "LOC_POWER_STATUS_NO_POWER_NEEDED_DESCRIPTION";
	elseif (currentPower < requiredPower) then
		powerStatusName = "LOC_POWER_STATUS_UNPOWERED_NAME";
		powerStatusDescription = "LOC_POWER_STATUS_UNPOWERED_DESCRIPTION";
	elseif (pCityPower:IsFullyPoweredByActiveProject()) then
		currentPower = requiredPower;
	end
	Controls.ConsumingPowerLabel:SetText(Locale.Lookup("LOC_POWER_PANEL_CONSUMED", Round(currentPower, 1)));
	Controls.RequiredPowerLabel:SetText(Locale.Lookup("LOC_POWER_PANEL_REQUIRED", Round(requiredPower, 1)));
	Controls.PowerStatusNameLabel:SetText(Locale.Lookup(powerStatusName));

	-- Status Effects
	local statusText = Locale.Lookup(powerStatusDescription)
	if isInorganic then
		local pop = pCity:GetPopulation()
		local powerSurplus = currentPower - requiredPower
		local accumulated = pCity:GetProperty("POWER_GROWTH") or 0
		local growth = pCity:GetGrowth()
		local threshold = 0
		if growth then
			threshold = growth:GetGrowthThreshold()
		end
		statusText = statusText .. "[NEWLINE][NEWLINE][ICON_Citizen] Population: " .. pop
		if powerSurplus > 0 then
			statusText = statusText .. "[NEWLINE][COLOR_GREEN]+" .. powerSurplus .. "[ENDCOLOR] surplus [ICON_Power] Power"
			local remaining = threshold - accumulated
			if remaining <= 0 then
				statusText = statusText .. "[NEWLINE]1 turn until growth"
			else
				local turns = math.ceil(remaining / powerSurplus)
				statusText = statusText .. "[NEWLINE]" .. turns .. " turns until growth"
			end
		elseif powerSurplus < 0 then
			statusText = statusText .. "[NEWLINE][COLOR_RED]" .. powerSurplus .. "[ENDCOLOR] deficit [ICON_Power] Power"
			statusText = statusText .. "[NEWLINE][COLOR_RED]Population is declining[ENDCOLOR]"
		else
			statusText = statusText .. "[NEWLINE]0 surplus [ICON_Power] Power"
			statusText = statusText .. "[NEWLINE]Growth stalled"
		end
	end
	Controls.PowerStatusDescriptionLabel:SetText(statusText);
	Controls.PowerStatusDescriptionBox:SetSizeY(Controls.PowerStatusDescriptionLabel:GetSizeY() + 15);

	-- Breakdown
	m_kPowerBreakdownIM:ResetInstances();
	-----Consumed
	local freePowerBreakdown:table = pCityPower:GetFreePowerSources();
	local temporaryPowerBreakdown:table = pCityPower:GetTemporaryPowerSources();
	local somethingToShow:boolean = false;
	for _,innerTable in ipairs(freePowerBreakdown) do
		somethingToShow = true;
		local scoreSource, scoreValue = next(innerTable);
		local lineInstance = m_kPowerBreakdownIM:GetInstance(Controls.ConsumedPowerBreakdownStack);
		lineInstance.LineTitle:SetText(scoreSource);
		lineInstance.LineValue:SetText("[ICON_Power]" .. Round(scoreValue, 1));
	end
	for _,innerTable in ipairs(temporaryPowerBreakdown) do
		somethingToShow = true;
		local scoreSource, scoreValue = next(innerTable);
		local lineInstance = m_kPowerBreakdownIM:GetInstance(Controls.ConsumedPowerBreakdownStack);
		lineInstance.LineTitle:SetText(scoreSource);
		lineInstance.LineValue:SetText("[ICON_Power]" .. Round(scoreValue, 1));
	end
	-- Singularity: Add Fusion Core to Usable Power section
	if CityHasFusionCore(pCity) then
		somethingToShow = true
		local lineInstance = m_kPowerBreakdownIM:GetInstance(Controls.ConsumedPowerBreakdownStack)
		lineInstance.LineTitle:SetText("Fusion Core")
		lineInstance.LineValue:SetText("[ICON_Power]" .. FUSION_CORE_POWER)
	end
	-- Singularity: Add Microreactors to Usable Power section
	local mrCount = CountMicroreactorsInCity(pCity)
	if mrCount > 0 then
		somethingToShow = true
		local lineInstance = m_kPowerBreakdownIM:GetInstance(Controls.ConsumedPowerBreakdownStack)
		if mrCount == 1 then
			lineInstance.LineTitle:SetText("Microreactor")
		else
			lineInstance.LineTitle:SetText("Microreactor x" .. mrCount)
		end
		lineInstance.LineValue:SetText("[ICON_Power]" .. (mrCount * MICROREACTOR_POWER))
	end
	-- Singularity: Add Dyson Swarm to Usable Power section
	local dysonCount = CountDysonQuartersInCity(pCity)
	if dysonCount > 0 then
		somethingToShow = true
		local lineInstance = m_kPowerBreakdownIM:GetInstance(Controls.ConsumedPowerBreakdownStack)
		lineInstance.LineTitle:SetText("Dyson Swarm (" .. dysonCount .. "/4)")
		lineInstance.LineValue:SetText("[ICON_Power]" .. (dysonCount * DYSON_QUARTER_POWER))
	end
	Controls.ConsumedPowerBreakdownStack:CalculateSize();
	Controls.ConsumedBreakdownBox:SetSizeY(Controls.ConsumedPowerBreakdownStack:GetSizeY() + 15);
	Controls.ConsumedBreakdownBox:SetHide(not somethingToShow);
	Controls.ConsumedTitle:SetHide(not somethingToShow);
	-----Required
	local requiredPowerBreakdown:table = pCityPower:GetRequiredPowerSources();
	local somethingToShow:boolean = false;
	for _,innerTable in ipairs(requiredPowerBreakdown) do
		somethingToShow = true;
		local scoreSource, scoreValue = next(innerTable);
		local lineInstance = m_kPowerBreakdownIM:GetInstance(Controls.RequiredPowerBreakdownStack);
		lineInstance.LineTitle:SetText(scoreSource);
		lineInstance.LineValue:SetText("[ICON_Power]" .. Round(scoreValue, 1));
	end
	-- Singularity: Add Data Center power consumption to Required section
	if dcCount > 0 then
		somethingToShow = true
		local lineInstance = m_kPowerBreakdownIM:GetInstance(Controls.RequiredPowerBreakdownStack)
		if dcCount == 1 then
			lineInstance.LineTitle:SetText("Data Center")
		else
			lineInstance.LineTitle:SetText("Data Center x" .. dcCount)
		end
		lineInstance.LineValue:SetText("[ICON_Power]" .. dcPowerDraw)
	end
	-- Singularity: Add Inorganic Life population power consumption to Required section
	if isInorganic and popPowerDraw > 0 then
		somethingToShow = true
		local lineInstance = m_kPowerBreakdownIM:GetInstance(Controls.RequiredPowerBreakdownStack)
		lineInstance.LineTitle:SetText("Population x" .. pCity:GetPopulation())
		lineInstance.LineValue:SetText("[ICON_Power]" .. popPowerDraw)
	end
	Controls.RequiredPowerBreakdownStack:CalculateSize();
	Controls.RequiredBreakdownBox:SetSizeY(Controls.RequiredPowerBreakdownStack:GetSizeY() + 15);
	Controls.RequiredBreakdownBox:SetHide(not somethingToShow);
	Controls.RequiredTitle:SetHide(not somethingToShow);
	-----Generated
	local generatedPowerBreakdown:table = pCityPower:GetGeneratedPowerSources();
	local somethingToShow:boolean = false;
	for _,innerTable in ipairs(generatedPowerBreakdown) do
		somethingToShow = true;
		local scoreSource, scoreValue = next(innerTable);
		local lineInstance = m_kPowerBreakdownIM:GetInstance(Controls.GeneratedPowerBreakdownStack);
		lineInstance.LineTitle:SetText(scoreSource);
		lineInstance.LineValue:SetText("[ICON_Power]" .. Round(scoreValue, 1));
		lineInstance.LineValue:SetColorByName("White");
	end
	Controls.GeneratedPowerBreakdownStack:CalculateSize();
	Controls.GeneratedBreakdownBox:SetSizeY(Controls.GeneratedPowerBreakdownStack:GetSizeY() + 15);
	Controls.GeneratedBreakdownBox:SetHide(not somethingToShow);
	Controls.GeneratedTitle:SetHide(not somethingToShow);

	-- Advisor
	if m_kEspionageViewManager:IsEspionageView() then
		Controls.PowerAdvisor:SetHide(true);
	else
		Controls.PowerAdvice:SetText(pCity:GetPowerAdvice());
		Controls.PowerAdvisor:SetHide(false);
	end

	m_KeyStackIM:ResetInstances();

	AddKeyEntry("LOC_POWER_LENS_KEY_POWER_SOURCE", UI.GetColorValue("COLOR_STANDARD_GREEN_MD"), true);
	AddKeyEntry("LOC_POWER_LENS_KEY_FULLY_POWERED", UI.GetColorValue("COLOR_STANDARD_GREEN_MD"));
	AddKeyEntry("LOC_POWER_LENS_KEY_UNDERPOWERED", UI.GetColorValue("COLOR_STANDARD_RED_MD"));
	AddKeyEntry("LOC_POWER_LENS_KEY_POWER_RANGE", UI.GetColorValue("COLOR_YELLOW"), true);

	Controls.TabStack:CalculateSize();
end

-- ===========================================================================
function AddKeyEntry(textString:string, colorValue:number, bUseEmptyTexture:boolean)
	local keyEntryInstance:table = m_KeyStackIM:GetInstance();

	-- Update key text
	keyEntryInstance.KeyLabel:SetText(Locale.Lookup(textString));

	-- Set the texture if we want to use the hollow, border only hex texture
	if bUseEmptyTexture == true then
		keyEntryInstance.KeyColorImage:SetTexture("Controls_KeySwatchHexEmpty");
	else
		keyEntryInstance.KeyColorImage:SetTexture("Controls_KeySwatchHex");
	end

	-- Update key color
	keyEntryInstance.KeyColorImage:SetColor(colorValue);
end

-- ===========================================================================
function OnShowEnemyCityOverview( ownerID:number, cityID:number)
	m_kEspionageViewManager:SetEspionageViewCity( ownerID, cityID );
	OnRefresh();
end

-- ===========================================================================
function OnTabStackSizeChanged()
	-- Manually resize the context to fit the child stack
	ContextPtr:SetSizeX(Controls.TabStack:GetSizeX());
	ContextPtr:SetSizeY(Controls.TabStack:GetSizeY());
end

-- ===========================================================================
function Initialize()
	LuaEvents.CityPanelTabRefresh.Add(OnRefresh);
	Events.CitySelectionChanged.Add( OnRefresh );

	LuaEvents.CityBannerManager_ShowEnemyCityOverview.Add( OnShowEnemyCityOverview );

	Controls.TabStack:RegisterSizeChanged( OnTabStackSizeChanged );
end
Initialize();
