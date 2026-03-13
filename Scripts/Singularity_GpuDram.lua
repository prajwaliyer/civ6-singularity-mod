-- Singularity_GpuDram.lua
-- GPU/DRAM Specialization buildings consume Chips and produce GPU/DRAM each turn.
-- XML modifiers handle resource production display.
-- This script:
--   1. Actually consumes chips from stockpile each turn
--   2. Guards against zero-chips (undoes XML production)
--   3. Stores consumption rates as player properties for UI tooltip

local BUILDING_GPU_SPEC  = GameInfo.Buildings["BUILDING_GPU_SPECIALIZATION"]
local BUILDING_DRAM_SPEC = GameInfo.Buildings["BUILDING_DRAM_SPECIALIZATION"]
local RESOURCE_CHIPS     = GameInfo.Resources["RESOURCE_CHIPS"]
local RESOURCE_GPU       = GameInfo.Resources["RESOURCE_GPU"]
local RESOURCE_DRAM      = GameInfo.Resources["RESOURCE_DRAM"]

function GetGpuDramTotals(playerID)
	local pPlayer = Players[playerID]
	if pPlayer == nil then return 0, 0, 0 end

	local totalGpu = 0
	local totalDram = 0
	local totalChipCost = 0

	local pCities = pPlayer:GetCities()
	for i, pCity in pCities:Members() do
		local pBuildings = pCity:GetBuildings()
		if BUILDING_GPU_SPEC and pBuildings:HasBuilding(BUILDING_GPU_SPEC.Index) then
			totalGpu = totalGpu + 1
			totalChipCost = totalChipCost + 1
		end
		if BUILDING_DRAM_SPEC and pBuildings:HasBuilding(BUILDING_DRAM_SPEC.Index) then
			totalDram = totalDram + 1
			totalChipCost = totalChipCost + 1
		end
	end

	return totalGpu, totalDram, totalChipCost
end

function OnPlayerTurnActivated_GpuDramProduction(playerID, isFirstTime)
	if not isFirstTime then return end
	if RESOURCE_CHIPS == nil then return end

	local pPlayer = Players[playerID]
	if pPlayer == nil or not pPlayer:IsMajor() then return end

	local totalGpu, totalDram, totalChipCost = GetGpuDramTotals(playerID)

	if totalChipCost == 0 then
		pPlayer:SetProperty("SINGULARITY_CHIPS_FOR_GPU_DRAM", 0)
		pPlayer:SetProperty("SINGULARITY_GPU_BLOCKED", 0)
		pPlayer:SetProperty("SINGULARITY_DRAM_BLOCKED", 0)
		return
	end

	local pResources = pPlayer:GetResources()
	local chipStockpile = pResources:GetResourceAmount(RESOURCE_CHIPS.Index)

	if chipStockpile <= 0 then
		-- No chips: undo the GPU/DRAM that XML produced, mark all blocked
		if RESOURCE_GPU and totalGpu > 0 then
			pResources:ChangeResourceAmount(RESOURCE_GPU.Index, -totalGpu)
		end
		if RESOURCE_DRAM and totalDram > 0 then
			pResources:ChangeResourceAmount(RESOURCE_DRAM.Index, -totalDram)
		end
		pPlayer:SetProperty("SINGULARITY_CHIPS_FOR_GPU_DRAM", 0)
		pPlayer:SetProperty("SINGULARITY_GPU_BLOCKED", totalGpu)
		pPlayer:SetProperty("SINGULARITY_DRAM_BLOCKED", totalDram)
		return
	end

	-- Have chips: consume them
	local chipsToConsume = math.min(totalChipCost, chipStockpile)
	pResources:ChangeResourceAmount(RESOURCE_CHIPS.Index, -chipsToConsume)

	-- If not enough chips for full production, scale back proportionally
	local gpuBlocked = 0
	local dramBlocked = 0
	if chipsToConsume < totalChipCost then
		local ratio = chipsToConsume / totalChipCost
		local gpuProduced = math.floor(totalGpu * ratio)
		local dramProduced = math.floor(totalDram * ratio)
		gpuBlocked = totalGpu - gpuProduced
		dramBlocked = totalDram - dramProduced
		if RESOURCE_GPU and gpuBlocked > 0 then
			pResources:ChangeResourceAmount(RESOURCE_GPU.Index, -gpuBlocked)
		end
		if RESOURCE_DRAM and dramBlocked > 0 then
			pResources:ChangeResourceAmount(RESOURCE_DRAM.Index, -dramBlocked)
		end
	end

	pPlayer:SetProperty("SINGULARITY_CHIPS_FOR_GPU_DRAM", chipsToConsume)
	pPlayer:SetProperty("SINGULARITY_GPU_BLOCKED", gpuBlocked)
	pPlayer:SetProperty("SINGULARITY_DRAM_BLOCKED", dramBlocked)
end

Events.PlayerTurnActivated.Add(OnPlayerTurnActivated_GpuDramProduction)
print("Singularity: GPU/DRAM module loaded")
