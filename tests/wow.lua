-- A small mock of the WoW client: enough of the key binding system, saved variables and
-- character identity to run BindPad's real code through login sessions on several characters.
--
-- A World holds what outlives a session (SavedVariables, the account and per-character binding
-- sets, the clock). world:Login(character) loads the addon files into a fresh environment, like
-- the game does on each login, and returns a Session.

local ROOT = (debug.getinfo(1, "S").source:match("^@(.*)tests/wow%.lua$") or "") .. "BindPad/"

local M = {}

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = DeepCopy(v)
    end
    return copy
end
M.DeepCopy = DeepCopy

-- Anything the tests don't care about (frames, textures, tooltips...) is this stub:
-- every field is the stub again, and calling it returns the stub.
local stub = {}
setmetatable(stub, {
    __index = function()
        return stub
    end,
    __call = function()
        return stub
    end,
    __newindex = function() end,
    __concat = function(a, b)
        return (a == stub and "" or tostring(a)) .. (b == stub and "" or tostring(b))
    end,
})
M.stub = stub

-- Commands declared in Bindings.xml files. Like the real client, GetBinding() lists only these,
-- never "CLICK ..." bindings.
local DECLARED_COMMANDS = {
    "MOVEFORWARD",
    "MOVEBACKWARD",
    "TURNLEFT",
    "TURNRIGHT",
    "JUMP",
    "TOGGLEGAMEMENU",
    "OPENCHAT",
    "TOGGLEWORLDMAP",
    "ACTIONBUTTON1",
    "ACTIONBUTTON2",
    "ACTIONBUTTON3",
    "ACTIONBUTTON4",
    "TARGETNEARESTENEMY",
    "TOGGLE_BINDPAD",
}

local DEFAULT_BINDINGS = {
    W = "MOVEFORWARD",
    S = "MOVEBACKWARD",
    A = "TURNLEFT",
    D = "TURNRIGHT",
    SPACE = "JUMP",
    ESCAPE = "TOGGLEGAMEMENU",
    ENTER = "OPENCHAT",
    M = "TOGGLEWORLDMAP",
    ["1"] = "ACTIONBUTTON1",
    ["2"] = "ACTIONBUTTON2",
    ["3"] = "ACTIONBUTTON3",
    ["4"] = "ACTIONBUTTON4",
    TAB = "TARGETNEARESTENEMY",
}

local World = {}
World.__index = World

function M.NewWorld()
    return setmetatable({
        saved = nil, -- BindPadVars as written to SavedVariables/BindPad.lua
        accountBindings = DeepCopy(DEFAULT_BINDINGS),
        characterBindings = {}, -- [character id] = bindings, only for characters using the character set
        now = 1700000000,
    }, World)
end

-- character: { name = "Leehman", surname = "Trueshot", ruleset = "PvE", realm = "...", regional = true }
-- regional = true is a WoW Forever style server: no realms, "Firstname Lastname" names.
function M.Character(fields)
    fields.realm = fields.realm or "TestRealm"
    fields.ruleset = fields.ruleset or "PvE"
    fields.id = fields.realm .. "/" .. fields.name .. " " .. (fields.surname or "")
    return fields
end

function World:AdvanceDays(days)
    self.now = self.now + days * 24 * 60 * 60
end

local Session = {}
Session.__index = Session

function World:Login(character)
    local session =
        setmetatable({ world = self, character = character, events = {}, timers = {}, output = {} }, Session)

    -- The binding set the game loads: the character's own one if it has one, else the account one.
    local own = self.characterBindings[character.id]
    session.bindingSet = own and 2 or 1
    session.active = DeepCopy(own or self.accountBindings)

    session.env = self:NewEnvironment(session)
    for _, file in ipairs({ "Localization.lua", "BindPad.lua" }) do
        local chunk = assert(loadfile(ROOT .. file))
        setfenv(chunk, session.env)
        chunk()
    end
    -- SavedVariables are loaded after the addon's files ran, replacing the defaults they set.
    if self.saved then
        session.env.BindPadVars = DeepCopy(self.saved)
    end

    session:Fire("PLAYER_ENTERING_WORLD")
    session:Fire("UPDATE_BINDINGS")
    session:Pump()
    return session
end

function World:NewEnvironment(session)
    local character = session.character
    local world = self
    local env = {}

    -- Bindings -------------------------------------------------------------------------------
    local function KeysFor(action)
        local keys = {}
        for key, bound in pairs(session.active) do
            if bound == action then
                keys[#keys + 1] = key
            end
        end
        table.sort(keys)
        return keys
    end

    function env.SetBinding(key, action)
        session.active[key] = action
        session.events[#session.events + 1] = "UPDATE_BINDINGS"
        return true
    end
    function env.GetBindingKey(action)
        return unpack(KeysFor(action), 1, 2)
    end
    function env.GetBindingAction(key)
        return session.active[key] or ""
    end
    function env.GetNumBindings()
        return #DECLARED_COMMANDS
    end
    function env.GetBinding(i)
        local command = DECLARED_COMMANDS[i]
        local key1, key2 = unpack(KeysFor(command), 1, 2)
        return command, "category", key1, key2
    end
    function env.GetCurrentBindingSet()
        return session.bindingSet
    end
    function env.LoadBindings(set)
        local own = world.characterBindings[character.id]
        session.active = DeepCopy(set == 2 and own or world.accountBindings)
        session.bindingSet = set
        session.events[#session.events + 1] = "UPDATE_BINDINGS"
    end
    function env.SaveBindings(set)
        if set == 1 then
            world.accountBindings = DeepCopy(session.active)
            world.characterBindings[character.id] = nil
        else
            world.characterBindings[character.id] = DeepCopy(session.active)
        end
        session.bindingSet = set
    end
    env.GetBindingText = function(key)
        return key
    end

    -- Character ------------------------------------------------------------------------------
    function env.UnitName(unit)
        if character.regional then
            return character.name, character.surname
        end
        return character.name
    end
    function env.GetRealmName()
        return character.realm
    end
    if character.regional then
        env.RegionalUniqueNamesEnabled = function()
            return true
        end
    else
        env.RegionalUniqueNamesEnabled = function()
            return false
        end
    end
    env.Enum = setmetatable({ GameRule = { PvPRuleset = 1, RPRuleset = 2, HardcoreRuleset = 3 } }, getmetatable(stub))
    env.C_GameRules = {
        IsGameRuleActive = function(rule)
            local r = character.ruleset
            return (rule == 1 and (r == "PvP" or r == "RPPvP"))
                or (rule == 2 and (r == "RP" or r == "RPPvP"))
                or (rule == 3 and r == "HC")
        end,
    }
    env.Constants = { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " " } }
    env.GetSpecialization = function()
        return 1
    end
    env.GetLocale = function()
        return "enUS"
    end
    env.InCombatLockdown = function()
        return false
    end
    env.time = function()
        return world.now
    end
    env.GetTime = function()
        return 0
    end

    -- Timers: run on session:Pump(), like the next frames would.
    local function NewTimer(_, callback)
        local timer = { callback = callback }
        timer.Cancel = function()
            timer.cancelled = true
        end
        session.timers[#session.timers + 1] = timer
        return timer
    end
    env.C_Timer = { NewTicker = NewTimer, NewTimer = NewTimer, After = NewTimer }

    -- Items: every item exists, with a fixed icon.
    env.C_Item = setmetatable({
        GetItemInfo = function(link)
            local name = link:match("%[(.-)%]") or link
            return name, link, 1, 1, 1, "Misc", "Misc", 1, "", 134414
        end,
    }, getmetatable(stub))

    -- The BindPad window stays closed.
    env.BindPadFrame = setmetatable({
        IsShown = function()
            return false
        end,
    }, getmetatable(stub))

    env.ChatFrame1 = {
        AddMessage = function(_, text)
            session.output[#session.output + 1] = text
        end,
    }

    -- Lua extensions and aliases the WoW client provides.
    env.table = setmetatable({
        wipe = function(t)
            for k in pairs(t) do
                t[k] = nil
            end
            return t
        end,
    }, { __index = table })
    env.strfind, env.strsub, env.strlower, env.strupper = string.find, string.sub, string.lower, string.upper
    env.strlen, env.strtrim, env.format, env.gsub = string.len, nil, string.format, string.gsub
    env.strmatch, env.gmatch, env.tinsert, env.tremove = string.match, string.gmatch, table.insert, table.remove
    env.min, env.max, env.floor, env.ceil, env.abs = math.min, math.max, math.floor, math.ceil, math.abs
    env.wipe = env.table.wipe

    -- Real Lua standard library first, then the stub for every other WoW global.
    env._G = env
    return setmetatable(env, {
        __index = function(_, name)
            local std = _G[name]
            if std ~= nil then
                return std
            end
            return stub
        end,
    })
end

-- Session --------------------------------------------------------------------------------------

function Session:Fire(event, ...)
    self.env.BindPadFrame_OnEvent(stub, event, ...)
end

-- Delivers queued events and due timers, until nothing is left.
function Session:Pump()
    for _ = 1, 20 do
        local events, timers = self.events, self.timers
        if #events == 0 and #timers == 0 then
            return
        end
        self.events, self.timers = {}, {}
        local seen = {}
        for _, event in ipairs(events) do
            if not seen[event] then -- the client coalesces repeated events within a frame
                seen[event] = true
                self:Fire(event)
            end
        end
        for _, timer in ipairs(timers) do
            if not timer.cancelled then
                timer.callback()
            end
        end
    end
    error("events kept coming")
end

function Session:Logout()
    self.world.saved = DeepCopy(self.env.BindPadVars)
end

function Session:Vars()
    return self.env.BindPadVars
end

function Session:Core()
    return self.env.BindPadCore
end

-- Tab 1 is General (shared by the account); tabs 2-4 are this character's.
function Session:PlaceSpell(tab, id, name)
    local core = self:Core()
    local slot = core.GetSlotInfoInTab(tab, id, true)
    slot.type = "SPELL"
    slot.name = name
    slot.bookType = "spell"
    slot.texture = 1
    slot.action = "CLICK BindPadKey:SPELL " .. name
    core.UpdateMacroText(slot)
    return slot
end

-- Drops an item from the bags onto a slot, through BindPad's own placement code.
function Session:PlaceItem(tab, id, name)
    self:Vars().tab = tab
    local link = "|cffffffff|Hitem:6948::::::::|h[" .. name .. "]|h|r"
    self:Core().PlaceIntoSlot(id, "item", 6948, link)
    return self:Core().GetSlotInfoInTab(tab, id)
end

-- Switching to a character tab makes BindPad move this character to the character binding set.
function Session:UseCharacterBindings()
    self.env.LoadBindings(2)
    self:Core().SaveBindings(2)
    self:Pump()
end

-- Binds key to a slot like the bind dialog does. forAllCharacters, if given, sets the checkbox first.
function Session:Bind(tab, id, key, forAllCharacters)
    local core = self:Core()
    local slot = core.GetSlotInfoInTab(tab, id)
    assert(slot, "no slot " .. tab .. "/" .. id)
    self:Vars().tab = tab
    if forAllCharacters ~= nil then
        slot.isForAllCharacters = forAllCharacters or nil
    end
    core.selectedSlot = slot
    core.BindKey(slot, key)
    self:Pump()
end

function Session:KeyFor(action)
    return self.env.GetBindingKey(action)
end

function Session:ActionOn(key)
    return self.active[key]
end

function Session:Said(pattern)
    for _, line in ipairs(self.output) do
        if line:find(pattern) then
            return true
        end
    end
    return false
end

return M
