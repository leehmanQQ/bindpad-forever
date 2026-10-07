local P = NORMAL_FONT_COLOR_CODE .. "%s" .. FONT_COLOR_CODE_CLOSE

-- enUS strings. Translations below override single keys; anything missing falls back to English.
local L = {
    BINDING_HEADER = "BindPad",
    BINDING_NAME_TOGGLE = "Toggle BindPad",
    TITLE = "BindPad",
    TITLE_PROFILE = "BindPad Profile%d",
    KEYBINDINGS_TITLE = "Keybinding",
    MACRO_TITLE = "Create BindPad Macro",

    TEXT_GENERAL_TAB = "General",
    TEXT_SPECIFIC_TAB = "%s Specific",
    TEXT_SPECIFIC_EXTRA_TAB2 = "2",
    TEXT_SPECIFIC_EXTRA_TAB3 = "3",
    TEXT_EXIT = "Exit",
    TEXT_TEST = "Test",
    TEXT_UNBIND = "Unbind",
    TEXT_PRESSKEY = "Press a key to bind",
    TEXT_KEY = "Current Key: ",
    TEXT_NOTBOUND = "Not Bound",
    TEXT_CONFIRM_BINDING = P
        .. " is currently bound to \n"
        .. P
        .. "\n\nDo you want to bind "
        .. P
        .. " to \n"
        .. P
        .. "?",
    TEXT_CANNOT_PLACE = "ERROR: %s can not be placed in BindPad slot.",
    TEXT_CANNOT_BIND = "Cannot change key bindings while in combat.",
    TEXT_ARE_YOU_SURE = "REALLY? ARE YOU SURE?",
    TEXT_CONFIRM_CHANGE_BINDING_PROFILE = "You need to activate Character Specific Key Bindings mode of Blizard-UI.  Click Okay if you want to change Key Bindings mode now.",
    TEXT_CONFIRM_CONVERT = 'Are you sure you want to convert this %s "%s" into a BindPad Macro?',
    TEXT_SHOW_HOTKEY = "Show Hotkeys",
    TEXT_SAVE_ALL_KEYS = "Save All Keys",
    TEXT_FOR_ALL_CHARACTERS = "For all characters",
    TEXT_CHARACTER_SPECIFIC = "Character Specific Key Bindings",
    TEXT_SPELLBOOK = "Spellbook",
    TEXT_MACROS = "Macros",
    TEXT_BAGS = "Bags",
    TEXT_CONVERT = "Convert to BindPad Macro",
    TEXT_SPELL_RANK = "Spell Rank",
    TEXT_HIGHEST_RANK = "Highest Rank",
    TEXT_RANK_SHORT = "R%s",
    TEXT_CHAR_LIMIT = "%d/1024 Characters Used",
    TEXT_ERR_UNIQUENAME = "You must enter unique name for BindPadMacro.",
    TEXT_ERR_SPELL_INCOMBAT = "Cannot pickup spell icon while in combat.",
    TEXT_ERR_MACRO_INCOMBAT = "Cannot pickup macro icon while in combat.",
    TEXT_ERR_BINDPADMACRO_INCOMBAT = "Cannot edit BindPadMacro while in combat.",
    TEXT_ERR_RANK_INCOMBAT = "Cannot change spell rank while in combat.",
    TEXT_CREATE_PROFILETAB = "Created new profile.  All icons are duplicated now.",
    TEXT_SLOTS_SHOWN = "%d Slots shown",
    TEXT_USAGE = "Usage: /bindpad [command] or /bp [command] \n"
        .. "    /bindpad : Toggle BindPadFrame.\n"
        .. "    /bindpad list : List profiles in saved variables.\n"
        .. "    /bindpad delete REALMNAME_CHARACTERNAME : Delete a profile for the named character.\n"
        .. "    /bindpad copyfrom REALMNAME_CHARACTERNAME : Copy a profile from the named character.\n"
        .. "    Example: /bp copyfrom Blackrock_foobar",
    TEXT_DO_DELETE = "Successfully deleted profiles for %s.",
    TEXT_DO_DELETE_ERR_CURRENT = "Cannot delete profiles for current character.",
    TEXT_DO_ERR_NOT_FOUND = "Profile for %s is not found.",
    TEXT_DO_COPY = "Successfully duplicated profiles from %s.",
    TEXT_DO_COPY_ERR_CURRENT = "Cannot copy profiles from same character.",

    TOOLTIP_MACRO = "Macro: ",
    TOOLTIP_BINDPADMACRO = "BindPadMacro:%s",
    TOOLTIP_KEYBINDING = "KeyBinding: ",
    TOOLTIP_UNKNOWN_SPELL = "Unknown spell: ",
    TOOLTIP_OPTIONS = "Options",
    TOOLTIP_RANK_PINNED = "Always casts %s",
    TOOLTIP_RANK_HIGHEST = "Always casts your highest rank",
    TOOLTIP_TAB1 = "General Slots",
    TOOLTIP_GENERAL_TAB_EXPLAIN = "For common icons used for every characters and every specs.",
    TOOLTIP_TAB2 = "%s Specific Slots",
    TOOLTIP_SPECIFIC_TAB_EXPLAIN = "For icons specific to current character and current spec.",
    TOOLTIP_TAB3 = "%s Specific Slots 2nd Tab",
    TOOLTIP_TAB4 = "%s Specific Slots 3rd Tab",
    TOOLTIP_SAVE_ALL_KEYS = "Automatically save&restore all keys of Blizzard's Key Bindings Interface for each profile.",
    TOOLTIP_SHOW_HOTKEY = "Automatically shows hotkey text when you place 'BindPad'ed icons on ActionBars. Also shows keybindings in tooltips.",
    TOOLTIP_FOR_ALL_CHARACTERS = "Keybind for this icon will be carried over to all other characters.",
    TOOLTIP_CREATE_MACRO = "Create BindPad Macro",
    TOOLTIP_CLICK_USAGE1 = "Right click to edit macro\nLeft click to bind",
    TOOLTIP_CLICK_USAGE2 = "Right click for options\nLeft click to bind",
    TOOLTIP_EXTRA_PROFILE = "Profile",
    TOOLTIP_PROFILE_CURRENTLY1 = "Currently assigned to %s",
    TOOLTIP_PROFILE_CURRENTLY2 = "Currently assigned to both %s and %s",
    TOOLTIP_PROFILE_CURRENTLY3 = "Currently assigned to %s, %s and %s",
    TOOLTIP_PROFILE_CURRENTLY4 = "Currently assigned to 4 specs",
    TOOLTIP_PROFILE_CLICK_FOR = "Click here to assign Profile%d to %s",
    TOOLTIP_SHOW_MORE_SLOT = "Show more slots",
    TOOLTIP_SHOW_LESS_SLOT = "Show less slots",
}

-- zhTW/zhCN translations by xinsonic (xinsonic@gmail.com).
local translations = {
    zhTW = {
        BINDING_NAME_TOGGLE = "開啟BindPad",
        KEYBINDINGS_TITLE = "按鍵綁定",
        MACRO_TITLE = "新建 BindPad 巨集",

        TEXT_GENERAL_TAB = "共用",
        TEXT_SPECIFIC_TAB = "%s 專用",
        TEXT_EXIT = "離開",
        TEXT_TEST = "測試",
        TEXT_UNBIND = "取消綁定",
        TEXT_PRESSKEY = "請按下您想綁定的按鍵",
        TEXT_KEY = "目前綁定鍵: ",
        TEXT_NOTBOUND = "未綁定",
        TEXT_CONFIRM_BINDING = P .. " 已經設為\n" .. P .. "\n\n您確定綁定要 " .. P .. " 為 " .. P .. " 嗎?",
        TEXT_CANNOT_PLACE = "錯誤: %s 不能被放置在 BindPad 中。",
        TEXT_CANNOT_BIND = "不能在戰鬥中設置按鍵綁定!",
        TEXT_ARE_YOU_SURE = "真的? 您確定嗎?",
        TEXT_CONFIRM_CHANGE_BINDING_PROFILE = "您需要開啟按鍵設定中的角色專用按鍵設定選項。若您想改變按鍵綁定模式請按確定。",
        TEXT_CONFIRM_CONVERT = '您確認轉換 %s "%s" 為 BindPad 巨集?',
        TEXT_SHOW_HOTKEY = "顯示綁定按鍵文字",
        TEXT_CHARACTER_SPECIFIC = "角色專用按鍵設定",
        TEXT_SPELLBOOK = "法術書",
        TEXT_MACROS = "巨集",
        TEXT_BAGS = "背包",
        TEXT_CONVERT = "轉換為 BindPad 巨集",
        TEXT_SPELL_RANK = "法術等級",
        TEXT_HIGHEST_RANK = "最高等級",
        TEXT_ERR_RANK_INCOMBAT = "戰鬥中無法變更法術等級。",

        TOOLTIP_MACRO = "巨集: ",
        TOOLTIP_BINDPADMACRO = "BindPad 巨集: %s",
        TOOLTIP_KEYBINDING = "按鍵綁定: ",
        TOOLTIP_UNKNOWN_SPELL = "未知法術: ",
        TOOLTIP_OPTIONS = "選項",
        TOOLTIP_RANK_PINNED = "總是施放%s",
        TOOLTIP_RANK_HIGHEST = "總是施放最高等級",
        TOOLTIP_TAB1 = "共用",
        TOOLTIP_TAB2 = "%s 專用",
        TOOLTIP_TAB3 = "%s 專用 2",
        TOOLTIP_TAB4 = "%s 專用 3",
        TOOLTIP_SHOW_HOTKEY = "自動在動作條上顯示被 BindPad 綁定過的按鍵的快捷鍵文字.",
        TOOLTIP_CREATE_MACRO = "新建 BindPad 巨集",
        TOOLTIP_CLICK_USAGE1 = "右擊以編輯巨集\n左擊以進行綁定",
        TOOLTIP_CLICK_USAGE2 = "右擊開啟選項\n左擊以進行綁定",
    },
    zhCN = {
        BINDING_NAME_TOGGLE = "开启BindPad",
        KEYBINDINGS_TITLE = "按键绑定",
        MACRO_TITLE = "创建 BindPad 宏",

        TEXT_GENERAL_TAB = "共用",
        TEXT_SPECIFIC_TAB = "%s 专用",
        TEXT_EXIT = "离开",
        TEXT_TEST = "测试",
        TEXT_UNBIND = "取消绑定",
        TEXT_PRESSKEY = "请按下您想绑定的按键",
        TEXT_KEY = "当前绑定键: ",
        TEXT_NOTBOUND = "未绑定",
        TEXT_CONFIRM_BINDING = P .. " 已经设为\n" .. P .. "\n\n您确定绑定要 " .. P .. " 为 " .. P .. " 吗?",
        TEXT_CANNOT_PLACE = "错误: %s 不能被放置在 BindPad 中。",
        TEXT_CANNOT_BIND = "不能在战斗中设置按键绑定!",
        TEXT_ARE_YOU_SURE = "真的? 您确定吗?",
        TEXT_CONFIRM_CHANGE_BINDING_PROFILE = "您需要开启按键设定中的角色专用按键设定选项。若您想改变按键绑定模式请按确定。",
        TEXT_CONFIRM_CONVERT = '您确认转换 %s "%s" 为 BindPad 宏?',
        TEXT_SHOW_HOTKEY = "显示绑定按键文字",
        TEXT_CHARACTER_SPECIFIC = "角色专用按键设定",
        TEXT_SPELLBOOK = "法术书",
        TEXT_MACROS = "宏",
        TEXT_BAGS = "背包",
        TEXT_CONVERT = "转换为 BindPad 宏",
        TEXT_SPELL_RANK = "法术等级",
        TEXT_HIGHEST_RANK = "最高等级",
        TEXT_ERR_RANK_INCOMBAT = "战斗中无法更改法术等级。",

        TOOLTIP_MACRO = "宏: ",
        TOOLTIP_BINDPADMACRO = "BindPad 宏: %s",
        TOOLTIP_KEYBINDING = "按键绑定: ",
        TOOLTIP_UNKNOWN_SPELL = "未知法术: ",
        TOOLTIP_OPTIONS = "选项",
        TOOLTIP_RANK_PINNED = "总是施放%s",
        TOOLTIP_RANK_HIGHEST = "总是施放最高等级",
        TOOLTIP_TAB1 = "共用",
        TOOLTIP_TAB2 = "%s 专用",
        TOOLTIP_TAB3 = "%s 专用 2",
        TOOLTIP_TAB4 = "%s 专用 3",
        TOOLTIP_SHOW_HOTKEY = "自动在动作条上显示被 BindPad 绑定过的按键的快捷键文字。",
        TOOLTIP_CREATE_MACRO = "创建 BindPad 宏",
        TOOLTIP_CLICK_USAGE1 = "右击以编辑宏\n左击以进行绑定",
        TOOLTIP_CLICK_USAGE2 = "右击打开选项\n左击以进行绑定",
    },
}

for key, text in pairs(translations[GetLocale()] or {}) do
    L[key] = text
end

-- Global so XML script handlers can reach it; Lua code uses it as a local.
BindPadL = L

BINDING_HEADER_BINDPAD = L.BINDING_HEADER
BINDING_NAME_TOGGLE_BINDPAD = L.BINDING_NAME_TOGGLE
