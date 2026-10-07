--[[

BindPad Addon for World of Warcraft

Author: Tageshi
WoW Forever re-release: leehmanQQ (https://github.com/leehmanQQ/bindpad-forever)

--]]

local L = BindPadL

local function concat(arg1, arg2)
    if arg1 and arg2 then
        return arg1 .. arg2
    end
end

--
-- API helpers for the WoW Forever client (modern C_* namespaces)
--

-- Saved slots store book types as strings; the modern API takes Enum.SpellBookSpellBank.
local BOOKTYPE_SPELL = "spell"
local BOOKTYPE_PET = "pet"

local GetItemInfo = C_Item.GetItemInfo
local GetItemSpell = C_Item.GetItemSpell
local PickupItem = C_Item.PickupItem
local PickupSpell = C_Spell.PickupSpell

local function NormalizeBookType(bookType)
    if bookType == BOOKTYPE_PET or bookType == Enum.SpellBookSpellBank.Pet then
        return BOOKTYPE_PET
    end
    return BOOKTYPE_SPELL
end

local function ToSpellBank(bookType)
    if NormalizeBookType(bookType) == BOOKTYPE_PET then
        return Enum.SpellBookSpellBank.Pet
    end
    return Enum.SpellBookSpellBank.Player
end

local function GetSpellNameAndIcon(spell)
    if spell == nil then
        return nil
    end
    local info = C_Spell.GetSpellInfo(spell)
    if info then
        return info.name, info.iconID
    end
    return nil
end

local function GetSpellName(spell)
    return (GetSpellNameAndIcon(spell))
end

local function GetSpellBookName(index, bookType)
    return C_SpellBook.GetSpellBookItemName(index, ToSpellBank(bookType))
end

local function GetSpellBookTexture(index, bookType)
    return C_SpellBook.GetSpellBookItemTexture(index, ToSpellBank(bookType))
end

-- Returns true and the base spell ID if the spellbook entry is a regular spell.
local function GetSpellBookSpell(index, bookType)
    local itemType, actionID = C_SpellBook.GetSpellBookItemType(index, ToSpellBank(bookType))
    return itemType == Enum.SpellBookItemType.Spell, actionID
end

local function PickupSpellBookEntry(index, bookType)
    C_SpellBook.PickupSpellBookItem(index, ToSpellBank(bookType))
end

local function GetNumPetSpells()
    return C_SpellBook.HasPetSpells() or 0
end

local function GetNumPlayerSpells()
    local spellNum = 0
    for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(i)
        if info then
            spellNum = max(spellNum, info.itemIndexOffset + info.numSpellBookItems)
        end
    end
    return spellNum
end

-- Returns the active talent group (dual spec), never nil.
local function GetSpecialization()
    local spec = C_SpecializationInfo.GetActiveSpecGroup()
    if type(spec) ~= "number" or spec < 1 then
        spec = 1
    end
    return spec
end

--
-- Spell ranks. WoW Forever keeps every learned rank as its own spellbook item, but casting a spell
-- by name always casts the highest rank, so a specific rank can only be cast by its spell ID.
--

-- "Rank 3" for a ranked spell, nil for anything else ("Racial", "Passive", ...).
local function GetSpellRankText(spellID)
    local subtext = spellID and C_Spell.GetSpellSubtext(spellID)
    if subtext and subtext:find("%d") then
        return subtext
    end
    return nil
end

-- True when a higher rank of the spell is known.
local function IsLowRankSpell(spellID)
    local slot, bank = C_SpellBook.FindSpellBookSlotForSpell(spellID, true)
    return slot ~= nil and C_SpellBook.IsSpellBookItemLowRank(slot, bank)
end

-- A slot pinned to a rank casts exactly that rank; otherwise it follows the highest rank.
local function IsRankPinned(padSlot)
    return padSlot.rank ~= nil and padSlot.spellid ~= nil
end

local function GetRankedSpellCommand(spellName, rank)
    return format("SPELL %s(%s)", spellName, rank)
end

-- The BindPadKey button (and binding suffix) a spell slot is cast through.
local function GetSpellSlotCommand(padSlot)
    if IsRankPinned(padSlot) then
        return GetRankedSpellCommand(padSlot.name, padSlot.rank)
    end
    return "SPELL " .. padSlot.name
end

-- Register BindPad frame to be controlled together with
-- other panels in standard UI.
UIPanelWindows["BindPadFrame"] = { area = "left", pushable = 8, whileDead = 1 }
UIPanelWindows["BindPadMacroFrame"] = { area = "left", pushable = 9, whileDead = 1 }

local BINDPAD_MAXSLOTS_DEFAULT = 42
local BINDPAD_MAXPROFILETAB = 5
local BINDPAD_GENERAL_TAB = 1
local BINDPAD_SAVEFILE_VERSION = 1.3

local TYPE_ITEM = "ITEM"
local TYPE_SPELL = "SPELL"
local TYPE_MACRO = "MACRO"
local TYPE_BPMACRO = "CLICK"

local BindPadPetAction = {
    [PET_ACTION_MOVE_TO] = SLASH_PET_MOVE_TO1,
    [PET_ACTION_ATTACK] = SLASH_PET_ATTACK1,
    [PET_ACTION_FOLLOW] = SLASH_PET_FOLLOW1,
    [PET_ACTION_WAIT] = SLASH_PET_STAY1,
    [PET_MODE_AGGRESSIVE] = SLASH_PET_AGGRESSIVE1,
    [PET_MODE_DEFENSIVE] = SLASH_PET_DEFENSIVE1,
    [PET_MODE_PASSIVE] = SLASH_PET_PASSIVE1,
    [PET_MODE_ASSIST] = SLASH_PET_ASSIST1,
}

-- Initialize the saved variable for BindPad.
BindPadVars = {
    tab = BINDPAD_GENERAL_TAB,
    version = BINDPAD_SAVEFILE_VERSION,
    GeneralKeyBindings = {},
}

-- Initialize BindPad core object.
BindPadCore = {
    drag = {},
    dragswap = {},
    currentkeybindings = {},
    eventProc = {},
}

local BindPadCore = BindPadCore

local SPEC_GROUP_LABELS = { DUAL_SPEC_PRIMARY, DUAL_SPEC_SECONDARY }

-- Names a talent group after its talent tree with the most points; Forever talent trees are C_Traits groups.
function BindPadCore.GetSpecializationInfo(specGroup)
    local label = SPEC_GROUP_LABELS[specGroup] or tostring(specGroup)
    local configID = C_SpecializationInfo.GetCombatConfigIDForSpecGroup(specGroup)
    local configInfo = configID and C_Traits.GetConfigInfo(configID)
    local treeID = configInfo and configInfo.treeIDs[1]
    if not treeID then
        return label
    end

    local displayInfos = C_Traits.GetGroupDisplayInfoByTreeID(treeID)
    local groupIDs = {}
    for _, displayInfo in ipairs(displayInfos) do
        table.insert(groupIDs, displayInfo.groupID)
    end

    local spentByGroup = {}
    for _, groupInfo in ipairs(C_Traits.GetGroupCurrencyInfo(configID, groupIDs)) do
        local currencyInfo = groupInfo.currencyInfos[1]
        spentByGroup[groupInfo.traitNodeGroupID] = currencyInfo and currencyInfo.spent or 0
    end

    local best, bestPoints = nil, 0
    for _, displayInfo in ipairs(displayInfos) do
        local spent = spentByGroup[displayInfo.groupID] or 0
        if spent > bestPoints then
            best, bestPoints = displayInfo, spent
        end
    end
    if best then
        return format("%s (%s)", best.displayName, label), best.icon
    end
    return label
end

function BindPadFrame_Toggle()
    if BindPadFrame:IsVisible() then
        HideUIPanel(BindPadFrame)
    else
        ShowUIPanel(BindPadFrame)
    end
end

-- The top tabs start right of the portrait.
local MODERN_TAB_ROW_LEFT = 60

function BindPadCore.CreateFrameTabs(frame)
    local labels = {
        L.TEXT_GENERAL_TAB,
        format(L.TEXT_SPECIFIC_TAB, NameUtil.FormatUnitNameForDisplay("player") or ""),
        L.TEXT_SPECIFIC_EXTRA_TAB2,
        L.TEXT_SPECIFIC_EXTRA_TAB3,
    }
    for i, label in ipairs(labels) do
        local tab = CreateFrame("Button", "BindPadFrameTab" .. i, frame, "PanelTopTabButtonTemplate", i)
        tab:SetText(label)
        tab:SetScript("OnClick", BindPadFrameTab_OnClick)
        tab:SetScript("OnEnter", BindPadFrameTab_OnEnter)
        tab:SetScript("OnLeave", GameTooltip_Hide)
        -- PanelTemplates_SetNumTabs anchors tabs 2..n itself.
        if i == 1 then
            tab:SetPoint("TOPLEFT", frame, "TOPLEFT", MODERN_TAB_ROW_LEFT, -28)
        end
    end
    BindPadCore.LayoutModernTabs(frame)
end

-- Modern tabs default to a wide minimum width, so fit the row inside the frame art instead.
local MODERN_TAB_MIN_WIDTH = 44
-- Stop short of the options dropdown in the top right corner.
local MODERN_TAB_ROW_RIGHT = 312
local MODERN_TAB_SPACING = 3

function BindPadCore.LayoutModernTabs(frame)
    frame.minTabWidth = MODERN_TAB_MIN_WIDTH
    frame.maxTabWidth = nil

    local othersWidth = 0
    for i = 1, 4 do
        local tab = _G["BindPadFrameTab" .. i]
        PanelTemplates_TabResize(tab, nil, nil, frame.minTabWidth)
        if i ~= 2 then
            othersWidth = othersWidth + tab:GetWidth()
        end
    end

    -- Only the character-specific tab has a long label; give it whatever room is left.
    local available = MODERN_TAB_ROW_RIGHT - MODERN_TAB_ROW_LEFT - othersWidth - MODERN_TAB_SPACING * 3
    frame.maxTabWidth = max(frame.minTabWidth, available)
    for i = 1, 4 do
        PanelTemplates_TabResize(_G["BindPadFrameTab" .. i], nil, nil, frame.minTabWidth, frame.maxTabWidth)
    end
end

function BindPadCheckButton_SetLabel(button, label)
    local text = button.Text or _G[button:GetName() .. "Text"]
    if text then
        text:SetText(label)
        text:SetPoint("LEFT", button, "RIGHT", 2, 1)
    end
end

function BindPadFrame_OpenSpellBook()
    PlayerSpellsUtil.OpenToSpellBookTab()
end

local function AddOptionTooltip(elementDescription, text)
    elementDescription:SetTooltip(function(tooltip)
        GameTooltip_SetTitle(tooltip, MenuUtil.GetElementText(elementDescription))
        GameTooltip_AddNormalLine(tooltip, text)
    end)
end

-- The options dropdown in the top right corner, like the spellbook's settings.
function BindPadCore.SetupSettingsMenu(dropdown, rootDescription)
    local characterSpecific = rootDescription:CreateCheckbox(L.TEXT_CHARACTER_SPECIFIC, function()
        return GetCurrentBindingSet() == 2
    end, function()
        BindPadFrame_ChangeBindingProfile()
        -- Turning it off asks for confirmation, which the open menu would cover.
        return MenuResponse.CloseAll
    end)
    AddOptionTooltip(characterSpecific, CHARACTER_SPECIFIC_KEYBINDING_TOOLTIP)

    local saveAllKeys = rootDescription:CreateCheckbox(L.TEXT_SAVE_ALL_KEYS, function()
        return BindPadVars.saveAllKeysFlag
    end, BindPadFrame_SaveAllKeysToggle)
    AddOptionTooltip(saveAllKeys, L.TOOLTIP_SAVE_ALL_KEYS)

    local showHotkey = rootDescription:CreateCheckbox(L.TEXT_SHOW_HOTKEY, function()
        return BindPadVars.showHotkey
    end, BindPadFrame_ShowHotkeyToggle)
    AddOptionTooltip(showHotkey, L.TOOLTIP_SHOW_HOTKEY)
end

function BindPad_SlashCmd(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")

    if cmd == nil or cmd == "" then
        BindPadFrame_Toggle()
    elseif cmd == "list" then
        BindPadCore.DoList(arg)
    elseif cmd == "delete" then
        BindPadCore.DoDelete(arg)
    elseif cmd == "copyfrom" then
        BindPadCore.DoCopyFrom(arg)
    else
        BindPadFrame_OutputText(L.TEXT_USAGE)
    end
end

function BindPadFrame_OnLoad(self)
    self:SetPortraitToAsset("Interface\\AddOns\\BindPad\\Icon")
    self.SettingsDropdown:SetupMenu(BindPadCore.SetupSettingsMenu)

    BindPadCore.CreateFrameTabs(self)
    PanelTemplates_SetNumTabs(BindPadFrame, 4)

    SlashCmdList["BINDPAD"] = BindPad_SlashCmd
    SLASH_BINDPAD1 = "/bindpad"
    SLASH_BINDPAD2 = "/bp"

    self:RegisterEvent("UPDATE_BINDINGS")
    self:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    self:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
    self:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
    self:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
    self:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    self:RegisterEvent("UPDATE_POSSESS_BAR")

    self:RegisterEvent("PLAYER_TALENT_UPDATE")
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self:RegisterEvent("CVAR_UPDATE")

    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function BindPadFrame_OnMouseDown(self, button)
    if button == "RightButton" then
        BindPadCore.ClearCursor()
    end
end

function BindPadFrame_OnEnter(self)
    BindPadCore.UpdateCursor()
end

function BindPadFrame_OnEvent(self, event, ...)
    local arg1, arg2 = ...
    if event == "UPDATE_BINDINGS" then
        -- BindPad will always save keybindings when something changed
        -- because current spec can be changed while BindPad addon is disabled.
        -- If we don't save now, we can lose the new keybind when logout/relogin as other spec.
        BindPadCore.DoSaveAllKeys() -- correct?

        BindPadCore.UpdateAllHotkeys()
    elseif
        event == "ACTIONBAR_SLOT_CHANGED"
        or event == "UPDATE_BONUS_ACTIONBAR"
        or event == "UPDATE_VEHICLE_ACTIONBAR"
        or event == "UPDATE_OVERRIDE_ACTIONBAR"
        or event == "ACTIONBAR_PAGE_CHANGED"
        or event == "UPDATE_SHAPESHIFT_FORM"
        or event == "UPDATE_POSSESS_BAR"
    then
        BindPadCore.UpdateAllHotkeys()
    elseif event == "PLAYER_ENTERING_WORLD" then
        BindPadCore.InitBindPadOnce(event)
    elseif
        event == "PLAYER_TALENT_UPDATE"
        or event == "ACTIVE_TALENT_GROUP_CHANGED"
        or event == "PLAYER_SPECIALIZATION_CHANGED"
    then
        if event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 ~= "player" then
            return
        end
        BindPadCore.PlayerTalentUpdate()
    elseif event == "CVAR_UPDATE" then
        BindPadCore.CVAR_UPDATE(arg1, arg2)
    end
end

function BindPadFrame_OutputText(text)
    ChatFrame1:AddMessage("[BindPad] " .. text, 1.0, 1.0, 0.0)
end

function BindPadFrame_OnShow()
    BindPadCore.LayoutModernTabs(BindPadFrame)

    if not BindPadVars.tab then
        BindPadVars.tab = 1
    end

    if GetCurrentBindingSet() == 1 then
        -- Don't show Character Specific Slots tab at first.
        BindPadVars.tab = 1
    end

    if BindPadVars.tab == 1 then
        BindPadFrame:SetTitle(L.TITLE)
    else
        BindPadFrame:SetTitle(format(L.TITLE_PROFILE, BindPadCore.GetCurrentProfileNum()))
    end
    PanelTemplates_SetTab(BindPadFrame, BindPadVars.tab)

    BindPadVars.showHotkey = (BindPadVars.showHotkey or BindPadVars.showKeyInTooltipFlag)
    BindPadVars.showKeyInTooltipFlag = nil

    -- Update profile tab
    for i = 1, BINDPAD_MAXPROFILETAB, 1 do
        local profiletab = _G["BindPadProfileTab" .. i]
        profiletab:SetChecked((BindPadCore.GetCurrentProfileNum() == i))
        BindPadProfileTab_OnShow(profiletab)
    end

    local tabInfo = BindPadCore.GetTabInfo(BindPadVars.tab)
    BindPadCore.CreateBindPadSlot(tabInfo.numSlot)
    for i = 1, tabInfo.numSlot do
        local button = _G["BindPadSlot" .. i]
        BindPadSlot_UpdateState(button)
    end
end

function BindPadFrame_OnHide(self)
    BindPadCore.HideSubFrames()
end

function BindPadFrameTab_OnClick(self)
    local id = self:GetID()
    local function f()
        if GetCurrentBindingSet() == 1 then
            local answer = BindPadCore.ShowDialog(L.TEXT_CONFIRM_CHANGE_BINDING_PROFILE)
            if answer then
                LoadBindings(2)
                BindPadCore.SaveBindings(2)
            else
                BindPadVars.tab = 1
                return
            end
        end
        BindPadVars.tab = id
        BindPadFrame_OnShow()
    end

    -- Handles callback with coroutine.
    return coroutine.wrap(f)()
end

function BindPadFrameTab_OnEnter(self)
    local id = self:GetID()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if id == 1 then
        GameTooltip:SetText(L.TOOLTIP_TAB1, nil, nil, nil, nil, 1)
        GameTooltip:AddLine(L.TOOLTIP_GENERAL_TAB_EXPLAIN, 1.0, 0.8, 0.8)
    else
        GameTooltip:SetText(
            format(L["TOOLTIP_TAB" .. id], NameUtil.FormatUnitNameForDisplay("player")),
            nil,
            nil,
            nil,
            nil,
            1
        )
        GameTooltip:AddLine(L.TOOLTIP_SPECIFIC_TAB_EXPLAIN, 0.8, 1.0, 0.8)
    end
    GameTooltip:Show()
end

-- A readable name for a binding action: the slot name for BindPad actions, the key bindings menu name otherwise.
local function GetBindingLabel(action)
    local label = action:match("^CLICK BindPadKey:%u+ (.+)$") or action:match("^CLICK BindPadMacro:(.+)$")
    return label or _G["BINDING_NAME_" .. action] or action
end

local GRAY_TEXT = "|cff808080%s|r"
local WHITE_TEXT = "|cffffffff%s|r"

local function GetSlotDisplayName(padSlot)
    if IsRankPinned(padSlot) then
        return padSlot.name .. " " .. format(GRAY_TEXT, "(" .. padSlot.rank .. ")")
    end
    return padSlot.name
end

function BindPadBindFrame_Update()
    BindPadCore.CancelDialogs()

    local padSlot = BindPadCore.selectedSlot
    BindPadBindFrame.Icon:SetTexture(padSlot.texture)
    BindPadBindFrameAction:SetText(GetSlotDisplayName(padSlot))

    local key = GetBindingKey(padSlot.action)
    if key then
        BindPadBindFrameKey:SetText(L.TEXT_KEY .. format(WHITE_TEXT, BindPadCore.GetBindingText(key, "KEY_")))
    else
        BindPadBindFrameKey:SetText(L.TEXT_KEY .. format(GRAY_TEXT, L.TEXT_NOTBOUND))
    end

    if (BindPadVars.tab or 1) == 1 then
        BindPadBindFrameForAllCharacterButton:SetChecked(BindPadCore.selectedSlot.isForAllCharacters)
        BindPadBindFrameForAllCharacterButton:Show()
    else
        BindPadBindFrameForAllCharacterButton:Hide()
    end
end

function BindPadBindFrame_OnKeyDown(self, keyOrButton)
    if keyOrButton == "ESCAPE" then
        BindPadBindFrame:Hide()
        return
    end

    if GetBindingFromClick(keyOrButton) == "SCREENSHOT" then
        RunBinding("SCREENSHOT")
        return
    end

    local keyPressed = keyOrButton

    if keyPressed == "UNKNOWN" then
        return
    end

    -- Convert the mouse button names
    if keyPressed == "LeftButton" then
        keyPressed = "BUTTON1"
    elseif keyPressed == "RightButton" then
        keyPressed = "BUTTON2"
    elseif keyPressed == "MiddleButton" then
        keyPressed = "BUTTON3"
    else
        keyPressed = (keyPressed:gsub("^Button(%d+)$", "BUTTON%1"))
    end

    if
        keyPressed == "LSHIFT"
        or keyPressed == "RSHIFT"
        or keyPressed == "LCTRL"
        or keyPressed == "RCTRL"
        or keyPressed == "LALT"
        or keyPressed == "RALT"
    then
        return
    end

    if IsShiftKeyDown() then
        keyPressed = "SHIFT-" .. keyPressed
    end

    if IsControlKeyDown() then
        keyPressed = "CTRL-" .. keyPressed
    end

    if IsAltKeyDown() then
        keyPressed = "ALT-" .. keyPressed
    end

    if keyPressed == "BUTTON1" or keyPressed == "BUTTON2" then
        return
    end

    local function f()
        local answer
        local padSlot = BindPadCore.selectedSlot
        local oldAction = GetBindingAction(keyPressed)

        if oldAction ~= "" and oldAction ~= padSlot.action then
            local keyText = BindPadCore.GetBindingText(keyPressed, "KEY_")
            local text = format(
                L.TEXT_CONFIRM_BINDING,
                keyText,
                GetBindingLabel(oldAction),
                keyText,
                GetBindingLabel(padSlot.action)
            )
            answer = BindPadCore.ShowDialog(text)
        else
            answer = true
        end

        if answer then
            BindPadCore.BindKey(padSlot, keyPressed)
        end
        BindPadBindFrame_Update()
    end
    -- Handles callback with coroutine.
    return coroutine.wrap(f)()
end

function BindPadBindFrame_Unbind()
    BindPadCore.UnbindSlot(BindPadCore.selectedSlot)
    BindPadBindFrame_Update()
end

function BindPadBindFrame_OnHide(self)
    -- Close the confirmation dialog frame if it is still open.
    BindPadCore.CancelDialogs()
end

function BindPadSlot_OnUpdateBindings(self)
    if BindPadCore.character then
        BindPadSlot_UpdateState(self)
    end
end

function BindPadSlot_OnClick(self, button, down)
    if button == "RightButton" then
        if BindPadCore.CursorHasIcon() then
            BindPadCore.ClearCursor()
        else
            local padSlot = BindPadCore.GetSlotInfo(self:GetID())
            if padSlot and TYPE_BPMACRO ~= padSlot.type then
                BindPadCore.ShowSlotMenu(self, padSlot)
            else
                BindPadMacroFrame_Open(self)
            end
        end

        return
    end

    if BindPadCore.CursorHasIcon() then
        -- If cursor has icon to drop, drop it.
        BindPadSlot_OnReceiveDrag(self)
    elseif IsShiftKeyDown() then
        -- Shift+click to start drag.
        BindPadSlot_OnDragStart(self)
    else
        -- Otherwise open dialog window to set keybinding.
        if BindPadCore.GetSlotInfo(self:GetID()) then
            BindPadCore.HideSubFrames()
            BindPadCore.selectedSlot = BindPadCore.GetSlotInfo(self:GetID())
            BindPadCore.selectedSlotButton = self
            BindPadBindFrame_Update()
            BindPadBindFrame:Show()
        end
    end
end

function BindPadSlot_OnDragStart(self)
    if not BindPadCore.CanPickupSlot(self) then
        return
    end

    BindPadCore.PickupSlot(self, self:GetID(), true)
    BindPadSlot_UpdateState(self)
end

function BindPadSlot_OnReceiveDrag(self)
    if self == BindPadCore.selectedSlotButton then
        BindPadCore.HideSubFrames()
    end

    if not BindPadCore.CanPickupSlot(self) then
        return
    end

    local type, detail, subdetail, spellid = GetCursorInfo()
    if type then
        if type == "petaction" then
            detail = BindPadCore.PickupSpellBookItem_slot
            subdetail = BindPadCore.PickupSpellBookItem_bookType
        end
        ClearCursor()
        ResetCursor()
        BindPadCore.PickupSlot(self, self:GetID())
        BindPadCore.PlaceIntoSlot(self:GetID(), type, detail, subdetail, spellid)

        BindPadSlot_UpdateState(self)
        BindPadSlot_OnEnter(self)
    elseif TYPE_BPMACRO == BindPadCore.drag.type then
        local drag = BindPadCore.drag
        ClearCursor()
        ResetCursor()
        BindPadCore.PickupSlot(self, self:GetID())
        BindPadCore.PlaceVirtualIconIntoSlot(self:GetID(), drag)

        BindPadSlot_UpdateState(self)
        BindPadSlot_OnEnter(self)
    end
end

function BindPadSlot_OnEnter(self)
    BindPadCore.UpdateCursor()

    local padSlot = BindPadCore.GetSlotInfo(self:GetID())

    if not padSlot then
        return
    end

    if BindPadCore.CheckCorruptedSlot(padSlot) then
        return
    end

    GameTooltip:SetOwner(self, "ANCHOR_LEFT")

    if TYPE_ITEM == padSlot.type then
        GameTooltip:SetHyperlink(padSlot.linktext)
    elseif TYPE_SPELL == padSlot.type then
        if padSlot.spellid then
            GameTooltip:SetSpellByID(padSlot.spellid)
            if IsRankPinned(padSlot) then
                GameTooltip:AddLine(format(L.TOOLTIP_RANK_PINNED, padSlot.rank), 1.0, 0.82, 0.0)
            elseif GetSpellRankText(padSlot.spellid) then
                GameTooltip:AddLine(L.TOOLTIP_RANK_HIGHEST, 1.0, 0.82, 0.0)
            end
        else
            local spellBookId = BindPadCore.FindSpellBookIdByName(padSlot.name, padSlot.rank, padSlot.bookType)
            if spellBookId then
                GameTooltip:SetSpellBookItem(spellBookId, ToSpellBank(padSlot.bookType))
            else
                GameTooltip:SetText(L.TOOLTIP_UNKNOWN_SPELL .. padSlot.name, 1.0, 1.0, 1.0)
            end
            if padSlot.rank then
                GameTooltip:AddLine(padSlot.rank, 1.0, 0.7, 0.7)
            end
        end
    elseif TYPE_MACRO == padSlot.type then
        GameTooltip:SetText(L.TOOLTIP_MACRO .. padSlot.name, 1.0, 1.0, 1.0)
    elseif TYPE_BPMACRO == padSlot.type then
        GameTooltip:SetText(format(L.TOOLTIP_BINDPADMACRO, padSlot.name), 1.0, 1.0, 1.0)
    end

    -- Spell keybind is already shown if "Show Keys in Tooltip" option is ON.
    if not (BindPadVars.showHotkey and TYPE_SPELL == padSlot.type) then
        local key = GetBindingKey(padSlot.action)
        if key then
            GameTooltip:AddLine(L.TOOLTIP_KEYBINDING .. BindPadCore.GetBindingText(key, "KEY_"), 0.8, 0.8, 1.0)
        end
    end

    if not BindPadCore.CursorHasIcon() then
        if TYPE_BPMACRO == padSlot.type then
            GameTooltip:AddLine(L.TOOLTIP_CLICK_USAGE1, 0.8, 1.0, 0.8)
        else
            GameTooltip:AddLine(L.TOOLTIP_CLICK_USAGE2, 0.8, 1.0, 0.8)
        end
    end

    GameTooltip:Show()
end

function BindPadSlot_UpdateState(self)
    local padSlot = BindPadCore.GetSlotInfo(self:GetID())

    if padSlot and padSlot.type and padSlot.action then
        self.icon:SetTexture(padSlot.texture)
        self.icon:Show()
        self.SlotArt:Hide()
        self.addbutton:Hide()

        self.name:SetText(padSlot.name or "")

        local key = GetBindingKey(padSlot.action)
        if key then
            self.hotkey:SetText(BindPadCore.GetBindingText(key, "KEY_", 1))
        else
            self.hotkey:SetText("")
        end

        if IsRankPinned(padSlot) then
            self.rank:SetFormattedText(L.TEXT_RANK_SHORT, padSlot.rank:match("%d+") or padSlot.rank)
        else
            self.rank:SetText("")
        end

        if TYPE_BPMACRO == padSlot.type then
            self.border:SetVertexColor(0, 1.0, 0, 0.35)
            self.border:Show()
        else
            self.border:Hide()
        end
    else
        self.icon:Hide()
        self.SlotArt:Show()
        self.addbutton:Show()
        self.name:SetText("")
        self.hotkey:SetText("")
        self.rank:SetText("")
        self.border:Hide()
    end
end

function BindPadMacroPopupFrame_Open(self)
    if InCombatLockdown() then
        BindPadFrame_OutputText(L.TEXT_ERR_BINDPADMACRO_INCOMBAT)
        return
    end
    local padSlot = BindPadCore.GetSlotInfo(self:GetID())
    if padSlot and not BindPadCore.CheckCorruptedSlot(padSlot) and padSlot.type ~= TYPE_BPMACRO then
        return
    end

    BindPadCore.HideSubFrames()
    BindPadCore.selectedSlotButton = self
    BindPadMacroPopupFrame.slotButton = self
    BindPadMacroPopupFrame:Show()
end

function BindPadMacroAddButton_OnClick(self, button)
    if button == "RightButton" and BindPadCore.CursorHasIcon() then
        BindPadCore.ClearCursor()
    elseif BindPadCore.CursorHasIcon() then
        BindPadSlot_OnReceiveDrag(self)
    else
        BindPadCore.HideSubFrames()
        PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK)
        BindPadMacroPopupFrame_Open(self)
    end
end

-- Every rank of a player spell the character knows, highest first.
function BindPadCore.GetSpellRanks(spellName)
    local ranks, seen = {}, {}
    local bank = Enum.SpellBookSpellBank.Player
    for i = 1, GetNumPlayerSpells() do
        local itemType, spellID = C_SpellBook.GetSpellBookItemType(i, bank)
        if itemType == Enum.SpellBookItemType.Spell and not seen[spellID] and GetSpellName(spellID) == spellName then
            seen[spellID] = true
            local rank = GetSpellRankText(spellID)
            if rank then
                table.insert(ranks, { spellID = spellID, rank = rank, number = tonumber(rank:match("%d+")) })
            end
        end
    end
    table.sort(ranks, function(a, b)
        return a.number > b.number
    end)
    return ranks
end

-- Pins a spell slot to one rank, or (rank nil) lets it follow the highest rank. Its key binding moves along.
function BindPadCore.SetSlotRank(button, spellID, rank)
    if InCombatLockdown() then
        BindPadFrame_OutputText(L.TEXT_ERR_RANK_INCOMBAT)
        return
    end
    local padSlot = BindPadCore.GetSlotInfo(button:GetID())
    if padSlot == nil or TYPE_SPELL ~= padSlot.type then
        return
    end
    padSlot.spellid = spellID
    padSlot.rank = rank
    BindPadCore.UpdateMacroText(padSlot)
    BindPadSlot_UpdateState(button)
end

function BindPadCore.ShowSlotMenu(button, padSlot)
    MenuUtil.CreateContextMenu(button, function(owner, rootDescription)
        rootDescription:CreateTitle(padSlot.name)

        local ranks = TYPE_SPELL == padSlot.type
                and padSlot.bookType ~= BOOKTYPE_PET
                and BindPadCore.GetSpellRanks(padSlot.name)
            or {}
        if #ranks > 1 or IsRankPinned(padSlot) then
            rootDescription:CreateDivider()
            rootDescription:CreateTitle(L.TEXT_SPELL_RANK)
            local highest = rootDescription:CreateRadio(L.TEXT_HIGHEST_RANK, function()
                return not IsRankPinned(padSlot)
            end, function()
                BindPadCore.SetSlotRank(button, ranks[1] and ranks[1].spellID or padSlot.spellid, nil)
            end)
            highest:SetTooltip(function(tooltip)
                GameTooltip_SetTitle(tooltip, L.TOOLTIP_RANK_HIGHEST)
            end)
            for _, info in ipairs(ranks) do
                rootDescription:CreateRadio(info.rank, function()
                    return IsRankPinned(padSlot) and padSlot.spellid == info.spellID
                end, function()
                    BindPadCore.SetSlotRank(button, info.spellID, info.rank)
                end)
            end
        end

        rootDescription:CreateDivider()
        rootDescription:CreateButton(L.TEXT_CONVERT, function()
            BindPadMacroFrame_Open(button)
        end)
    end)
end

-- Name and icon picker for BindPad Macros, built on Blizzard's shared macro icon selector.
BindPadMacroPopupMixin = {}

function BindPadMacroPopupMixin:OnShow()
    IconSelectorPopupFrameTemplateMixin.OnShow(self)
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)

    self.iconDataProvider = CreateAndInitFromMixin(IconDataProviderMixin, IconDataProviderExtraType.Spellbook)
    self:SetIconFilter(IconSelectorPopupFrameIconFilterTypes.All)
    self:Update()
    self.BorderBox.IconSelectorEditBox:OnTextChanged()
    self.BorderBox.IconSelectorEditBox:SetFocus()

    local selectedIconArea = self.BorderBox.SelectedIconArea
    self.IconSelector:SetSelectedCallback(function(_, icon)
        selectedIconArea.SelectedIconButton:SetIconTexture(icon)
        -- The selected index isn't set yet here, but a clicked icon is always in the list.
        selectedIconArea.SelectedIconText.SelectedIconDescription:SetText(ICON_SELECTION_CLICK)
        selectedIconArea.SelectedIconText.SelectedIconDescription:SetFontObject(GameFontHighlightSmall)
    end)
end

function BindPadMacroPopupMixin:OnHide()
    IconSelectorPopupFrameTemplateMixin.OnHide(self)
    PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK)

    if self.iconDataProvider then
        self.iconDataProvider:Release()
        self.iconDataProvider = nil
    end

    if not BindPadFrame:IsVisible() then
        ShowUIPanel(BindPadFrame)
    end
end

function BindPadMacroPopupMixin:Update()
    local padSlot = BindPadCore.GetSlotInfo(self.slotButton:GetID())
    local editBox = self.BorderBox.IconSelectorEditBox
    local selectedIconButton = self.BorderBox.SelectedIconArea.SelectedIconButton

    if padSlot then
        editBox:SetText(padSlot.name)
        editBox:HighlightText()
        self.IconSelector:SetSelectedIndex(self:GetIndexOfIcon(padSlot.texture))
        selectedIconButton:SetIconTexture(padSlot.texture)
    else
        editBox:SetText("")
        self.IconSelector:SetSelectedIndex(1)
        selectedIconButton:SetIconTexture(self:GetIconByIndex(1))
    end

    self.IconSelector:SetSelectionsDataProvider(
        GenerateClosure(self.GetIconByIndex, self),
        GenerateClosure(self.GetNumIcons, self)
    )
    self.IconSelector:ScrollToSelectedIndex()
    self:SetSelectedIconText()
end

function BindPadMacroPopupMixin:OkayButton_OnClick()
    IconSelectorPopupFrameTemplateMixin.OkayButton_OnClick(self)

    if InCombatLockdown() then
        BindPadFrame_OutputText(L.TEXT_ERR_BINDPADMACRO_INCOMBAT)
        return
    end

    local button = self.slotButton
    local padSlot = BindPadCore.GetSlotInfo(button:GetID(), true)
    local name = self.BorderBox.IconSelectorEditBox:GetText():gsub('"', "")

    if padSlot.type == TYPE_BPMACRO then
        BindPadCore.DeleteBindPadMacroID(padSlot)
    else
        padSlot.type = TYPE_BPMACRO
        padSlot.macrotext = ""
    end
    padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, name)
    if padSlot.name ~= name then
        BindPadFrame_OutputText(L.TEXT_ERR_UNIQUENAME)
    end
    padSlot.texture = self.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture()
    -- Keep the old action on rename so UpdateMacroText can move its key binding to the new name.
    padSlot.action = padSlot.action or BindPadCore.CreateBindPadMacroAction(padSlot)
    BindPadCore.UpdateMacroText(padSlot)

    BindPadSlot_UpdateState(button)
    BindPadMacroFrame_Open(button)
end

function BindPadMacroFrame_Open(self)
    BindPadCore.HideSubFrames()

    local id = self:GetID()
    local padSlot = BindPadCore.GetSlotInfo(id)
    if padSlot == nil then
        return
    end
    BindPadCore.selectedSlot = padSlot
    BindPadCore.selectedSlotButton = self

    if TYPE_ITEM == padSlot.type or TYPE_SPELL == padSlot.type or TYPE_MACRO == padSlot.type then
        local function f()
            local answer = BindPadCore.ShowDialog(format(L.TEXT_CONFIRM_CONVERT, padSlot.type, padSlot.name))
            if answer then
                BindPadCore.ConvertToBindPadMacro()
            end
        end
        -- Handles callback with coroutine.
        return coroutine.wrap(f)()
    end

    BindPadMacroFrameSlotName:SetText(padSlot.name)
    BindPadMacroFrameSlotButtonIcon:SetTexture(padSlot.texture)
    BindPadMacroFrameSlotButtonIcon:Show()
    BindPadMacroFrameSlotButton.SlotArt:Hide()
    BindPadMacroFrameText:SetText(padSlot.macrotext)
    BindPadMacroFrameText:SetMaxBytes(1024)

    if not InCombatLockdown() then
        BindPadMacroFrameTestButton:SetAttribute("macrotext", padSlot.macrotext)
    end

    BindPadCore.HidePopup()
    ShowUIPanel(BindPadMacroFrame)
end

function BindPadMacroFrameEditButton_OnClick(self)
    BindPadMacroPopupFrame_Open(BindPadCore.selectedSlotButton)
end

function BindPadMacroDeleteButton_OnClick(self)
    BindPadCore.HideSubFrames()

    local padSlot = BindPadCore.GetSlotInfo(BindPadCore.selectedSlotButton:GetID())
    if padSlot == nil then
        return
    end

    BindPadCore.DeleteBindPadMacroID(padSlot)

    table.wipe(padSlot)

    BindPadSlot_UpdateState(BindPadCore.selectedSlotButton)
end

function BindPadMacroFrame_OnShow(self)
    BindPadMacroFrameText:SetFocus()
end

function BindPadMacroFrame_OnHide(self)
    if BindPadCore.selectedSlot.macrotext ~= BindPadMacroFrameText:GetText() then
        if InCombatLockdown() then
            BindPadFrame_OutputText(L.TEXT_ERR_BINDPADMACRO_INCOMBAT)
            BindPadMacroFrameText:SetText(BindPadCore.selectedSlot.macrotext)
        else
            BindPadCore.selectedSlot.macrotext = BindPadMacroFrameText:GetText()
            BindPadCore.UpdateMacroText(BindPadCore.selectedSlot)
        end
    end

    if not BindPadFrame:IsVisible() then
        ShowUIPanel(BindPadFrame)
    end
end

function BindPadProfileTab_OnShow(self)
    local spec1, spec2, spec3, spec4 = BindPadCore.GetSpecsForProfile(self:GetID())
    local texture = BindPadCore.GetSpecTexture(spec1)
    -- A profile no talent group uses yet shows its number instead of an icon.
    self.Icon:SetTexture(texture)
    self.Number:SetText(texture == nil and self:GetID() or "")

    if spec2 then
        texture = BindPadCore.GetSpecTexture(spec2)
        self.subIcon:SetTexture(texture)
        self.subIcon:Show()
    else
        self.subIcon:Hide()
    end

    if spec3 then
        texture = BindPadCore.GetSpecTexture(spec3)
        self.subIcon2:SetTexture(texture)
        self.subIcon2:Show()
    else
        self.subIcon2:Hide()
    end

    if spec4 then
        texture = BindPadCore.GetSpecTexture(spec4)
        self.subIcon3:SetTexture(texture)
        self.subIcon3:Show()
    else
        self.subIcon3:Hide()
    end

    self:SetChecked(BindPadCore.GetCurrentProfileNum() == self:GetID())
end

function BindPadProfileTab_OnClick(self, button, upInside)
    if button ~= "LeftButton" or not upInside then
        return
    end
    if BindPadVars.tab == 1 and self:GetID() ~= BindPadCore.GetCurrentProfileNum() then
        BindPadFrameTab_OnClick(BindPadFrameTab2)
    end
    BindPadCore.SwitchProfile(self:GetID())
    BindPadFrame_OnShow()
    BindPadProfileTab_OnEnter(self)
end

function BindPadProfileTab_OnEnter(self, motion)
    local profileNum = self:GetID()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.TOOLTIP_EXTRA_PROFILE .. profileNum)

    local spec1, spec2, spec3, spec4 = BindPadCore.GetSpecsForProfile(self:GetID())
    if spec4 ~= nil then
        GameTooltip:AddLine(L.TOOLTIP_PROFILE_CURRENTLY4, 0.8, 0.8, 1.0)
    elseif spec3 ~= nil then
        GameTooltip:AddLine(
            format(
                L.TOOLTIP_PROFILE_CURRENTLY3,
                BindPadCore.GetTalentSpec(spec1),
                BindPadCore.GetTalentSpec(spec2),
                BindPadCore.GetTalentSpec(spec3)
            ),
            0.8,
            0.8,
            1.0
        )
    elseif spec2 ~= nil then
        GameTooltip:AddLine(
            format(L.TOOLTIP_PROFILE_CURRENTLY2, BindPadCore.GetTalentSpec(spec1), BindPadCore.GetTalentSpec(spec2)),
            0.8,
            0.8,
            1.0
        )
    elseif spec1 ~= nil then
        GameTooltip:AddLine(format(L.TOOLTIP_PROFILE_CURRENTLY1, BindPadCore.GetTalentSpec(spec1)), 0.8, 0.8, 1.0)
    end

    local specIndex = GetSpecialization()
    if profileNum ~= BindPadCore.GetProfileForSpec(specIndex) then
        GameTooltip:AddLine(
            format(L.TOOLTIP_PROFILE_CLICK_FOR, profileNum, BindPadCore.GetTalentSpec(specIndex)),
            0.8,
            1.0,
            0.8
        )
    end

    GameTooltip:Show()
end

--
-- BindPadCore:  A set of core functions
--

function BindPadCore.GetEquipmentSetTexture(setName)
    local setID = C_EquipmentSet.GetEquipmentSetID(setName)
    if setID then
        local _, iconFileID = C_EquipmentSet.GetEquipmentSetInfo(setID)
        return iconFileID
    end
    return nil
end

function BindPadCore.PlaceIntoSlot(id, type, detail, subdetail, spellid)
    local padSlot = BindPadCore.GetSlotInfo(id, true)

    if type == "item" then
        padSlot.type = TYPE_ITEM
        padSlot.linktext = subdetail
        local name, _, _, _, _, _, _, _, _, texture = GetItemInfo(padSlot.linktext)
        padSlot.name = name
        padSlot.texture = texture
    elseif type == "macro" then
        padSlot.type = TYPE_MACRO
        local name, texture = GetMacroInfo(detail)
        padSlot.name = name
        padSlot.texture = texture
    elseif type == "spell" then
        padSlot.type = TYPE_SPELL
        if not spellid and detail then
            local _, baseSpellID = GetSpellBookSpell(detail, subdetail)
            spellid = baseSpellID
        end
        local spellName, texture = GetSpellNameAndIcon(spellid)
        padSlot.bookType = NormalizeBookType(subdetail)
        padSlot.name = spellName
        -- A lower rank stays pinned to that rank; the highest rank follows new ranks as they are learned.
        padSlot.rank = spellid and IsLowRankSpell(spellid) and GetSpellRankText(spellid) or nil
        padSlot.spellid = spellid
        padSlot.texture = texture
    elseif type == "petaction" then
        if not detail then
            BindPadFrame_OutputText(format(L.TEXT_CANNOT_PLACE, type))
            return
        end
        local spellName = GetSpellBookName(detail, subdetail)
        local texture = GetSpellBookTexture(detail, subdetail)
        if BindPadPetAction[spellName] then
            padSlot.type = TYPE_BPMACRO
            padSlot.bookType = nil
            padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, BindPadPetAction[spellName])
            padSlot.rank = nil
            padSlot.texture = texture
            padSlot.macrotext = BindPadPetAction[spellName]
        else
            padSlot.type = TYPE_SPELL
            padSlot.bookType = NormalizeBookType(subdetail)
            padSlot.name = spellName
            padSlot.rank = nil
            padSlot.texture = texture
            padSlot.macrotext = nil
        end
    elseif type == "merchant" then
        padSlot.type = TYPE_ITEM
        padSlot.linktext = GetMerchantItemLink(detail)
        local name, _, _, _, _, _, _, _, _, texture = GetItemInfo(padSlot.linktext)
        padSlot.name = name
        padSlot.texture = texture
    elseif type == "mount" then
        padSlot.type = TYPE_BPMACRO
        if subdetail == 0 then
            local SUMMON_RANDOM_FAVORITE_MOUNT_SPELL = 150544
            local spellName, spellIcon = GetSpellNameAndIcon(SUMMON_RANDOM_FAVORITE_MOUNT_SPELL)
            padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, spellName)
            padSlot.texture = spellIcon

            -- This fails when player is in a Druid's shapeshift form;
            --  padSlot.macrotext = SLASH_SCRIPT1.." C_MountJournal.Summon(0)";

            -- This fails if Blizzard_PetBattleUI is not loaded in memory;
            --  padSlot.macrotext = SLASH_CLICK1.." MountJournalSummonRandomFavoriteButton";

            -- This will accidently cancel Priest's Shadowform.
            -- padSlot.macrotext = "/cancelform\n"..SLASH_SCRIPT1.." C_MountJournal.Summon(0)";

            -- A very hacky workaround to all of the above.
            padSlot.macrotext = "/cancelform [worn:Leather]\n" .. SLASH_SCRIPT1 .. " C_MountJournal.SummonByID(0)"
        else
            local creatureName, _, icon = C_MountJournal.GetMountInfoByID(detail)
            padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, creatureName)
            padSlot.texture = icon
            padSlot.macrotext = SLASH_CAST1 .. " " .. creatureName
        end
    elseif type == "battlepet" then
        padSlot.type = TYPE_BPMACRO
        local _, customName, _, _, _, _, _, petName, petIcon = C_PetJournal.GetPetInfoByPetID(detail)
        padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, customName or petName)
        padSlot.texture = petIcon
        padSlot.macrotext = SLASH_SUMMON_BATTLE_PET1 .. " " .. (customName or petName)
    elseif type == "equipmentset" then
        if _G.type(detail) == "number" then
            detail = C_EquipmentSet.GetEquipmentSetInfo(detail)
        end
        padSlot.type = TYPE_BPMACRO
        local textureName = BindPadCore.GetEquipmentSetTexture(detail)
        padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, detail)
        padSlot.texture = textureName
        padSlot.macrotext = SLASH_EQUIP_SET1 .. " " .. detail
    else
        BindPadFrame_OutputText(format(L.TEXT_CANNOT_PLACE, type))
        return
    end

    padSlot.action = BindPadCore.CreateBindPadMacroAction(padSlot)
    if (BindPadVars.tab or 1) == 1 then
        local key = GetBindingKey(padSlot.action)
        if key then
            if BindPadVars.GeneralKeyBindings[key] == padSlot.action then
                padSlot.isForAllCharacters = true
            end
        end
    end
    BindPadCore.UpdateMacroText(padSlot)
end

function BindPadCore.PlaceVirtualIconIntoSlot(id, drag)
    if TYPE_BPMACRO ~= drag.type then
        return
    end

    local padSlot = BindPadCore.GetSlotInfo(id, true)

    padSlot.type = drag.type
    padSlot.id = drag.id
    padSlot.macrotext = drag.macrotext
    padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, drag.name)
    padSlot.texture = drag.texture
    padSlot.action = BindPadCore.CreateBindPadMacroAction(padSlot)
    if (BindPadVars.tab or 1) == 1 then
        padSlot.isForAllCharacters = drag.isForAllCharacters
    else
        padSlot.isForAllCharacters = nil
    end
    BindPadCore.UpdateMacroText(padSlot)

    table.wipe(drag)
    PlaySound(SOUNDKIT.IG_ABILITY_ICON_DROP)
end

function BindPadCore.CheckCorruptedSlot(padSlot)
    if padSlot.type == TYPE_ITEM and padSlot.linktext and padSlot.name and padSlot.texture and padSlot.action then
        return false
    end
    if padSlot.type == TYPE_MACRO and padSlot.name and padSlot.texture and padSlot.action then
        return false
    end
    if padSlot.type == TYPE_SPELL and padSlot.bookType and padSlot.name and padSlot.texture and padSlot.action then
        return false
    end
    if padSlot.type == TYPE_BPMACRO and padSlot.name and padSlot.texture and padSlot.macrotext and padSlot.action then
        return false
    end

    table.wipe(padSlot)
    return true
end

function BindPadCore.GetCurrentProfileNum()
    if not BindPadCore.profileNum then
        BindPadCore.profileNum = 1
    end

    return BindPadCore.profileNum
end

function BindPadCore.GetProfileForSpec(specIndex)
    local character = BindPadCore.character
    if not character then
        return nil
    end
    if not BindPadVars[character].profileForTalentGroup[specIndex] then
        BindPadVars[character].profileForTalentGroup[specIndex] = specIndex
    end

    return BindPadVars[character].profileForTalentGroup[specIndex]
end

function BindPadCore.GetSpecsForProfile(profileNum)
    local spec1, spec2, spec3, spec4
    local character = BindPadCore.character

    if not character then
        return nil
    end

    local specIndex = GetSpecialization()
    if BindPadVars[character].profileForTalentGroup[specIndex] == profileNum then
        spec1 = specIndex
    end

    for k, v in pairs(BindPadVars[character].profileForTalentGroup) do
        if v == profileNum and k ~= specIndex then
            if spec1 == nil then
                spec1 = k
            elseif spec2 == nil then
                spec2 = k
            elseif spec3 == nil then
                spec3 = k
            elseif spec4 == nil then
                spec4 = k
            end
        end
    end

    return spec1, spec2, spec3, spec4
end

function BindPadCore.GetProfileData()
    local character = BindPadCore.character
    if not character then
        return nil
    end
    local profileNum = BindPadCore.GetCurrentProfileNum()
    local profile = BindPadVars[character][profileNum]

    return profile
end

function BindPadCore.SwitchProfile(newProfileNum, force)
    local oldProfileNum = BindPadCore.GetCurrentProfileNum()
    if not force and newProfileNum == oldProfileNum then
        return
    end

    if InCombatLockdown() then
        return
    end

    -- Close any optional frames.
    BindPadCore.HideSubFrames()

    local character = BindPadCore.character
    if not character then
        return
    end

    BindPadCore.profileNum = newProfileNum

    local specIndex = GetSpecialization()
    BindPadVars[character].profileForTalentGroup[specIndex] = newProfileNum

    -- Create new profile if not available
    if not BindPadVars[character][newProfileNum] then
        BindPadVars[character][newProfileNum] = {}

        -- This call to DoSaveAllKeys is nesessary
        -- Putting current keybindings data into a new profile tab table.
        BindPadCore.DoSaveAllKeys()
        BindPadFrame_OutputText(L.TEXT_CREATE_PROFILETAB)
    end

    -- Restore all Blizzard's Key Bindings for this spec if possible.
    BindPadCore.DoRestoreAllKeys()
end

function BindPadCore.CanPickupSlot(self)
    if not InCombatLockdown() then
        return true
    end
    local padSlot = BindPadCore.GetSlotInfo(self:GetID())
    if padSlot == nil then
        return false
    end
    if TYPE_SPELL == padSlot.type then
        BindPadFrame_OutputText(L.TEXT_ERR_SPELL_INCOMBAT)
        return false
    end
    if TYPE_MACRO == padSlot.type then
        BindPadFrame_OutputText(L.TEXT_ERR_MACRO_INCOMBAT)
        return false
    end
    return true
end

function BindPadCore.PickupSlot(self, id, isOnDragStart)
    local padSlot = BindPadCore.GetSlotInfo(id)
    if padSlot == nil then
        return
    end

    if self == BindPadCore.selectedSlotButton then
        BindPadCore.HideSubFrames()
    end

    if TYPE_ITEM == padSlot.type then
        PickupItem(padSlot.linktext)
    elseif TYPE_SPELL == padSlot.type then
        if padSlot.spellid then
            PickupSpell(padSlot.spellid)
        else
            local spellBookId = BindPadCore.FindSpellBookIdByName(padSlot.name, padSlot.rank, padSlot.bookType)
            if spellBookId then
                PickupSpellBookEntry(spellBookId, padSlot.bookType)
            end
        end
    elseif TYPE_MACRO == padSlot.type then
        PickupMacro(padSlot.name)
    elseif TYPE_BPMACRO == padSlot.type then
        local drag = BindPadCore.dragswap
        BindPadCore.dragswap = BindPadCore.drag
        BindPadCore.drag = drag

        drag.action = padSlot.action
        drag.id = padSlot.id
        drag.macrotext = padSlot.macrotext
        drag.name = padSlot.name
        drag.texture = padSlot.texture
        drag.type = padSlot.type
        drag.isForAllCharacters = padSlot.isForAllCharacters

        BindPadCore.UpdateCursor()
        PlaySound(SOUNDKIT.IG_ABILITY_OPEN)
    end
    if not (isOnDragStart and IsModifierKeyDown()) then
        -- Disable BindPadMacro (It will be re-enabled when placed on a slot.)
        BindPadCore.DeleteBindPadMacroID(padSlot)
        -- Empty the original slot
        table.wipe(padSlot)
    end
end

function BindPadCore.CarryOverKeybinding(key, action)
    local character = BindPadCore.character
    for profileNum = 1, BINDPAD_MAXPROFILETAB do
        local profile = BindPadVars[character][profileNum]
        if profile and profile.AllKeyBindings then
            profile.AllKeyBindings[key] = action
        end
    end
end

function BindPadCore.InnerSetBinding(key, action)
    BindPadCore.currentkeybindings[key] = action
    SetBinding(key, action)
end

function BindPadCore.ManuallySetBinding(key, action)
    BindPadCore.InnerSetBinding(key, action)

    -- Set common binding for all Profiles if it's general tab.
    if (BindPadVars.tab or 1) == 1 then
        BindPadCore.CarryOverKeybinding(key, action)

        if BindPadCore.selectedSlot.isForAllCharacters then
            BindPadVars.GeneralKeyBindings[key] = action
        else
            BindPadVars.GeneralKeyBindings[key] = nil
        end
    end
end

function BindPadCore.BindKey(padSlot, keyPressed)
    if not InCombatLockdown() then
        BindPadCore.UnbindSlot(padSlot)
        BindPadCore.ManuallySetBinding(keyPressed, padSlot.action)
        BindPadCore.SaveBindings(GetCurrentBindingSet())
    else
        BindPadFrame_OutputText(L.TEXT_CANNOT_BIND)
    end
end

function BindPadCore.UnbindSlot(padSlot)
    if not InCombatLockdown() then
        repeat
            local key = GetBindingKey(padSlot.action)
            if key then
                BindPadCore.ManuallySetBinding(key)
            end
        until key == nil
        BindPadCore.SaveBindings(GetCurrentBindingSet())
    end
end

function BindPadCore.GetSpellNum(bookType)
    if NormalizeBookType(bookType) == BOOKTYPE_PET then
        return GetNumPetSpells()
    end
    return GetNumPlayerSpells()
end

function BindPadCore.FindSpellBookIdByName(srchName, srchRank, bookType)
    for i = 1, BindPadCore.GetSpellNum(bookType), 1 do
        local spellName = GetSpellBookName(i, bookType)
        if spellName == srchName then
            return i
        end
    end
end

function BindPadCore.GetBindingText(name, prefix, returnAbbr)
    local modKeys = GetBindingText(name)

    if returnAbbr then
        modKeys = gsub(modKeys, "CTRL", "c")
        modKeys = gsub(modKeys, "SHIFT", "s")
        modKeys = gsub(modKeys, "ALT", "a")
        modKeys = gsub(modKeys, "STRG", "st")
        modKeys = gsub(modKeys, "(%l)-(%l)-", "%1%2-")
        modKeys = gsub(modKeys, "-?Num Pad ", "#")
    end

    return modKeys
end

function BindPadFrame_ChangeBindingProfile()
    if GetCurrentBindingSet() == 1 then
        LoadBindings(2)
        BindPadCore.SaveBindings(2)
    else
        local function f()
            local answer1 = BindPadCore.ShowDialog(CONFIRM_DELETING_CHARACTER_SPECIFIC_BINDINGS)
            if not answer1 then
                return
            end

            local answer2 = BindPadCore.ShowDialog(L.TEXT_ARE_YOU_SURE)
            if not answer2 then
                return
            end

            LoadBindings(1)
            BindPadCore.SaveBindings(1)
            BindPadVars.tab = 1
            BindPadFrame_OnShow()
        end

        -- Handles callback with coroutine.
        return coroutine.wrap(f)()
    end
end

function BindPadCore.ChatEdit_InsertLinkHook(text)
    if not text then
        return
    end
    if ChatFrameUtil.GetActiveWindow() then
        return
    end
    if MacroFrameText and MacroFrameText:IsVisible() then
        return
    end

    if BindPadMacroFrameText and BindPadMacroFrameText:IsVisible() then
        local _, _, kind, spellid = string.find(text, "^|c%x+|H(%a+):(%d+)[|:]")

        if kind == "item" then
            text = GetItemInfo(text)
        elseif kind == "spell" and spellid then
            text = GetSpellName(tonumber(spellid))
        end
        if BindPadMacroFrameText:GetText() == "" then
            if kind == "item" then
                if GetItemSpell(text) then
                    BindPadMacroFrameText:Insert(SLASH_USE1 .. " " .. text)
                else
                    BindPadMacroFrameText:Insert(SLASH_EQUIP1 .. " " .. text)
                end
            elseif kind == "spell" then
                BindPadMacroFrameText:Insert(SLASH_CAST1 .. " " .. text)
            else
                BindPadMacroFrameText:Insert(text)
            end
        else
            BindPadMacroFrameText:Insert(text)
        end
    end
end
do
    -- Hook both entry points; dedupe in case one forwards to the other.
    local lastText, lastTime
    local function InsertLinkHook(text)
        local now = GetTime()
        if text == lastText and now == lastTime then
            return
        end
        lastText, lastTime = text, now
        BindPadCore.ChatEdit_InsertLinkHook(text)
    end
    hooksecurefunc(ChatFrameUtil, "InsertLink", InsertLinkHook)
    -- Deprecated alias still used by some addons; it points at the unhooked original.
    if ChatEdit_InsertLink then
        hooksecurefunc("ChatEdit_InsertLink", InsertLinkHook)
    end
end

function BindPadCore.PickupSpellBookItemHook(slot, bookType)
    BindPadCore.PickupSpellBookItem_slot = slot
    BindPadCore.PickupSpellBookItem_bookType = bookType
end
hooksecurefunc(C_SpellBook, "PickupSpellBookItem", BindPadCore.PickupSpellBookItemHook)

function BindPadCore.InitBindPadOnce(event)
    if not BindPadCore.initialized then
        BindPadCore.initialized = true

        -- GetCurrentBindingSet() may not be ready yet.
        -- But sometimes we are already in combat at login.
        -- So do it now! or we won't have a chance to do it until combat finished.
        BindPadCore.InitProfile()
        BindPadCore.InitHotKeyList()
        BindPadCore.UpdateAllHotkeys()
    end
end

function BindPadCore.InitProfile()
    BindPadCore.character = "PROFILE_" .. GetRealmName() .. "_" .. UnitName("player")
    local character = BindPadCore.character

    if not BindPadVars[character] then
        local profileNum = BindPadCore.GetCurrentProfileNum()
        BindPadVars[character] = {}
        BindPadVars[character][profileNum] = {}
    end

    if not BindPadVars[character].profileForTalentGroup then
        BindPadVars[character].profileForTalentGroup = {}
    end

    local newActiveTalentGroup = GetSpecialization()
    local profileNum = BindPadCore.GetProfileForSpec(newActiveTalentGroup)

    -- Make sure profileNum tab is set for current talent group.
    BindPadCore.SwitchProfile(profileNum, true)

    BindPadMacro:SetAttribute("*type*", "macro")
    BindPadKey:SetAttribute("*checkselfcast*", true)
    BindPadKey:SetAttribute("*checkfocuscast*", true)
    BindPadRank:SetAttribute("*checkselfcast*", true)
    BindPadRank:SetAttribute("*checkfocuscast*", true)
    -- /click sends an up-click whatever the cast-on-key-down setting is.
    BindPadRank:SetAttribute("useOnKeyDown", false)
    BindPadRank:RegisterForClicks("AnyUp")

    BindPadCore.SetTriggerOnKeydown()

    -- HACK: Making sure BindPadMacroFrame has UIPanelLayout defined.
    -- If we don't do this at the init, ShowUIPanel() may fail in combat.
    GetUIPanelWidth(BindPadMacroFrame)
    -- Set current version number
    BindPadVars.version = BINDPAD_SAVEFILE_VERSION
end

function BindPadCore.UpdateMacroText(padSlot)
    if padSlot == nil then
        return
    end

    BindPadCore.CheckCorruptedSlot(padSlot)
    if TYPE_ITEM == padSlot.type then
        BindPadKey:SetAttribute("*type-ITEM " .. padSlot.name, "item")
        BindPadKey:SetAttribute("*item-ITEM " .. padSlot.name, padSlot.name)
    elseif TYPE_SPELL == padSlot.type then
        local command = GetSpellSlotCommand(padSlot)
        BindPadKey:SetAttribute("*type-" .. command, "spell")
        BindPadKey:SetAttribute("*spell-" .. command, IsRankPinned(padSlot) and padSlot.spellid or padSlot.name)
    elseif TYPE_MACRO == padSlot.type then
        BindPadKey:SetAttribute("*type-MACRO " .. padSlot.name, "macro")
        BindPadKey:SetAttribute("*macro-MACRO " .. padSlot.name, padSlot.name)
    elseif TYPE_BPMACRO == padSlot.type then
        BindPadMacro:SetAttribute("*macrotext-" .. padSlot.name, padSlot.macrotext)
        for spellID in padSlot.macrotext:gmatch("BindPadRank (%d+)") do
            BindPadCore.SetRankProxy(spellID)
        end
    else
        return
    end

    -- !!!!! It's NOT old file conversion.
    -- Update string of padSlot.action
    -- And then update a keybinding for the padSlot.action.
    local newAction = BindPadCore.CreateBindPadMacroAction(padSlot)
    if padSlot.action ~= newAction then
        local key = GetBindingKey(padSlot.action)
        if key then
            BindPadCore.InnerSetBinding(key, newAction)
            BindPadCore.SaveBindings(GetCurrentBindingSet())
        end
        padSlot.action = newAction
    end
end

function BindPadCore.NewBindPadMacroName(padSlot, name)
    local successFlag
    repeat
        successFlag = true
        for curSlot in BindPadCore.AllSlotInfoIter() do
            if
                TYPE_BPMACRO == curSlot.type
                and padSlot ~= curSlot
                and curSlot.name ~= nil
                and strlower(name) == strlower(curSlot.name)
            then
                local first, _, num = strfind(name, "(%d+)$")
                if not num then
                    name = name .. "_2"
                else
                    name = strsub(name, 0, first - 1) .. (num + 1)
                end
                successFlag = false
                break
            end
        end
    until successFlag

    return name
end

function BindPadCore.DeleteBindPadMacroID(padSlot)
    BindPadMacro:SetAttribute("*macrotext-" .. padSlot.name, nil)
end

-- Macros can't /cast a lower rank by name, so they /click BindPadRank with the rank's spell ID as the button.
function BindPadCore.SetRankProxy(spellID)
    BindPadRank:SetAttribute("*type-" .. spellID, "spell")
    BindPadRank:SetAttribute("*spell-" .. spellID, tonumber(spellID))
end

function BindPadCore.UpdateCursor()
    local drag = BindPadCore.drag
    if GetCursorInfo() then
        BindPadCore.ClearCursor()
    end
    if TYPE_BPMACRO == drag.type then
        if type(drag.texture) == "number" then
            -- SetCursor() doesn't accept numbers.
            SetCursor("Interface\\ICONS\\INV_Misc_QuestionMark")
        else
            SetCursor(drag.texture)
        end
    end
end

function BindPadCore.CreateBindPadMacroAction(padSlot)
    if padSlot.name == nil then
        return nil
    end
    if TYPE_ITEM == padSlot.type then
        return "CLICK BindPadKey:ITEM " .. padSlot.name
    elseif TYPE_SPELL == padSlot.type then
        return "CLICK BindPadKey:" .. GetSpellSlotCommand(padSlot)
    elseif TYPE_MACRO == padSlot.type then
        return "CLICK BindPadKey:MACRO " .. padSlot.name
    elseif TYPE_BPMACRO == padSlot.type then
        return "CLICK BindPadMacro:" .. padSlot.name
    end
    return nil
end

function BindPadCore.ConvertToBindPadMacro()
    local padSlot = BindPadCore.selectedSlot

    if TYPE_ITEM == padSlot.type then
        padSlot.type = TYPE_BPMACRO
        padSlot.linktext = nil
        padSlot.macrotext = SLASH_USE1 .. " [mod:SELFCAST,@player][mod:FOCUSCAST,@focus][] " .. padSlot.name
    elseif TYPE_SPELL == padSlot.type then
        if IsRankPinned(padSlot) then
            padSlot.macrotext = SLASH_CLICK1 .. " BindPadRank " .. padSlot.spellid
        else
            padSlot.macrotext = SLASH_CAST1 .. " [mod:SELFCAST,@player][mod:FOCUSCAST,@focus][] " .. padSlot.name
        end
        padSlot.type = TYPE_BPMACRO
        padSlot.bookType = nil
        padSlot.rank = nil
        padSlot.spellid = nil
    elseif TYPE_MACRO == padSlot.type then
        local _, _, macrotext = GetMacroInfo(padSlot.name)
        padSlot.type = TYPE_BPMACRO
        padSlot.macrotext = macrotext or ""
    else
        return
    end

    padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, padSlot.name)
    padSlot.action = BindPadCore.CreateBindPadMacroAction(padSlot)
    BindPadCore.UpdateMacroText(padSlot)

    BindPadSlot_UpdateState(BindPadCore.selectedSlotButton)
    BindPadMacroFrame_Open(BindPadCore.selectedSlotButton)
end

function BindPadCore.CursorHasIcon()
    return GetCursorInfo() or BindPadCore.drag.type
end

function BindPadCore.ClearCursor()
    local drag = BindPadCore.drag
    if TYPE_BPMACRO == drag.type then
        ResetCursor()
        PlaySound(SOUNDKIT.IG_ABILITY_ICON_DROP)
    end
    drag.type = nil
end

function BindPadCore.PlayerTalentUpdate()
    -- Reset cache for morphing spells
    BindPadCore.morphingSpellCache = nil

    local newActiveSpec = GetSpecialization()
    local profileNum = BindPadCore.GetProfileForSpec(newActiveSpec)

    BindPadCore.SwitchProfile(profileNum)
    if BindPadFrame:IsShown() then
        BindPadFrame_OnShow()
    end
end

function BindPadCore.CVAR_UPDATE(arg1, arg2)
    if arg1 == "ACTION_BUTTON_USE_KEY_DOWN" or arg1 == "ActionButtonUseKeyDown" then
        BindPadCore.SetTriggerOnKeydown()
    end
end

function BindPadCore.GetSpecTexture(specIndex)
    if specIndex == nil then
        return nil
    end
    local _, icon = BindPadCore.GetSpecializationInfo(specIndex)
    if icon ~= nil then
        return icon
    end
    return "Interface\\Icons\\Ability_Marksmanship"
end

function BindPadCore.SetTriggerOnKeydown()
    if InCombatLockdown() then
        BindPadCore.WaitForEvent("PLAYER_REGEN_ENABLED", BindPadCore.SetTriggerOnKeydown)
        return
    end
    local keyDown = GetCVarBool("ActionButtonUseKeyDown")
    -- Modern SecureActionButtonTemplate only fires when the click direction matches useOnKeyDown.
    BindPadMacro:SetAttribute("useOnKeyDown", keyDown)
    BindPadKey:SetAttribute("useOnKeyDown", keyDown)
    if keyDown then
        -- Triggered on pressing a key instead of releasing.
        BindPadMacro:RegisterForClicks("AnyDown")
        BindPadKey:RegisterForClicks("AnyDown")
    else
        -- Triggered on releasing a key.
        BindPadMacro:RegisterForClicks("AnyUp")
        BindPadKey:RegisterForClicks("AnyUp")
    end
end

function BindPadCore.GetTalentSpec(specIndex)
    if specIndex == nil then
        return ""
    end
    return (BindPadCore.GetSpecializationInfo(specIndex))
end

function BindPadCore.DoList(arg)
    for k in pairs(BindPadVars) do
        local name = string.match(k, "^PROFILE_(.*)")
        if name then
            print(name)
        end
    end
end

function BindPadCore.DoDelete(arg)
    local name = "PROFILE_" .. arg
    if name == BindPadCore.character then
        BindPadFrame_OutputText(L.TEXT_DO_DELETE_ERR_CURRENT)
    else
        if BindPadVars[name] then
            BindPadVars[name] = nil
            BindPadFrame_OutputText(string.format(L.TEXT_DO_DELETE, arg))
        else
            BindPadFrame_OutputText(string.format(L.TEXT_DO_ERR_NOT_FOUND, arg))
        end
    end
end

function BindPadCore.DoCopyFrom(arg)
    local name = "PROFILE_" .. arg
    if name == BindPadCore.character then
        BindPadFrame_OutputText(L.TEXT_DO_COPY_ERR_CURRENT)
    else
        if BindPadVars[name] then
            local backupname = BindPadCore.character .. "_backup"
            if BindPadVars[backupname] == nil then
                BindPadVars[backupname] = BindPadVars[BindPadCore.character]
            end
            BindPadVars[BindPadCore.character] = BindPadCore.DuplicateTable(BindPadVars[name])
            BindPadCore.InitProfile()

            if BindPadFrame:IsShown() then
                BindPadFrame_OnShow()
            end
            BindPadFrame_OutputText(string.format(L.TEXT_DO_COPY, arg))
        else
            BindPadFrame_OutputText(string.format(L.TEXT_DO_ERR_NOT_FOUND, arg))
        end
    end
end

function BindPadCore.DuplicateTable(table)
    local newtable = {}
    for k, v in pairs(table) do
        if type(v) == "table" then
            newtable[k] = BindPadCore.DuplicateTable(v)
        else
            newtable[k] = v
        end
    end
    return newtable
end

function BindPadFrame_SaveAllKeysToggle()
    BindPadVars.saveAllKeysFlag = not BindPadVars.saveAllKeysFlag
    BindPadCore.DoSaveAllKeys()
end

function BindPadFrame_ShowHotkeyToggle()
    BindPadVars.showHotkey = not BindPadVars.showHotkey
    BindPadCore.UpdateAllHotkeys()
end

function BindPadCore.DoSaveAllKeys()
    if BindPadCore.ChangingKeyBindings then
        return
    end
    if not BindPadCore.character then
        return
    end
    local profile = BindPadCore.GetProfileData()

    if profile.AllKeyBindings == nil then
        profile.AllKeyBindings = {}
    else
        table.wipe(profile.AllKeyBindings)
    end
    if BindPadVars.GeneralKeyBindings == nil then
        BindPadVars.GeneralKeyBindings = {}
    else
        table.wipe(BindPadVars.GeneralKeyBindings)
    end

    for i = 1, GetNumBindings() do
        local command, _, key1, key2 = GetBinding(i)
        if key1 then
            profile.AllKeyBindings[key1] = command
            if key2 then
                profile.AllKeyBindings[key2] = command
            end
        end
    end
    for padSlot in BindPadCore.AllSlotInfoIter() do
        local key = GetBindingKey(padSlot.action)
        if key then
            profile.AllKeyBindings[key] = padSlot.action
            if padSlot.isForAllCharacters then
                BindPadVars.GeneralKeyBindings[key] = padSlot.action
            end
        end
    end
end

function BindPadCore.DoRestoreAllKeys()
    local profile = BindPadCore.GetProfileData()
    if profile.AllKeyBindings == nil then
        -- Initialize keyBindings table if none available.
        BindPadCore.DoSaveAllKeys()
    end

    if BindPadVars.GeneralKeyBindings == nil then
        BindPadVars.GeneralKeyBindings = {}
    end

    local count = 0
    for _ in pairs(profile.AllKeyBindings) do
        count = count + 1
    end

    if count < 10 then
        BindPadFrame_OutputText("DEBUG: Something wrong. profile.AllKeyBindings is most likely broken.")
        return
    end

    BindPadCore.ChangingKeyBindings = true

    -- Override GeneralKeyBindings over all profiles.
    for k, v in pairs(BindPadVars.GeneralKeyBindings) do
        BindPadCore.CarryOverKeybinding(k, v)
    end

    -- Unbind Blizzard's key bindings only when "Save All Keys" option is ON.
    if BindPadVars.saveAllKeysFlag then
        for i = 1, GetNumBindings() do
            local _, _, key1, key2 = GetBinding(i)
            -- Ensure to be unbinded if not binded.
            if key1 and profile.AllKeyBindings[key1] == nil then
                BindPadCore.InnerSetBinding(key1, nil)
            end
            -- Ensure to be unbinded if not binded.
            if key2 and profile.AllKeyBindings[key2] == nil then
                BindPadCore.InnerSetBinding(key2, nil)
            end
        end
    end

    local to_be_removed = {}
    for k, v in pairs(BindPadCore.currentkeybindings) do
        -- Ensure to be unbinded if not binded.
        if profile.AllKeyBindings[k] == nil then
            if strfind(v, "^CLICK BindPad") then
                table.insert(to_be_removed, k)
            end
        end
    end

    for i = 1, #to_be_removed do
        BindPadCore.InnerSetBinding(to_be_removed[i], nil)
    end

    for k, v in pairs(profile.AllKeyBindings) do
        if BindPadVars.saveAllKeysFlag or strfind(v, "^CLICK BindPad") then
            local key1, key2 = GetBindingKey(v)
            if key1 ~= k and key2 ~= k then
                BindPadCore.InnerSetBinding(k, v)
            else
                BindPadCore.currentkeybindings[k] = v
            end
        end
    end

    BindPadCore.ChangingKeyBindings = false

    -- Don't do it twice.
    local ticker = BindPadCore.ticker_SaveBindings
    if ticker ~= nil then
        ticker:Cancel()
    end

    -- 2.7.13: It really need to be saved.  So do it later with 0.5 sec delay.
    BindPadCore.ticker_SaveBindings = C_Timer.NewTicker(0.5, function()
        BindPadCore.ticker_SaveBindings = nil
        local function run()
            BindPadCore.SaveBindings(GetCurrentBindingSet())
        end
        if InCombatLockdown() then
            BindPadCore.WaitForEvent("PLAYER_REGEN_ENABLED", run)
        else
            run()
        end
    end, 1)

    for padSlot in BindPadCore.AllSlotInfoIter() do
        -- Prepare macro text for every BindPad Macro for this profile.
        BindPadCore.UpdateMacroText(padSlot)
    end
end

function BindPadCore.InsertBindingTooltip(key)
    if BindPadVars.showHotkey and key then
        GameTooltip:AddLine(L.TOOLTIP_KEYBINDING .. BindPadCore.GetBindingText(key, "KEY_"), 0.8, 0.8, 1.0)
        GameTooltip:Show()
    end
end

-- The key of a BindPad action, also trying the base spell when action is a morphed spell.
function BindPadCore.FindKeyForAction(action)
    if not action then
        return nil
    end
    return BindPadCore.GetBindingKeyFromAction(action)
        or BindPadCore.GetBindingKeyFromAction(BindPadCore.GetBaseForMorphingSpell(action))
end

-- The key that casts this exact spell: a slot pinned to its rank, or, unless it is a lower rank, a slot casting the spell by name.
function BindPadCore.FindSpellKey(spellID)
    if spellID == nil or issecretvalue(spellID) then
        return nil
    end
    local spellName = GetSpellName(spellID)
    if not spellName then
        return nil
    end
    local rank = GetSpellRankText(spellID)
    if rank then
        local key = BindPadCore.GetBindingKeyFromAction(GetRankedSpellCommand(spellName, rank))
        if key or IsLowRankSpell(spellID) then
            return key
        end
    end
    return BindPadCore.FindKeyForAction("SPELL " .. spellName)
end

function BindPadCore.GameTooltipSetItemByID(self, itemID)
    BindPadCore.InsertBindingTooltip(BindPadCore.FindKeyForAction(concat("ITEM ", GetItemInfo(itemID))))
end

function BindPadCore.GameTooltipSetBagItem(self, bag, slot)
    local itemID = C_Container.GetContainerItemID(bag, slot)
    if itemID then
        BindPadCore.InsertBindingTooltip(BindPadCore.FindKeyForAction(concat("ITEM ", GetItemInfo(itemID))))
    end
end

function BindPadCore.GameTooltipSetSpellByID(self, spellID)
    BindPadCore.InsertBindingTooltip(BindPadCore.FindSpellKey(spellID))
end

function BindPadCore.GameTooltipSetSpellBookItem(self, slot, bookType)
    local isSpell, spellID = GetSpellBookSpell(slot, bookType)
    if isSpell then
        BindPadCore.InsertBindingTooltip(BindPadCore.FindSpellKey(spellID))
    else
        BindPadCore.InsertBindingTooltip(
            BindPadCore.FindKeyForAction(concat("SPELL ", GetSpellBookName(slot, bookType)))
        )
    end
end

function BindPadCore.GameTooltipSetAction(self, slot)
    BindPadCore.InsertBindingTooltip(BindPadCore.GetActionKey(slot))
end

for method, handler in pairs({
    SetItemByID = "GameTooltipSetItemByID",
    SetBagItem = "GameTooltipSetBagItem",
    SetSpellByID = "GameTooltipSetSpellByID",
    SetSpellBookItem = "GameTooltipSetSpellBookItem",
    SetAction = "GameTooltipSetAction",
}) do
    if GameTooltip[method] then
        hooksecurefunc(GameTooltip, method, function(...)
            if BindPadVars.showHotkey then
                return BindPadCore[handler](...)
            end
        end)
    end
end

function BindPadCore.ShowDialog(text)
    BindPadCore.CancelDialogs()

    local dialog = BindPadDialogFrame
    dialog.text:SetText(text)
    local height = 22 + dialog.text:GetHeight() + 16 + dialog.okaybutton:GetHeight() + 18
    dialog:SetHeight(height)

    local co = coroutine.running()
    -- Making closures with current local value of co.
    dialog.okaybutton:SetScript("OnClick", function(self)
        self:GetParent():Hide()
        coroutine.resume(co, true)
    end)
    dialog.cancelbutton:SetScript("OnClick", function(self)
        self:GetParent():Hide()
        coroutine.resume(co, false)
    end)
    dialog:Show()

    return coroutine.yield()
end

function BindPadCore.CancelDialogs()
    local dialog = BindPadDialogFrame
    if dialog:IsShown() then
        dialog.cancelbutton:Click()
    end
end

BindPadCore.HotKeyList = {}
BindPadCore.CreateFrameQueue = {}

function BindPadCore.InitHotKeyList()
    if not (ActionBarButtonEventsFrame and ActionBarButtonEventsFrame.frames) then
        return
    end
    for _, button in pairs(ActionBarButtonEventsFrame.frames) do
        if button:GetName() then
            BindPadCore.CreateFrameQueue[button:GetName()] = "ActionBarButtonTemplate"
        end
    end
end

function BindPadCore.AddHotKey(name, GetAction)
    if BindPadCore.HotKeyList[name] then
        return
    end

    local button = _G[name]
    if not button then
        return
    end

    local hotkey = button.HotKey or _G[name .. "HotKey"]
    if not hotkey then
        return
    end

    local info = {}
    info.GetAction = GetAction
    info.button = button
    info.hotkey = hotkey

    -- Mirror the original hotkey so bar addons that restyle/reparent it (e.g. EllesmereUI) still line up.
    local layer, sublevel = hotkey:GetDrawLayer()
    info.bphotkey = (hotkey:GetParent() or button):CreateFontString(
        name .. "BPHotKey",
        layer or "ARTWORK",
        "NumberFontNormalSmallGray",
        sublevel
    )
    info.bphotkey:SetAllPoints(hotkey)
    info.bphotkey:SetJustifyH(hotkey:GetJustifyH() or "RIGHT")
    info.bphotkey:Show()

    -- Copying the range indicator color change.
    hooksecurefunc(info.hotkey, "SetVertexColor", function(self, red, green, blue)
        return info.bphotkey:SetVertexColor(red, green, blue)
    end)

    BindPadCore.HotKeyList[name] = info
end

function BindPadCore.AddAllHotKeys()
    for buttonname, buttontype in pairs(BindPadCore.CreateFrameQueue) do
        if buttontype == "ActionBarButtonTemplate" then
            BindPadCore.AddHotKey(buttonname, function(info)
                return info.button.action or info.button:GetAttribute("action")
            end)
        elseif buttontype == "LibActionButton" then
            if _G[buttonname].GetAction then
                BindPadCore.AddHotKey(buttonname, function(info)
                    local type, action = info.button:GetAction()
                    if type == "action" then
                        return action
                    else
                        return nil
                    end
                end)
            end
        end
    end
    table.wipe(BindPadCore.CreateFrameQueue)
end

function BindPadCore.UpdateAllHotkeys()
    local function f()
        BindPadCore.ticker_UpdateAllHotkeys = nil
        BindPadCore.AddAllHotKeys()
        for _, info in pairs(BindPadCore.HotKeyList) do
            BindPadCore.OverwriteHotKey(info)
        end
    end

    -- Don't do it twice.
    local ticker = BindPadCore.ticker_UpdateAllHotkeys
    if ticker ~= nil then
        ticker:Cancel()
    end

    -- It's hard work, so do it later with 0.1 sec delay.
    BindPadCore.ticker_UpdateAllHotkeys = C_Timer.NewTicker(0.1, f, 1)
end

function BindPadCore.OverwriteHotKey(info)
    if BindPadVars.showHotkey then
        local actionSlot = info:GetAction()
        if issecretvalue(actionSlot) then
            -- Action slots can be secret in combat on the modern client; keep the current text.
            return
        end
        local key = BindPadCore.GetActionKey(actionSlot)
        if key then
            -- BindPad's ShowHotKey
            local font, size, flags = info.hotkey:GetFont()
            if font then
                info.bphotkey:SetFont(font, size, flags)
            end
            info.bphotkey:SetTextColor(info.hotkey:GetTextColor())
            info.bphotkey:SetText(BindPadCore.GetBindingText(key, "KEY_", 1))
            info.bphotkey:SetAlpha(1)

            -- Making original hotkey transparent.
            info.hotkey:SetAlpha(0)
            return
        end
    end

    -- Restoring original hotkey
    info.bphotkey:SetAlpha(0)
    info.hotkey:SetAlpha(1)
end

function BindPadCore.GetActionKey(actionSlot)
    if not actionSlot then
        return nil
    end
    local type, id = GetActionInfo(actionSlot)
    if issecretvalue(id) then
        return nil
    end
    if type == "spell" then
        return BindPadCore.FindSpellKey(id)
    elseif type == "item" then
        return BindPadCore.FindKeyForAction(concat("ITEM ", GetItemInfo(id)))
    elseif type == "macro" then
        return BindPadCore.FindKeyForAction(concat("MACRO ", GetMacroInfo(id)))
    end
    return nil
end

function BindPadCore.CreateFrameHook(frameType, frameName, parentFrame, inheritsFrame, id)
    if frameType == "CheckButton" and inheritsFrame then
        if frameName then
            if frameName:match("$parent") and parentFrame:GetName() then
                frameName = frameName:gsub("$parent", parentFrame:GetName())
            end
            if not _G[frameName] then
                return
            end
            -- Match ActionBarButtonTemplate anywhere in the inherits list (EllesmereUI uses "ActionBarButtonTemplate, SecureActionButtonTemplate").
            local templates = "," .. (inheritsFrame:gsub("%s", "")) .. ","
            if templates:find(",ActionBarButtonTemplate,", 1, true) then
                BindPadCore.CreateFrameQueue[frameName] = "ActionBarButtonTemplate"
            end
            if string.find(inheritsFrame, "SecureActionButtonTemplate%s*,%s*ActionButtonTemplate") then
                BindPadCore.CreateFrameQueue[frameName] = "LibActionButton"
            end
            -- Bartender4's LibActionButton uses reversed template order
            if string.find(inheritsFrame, "ActionButtonTemplate%s*,%s*SecureActionButtonTemplate") then
                BindPadCore.CreateFrameQueue[frameName] = "LibActionButton"
            end
            if BindPadCore.initialized and BindPadCore.CreateFrameQueue[frameName] then
                BindPadCore.UpdateAllHotkeys()
            end
        end
    end
end
hooksecurefunc("CreateFrame", BindPadCore.CreateFrameHook)

BindPadCore.useBindPadSlot = 0
local NUM_SLOTS_PER_ROW = 6
local SLOT_SIZE = 42
local SLOT_SPACING = 10
local SLOT_LEFT = 1
local SLOT_TOP = 4

function BindPadCore.CreateBindPadSlot(usenum)
    for i = min(usenum + 1, BindPadCore.useBindPadSlot + 1), max(usenum, BindPadCore.useBindPadSlot) do
        local button = _G["BindPadSlot" .. i]
        if button == nil then
            button =
                CreateFrame("CheckButton", "BindPadSlot" .. i, BindPadSlotButtonContainer, "BindPadSlotTemplate", i)
        end
        if i <= usenum then
            local row, column = floor((i - 1) / NUM_SLOTS_PER_ROW), (i - 1) % NUM_SLOTS_PER_ROW
            button:ClearAllPoints()
            button:SetPoint(
                "TOPLEFT",
                BindPadSlotButtonContainer,
                "TOPLEFT",
                SLOT_LEFT + column * (SLOT_SIZE + SLOT_SPACING),
                -(SLOT_TOP + row * (SLOT_SIZE + SLOT_SPACING))
            )
            button:Enable()
            button:Show()
        else
            button:Hide()
            button:Disable()
            button:ClearAllPoints()
        end
    end

    -- The scroll range comes from the scroll child's height.
    local rows = math.ceil(usenum / NUM_SLOTS_PER_ROW)
    BindPadSlotButtonContainer:SetHeight(SLOT_TOP * 2 + rows * SLOT_SIZE + (rows - 1) * SLOT_SPACING)

    BindPadCore.useBindPadSlot = usenum
    BindPadScrollFrameNumber:SetFormattedText(L.TEXT_SLOTS_SHOWN, usenum)
    if usenum > BINDPAD_MAXSLOTS_DEFAULT then
        BindPadShowLessSlotButton:Enable()
    else
        BindPadShowLessSlotButton:Disable()
    end
end

function BindPadShowLessSlotButton_OnClick()
    local tabInfo = BindPadCore.GetTabInfo(BindPadVars.tab)
    tabInfo.numSlot = tabInfo.numSlot - 42
    BindPadFrame_OnShow()
end

function BindPadShowMoreSlotButton_OnClick()
    local tabInfo = BindPadCore.GetTabInfo(BindPadVars.tab)
    tabInfo.numSlot = tabInfo.numSlot + 42
    BindPadFrame_OnShow()
end

function BindPadCore.GetSlotInfo(id, newFlag)
    return BindPadCore.GetSlotInfoInTab(BindPadVars.tab, id, newFlag)
end

function BindPadCore.GetTabInfo(tab)
    if tab == BINDPAD_GENERAL_TAB then
        if BindPadVars.numSlot == nil then
            BindPadVars.numSlot = BINDPAD_MAXSLOTS_DEFAULT
        end

        return BindPadVars
    else
        local character = BindPadCore.character
        local profileNum = BindPadCore.GetCurrentProfileNum()
        if not BindPadVars[character][profileNum] then
            BindPadVars[character][profileNum] = {}
        end
        local profile = BindPadVars[character][profileNum]

        local tabname = "CharacterSpecificTab" .. (tab - BINDPAD_GENERAL_TAB)
        if not profile[tabname] then
            profile[tabname] = {}
            for newid = 1, BINDPAD_MAXSLOTS_DEFAULT do
                local oldid = newid + (tab - 2) * BINDPAD_MAXSLOTS_DEFAULT
                -- Relocating old SlotInfo into the new table.
                profile[tabname][newid] = profile[oldid]
                profile[oldid] = nil
            end
            if profile[tabname].numSlot == nil then
                profile[tabname].numSlot = BINDPAD_MAXSLOTS_DEFAULT
            end
        end

        return profile[tabname]
    end
end

function BindPadCore.GetSlotInfoInTab(tab, id, newFlag)
    if not BindPadCore.character then
        BindPadFrame_OutputText("DEBUG: Something wrong.  Please report this message to the author of BindPad.")
        return nil
    end

    if tab == nil then
        tab = 1
    end

    if id == nil then
        return nil
    end

    local tabInfo = BindPadCore.GetTabInfo(tab)
    if not tabInfo[id] then
        if newFlag then
            tabInfo[id] = {}
        end
    else
        if not newFlag and tabInfo[id].type == nil then
            tabInfo[id] = nil
        end
    end

    return tabInfo[id]
end

function BindPadCore.AllSlotInfoIter()
    local function f()
        for tab = 1, 4 do
            local numSlot = BindPadCore.GetTabInfo(tab).numSlot
            for id = 1, numSlot do
                local padSlot = BindPadCore.GetSlotInfoInTab(tab, id, nil)
                if padSlot then
                    coroutine.yield(padSlot)
                end
            end
        end
    end

    return coroutine.wrap(f)
end

function BindPadCore.HidePopup()
    BindPadMacroPopupFrame:Hide()
    BindPadBindFrame:Hide()
end

function BindPadCore.HideSubFrames()
    BindPadCore.HidePopup()
    HideUIPanel(BindPadMacroFrame)
end

function BindPadCore.SaveBindings(which)
    -- GetCurrentBindingSet() sometimes returns an invalid number at login; there is no good way to avoid this.
    if which == 1 or which == 2 then
        SaveBindings(which)
    end
end

function BindPadCore.GetBaseForMorphingSpell(spellAction)
    if not BindPadCore.morphingSpellCache then
        BindPadCore.morphingSpellCache = {}
        local bookType = BOOKTYPE_SPELL
        for i = 1, BindPadCore.GetSpellNum(bookType), 1 do
            local isSpell, spellId = GetSpellBookSpell(i, bookType)
            if isSpell then
                local morphSpellName = GetSpellBookName(i, bookType)
                local baseSpellName = GetSpellName(spellId)
                if morphSpellName and baseSpellName and string.upper(baseSpellName) ~= string.upper(morphSpellName) then
                    BindPadCore.morphingSpellCache["SPELL " .. string.upper(morphSpellName)] = "SPELL " .. baseSpellName
                end
            end
        end
    end

    if BindPadCore.morphingSpellCache[string.upper(spellAction)] then
        return BindPadCore.morphingSpellCache[string.upper(spellAction)]
    else
        return spellAction
    end
end

function BindPadFrame_ForAllCharactersToggle(self)
    local padSlot = BindPadCore.selectedSlot
    padSlot.isForAllCharacters = (not not self:GetChecked())

    local key = GetBindingKey(padSlot.action)
    if key then
        -- Re-bind same existing keybinding to update BindPadVars.GeneralKeyBindings.
        BindPadCore.ManuallySetBinding(key, padSlot.action)
    end
end

function BindPadCore.GetBindingKeyFromAction(action)
    local key = GetBindingKey("CLICK BindPadKey:" .. action)
    if key then
        -- Check if this keybind is ready to use. (or residue)
        if BindPadKey:GetAttribute("*type-" .. action) then
            return key
        end
    end
    return nil
end

function BindPadCore.WaitForEvent(event, func)
    if BindPadCore.JobFrame == nil then
        BindPadCore.JobFrame = CreateFrame("FRAME", "BindPadCoreJobFrame")
    end
    local stack = nil
    if BindPadCore.eventProc[event] ~= nil then
        stack = BindPadCore.eventProc[event]
    else
        BindPadCore.JobFrame:RegisterEvent(event)
        local function OnEvent(self, event2, ...)
            local run = BindPadCore.eventProc[event2]
            if run ~= nil then
                BindPadCore.eventProc[event2] = nil
                run(event2, ...)
            end
        end
        BindPadCore.JobFrame:SetScript("OnEvent", OnEvent)
    end
    local function f(...)
        BindPadCore.JobFrame:UnregisterEvent(event)
        func(...)
        if stack ~= nil then
            stack(...)
        end
    end
    BindPadCore.eventProc[event] = f
end
