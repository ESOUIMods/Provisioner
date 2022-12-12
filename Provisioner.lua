-----------------------------------------
-- Provisioner is based off of Esohead --
-----------------------------------------

-----------------------------------------
--             Constants               --
-----------------------------------------

COOK = {}
WRONG_INTERACTION_TYPE = "WrongInteractionType"
local LMP = LibMapPins

ignored_interaction_types = {
  [INTERACTION_VENDOR] = true,
  [INTERACTION_STORE] = true,
  [INTERACTION_QUEST] = true,
  [INTERACTION_MAIL] = true,
  [INTERACTION_GUILDBANK] = true,
  [INTERACTION_CRAFT] = true,
  [INTERACTION_STORE] = true,
  [INTERACTION_BANK] = true,
  [INTERACTION_CONVERSATION] = true
}

ignored_tagets = {
  ["Clothier Delivery Crate"] = true,
  ["Blacksmith Delivery Crate"] = true,
  ["Woodworker Delivery Crate"] = true,
  ["Provisioner Delivery Crate"] = true,
  ["Enchanter Delivery Crate"] = true,
  ["Alchemist Delivery Crate"] = true
}

-----------------------------------------
--           Core Functions            --
-----------------------------------------

function COOK.Initialize()
  COOK.savedVars = {}
  COOK.debugDefault = 0
  COOK.dataDefault = {
    data = {}
  }
  --COOK.name = ""
  COOK.time = 0
  COOK.isHarvesting = false
  COOK.action = ""
  COOK.langs = { "en", "de", "fr", }

  COOK.minDefault = 0.000025 -- 0.005^2
  COOK.minContainer = 0.00001369 -- 0.0037^2
end

function COOK.InitSavedVariables()
  COOK.savedVars = {
    ["internal"] = ZO_SavedVars:NewAccountWide("Provisioner_SavedVariables", 1, "internal", { debug = COOK.debugDefault, language = "" }),
    ["provisioning"] = ZO_SavedVars:NewAccountWide("Provisioner_SavedVariables", 4, "provisioning", COOK.dataDefault),
    ["vendor"] = ZO_SavedVars:NewAccountWide("Provisioner_SavedVariables", 2, "vendor", COOK.dataDefault),
    ["unlocalized"] = ZO_SavedVars:NewAccountWide("Provisioner_SavedVariables", 1, "unlocalized", COOK.dataDefault),
    ["vendor_export"] = ZO_SavedVars:NewAccountWide("Provisioner_SavedVariables", 1, "vendor_export", COOK.dataDefault),
  }

  if COOK.savedVars["internal"].debug == 1 then
    COOK.Debug("Provisioner addon initialized. Debugging is enabled.")
  else
    COOK.Debug("Provisioner addon initialized. Debugging is disabled.")
  end
end

---
-- vendor
---

-- Checks if we already have an entry for the object/npc within a certain x/y distance
function COOK.VendLogCheck(type, nodes, x, y, scale, name)
  local log = true
  local sv

  if x <= 0 or y <= 0 then
    return false
  end

  if COOK.savedVars[type] == nil or COOK.savedVars[type].data == nil then
    return true
  else
    sv = COOK.savedVars[type].data
  end

  local distance
  if scale == nil then
    distance = COOK.minDefault
  else
    distance = scale
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
    -- item[3] is Vendor Name
    if item[3] == name then
      -- regardless of loc, don't duplicate the Vendor
      return false
    end
    -- if dist < distance then -- near player location
    --     if name == nil then -- npc, quest, vendor all but harvesting
    --         return false
    --     else -- harvesting only
    --         if item[3] == name then
    --             return false
    --         elseif item[3] ~= name then
    --             return true
    --         end
    --     end
    -- end
  end

  return log
end

function COOK.VendLog(type, nodes, ...)
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

  -- data[3] is the target name
  if COOK.savedVars["internal"].debug == 1 then
    COOK.Debug("Logged [" .. type .. "] data: " .. dataStr)
    COOK.Debug("For [" .. data[3] .. "]")
  end

  if #sv == 0 then
    sv[1] = data
  else
    sv[#sv + 1] = data
  end
end

---
-- other
---

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

  if #sv == 0 then
    sv[1] = data
  else
    sv[#sv + 1] = data
  end
end

-- Checks if we already have an entry for the object/npc within a certain x/y distance
function COOK.LogCheck(type, nodes, name)
  local log
  local sv

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

    if item[1] == name then
      log = item
      -- COOK.Debug("item[1] equals the name")
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
--[[
ZO_PreHook(ZO_Reticle, "TryHandlingInteraction", function(interactionPossible, currentFrameTimeSeconds)

    action, name, interactBlocked, isOwned, additionalInfo, contextualInfo, contextualLink, isCriminalInteract = GetGameCameraInteractableActionInfo()
    local type_of_action = GetInteractionType()
    if type_of_action ~= 0 then
        d(type_of_action)
    end
    if name and not ignored_interaction_types[action] and not ignored_tagets[name] then
        COOK.Debug("I am looking at name " .. name)
        COOK.name = name
    else
        -- COOK.Debug("I am not looking at somethinge ")
        COOK.name = WRONG_INTERACTION_TYPE
    end
end)

local function OnInteract(event_code, client_interact_result, interact_target_name)
    d("Provisioner")
    d(event_code)
    d(client_interact_result)
    text = zo_strformat(SI_CHAT_MESSAGE_FORMATTER, interact_target_name)
    d(text)
    d("Provisioner Camera Interact")
    action, name, interactBlocked, isOwned, additionalInfo, contextualInfo, contextualLink, isCriminalInteract = GetGameCameraInteractableActionInfo()
    d(action)
    text = zo_strformat(SI_CHAT_MESSAGE_FORMATTER, name)
    d(text)
    d(interactBlocked)
    d(additionalInfo)
    d("Provisioner Interaction Type")
    interaction_type = GetInteractionType()
    d(interaction_type)
    d("OnInteract End")
end
EVENT_MANAGER:RegisterForEvent(AddonName,EVENT_CLIENT_INTERACT_RESULT, OnInteract)
]]--

-----------------------------------------
--            API Helpers              --
-----------------------------------------
function COOK.InventoryChanged(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason, stackCountChange)
  _, targetName, _, _, _, _, _, _ = GetGameCameraInteractableActionInfo()
  -- targetName = COOK.name
  local type_of_action = GetInteractionType()
  if COOK.savedVars["internal"].debug == 1 then
    COOK.Debug("CHECK Target name: " .. targetName .. " interaction type was " .. type_of_action)
    COOK.Debug("CHECK Update reason: " .. updateReason)
  end

  if updateReason == INVENTORY_UPDATE_REASON_ITEM_CHARGE then return end
  if updateReason == INVENTORY_UPDATE_REASON_DURABILITY_CHANGE then return end
  -- note to self, if I wanted to track quest rewards they are conversations
  if ignored_interaction_types[type_of_action] then
    targetName = WRONG_INTERACTION_TYPE
  end
  if ignored_tagets[targetName] then
    if COOK.savedVars["internal"].debug == 1 then
      COOK.Debug("IGNORE: I made it to here and was one of the writ crates!")
    end
    targetName = WRONG_INTERACTION_TYPE
  end
  if targetName == WRONG_INTERACTION_TYPE then return end
  if COOK.savedVars["internal"].debug == 1 then
    COOK.Debug("NEW IC: I made it to here and the interaction type was " .. type_of_action)
  end

  if SHARED_INVENTORY:AreAnyItemsNew(nil, nil, BAG_BACKPACK, BAG_VIRTUAL) then
    local itemLink = GetItemLink(bagId, slotIndex)
    local link = COOK.ItemLinkParse(itemLink)
    local x, y, a, subzone, world, texturename = COOK.GetUnitPosition("player")
    COOK.recordData("provisioning", texturename, x, y, targetName, itemLink, stackCountChange, link.id)
    if COOK.savedVars["internal"].debug == 1 then
      COOK.Debug("NEW IC: Picked up a " .. itemLink .. " and I picked up " .. stackCountChange)
      COOK.Debug("NEW IC: However the event code was " .. eventCode .. " and the reason was " .. updateReason)
    end
  else
    if COOK.savedVars["internal"].debug == 1 then
      COOK.Debug("NEW IC: Something changed but it was not a new item.")
    end
  end
end

function COOK.GetUnitPosition(tag)
  local setMap = SetMapToPlayerLocation() -- Fix for bug #23
  if setMap == 2 then
    CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged") -- Fix for bug #23
  end

  local x, y, a = GetMapPlayerPosition(tag)
  local subzone = GetMapName()
  local world = GetUnitZone(tag)
  textureName = LMP:GetZoneAndSubzone(true)

  if textureName == "eyevea_base" then
    worldMapName = GetUnitZone("player")
    worldMapName = string.lower(worldMapName)
    textureName = worldMapName .. "/" .. textureName
  end

  return x, y, a, subzone, world, textureName
end

function COOK.contains(table, value)
  for key, v in pairs(table) do
    if v == value then
      return key
    end
  end
  return nil
end

-----------------------------------------
--           Debug Logger              --
-----------------------------------------

local function EmitMessage(text)
  if (CHAT_SYSTEM)
  then
    if (text == "")
    then
      text = "[Empty String]"
    end

    CHAT_SYSTEM:AddMessage(text)
  end
end

local function EmitTable(t, indent, tableHistory)
  indent = indent or "."
  tableHistory = tableHistory or {}

  for k, v in pairs(t)
  do
    local vType = type(v)

    EmitMessage(indent .. "(" .. vType .. "): " .. tostring(k) .. " = " .. tostring(v))

    if (vType == "table")
    then
      if (tableHistory[v])
      then
        EmitMessage(indent .. "Avoiding cycle on table...")
      else
        tableHistory[v] = true
        EmitTable(v, indent .. "  ", tableHistory)
      end
    end
  end
end

function COOK.Debug(...)
  for i = 1, select("#", ...) do
    local value = select(i, ...)
    if (type(value) == "table")
    then
      EmitTable(value)
    else
      EmitMessage(tostring(value))
    end
  end
end

-----------------------------------------
--           Loot Tracking             --
-----------------------------------------

function COOK.ItemLinkParse(link)

  local Field1, Field2, Field3, Field4, Field5 = ZO_LinkHandler_ParseLink(link)

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
  for _, entry in pairs(items) do
    if entry[1] == itemName then
      return true
    end
  end
  return false
end

function COOK.recordData(dataType, map, x, y, nodeName, itemLink, quantity, itemId)
  if COOK.savedVars["internal"].debug == 1 then
    COOK.Debug("Looted : " .. itemLink .. " ftom: " .. nodeName)
  end
  data = COOK.LogCheck(dataType, { map }, nodeName)
  if not data then
    -- when there is no node at the given location, save a new entry
    if COOK.savedVars["internal"].debug == 1 then
      COOK.Debug("Create New : " .. nodeName)
    end
    COOK.Log(dataType, { map }, nodeName, { { itemLink, itemId } })
  else
    --otherwise add the new data to the entry
    if COOK.savedVars["internal"].debug == 1 then
      COOK.Debug("Looking to insert " .. itemLink .. " into: " .. nodeName)
    end
    if data[1] == nodeName then
      if not COOK.CheckDupeContents(data[2], itemLink) then
        if COOK.savedVars["internal"].debug == 1 then
          -- COOK.Debug("Inserted " .. itemName .. " from " .. nodeName .. " into existing " .. data[3])
          COOK.Debug("Inserted into " .. nodeName)
        end
        table.insert(data[2], { itemLink, itemId })
      else
        if COOK.savedVars["internal"].debug == 1 then
          COOK.Debug("Entry Found " .. itemLink)
        end
      end
    else
      if COOK.savedVars["internal"].debug == 1 then
        -- COOK.Debug("Didn't insert " .. itemName .. " from " .. nodeName .. " into existing " .. data[3])
        COOK.Debug("Data[1] did not equal the nodename.")
        COOK.Debug("Adding: " .. nodeName)
      end
      COOK.Log(dataType, { map }, nodeName, { { itemLink, itemId } })
    end
  end
end


-----------------------------------------
--          Vendor Tracking            --
-----------------------------------------
-- /script d({GetItemLinkItemType("|H1:item:45815:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")})
function COOK.VendorOpened()
  local x, y, a, subzone, world, texturename = COOK.GetUnitPosition("player")

  dataType = "vendor"

  local storeItems = {}

  _, targetName, _, _, _, _, _, _ = GetGameCameraInteractableActionInfo()

  if COOK.VendLogCheck(dataType, { texturename }, x, y, 0.1, targetName) then
    for entryIndex = 1, GetNumStoreItems() do
      local icon, name, stack, price, sellPrice, meetsRequirementsToBuy, meetsRequirementsToUse, quality, questNameColor, currencyType1, currencyQuantity1, currencyType2, currencyQuantity2, entryType, buyStoreFailure, buyErrorStringId = GetStoreEntryInfo(entryIndex)
      local itemLink = GetStoreItemLink(entryIndex, LINK_STYLE_BRACKETS)
      local itemId = GetItemLinkItemId(itemLink)
      local itemLinkName = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink))

      if (stack > 0) then
        local itemData = {
          itemLink = itemLink,
          itemId = itemId,
          name = itemLinkName,
          stack = stack,
          price = price,
          sellPrice = sellPrice,
          quality = quality,
          questNameColor = questNameColor,
          currencyType1 = currencyType1,
          currencyQuantity1 = currencyQuantity1,
          currencyType2 = currencyType2,
          currencyQuantity2 = currencyQuantity2,
          storeEntryTypeInfo = { GetStoreEntryTypeInfo(entryIndex) },
          storeEntryStatValue = GetStoreEntryStatValue(entryIndex),
        }

        storeItems[#storeItems + 1] = itemData
      end
    end

    COOK.VendLog(dataType, { texturename }, x, y, targetName, storeItems)
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

  COOK.Debug("Provisioner starting import from Esohead")
  for category, data in pairs(EH.savedVars) do
    if category ~= "internal" and category == "provisioning" then
      for map, location in pairs(data.data) do
        newMapName = COOK.GetNewMapName(map)
        if newMapName then
          for itemId, nodes in pairs(location[5]) do
            for index, node in pairs(nodes) do
              -- [1] X, [2] Y, [3] Stack Size, [4] = [[Sack]]
              if COOK.IsValidNode(node[4]) and COOK.GetTradeskillByMaterial(itemId) then
                itemName = COOK.GetItemNameFromItemID(itemId)
                COOK.recordData("provisioning", newMapName, node[1], node[2], node[4], itemName, itemId)
              end
            end
          end
        else
          for itemId, nodes in pairs(location[5]) do
            for index, node in pairs(nodes) do
              -- [1] X, [2] Y, [3] Stack Size, [4] = [[Sack]]
              if COOK.IsValidNode(node[4]) and COOK.GetTradeskillByMaterial(itemId) then
                itemName = COOK.GetItemNameFromItemID(itemId)
                COOK.recordData("unlocalized", map, node[1], node[2], node[4], itemName, itemId)
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

  COOK.Debug("Provisioner starting import from EsoheadMerge")
  for category, data in pairs(EHM.savedVars) do
    if category ~= "internal" and category == "provisioning" then
      for map, location in pairs(data.data) do
        newMapName = COOK.GetNewMapName(map)
        if newMapName then
          for itemId, nodes in pairs(location[5]) do
            for index, node in pairs(nodes) do
              -- [1] X, [2] Y, [3] Stack Size, [4] = [[Sack]]
              if COOK.IsValidNode(node[4]) and COOK.GetTradeskillByMaterial(itemId) then
                itemName = COOK.GetItemNameFromItemID(itemId)
                COOK.recordData("provisioning", newMapName, node[1], node[2], node[4], itemName, itemId)
              end
            end
          end
        else
          for itemId, nodes in pairs(location[5]) do
            for index, node in pairs(nodes) do
              -- [1] X, [2] Y, [3] Stack Size, [4] = [[Sack]]
              if COOK.IsValidNode(node[4]) and COOK.GetTradeskillByMaterial(itemId) then
                itemName = COOK.GetItemNameFromItemID(itemId)
                COOK.recordData("unlocalized", map, node[1], node[2], node[4], itemName, itemId)
              end
            end
          end
        end
      end
    end
  end
  COOK.Debug("Import Complete")
end

local COOK_PROVISIONER_XLOC = 1
local COOK_PROVISIONER_YLOC = 2
local COOK_PROVISIONER_NPC_NAME = 3
local COOK_PROVISIONER_DATA = 4

function COOK.GetVendorInventoryFromSavedVars(npcString)
  COOK.Debug("Get Vendor Inventory From Saved Vars starting...")
  local x, y, a, subzone, world, texturename = COOK.GetUnitPosition("player")
  local vendorData = COOK.savedVars["vendor"]["data"][texturename]
  local npcName = npcString
  if npcString == nil then npcName = "Sosia Epinard" end
  COOK.Debug(npcName)
  local itemType = nil
  local hasEntry = false
  local vendorDataFound = nil
  local dataTable = {}
  for index, data in pairs(vendorData) do
    -- COOK.Debug(string.format("index : %s", index))
    for inventoryIndex, inventoryData in pairs(data) do
      -- COOK.Debug(string.format("inventoryIndex : %s", inventoryIndex))
      if inventoryData == npcName then
        vendorDataFound = vendorData[index][COOK_PROVISIONER_DATA]
      end
    end
  end
  if vendorDataFound then
    -- COOK.Debug("Data Found")
    for index, inventoryData in pairs(vendorDataFound) do
      COOK.Debug(string.format("Looking for: %s", inventoryData.itemLink))
      itemType = GetItemLinkItemType(inventoryData.itemLink)
      hasEntry = false
      if MasterMerchant and itemType then
        if MasterMerchant["vendor_price_table"][itemType] then
          if MasterMerchant["vendor_price_table"][itemType][inventoryData.itemId] then
            COOK.Debug(string.format("MasterMerchant has entry itemType %s : %s, for %s", itemType, inventoryData.itemId, MasterMerchant["vendor_price_table"][itemType][inventoryData.itemId]))
            hasEntry = true
          end
        end
      end
      local notNeeded = itemType == ITEMTYPE_CONTAINER or itemType == ITEMTYPE_DRINK or itemType == ITEMTYPE_FOOD
      if not hasEntry and not notNeeded then
        COOK.Debug(string.format("MasterMerchant saved itemType %s : %s, for %s", itemType, inventoryData.itemId, inventoryData.price))
        dataTable[itemType] = dataTable[itemType] or {}
        dataTable[itemType][inventoryData.itemId] = inventoryData.price
      end
    end
  end

  COOK.savedVars["vendor_export"]["data"][npcName] = COOK.savedVars["vendor_export"]["data"][npcName] or {}
  COOK.savedVars["vendor_export"]["data"][npcName] = dataTable
  COOK.Debug("Saved Vendor Inventory...")
end

local function ResetVendorByZone()
  local x, y, a, subzone, world, texturename = COOK.GetUnitPosition("player")
  COOK.Debug(string.format("Reset Vendor By Zone: %s", texturename))
  COOK.savedVars["vendor"]["data"][texturename] = {}
  COOK.savedVars["vendor_export"]["data"] = {}
end

-----------------------------------------
--           Slash Command             --
-----------------------------------------

SLASH_COMMANDS["/cook"] = function(cmd)
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

    if #commands == 2 and commands[2] == "vendor" then
      ResetVendorByZone()
      COOK.Debug("Current zone's vendor data has been completely reset")
    else
      for type, sv in pairs(COOK.savedVars) do
        if type ~= "internal" then
          COOK.savedVars[type].data = {}
        end
      end

      COOK.Debug("Saved data has been completely reset")
    end

  elseif commands[1] == "vendor" then
    if commands[2] ~= nil then
      COOK.GetVendorInventoryFromSavedVars(commands[2])
    else
      COOK.GetVendorInventoryFromSavedVars()
    end

  elseif commands[1] == "datalog" then
    COOK.Debug("---")
    COOK.Debug("Complete list of gathered data:")
    COOK.Debug("---")

    local counter = {
      ["map"] = 0,
      ["nodes"] = 0,
      ["item"] = 0,
    }

    --[[
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
    --]]

    for category, data in pairs(COOK.savedVars) do
      if category ~= "internal" and category == "provisioning" then
        for map, nodes in pairs(data.data) do
          -- Inc Map Count COOK.Debug(map)
          for n, node in pairs(nodes) do
            local name = node[1]
            local items = node[2]
            -- Inc Node Count COOK.Debug("Node Name " .. name)
            for i, item in pairs(items) do
              -- Inc Item Count COOK.Debug(item[1])
            end
          end
        end
      end
    end

    COOK.Debug("map: " .. COOK.NumberFormat(counter["map"]))
    COOK.Debug("nodes: " .. COOK.NumberFormat(counter["nodes"]))
    COOK.Debug("item: " .. COOK.NumberFormat(counter["item"]))

    COOK.Debug("---")
  end
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

  EVENT_MANAGER:RegisterForEvent("Provisioner", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, COOK.InventoryChanged)
  EVENT_MANAGER:RegisterForEvent("Provisioner", EVENT_OPEN_STORE, COOK.VendorOpened)
end

EVENT_MANAGER:RegisterForEvent("Provisioner", EVENT_ADD_ON_LOADED, function(eventCode, addOnName)
  if addOnName == "Provisioner" then
    COOK.Initialize()
    COOK.OnLoad(eventCode, addOnName)
  end
end)