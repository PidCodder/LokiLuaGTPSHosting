-- ============================================================
--  INVEST PS EXCHANGE v5.3
--  Spacer diperkecil
-- ============================================================
print("(Loaded) INVEST PS EXCHANGE v5.3")
print("========================================")

-- ============================================================
--  DATABASE
-- ============================================================
local DB_PATH = "herzz_exchange.db"
local db = sqlite.open(DB_PATH)

db:query([[CREATE TABLE IF NOT EXISTS categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT DEFAULT '',
    icon_id INTEGER DEFAULT 242
)]])

db:query([[CREATE TABLE IF NOT EXISTS exchange_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category_id INTEGER NOT NULL,
    req_item_id INTEGER NOT NULL,
    req_item_amount INTEGER DEFAULT 1,
    reward_item_id INTEGER NOT NULL,
    reward_item_amount INTEGER DEFAULT 1,
    duration_seconds INTEGER DEFAULT 0,
    end_time INTEGER DEFAULT 0,
    max_limit INTEGER DEFAULT 0,
    used_count INTEGER DEFAULT 0,
    player_limit INTEGER DEFAULT 0,
    active INTEGER DEFAULT 1
)]])

db:query([[CREATE TABLE IF NOT EXISTS player_tracker (
    user_id TEXT NOT NULL,
    exchange_id INTEGER NOT NULL,
    count INTEGER DEFAULT 0,
    PRIMARY KEY(user_id, exchange_id)
)]])

do
    local function hasColumn(table, col)
        local cols = db:query("PRAGMA table_info("..table..")") or {}
        for _, c in ipairs(cols) do
            if c.name == col then return true end
        end
        return false
    end

    local migrations = {
        {"exchange_items", "duration_seconds", "ALTER TABLE exchange_items ADD COLUMN duration_seconds INTEGER DEFAULT 0"},
        {"exchange_items", "end_time",         "ALTER TABLE exchange_items ADD COLUMN end_time INTEGER DEFAULT 0"},
        {"exchange_items", "max_limit",        "ALTER TABLE exchange_items ADD COLUMN max_limit INTEGER DEFAULT 0"},
        {"exchange_items", "used_count",       "ALTER TABLE exchange_items ADD COLUMN used_count INTEGER DEFAULT 0"},
        {"exchange_items", "player_limit",     "ALTER TABLE exchange_items ADD COLUMN player_limit INTEGER DEFAULT 0"},
    }
    for _, m in ipairs(migrations) do
        if not hasColumn(m[1], m[2]) then
            db:query(m[3])
            print("[Exchange] Migration: "..m[1].."."..m[2])
        end
    end
end

-- ============================================================
--  CONFIG
-- ============================================================
local ADMIN_ROLE = 1000
local PER_ROW    = 7
local ARROW_ICON = 482
local MAIN_ICON  = 3802

-- ============================================================
--  HELPERS
-- ============================================================
local function esc(s) return tostring(s or ""):gsub("'", "''") end
local function getItemName(id) local item = getItem(tonumber(id) or 0); return (item and item:getName()) or ("ID "..tostring(id)) end
local function fmt(n) n = math.floor(tonumber(n or 0) or 0); return tostring(n):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","") end

local function formatTime(seconds)
    if seconds <= 0 then return "Expired" end
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds % 86400) / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if d > 0 then return d.."d "..h.."h"
    elseif h > 0 then return h.."h "..m.."m"
    else return m.."m" end
end

-- ============================================================
--  FUNGSI CATEGORY
-- ============================================================
local function getCategories()
    return db:query("SELECT * FROM categories ORDER BY id ASC") or {}
end

local function getCategoryByID(id)
    local rows = db:query(string.format("SELECT * FROM categories WHERE id=%d", tonumber(id) or 0))
    return rows and rows[1]
end

local function addCategory(name, description, iconID)
    db:query(string.format([[
        INSERT INTO categories (name, description, icon_id)
        VALUES ('%s', '%s', %d)
    ]], esc(name), esc(description or ""), tonumber(iconID) or 242))
    return true
end

local function deleteCategory(id)
    db:query(string.format("DELETE FROM categories WHERE id=%d", tonumber(id) or 0))
    db:query(string.format("DELETE FROM exchange_items WHERE category_id=%d", tonumber(id) or 0))
    return true
end

local function updateCategory(id, name, description, iconID)
    db:query(string.format([[
        UPDATE categories SET name='%s', description='%s', icon_id=%d WHERE id=%d
    ]], esc(name), esc(description or ""), tonumber(iconID) or 242, tonumber(id) or 0))
    return true
end

local function getLastCategoryID()
    local rows = db:query("SELECT id FROM categories ORDER BY id DESC LIMIT 1")
    return rows and rows[1] and tonumber(rows[1].id) or 0
end

-- ============================================================
--  FUNGSI EXCHANGE ITEMS
-- ============================================================
local function getExchangeItems(categoryID)
    local now = os.time()
    return db:query(string.format(
        "SELECT * FROM exchange_items WHERE category_id=%d AND active=1 AND (end_time=0 OR end_time>%d) ORDER BY id ASC",
        tonumber(categoryID) or 0, now
    )) or {}
end

local function getAllItemsByCategory(categoryID)
    return db:query(string.format(
        "SELECT * FROM exchange_items WHERE category_id=%d ORDER BY id ASC",
        tonumber(categoryID) or 0
    )) or {}
end

local function addExchangeItem(categoryID, reqID, reqAmount, rewardID, rewardAmount, duration, limit, playerLimit)
    local endTime = 0
    if (duration or 0) > 0 then
        endTime = os.time() + duration
    end
    db:query(string.format([[
        INSERT INTO exchange_items
        (category_id, req_item_id, req_item_amount, reward_item_id, reward_item_amount,
         duration_seconds, end_time, max_limit, player_limit, used_count, active)
        VALUES (%d, %d, %d, %d, %d, %d, %d, %d, %d, 0, 1)
    ]], tonumber(categoryID) or 0, tonumber(reqID) or 0, tonumber(reqAmount) or 1,
        tonumber(rewardID) or 0, tonumber(rewardAmount) or 1,
        tonumber(duration) or 0, endTime,
        tonumber(limit) or 0, tonumber(playerLimit) or 0))
    return true
end

local function updateExchangeItem(id, reqID, reqAmount, rewardID, rewardAmount, duration, limit, playerLimit)
    local endTime = 0
    if (duration or 0) > 0 then
        endTime = os.time() + duration
    end
    db:query(string.format([[
        UPDATE exchange_items SET
            req_item_id=%d, req_item_amount=%d,
            reward_item_id=%d, reward_item_amount=%d,
            duration_seconds=%d, end_time=%d,
            max_limit=%d, player_limit=%d
        WHERE id=%d
    ]], tonumber(reqID) or 0, tonumber(reqAmount) or 1,
        tonumber(rewardID) or 0, tonumber(rewardAmount) or 1,
        tonumber(duration) or 0, endTime,
        tonumber(limit) or 0, tonumber(playerLimit) or 0,
        tonumber(id) or 0))
    return true
end

local function deleteExchangeItem(id)
    db:query(string.format("DELETE FROM exchange_items WHERE id=%d", tonumber(id) or 0))
    return true
end

local function getExchangeItemByID(id)
    local rows = db:query(string.format("SELECT * FROM exchange_items WHERE id=%d", tonumber(id) or 0))
    return rows and rows[1]
end

local function checkExpired()
    db:query(string.format("UPDATE exchange_items SET active=0 WHERE end_time>0 AND end_time<=%d", os.time()))
end

-- ============================================================
--  PLAYER TRACKER
-- ============================================================
local function getPlayerCount(uid, eid)
    local rows = db:query(string.format(
        "SELECT count FROM player_tracker WHERE user_id='%s' AND exchange_id=%d",
        tostring(uid), tonumber(eid) or 0
    ))
    return rows and rows[1] and tonumber(rows[1].count) or 0
end

local function incrementPlayerCount(uid, eid)
    db:query(string.format(
        "INSERT INTO player_tracker (user_id, exchange_id, count) VALUES ('%s', %d, 1) ON CONFLICT(user_id, exchange_id) DO UPDATE SET count = count + 1",
        tostring(uid), tonumber(eid) or 0
    ))
end

-- ============================================================
--  ADMIN SESSION
-- ============================================================
local adminSession = {}
local function getAdminSession(player)
    local netID = player:getNetID()
    if not adminSession[netID] then
        adminSession[netID] = {
            reqItemID = nil,
            rewardItemID = nil,
            editCategoryID = nil,
            editItemID = nil,
            duration = 0,
            limit = 0,
            playerLimit = 0,
        }
    end
    return adminSession[netID]
end

-- ============================================================
--  UI: MAIN MENU
-- ============================================================
local function showMainMenu(player)
    local categories = getCategories()

    local d = "set_default_color|`o\n"
    d = d .. "text_scaling_string|aaaaaaa|\n"
    d = d .. "add_label_with_icon|big|`wINVEST PS EXCHANGE|left|"..MAIN_ICON.."|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_label_with_icon|small|`0Choose a category to exchange your items.|left|2398|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_custom_break|\n"
    d = d .. "add_spacer|small|\n"

    if #categories == 0 then
        d = d .. "add_textbox|`oTidak ada kategori|left|\n"
    else
        local count = 0
        d = d .. "reset_placement_x|\n"
        for _, cat in ipairs(categories) do
            local icon = tonumber(cat.icon_id) or 242
            local label = "`0" .. cat.name .. "``"
            d = d .. string.format(
                "add_button_with_icon|open_category_%d|%s|noflags|%d|\n",
                cat.id, label, icon
            )
            count = count + 1
            if count % PER_ROW == 0 then
                d = d .. "add_custom_break|\n"
                d = d .. "reset_placement_x|\n"
            end
        end
        if count % PER_ROW ~= 0 then
            d = d .. "add_custom_break|\n"
        end
        d = d .. "add_spacer|small|\n"
    end

    d = d .. "add_label|small|`0Get other `8interesting item`0, here you can get|left|\n"
    d = d .. "add_label|small|`0The best and `4limited `0items!|left|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_quick_exit|\nend_dialog|exchange_main|Close||\n"

    player:onDialogRequest(d)
end

-- ============================================================
--  UI: CATEGORY MENU (Spacer diperkecil)
-- ============================================================
local function showCategoryMenu(player, categoryID)
    checkExpired()
    local cat = getCategoryByID(categoryID)
    if not cat then showMainMenu(player); return end

    local items = getExchangeItems(categoryID)
    local uid = tostring(player:getUserID())

    local d = "set_border_color|112,86,191,255\n"
    d = d .. "set_bg_color|43,34,74,200\n"
    d = d .. "set_default_color|`o\n"
    d = d .. string.format("add_label_with_icon|big|`w%s``|left|%d|\n",
        cat.name, tonumber(cat.icon_id) or 242)
    d = d .. "text_scaling_string|+++++++++++++++|\n"
    d = d .. "add_textbox|\"You drive a hard bargain, friend. But I like a challenge! Let's see if we can make this trade really worth our while.\"|\n"

    if #items == 0 then
        d = d .. "add_textbox|`oNo exchange items available.|left|\n"
    else
        for _, item in ipairs(items) do
            local itemId  = tonumber(item.id) or 0
            local reqId   = tonumber(item.req_item_id) or 0
            local rewId   = tonumber(item.reward_item_id) or 0
            local reqAmt  = tonumber(item.req_item_amount) or 1
            local rewAmt  = tonumber(item.reward_item_amount) or 1
            local reqName = getItemName(reqId)
            local rewName = getItemName(rewId)
            local hasItem = player:getItemAmount(reqId) or 0
            local enough  = hasItem >= reqAmt

            local maxLimit  = tonumber(item.max_limit) or 0
            local usedCount = tonumber(item.used_count) or 0
            local serverRemaining = 0
            local isSoldOut = false
            if maxLimit > 0 then
                serverRemaining = maxLimit - usedCount
                if serverRemaining <= 0 then isSoldOut = true end
            end

            local playerLimit = tonumber(item.player_limit) or 0
            local playerUsed  = playerLimit > 0 and getPlayerCount(uid, itemId) or 0
            local isPlayerMaxed = (playerLimit > 0 and playerUsed >= playerLimit)

            local endTime = tonumber(item.end_time) or 0
            local isExpired = (endTime > 0 and endTime <= os.time())

            -- Item block (langsung tanpa spacer)
            d = d .. string.format(
                "add_button_with_icon|info_%d|`$%s``|frame|%d|%d|\n",
                reqId, reqName, reqId, reqAmt
            )
            d = d .. string.format(
                "add_button_with_icon|DO_NOTHING||noflags|%d||\n",
                ARROW_ICON
            )
            d = d .. string.format(
                "add_button_with_icon|info_%d|`$%s``|frame|%d|%d|\n",
                rewId, rewName, rewId, rewAmt
            )

            if endTime > 0 then
                d = d .. string.format(
                    "add_smalltext|`s(Expire In `w%s``)|\n",
                    formatTime(math.max(0, endTime - os.time()))
                )
            end

            d = d .. string.format(
                "add_smalltext|`sYou have `w%s/%s`` %s``|\n",
                fmt(hasItem), fmt(reqAmt), reqName
            )

            if maxLimit > 0 then
                d = d .. string.format(
                    "add_smalltext|`sLimit: `w%d left``|\n",
                    math.max(0, serverRemaining)
                )
            end

            local isDisabled = (not enough) or isSoldOut or isExpired or isPlayerMaxed

            if isDisabled then
                d = d .. "add_small_font_button|exchange_disabled|`4NOT AVAILABLE|small|\n"
            else
                d = d .. string.format(
                    "add_small_font_button|exq_%d_%d_%d_%d_%d|GET!|small|\n",
                    reqId, reqAmt, rewId, rewAmt, itemId
                )
            end

            d = d .. "add_button_with_icon||END_LIST|||%d|\n"
            d = d .. "add_custom_break|\n"
        end
    end

    d = d .. "add_button|back_to_main|`wBack|noflags|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|exchange_go|Nevermind||\n"

    player:onDialogRequest(d)
end

-- ============================================================
--  DO EXCHANGE
-- ============================================================
local function doExchange(player, exchangeID)
    local item = getExchangeItemByID(exchangeID)
    if not item then
        player:onConsoleMessage("`4Exchange Gagal! Item tidak ditemukan.")
        return
    end

    local cat = getCategoryByID(item.category_id)
    if not cat then
        player:onConsoleMessage("`4Exchange Gagal! Kategori tidak ditemukan.")
        return
    end

    local uid = tostring(player:getUserID())
    local reqID = tonumber(item.req_item_id) or 0
    local reqAmt = tonumber(item.req_item_amount) or 1
    local rewardID = tonumber(item.reward_item_id) or 0
    local rewardAmt = tonumber(item.reward_item_amount) or 1
    local maxLimit = tonumber(item.max_limit) or 0
    local usedCount = tonumber(item.used_count) or 0
    local endTime = tonumber(item.end_time) or 0
    local playerLimit = tonumber(item.player_limit) or 0

    if endTime > 0 and endTime <= os.time() then
        player:onConsoleMessage("`4Exchange Gagal! Item sudah expired.")
        showCategoryMenu(player, cat.id)
        return
    end

    if maxLimit > 0 and usedCount >= maxLimit then
        player:onConsoleMessage("`4Exchange Gagal! Stock sudah habis.")
        showCategoryMenu(player, cat.id)
        return
    end

    if playerLimit > 0 then
        local used = getPlayerCount(uid, exchangeID)
        if used >= playerLimit then
            player:onConsoleMessage(string.format(
                "`4Exchange Gagal! Kamu sudah mencapai limit (%d/%d)", used, playerLimit))
            showCategoryMenu(player, cat.id)
            return
        end
    end

    local hasItem = player:getItemAmount(reqID) or 0
    if hasItem < reqAmt then
        player:onConsoleMessage(string.format("`4Exchange Gagal! Butuh %d %s!",
            reqAmt, getItemName(reqID)))
        showCategoryMenu(player, cat.id)
        return
    end

    if (player:getItemAmount(rewardID) or 0) + rewardAmt > 200 then
        player:onConsoleMessage("`4Exchange Gagal! Inventory penuh.")
        showCategoryMenu(player, cat.id)
        return
    end

    player:changeItem(reqID, -reqAmt, 0)
    player:changeItem(rewardID, rewardAmt, 0)

    incrementPlayerCount(uid, exchangeID)
    if maxLimit > 0 then
        db:query(string.format("UPDATE exchange_items SET used_count=used_count+1 WHERE id=%d", exchangeID))
    end

    player:onConsoleMessage(string.format("`2Exchange Berhasil! %d %s → %d %s!",
        reqAmt, getItemName(reqID), rewardAmt, getItemName(rewardID)))
    player:playAudio("success.wav")

    showCategoryMenu(player, cat.id)
end

-- ============================================================
--  UI: ADMIN MENU
-- ============================================================
local function showAdminMenu(player)
    if not player:hasRole(ADMIN_ROLE) then
        player:onConsoleMessage("`4Hanya Role "..ADMIN_ROLE.." yang bisa menggunakan command ini!")
        return false
    end

    local categories = getCategories()

    local d = "set_default_color|`o\n"
    d = d .. "text_scaling_string|aaaaaaa|\n"
    d = d .. "add_label_with_icon|big|`wINVEST PS EXCHANGE ADMIN|left|"..MAIN_ICON.."|\n"
    d = d .. "add_custom_break|\n"
    d = d .. "add_spacer|small|\n"

    d = d .. "add_label|small|`wKATEGORI:|left|\n"
    d = d .. "add_spacer|small|\n"

    if #categories == 0 then
        d = d .. "add_textbox|`oTidak ada kategori|left|\n"
    else
        for _, cat in ipairs(categories) do
            local items = getAllItemsByCategory(cat.id)
            d = d .. string.format("add_label_with_icon|small|`w%s `o(%d item)|left|%d|\n",
                cat.name, #items, tonumber(cat.icon_id) or 242)
            d = d .. string.format("add_button|admin_add_item_%d|`2+ Add Item|noflags|\n", cat.id)
            d = d .. string.format("add_button|admin_view_items_%d|`9View Items|noflags|\n", cat.id)
            d = d .. string.format("add_button|admin_edit_cat_%d|`5Edit Category|noflags|\n", cat.id)
            d = d .. string.format("add_button|admin_del_cat_%d|`4Delete Category|noflags|\n", cat.id)
            d = d .. "add_spacer|small|\n"
        end
    end

    d = d .. "add_custom_break|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_label|small|`wTAMBAH KATEGORI:|left|\n"
    d = d .. "add_text_input|cat_name|Nama Kategori:||30|\n"
    d = d .. "add_text_input|cat_desc|Deskripsi:||50|\n"
    d = d .. "add_text_input|cat_icon|Icon ID:|242|10|numeric|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|admin_add_cat|`2Add Category|noflags|\n"
    d = d .. "add_quick_exit|\nend_dialog|exchange_admin|Close||\n"

    player:onDialogRequest(d)
end

-- ============================================================
--  UI: ADMIN VIEW ITEMS
-- ============================================================
local function showAdminViewItems(player, categoryID)
    if not player:hasRole(ADMIN_ROLE) then return end

    local cat = getCategoryByID(categoryID)
    if not cat then showAdminMenu(player); return end

    local items = getAllItemsByCategory(categoryID)

    local d = "set_default_color|`o\n"
    d = d .. "text_scaling_string|aaaaaaa|\n"
    d = d .. string.format("add_label_with_icon|big|`w%s - ITEMS|left|%d|\n", cat.name, tonumber(cat.icon_id) or 242)
    d = d .. "add_custom_break|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. string.format("add_smalltext|`oTotal: %d item|left|\n", #items)
    d = d .. "add_spacer|small|\n"

    if #items == 0 then
        d = d .. "add_textbox|`oTidak ada item|left|\n"
    else
        for _, item in ipairs(items) do
            local info = ""
            local maxLimit = tonumber(item.max_limit) or 0
            local usedCount = tonumber(item.used_count) or 0
            local playerLimit = tonumber(item.player_limit) or 0
            local endTime = tonumber(item.end_time) or 0
            local active = tonumber(item.active) or 0

            if maxLimit > 0 then
                info = info .. string.format(" `7[%d/%d]", usedCount, maxLimit)
            end
            if playerLimit > 0 then
                info = info .. string.format(" `7[P:%d]", playerLimit)
            end
            if endTime > 0 then
                info = info .. string.format(" `7[%s]", formatTime(math.max(0, endTime - os.time())))
            end
            if active == 0 then
                info = info .. " `4[EXPIRED]"
            end

            d = d .. string.format("add_label_with_icon|small|`w%s x%d → `2%s x%d%s|left|%d|\n",
                getItemName(item.req_item_id), item.req_item_amount,
                getItemName(item.reward_item_id), item.reward_item_amount,
                info, item.req_item_id)
            d = d .. string.format("add_button|admin_edit_item_%d|`5Edit|noflags|\n", item.id)
            d = d .. string.format("add_button|admin_del_item_%d|`4Delete|noflags|\n", item.id)
            d = d .. "add_spacer|small|\n"
        end
    end

    d = d .. "add_custom_break|\n"
    d = d .. string.format("add_button|admin_add_item_%d|`2+ Add Item|noflags|\n", categoryID)
    d = d .. "add_button|admin_back|`wKembali|noflags|\n"
    d = d .. "add_quick_exit|\nend_dialog|admin_view_items|Close||\n"
    player:onDialogRequest(d)
end

-- ============================================================
--  UI: ADMIN EDIT CATEGORY
-- ============================================================
local function showAdminEditCategory(player, categoryID)
    if not player:hasRole(ADMIN_ROLE) then return end

    local cat = getCategoryByID(categoryID)
    if not cat then showAdminMenu(player); return end

    local d = "set_default_color|`o\n"
    d = d .. "text_scaling_string|aaaaaaa|\n"
    d = d .. string.format("add_label_with_icon|big|`wEDIT KATEGORI|left|%d|\n", tonumber(cat.icon_id) or 242)
    d = d .. "add_custom_break|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. string.format("add_text_input|edit_cat_name|Nama:|%s|30|\n", cat.name)
    d = d .. string.format("add_text_input|edit_cat_desc|Deskripsi:|%s|50|\n", cat.description or "")
    d = d .. string.format("add_text_input|edit_cat_icon|Icon ID:|%d|10|numeric|\n", tonumber(cat.icon_id) or 242)
    d = d .. "add_spacer|small|\n"
    d = d .. string.format("add_button|admin_save_cat_%d|`2Save|noflags|\n", categoryID)
    d = d .. "add_button|admin_back|`wKembali|noflags|\n"
    d = d .. "add_quick_exit|\nend_dialog|admin_edit_cat|Close||\n"

    player:onDialogRequest(d)
end

-- ============================================================
--  UI: ADMIN ADD / EDIT ITEM
-- ============================================================
local function showAdminAddItem(player, categoryID, editItemID)
    if not player:hasRole(ADMIN_ROLE) then return end

    local cat = getCategoryByID(categoryID)
    if not cat then showAdminMenu(player); return end

    local sess = getAdminSession(player)
    sess.editCategoryID = categoryID
    sess.editItemID = editItemID

    local existing = nil
    if editItemID then
        existing = getExchangeItemByID(editItemID)
        if existing then
            if not sess.reqItemID then sess.reqItemID = tonumber(existing.req_item_id) end
            if not sess.rewardItemID then sess.rewardItemID = tonumber(existing.reward_item_id) end
            sess.duration = tonumber(existing.duration_seconds) or 0
            sess.limit = tonumber(existing.max_limit) or 0
            sess.playerLimit = tonumber(existing.player_limit) or 0
        end
    else
        sess.duration = sess.duration or 0
        sess.limit = sess.limit or 0
        sess.playerLimit = sess.playerLimit or 0
    end

    local reqText    = sess.reqItemID    and (getItemName(sess.reqItemID) .. " `7(ID "..sess.reqItemID..")")    or "`7(belum dipilih)"
    local rewardText = sess.rewardItemID and (getItemName(sess.rewardItemID) .. " `7(ID "..sess.rewardItemID..")") or "`7(belum dipilih)"

    local titleAction = editItemID and "EDIT" or "TAMBAH"
    local d = "set_default_color|`o\n"
    d = d .. "text_scaling_string|aaaaaaa|\n"
    d = d .. string.format("add_label_with_icon|big|`w%s ITEM - %s|left|%d|\n",
        titleAction, cat.name, tonumber(cat.icon_id) or 242)
    d = d .. "add_custom_break|\n"
    d = d .. "add_spacer|small|\n"

    d = d .. "add_label|small|`wRequired Item (player gives):|left|\n"
    d = d .. string.format("add_smalltext|`9Dipilih: %s|left|\n", reqText)
    d = d .. "add_item_picker|req_pick|`9Pick Item|`oSelect from inventory|\n"
    d = d .. "add_text_input|req_amount|Amount:|1|10|numeric|\n"
    d = d .. "add_spacer|small|\nadd_custom_break|\n"

    d = d .. "add_label|small|`wReward Item (player gets):|left|\n"
    d = d .. string.format("add_smalltext|`2Dipilih: %s|left|\n", rewardText)
    d = d .. "add_item_picker|reward_pick|`2Pick Item|`oSelect from inventory|\n"
    d = d .. "add_text_input|reward_amount|Amount:|1|10|numeric|\n"
    d = d .. "add_spacer|small|\nadd_custom_break|\n"

    d = d .. string.format("add_text_input|adm_duration|Duration (seconds, 0=forever):|%d|10|numeric|\n", sess.duration or 0)
    d = d .. "add_button|adm_dur_1d|`91 Day|noflags|\n"
    d = d .. "add_button|adm_dur_3d|`93 Days|noflags|\n"
    d = d .. "add_button|adm_dur_7d|`97 Days|noflags|\n"
    d = d .. "add_spacer|small|\nadd_custom_break|\n"

    d = d .. string.format("add_text_input|adm_limit|Server Limit (0=unlimited):|%d|10|numeric|\n", sess.limit or 0)
    d = d .. "add_spacer|small|\nadd_custom_break|\n"

    d = d .. "add_label|small|`wPer-Player Limit:|left|\n"
    d = d .. string.format("add_text_input|adm_player_limit|Max per player (0=unlimited):|%d|10|numeric|\n", sess.playerLimit or 0)
    d = d .. "add_smalltext|`o0 = unlimited | 1 = once | 5 = 5 times|left|\n"
    d = d .. "add_spacer|small|\nadd_custom_break|\n"

    if editItemID then
        d = d .. string.format("add_button|admin_update_item_%d|`2Update|noflags|\n", editItemID)
    else
        d = d .. string.format("add_button|admin_save_item_%d|`2Save|noflags|\n", categoryID)
    end
    d = d .. string.format("add_button|admin_view_items_%d|`9Lihat Item|noflags|\n", categoryID)
    d = d .. "add_button|admin_back|`wKembali|noflags|\n"
    d = d .. "add_quick_exit|\nend_dialog|admin_add_item|Close||\n"

    player:onDialogRequest(d)
end

-- ============================================================
--  COMMANDS
-- ============================================================
registerLuaCommand({command = "exchange", roleRequired = 0, description = "Open Exchange Menu"})
registerLuaCommand({command = "exchangeadmin", roleRequired = ADMIN_ROLE, description = "Exchange Admin Panel"})

onPlayerCommandCallback(function(w, p, c)
    local cmd = c:match("^(%S+)")
    if cmd == "exchange" then
        showMainMenu(p)
        return true
    end
    if cmd == "exchangeadmin" and p:hasRole(ADMIN_ROLE) then
        showAdminMenu(p)
        return true
    end
    return false
end)

-- ============================================================
--  DIALOG CALLBACK
-- ============================================================
onPlayerDialogCallback(function(w, p, d)
    if not d then return false end

    local dlg = d.dialog_name or ""
    local btn = d.buttonClicked or ""
    local sess = getAdminSession(p)

    if dlg ~= "admin_add_item" and dlg ~= "admin_view_items" and dlg ~= "admin_edit_cat" then
        sess.reqItemID = nil
        sess.rewardItemID = nil
        sess.editItemID = nil
    end

    if dlg == "exchange_main" then
        local catID = tonumber(btn:match("^open_category_(%d+)$"))
        if catID then
            showCategoryMenu(p, catID)
            return true
        end
        return true
    end

    if dlg == "exchange_go" then
        if btn == "back_to_main" then
            showMainMenu(p)
            return true
        end

        local reqID, reqAmt, rewID, rewAmt, exchangeID = btn:match("^exq_(%d+)_(%d+)_(%d+)_(%d+)_(%d+)$")
        if exchangeID then
            doExchange(p, tonumber(exchangeID))
            return true
        end
        return true
    end

    if not p:hasRole(ADMIN_ROLE) then return false end

    if dlg == "exchange_admin" then
        if btn == "admin_add_cat" then
            local name = d.cat_name or ""
            local desc = d.cat_desc or ""
            local icon = tonumber(d.cat_icon) or 242

            if name == "" then
                p:onConsoleMessage("`4Nama kategori harus diisi!")
                showAdminMenu(p)
                return true
            end

            addCategory(name, desc, icon)
            p:onConsoleMessage(string.format("`2Kategori '%s' ditambahkan!", name))

            local newCatID = getLastCategoryID()
            if newCatID > 0 then
                sess.reqItemID = nil
                sess.rewardItemID = nil
                sess.duration = 0
                sess.limit = 0
                sess.playerLimit = 0
                showAdminAddItem(p, newCatID, nil)
            else
                showAdminMenu(p)
            end
            return true
        end

        local addItemCat = tonumber(btn:match("^admin_add_item_(%d+)$"))
        if addItemCat then
            sess.editCategoryID = addItemCat
            sess.reqItemID = nil
            sess.rewardItemID = nil
            sess.editItemID = nil
            sess.duration = 0
            sess.limit = 0
            sess.playerLimit = 0
            showAdminAddItem(p, addItemCat, nil)
            return true
        end

        local viewCat = tonumber(btn:match("^admin_view_items_(%d+)$"))
        if viewCat then
            sess.editCategoryID = viewCat
            showAdminViewItems(p, viewCat)
            return true
        end

        local editCat = tonumber(btn:match("^admin_edit_cat_(%d+)$"))
        if editCat then
            showAdminEditCategory(p, editCat)
            return true
        end

        local delCat = tonumber(btn:match("^admin_del_cat_(%d+)$"))
        if delCat then
            deleteCategory(delCat)
            p:onConsoleMessage("`4Kategori dihapus!")
            showAdminMenu(p)
            return true
        end

        return true
    end

    if dlg == "admin_add_item" then
        if btn == "admin_back" then
            showAdminMenu(p)
            return true
        end

        local viewBtn = tonumber(btn:match("^admin_view_items_(%d+)$"))
        if viewBtn then
            showAdminViewItems(p, viewBtn)
            return true
        end

        local reqPicked = nil
        local reqVal = tonumber(d["req_pick"])
        if reqVal and reqVal > 0 then
            reqPicked = reqVal
        elseif btn:match("^req_pick_(%d+)$") then
            reqPicked = tonumber(btn:match("^req_pick_(%d+)$"))
        elseif btn == "req_pick" then
            local alt = tonumber(d["buttonClicked_value"]) or tonumber(d["itemID"])
            if alt and alt > 0 then reqPicked = alt end
        end

        if reqPicked then
            sess.reqItemID = reqPicked
            p:onConsoleMessage(string.format("`2Required item dipilih: %s (ID %d)",
                getItemName(reqPicked), reqPicked))
            showAdminAddItem(p, sess.editCategoryID, sess.editItemID)
            return true
        end

        local rewardPicked = nil
        local rewardVal = tonumber(d["reward_pick"])
        if rewardVal and rewardVal > 0 then
            rewardPicked = rewardVal
        elseif btn:match("^reward_pick_(%d+)$") then
            rewardPicked = tonumber(btn:match("^reward_pick_(%d+)$"))
        elseif btn == "reward_pick" then
            local alt = tonumber(d["buttonClicked_value"]) or tonumber(d["itemID"])
            if alt and alt > 0 then rewardPicked = alt end
        end

        if rewardPicked then
            sess.rewardItemID = rewardPicked
            p:onConsoleMessage(string.format("`2Reward item dipilih: %s (ID %d)",
                getItemName(rewardPicked), rewardPicked))
            showAdminAddItem(p, sess.editCategoryID, sess.editItemID)
            return true
        end

        local durMap = {adm_dur_1d=86400, adm_dur_3d=259200, adm_dur_7d=604800}
        if durMap[btn] then
            sess.duration = durMap[btn]
            p:onConsoleMessage(string.format("`2Duration diset: %d detik", durMap[btn]))
            showAdminAddItem(p, sess.editCategoryID, sess.editItemID)
            return true
        end

        local saveCat = tonumber(btn:match("^admin_save_item_(%d+)$"))
        if saveCat then
            local reqAmt    = tonumber(d.req_amount) or 1
            local rewardAmt = tonumber(d.reward_amount) or 1
            local duration  = tonumber(d.adm_duration) or sess.duration or 0
            local limit     = tonumber(d.adm_limit) or sess.limit or 0
            local playerLimit = tonumber(d.adm_player_limit) or sess.playerLimit or 0
            local finalReqID    = sess.reqItemID or 0
            local finalRewardID = sess.rewardItemID or 0

            if finalReqID <= 0 or finalRewardID <= 0 then
                p:onConsoleMessage("`4Pilih required dan reward item terlebih dahulu!")
                showAdminAddItem(p, saveCat, nil)
                return true
            end

            addExchangeItem(saveCat, finalReqID, reqAmt, finalRewardID, rewardAmt,
                duration, limit, playerLimit)
            p:onConsoleMessage(string.format("`2Item ditambahkan! %s x%d → %s x%d",
                getItemName(finalReqID), reqAmt, getItemName(finalRewardID), rewardAmt))

            sess.reqItemID = nil
            sess.rewardItemID = nil
            sess.duration = 0
            sess.limit = 0
            sess.playerLimit = 0

            showAdminViewItems(p, saveCat)
            return true
        end

        local updateID = tonumber(btn:match("^admin_update_item_(%d+)$"))
        if updateID then
            local reqAmt    = tonumber(d.req_amount) or 1
            local rewardAmt = tonumber(d.reward_amount) or 1
            local duration  = tonumber(d.adm_duration) or sess.duration or 0
            local limit     = tonumber(d.adm_limit) or sess.limit or 0
            local playerLimit = tonumber(d.adm_player_limit) or sess.playerLimit or 0
            local finalReqID    = sess.reqItemID or 0
            local finalRewardID = sess.rewardItemID or 0

            if finalReqID <= 0 or finalRewardID <= 0 then
                p:onConsoleMessage("`4Required & reward harus valid!")
                showAdminAddItem(p, sess.editCategoryID, updateID)
                return true
            end

            updateExchangeItem(updateID, finalReqID, reqAmt, finalRewardID, rewardAmt,
                duration, limit, playerLimit)
            p:onConsoleMessage("`2Item diupdate!")

            sess.reqItemID = nil
            sess.rewardItemID = nil
            sess.editItemID = nil
            sess.duration = 0
            sess.limit = 0
            sess.playerLimit = 0

            showAdminViewItems(p, sess.editCategoryID)
            return true
        end

        return true
    end

    if dlg == "admin_view_items" then
        if btn == "admin_back" then
            showAdminMenu(p)
            return true
        end

        local addBtn = tonumber(btn:match("^admin_add_item_(%d+)$"))
        if addBtn then
            sess.editCategoryID = addBtn
            sess.reqItemID = nil
            sess.rewardItemID = nil
            sess.editItemID = nil
            sess.duration = 0
            sess.limit = 0
            sess.playerLimit = 0
            showAdminAddItem(p, addBtn, nil)
            return true
        end

        local editItem = tonumber(btn:match("^admin_edit_item_(%d+)$"))
        if editItem then
            sess.editItemID = editItem
            sess.reqItemID = nil
            sess.rewardItemID = nil
            showAdminAddItem(p, sess.editCategoryID, editItem)
            return true
        end

        local delID = tonumber(btn:match("^admin_del_item_(%d+)$"))
        if delID then
            deleteExchangeItem(delID)
            p:onConsoleMessage("`4Item dihapus!")
            showAdminViewItems(p, sess.editCategoryID or 0)
            return true
        end

        return true
    end

    if dlg == "admin_edit_cat" then
        if btn == "admin_back" then
            showAdminMenu(p)
            return true
        end

        local saveCat = tonumber(btn:match("^admin_save_cat_(%d+)$"))
        if saveCat then
            local name = d.edit_cat_name or ""
            local desc = d.edit_cat_desc or ""
            local icon = tonumber(d.edit_cat_icon) or 242

            if name == "" then
                p:onConsoleMessage("`4Nama kategori harus diisi!")
                showAdminEditCategory(p, saveCat)
                return true
            end

            updateCategory(saveCat, name, desc, icon)
            p:onConsoleMessage(string.format("`2Kategori '%s' diupdate!", name))
            showAdminMenu(p)
            return true
        end

        return true
    end

    return false
end)

-- ============================================================
--  DISCONNECT CLEANUP
-- ============================================================
onPlayerDisconnectCallback(function(player)
    local netID = player:getNetID()
    if adminSession[netID] then adminSession[netID] = nil end
end)

print("========================================")
print("INVEST PS EXCHANGE v5.3 — DB: herzz_exchange.db")
print("  /exchange      - Open Exchange Menu")
print("  /exchangeadmin - Admin Panel (Role "..ADMIN_ROLE..")")
print("========================================")