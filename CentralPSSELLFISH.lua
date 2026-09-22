-- Fish Selling System - Custom Button + Gems Reward (Bracket Based)
print("(Loaded) Fish Selling System - Custom Button + Gems Reward")

local HSF_ADMIN_COMMAND = "fishadmin"

local hsf_config = {
    EVENT_ACTIVE = false,
    EVENT_MULTIPLIER = 2,
    FISH_WORLD = "FISHING",
    WARP_BUTTON_ENABLED = true,
    SAVE_KEY = "HERZZ_SELLFISH_CONFIG_GEMS_V12",
    AUTO_SELL_IDLE_TIMEOUT = 80,
}

local Roles = {
    ROLE_DEVELOPER = 1000,
    ROLE_DEFAULT = 0
}

local hsf_sessionState = {}
local hsf_FISH_ACTION_TYPE = 64

-- Auto Sell State
local autoSellEnabled = {}
local autoSellIdleTimer = {}

-- ============================================================
--  PRICE BRACKETS (Weight Range → Gems)
-- ============================================================
local HSF_PRICE_BRACKETS = {
    { min = 0,   max = 15,  gems = 10000 },
    { min = 16,  max = 20,  gems = 15000 },
    { min = 21,  max = 30,  gems = 25000 },
    { min = 31,  max = 50,  gems = 50000 },
    { min = 51,  max = 80,  gems = 70000 },
    -- NOTE: gap 81-120 di spec asli — kalau bukan typo, bracket ini return 0
    { min = 121, max = 160, gems = 120000 },
    { min = 161, max = 200, gems = 180000 },
}

-- Cari reward untuk 1 ekor ikan berdasarkan beratnya
local function hsf_getFishReward(weight)
    for _, b in ipairs(HSF_PRICE_BRACKETS) do
        if weight >= b.min and weight <= b.max then
            return b.gems
        end
    end
    return 0
end

-- ============================================================
--  CONFIG SAVE/LOAD
-- ============================================================
local function hsf_saveConfig()
    saveDataToServer(hsf_config.SAVE_KEY, hsf_config)
    print("[SellFish] Config saved to server.")
end

local function hsf_loadConfig()
    local loadedData = loadDataFromServer(hsf_config.SAVE_KEY)
    if loadedData and type(loadedData) == "table" then
        for key, value in pairs(loadedData) do
            hsf_config[key] = value
        end
        print("[SellFish] Config loaded and verified.")
    else
        hsf_saveConfig()
    end
end

local function hsf_getSafeItemName(itemID)
    local item = getItem(itemID)
    return (item and item:getName()) or "Invalid Item"
end

local function hsf_isFish(itemID)
    local item = getItem(itemID)
    return item and item:getActionType() == hsf_FISH_ACTION_TYPE
end

-- Format angka pakai TITIK sebagai pemisah ribuan
local function hsf_formatNum(num)
    local n = tonumber(num) or 0
    local s = tostring(math.floor(n))
    s = s:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
    return s
end

-- ============================================================
--  CALCULATE GEMS REWARD (bracket based)
-- ============================================================
local function hsf_calculatePrize(fishToSell)
    local total = 0
    local eventMultiplier = (hsf_config.EVENT_ACTIVE and hsf_config.EVENT_MULTIPLIER) or 1

    for _, fish in ipairs(fishToSell) do
        local reward = hsf_getFishReward(fish.weight)
        total = total + (reward * eventMultiplier)
    end
    return math.floor(total)
end

-- ============================================================
--  SESSION CLEANUP
-- ============================================================
local function hsf_clearSession(player)
    if not player then return end
    local uid = player:getUserID()
    local netID = player:getNetID()
    if hsf_sessionState[netID] then hsf_sessionState[netID] = nil end
    if hsf_sessionState[uid]   then hsf_sessionState[uid]   = nil end
    autoSellEnabled[uid]   = nil
    autoSellIdleTimer[uid] = nil
end

-- ============================================================
--  SELL FISH SILENT (auto sell)
-- ============================================================
local function hsf_sellAllFishSilent(player)
    local fishList = {}
    local totalWeight = 0
    for _, item in ipairs(player:getInventoryItems()) do
        if hsf_isFish(item:getItemID()) then
            local weight = item:getItemCount()
            table.insert(fishList, { id = item:getItemID(), weight = weight })
            totalWeight = totalWeight + weight
        end
    end

    if #fishList == 0 then return 0, 0, 0 end

    local totalPrize = hsf_calculatePrize(fishList)
    local totalFishSold = #fishList

    for _, fish in ipairs(fishList) do
        player:changeItem(fish.id, -fish.weight, 0)
    end

    if totalPrize > 0 then
        player:addGems(totalPrize)
    end

    return totalFishSold, totalWeight, totalPrize
end

-- ============================================================
--  AUTO SELL RUNNER
-- ============================================================
local function hsf_runAutoSell(player)
    if not player then return false end

    local fishSold, weightSold, gemsEarned = hsf_sellAllFishSilent(player)

    if fishSold > 0 then
        local uid = player:getUserID()

        player:onTalkBubble(player:getNetID(),
            "`0[Auto Sell] Sold " .. fishSold .. " fish for " .. hsf_formatNum(gemsEarned) .. " Gems", 0)
        player:onConsoleMessage("`0[Auto Sell] Sold " .. fishSold .. " fish for " .. hsf_formatNum(gemsEarned) .. " Gems")

        autoSellIdleTimer[uid] = os.time()
        return true
    end
    return false
end

-- ============================================================
--  TICK AUTO SELL
-- ============================================================
onTick(function()
    local currentTime = os.time()
    local players = getServerPlayers()
    if not players then return end

    for _, player in ipairs(players) do
        if player and player:isOnline() then
            local uid = player:getUserID()

            if autoSellEnabled[uid] then
                hsf_runAutoSell(player)

                if autoSellIdleTimer[uid] and (currentTime - autoSellIdleTimer[uid]) >= hsf_config.AUTO_SELL_IDLE_TIMEOUT then
                    autoSellEnabled[uid] = false
                    autoSellIdleTimer[uid] = nil
                    player:onTalkBubble(player:getNetID(), "`0[Auto Sell] Disabled (Inactivity)", 0)
                    player:onConsoleMessage("`0[Auto Sell] Disabled due to inactivity.")
                end
            end
        end
    end
end)

-- ============================================================
--  DIALOG AUTO SELL SETTINGS
-- ============================================================
local function hsf_buildAutoSellDialog(player)
    local uid = player:getUserID()
    local isEnabled = autoSellEnabled[uid] or false

    local dialog = ""
    dialog = dialog .. "set_default_color|`0\n"
    dialog = dialog .. "add_label_with_icon|big|`0Auto Sell Settings|left|7002|\n"
    dialog = dialog .. "add_smalltext|`0Automatically sell fish for Gems.|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. string.format("add_checkbox|hsf_auto_toggle|`0Enable Auto Sell|%d|\n", isEnabled and 1 or 0)
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_button|hsf_save_auto|`0Save Auto Sell|noflags|0|0|\n"
    dialog = dialog .. "add_custom_button|hsf_back_main|textLabel:`0BACK TO MENU;anchor:_button_hsf_save_auto;left:1;margin:40,0;|\n"
    dialog = dialog .. "add_quick_exit|\nend_dialog|hsf_auto_sell_dialog|||\n"
    player:onDialogRequest(dialog)
end

-- ============================================================
--  DIALOG PLAYER MENU
-- ============================================================
local function hsf_buildPlayerMenu(player)
    local fishList = {}
    local totalWeight = 0
    for _, item in ipairs(player:getInventoryItems()) do
        if hsf_isFish(item:getItemID()) then
            local weight = item:getItemCount()
            table.insert(fishList, { id = item:getItemID(), weight = weight })
            totalWeight = totalWeight + weight
        end
    end

    local uid = player:getUserID()
    local autoOn = autoSellEnabled[uid] or false
    local currentGems = player:getGems() or 0

    local dialog = ""
    dialog = dialog .. "set_default_color|`0\n"
    dialog = dialog .. "add_label_with_icon|big|`wAquatic Treasures``|left|7002|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_label_with_icon|small|`0Yo, got any fish to sell? Price depends on the fish weight - the heavier the fish, the bigger the payout!|left|3902|\n"
    dialog = dialog .. "add_spacer|small|\n"

    if hsf_config.EVENT_ACTIVE then
        dialog = dialog .. "add_textbox|`0EVENT ACTIVE: All fish sales are worth " .. hsf_config.EVENT_MULTIPLIER .. "x more right now!|\n"
    end

    -- Your total gems
    dialog = dialog .. "add_label_with_icon|small|`0Your total gems: " .. hsf_formatNum(currentGems) .. "|left|9438|\n"
    dialog = dialog .. "add_spacer|small|\n"

    -- ============================================================
    --  PRICE BY WEIGHT (angka hijau, format titik ribuan)
    -- ============================================================
    dialog = dialog .. "add_smalltext|`oPrice by weight:|\n"
    dialog = dialog .. "add_smalltext|`w 0-15 lb`` =  `210.000`9 Gems``|\n"
    dialog = dialog .. "add_smalltext|`w16-20 lb`` =  `215.000`9 Gems``|\n"
    dialog = dialog .. "add_smalltext|`w21-30 lb`` =  `225.000`9 Gems``|\n"
    dialog = dialog .. "add_smalltext|`w31-50 lb`` =  `250.000`9 Gems``|\n"
    dialog = dialog .. "add_smalltext|`w51-80 lb`` =  `270.000`9 Gems``|\n"
    dialog = dialog .. "add_smalltext|`w121-160 lb`` =  `2120.000`9 Gems``|\n"
    dialog = dialog .. "add_smalltext|`w161-200 lb`` =  `2180.000`9 Gems``|\n"
    dialog = dialog .. "add_spacer|small|\n"

    -- ============================================================
    --  CUSTOM BUTTONS: AUTO SELL & GO WORLD
    --  Jarak 40px antar tombol (sama seperti Auto Sell Settings)
    -- ============================================================
    dialog = dialog .. "add_button|hsf_auto_sell_menu|`0AUTO SELL|noflags|0|0|\n"

    if hsf_config.WARP_BUTTON_ENABLED then
        dialog = dialog .. "add_custom_button|hsf_warp_fishing|textLabel:`0GO " .. hsf_config.FISH_WORLD .. ";anchor:_button_hsf_auto_sell_menu;left:1;margin:40,0;|\n"
    end

    dialog = dialog .. "add_spacer|small|\n"

    -- Auto Sell status
    dialog = dialog .. "reset_placement_x|\n"
    dialog = dialog .. string.format("add_label|small|`0Auto Sell: %s|left|\n", autoOn and "`2ON" or "`4OFF")
    dialog = dialog .. "add_custom_break|\n"
    dialog = dialog .. "add_spacer|small|\n"

    -- Info ikan (di bawah Auto Sell status)
    dialog = dialog .. "reset_placement_x|\n"
    dialog = dialog .. string.format("add_label|small|`0You have %s fish (%s lbs total)|left|\n",
        #fishList, hsf_formatNum(totalWeight))
    dialog = dialog .. "add_custom_break|\n"
    dialog = dialog .. "add_spacer|small|\n"

    -- Sell button (kalau ada ikan)
    if #fishList == 0 then
        dialog = dialog .. "add_textbox|`0You have no fish in your inventory to sell.|\n"
    else
        local totalPrize = hsf_calculatePrize(fishList)
        dialog = dialog .. "add_button|hsf_sell_all|`0Sell your fish (" .. totalWeight .. " lbs -> " .. hsf_formatNum(totalPrize) .. " Gems)|noflags|0|0|\n"
    end

    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_quick_exit|\nend_dialog|hsf_player_menu|||\n"
    player:onDialogRequest(dialog)
end

-- ============================================================
--  DIALOG CONFIRM
-- ============================================================
local function hsf_buildConfirmDialog(player, fishToSell)
    local totalPrize = hsf_calculatePrize(fishToSell)

    local dialog = ""
    dialog = dialog .. "set_default_color|`0\n"
    dialog = dialog .. "add_label_with_icon|big|`0Confirm Sale|left|6292|\n"
    dialog = dialog .. "add_smalltext|`0Please review your transaction.|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_textbox|`0You are selling:|\n"
    for _, fish in ipairs(fishToSell) do
        local fishPrize = hsf_calculatePrize({{ id = fish.id, weight = fish.weight }})
        dialog = dialog .. "add_label|small|`0" .. fish.weight .. " lbs " .. hsf_getSafeItemName(fish.id) .. " -> " .. hsf_formatNum(fishPrize) .. " Gems|left|\n"
    end
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_textbox|`0Total Reward: " .. hsf_formatNum(totalPrize) .. " Gems|\n"

    if totalPrize == 0 then
        dialog = dialog .. "add_textbox|`4Reward for these fish is 0 Gems.|\n"
    end

    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_button|hsf_confirm_sale|`0Confirm|noflags|0|0|\n"
    dialog = dialog .. "add_button|hsf_cancel_sale|`0Cancel|noflags|0|0|\n"
    dialog = dialog .. "end_dialog|hsf_confirm_dialog|Close||\n"
    player:onDialogRequest(dialog)
end

-- ============================================================
--  ADMIN MENUS
-- ============================================================
local function hsf_buildAdminMainMenu(player)
    local dialog = ""
    dialog = dialog .. "set_default_color|`0\n"
    dialog = dialog .. "add_label_with_icon|big|`0Fish Sell Admin|left|2426|\n"
    dialog = dialog .. "add_smalltext|`0Configure the fish selling system.|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_button|hsf_admin_open_prices|`0Configure Price|noflags|0|0|\n"
    dialog = dialog .. "add_button|hsf_admin_open_event|`0Manage Global Event|noflags|0|0|\n"
    dialog = dialog .. "add_button|hsf_admin_open_general|`0General Settings|noflags|0|0|\n"
    dialog = dialog .. "add_button|hsf_admin_auto_config|`0Auto Sell Config|noflags|0|0|\n"
    dialog = dialog .. "add_quick_exit|\nend_dialog|hsf_admin_main|Close||\n"
    player:onDialogRequest(dialog)
end

local function hsf_buildPriceAdminDialog(player)
    local dialog = ""
    dialog = dialog .. "set_default_color|`0\n"
    dialog = dialog .. "add_label_with_icon|big|`0Price Config|left|2426|\n"
    dialog = dialog .. "add_smalltext|`oPrice by weight:|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_smalltext|`w 0-15 lb`` =  `210.000`9 Gems``|left|\n"
    dialog = dialog .. "add_smalltext|`w16-20 lb`` =  `215.000`9 Gems``|left|\n"
    dialog = dialog .. "add_smalltext|`w21-30 lb`` =  `225.000`9 Gems``|left|\n"
    dialog = dialog .. "add_smalltext|`w31-50 lb`` =  `250.000`9 Gems``|left|\n"
    dialog = dialog .. "add_smalltext|`w51-80 lb`` =  `270.000`9 Gems``|left|\n"
    dialog = dialog .. "add_smalltext|`w121-160 lb`` =  `2120.000`9 Gems``|left|\n"
    dialog = dialog .. "add_smalltext|`w161-200 lb`` =  `2180.000`9 Gems``|left|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_textbox|`4Note: Bracket di-hardcode di script.|\n"
    dialog = dialog .. "add_textbox|`4Edit HSF_PRICE_BRACKETS untuk ubah.|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_button|hsf_admin_back|`0Back to Admin Menu|noflags|0|0|\n"
    dialog = dialog .. "end_dialog|hsf_admin_prices|Close||\n"
    player:onDialogRequest(dialog)
end

local function hsf_buildEventAdminDialog(player)
    local dialog = ""
    dialog = dialog .. "set_default_color|`0\n"
    dialog = dialog .. "add_label_with_icon|big|`0Global Event Config|left|1430|\n"
    dialog = dialog .. "add_smalltext|`0Manage the server-wide sell price multiplier event.|\n"
    dialog = dialog .. "add_spacer|small|\n"
    local status = hsf_config.EVENT_ACTIVE and "`2ACTIVE" or "`4INACTIVE"
    dialog = dialog .. "add_textbox|`0Event Status: " .. status .. "`0|\n"
    dialog = dialog .. "add_text_input|hsf_admin_multiplier|`0Event Multiplier (e.g. 2 for 2x):|" .. hsf_config.EVENT_MULTIPLIER .. "|4|numeric|\n"
    if hsf_config.EVENT_ACTIVE then
        dialog = dialog .. "add_button|hsf_admin_disable_event|`0Disable Event|noflags|0|0|\n"
    else
        dialog = dialog .. "add_button|hsf_admin_enable_event|`0Enable Event|noflags|0|0|\n"
    end
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_button|hsf_admin_save_event|`0Save Event Settings|noflags|0|0|\n"
    dialog = dialog .. "add_button|hsf_admin_back|`0Back to Admin Menu|noflags|0|0|\n"
    dialog = dialog .. "end_dialog|hsf_admin_event|Close||\n"
    player:onDialogRequest(dialog)
end

local function hsf_buildGeneralAdminDialog(player)
    local dialog = ""
    dialog = dialog .. "set_default_color|`0\n"
    dialog = dialog .. "add_label_with_icon|big|`0General Settings|left|7070|\n"
    dialog = dialog .. "add_smalltext|`0Manage general settings for the fish selling system.|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_text_input|hsf_admin_fish_world|`0Fishing World Name:|" .. hsf_config.FISH_WORLD .. "|24|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_checkbox|hsf_admin_warp_toggle|`0Enable Go World Button|" .. (hsf_config.WARP_BUTTON_ENABLED and "1" or "0") .. "|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_button|hsf_admin_save_general|`0Save General Settings|noflags|0|0|\n"
    dialog = dialog .. "add_button|hsf_admin_back|`0Back to Admin Menu|noflags|0|0|\n"
    dialog = dialog .. "end_dialog|hsf_admin_general|Close||\n"
    player:onDialogRequest(dialog)
end

local function hsf_buildAutoConfigDialog(player)
    local dialog = ""
    dialog = dialog .. "set_default_color|`0\n"
    dialog = dialog .. "add_label_with_icon|big|`0Auto Sell Config|left|7002|\n"
    dialog = dialog .. "add_smalltext|`0Configure auto sell settings.|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. string.format("add_text_input|hsf_admin_timeout|`0Idle Timeout (seconds):|" .. hsf_config.AUTO_SELL_IDLE_TIMEOUT .. "|4|numeric|\n")
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_button|hsf_admin_save_auto|`0Save Auto Sell Config|noflags|0|0|\n"
    dialog = dialog .. "add_button|hsf_admin_back|`0Back to Admin Menu|noflags|0|0|\n"
    dialog = dialog .. "end_dialog|hsf_admin_auto_config|Close||\n"
    player:onDialogRequest(dialog)
end

-- ============================================================
--  COMMANDS
-- ============================================================
registerLuaCommand({ command = "sellfish", roleRequired = Roles.ROLE_DEFAULT, description = "Open fish selling menu." })
registerLuaCommand({ command = HSF_ADMIN_COMMAND, roleRequired = Roles.ROLE_DEVELOPER, description = "Configure the fish selling system." })

onPlayerCommandCallback(function(world, player, fullCommand)
    local command = fullCommand:match("^(%S+)")

    if command == "sellfish" then
        hsf_buildPlayerMenu(player)
        player:playAudio("spell1.wav")
        return true
    end

    if command == HSF_ADMIN_COMMAND and player:hasRole(Roles.ROLE_DEVELOPER) then
        hsf_buildAdminMainMenu(player)
        return true
    end
    return false
end)

-- ============================================================
--  DIALOG CALLBACK
-- ============================================================
onPlayerDialogCallback(function(world, player, data)
    local netID = player:getNetID()
    hsf_sessionState[netID] = hsf_sessionState[netID] or {}
    local state = hsf_sessionState[netID]
    local dialogName = data.dialog_name
    local button = data.buttonClicked

    -- AUTO SELL DIALOG
    if dialogName == "hsf_auto_sell_dialog" then
        if button == "hsf_save_auto" then
            local enabled = (data.hsf_auto_toggle == "1")
            local uid = player:getUserID()
            autoSellEnabled[uid] = enabled
            if enabled then
                autoSellIdleTimer[uid] = os.time()
                player:onTalkBubble(player:getNetID(), "`0Auto Sell: `2ON", 0)
                player:onConsoleMessage("`0[Auto Sell] Enabled.")
            else
                autoSellIdleTimer[uid] = nil
                player:onTalkBubble(player:getNetID(), "`0Auto Sell: `4OFF", 0)
                player:onConsoleMessage("`0[Auto Sell] Disabled.")
            end
            hsf_buildAutoSellDialog(player)
            return true
        elseif button == "hsf_back_main" then
            hsf_buildPlayerMenu(player)
            return true
        end
        return true
    end

    -- PLAYER MENU
    if dialogName == "hsf_player_menu" then
        if button == "hsf_sell_all" then
            local allFish = {}
            for _, item in ipairs(player:getInventoryItems()) do
                if hsf_isFish(item:getItemID()) then
                    table.insert(allFish, { id = item:getItemID(), weight = item:getItemCount() })
                end
            end
            if #allFish > 0 then
                state.fishToSell = allFish
                hsf_buildConfirmDialog(player, allFish)
            else
                player:onConsoleMessage("`0You have no fish to sell.")
            end
        elseif button == "hsf_warp_fishing" then
            player:enterWorld(hsf_config.FISH_WORLD, "")
        elseif button == "hsf_auto_sell_menu" then
            hsf_buildAutoSellDialog(player)
        end
        return true

    elseif dialogName == "hsf_confirm_dialog" then
        if button == "hsf_cancel_sale" then
            hsf_buildPlayerMenu(player)

        elseif button == "hsf_confirm_sale" then
            -- Re-verify: pastikan ikan masih ada sebelum reward
            local verifiedFish = {}
            local allOk = true
            for _, fish in ipairs(state.fishToSell or {}) do
                local have = player:getItemAmount(fish.id) or 0
                if have >= fish.weight then
                    table.insert(verifiedFish, fish)
                else
                    allOk = false
                end
            end

            if #verifiedFish == 0 then
                player:onConsoleMessage("`4You no longer have those fish.")
                hsf_buildPlayerMenu(player)
                return true
            end

            local totalPrize = hsf_calculatePrize(verifiedFish)
            local totalFishSold = #verifiedFish
            local totalWeightSold = 0

            for _, fish in ipairs(verifiedFish) do
                player:changeItem(fish.id, -fish.weight, 0)
                totalWeightSold = totalWeightSold + fish.weight
            end

            if totalPrize > 0 then
                player:addGems(totalPrize)
                player:onTalkBubble(player:getNetID(),
                    "`0Kamu menjual ikan seharga: " .. hsf_formatNum(totalPrize) .. " Gems", 0)
                player:onConsoleMessage("`0Successfully sold " .. totalFishSold .. " fish (" .. totalWeightSold .. " lbs) for " .. hsf_formatNum(totalPrize) .. " Gems!")
                player:playAudio("cash_register.wav")
            else
                player:onConsoleMessage("`0Sold fish but reward is 0 Gems.")
            end

            if not allOk then
                player:onConsoleMessage("`4Beberapa ikan tidak ditemukan dan tidak dihitung.")
            end

            state.fishToSell = nil
            hsf_buildPlayerMenu(player)
        end
        return true
    end

    -- ADMIN MENUS
    if not player:hasRole(Roles.ROLE_DEVELOPER) then return false end

    if button == "hsf_admin_back" then
        hsf_buildAdminMainMenu(player)
        return true
    end

    if dialogName == "hsf_admin_main" then
        if button == "hsf_admin_open_prices" then
            hsf_buildPriceAdminDialog(player)
        elseif button == "hsf_admin_open_event" then
            hsf_buildEventAdminDialog(player)
        elseif button == "hsf_admin_open_general" then
            hsf_buildGeneralAdminDialog(player)
        elseif button == "hsf_admin_auto_config" then
            hsf_buildAutoConfigDialog(player)
        end
        return true

    elseif dialogName == "hsf_admin_prices" then
        if button == "hsf_admin_back" then
            hsf_buildAdminMainMenu(player)
        end
        return true

    elseif dialogName == "hsf_admin_event" then
        if button == "hsf_admin_enable_event" then
            hsf_config.EVENT_ACTIVE = true
            hsf_saveConfig()
            hsf_buildEventAdminDialog(player)
        elseif button == "hsf_admin_disable_event" then
            hsf_config.EVENT_ACTIVE = false
            hsf_saveConfig()
            hsf_buildEventAdminDialog(player)
        elseif button == "hsf_admin_save_event" then
            local newMultiplier = tonumber(data.hsf_admin_multiplier)
            if newMultiplier and newMultiplier > 1 then
                hsf_config.EVENT_MULTIPLIER = newMultiplier
                hsf_saveConfig()
                player:onConsoleMessage("`0Event multiplier saved.")
            else
                player:onConsoleMessage("`4Invalid multiplier.")
            end
            hsf_buildEventAdminDialog(player)
        end
        return true

    elseif dialogName == "hsf_admin_general" then
        if button == "hsf_admin_save_general" then
            local newWorldName = data.hsf_admin_fish_world
            if newWorldName and newWorldName ~= "" then
                hsf_config.FISH_WORLD = newWorldName:upper()
            end
            hsf_config.WARP_BUTTON_ENABLED = (data.hsf_admin_warp_toggle == "1")
            hsf_saveConfig()
            player:onConsoleMessage("`0General settings saved.")
            hsf_buildGeneralAdminDialog(player)
        end
        return true

    elseif dialogName == "hsf_admin_auto_config" then
        if button == "hsf_admin_save_auto" then
            local newTimeout = tonumber(data.hsf_admin_timeout)
            if newTimeout and newTimeout > 0 then
                hsf_config.AUTO_SELL_IDLE_TIMEOUT = newTimeout
            end
            hsf_saveConfig()
            player:onConsoleMessage("`0Auto Sell config saved!")
            hsf_buildAutoConfigDialog(player)
        end
        return true
    end

    return false
end)

-- ============================================================
--  DISCONNECT CLEANUP
-- ============================================================
onPlayerDisconnectCallback(function(player)
    hsf_clearSession(player)
end)

onAutoSaveRequest(function()
    hsf_saveConfig()
end)

hsf_loadConfig()

print("==========================================")
print("Fish Selling System - Custom Button + Gems Reward")
print("  Command: /sellfish")
print("  Auto Sell: Enable dari menu Auto Sell Settings")
print("  Reward: Gems (bracket based by weight)")
print("  /fishadmin - Admin Config (Role 1000)")
print("==========================================")