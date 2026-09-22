-- ============================================================
--   FUNTOPIA BANK SYSTEM - 5 LOCKS VAULT
--   Refactored & Beautified Version for GTPS
--   Features:
--     • Modular DialogBuilder (No messy string concatenations)
--     • Responsive Layout (Works seamlessly on PC, iOS & Android)
--     • Vibrant Growtopia Color Coding (`w, `e, `9, `2, `4, `p)
--     • Real 1% Transfer Tax System & Clean Logs
--     • Anti-Dupe / Anti-Overflow 32-bit Integer Protections
-- ============================================================

local SERVER_NAME         = "FUNTOPIA"
local DATA_KEY_PREFIX     = "FUNTOPIA_BANK_V2_"
local TRANSFER_LOG_KEY    = "FUNTOPIA_TRANSFER_LOGS"
local TRANSFER_TAX_PCT    = 1    -- Tax persen untuk transfer (1%)
local MAX_LOG_ENTRIES     = 200
local ADMIN_ROLE          = 51     -- Role akses audit logs

-- ============================================================
--   DAFTAR LOCKS & KONVERSI
-- ============================================================
local LOCKS = {
    { id = 242,  key = "WL",  label = "World Lock",      icon = 242,  color = "`e", short = "WL" },
    { id = 1796, key = "DL",  label = "Diamond Lock",    icon = 1796, color = "`1", short = "DL" },
    { id = 7188, key = "BGL", label = "Blue Gem Lock",   icon = 7188, color = "`9", short = "BGL" },
    { id = 8470, key = "GGL", label = "Golden Gem Lock", icon = 8470, color = "`6", short = "GGL" },
    { id = 2950, key = "ML",  label = "Mystic Lock",     icon = 2950, color = "`p", short = "ML" },
}

local CONVERSIONS = {
    -- UPGRADE (100 -> 1)
    { from = 242,  to = 1796, fromRate = 100, toRate = 1,   type = "upgrade",   label = "100 WL → 1 DL" },
    { from = 1796, to = 7188, fromRate = 100, toRate = 1,   type = "upgrade",   label = "100 DL → 1 BGL" },
    { from = 7188, to = 8470, fromRate = 100, toRate = 1,   type = "upgrade",   label = "100 BGL → 1 GGL" },
    { from = 8470, to = 2950, fromRate = 100, toRate = 1,   type = "upgrade",   label = "100 GGL → 1 ML" },

    -- DOWNGRADE (1 -> 100)
    { from = 2950, to = 8470, fromRate = 1,   toRate = 100, type = "downgrade", label = "1 ML → 100 GGL" },
    { from = 8470, to = 7188, fromRate = 1,   toRate = 100, type = "downgrade", label = "1 GGL → 100 BGL" },
    { from = 7188, to = 1796, fromRate = 1,   toRate = 100, type = "downgrade", label = "1 BGL → 100 DL" },
    { from = 1796, to = 242,  fromRate = 1,   toRate = 100, type = "downgrade", label = "1 DL → 100 WL" },
}

-- ============================================================
--   HELPER: DIALOG BUILDER (RAPIH & EFISIEN)
-- ============================================================
local function DialogBuilder()
    local t = {}
    local builder = {}

    function builder:add(command, ...)
        local args = {...}
        if #args == 0 then
            t[#t + 1] = command .. "|\n"
        else
            t[#t + 1] = command .. "|" .. table.concat(args, "|") .. "|\n"
        end
        return builder
    end

    function builder:spacer(size)
        return builder:add("add_spacer", size or "small")
    end

    function builder:breakLine()
        return builder:add("add_custom_break")
    end

    function builder:build()
        return table.concat(t)
    end

    return builder
end

-- ============================================================
--   FORMAT ANGKA DENGAN KOMA (1,000,000)
-- ============================================================
local function formatNum(num)
    local n = math.floor(tonumber(num) or 0)
    local s = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return s
end

local function getLockConfigById(id)
    for _, lock in ipairs(LOCKS) do
        if lock.id == id then return lock end
    end
    return nil
end

local function normalizeName(name)
    if not name then return "" end
    return tostring(name):lower():gsub("`.", ""):gsub("@", ""):gsub("%b[]", ""):gsub("^dr%.", ""):gsub(" of legend", ""):gsub("%s+", "")
end

local function findPlayerByName(inputName)
    if not inputName or inputName == "" then return nil end
    local target = normalizeName(inputName)
    for _, p in ipairs(getServerPlayers() or {}) do
        if normalizeName(p:getCleanName()) == target then
            return p
        end
    end
    return nil
end

local function isAdmin(player)
    if not player then return false end
    return player:hasRole(ADMIN_ROLE)
end

-- ============================================================
--   DATABASE & CACHING ENGINE
-- ============================================================
local playerBankCache = {}
local transferLogs = {}

local function loadPlayerBank(userID)
    if not userID then return {} end
    if playerBankCache[userID] then return playerBankCache[userID] end

    local data = loadDataFromServer(DATA_KEY_PREFIX .. tostring(userID))
    local bank = {}
    if data and type(data) == "table" then
        for k, v in pairs(data) do
            bank[tonumber(k) or k] = math.max(0, math.floor(tonumber(v) or 0))
        end
    end
    playerBankCache[userID] = bank
    return bank
end

local function savePlayerBank(userID)
    if userID and playerBankCache[userID] then
        saveDataToServer(DATA_KEY_PREFIX .. tostring(userID), playerBankCache[userID])
    end
end

local function saveAllBanks()
    for uid, _ in pairs(playerBankCache) do
        savePlayerBank(uid)
    end
end

-- Simpan otomatis tiap siklus
onAutoSaveRequest(function()
    saveAllBanks()
end)

function getBankBalance(player, itemID)
    if not player or not itemID then return 0 end
    local bank = loadPlayerBank(player:getUserID())
    return bank[itemID] or 0
end

function changeBankBalance(player, itemID, amount)
    if not player or not itemID or not amount then return false end
    amount = math.floor(tonumber(amount) or 0)
    if amount == 0 then return false end

    local uid = player:getUserID()
    local pdata = loadPlayerBank(uid)
    local current = pdata[itemID] or 0
    local newValue = current + amount

    -- Cegah negatif & batas maksimal 2 Miliar (safe 32-bit int)
    if newValue < 0 or newValue > 2000000000 then return false end

    pdata[itemID] = newValue
    playerBankCache[uid] = pdata
    savePlayerBank(uid)
    return true
end

function getTotalNetWorth(player)
    if not player then return 0 end
    local uid = player:getUserID()
    local pdata = loadPlayerBank(uid)

    local wl  = pdata[242]  or 0
    local dl  = pdata[1796] or 0
    local bgl = pdata[7188] or 0
    local ggl = pdata[8470] or 0
    local ml  = pdata[2950] or 0

    return wl + (dl * 100) + (bgl * 10000) + (ggl * 1000000) + (ml * 100000000)
end

-- ============================================================
--   TRANSFER AUDIT LOGS
-- ============================================================
local function loadTransferLogs()
    local data = loadDataFromServer(TRANSFER_LOG_KEY)
    if data and type(data) == "table" then
        transferLogs = data
    else
        transferLogs = {}
    end
end

local function saveTransferLogs()
    saveDataToServer(TRANSFER_LOG_KEY, transferLogs)
end

local function addTransferLog(fromName, toName, amount, lockShort, taxAmount)
    table.insert(transferLogs, 1, {
        time = os.time(),
        date = os.date("%Y-%m-%d %H:%M:%S"),
        from = fromName,
        to = toName,
        amount = amount,
        currency = lockShort,
        tax = taxAmount or 0,
    })

    if #transferLogs > MAX_LOG_ENTRIES then
        for i = MAX_LOG_ENTRIES + 1, #transferLogs do
            transferLogs[i] = nil
        end
    end

    saveTransferLogs()
end

-- ============================================================
--   UI: TAMPILAN BALANCE ROW (ANTI-OVERLAP / RAPIH SEPERTI IN-GAME)
-- ============================================================
local function appendBalanceRow(dialog, player)
    -- Membagi 5 Locks menjadi 2 baris (3 di atas, 2 di bawah) agar teks & icon
    -- TIDAK BERTABRAKAN / OVERLAP di layar PC maupun HP Android/iOS
    dialog:add("reset_placement_x")
    for i = 1, 3 do
        local lock = LOCKS[i]
        local bal = getBankBalance(player, lock.id)
        dialog:add(
            "add_button_with_icon",
            "btn_bal_" .. lock.key,
            lock.color .. lock.short .. "`o: `w" .. formatNum(bal),
            "noflags",
            tostring(lock.icon),
            tostring(bal),
            "left"
        )
    end
    dialog:breakLine()
    dialog:spacer("small")

    dialog:add("reset_placement_x")
    for i = 4, 5 do
        local lock = LOCKS[i]
        local bal = getBankBalance(player, lock.id)
        dialog:add(
            "add_button_with_icon",
            "btn_bal_" .. lock.key,
            lock.color .. lock.short .. "`o: `w" .. formatNum(bal),
            "noflags",
            tostring(lock.icon),
            tostring(bal),
            "left"
        )
    end
    dialog:breakLine()
    dialog:spacer("small")
end

-- ============================================================
--   UI: BANK CENTRAL (UNIFIED PAGE: OVERVIEW, UPGRADE & DOWNGRADE)
-- ============================================================
local function showBankDialog(player, currentTab)
    currentTab = currentTab or "upgrade"
    local d = DialogBuilder()

    local totalVal = getTotalNetWorth(player)
    local uid = player:getUserID()
    local pdata = loadPlayerBank(uid)

    local totalLocksCount = 0
    for _, l in ipairs(LOCKS) do
        totalLocksCount = totalLocksCount + (pdata[l.id] or 0)
    end

    d:add("disable_resize")
    d:add("set_default_color", "`o")

    -- HEADER
    d:add("add_label_with_icon", "big", "`w" .. SERVER_NAME .. " CENTRAL BANK``", "left", "7188")
    d:spacer("small")

    -- STATS BANNER
    d:add("add_smalltext", "`oNet Worth: `2" .. formatNum(totalVal) .. " `eWL`o | Stored: `9" .. formatNum(totalLocksCount) .. " `oLocks | Tax: `4" .. TRANSFER_TAX_PCT .. "%")
    d:spacer("small")

    -- BALANCE TILES (ANTI-OVERLAP)
    d:add("add_label", "small", "`w─── YOUR VAULT BALANCES ───", "left")
    d:spacer("small")
    appendBalanceRow(d, player)

    -- MAIN NAVIGATION ACTIONS (SEJAJAR 1 BARIS - FLAG 'left')
    d:add("reset_placement_x")
    d:add("add_button", "nav_deposit",  "`2[ DEPOSIT ]``",  "left")
    d:add("add_button", "nav_withdraw", "`4[ WITHDRAW ]``", "left")
    d:add("add_button", "nav_transfer", "`9[ TRANSFER ]``", "left")
    d:breakLine()
    d:spacer("small")

    -- TABS CONVERSION (DIJAMIN SEJAJAR 1 BARIS: FLAG 'left' ATAU 'add_button_with_icon')
    d:add("reset_placement_x")
    if currentTab == "upgrade" then
        d:add("add_button", "tab_upgrade",   "`2[ UPGRADE (100:1) ]``",   "left")
        d:add("add_button", "tab_downgrade", "`o[ DOWNGRADE (1:100) ]``", "left")
    else
        d:add("add_button", "tab_upgrade",   "`o[ UPGRADE (100:1) ]``",   "left")
        d:add("add_button", "tab_downgrade", "`2[ DOWNGRADE (1:100) ]``", "left")
    end
    d:breakLine()
    d:spacer("small")

    -- LIST CONVERSIONS (PERSIS SEPERTI FOTO KE-3)
    local filterType = currentTab == "upgrade" and "upgrade" or "downgrade"
    local list = {}
    for _, c in ipairs(CONVERSIONS) do
        if c.type == filterType then list[#list + 1] = c end
    end

    for _, conv in ipairs(list) do
        local fromCfg = getLockConfigById(conv.from)
        local toCfg   = getLockConfigById(conv.to)
        local balance = getBankBalance(player, conv.from)
        local canConvert = (balance >= conv.fromRate)

        d:add("reset_placement_x")
        d:add("add_button_with_icon", "c_src_" .. conv.from, fromCfg.color .. formatNum(conv.fromRate) .. " " .. fromCfg.short, "noflags", tostring(conv.from), tostring(conv.fromRate), "left")
        d:add("add_button", "c_arr_" .. conv.from, "`4→", "left")
        d:add("add_button_with_icon", "c_dst_" .. conv.to,   toCfg.color   .. formatNum(conv.toRate)   .. " " .. toCfg.short,   "noflags", tostring(conv.to),   tostring(conv.toRate),   "left")

        if canConvert then
            d:add("add_button", "do_conv_" .. conv.from .. "_" .. conv.to, "`2[ CONVERT ]``", "left")
        else
            d:add("add_button", "cant_conv_" .. conv.from .. "_" .. conv.to, "`4[ INSUFFICIENT ]``", "left")
        end
        d:breakLine()
        d:spacer("small")
    end

    d:spacer("small")
    d:add("add_quick_exit")
    d:add("end_dialog", "bank_main_dialog", "", "")

    player:onDialogRequest(d:build())
end

-- ============================================================
--   FUNGSI PROSES CONVERT
-- ============================================================
local function processConversion(player, fromID, toID)
    local conv = nil
    for _, c in ipairs(CONVERSIONS) do
        if c.from == fromID and c.to == toID then
            conv = c
            break
        end
    end

    if not conv then return false end

    local fromCfg = getLockConfigById(conv.from)
    local toCfg   = getLockConfigById(conv.to)
    local balance = getBankBalance(player, conv.from)

    if balance < conv.fromRate then
        player:onConsoleMessage("`4[BANK] `oSaldo tidak cukup! Butuh `e" .. formatNum(conv.fromRate) .. " " .. fromCfg.short)
        player:onTalkBubble(player:getNetID(), "`4Saldo Tidak Cukup!", 0)
        player:playAudio("bleep_fail.wav")
        return false
    end

    if changeBankBalance(player, conv.from, -conv.fromRate) then
        changeBankBalance(player, conv.to, conv.toRate)
        player:onConsoleMessage(string.format("`2[BANK] `oSukses tukar `e%s %s `o→ `9%s %s`o!",
            formatNum(conv.fromRate), fromCfg.short, formatNum(conv.toRate), toCfg.short))
        player:onTalkBubble(player:getNetID(), "`2✓ " .. fromCfg.short .. " → " .. toCfg.short, 0)
        player:playAudio("keypad_hit.wav")
        return true
    end

    return false
end

-- ============================================================
--   UI: TRANSACTION DIALOG (DEPOSIT / WITHDRAW / TRANSFER)
-- ============================================================
local function showTransactionDialog(player, txType)
    local d = DialogBuilder()
    local titles = {
        deposit  = "`2DEPOSIT LOCKS TO VAULT",
        withdraw = "`4WITHDRAW LOCKS FROM VAULT",
        transfer = "`9TRANSFER LOCKS TO PLAYER",
    }

    d:add("disable_resize")
    d:add("set_default_color", "`o")

    -- HEADER
    d:add("add_label_with_icon", "big", titles[txType] or "TRANSACTION", "left", "7188")
    d:spacer("small")

    if txType == "transfer" then
        d:add("add_smalltext", "`4Catatan: `oPajak transfer `4" .. TRANSFER_TAX_PCT .. "%`o akan otomatis dipotong.")
        d:spacer("small")
    end

    -- PILIH CURRENCY
    d:add("add_label", "small", "`wPilih Jenis Lock:", "left")
    d:add("max_checks", "1")

    d:add("reset_placement_x")
    for i = 1, 3 do
        local l = LOCKS[i]
        d:add("add_checkicon", l.key, l.color .. l.label, "noflags", tostring(l.id), "", "0")
    end
    d:breakLine()

    d:add("reset_placement_x")
    for i = 4, 5 do
        local l = LOCKS[i]
        d:add("add_checkicon", l.key, l.color .. l.label, "noflags", tostring(l.id), "", "0")
    end
    d:breakLine()
    d:spacer("small")

    -- INPUT JUMLAH
    d:add("add_label", "small", "`wJumlah (Amount):", "left")
    d:add("add_text_input", "amount_input", "", "", "10")
    d:spacer("small")

    -- INPUT TARGET TRANSFER
    if txType == "transfer" then
        d:add("add_label", "small", "`wTarget GrowID Penerima:", "left")
        d:add("add_text_input", "target_growid", "", "", "24")
        d:spacer("small")
    end

    -- ACTION BUTTONS
    d:add("reset_placement_x")
    d:add("add_button", "back_to_bank_home", "`o« KEMBALI", "left")
    d:add("add_button", "submit_" .. txType, "`2KONFIRMASI »", "left")
    d:breakLine()

    d:spacer("small")
    d:add("add_quick_exit")
    d:add("end_dialog", "bank_tx_" .. txType, "", "")

    player:onDialogRequest(d:build())
end

-- ============================================================
--   UI: /INFOWL (CLEAN & ORGANIZED)
-- ============================================================
local function showInfoWL(player, targetName)
    if not player then return false end

    local target = nil
    if not targetName or targetName == "" then
        target = player
    else
        target = findPlayerByName(targetName)
    end

    if not target then
        player:onConsoleMessage("`4[INFO] `oPlayer '`e" .. tostring(targetName) .. "`o' tidak ditemukan atau offline!")
        return false
    end

    local uid = target:getUserID()
    local isSelf = (target == player)
    local displayName = target:getName()

    -- HITUNG DARI INVENTORY
    local invData = {}
    local totalInv = 0
    local items = target:getInventoryItems() or {}
    for _, it in ipairs(items) do
        local id = it:getItemID()
        local count = it:getItemCount()
        if getLockConfigById(id) then
            invData[id] = (invData[id] or 0) + count
            totalInv = totalInv + count
        end
    end

    -- HITUNG DARI BANK
    local bankData = loadPlayerBank(uid)
    local totalBank = 0
    for _, l in ipairs(LOCKS) do
        local count = bankData[l.id] or 0
        totalBank = totalBank + count
    end

    local d = DialogBuilder()
    d:add("disable_resize")
    d:add("set_default_color", "`o")

    local title = isSelf and "`wYOUR LOCKS OVERVIEW``" or string.format("`w%s's LOCKS OVERVIEW``", displayName)
    d:add("add_label_with_icon", "big", title, "left", "7188")
    d:spacer("small")

    -- SECTION BANK
    d:add("add_label", "small", "`9═══ VAULT STORAGE (BANK) ═══", "left")
    d:spacer("small")
    local hasBank = false
    for _, lock in ipairs(LOCKS) do
        local count = bankData[lock.id] or 0
        if count > 0 then
            hasBank = true
            d:add("add_label_with_icon", "small", lock.color .. lock.label .. "`o: `w" .. formatNum(count), "left", tostring(lock.id))
        end
    end
    if not hasBank then
        d:add("add_label", "small", "`8(Vault kosong)", "left")
    end
    d:add("add_smalltext", "`oSubtotal Bank: `2" .. formatNum(totalBank) .. " `olocks")
    d:spacer("small")

    -- SECTION INVENTORY
    d:add("add_label", "small", "`e═══ ACTIVE INVENTORY ═══", "left")
    d:spacer("small")
    local hasInv = false
    for _, lock in ipairs(LOCKS) do
        local count = invData[lock.id] or 0
        if count > 0 then
            hasInv = true
            d:add("add_label_with_icon", "small", lock.color .. lock.label .. "`o: `w" .. formatNum(count), "left", tostring(lock.id))
        end
    end
    if not hasInv then
        d:add("add_label", "small", "`8(Tidak ada locks di tas)", "left")
    end
    d:add("add_smalltext", "`oSubtotal Inventory: `2" .. formatNum(totalInv) .. " `olocks")
    d:spacer("small")

    -- GRAND TOTAL
    d:add("add_label", "small", "`w═══════════════════════════════", "left")
    d:add("add_label_with_icon", "small", "`2COMBINED TOTAL: `w" .. formatNum(totalBank + totalInv) .. " `oLocks", "left", "242")
    d:spacer("small")

    d:add("add_quick_exit")
    d:add("end_dialog", "infowl_dialog", "", "")

    player:onDialogRequest(d:build())
    return true
end

-- ============================================================
--   UI: /TRANSFERCHECK (ADMIN AUDIT)
-- ============================================================
local function showTransferCheck(player)
    if not isAdmin(player) then
        player:onConsoleMessage("`4[RESTRICTED] `oCommand ini hanya untuk Role " .. ADMIN_ROLE .. " ke atas!")
        return false
    end

    local logs = transferLogs
    local d = DialogBuilder()

    d:add("disable_resize")
    d:add("set_default_color", "`o")

    d:add("add_label_with_icon", "big", "`4[AUDIT] `wTRANSFER LOGS", "left", "7188")
    d:spacer("small")
    d:add("add_smalltext", "`oTotal Catatan: `2" .. formatNum(#logs) .. " `otransaksi | Menampilkan maks 20 terbaru")
    d:spacer("small")

    if #logs == 0 then
        d:add("add_label", "small", "`8Belum ada catatan transaksi transfer.", "left")
    else
        local count = math.min(20, #logs)
        for i = 1, count do
            local log = logs[i]
            if log then
                local line = string.format("`7[%s] `e%s `o→ `e%s `o: `2%s %s `4(Pajak: %s)",
                    log.date or "-",
                    log.from or "?",
                    log.to or "?",
                    formatNum(log.amount or 0),
                    log.currency or "WL",
                    formatNum(log.tax or 0)
                )
                d:add("add_smalltext", line)
            end
        end
    end

    d:spacer("small")
    d:add("reset_placement_x")
    d:add("add_button", "refresh_transfer_logs", "`9[ REFRESH ]``", "noflags", "0", "0")
    d:breakLine()
    d:add("add_quick_exit")
    d:add("end_dialog", "transfer_audit_dialog", "", "")

    player:onDialogRequest(d:build())
    return true
end

-- ============================================================
--   COMMAND REGISTRATION & HANDLER
-- ============================================================
registerLuaCommand({ command = "funtopia",      roleRequired = 0,          description = "Buka Central Bank 5 Locks" })
registerLuaCommand({ command = "infowl",        roleRequired = 0,          description = "Cek jumlah locks player" })
registerLuaCommand({ command = "transfercheck", roleRequired = ADMIN_ROLE, description = "Cek audit log transfer" })

onPlayerCommandCallback(function(world, player, fullCommand)
    if not player or not fullCommand then return false end

    local cmdLine = fullCommand
    if cmdLine:sub(1, 1) == "/" then cmdLine = cmdLine:sub(2) end

    local cmd, args = cmdLine:match("^(%S+)%s*(.*)")
    if not cmd then return false end
    cmd = cmd:lower()

    if cmd == "funtopia" or cmd == "bank" then
        showBankDialog(player, "upgrade")
        player:playAudio("spell1.wav")
        return true
    end

    if cmd == "infowl" then
        args = args:gsub("^%s+", ""):gsub("%s+$", "")
        showInfoWL(player, args)
        return true
    end

    if cmd == "transfercheck" then
        showTransferCheck(player)
        return true
    end

    return false
end)

-- CONSUMABLE QUICK LAUNCH (ID 9950)
onPlayerConsumableCallback(function(world, player, tile, itemID, targetPlayer)
    if itemID == 9950 then
        showBankDialog(player, "upgrade")
        player:playAudio("spell1.wav")
        return true
    end
    return false
end)

-- ============================================================
--   DIALOG CALLBACK HANDLER
-- ============================================================
onPlayerDialogCallback(function(world, player, data)
    if not player or not data then return false end

    local dialogName = data["dialog_name"]
    local button = data["buttonClicked"]

    local function getSelectedLockID(d)
        for _, lock in ipairs(LOCKS) do
            if d[lock.key] == "1" then return lock.id end
        end
        return nil
    end

    -- REFRESH LOGS
    if dialogName == "transfer_audit_dialog" then
        if button == "refresh_transfer_logs" then
            showTransferCheck(player)
            return true
        end
        return true
    end

    -- DIALOG UTAMA (BANK MAIN)
    if dialogName == "bank_main_dialog" then
        if button == "nav_deposit" then
            showTransactionDialog(player, "deposit")
            return true
        elseif button == "nav_withdraw" then
            showTransactionDialog(player, "withdraw")
            return true
        elseif button == "nav_transfer" then
            showTransactionDialog(player, "transfer")
            return true
        elseif button == "tab_upgrade" then
            showBankDialog(player, "upgrade")
            return true
        elseif button == "tab_downgrade" then
            showBankDialog(player, "downgrade")
            return true
        else
            -- Check convert button pattern: do_conv_FROM_TO
            local fromID, toID = button:match("^do_conv_(%d+)_(%d+)$")
            if fromID and toID then
                fromID, toID = tonumber(fromID), tonumber(toID)
                local curTab = (fromID == 2950 or fromID == 8470 or fromID == 7188 and toID == 1796) and "downgrade" or "upgrade"
                processConversion(player, fromID, toID)
                showBankDialog(player, curTab)
                return true
            end
        end
        return true
    end

    -- KEMBALI KE MENU UTAMA
    if button == "back_to_bank_home" then
        showBankDialog(player, "upgrade")
        return true
    end

    -- HANDLE TRANSAKSI (DEPOSIT / WITHDRAW / TRANSFER)
    if dialogName and dialogName:match("^bank_tx_") then
        local lockID = getSelectedLockID(data)
        local amount = tonumber(data["amount_input"]) or 0

        if not lockID then
            player:onConsoleMessage("`4[BANK] `oMohon centang salah satu jenis Lock!")
            player:playAudio("bleep_fail.wav")
            showBankDialog(player, "upgrade")
            return true
        end

        if amount < 1 or amount ~= math.floor(amount) or amount > 2000000000 then
            player:onConsoleMessage("`4[BANK] `oJumlah tidak valid! Masukkan angka bulat positif.")
            player:playAudio("bleep_fail.wav")
            showBankDialog(player, "upgrade")
            return true
        end

        local cfg = getLockConfigById(lockID)

        -- 1. DEPOSIT
        if button == "submit_deposit" then
            local inInv = player:getItemAmount(lockID) or 0
            if inInv < amount then
                player:onConsoleMessage("`4[BANK] `oJumlah " .. cfg.short .. " di inventory kamu kurang! (Punya: " .. formatNum(inInv) .. ")")
                player:playAudio("bleep_fail.wav")
                showBankDialog(player, "upgrade")
                return true
            end

            if not player:changeItem(lockID, -amount) then
                player:onConsoleMessage("`4[BANK] `oGagal menarik item dari inventory!")
                return true
            end

            changeBankBalance(player, lockID, amount)
            player:onConsoleMessage("`2[BANK] `oSukses deposit `e+" .. formatNum(amount) .. " " .. cfg.short .. "`o ke vault!")
            player:playAudio("drop_item.wav")
            showBankDialog(player, "upgrade")
            return true

        -- 2. WITHDRAW
        elseif button == "submit_withdraw" then
            local currentBal = getBankBalance(player, lockID)
            if currentBal < amount then
                player:onConsoleMessage("`4[BANK] `oSaldo vault kamu tidak mencukupi! (Saldo: " .. formatNum(currentBal) .. ")")
                player:playAudio("bleep_fail.wav")
                showBankDialog(player, "upgrade")
                return true
            end

            if not changeBankBalance(player, lockID, -amount) then
                player:onConsoleMessage("`4[BANK] `oGagal memproses saldo!")
                return true
            end

            if not player:giveItem(lockID, amount) then
                -- Rollback jika inventori penuh
                changeBankBalance(player, lockID, amount)
                player:onConsoleMessage("`4[BANK] `oInventory penuh! Gagal mengambil " .. cfg.short)
                player:playAudio("bleep_fail.wav")
                return true
            end

            player:onConsoleMessage("`2[BANK] `oSukses withdraw `4-" .. formatNum(amount) .. " " .. cfg.short .. "`o!")
            player:playAudio("drop_item.wav")
            showBankDialog(player, "upgrade")
            return true

        -- 3. TRANSFER
        elseif button == "submit_transfer" then
            local targetName = data["target_growid"]
            if not targetName or targetName == "" then
                player:onConsoleMessage("`4[BANK] `oSilakan masukkan GrowID tujuan!")
                showBankDialog(player, "upgrade")
                return true
            end

            if normalizeName(targetName) == normalizeName(player:getCleanName()) then
                player:onConsoleMessage("`4[BANK] `oTidak dapat melakukan transfer ke akun sendiri!")
                showBankDialog(player, "upgrade")
                return true
            end

            local target = findPlayerByName(targetName)
            if not target or not target:isOnline() then
                player:onConsoleMessage("`4[BANK] `oPlayer '`e" .. targetName .. "`4' tidak sedang online!")
                showBankDialog(player, "upgrade")
                return true
            end

            local currentBal = getBankBalance(player, lockID)
            if currentBal < amount then
                player:onConsoleMessage("`4[BANK] `oSaldo vault tidak cukup untuk transfer!")
                player:playAudio("bleep_fail.wav")
                showBankDialog(player, "upgrade")
                return true
            end

            -- Hitung Pajak Transfer
            local taxAmount = math.floor(amount * (TRANSFER_TAX_PCT / 100))
            local netReceive = amount - taxAmount

            if netReceive <= 0 then
                player:onConsoleMessage("`4[BANK] `oJumlah transfer terlalu kecil setelah dipotong pajak!")
                return true
            end

            changeBankBalance(player, lockID, -amount)
            changeBankBalance(target, lockID, netReceive)

            addTransferLog(player:getCleanName(), target:getCleanName(), amount, cfg.short, taxAmount)

            player:onConsoleMessage(string.format("`2[BANK] `oTransfer `e%s %s `oke `w%s `osukses! (Pajak: `4%s %s`o, Diterima: `2%s %s`o)",
                formatNum(amount), cfg.short, target:getName(),
                formatNum(taxAmount), cfg.short,
                formatNum(netReceive), cfg.short))
            player:playAudio("success.wav")

            target:onConsoleMessage(string.format("`2[BANK] `oKamu menerima transfer `2+%s %s `odari `w%s`o (setelah pajak %d%%)",
                formatNum(netReceive), cfg.short, player:getName(), TRANSFER_TAX_PCT))
            target:playAudio("success.wav")

            showBankDialog(player, "upgrade")
            return true
        end

        return true
    end

    return false
end)

-- Inisialisasi logs saat script pertama dimuat
loadTransferLogs()

print("==================================================")
print("  [OK] " .. SERVER_NAME .. " BANK SYSTEM INITIALIZED")
print("  Prefix Key : " .. DATA_KEY_PREFIX)
print("  Transfer Tax: " .. TRANSFER_TAX_PCT .. "%")
print("  Admin Role : " .. ADMIN_ROLE)
print("==================================================")
