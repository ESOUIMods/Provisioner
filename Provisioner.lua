-----------------------------------------
-- Provisioner is based off of Esohead --
-----------------------------------------

COOK = {}

-----------------------------------------
--           Core Functions            --
-----------------------------------------

function COOK.Initialize()
    COOK.savedVars = {}
    COOK.debugDefault = 0
    COOK.dataDefault = {
        data = {}
    }
    COOK.name = ""
    COOK.time = 0
    COOK.isHarvesting = false
    COOK.action = ""
    COOK.langs = { "en", "de", "fr", }

    COOK.currentConversation = {
        npcName = "",
        npcLevel = 0,
        x = 0,
        y = 0,
        subzone = ""
    }
    COOK.minDefault = 0.000025 -- 0.005^2
    COOK.minContainer = 0.00001225 -- 0.0035^2
end

function COOK.InitSavedVariables()
    COOK.savedVars = {
        ["internal"]     = ZO_SavedVars:NewAccountWide("Provisioner_SavedVariables", 1, "internal", { debug = COOK.debugDefault, language = "" }),
        ["provisioning"] = ZO_SavedVars:NewAccountWide("Provisioner_SavedVariables", 2, "provisioning", COOK.dataDefault),
    }

    if COOK.savedVars["internal"].debug == 1 then
        COOK.Debug("Provisioner addon initialized. Debugging is enabled.")
    else
        COOK.Debug("Provisioner addon initialized. Debugging is disabled.")
    end
end

-- Logs saved variables
function COOK.Log(type, nodes, ...)
    local data = {}
    local dataStr = ""
    local sv

    if COOK.savedVars[type] == nil or COOK.savedVars[type].data == nil then
        COOK.Debug("Attempted to log unknown type: " .. type)
        return
    else
        sv = COOK.savedVars[type].data
    end

    for i = 1, #nodes do
        local node = nodes[i];
        if string.find(node, '\"') then
            node = string.gsub(node, '\"', '\'')
        end

        if sv[node] == nil then
            sv[node] = {}
        end
        sv = sv[node]
    end

    for i = 1, select("#", ...) do
        local value = select(i, ...)
        data[i] = value
        dataStr = dataStr .. "[" .. tostring(value) .. "] "
    end

    if COOK.savedVars["internal"].debug == 1 then
        COOK.Debug("COOK: Logged [" .. type .. "] data: " .. dataStr)
    end

    if #sv == 0 then
        sv[1] = data
    else
        sv[#sv+1] = data
    end
end

-- Checks if we already have an entry for the object/npc within a certain x/y distance
function COOK.LogCheck(type, nodes, x, y, scale, name)
    local log
    local sv

    local distance
    if scale == nil then
        distance = COOK.minDefault
    else
        distance = scale
    end

    if COOK.savedVars[type] == nil or COOK.savedVars[type].data == nil then
        return nil
    else
        sv = COOK.savedVars[type].data
    end

    for i = 1, #nodes do
        local node = nodes[i];
        if string.find(node, '\"') then
            node = string.gsub(node, '\"', '\'')
        end

        if sv[node] == nil then
            sv[node] = {}
        end
        sv = sv[node]
    end

    for i = 1, #sv do
        local item = sv[i]

        dx = item[1] - x
        dy = item[2] - y
        -- (x - center_x)2 + (y - center_y)2 = r2, where center is the player
        dist = math.pow(dx, 2) + math.pow(dy, 2)
        -- both ensure that the entire table isn't parsed
        if dist < distance then -- near or at player location
            if name == nil then -- Unused in Provisioner : npc, quest, vendor all but harvesting
                log = item
            else -- Provisioning checks for name same as harvesting would
                if item[3] == name then
                    log = item
                elseif item[3] ~= name then
                    log = item
                end
            end
        end
    end

    return log
end

-- formats a number with commas on thousands
function COOK.NumberFormat(num)
    local formatted = num
    local k

    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then
            break
        end
    end

    return formatted
end

-- Listens for anything that is not event driven by the API but needs to be tracked
function COOK.OnUpdate(time)
    if IsGameCameraUIModeActive() or IsUnitInCombat("player") then
        return
    end

    local type = GetInteractionType()
    local active = IsPlayerInteractingWithObject()
    local x, y, a, subzone, world = COOK.GetUnitPosition("player")
    local targetType
    local action, name, interactionBlocked, additionalInfo, context = GetGameCameraInteractableActionInfo()

    local isHarvesting = ( active and (type == INTERACTION_HARVEST) )
    if not isHarvesting then
        -- COOK.Debug("I am NOT busy! Time : " .. time)
        if name then
            COOK.name = name -- COOK.name is the global current node
        end

        if COOK.isHarvesting and time - COOK.time > 1 then
            COOK.isHarvesting = false
        end

        -- No reticle actions to check in this version
        if action ~= COOK.action then
            COOK.action = action -- COOK.action is the global current action
            -- if COOK.action ~= nil then
            --     COOK.Debug("New Action! : " .. COOK.action .. " : " .. time)
            -- end
            -- COOK.Debug(COOK.action .. " : " .. GetString(SI_GAMECAMERAACTIONTYPE16))

        end -- End of {{if action ~= COOK.action then}}
    else -- End of {{if not isHarvesting then}}
        -- COOK.Debug("I am REALLY busy! Time : " .. time)
        COOK.isHarvesting = true
        COOK.time = time

    -- End of Else Block
    end -- End of Else Block
end

-----------------------------------------
--         Coordinate System           --
-----------------------------------------

function COOK.UpdateCoordinates()
    local mouseOverControl = WINDOW_MANAGER:GetMouseOverControl()

    if (mouseOverControl == ZO_WorldMapContainer or mouseOverControl:GetParent() == ZO_WorldMapContainer) then
        local currentOffsetX = ZO_WorldMapContainer:GetLeft()
        local currentOffsetY = ZO_WorldMapContainer:GetTop()
        local parentOffsetX = ZO_WorldMap:GetLeft()
        local parentOffsetY = ZO_WorldMap:GetTop()
        local mouseX, mouseY = GetUIMousePosition()
        local mapWidth, mapHeight = ZO_WorldMapContainer:GetDimensions()
        local parentWidth, parentHeight = ZO_WorldMap:GetDimensions()

        local normalizedX = math.floor((((mouseX - currentOffsetX) / mapWidth) * 100) + 0.5)
        local normalizedY = math.floor((((mouseY - currentOffsetY) / mapHeight) * 100) + 0.5)

        ProvisionerCoordinates:SetAlpha(0.8)
        ProvisionerCoordinates:SetDrawLayer(ZO_WorldMap:GetDrawLayer() + 1)
        ProvisionerCoordinates:SetAnchor(TOPLEFT, nil, TOPLEFT, parentOffsetX + 0, parentOffsetY + parentHeight)
        ProvisionerCoordinatesValue:SetText("Coordinates: " .. normalizedX .. ", " .. normalizedY)
    else
        ProvisionerCoordinates:SetAlpha(0)
    end
end

-----------------------------------------
--            API Helpers              --
-----------------------------------------

function COOK.GetUnitPosition(tag)
    local setMap = SetMapToPlayerLocation() -- Fix for bug #23
    if setMap == 2 then
        CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged") -- Fix for bug #23
    end

    local x, y, a = GetMapPlayerPosition(tag)
    local subzone = GetMapName()
    local world = GetUnitZone(tag)

    return x, y, a, subzone, world
end

function COOK.GetUnitName(tag)
    return GetUnitName(tag)
end

function COOK.GetUnitLevel(tag)
    return GetUnitLevel(tag)
end

function COOK.GetLootEntry(index)
    return GetLootItemInfo(index)
end

-----------------------------------------
--           Debug Logger              --
-----------------------------------------

local function EmitMessage(text)
    if(CHAT_SYSTEM)
    then
        if(text == "")
        then
            text = "[Empty String]"
        end

        CHAT_SYSTEM:AddMessage(text)
    end
end

local function EmitTable(t, indent, tableHistory)
    indent          = indent or "."
    tableHistory    = tableHistory or {}

    for k, v in pairs(t)
    do
        local vType = type(v)

        EmitMessage(indent.."("..vType.."): "..tostring(k).." = "..tostring(v))

        if(vType == "table")
        then
            if(tableHistory[v])
            then
                EmitMessage(indent.."Avoiding cycle on table...")
            else
                tableHistory[v] = true
                EmitTable(v, indent.."  ", tableHistory)
            end
        end
    end
end

function COOK.Debug(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if(type(value) == "table")
        then
            EmitTable(value)
        else
            EmitMessage(tostring (value))
        end
    end
end

-----------------------------------------
--           Loot Tracking             --
-----------------------------------------

function COOK.ItemLinkParse(link)

    local Field1, Field2, Field3, Field4, Field5 = ZO_LinkHandler_ParseLink( link )

    -- name = Field1
    -- unused = Field2
    -- type = Field3
    -- id = Field4
    -- quality = Field5

    return {
        type = Field3,
        id = tonumber(Field4),
        quality = tonumber(Field5),
        name = zo_strformat(SI_TOOLTIP_ITEM_NAME, Field1)
    }
end

function COOK.CheckDupeContents(items, itemName)
    for _, entry in pairs( items ) do
        COOK.Debug("Entry Found " .. entry[1] .. " Itenname : " .. itemName)
        if entry[1] == itemName then
            return true
        end
    end
    return false
end

function COOK.OnLootReceived(eventCode, receivedBy, objectName, stackCount, soundCategory, lootType, lootedBySelf)
    if not IsGameCameraUIModeActive() then
        targetName = COOK.name

        if not COOK.IsValidNode(targetName) then
            return
        end

        local link = COOK.ItemLinkParse(objectName)
        local material = COOK.GetTradeskillByMaterial(link.id)
        local x, y, a, subzone, world = COOK.GetUnitPosition("player")

        -- This attempts to resolve an issue where you can loot a harvesting
        -- node that has worms or plump worms in it and it gets recorded.
        -- It also attempts to resolve adding non harvest nodes to harvest
        -- such as bottles, crates, barrels, baskets, wine racks, and
        -- heavy sacks.  Some of those containers give random items but can
        -- also give solvents.  Heavy Sacks can contain Enchanting reagents.
        if not COOK.isHarvesting and material >= 1 then
            material = 5
        elseif COOK.isHarvesting and material == 5 then
            material = 0
        end

        if material == 0 then
            return
        end

        if material == 5 then
            data = COOK.LogCheck("provisioning", { subzone }, x, y, COOK.minContainer, targetName)
            if not data then -- when there is no node at the given location, save a new entry
                COOK.Log("provisioning", { subzone }, x, y, targetName, { {link.name, link.id, stackCount} } )
            else --otherwise add the new data to the entry
                COOK.Debug("Looking to insert " .. targetName .. " into existing " .. data[3])
                if data[3] == targetName then
                    if not COOK.CheckDupeContents(data[4], link.name) then
                        COOK.Debug("Inserted " .. link.name .. " from " .. targetName .. " into existing " .. data[3])
                        table.insert(data[4], {link.name, link.id, stackCount} )
                    end
                else
                    COOK.Debug("Didn't insert " .. link.name .. " from " .. targetName .. " into existing " .. data[3])
                    COOK.Log("provisioning", { subzone }, x, y, targetName, { {link.name, link.id, stackCount} } )
                end
            end
        end
    end
end

-----------------------------------------
--           Merge Nodes               --
-----------------------------------------
function COOK.importFromEsohead()
    if not EH then
        COOK.Debug("Please enable the Esohead addon to import data!")
        return
    end

    COOK.Debug("Provisioner Starting from Esohead")
    for category, data in pairs(EH.savedVars) do
        if category ~= "internal" and category == "provisioning" then
            for map, location in pairs(data.data) do
                -- COOK.Debug(category .. map)
                for itemId, nodes in pairs(location[5]) do
                    for index, node in pairs(nodes) do
                        if COOK.GetTradeskillByMaterial(itemId) == 5 then
                            --COOK.Debug("Map : " .. map .. " : Category : " .. category .. " : ItemID : " .. itemId)
                            --COOK.Debug("node : 1) " .. node[1] .. " : 2) " .. node[2] .. " : 3) " .. node[3] .. " : 4) " .. node[4])
                            data = COOK.LogCheck("provisioning", { map }, node[1], node[2], COOK.minContainer, node[4])
                            itemName = "testName" --[[ COOK.GetItemNameFromItemID(id) ]]--
                            if not data then -- when there is no node at the given location, save a new entry
                                COOK.Log("provisioning", { map }, node[1], node[2], node[4], { {itemName, itemId, node[3]} } )
                            else --otherwise add the new data to the entry
                                -- COOK.Debug("looking to insert!" .. targetName)
                                if data[3] == node[4] then
                                    if not COOK.CheckDupeContents(data[4], itemName) then
                                        -- COOK.Debug("Inserted " .. link.name .. " 3) " .. data[3] .. " : Target " .. targetName)
                                        table.insert(data[4], {itemName, itemId, node[3]} )
                                    end
                                else
                                    -- COOK.Debug("Didn't insert " .. link.name .. " 3) " .. data[3] .. " : Target " .. targetName)
                                    COOK.Log("provisioning", { map }, node[1], node[2], node[4], { {itemName, itemId, node[4]} } )
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    COOK.Debug("Import Complete")
end

function COOK.importFromEsoheadMerge()
    if not EHM then
        COOK.Debug("Please enable the EsoheadMerge addon to import data!")
        return
    end

    COOK.Debug("Provisioner Starting Import from EsoheadMerge")
    for category, data in pairs(EHM.savedVars) do
        if category ~= "internal" and category == "provisioning" then
            for map, location in pairs(data.data) do
                -- COOK.Debug(category .. map)
                for itemId, nodes in pairs(location[5]) do
                    for index, node in pairs(nodes) do
                        if COOK.GetTradeskillByMaterial(itemId) == 5 then
                            --COOK.Debug("Map : " .. map .. " : Category : " .. category .. " : ItemID : " .. itemId)
                            --COOK.Debug("node : 1) " .. node[1] .. " : 2) " .. node[2] .. " : 3) " .. node[3] .. " : 4) " .. node[4])
                            data = COOK.LogCheck("provisioning", { map }, node[1], node[2], COOK.minContainer, node[4])
                            itemName = "testName" --[[ COOK.GetItemNameFromItemID(id) ]]--
                            if not data then -- when there is no node at the given location, save a new entry
                                COOK.Log("provisioning", { map }, node[1], node[2], node[4], { {itemName, itemId, node[3]} } )
                            else --otherwise add the new data to the entry
                                -- COOK.Debug("looking to insert!" .. targetName)
                                if data[3] == node[4] then
                                    if not COOK.CheckDupeContents(data[4], itemName) then
                                        -- COOK.Debug("Inserted " .. link.name .. " 3) " .. data[3] .. " : Target " .. targetName)
                                        table.insert(data[4], {itemName, itemId, node[3]} )
                                    end
                                else
                                    -- COOK.Debug("Didn't insert " .. link.name .. " 3) " .. data[3] .. " : Target " .. targetName)
                                    COOK.Log("provisioning", { map }, node[1], node[2], node[4], { {itemName, itemId, node[4]} } )
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    COOK.Debug("Import Complete")
end

-----------------------------------------
--           Slash Command             --
-----------------------------------------

SLASH_COMMANDS["/cook"] = function (cmd)
    local commands = {}
    local index = 1
    for i in string.gmatch(cmd, "%S+") do
        if (i ~= nil and i ~= "") then
            commands[index] = i
            index = index + 1
        end
    end

    if #commands == 0 then
        return COOK.Debug("Please enter a valid Provisioner command")
    end

    if #commands == 2 and commands[1] == "debug" then
        if commands[2] == "on" then
            COOK.Debug("Provisioner debugger toggled on")
            COOK.savedVars["internal"].debug = 1
        elseif commands[2] == "off" then
            COOK.Debug("Provisioner debugger toggled off")
            COOK.savedVars["internal"].debug = 0
        end

    elseif #commands == 2 and commands[1] == "import" then

        if commands[2] == "esohead" then
            COOK.importFromEsohead()
        elseif commands[2] == "esomerge" then
            COOK.importFromEsoheadMerge()
        end

    elseif commands[1] == "reset" then
        for type,sv in pairs(COOK.savedVars) do
            if type ~= "internal" then
                COOK.savedVars[type].data = {}
            end
        end

        COOK.Debug("Saved data has been completely reset")

    elseif commands[1] == "datalog" then
        COOK.Debug("---")
        COOK.Debug("Complete list of gathered data:")
        COOK.Debug("---")

        local counter = {
            ["provisioning"] = 0,
        }

        for type,sv in pairs(COOK.savedVars) do
            if type ~= "internal" and type == "provisioning" then
                for zone, t1 in pairs(COOK.savedVars[type].data) do
                    counter[type] = counter[type] + #COOK.savedVars[type].data[zone]
                end
            end
        end

        COOK.Debug("Provisioning: "     .. COOK.NumberFormat(counter["provisioning"]))

        COOK.Debug("---")
    end
end

SLASH_COMMANDS["/rl"] = function()
    ReloadUI("ingame")
end

SLASH_COMMANDS["/reload"] = function()
    ReloadUI("ingame")
end

-----------------------------------------
--        Addon Initialization         --
-----------------------------------------

function COOK.OnLoad(eventCode, addOnName)
    if addOnName ~= "Provisioner" then
        return
    end

    COOK.language = (GetCVar("language.2") or "en")
    COOK.InitSavedVariables()
    COOK.savedVars["internal"]["language"] = COOK.language
    COOK.materialID = 5

    EVENT_MANAGER:RegisterForEvent("Provisioner", EVENT_LOOT_RECEIVED, COOK.OnLootReceived)
end

EVENT_MANAGER:RegisterForEvent("Provisioner", EVENT_ADD_ON_LOADED, function (eventCode, addOnName)
    if addOnName == "Provisioner" then
        COOK.Initialize()
        COOK.OnLoad(eventCode, addOnName)
    end
end)