-- ============================================================
--  GTPS HOSTING INVEST PS MENU v1.2
--  Sidebar button + Icon grid menu
-- ============================================================
print("(Loaded) GTPS Hosting Invest PS Menu v1.2")

-- ============================================================
--  KONFIGURASI
-- ============================================================
local MENU_TITLE = "INVEST PS MENU"
local MENU_ICON = 658
local EVENT_WORLD = "EVENT"

local PER_ROW = 6

local MENUS = {
    { name = "Exchange", icon = 3803,  action = "cmd", command = "exchange" },
    { name = "Sellfish", icon = 7002,  action = "cmd", command = "sellfish" },
    { name = "Tutorial", icon = 14730, action = "cmd", command = "tutorial" },
    { name = "Event",    icon = 2480,  action = "warp", world = EVENT_WORLD },
    { name = "Daily",    icon = 1360,  action = "cmd", command = "daily" },
    { name = "Unknown",  icon = 3198,  action = "cmd", command = "asu" },
}

-- ============================================================
--  UI: INVEST PS MENU
-- ============================================================
local function showInvestMenu(player)
    local d = ""
    d = d .. "set_border_color|112,86,191,255\n"
    d = d .. "set_bg_color|43,34,74,200\n"
    d = d .. "set_default_color|`o\n"
    d = d .. "text_scaling_string|aaaaaaa|\n"
    d = d .. string.format("add_label_with_icon|big|`w%s``|left|%d|\n", MENU_TITLE, MENU_ICON)
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|`0Klik menu untuk membuka menu tanpa cmd|\n"
    d = d .. "add_custom_break|\n"
    d = d .. "add_spacer|small|\n"

    local count = 0
    d = d .. "reset_placement_x|\n"
    for i, menu in ipairs(MENUS) do
        d = d .. string.format(
            "add_button_with_icon|invest_menu_%d|`$%s|staticBlueFrame|%d|\n",
            i, menu.name, menu.icon
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
    d = d .. "add_smalltext|`2Click an icon to open the menu.|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|invest_ps_menu|Exit||\n"

    player:onDialogRequest(d)
end

-- ============================================================
--  SIDEBAR BUTTON
-- ============================================================
local function addInvestButton()
    local btn = {
        active = true,
        buttonAction = "open_invest",
        buttonTemplate = "BaseEventButton",
        counter = 0,
        counterMax = 0,
        itemIdIcon = MENU_ICON,
        name = "InvestPSButton",
        order = 5,
        rcssClass = "clash-event",
        text = "Invest"
    }
    addSidebarButton(json.encode(btn))
end

addInvestButton()

-- ============================================================
--  HANDLE KLIK SIDEBAR
-- ============================================================
onPlayerActionCallback(function(world, player, data)
    if data.action == "open_invest" then
        showInvestMenu(player)
        return true
    end
    return false
end)

-- ============================================================
--  DIALOG CALLBACK
-- ============================================================
onPlayerDialogCallback(function(world, player, data)
    if not data then return false end

    local dlg = data.dialog_name or ""
    local btn = data.buttonClicked or ""

    if dlg == "invest_ps_menu" then
        local index = tonumber(btn:match("^invest_menu_(%d+)$"))
        if index and MENUS[index] then
            local menu = MENUS[index]

            if menu.action == "cmd" then
                world:sendPlayerMessage(player, "/" .. menu.command)
                player:playAudio("click.wav")

            elseif menu.action == "warp" then
                player:enterWorld(menu.world, "")
                player:playAudio("click.wav")
            end
            return true
        end
        return true
    end

    return false
end)

print("========================================")
print("GTPS Hosting Invest PS Menu v1.2")
print("  Sidebar: InvestPSButton → open_invest")
print("  Menus: " .. #MENUS)
print("  Grid: " .. PER_ROW .. " icons per row")
print("  Scaling: text_scaling_string|aaaaaaa|")
print("========================================")