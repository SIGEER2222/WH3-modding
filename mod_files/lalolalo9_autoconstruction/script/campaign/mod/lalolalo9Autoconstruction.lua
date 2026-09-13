local Lalolalo9AutoConstructionEnabled = 1
local Lalolalo9 ={}
local Lalolalo9AutoConstructionPlayerFaction = 0
local ldebug = false
local Lalolalo9AutoConstructionPriorityListString = ""
local Lalolalo9AutoConstructionPriorityList = {}
local Lalolalo9AutoConstructionPriorityListGroupedRes = {}
local Lalolalo9AutoConstructionPriorityListGroupedLand = {}
local Lalolalo9AutoConstructionPriorityListGroupedAll = {}
local Lalolalo9AutoConstructionBuildingListRes = {}
local Lalolalo9AutoConstructionBuildingListLand = {}
local Lalolalo9AutoconstructionPriorityGrouping = 0
local Lalolalo9AutoConstructionStartEnd = 0
local Lalolalo9AutoConstructionAutoConstructAutoupgrade = 0

local function callIfCallable(f)
    return function(...)
        error, result = pcall(f, ...)
        if error then -- f exists and is callable
            return result
        end
        -- nothing to do, as though not called, or print('error', result)
    end
end


local lvlog = function(t)
    if ldebug then
        callIfCallable(vlog("[Lalolalo9][AutoConstructionAssign]: " .. tostring(t)))
    end
end

local function Lalolalo9_PriorityBuildingListEncoder(ListToConvert)
    local tablecount = 0
    local Finalstring = ""
    for i, p in pairs(ListToConvert) do
        --lvlog("Building index is "  .. tostring(i) )
        --lvlog("Building Key is " .. tostring(p) )
        tablecount = tablecount + 1
    end
    Finalstring = tostring(tablecount) .. "_"
    for i, p in pairs(ListToConvert) do
        Finalstring = Finalstring ..  "__lalo__" .. tostring(p)
    end
   -- lvlog("Final sort string is " .. Finalstring)
    return Finalstring
end

local function Lalolalo9AutoConstructionSaveValues()
    cm:set_saved_value("Lalolalo9AutoConstructionEnabled",Lalolalo9AutoConstructionEnabled)
    cm:set_saved_value("Lalolalo9AutoconstructionPriorityGrouping",Lalolalo9AutoconstructionPriorityGrouping)
    cm:set_saved_value("Lalolalo9AutoConstructionStartEnd",Lalolalo9AutoConstructionStartEnd)
    cm:set_saved_value("Lalolalo9AutoConstructionAutoConstructAutoupgrade",Lalolalo9AutoConstructionAutoConstructAutoupgrade)
    cm:set_saved_value("Lalolalo9AutoConstructionPriorityList",Lalolalo9_PriorityBuildingListEncoder(Lalolalo9AutoConstructionPriorityList))
end

local function Lalolalo9_AutoConstruction_TooltipSetter()
  --  lvlog("Starting tooltip")
    local Lalolalo9_AutoConstruction_button_Building_Browser = find_uicomponent("Lalolalo9_AutoConstruction_button_Building_Browser")
    --lvlog("Set local var")
    --lvlog("locla is " .. tostring(Lalolalo9_AutoConstruction_button_Building_Browser))
    if Lalolalo9_AutoConstruction_button_Building_Browser ~= false then
      --  lvlog("foudn")
        local stringmaker = ""
        if Lalolalo9AutoConstructionEnabled == 0 then
            stringmaker = stringmaker .. "Currently disabled. Please click to access settings."
        else
            if Lalolalo9AutoConstructionAutoConstructAutoupgrade == 0 then
                stringmaker = stringmaker .. "Currently autoconstructing and autoupgrading at the "
            else
                stringmaker = stringmaker .. "Currently autoupgrading only at the "
            end
            if Lalolalo9AutoConstructionStartEnd == 0 then
                stringmaker = stringmaker .. "start of the turn. "
            else
                stringmaker = stringmaker .. "end of the turn. "
            end
            stringmaker = stringmaker .. "Please click to access settings."
        end
      --  lvlog("String is " .. stringmaker)
        Lalolalo9_AutoConstruction_button_Building_Browser:SetTooltipText(stringmaker,stringmaker,true)
        else
    --    lvlog("not found")
    end
end

local function Lalolalo9_PriorityBuildingListConverter()
  --  lvlog("Starting func")
    local setkey = ""
    local insertedlandmark = false
    local insertedresource = false
    Lalolalo9AutoConstructionPriorityListGroupedRes = {}
    Lalolalo9AutoConstructionPriorityListGroupedLand = {}
    Lalolalo9AutoConstructionPriorityListGroupedAll = {}
    Lalolalo9AutoConstructionBuildingListRes = {}
    Lalolalo9AutoConstructionBuildingListLand = {}
   -- lvlog("set everything to zero")
    for i , p in pairs(Lalolalo9AutoConstructionPriorityList) do
      --  lvlog("INdex " .. tostring(i) .. " has " .. tostring(p))
        setkey =  common.get_context_value("DatabaseRecordContext(\"CcoBuildingChainRecord\",\"" .. tostring(p) ..  "\").BuildingSetContext.Key")
       -- lvlog("Teesting is " .. tostring(setkey))
        if setkey == "wh2_main_set_resource" then
            table.insert(Lalolalo9AutoConstructionBuildingListRes,p)
            if not insertedresource then
                table.insert(Lalolalo9AutoConstructionPriorityListGroupedRes, "Lalolalo9ResourceChainGroup")
                table.insert(Lalolalo9AutoConstructionPriorityListGroupedAll, "Lalolalo9ResourceChainGroup")
                insertedresource = true
            end
            table.insert(Lalolalo9AutoConstructionPriorityListGroupedLand, p) 
        elseif ((setkey == "wh2_main_set_landmark") or (setkey == "wh_main_set_port")) then
            table.insert(Lalolalo9AutoConstructionBuildingListLand,p)
            if not insertedlandmark then
            table.insert(Lalolalo9AutoConstructionPriorityListGroupedLand, "Lalolalo9LandChainGroup")
            table.insert(Lalolalo9AutoConstructionPriorityListGroupedAll, "Lalolalo9LandChainGroup")
            insertedlandmark = true
            end
            table.insert(Lalolalo9AutoConstructionPriorityListGroupedRes, p)
        else
            table.insert(Lalolalo9AutoConstructionPriorityListGroupedRes, p)
            table.insert(Lalolalo9AutoConstructionPriorityListGroupedLand, p)
            table.insert(Lalolalo9AutoConstructionPriorityListGroupedAll, p)
        end
    end
    for i , p in pairs(Lalolalo9AutoConstructionPriorityListGroupedRes) do
       -- lvlog("IndexRes " .. tostring(i) .. " has " .. tostring(p))
    end
    for i , p in pairs(Lalolalo9AutoConstructionPriorityListGroupedLand) do
       -- lvlog("IndexLand " .. tostring(i) .. " has " .. tostring(p))
    end
    for i , p in pairs(Lalolalo9AutoConstructionPriorityListGroupedAll) do
     --   lvlog("IndexAll " .. tostring(i) .. " has " .. tostring(p))
    end
    if Lalolalo9AutoConstructionPriorityListGroupedRes == {} then
        Lalolalo9AutoConstructionPriorityListGroupedRes = Lalolalo9AutoConstructionPriorityList
    end
    if Lalolalo9AutoConstructionPriorityListGroupedLand == {} then
        Lalolalo9AutoConstructionPriorityListGroupedLand = Lalolalo9AutoConstructionPriorityList
    end
    if Lalolalo9AutoConstructionPriorityListGroupedAll == {} then
        Lalolalo9AutoConstructionPriorityListGroupedAll = Lalolalo9AutoConstructionPriorityList
    end
end


local function Lalolalo9_PriorityBuildingListDecoder(StringToConvert)
    local tempstring = StringToConvert
    local prioritylistsize = tonumber(string.match(tempstring, "^%d+"))
    local encodedtable = {}
   -- lvlog("List size is " .. tostring(prioritylistsize))
    tempstring = string.gsub(tempstring, tostring(prioritylistsize) .. "___lalo__", "" , 1)
   -- lvlog("Substituded string is " .. tempstring)
    for indexloop = 1, prioritylistsize do
        local chainkey = ""
        if indexloop == prioritylistsize then
            chainkey = tempstring
        else
            local fistpartend = string.find(tempstring, "__lalo__") - 1
     --       lvlog("Substituded is " .. tostring(fistpartend))
            chainkey = string.sub(tempstring,1,fistpartend)
            tempstring = string.gsub(tempstring, chainkey .. "__lalo__", "", 1)
        end
        --lvlog("Stringdecode inserting " .. chainkey)
        local testing = common.get_context_value("DatabaseRecordContext(\"CcoBuildingChainRecord\",\"" .. tostring(chainkey) .. "\").Key")
        --lvlog("Strigndecode testing is " .. tostring(testing))
        if testing ~= nil then
            table.insert(encodedtable,chainkey)
          --  lvlog("Instedrd xxxx" .. tostring( chainkey))
        end
    end
    for AllSettlementIndex = 0 , common.get_context_value("CcoCampaignRoot", "","SettlementList.Size") - 1 do
    --lvlog("Starting settlement loop")
        for AllBuildingChainsIndex = 0 , common.get_context_value("CcoCampaignRoot", "" , "SettlementList.At(" .. AllSettlementIndex .. ").PlayersFactionChainList.Size") - 1 do
        --lvlog("Starting buildchain loop")
            local AllBuildingKey = common.get_context_value("CcoCampaignRoot", "", "SettlementList.At(" ..AllSettlementIndex .. ").PlayersFactionChainList.At(" .. AllBuildingChainsIndex .. ").Key")
            local BuildingKeyAllreadyAdded = false
            for encodedindex , encodedkey in pairs(encodedtable) do
                if encodedkey == AllBuildingKey then
                    BuildingKeyAllreadyAdded = true
                    break
                end
            end
            if not BuildingKeyAllreadyAdded then
                    -- lvlog("Other insert of" .. tostring(AllBuildingKey))
                table.insert(encodedtable,AllBuildingKey)
            end
        end
    end
    return encodedtable
end

local function Lalolalo9_Add_Buildings_To_Queue(faction)
    --lvlog("Starting build function")
--    lvlog("faction " .. tostring(faction))
--    lvlog("Lalolalo9AutoConstructionEnabled" .. tostring(Lalolalo9AutoConstructionEnabled))
    local budgetPerc = (common.get_context_value("CcoCampaignFaction",faction:cqi(),"AutoManagementBudgetPercentage") or 0)         
	local SlotsToUpgrade = {}
	local prioindexallland = 0
	local prioindexallres = 0
	local prioindexland = 0
	local prioindexres = 0
    for landresindex , landreskey in pairs(Lalolalo9AutoConstructionPriorityListGroupedAll) do
        if landreskey == "Lalolalo9LandChainGroup" then
            if prioindexallland == 0 then
                prioindexallland = landresindex
            end
        end
        if landreskey == "Lalolalo9ResourceChainGroup" then
            if prioindexallres == 0 then
                prioindexallres = landresindex
            end
        end
    end
    for landindex , landkey in pairs(Lalolalo9AutoConstructionPriorityListGroupedLand) do
        if landkey == "Lalolalo9LandChainGroup" then
            prioindexland = landindex
            break
        end
    end
    for resindex , reskey in pairs(Lalolalo9AutoConstructionPriorityListGroupedRes) do
        if reskey == "Lalolalo9ResourceChainGroup" then
            prioindexres = resindex
            break
        end
    end
 --   lvlog("prioindexallland is " .. tostring(prioindexallland))
   -- lvlog("prioindexallres is " .. tostring(prioindexallres))
    --lvlog("prioindexland is " .. tostring(prioindexland))
    --lvlog("prioindexres is " .. tostring(prioindexres))
    local militarybuildingstoexclude = {}
	for SettleIndex = 0 , common.get_context_value("CcoCampaignFaction",faction:command_queue_index(),"SettlementList.Size") - 1 do
--		lvlog("Settle " .. tostring(SettleIndex))
        local Provincekey =  common.get_context_value("CcoCampaignFaction",faction:command_queue_index(),"SettlementList.At(".. SettleIndex .. ").ProvinceContext.ModelProvinceContext.RecordKey")
		local RegionCanUpgrade = false
		local SettlementCQI = common.get_context_value("CcoCampaignFaction",faction:command_queue_index(),"SettlementList.At(".. SettleIndex .. ").CQI")
		local RegionRecord = common.get_context_value("CcoCampaignFaction",faction:command_queue_index(),"SettlementList.At(".. SettleIndex .. ").RegionRecordKey")
--		lvlog("RegionRecord " .. tostring(RegionRecord))
        if militarybuildingstoexclude[Provincekey] == nil then
            militarybuildingstoexclude[Provincekey] = {}
        end
        local BuildingsToExclude = militarybuildingstoexclude[Provincekey]
		for SlotIndex = 0, common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.Size") - 1 do
--			if not RegionCanUpgrade then
            if true then
				local SlotPrio = {}
				local isPort = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").IsPort")
				local IsActive = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").IsActive")
				local IsEmpty = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").IsEmpty")
				local IsDismantling = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").IsDismantling")
				local IsUpgrading = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").IsUpgrading")
				local IsRepairing = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").IsRepairing")
				local IsBuildingNew = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").IsBuildingNew")
				local CanUpgrade = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").CanUpgrade")
				local CanRepair = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").CanRepair")
				local BuildingSlotIndex = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").Index")
				local MayBuildEmpty = true
				local Currentbuildingslotlevel = -1
				if IsEmpty then
                    if Lalolalo9AutoConstructionAutoConstructAutoupgrade == 1 then
                        MayBuildEmpty = false
                    end
                else
                local Currentbuildingslotlevel = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").BuildingContext.BuildingLevelRecordContext.Level")
				end
--				lvlog("Current level is " .. tostring(Currentbuildingslotlevel))
--  				lvlog("isPort " .. tostring(isPort))
--  				lvlog("IsActive " .. tostring(IsActive))
--  				lvlog("IsEmpty " .. tostring(IsEmpty))
--  				lvlog("IsDismantling " .. tostring(IsDismantling))
--  				lvlog("IsUpgrading " .. tostring(IsUpgrading))
--  				lvlog("IsRepairing " .. tostring(IsRepairing))
--  				lvlog("IsBuildingNew " .. tostring(IsBuildingNew))
--  				lvlog("CanUpgrade " .. tostring(CanUpgrade))
--  				lvlog("CanRepair " .. tostring(CanRepair))
--  				lvlog("BuildingSlotIndex " .. tostring(BuildingSlotIndex))
--  				lvlog("MayBuildEmpty " .. tostring(MayBuildEmpty))
-- 	--			lvlog("MayBuildEmpty " .. tostring(MayBuildEmpty))
				if MayBuildEmpty and IsActive and CanUpgrade and (not IsDismantling) and (not IsUpgrading) and (not IsRepairing) and (not IsBuildingNew) and (not CanRepair) then
			--		lvlog("Region " .. tostring(RegionRecord) .. " can be upgraded")
					for PosIndex = 0 , common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList(true).Size") - 1 do
                        
                        local PriorityValue = 0
						local possibleupgradecontext = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList(true).At("..PosIndex..")")
						local upgradelevel = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList(true).At("..PosIndex..").Level")
						local isincreaseinlevel = true
						if upgradelevel <= Currentbuildingslotlevel then
                            isincreaseinlevel = false
                        end
						local possibleupgradecontextId = possibleupgradecontext:Call("GetContextObjectId")
						local possibleupgradecontextcachr = possibleupgradecontext:Call("ContextCacheId")
	--					lvlog("ContexCache" .. tostring(possibleupgradecontext))
						local BuildingIncome = 0
		--				local IsRedundantDuplicate = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList.At("..PosIndex..")"):Call("IsRedundantDuplicate(FindContext(\"CcoCampaignSettlement\",\"" .. tostring(SettlementCQI) .. "\"))")
						local IsRedundantDuplicate = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList(true).At("..PosIndex..")"):Call("IsRedundantDuplicate(FindContext(\"CcoCampaignSettlement\",\"".. tostring(SettlementCQI) .. "\"))")
					--	local ResourceRequirementContext = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList.At("..PosIndex..").CreateCost")
					--	local CreateCost = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList.At("..PosIndex..")"):Call("CreateCost(FindContext(\"CcoCampaignSettlement\",\"".. tostring(SettlementCQI) .. "\"))")
					--	local CreateCost = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList.At("..PosIndex..")"):Call("ResourceCostContext(FindContext(\"CcoCampaignSettlement\",\"".. tostring(SettlementCQI) .. "\",\"BuildingSlotList.At("..SlotIndex..")\"))")
					--	local CreateCost = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList.At("..PosIndex..").CreateCost()")
						
	--					local IsRedundantDuplicate = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList.At("..PosIndex..")"):Call("IsRedundantDuplicate(FindContext(\"" .. tostring(SettlementCQI) .. "\",\"CcoCampaignFaction\"))")
	--					local IsRedundantDuplicate = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList.At("..PosIndex..").IsRedundantDuplicate(FindContext(\"" .. tostring(SettlementCQI) .. "\",\"CcoCampaignSettlement\"))")
		--				local IsRedundantDuplicate = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList(true).At("..PosIndex..").IsRedundantDuplicate(\"CcoCampaignRoot\",\"\",\"FactionList.At(" .. tostring(LocalPlayerFactionIndex) .. ").SettlementList.At(".. tostring(SettleIndex) ..  ")\")")
		--				local IsRedundantDuplicate = common.get_context_value("FindContext(\"CcoCampaignSettlement\",\"".. tostring(SettlementCQI) .. "\")")
					--	lvlog("Can upgrade to " .. posibleupgradekey .. " " .. tostring(IsRedundantDuplicate))
			--			for PosIndex = 0 , common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeWithoutConversionsList	.Size") - 1 do
			--[[
                        local haseffects = false
                        local unlockunits = true
                        if IsEmpty then
                            for el = 0 ,common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList(true).At("..PosIndex..").EffectList.Size") - 1 do
								local effectkey = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeWithoutConversionsList.At("..PosIndex..").EffectList.At("..el..").EffectKey")
								local effecval = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeWithoutConversionsList.At("..PosIndex..").EffectList.At("..el..").Value")
								local IsPositive = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeWithoutConversionsList.At("..PosIndex..").EffectList.At("..el..").IsPositive")
				--				lvlog("effectkey" .. tostring(effectkey))
				--				lvlog("effecval" .. tostring(effecval))
								if string.match(string.lower(tostring(effectkey)),"_economy") and IsPositive and effecval > 0 then
									table.insert(SlotPrio,{UniqueKey,tonumber(effecval)/tonumber(CreateCost),CreateCost,BuildingToBuild})
								end
							end
                        end
                ]]
						local CanBuildInCurrentSlot = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList(true).At("..PosIndex..")"):Call("CanBuildInCurrentSlot(FindContext(\"CcoCampaignSettlement\",\"".. tostring(SettlementCQI) .. "\").BuildingSlotList.At("..SlotIndex.."))")
					--	lvlog("Can be built to " .. posibleupgradekey .. " " .. tostring(CanBuildInCurrentSlot))
						if CanBuildInCurrentSlot and (not IsRedundantDuplicate) and isincreaseinlevel then
			--				lvlog("Can build " .. tostring(PosIndex))
							local BuildingSuperchainContext = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList(true).At("..PosIndex..").BuildingChainRecordContext.Key")
							local BuildingLevelRecordKey = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList(true).At("..PosIndex..").Key")
							local UniqueKey = "Lalolalo9AutoConstructionTrigger_Reg__"..tostring(RegionRecord).."__Slot__"..tostring(BuildingSlotIndex).."__Build__"..tostring(BuildingLevelRecordKey)
							local BuildingToBuild = tostring(BuildingLevelRecordKey)
							local CreateCost = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList(true).At("..PosIndex..")"):Call("CreateCost(FindContext(\"CcoCampaignSettlement\",\"".. tostring(SettlementCQI) .. "\"))")
							local Unlocksonly = false
							--lvlog("So far so good")
							if IsEmpty then
                                for unitlistindex = 0 , common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList(true).At("..PosIndex..")"):Call("UnitList(FindContext(\"CcoCampaignSettlement\",\"".. tostring(SettlementCQI) .. "\")).Size") - 1 do
                                    Unlocksonly = true
                                    break
                                end
                            end
                  --          lvlog("succesfully completed this")
					--lvlog(UniqueKey .. " is " .. tostring(Unlocksonly))
			--				lvlog("CreateCost is " .. tostring(CreateCost))
							if CreateCost == nil or CreateCost == 0 then
								CreateCost = 1
							end
							for localindexpriolist , localkeyprio in pairs(Lalolalo9AutoConstructionPriorityList) do
                             --   lvlog("Index for " .. tostring(UniqueKey) .. " is " .. tostring(localindexpriolist) .. " and chainket is " .. tostring(localkeyprio))
                                if localkeyprio == BuildingSuperchainContext then
                                    PriorityValue = 50000 - localindexpriolist
                                    break
                                end
                            end
							if (Lalolalo9AutoconstructionPriorityGrouping <= 1) then
                                for localindexland , localindexkey in pairs(Lalolalo9AutoConstructionBuildingListLand) do
                                    if localindexkey == BuildingSuperchainContext then
                                        if Lalolalo9AutoconstructionPriorityGrouping == 0 then
                                            PriorityValue = 50000 - prioindexallland
                                            break
                                        else
                                            PriorityValue = 50000 - prioindexland
                                            break
                                        end
                                    end
                                end
                            end
                            if ((Lalolalo9AutoconstructionPriorityGrouping == 2) or (Lalolalo9AutoconstructionPriorityGrouping == 0)) then
        --                        lvlog("Cheking res")
                                for localindexres , localindexkey in pairs(Lalolalo9AutoConstructionBuildingListRes) do
        --                          lvlog("Index for " .. tostring(UniqueKey) .. " is " .. tostring(localindexland) .. " and chainket is " .. tostring(localindexkey))
                                    if localindexkey == BuildingSuperchainContext then
          --                              lvlog("Key and chain are the same")
                                        if Lalolalo9AutoconstructionPriorityGrouping == 0 then
                                            PriorityValue = 50000 - prioindexallres 
                          --                  lvlog("Setting PriorityValue to " .. tostring(prioindexallland))
                                            break
                                        else
                                            PriorityValue = 50000 - prioindexres
                                            break
                                        end
                                    end
                                end
                            end
				--			lvlog("Priority value for " .. tostring(UniqueKey) .. " is " .. tostring(PriorityValue))
							table.insert(SlotPrio,{UniqueKey,PriorityValue,CreateCost,BuildingToBuild,Unlocksonly})
							--[[
							if string.match(string.lower(BuildingSuperchainContext),"_port") then
					--			SlotsToUpgrade["Reg"..tostring(RegionRecord).."Slot"..tostring(BuildingSlotIndex).."Build"..tostring(BuildingLevelRecordKey)] = 2000
								table.insert(SlotPrio,{UniqueKey,2000,CreateCost,BuildingToBuild})
							end
				--			lvlog("PortCheck")
							if string.match(string.lower(BuildingSuperchainContext),"_special_") then
					--			SlotsToUpgrade["Reg"..tostring(RegionRecord).."Slot"..tostring(BuildingSlotIndex).."Build"..tostring(BuildingLevelRecordKey)] = 2000
								table.insert(SlotPrio,{UniqueKey,2100,CreateCost,BuildingToBuild})
							end
							
				--			lvlog("SpecialCheck")
							if string.match(string.lower(BuildingSuperchainContext),"_landmark") then
					--			SlotsToUpgrade["Reg"..tostring(RegionRecord).."Slot"..tostring(BuildingSlotIndex).."Build"..tostring(BuildingLevelRecordKey)] = 2000
								table.insert(SlotPrio,{UniqueKey,2100,CreateCost,BuildingToBuild})
							end
							
					--		lvlog("LandCheck")
							if common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeWithoutConversionsList.At("..PosIndex..").IsResourceBuilding") then
						--		SlotsToUpgrade["Reg"..tostring(RegionRecord).."Slot"..tostring(BuildingSlotIndex).."Build"..tostring(BuildingLevelRecordKey)] = 1900
								table.insert(SlotPrio,{UniqueKey,1800,CreateCost,BuildingToBuild})
							end
							
			--				lvlog("ResCheck")
							if string.match(string.lower(BuildingSuperchainContext),"_garrison") or string.match(string.lower(BuildingSuperchainContext),"_defence") or string.match(string.lower(BuildingSuperchainContext),"_walls") then
							--	SlotsToUpgrade["Reg"..tostring(RegionRecord).."Slot"..tostring(BuildingSlotIndex).."Build"..tostring(BuildingLevelRecordKey)] = 1800
								table.insert(SlotPrio,{UniqueKey,1900,CreateCost,BuildingToBuild})
							end
							
		--					lvlog("garCheck")
							
							
							
							if (not IsEmpty) then
                                table.insert(SlotPrio,{UniqueKey,0,CreateCost,BuildingToBuild})
							end
							]]
			--				lvlog("effeccheck")
						end
			--			local posibleupgradekey = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeWithoutConversionsList	.At("..PosIndex..").Key")
			--			local possibleupgradecontext = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeWithoutConversionsList	.At("..PosIndex..")")
			--			local possibleupgradecontextId = possibleupgradecontext:Call("GetContextObjectId")
			--			local possibleupgradecontextcachr = possibleupgradecontext:Call("ContextCacheId")
	--		--			lvlog("ContexCache" .. tostring(possibleupgradecontext))
	--		--			local IsRedundantDuplicate = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList.At("..PosIndex..")"):Call("IsRedundantDuplicate(FindContext(\"CcoCampaignSettlement\",\"" .. tostring(SettlementCQI) .. "\"))")
	---		--			local IsRedundantDuplicate = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList.At("..PosIndex..")"):Call("IsRedundantDuplicate(FindContext(\"" .. tostring(SettlementCQI) .. "\",\"CcoCampaignFaction\"))")
	--		--			local IsRsedundantDuplicate = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList.At("..PosIndex..").IsRedundantDuplicate(FindContext(\"" .. tostring(SettlementCQI) .. "\",\"CcoCampaignSettlement\"))")
			--			local IsRedundantDuplicate = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").PossibleUpgradeList(true).At("..PosIndex..").IsRedundantDuplicate(FindContext(\"CcoCampaignSettlement\",\"" .. tostring(possibleupgradecontextId) .. "\"))")
			--			lvlog("Can upgrade to " .. posibleupgradekey .. " " .. tostring(IsRedundantDuplicate))
					end
					table.sort(SlotPrio,function(a,b) return a[2] > b[2] end)
					for k,v in pairs(SlotPrio) do
                        --lvlog("Buildings considered for this slot at pos " .. tostring(k) .. " key is "  .. tostring(v[1]) .. " with prio " .. tostring(v[2]))
					end
					-- RegionCanUpgrade = true
					if BuildingsToExclude[1] == nil then
                 --       lvlog("First building")
                        if SlotPrio[1] ~= nil then
                                local key = SlotPrio[1]
					--	        lvlog("Settled for key is " .. tostring(key[1]) .. tostring(key[2]))         
                                table.insert(SlotsToUpgrade, {key[1], key[2],key[3]})
                                table.insert(BuildingsToExclude, key[4])
                                if key[5] then
                 --                   lvlog("Trygin to instert")
                                    table.insert(militarybuildingstoexclude[Provincekey],key[4])
                   --                 lvlog("Succesfully inserted")
                                end
                                
                            --for a, b in pairs(key) do
                            --	SlotsToUpgrade[a] = b
                            --	lvlog("a " .. tostring(a) .. " b " .. tostring(b))
                            --end
                        end
					else
                        for i , p in pairs(SlotPrio) do
                            local BuildingAlreadyAddedToQueue = false
              --              lvlog("Tyring to build second slot")
                            for j, q in pairs(BuildingsToExclude) do
                            --    lvlog("cheking similar building to " .. tostring(p[4]))
                                if q == p[4] then
                                    BuildingAlreadyAddedToQueue = true
                                    --lvlog("We already have " .. tostring(p[4]) .. " so not building")
                                    break
                                end
                            end
                      --      lvlog("The check is " .. tostring(BuildingAlreadyAddedToQueue))
                            if not BuildingAlreadyAddedToQueue then
		--				        lvlog("Key is " .. tostring(key[1]) .. tostring(key[2]))
                      --          lvlog("Second slot to build is " .. tostring(p[1]))
                                table.insert(SlotsToUpgrade, {p[1], p[2],p[3]})
                                table.insert(BuildingsToExclude, p[4])
                                if p[5] then
                                    table.insert(militarybuildingstoexclude[Provincekey],p[4])
                                end
                                break
                            --for a, b in pairs(key) do
                            --	SlotsToUpgrade[a] = b
                            --	lvlog("a " .. tostring(a) .. " b " .. tostring(b))
                            --end
                            end
                        end
					end
				end
			end
		end
		--for i,p in pairs(BuildingsToExclude) do
        --    lvlog(" exluded buidling " .. tostring(p))
		--end
	end
	--lvlog("Srtarting sorting peio")
	local MinMoneyToKeep = (1 - budgetPerc) * faction:treasury()
	local WouldBeMoney = faction:treasury()
	--lvlog("MinMoneyToKeep" .. tostring(MinMoneyToKeep))
	--lvlog("WouldBeMoney" .. tostring(WouldBeMoney))
	--for i, p in pairs(SlotsToUpgrade) do
     --   lvlog("Just iterating")
	--	lvlog("Not sorted " .. i .. " " .. tostring(p) .. " to " .. tostring(p[1]) .. " " .. tostring(p[2]))
	--end
	--lvlog("end of iterating")
	table.sort(SlotsToUpgrade, function(a,b) return a[2] > b[2] end)
	--lvlog("after sort")
	for i, p in ipairs(SlotsToUpgrade) do
     --   lvlog("Iterating final step")
--	lvlog("Sorted " .. i .. " " .. tostring(p) .. " to " .. tostring(p[1]) .. " " .. tostring(p[2]) .. " with cost " .. tostring(p[3]))
		if WouldBeMoney - p[3] > MinMoneyToKeep then
			CampaignUI.TriggerCampaignScriptEvent(0,tostring(p[1]))
			WouldBeMoney = WouldBeMoney - p[3]
	--		lvlog("Constructing " .. p[1])
		end
	end
end

local function Lalolalo9_BuildingBrowserMaker()
     --   lvlog("Creating buildingSortOrderList")
    local globalPrioListToUse = {}
    if Lalolalo9AutoconstructionPriorityGrouping == 0 then
        globalPrioListToUse = Lalolalo9AutoConstructionPriorityListGroupedAll
    elseif Lalolalo9AutoconstructionPriorityGrouping == 1 then
        globalPrioListToUse = Lalolalo9AutoConstructionPriorityListGroupedLand
    elseif Lalolalo9AutoconstructionPriorityGrouping == 2 then
        globalPrioListToUse = Lalolalo9AutoConstructionPriorityListGroupedRes
    else
        globalPrioListToUse = Lalolalo9AutoConstructionPriorityList
    end
    if Lalolalo9_AutoConstruction_Building_Browser ~= nil then
        Lalolalo9_AutoConstruction_Building_Browser = nil
    end
    Lalolalo9_AutoConstruction_Building_Browser = core:get_or_create_component("Lalolalo9_AutoConstruction_Building_Browser","ui/templates/panel_frame.twui.xml")
  --      lvlog(tostring(Lalolalo9.ItemShopMenu))
    if Lalolalo9_AutoConstruction_Building_Browser ~= nil and Lalolalo9_AutoConstruction_Building_Browser:IsValid() then
        Lalolalo9_AutoConstruction_Building_Browser:SetVisible(true)
        Lalolalo9_AutoConstruction_Building_Browser:SetCanResizeWidth(true)
        Lalolalo9_AutoConstruction_Building_Browser:SetCanResizeHeight(true)
        local xscreen, yscreen = core:get_ui_root():Dimensions()
        local x, y = Lalolalo9_AutoConstruction_Building_Browser:Dimensions()
        --if x == tonumber(tonumber(xscreen) * 9 / 10) and y == tonumber(tonumber(yscreen) * 9 / 10) then
        --else
          --  Lalolalo9_AutoConstruction_Building_Browser:Resize(tonumber(xscreen * 9 / 10), tonumber(yscreen * 9 / 10),true)
        --end
        Lalolalo9_AutoConstruction_Building_Browser:Resize(tonumber(xscreen * 9 / 10), tonumber(yscreen * 9 / 10),true)
        Lalolalo9_AutoConstruction_Building_Browser:ResizeCurrentStateImage(0,tonumber(xscreen * 9 / 10), tonumber(yscreen * 9 / 10))
        
        Lalolalo9_AutoConstruction_Building_Browser:ResizeCurrentStateImage(1,tonumber(xscreen * 9 / 10), tonumber(yscreen * 9 / 10))
        
        x, y = Lalolalo9_AutoConstruction_Building_Browser:Dimensions()
        Lalolalo9_AutoConstruction_Building_Browser:SetMoveable(true)
        Lalolalo9_AutoConstruction_Building_Browser:MoveTo(tonumber((xscreen - x)/2),tonumber((yscreen - y)/2))
        Lalolalo9_AutoConstruction_Building_Browser:SetMoveable(false)
        local ListHeaderbuildingbrowser =  UIComponent(Lalolalo9_AutoConstruction_Building_Browser:CreateComponent("Priority","ui/common ui/text_pointer_text_only.twui.xml"))
        local headertextbuildingbrowser = find_child_uicomponent(ListHeaderbuildingbrowser,"text")
        local budgetPerc = (common.get_context_value("CcoCampaignFaction",Lalolalo9AutoConstructionPlayerFaction:cqi(),"AutoManagementBudgetPercentage") or 0)         
        if budgetPerc == 0 then
            headertextbuildingbrowser:SetText("Priority - Beware no budget set! Please do so in treasury!!")
        else
            headertextbuildingbrowser:SetText("Priority - budget is: " .. tostring(budgetPerc *  Lalolalo9AutoConstructionPlayerFaction:treasury()) )
        end
        ListHeaderbuildingbrowser:MoveTo(tonumber(xscreen * 1 / 10), tonumber(yscreen * 8 / 100))
        local listSizeX = tonumber(xscreen * 8 / 10)
        local listSizeY = tonumber(yscreen * 8 / 10 - 60)
        local bottomconfigXSize = listSizeX * 3 / 4
        local BottomConfigHolder = UIComponent(Lalolalo9_AutoConstruction_Building_Browser:CreateComponent("BottomConfigHolder","ui/templates/panel_frame.twui.xml"))
        BottomConfigHolder:SetDockingPoint(8)
        BottomConfigHolder:Resize(bottomconfigXSize,80)
        BottomConfigHolder:SetDockOffset(tonumber(xscreen * -1 / 10),0)
        BottomConfigHolder:SetCurrentStateImageOpacity(0,0)
        BottomConfigHolder:SetCurrentStateImageOpacity(1,0) 
        local BottomEnablerHolder = UIComponent(Lalolalo9_AutoConstruction_Building_Browser:CreateComponent("BottomEnablerHolder","ui/templates/panel_frame.twui.xml"))
        BottomEnablerHolder:SetDockingPoint(9)
        BottomEnablerHolder:Resize(tonumber( bottomconfigXSize / 3) ,80)
        BottomEnablerHolder:SetDockOffset(0,0)
        BottomEnablerHolder:SetCurrentStateImageOpacity(0,0)
        BottomEnablerHolder:SetCurrentStateImageOpacity(1,0)
        local EnableConstructButton = UIComponent(BottomEnablerHolder:CreateComponent("Lalolalo9_Autoconstruction_EnableConstructButton","ui/templates/round_large_button.twui.xml"))
        --ui/skins/default/icon_check_green.png)
        EnableConstructButton:SetDockingPoint(4)
        EnableConstructButton:SetImagePath("ui/skins/default/icon_check_green.png")
        EnableConstructButton:SetTooltipText("Enable with chosen settings","Enable with chosen settings",true)
        local DisableConstructButton = UIComponent(BottomEnablerHolder:CreateComponent("Lalolalo9_Autoconstruction_DisableConstructButton","ui/templates/round_medium_button.twui.xml"))
        -- ui/skins/default/icon_cross_square_red.png
        DisableConstructButton:SetDockingPoint(5)
        DisableConstructButton:SetImagePath("ui/skins/default/icon_cross_square_red.png")
        DisableConstructButton:SetTooltipText("Click to turn off everything","Click to turn off everything",true)
        local UpgradeConstructConfig = UIComponent(BottomConfigHolder:CreateComponent("Lalolalo9_AutoConstruction_Upgrade_Construct_Config","ui/templates/square_medium_text_tab_toggle.twui.xml"))
        for stateindex = 0, UpgradeConstructConfig:NumStates() do
       --     lvlog("State " .. tostring(stateindex) .. " is " .. tostring(UpgradeConstructConfig:GetStateByIndex(stateindex)))
        end
        --bottomitem:MoveTo(tonumber(xscreen * 5 / 10), tonumber(yscreen * 9 / 100))
        UpgradeConstructConfig:SetDockingPoint(4)
        UpgradeConstructConfig:SetState("active")
        
        UpgradeConstructConfig:SetTextXOffset(20,0)
        UpgradeConstructConfig:SetTextYOffset(10,0)
        UpgradeConstructConfig:SetStateText("Buildings autoupgrade and autoconstruct","Buildings autoupgrade and autoconstruct")
        UpgradeConstructConfig:SetState("hover")
        
        UpgradeConstructConfig:SetTextXOffset(20,0)
        UpgradeConstructConfig:SetTextYOffset(10,0)
        UpgradeConstructConfig:SetStateText("Buildings autoupgrade and autoconstruct","Buildings autoupgrade and autoconstruct")
        UpgradeConstructConfig:SetTooltipText("Click to set to autoupgrade only","Click to set to autoupgrade only",false)
        UpgradeConstructConfig:SetState("selected")
        UpgradeConstructConfig:SetStateText("Buildings only autoupgrade","Buildings only autoupgrade")
        
        UpgradeConstructConfig:SetTextXOffset(20,0)
        UpgradeConstructConfig:SetTextYOffset(10,0)
        UpgradeConstructConfig:SetState("selected_hover")
        UpgradeConstructConfig:SetStateText("Buildings only autoupgrade","Buildings only autoupgrade")
        UpgradeConstructConfig:SetTooltipText("Click to set to autoupgrade and construction","Click to set to autoupgrade and construction",false)
        UpgradeConstructConfig:SetTextXOffset(20,0)
        UpgradeConstructConfig:SetTextYOffset(10,0)
        local startendconfig = UIComponent(BottomConfigHolder:CreateComponent("Lalolalo9_AutoConstruction_Start_End_Config","ui/templates/square_medium_text_tab_toggle.twui.xml"))
        --bottomitem:MoveTo(tonumber(xscreen * 5 / 10), tonumber(yscreen * 9 / 100))
        startendconfig:SetDockingPoint(5)
        startendconfig:SetState("active")
        startendconfig:SetStateText("Build at the start of turn","Build at the start of turn")
        startendconfig:SetTextXOffset(20,0)
        startendconfig:SetTextYOffset(10,0)
        startendconfig:SetState("hover")
        startendconfig:SetStateText("Build at the start of turn","Build at the start of turn")
        startendconfig:SetTextXOffset(20,0)
        startendconfig:SetTextYOffset(10,0)
        startendconfig:SetTooltipText("Click to build at the end of the turn","Click to build at the end of the turn",false)
        startendconfig:SetState("selected")
        startendconfig:SetStateText("Build at the end of turn","Build at the end of turn")
        startendconfig:SetTextXOffset(20,0)
        startendconfig:SetTextYOffset(10,0)
        startendconfig:SetState("selected_hover")
        startendconfig:SetStateText("Build at the end of turn","Build at the end of turn")
        startendconfig:SetTextXOffset(20,0)
        startendconfig:SetTextYOffset(10,0)
        startendconfig:SetTooltipText("Click to build at the start of the turn","Click to build at the start of the turn",false)
        local BuildingGroupConfig = UIComponent(BottomConfigHolder:CreateComponent("BottomConfigHolder","ui/templates/panel_frame.twui.xml"))
        BuildingGroupConfig:SetDockingPoint(6)
        BuildingGroupConfig:Resize(tonumber(bottomconfigXSize) / 3,90)
        --BuildingGroupConfig:SetDockOffset(tonumber(xscreen * -1 / 10),0)
        BuildingGroupConfig:SetCurrentStateImageOpacity(0,0)
        BuildingGroupConfig:SetCurrentStateImageOpacity(1,0)
        local ResourceGroupConfig = UIComponent(BuildingGroupConfig:CreateComponent("Lalolalo9_AutoConstruction_Resource_Group_Config","ui/templates/square_medium_text_tab_toggle.twui.xml"))
        --bottomitem:MoveTo(tonumber(xscreen * 5 / 10), tonumber(yscreen * 9 / 100))
        ResourceGroupConfig:SetDockingPoint(2)
        ResourceGroupConfig:SetState("active")
        ResourceGroupConfig:SetStateText("Grouping resource buildings","Grouping resource buildings")
        ResourceGroupConfig:SetTextXOffset(20,0)
        ResourceGroupConfig:SetTextYOffset(10,0)
        ResourceGroupConfig:SetState("hover")
        ResourceGroupConfig:SetStateText("Grouping resource buildings","Grouping resource buildings")
        ResourceGroupConfig:SetTextXOffset(20,0)
        ResourceGroupConfig:SetTextYOffset(10,0)
        ResourceGroupConfig:SetTooltipText("Click to ungroup resource buildings","Click to ungroup resource buildings",false)
        ResourceGroupConfig:SetState("selected")
        ResourceGroupConfig:SetStateText("Ungrouped resource buildings","Ungrouped resource buildings")
        ResourceGroupConfig:SetTextXOffset(20,0)
        ResourceGroupConfig:SetTextYOffset(10,0)
        ResourceGroupConfig:SetState("selected_hover")
        ResourceGroupConfig:SetStateText("Ungrouped resource buildings","Ungrouped resource buildings")
        ResourceGroupConfig:SetTextXOffset(20,0)
        ResourceGroupConfig:SetTextYOffset(10,0)
        ResourceGroupConfig:SetTooltipText("Click to group resource buildings","Click to group resource buildings",false)
        
        local LandmarkGroupConfig = UIComponent(BuildingGroupConfig:CreateComponent("Lalolalo9_AutoConstruction_Landmark_Group_Config","ui/templates/square_medium_text_tab_toggle.twui.xml"))
        --bottomitem:MoveTo(tonumber(xscreen * 5 / 10), tonumber(yscreen * 9 / 100))
        LandmarkGroupConfig:SetDockingPoint(8)
        LandmarkGroupConfig:SetState("active")
        LandmarkGroupConfig:SetStateText("Grouping landmarks","Grouping landmarks")
        LandmarkGroupConfig:SetTextXOffset(20,0)
        LandmarkGroupConfig:SetTextYOffset(10,0)
        LandmarkGroupConfig:SetState("hover")
        LandmarkGroupConfig:SetStateText("Grouping landmarks","Grouping landmarks")
        LandmarkGroupConfig:SetTextXOffset(20,0)
        LandmarkGroupConfig:SetTextYOffset(10,0)
        LandmarkGroupConfig:SetTooltipText("Click to ungroup landmarks","Click to ungroup landmarks",false)
        LandmarkGroupConfig:SetState("selected")
        LandmarkGroupConfig:SetStateText("Ungrouped landmarks","Ungrouped landmarks")
        LandmarkGroupConfig:SetTextXOffset(20,0)
        LandmarkGroupConfig:SetTextYOffset(10,0)
        LandmarkGroupConfig:SetState("selected_hover")
        LandmarkGroupConfig:SetStateText("Ungrouped landmarks","Ungrouped landmarks")
        LandmarkGroupConfig:SetTextXOffset(20,0)
        LandmarkGroupConfig:SetTextYOffset(10,0)
        LandmarkGroupConfig:SetTooltipText("Click to group landmarks","Click to group landmarks",false)
        
        local listview = core:get_or_create_component("listview","ui/templates/listview.twui.xml",Lalolalo9_AutoConstruction_Building_Browser)
        listview:SetCanResizeWidth(true)
        listview:SetCanResizeHeight(true)
        listview:Resize(listSizeX,listSizeY)
        --listview:SetMoveable(true)
        listview:SetDockingPoint(8)
        --listview:SetMoveable(false)
        local list_clip = core:get_or_create_component("list_clip","",listview)
        list_clip:SetCanResizeWidth(true)
        list_clip:SetCanResizeHeight(true)
        list_clip:Resize(listSizeX - 10,listSizeY - 10)
        listview:SetDockingPoint(5)
        list_clip:SetDockingPoint(5)
        local list_box = core:get_or_create_component("list_box","",list_clip)
        list_box:SetCanResizeWidth(true)
        list_box:SetCanResizeHeight(true)
        list_box:Resize(listSizeX - 10,listSizeY - 10)
        list_box:DestroyChildren()
        if Lalolalo9AutoConstructionAutoConstructAutoupgrade == 1 then
            UpgradeConstructConfig:SetState("selected")
        else
            UpgradeConstructConfig:SetState("active")
        end
        if Lalolalo9_AutoConstruction_Start_End_Config == 1 then
            startendconfig:SetState("selected")
        else
            startendconfig:SetState("active")
        end
                -- Lalolalo9AutoconstructionPriorityGrouping 0 both grouped
            -- 1 land is grouped
            -- 2 resourse is grouped
            -- all the rest are ungrouped
        if Lalolalo9AutoconstructionPriorityGrouping == 0 then
            ResourceGroupConfig:SetState("active")
            LandmarkGroupConfig:SetState("active")
        elseif Lalolalo9AutoconstructionPriorityGrouping == 1 then
            LandmarkGroupConfig:SetState("active")
            ResourceGroupConfig:SetState("selected")
        elseif Lalolalo9AutoconstructionPriorityGrouping == 2 then
            LandmarkGroupConfig:SetState("selected")
            ResourceGroupConfig:SetState("active")
        else
            ResourceGroupConfig:SetState("selected")
            LandmarkGroupConfig:SetState("selected")
        end
        --[[
        
        local panelhor = core:get_or_create_component("lalolalo9panelhor","ui/templates/panel_slider_horizontal.twui.xml",Lalolalo9_AutoConstruction_Building_Browser)
        panelhor:SetCanResizeWidth(true)
        panelhor:SetCanResizeHeight(true)
        panelhor:Resize(listSizeX,listSizeY)
        panelhor:SetDockingPoint(8)
        ]]
        local TextXValue = tonumber(xscreen * 8/ 60 - 5)
        local TextYValue = tonumber(yscreen * 1 / 8 - 17)
        local Lalolalo9AutoConstructionPriorityListSize = 0
        for i, p in pairs(globalPrioListToUse) do
            Lalolalo9AutoConstructionPriorityListSize = Lalolalo9AutoConstructionPriorityListSize + 1
        end
        for i, p in pairs(globalPrioListToUse) do
            local KeySubsitute = p
           -- lvlog("Building index is "  .. tostring(i) )
           -- lvlog("Building Key is " .. tostring(p) )
            local PriorityBuidings = core:get_or_create_component("Lalolalo9_BuildingNumber_" .. tostring(i),"ui/templates/panel_frame.twui.xml",list_box)
            PriorityBuidings:SetCanResizeWidth(true)
            PriorityBuidings:SetCanResizeHeight(true)
            PriorityBuidings:Resize(tonumber(xscreen * 31/ 40), tonumber(yscreen * 1 / 8),false)
            PriorityBuidings:SetDockOffset(0,0)
            PriorityBuidings:SetDockingPoint(4)
            local interfacereadjust = core:get_or_create_component("UIPrettifier","ui/templates/panel_frame.twui.xml",PriorityBuidings)
            interfacereadjust:SetCanResizeWidth(true)
            interfacereadjust:SetCanResizeHeight(true)
            interfacereadjust:Resize(tonumber(xscreen * 31/ 80), tonumber(yscreen * 1 / 8),false)
            interfacereadjust:SetDockOffset(0,0)
            interfacereadjust:SetDockingPoint(4)
            interfacereadjust:SetCurrentStateImageOpacity(0,0)
            interfacereadjust:SetCurrentStateImageOpacity(1,0)
            local PriorityNumber = UIComponent(interfacereadjust:CreateComponent("Priority","ui/common ui/text_pointer_text_only.twui.xml"))
            PriorityNumber:SetCanResizeWidth(true)
            PriorityNumber:SetCanResizeHeight(true)
            PriorityNumber:Resize(TextXValue, TextYValue)
            PriorityNumber:SetDockOffset(0,0)
            PriorityNumber:SetDockingPoint(4)
            PriorityNumber:SetCurrentStateImageOpacity(0,0)
            local prioritytext = find_child_uicomponent(PriorityNumber,"text")
             
            prioritytext:SetText(tostring(i) .. ".")
            local TextPanel1 = UIComponent(interfacereadjust:CreateComponent("Name","ui/common ui/text_pointer_text_only.twui.xml"))
            -- local TextPanel1 = core:get_or_create_component("Text_Panel1","ui/common ui/text_box.twui.xml",PriorityBuidings)
            TextPanel1:SetCanResizeWidth(true)
            TextPanel1:SetCanResizeHeight(true)
            TextPanel1:Resize(TextXValue, TextYValue)
            TextPanel1:SetDockOffset(0,0)
            TextPanel1:SetDockingPoint(5)
            
            local nametosetofbuilding = find_child_uicomponent(TextPanel1,"text")
       --     lvlog("Succesfully set name to " .. tostring(p) )
           -- PriorityBuidings:SetDockingPoint(7)
            --local buildingpanel = UIComponent(PriorityBuidings:CreateComponent("Lalolalo9_Building_" .. tostring(p),"ui/campaign ui/building_information.twui.xml"))
            --local buildingpanel = UIComponent(PriorityBuidings:CreateComponent("Lalolalo9_Building_" .. tostring(p),"ui/templates/building_frame.twui.xml"))-
            ---buildingpanel:SetContextObject(cco("CcoBuildingLevelRecord","wh3_main_ogr_settlement_major_1"))
            --find_child_uicomponent(buildingpanel,"square_building_button"):SetContextObject(cco("CcoBuildingLevelRecord","wh3_main_ogr_settlement_major_1"))
            --find_child_uicomponent(buildingpanel,"known_parent"):SetContextObject(cco("CcoBuildingLevelRecord","wh3_main_ogr_settlement_major_1"))
            
            if Lalolalo9AutoconstructionPriorityGrouping == 0 then
                if (p == "Lalolalo9LandChainGroup") then
                    KeySubsitute = Lalolalo9AutoConstructionBuildingListLand[1]
                elseif (p == "Lalolalo9ResourceChainGroup") then
                    KeySubsitute = Lalolalo9AutoConstructionBuildingListRes[1]
                end
            elseif Lalolalo9AutoconstructionPriorityGrouping == 1 then
                if (p == "Lalolalo9LandChainGroup") then
                    KeySubsitute = Lalolalo9AutoConstructionBuildingListLand[1]
                end
            elseif Lalolalo9AutoconstructionPriorityGrouping == 2 then
                if (p == "Lalolalo9ResourceChainGroup") then
                    KeySubsitute = Lalolalo9AutoConstructionBuildingListRes[1]
                end
            end
   --         lvlog("Key " .. tostring(p) .. " becomes " .. tostring(KeySubsitute))
            local LevelZeroBuilding = common.get_context_value("DatabaseRecordContext(\"CcoBuildingChainRecord\",\"" .. tostring(KeySubsitute) ..  "\").LevelZeroBuildingLevelContext.Key")
            
            local LevelZeroBuildingLevel = common.get_context_value("DatabaseRecordContext(\"CcoBuildingChainRecord\",\"" .. tostring(KeySubsitute) ..  "\").LevelZeroBuildingLevelContext.Level")
    --        lvlog("Building level is " .. tostring(LevelZeroBuildingLevel))
            
            local maxlevelbuildinglevel =LevelZeroBuildingLevel
            local maxlevelbuilding = common.get_context_value("DatabaseRecordContext(\"CcoBuildingChainRecord\",\"" .. tostring(KeySubsitute) ..  "\").LevelZeroBuildingLevelContext.Key")
            for localbuildingrecordcounter = 0 , common.get_context_value("DatabaseRecordContext(\"CcoBuildingChainRecord\",\"" .. tostring(KeySubsitute) ..  "\").LevelsList.Size") - 1 do 
                local localbuildingrecord =  common.get_context_value("DatabaseRecordContext(\"CcoBuildingChainRecord\",\"" .. tostring(KeySubsitute) ..  "\").LevelsList.At(" .. localbuildingrecordcounter .. ").Key")
                local localbuildingrecordlevel =  common.get_context_value("DatabaseRecordContext(\"CcoBuildingChainRecord\",\"" .. tostring(KeySubsitute) ..  "\").LevelsList.At(" .. localbuildingrecordcounter .. ").Level")
                if localbuildingrecordlevel > maxlevelbuildinglevel then
                    maxlevelbuildinglevel = localbuildingrecordlevel
                    maxlevelbuilding = localbuildingrecord
                end
            end
            local CultureBuildingCCORecordIcon = common.get_context_value("DatabaseRecordContext(\"CcoBuildingLevelRecord\",\"" .. tostring(maxlevelbuilding) .. "\").PlayerVariantRecordContext.Icon")
            if (p == "Lalolalo9LandChainGroup") then
                nametosetofbuilding:SetText(common.get_localised_string("uied_component_texts_localised_string_StateText_f2661fd0"))
            elseif (p == "Lalolalo9ResourceChainGroup") then 
                nametosetofbuilding:SetText(common.get_localised_string("campaign_localised_strings_string_public_order_resources"))
            else
                nametosetofbuilding:SetText(common.get_localised_string("building_chains_chain_tooltip_" .. tostring(KeySubsitute)))
            end
            
            -- local buildingpanel = UIComponent(PriorityBuidings:CreateComponent("Icon","ui/common ui/text_pointer_text_only.twui.xml"))
            local buildingpanel = UIComponent(interfacereadjust:CreateComponent("IconB","ui/common ui/tooltip_text_and_icon.twui.xml"))
            
            buildingpanel:DestroyChildren()
 --           lvlog("Created icon")
   --         lvlog(tostring(CultureBuildingCCORecordIcon))
            buildingpanel:SetCanResizeWidth(true)
            buildingpanel:SetCanResizeHeight(true)
            buildingpanel:Resize(74,74)
            buildingpanel:SetDockOffset(0,0)
            buildingpanel:SetDockingPoint(6)
            local iconwithtexuit = UIComponent(buildingpanel:CreateComponent("IconForeground","ui/common ui/tooltip_text_and_icon.twui.xml"))
            iconwithtexuit:SetVisible(true)
            iconwithtexuit:SetCanResizeWidth(true)
            iconwithtexuit:SetCanResizeHeight(true)
            iconwithtexuit:Resize(74,74)
            iconwithtexuit:SetImagePath(CultureBuildingCCORecordIcon,0,true)
            
            --iconwithtexuit:ResizeTextResizingComponentToInitialSize(74,74)
            iconwithtexuit:SetDockOffset(0,0)
            iconwithtexuit:SetDockingPoint(5)
            
            iconwithtexuit:DestroyChildren()
            --buildingpanel:SetImagePath(CultureBuildingCCORecordIcon,1,true)
            buildingpanel:SetImagePath("ui/skins/default/building_frame.png",0,true)
            
            buildingpanel:SetCurrentStateImageDockingPoint(0,5)
            iconwithtexuit:SetCurrentStateImageDockingPoint(0,5)
            buildingpanel:SetCurrentStateImageDockOffset(0,0,0)
            iconwithtexuit:SetCurrentStateImageDockOffset(0,0,0)
            buildingpanel:SetCurrentStateImageTiled(0,false)
            iconwithtexuit:SetCurrentStateImageTiled(0,false)
            buildingpanel:SetCurrentStateImageOpacity(0,255)
            iconwithtexuit:SetCurrentStateImageOpacity(0,255)
            buildingpanel:SetVisible(true)
         --   lvlog("State is" .. tostring(buildingpanel:CurrentState()))
            
            local movebuttonholder = core:get_or_create_component("movebuttonholder","ui/templates/panel_frame.twui.xml",PriorityBuidings)
            movebuttonholder:SetCanResizeWidth(true)
            movebuttonholder:SetCanResizeHeight(true)
            movebuttonholder:Resize(tonumber(xscreen * 31/ 80), tonumber(yscreen * 1 / 10),false)
            movebuttonholder:SetDockOffset(0,0)
            movebuttonholder:SetDockingPoint(6)
            movebuttonholder:SetCurrentStateImageOpacity(0,0)
            movebuttonholder:SetCurrentStateImageOpacity(1,0)
            if i > 1 then
                local arrowup = core:get_or_create_component("Lalolalo9_AutoConstruction_Building_Browser_Priority_Change_" .. tostring(i) .. "_UP" ,"ui/templates/cycle_button_arrow_previous.twui.xml",movebuttonholder)
                arrowup:SetDockingPoint(2)
                for imageindex = 0 , arrowup:NumImages() do
                    arrowup:SetImageRotation(imageindex,1.5708)
                end
                local flame = find_child_uicomponent(arrowup,"button_flame")
                flame:SetImageRotation(0,1.5708)
                arrowup:SetTooltipText("Move priority higher","Move priority higher",true)
            end
            if i ~= Lalolalo9AutoConstructionPriorityListSize then 
                local arrowdown = core:get_or_create_component("Lalolalo9_AutoConstruction_Building_Browser_Priority_Change_" .. tostring(i) .. "_DO" ,"ui/templates/cycle_button_arrow_next.twui.xml",movebuttonholder)
                arrowdown:SetDockingPoint(8)
                for imageindex = 0 , arrowdown:NumImages() do
                    arrowdown:SetImageRotation(imageindex,1.5708)
                end
                local flame = find_child_uicomponent(arrowdown,"button_flame")
                flame:SetImageRotation(0,1.5708)
                arrowdown:SetTooltipText("Move priority lower","Move priority lower",true)
            end
            
            --buildingpanel:SetState("newstate")
            --if i > 5 then
            --break
            --end
           -- PriorityBuidings:SetDockingPoint(4)
           
            
            --local buildingpanel = core:get_or_create_component("Lalolalo9_Building_" .. tostring(p),"ui/templates/ui/templates/building_frame.twui.xml",PriorityBuidings)
        
        end
        --[[    local header_list = core:get_or_create_component("header_list","",Lalolalo9.ItemShopMenu)
            header_list:SetDockingPoint(2)
            header_list:SetDockOffset(0,15)
            local categoryNumber = 0
            for a, b in pairs(ancillary_list) do
                categoryNumber = categoryNumber + 1
            end
            for a, b in pairs(ancillary_list) do
                local childa = core:get_or_create_component("Lalolalo9ItemShop_header_" .. tostring(a),"ui/templates/square_large_text_button.twui.xml",header_list)
                local Headertext = UIComponent(childa:Find("button_txt"))
                childa:SetCanResizeHeight(false)
                childa:SetCanResizeWidth(true)
                childa:Resize(tonumber( xscreen * 9 / 10 / categoryNumber),20)
                Headertext:SetText(common.get_localised_string("ancillaries_categories_onscreen_name_" .. tostring(a)))
            end
            local listSizeX = tonumber(xscreen * 8 / 10)
            local listSizeY = tonumber(yscreen * 8 / 10 - 40)
            local listview = core:get_or_create_component("listview","ui/templates/listview.twui.xml",Lalolalo9.ItemShopMenu)
            listview:SetCanResizeWidth(true)
            listview:SetCanResizeHeight(true)
            listview:Resize(listSizeX,listSizeY)
            listview:SetDockingPoint(8)
            local list_clip = core:get_or_create_component("list_clip","",listview)
            list_clip:SetCanResizeWidth(true)
            list_clip:SetCanResizeHeight(true)
            list_clip:Resize(listSizeX - 10,listSizeY - 10)
            listview:SetDockingPoint(5)
            list_clip:SetDockingPoint(5)
            local list_box = core:get_or_create_component("list_box","",list_clip)
            list_box:SetCanResizeWidth(true)
            list_box:Resize(listSizeX - 10,listSizeY - 10)
            list_box:DestroyChildren()
            for category, rarities in pairs(ancillary_list) do
                for rarity, itemtable in pairs(rarities) do
                    for key , price in pairs(itemtable) do
                        local ItemCCORecordAncillarty = common.get_context_value("DatabaseRecordContext(\"CcoAncillaryRecord\",\"" .. key .. "\")")
                        local localitemname = common.get_context_value("CcoAncillaryRecord",key,"OnscreenName")
                        local itempanel = core:get_or_create_component("Lalolalo9_ItemShop_Item_" .. tostring(key),"ui/templates/Lalolalo9panel_frame.twui.xml",list_box)
                        itempanel:SetVisible(true)
                        itempanel:SetCanResizeHeight(true)
                        itempanel:SetCanResizeWidth(true)
                        itempanel:Resize(tonumber(xscreen * 31/ 40), tonumber(yscreen * 1 / 8),false)
                        itempanel:SetDockingPoint(5)
                        local icon_item = core:get_or_create_component("icon_item","ui/templates/Lalolalo9ItemEntry.twui.xml",itempanel)
                        icon_item:SetContextObject(ItemCCORecordAncillarty)
                        icon_item:SetDockingPoint(4)
                        icon_item:SetVisible(true)
                        local equipment_items_frame = core:get_or_create_component("equipment_items_frame","",icon_item)
                        equipment_items_frame:SetVisible(true)
                        local TextXValue = tonumber(xscreen * 8/ 60 - 5)
                        local TextYValue = tonumber(yscreen * 1 / 8 - 17)
                        local TextPanel1 = UIComponent(itempanel:CreateComponent("Text_Panel1","ui/templates/panel_frame.twui.xml"))
                        TextPanel1:Resize(TextXValue, TextYValue)
                        TextPanel1:SetOpacity(0)
                        local TextPanel2 = UIComponent(itempanel:CreateComponent("Text_Panel2","ui/templates/panel_frame.twui.xml"))
                        TextPanel2:Resize(TextXValue, TextYValue)
                        TextPanel2:SetOpacity(0)
                        local TextPanel3 = UIComponent(itempanel:CreateComponent("Text_Panel3","ui/templates/panel_frame.twui.xml"))
                        TextPanel3:Resize(TextXValue, TextYValue)
                        TextPanel3:SetOpacity(0)
                        local XOffset = 0
                        local effectsSize = common.get_context_value("CcoAncillaryRecord",key,"EffectList.Size")
                        for el = 0 , effectsSize - 1 do
                            local effectrecord = common.get_context_value("CcoAncillaryRecord",key,"EffectList.At(" .. el .. ").EffectKey")
                            local loclarti = common.get_context_value("CcoAncillaryRecord",key,"EffectList.At(".. el ..").LocalisedText")
                            local value = common.get_context_value("CcoAncillaryRecord",key,"EffectList.At(".. el ..").Value")
                            local iconpath = common.get_context_value("CcoAncillaryRecord",key,"EffectList.At(".. el ..").IconPath")
                            local ChooseTextPanel = math.ceil((el+1) / 2)
                            local effectslist = ""
                            if el > 6 then
                                if (el % 3) == 0 then
                                    effectslist = UIComponent(TextPanel1:CreateComponent("effect_" .. (el),"ui/templates/effect_entry.twui.xml"))
                                elseif (el % 3) == 1 then
                                effectslist = UIComponent(TextPanel2:CreateComponent("effect_" .. (el),"ui/templates/effect_entry.twui.xml"))
                                else
                                    effectslist = UIComponent(TextPanel3:CreateComponent("effect_" .. (el),"ui/templates/effect_entry.twui.xml"))
                                end
                            else
                                if (ChooseTextPanel % 3) == 1 then
                                    effectslist = UIComponent(TextPanel1:CreateComponent("effect_" .. (el),"ui/templates/effect_entry.twui.xml"))
                                elseif (ChooseTextPanel % 3) == 2 then
                                    effectslist = UIComponent(TextPanel2:CreateComponent("effect_" .. (el),"ui/templates/effect_entry.twui.xml"))
                                else
                                    effectslist = UIComponent(TextPanel3:CreateComponent("effect_" .. (el),"ui/templates/effect_entry.twui.xml"))
                                end
                            end
                            local effectCCO = common.get_context_value("CcoAncillaryRecord",key,"EffectList.At(" .. el .. ")")
                            effectslist:SetContextObject(effectCCO)
                            if el % 2 == 0 then
                                effectslist:SetDockingPoint(2)
                            else
                                effectslist:SetDockingPoint(8)
                            end
                            if el > 5 then 
                                effectslist:SetDockingPoint(5)
                            end
                            effectslist:SetDockOffset(30,0)
                        end
                        local PurchaseButton = core:get_or_create_component("Lalolalo9PurchaseButton_" .. key,"ui/templates/square_large_text_button.twui.xml",itempanel)
                        PurchaseButton:SetDockingPoint(6)
                        local PurchaseButtonText = core:get_or_create_component("button_txt","ui/templates/square_large_text_button.twui.xml",PurchaseButton)
                        PurchaseButtonText:SetText(common.get_localised_string("campaign_localised_strings_string_beastmen_panel_button_purchase") .." : " .. price)
                    end
                end
            end]]
            end
end

local function Lalolalo9_AutoconstructionCloseListeners()
    core:remove_listener("Lalolalo9AutoConstructionPlayerFactionAboutToStartTurn")
    core:remove_listener("Lalolalo9AutoConstructionPlayerFactionAboutToEndTurn")
end


local function Lalolalo9_AutoConstruction_ListenerStarterEndTurn()
    core:add_listener(
        "Lalolalo9AutoConstructionPlayerFactionAboutToEndTurn",
        "FactionAboutToEndTurn",
        function (context)
            return tostring(context:faction():command_queue_index()) == tostring(Lalolalo9AutoConstructionPlayerFaction:command_queue_index())
        end,
        function (context)
            Lalolalo9_Add_Buildings_To_Queue(Lalolalo9AutoConstructionPlayerFaction)
  --          lvlog("Should have added a building")
        end,
        true
    )
end


local function Lalolalo9_AutoConstruction_ListenerStarterStartTurn()
    core:add_listener(
        "Lalolalo9AutoConstructionPlayerFactionAboutToStartTurn",
        "FactionTurnStart",
        function (context)
            return tostring(context:faction():command_queue_index()) == tostring(Lalolalo9AutoConstructionPlayerFaction:command_queue_index())
        end,
        function (context)
            Lalolalo9_Add_Buildings_To_Queue(Lalolalo9AutoConstructionPlayerFaction)
        end,
        true
    )
end


local function Lalolalo9_AutoConstruction_button_creation()
    local ui_root = core:get_ui_root()
    local menu_bar = find_child_uicomponent(ui_root,"menu_bar")
    local buttongroup = find_child_uicomponent(menu_bar,"buttongroup")
 --   lvlog("Adding button for popup")
    local Lalolalo9_AutoConstruction_button_Building_Browser = find_uicomponent(buttongroup,"Lalolalo9_AutoConstruction_button_Building_Browser")
   -- lvlog("Local button created")
    if not Lalolalo9_AutoConstruction_button_Building_Browser then
     --   lvlog("Local button not found")
        Lalolalo9_AutoConstruction_button_Building_Browser = core:get_or_create_component("Lalolalo9_AutoConstruction_button_Building_Browser","UI/templates/round_small_button.twui.xml", buttongroup)
       -- lvlog("creating the ui component")
        Lalolalo9_AutoConstruction_button_Building_Browser:SetImagePath("ui/skins/default/icon_automanage_construction.png", 0,false)
     --   lvlog("Setting imaghepath")
        Lalolalo9_AutoConstruction_button_Building_Browser:SetVisible(true)
        Lalolalo9_AutoConstruction_button_Building_Browser:Resize(38, 38)
        Lalolalo9_AutoConstruction_TooltipSetter()
      --  Lalolalo9.Lalolalo9_AutoConstruction_button_Building_Browser:SetTooltipText(common.get_localised_string("Lalolalo9Mode" .. tostring(Lalolalo9AutoConstructionEnabled)), common.get_localised_string("Lalolalo9Mode" .. tostring(Lalolalo9AutoConstructionEnabled)), true)
    end 
    
    
    core:add_listener(
    "Lalolalo9AutoConstructionButtonBuildingBrowserHitter",
    "ComponentLClickUp",
        function(context)
            return context.string == "Lalolalo9_AutoConstruction_button_Building_Browser"
        end,
        function(context)
            Lalolalo9_BuildingBrowserMaker()
        end,
        true
    )
    core:add_listener(
    "Lalolalo9AutoConstructionButtonMovePriority",
    "ComponentLClickUp",
        function(context)
      --      lvlog("MovePriority is hit")
       --     lvlog(context.string)
            if string.find(context.string, "Lalolalo9_AutoConstruction_Building_Browser_Priority_Change_") ~= nil then
          --      lvlog("returned true")
                return true
            else
                --lvlog(string.find(context.string, "Lalolalo9_AutoConstruction_Building_Browser_Priority_Change_"))
            --    lvlog("returned false")
                return false
            end
        end,
        function(context)
        --    lvlog("Testing teh waters")
            local contexstring = context.string
            local helpstring = string.gsub(contexstring,"Lalolalo9_AutoConstruction_Building_Browser_Priority_Change_","")
          --  lvlog("Did substring " .. tostring(helpstring))
            local updo = string.sub(helpstring,-2)
            --lvlog("Did updo " .. tostring(updo))
            local indexstring = string.gsub(helpstring,"_" .. updo ,"")
            local indextomove = 1 + indexstring - 1 
         --   lvlog("did indextomove " .. tostring(indextomove))
            local variant = 0
            if updo == "UP" then
                variant = indextomove - 1
            else
                variant = indextomove + 1
            end
 --           lvlog("did variant " .. tostring(variant))
            local swapindexindextomove = indextomove -- 14
            local swapindexvariant = variant -- 13
            local listtocheck = Lalolalo9AutoConstructionPriorityList
            if Lalolalo9AutoconstructionPriorityGrouping == 0 then
                listtocheck = Lalolalo9AutoConstructionPriorityListGroupedAll
            elseif Lalolalo9AutoconstructionPriorityGrouping == 1 then
                listtocheck = Lalolalo9AutoConstructionPriorityListGroupedLand
            elseif Lalolalo9AutoconstructionPriorityGrouping == 2 then
                listtocheck = Lalolalo9AutoConstructionPriorityListGroupedRes
            end
            local checkindex = true
            local checkvar = true
     --       lvlog("Chelist is")
            for q,e in pairs(listtocheck) do
    --            lvlog("List check " .. tostring(q) .. " is " .. tostring(e))
            end
            for forindex, forkey in pairs(Lalolalo9AutoConstructionPriorityList) do
                if checkindex then
                    if forkey == listtocheck[indextomove] then
                        swapindexindextomove = forindex -- 14
                        checkindex = false
        --                lvlog("Set first swapindexindextomove to " .. tostring(swapindexindextomove))
                    end
                end
                if checkvar then
                    if forkey == listtocheck[variant] then
                        swapindexvariant = forindex -- 13
                        checkvar = false
          --              lvlog("Set first swapindexvariant to " .. tostring(swapindexvariant))
                    end
                end
            end
      --      lvlog("Indext to moves is " .. tostring(listtocheck[indextomove]))
        --    lvlog("variant to move is " .. tostring(listtocheck[variant]))
            if (listtocheck[indextomove] == "Lalolalo9LandChainGroup") then
                local foundchain = false
                swapindexindextomove = 999
                for forindex, forkey in pairs(Lalolalo9AutoConstructionPriorityList) do
                    for forsecindex, forseckey in pairs(Lalolalo9AutoConstructionBuildingListLand) do
         --               lvlog("Checking " .. tostring(forkey) .. " with " .. tostring(forseckey))
                        if forkey == forseckey then
                            if forindex < swapindexindextomove then
                                swapindexindextomove = forindex
                                foundchain = true
                            end
                        end
                    end
                    if foundchain then
          --              lvlog("Set sec swapindexindextomove to " .. tostring(swapindexindextomove))
                        break
                    end
                end
            end
            if (listtocheck[indextomove] == "Lalolalo9ResourceChainGroup") then
                local foundchain = false
                swapindexindextomove = 999
                for forindex, forkey in pairs(Lalolalo9AutoConstructionPriorityList) do
                    for forsecindex, forseckey in pairs(Lalolalo9AutoConstructionBuildingListRes) do
                        if forkey == forseckey then
                            if forindex < swapindexindextomove then
                                swapindexindextomove = forindex
                                foundchain = true
                            end
                        end
                    end
                    if foundchain then
        --                lvlog("Set 3d swapindexindextomove to " .. tostring(swapindexindextomove))
                        break
                    end
                end
            end
            if (listtocheck[variant] == "Lalolalo9LandChainGroup") then
                local foundchain = false
                swapindexvariant = 999
                for forindex, forkey in pairs(Lalolalo9AutoConstructionPriorityList) do
                    for forsecindex, forseckey in pairs(Lalolalo9AutoConstructionBuildingListLand) do
                        if forkey == forseckey then
                            if forindex < swapindexvariant then
                                swapindexvariant = forindex
                                foundchain = true
                            end
                        end
                    end
                    if foundchain then
             --           lvlog("Set sec swapindexvariant to " .. tostring(swapindexvariant))
                        break
                    end
                end
            end 
            if (listtocheck[variant] == "Lalolalo9ResourceChainGroup") then
                local foundchain = false
                swapindexvariant = 999
                for forindex, forkey in pairs(Lalolalo9AutoConstructionPriorityList) do
                    for forsecindex, forseckey in pairs(Lalolalo9AutoConstructionBuildingListRes) do
                        if forkey == forseckey then
                            if forindex < swapindexvariant then
                                swapindexvariant = forindex
                                foundchain = true
                            end
                        end
                    end
                    if foundchain then
            --            lvlog("Set third swapindexvariant to " .. tostring(swapindexvariant))
                        break
                    end
                end
            end
   --         lvlog("Visual list from " .. tostring(indextomove) .. " to " .. tostring(variant))
     --       lvlog("Have to go from " .. tostring(swapindexindextomove) .. " to " .. tostring(swapindexvariant))
            if updo == "UP" then
                for forswapcounter = 0 , swapindexindextomove - swapindexvariant - 1 do -- 8 - 5 = 3
         --           lvlog("Switching pos " .. tostring(swapindexindextomove - forswapcounter) .. " key " .. tostring(Lalolalo9AutoConstructionPriorityList[swapindexindextomove - forswapcounter]) .. " and pos" .. tostring(swapindexindextomove - forswapcounter - 1) .. " key " ..   tostring(Lalolalo9AutoConstructionPriorityList[swapindexindextomove - forswapcounter - 1]))
                    local tableplaceholder = Lalolalo9AutoConstructionPriorityList[swapindexindextomove - forswapcounter] -- 8 - 0 = 8 / 8 - 1 = 7
                    Lalolalo9AutoConstructionPriorityList[swapindexindextomove - forswapcounter] =  Lalolalo9AutoConstructionPriorityList[swapindexindextomove - forswapcounter - 1] -- 8 - 0 - 1 = 7 / 8 - 1 - 1 = 6
                    Lalolalo9AutoConstructionPriorityList[swapindexindextomove - forswapcounter - 1] = tableplaceholder
                end
            else
                for forswapcounter = 0 , swapindexvariant - swapindexindextomove - 1 do
      --              lvlog("Switching pos " .. tostring(swapindexindextomove + forswapcounter + 1) .. " key " .. tostring(Lalolalo9AutoConstructionPriorityList[swapindexindextomove + forswapcounter + 1]) .. " and pos" .. tostring(swapindexindextomove + forswapcounter) .. " key " ..   tostring(Lalolalo9AutoConstructionPriorityList[swapindexindextomove + forswapcounter]))
                    local tableplaceholder = Lalolalo9AutoConstructionPriorityList[swapindexindextomove + forswapcounter + 1]
                    Lalolalo9AutoConstructionPriorityList[swapindexindextomove + forswapcounter + 1] = Lalolalo9AutoConstructionPriorityList[swapindexindextomove + forswapcounter]
                    Lalolalo9AutoConstructionPriorityList[swapindexindextomove + forswapcounter] = tableplaceholder
                end
            end
            Lalolalo9AutoConstructionSaveValues()
            Lalolalo9_PriorityBuildingListConverter()
 --           lvlog("replaced table sort")
            local uicindextomove = find_uicomponent("Lalolalo9_AutoConstruction_Building_Browser","Lalolalo9_BuildingNumber_" .. tostring(indextomove))
            local uicvariant = find_uicomponent("Lalolalo9_AutoConstruction_Building_Browser","Lalolalo9_BuildingNumber_" .. tostring(variant))
   --         lvlog("Found uics")
            local textplaceholder,text2placeholder = find_uicomponent(uicindextomove,"Name","text"):GetStateText()
            local textvplaceholder, textv2placeholder = find_uicomponent(uicvariant,"Name","text"):GetStateText()
     --       lvlog("Gottext")
   --         lvlog(tostring(textplaceholder) .. " " .. tostring(text2placeholder) .. " " .. tostring(textvplaceholder) .. " " .. tostring(textv2placeholder))
            find_uicomponent(uicindextomove,"Name","text"):SetText(textvplaceholder,textv2placeholder)
            find_uicomponent(uicvariant,"Name","text"):SetText(textplaceholder,text2placeholder)
       --     lvlog("Settext")
            local iconplaceholder = find_uicomponent(uicindextomove,"IconForeground"):GetImagePath(0)
         --   lvlog("Got image " .. iconplaceholder )
            find_uicomponent(uicindextomove,"IconForeground"):SetImagePath(find_uicomponent(uicvariant,"IconForeground"):GetImagePath(0),0,true)
           -- lvlog("Set image")
            find_uicomponent(uicvariant,"IconForeground"):SetImagePath(iconplaceholder,0,true)
        end,
        true
    )
    
    core:add_listener(
    "Lalolalo9AutoConstructionConfigButtons",
    "ComponentLClickUp",
        function(context)
            return ((context.string == "Lalolalo9_AutoConstruction_Start_End_Config") or (context.string == "Lalolalo9_AutoConstruction_Landmark_Group_Config") or (context.string == "Lalolalo9_AutoConstruction_Resource_Group_Config") or (context.string == "Lalolalo9_AutoConstruction_Upgrade_Construct_Config") or (context.string == "Lalolalo9_Autoconstruction_EnableConstructButton") or (context.string == "Lalolalo9_Autoconstruction_DisableConstructButton"))
        end,
        function(context)
            -- Lalolalo9AutoconstructionPriorityGrouping 0 both grouped
            -- 1 land is grouped
            -- 2 resourse is grouped
            -- all the rest are ungrouped
            Lalolalo9_AutoconstructionCloseListeners()
            local configbuttonhit = context.string
            local closebrowser = 0
            if configbuttonhit == "Lalolalo9_AutoConstruction_Start_End_Config" then
                if Lalolalo9AutoConstructionStartEnd == 0 then
                    Lalolalo9AutoConstructionStartEnd = 1
                else
                    Lalolalo9AutoConstructionStartEnd = 0
                end
            elseif configbuttonhit == "Lalolalo9_AutoConstruction_Upgrade_Construct_Config" then
                if Lalolalo9AutoConstructionAutoConstructAutoupgrade == 0 then
                    Lalolalo9AutoConstructionAutoConstructAutoupgrade = 1
                else
                    Lalolalo9AutoConstructionAutoConstructAutoupgrade = 0
                end
            elseif configbuttonhit == "Lalolalo9_AutoConstruction_Landmark_Group_Config" then
                if Lalolalo9AutoconstructionPriorityGrouping == 0 then
                    Lalolalo9AutoconstructionPriorityGrouping = 2
                elseif Lalolalo9AutoconstructionPriorityGrouping == 2 then
                    Lalolalo9AutoconstructionPriorityGrouping = 0
                elseif Lalolalo9AutoconstructionPriorityGrouping == 1 then
                    Lalolalo9AutoconstructionPriorityGrouping = 3
                else
                    Lalolalo9AutoconstructionPriorityGrouping = 1
                end
                closebrowser = 1
            elseif configbuttonhit == "Lalolalo9_AutoConstruction_Resource_Group_Config" then
                if Lalolalo9AutoconstructionPriorityGrouping == 0 then
                    Lalolalo9AutoconstructionPriorityGrouping = 1
                elseif Lalolalo9AutoconstructionPriorityGrouping == 1 then
                    Lalolalo9AutoconstructionPriorityGrouping = 0
                elseif Lalolalo9AutoconstructionPriorityGrouping == 2 then
                    Lalolalo9AutoconstructionPriorityGrouping = 3
                else
                    Lalolalo9AutoconstructionPriorityGrouping = 2
                end
                closebrowser = 1
            elseif configbuttonhit == "Lalolalo9_Autoconstruction_EnableConstructButton" then
                closebrowser = 2
                Lalolalo9AutoConstructionEnabled = 1
            elseif configbuttonhit == "Lalolalo9_Autoconstruction_DisableConstructButton" then
                closebrowser = 2
                Lalolalo9AutoConstructionEnabled = 0
            end
            --lvlog("So clicking buttong")
            Lalolalo9AutoConstructionSaveValues()
            --lvlog("Saved the values")
            --lvlog("Browser should or should not close  " .. tostring(closebrowser))
            if closebrowser > 0 then
                --lvlog("testing completed")
                if find_uicomponent("Lalolalo9_AutoConstruction_Building_Browser") ~= false then
                    --lvlog("did find the brozser")
                    find_uicomponent("Lalolalo9_AutoConstruction_Building_Browser"):Destroy()
                end
            end
            if Lalolalo9AutoConstructionEnabled == 1 then
                if Lalolalo9AutoConstructionStartEnd == 0 then
                    Lalolalo9_AutoConstruction_ListenerStarterStartTurn()
                else
                    Lalolalo9_AutoConstruction_ListenerStarterEndTurn()
                end
            end
            if closebrowser == 1 then
                Lalolalo9_BuildingBrowserMaker()
            end
            Lalolalo9_AutoConstruction_TooltipSetter()
        end,
        true
    )
    
    core:add_listener(
        "Lalolalo9AutoConstructionBuildSomethingFaction",
        "UITrigger",
        function (context)
            return string.match(string.lower(context:trigger()),"lalolalo9autoconstructiontrigger_reg__")
        end,
        function (context)
            local regionString = string.match(context:trigger(),"Reg__.*__Slot__"):gsub("Reg__",""):gsub("__Slot__","")
            local buildingslotString = string.match(context:trigger(),"__Slot__.*__Build__"):gsub("__Build__",""):gsub("__Slot__","")
            local buildrecordString = string.match(context:trigger(),"__Build__.*"):gsub("__Build__","")
            local SettlementCQI = tostring(cm:model():world():region_manager():region_by_key(regionString):cqi())
            for SlotIndex = 0, common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.Size") - 1 do
                local BuildingSlotIndex = common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..").Index")
                if tostring(BuildingSlotIndex) == buildingslotString then
                    common.get_context_value("CcoCampaignSettlement",tostring(SettlementCQI),"BuildingSlotList.At("..SlotIndex..")"):Call("Construct(DatabaseRecordContext(\"CcoBuildingLevelRecord\",\"" .. buildrecordString .. "\"))")
                    break
                end
            end
				
        end,
        true
    )
end


local function AssignPlayerFaction()
    local factionList = cm:get_human_factions()
   for f, faction in pairs(factionList) do
       local factionObject = cm:get_faction(faction)
        local key = common.get_context_value("CcoCampaignFaction",tostring(factionObject:command_queue_index()),"IsPlayersFaction")
        if key then
            Lalolalo9AutoConstructionPlayerFaction = factionObject
       end
    end
end


local function lalolalo9_Autoconstruction_init()
    if cm:get_saved_value("Lalolalo9AutoConstructionEnabled") ~= nil then
        Lalolalo9AutoConstructionEnabled = cm:get_saved_value("Lalolalo9AutoConstructionEnabled")
    else
        Lalolalo9AutoConstructionEnabled = 1
    end
    if cm:get_saved_value("Lalolalo9AutoconstructionPriorityGrouping") ~= nil then
        Lalolalo9AutoconstructionPriorityGrouping = cm:get_saved_value("Lalolalo9AutoconstructionPriorityGrouping")
    end
    if cm:get_saved_value("Lalolalo9AutoConstructionStartEnd") ~= nil then
        Lalolalo9AutoConstructionStartEnd = cm:get_saved_value("Lalolalo9AutoConstructionStartEnd")
    end
    if cm:get_saved_value("Lalolalo9AutoConstructionAutoConstructAutoupgrade") ~= nil then
    Lalolalo9AutoConstructionAutoConstructAutoupgrade = cm:get_saved_value("Lalolalo9AutoConstructionAutoConstructAutoupgrade")
    end
    if cm:get_saved_value("Lalolalo9AutoConstructionPriorityList") ~= nil then
        Lalolalo9AutoConstructionPriorityListString = cm:get_saved_value("Lalolalo9AutoConstructionPriorityList")
    else
        local AllBuildingsList = {}
        for AllSettlementIndex = 0 , common.get_context_value("CcoCampaignRoot", "","SettlementList.Size") - 1 do
    --lvlog("Starting settlement loop")
            for AllBuildingChainsIndex = 0 , common.get_context_value("CcoCampaignRoot", "" , "SettlementList.At(" .. AllSettlementIndex .. ").PlayersFactionChainList.Size") - 1 do
        --lvlog("Starting buildchain loop")
                local AllBuildingKey = common.get_context_value("CcoCampaignRoot", "", "SettlementList.At(" ..AllSettlementIndex .. ").PlayersFactionChainList.At(" .. AllBuildingChainsIndex .. ").Key")
                if AllBuildingsList[1] ~= nil then
                    local BuildingKeyAllreadyAdded = false
                    for i,p in pairs(AllBuildingsList) do
                        if p == AllBuildingKey then
                            BuildingKeyAllreadyAdded = true
                            break
                        end
                    end
                    if not BuildingKeyAllreadyAdded then
                       -- lvlog("Other insert of" .. tostring(AllBuildingKey))
                        table.insert(AllBuildingsList,AllBuildingKey)
                    end
                else
                    --lvlog("First insert of" .. tostring(AllBuildingKey))
                    table.insert(AllBuildingsList,AllBuildingKey)
                end
            end
        end
        Lalolalo9AutoConstructionPriorityListString = Lalolalo9_PriorityBuildingListEncoder(AllBuildingsList)
        --[[ lvlog("Final list")
        local tablecount = 0
        for i, p in pairs(AllBuildingsList) do
            lvlog("Building index is "  .. tostring(i) )
            lvlog("Building Key is " .. tostring(p) )
            tablecount = tablecount + 1
        end
        Lalolalo9AutoConstructionPriorityListString = tostring(tablecount) .. "_"
        for i, p in pairs(AllBuildingsList) do
            Lalolalo9AutoConstructionPriorityListString = Lalolalo9AutoConstructionPriorityListString ..  "__lalo__" .. tostring(p)
        end
        lvlog("Final sort string is " .. Lalolalo9AutoConstructionPriorityListString)
        ]]
    end
    Lalolalo9AutoConstructionPriorityList = Lalolalo9_PriorityBuildingListDecoder(Lalolalo9AutoConstructionPriorityListString)
    Lalolalo9_PriorityBuildingListConverter()
    --[[
    local prioritylistsize = tonumber(string.match(Lalolalo9AutoConstructionPriorityListString, "^%d+"))
    lvlog("List size is " .. tostring(prioritylistsize))
    Lalolalo9AutoConstructionPriorityListString = string.gsub(Lalolalo9AutoConstructionPriorityListString, tostring(prioritylistsize) .. "___lalo__", "" , 1)
    lvlog("Substituded string is " .. Lalolalo9AutoConstructionPriorityListString)
    for indexloop = 1, prioritylistsize do
        local chainkey = ""
        if indexloop == prioritylistsize then
            chainkey = Lalolalo9AutoConstructionPriorityListString
        else
            local fistpartend = string.find(Lalolalo9AutoConstructionPriorityListString, "__lalo__") - 1
            lvlog("Substituded is " .. tostring(fistpartend))
            chainkey = string.sub(Lalolalo9AutoConstructionPriorityListString,1,fistpartend)
            Lalolalo9AutoConstructionPriorityListString = string.gsub(Lalolalo9AutoConstructionPriorityListString, chainkey .. "__lalo__", "", 1)
        end
            lvlog("Stringdecode inserting " .. chainkey)
        table.insert(Lalolalo9AutoConstructionPriorityList,chainkey)
        
    end
    ]]
    AssignPlayerFaction()
    Lalolalo9_AutoConstruction_button_creation()
    if Lalolalo9AutoConstructionEnabled == 1 then
        if Lalolalo9AutoConstructionStartEnd == 0 then
            Lalolalo9_AutoConstruction_ListenerStarterStartTurn()
        else
            Lalolalo9_AutoConstruction_ListenerStarterEndTurn()
        end
    end
  --  lvlog("All good till here")
end

cm:add_first_tick_callback(function() lalolalo9_Autoconstruction_init() end);