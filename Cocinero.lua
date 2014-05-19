-----------------------------------------
-- Cocinero is based off of Esohead  --
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

    COOK.currentConversation = {
        npcName = "",
        npcLevel = 0,
        x = 0,
        y = 0,
        subzone = ""
    }
end

function COOK.InitSavedVariables()
    COOK.savedVars = {
        ["internal"]     = ZO_SavedVars:NewAccountWide("Cocinero_SavedVariables", 1, "internal", { debug = COOK.debugDefault, language = "" }),
        ["provisioning"] = ZO_SavedVars:NewAccountWide("Cocinero_SavedVariables", 1, "provisioning", COOK.dataDefault),
    }

    if COOK.savedVars["internal"].debug == 1 then
        COOK.Debug("Cocinero addon initialized. Debugging is enabled.")
    else
        COOK.Debug("Cocinero addon initialized. Debugging is disabled.")
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
        COOK.Debug("COS: Logged [" .. type .. "] data: " .. dataStr)
    end

    if #sv == 0 then
        sv[1] = data
    else
        sv[#sv+1] = data
    end
end

-- Checks if we already have an entry for the object/npc within a certain x/y distance
function COOK.LogCheck(type, nodes, x, y, scale)
    local log = nil
    local sv

    local distance
    if scale == nil then
        distance = 0.005
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

        if math.abs(item[1] - x) < distance and math.abs(item[2] - y) < distance then
            log = item
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
        -- d("I am NOT busy! Time : " .. time)
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
            --     d("New Action! : " .. COOK.action .. " : " .. time)
            -- end
            -- d(COOK.action .. " : " .. GetString(SI_GAMECAMERAACTIONTYPE16))

        end -- End of {{if action ~= COOK.action then}}
    else -- End of {{if not isHarvesting then}}
        -- d("I am REALLY busy! Time : " .. time)
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

        CocineroCoordinates:SetAlpha(0.8)
        CocineroCoordinates:SetDrawLayer(ZO_WorldMap:GetDrawLayer() + 1)
        CocineroCoordinates:SetAnchor(TOPLEFT, nil, TOPLEFT, parentOffsetX + 0, parentOffsetY + parentHeight)
        CocineroCoordinatesValue:SetText("Coordinates: " .. normalizedX .. ", " .. normalizedY)
    else
        CocineroCoordinates:SetAlpha(0)
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
            data = COOK.LogCheck("provisioning", { subzone, material }, x, y, 0.003)
            if not data then -- when there is no node at the given location, save a new entry
                COOK.Log("provisioning", { subzone, material }, x, y, targetName, { {link.name, link.id, stackCount} } )
            else --otherwise add the new data to the entry
                if data[3] == targetName then
                    if not COOK.CheckDupeContents(data[4], link.name) then
                        table.insert(data[4], {link.name, link.id, stackCount} )
                    end
                else
                    COOK.Log("provisioning", { subzone, material }, x, y, targetName, { {link.name, link.id, stackCount} } )
                end
            end
        end
    end
end

-----------------------------------------
--           Slash Command             --
-----------------------------------------

SLASH_COMMANDS["/cosecha"] = function (cmd)
    local commands = {}
    local index = 1
    for i in string.gmatch(cmd, "%S+") do
        if (i ~= nil and i ~= "") then
            commands[index] = i
            index = index + 1
        end
    end

    if #commands == 0 then
        return COOK.Debug("Please enter a valid Cocinero command")
    end

    if #commands == 2 and commands[1] == "debug" then
        if commands[2] == "on" then
            COOK.Debug("Cocinero debugger toggled on")
            COOK.savedVars["internal"].debug = 1
        elseif commands[2] == "off" then
            COOK.Debug("Cocinero debugger toggled off")
            COOK.savedVars["internal"].debug = 0
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
                    for item, t2 in pairs(COOK.savedVars[type].data[zone]) do
                        for data, t3 in pairs(COOK.savedVars[type].data[zone][item]) do
                            counter[type] = counter[type] + #COOK.savedVars[type].data[zone][item][data]
                        end
                    end
                end
            elseif type ~= "internal" then
                for zone, t1 in pairs(COOK.savedVars[type].data) do
                    for data, t2 in pairs(COOK.savedVars[type].data[zone]) do
                        counter[type] = counter[type] + #COOK.savedVars[type].data[zone][data]
                    end
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
    if addOnName ~= "Cocinero" then
        return
    end

    COOK.language = (GetCVar("language.2") or "en")
    COOK.InitSavedVariables()
    COOK.savedVars["internal"]["language"] = COOK.language

    EVENT_MANAGER:RegisterForEvent("Cocinero", EVENT_LOOT_RECEIVED, COOK.OnLootReceived)
end

EVENT_MANAGER:RegisterForEvent("Cocinero", EVENT_ADD_ON_LOADED, function (eventCode, addOnName)
    if addOnName == "Cocinero" then
        COOK.Initialize()
        COOK.OnLoad(eventCode, addOnName)
    end
end)