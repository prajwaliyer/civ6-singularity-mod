-- Singularity_DysonSphere.lua
-- Grants +30 Power to all player cities when a Dyson Swarm quarter is launched.

print("Singularity: DysonSphere script loaded")

local DYSON_QUARTER_MODIFIERS = {
	["PROJECT_LAUNCH_DYSON_SWARM_Q1"] = "DYSON_Q1_GENERATE_POWER",
	["PROJECT_LAUNCH_DYSON_SWARM_Q2"] = "DYSON_Q2_GENERATE_POWER",
	["PROJECT_LAUNCH_DYSON_SWARM_Q3"] = "DYSON_Q3_GENERATE_POWER",
	["PROJECT_LAUNCH_DYSON_SWARM_Q4"] = "DYSON_Q4_GENERATE_POWER",
};

function OnCityProjectCompleted(playerID, cityID, projectID)
	local projectInfo = GameInfo.Projects[projectID];
	if projectInfo == nil then return; end

	local modifierID = DYSON_QUARTER_MODIFIERS[projectInfo.ProjectType];
	if modifierID == nil then return; end

	local pPlayer = Players[playerID];
	if pPlayer == nil then return; end

	local pPlayerCities = pPlayer:GetCities();
	for _, city in pPlayerCities:Members() do
		city:AttachModifierByID(modifierID);
	end

	print("Singularity: Attached " .. modifierID .. " to all cities for player " .. playerID);
end

Events.CityProjectCompleted.Add(OnCityProjectCompleted);
