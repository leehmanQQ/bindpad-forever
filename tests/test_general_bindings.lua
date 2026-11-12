-- General tab slots marked "for all characters" share their key binding with every character.

local wow = require("wow")

local ACTION = "CLICK BindPadKey:SPELL Fireball"

-- Bob binds a General slot for all characters. He uses his own binding set, so the account
-- binding set (what a new character starts with) doesn't hold the binding: only BindPad can carry it.
local function WorldWithGeneralBinding(key)
    local world = wow.NewWorld()
    local bob = world:Login(wow.Character({ name = "Bob" }))
    bob:UseCharacterBindings()
    bob:PlaceSpell(1, 1, "Fireball")
    bob:Bind(1, 1, key or "F1", true)
    bob:Logout()
    assert_equal(nil, world.accountBindings[key or "F1"], "account binding set should not hold the binding")
    return world
end

test("a general binding reaches a new character", function()
    local world = WorldWithGeneralBinding()
    local alice = world:Login(wow.Character({ name = "Alice" }))
    assert_equal(ACTION, alice:ActionOn("F1"))
end)

test("a character whose binding set lacks a general binding doesn't erase it", function()
    local world = WorldWithGeneralBinding()
    local alice = world:Login(wow.Character({ name = "Alice" }))
    alice:Fire("UPDATE_BINDINGS")
    alice:Logout()
    assert_equal(ACTION, world.saved.GeneralKeyBindings.F1)

    local carol = world:Login(wow.Character({ name = "Carol" }))
    assert_equal(ACTION, carol:ActionOn("F1"))
end)

test("rebinding a general slot moves the shared key", function()
    local world = WorldWithGeneralBinding()
    local bob = world:Login(wow.Character({ name = "Bob" }))
    bob:Bind(1, 1, "F2", true)
    bob:Logout()
    assert_equal(nil, world.saved.GeneralKeyBindings.F1)
    assert_equal(ACTION, world.saved.GeneralKeyBindings.F2)

    local alice = world:Login(wow.Character({ name = "Alice" }))
    assert_equal(ACTION, alice:ActionOn("F2"))
end)

test("unmarking 'for all characters' stops sharing the binding", function()
    local world = WorldWithGeneralBinding()
    local bob = world:Login(wow.Character({ name = "Bob" }))
    local slot = bob:Core().GetSlotInfoInTab(1, 1)
    bob:Core().selectedSlot = slot
    bob.env.BindPadFrame_ForAllCharactersToggle({
        GetChecked = function()
            return false
        end,
    })
    bob:Pump()
    bob:Logout()
    assert_equal(nil, next(world.saved.GeneralKeyBindings))
end)

test("unbinding a general slot stops sharing the binding", function()
    local world = WorldWithGeneralBinding()
    local bob = world:Login(wow.Character({ name = "Bob" }))
    local slot = bob:Core().GetSlotInfoInTab(1, 1)
    bob:Core().selectedSlot = slot
    bob:Core().UnbindSlot(slot)
    bob:Pump()
    bob:Logout()
    assert_equal(nil, next(world.saved.GeneralKeyBindings))
end)

-- Saved variables written by 1.3, after its bug wiped GeneralKeyBindings. The account binding set
-- doesn't hold the binding either, so only the keys in the character profiles can bring it back.
local function WorldAfterWipe()
    local world = WorldWithGeneralBinding()
    world:Login(wow.Character({ name = "Alice" })):Logout()
    world:Login(wow.Character({ name = "Dave" })):Logout()
    world.saved.version = 1.3
    world.saved.GeneralKeyBindings = {}
    world.accountBindings.F1 = nil
    return world
end

test("upgrading restores general bindings lost to the 1.3 bug", function()
    local world = WorldAfterWipe()
    local carol = world:Login(wow.Character({ name = "Carol" }))
    assert_equal(ACTION, carol:Vars().GeneralKeyBindings.F1)
    assert_equal(ACTION, carol:ActionOn("F1"))
    assert(carol:Said("Restored 1 "), "no notice about the restore")
end)

test("restoring picks the key most profiles agree on", function()
    local world = WorldAfterWipe()
    -- One profile remembers an older key.
    local bobProfile = world.saved["PROFILE_TestRealm_Bob"][1].AllKeyBindings
    bobProfile.F1 = nil
    bobProfile.F9 = ACTION

    local carol = world:Login(wow.Character({ name = "Carol" }))
    carol:Logout()
    local general = world.saved.GeneralKeyBindings
    -- Alice's and Dave's profiles say F1, Bob's F9.
    assert_equal(ACTION, general.F1)
    assert_equal(nil, general.F9)
end)

test("the restore runs only once", function()
    local world = WorldAfterWipe()
    world.saved.version = 1.4
    local carol = world:Login(wow.Character({ name = "Carol" }))
    assert_equal(nil, next(carol:Vars().GeneralKeyBindings))
end)

test("upgrading without lost general bindings shows no notice", function()
    local world = WorldWithGeneralBinding()
    world.saved.version = 1.3
    local alice = world:Login(wow.Character({ name = "Alice" }))
    assert_equal(ACTION, alice:ActionOn("F1"))
    assert_equal(0, #alice.output)
end)

local HEARTHSTONE = "CLICK BindPadKey:ITEM Hearthstone"

test("a new General slot shares its key with all characters by default", function()
    local world = wow.NewWorld()
    local bob = world:Login(wow.Character({ name = "Bob" }))
    bob:UseCharacterBindings()
    local slot = bob:PlaceItem(1, 1, "Hearthstone")
    assert_equal(true, slot.isForAllCharacters)
    bob:Bind(1, 1, "H")
    bob:Logout()

    local alice = world:Login(wow.Character({ name = "Alice" }))
    assert_equal(HEARTHSTONE, alice:ActionOn("H"))
end)

test("a General slot can opt out of sharing its key", function()
    local world = wow.NewWorld()
    local bob = world:Login(wow.Character({ name = "Bob" }))
    bob:UseCharacterBindings()
    bob:PlaceItem(1, 1, "Hearthstone")
    bob:Bind(1, 1, "H", false)
    bob:Logout()

    local alice = world:Login(wow.Character({ name = "Alice" }))
    assert_equal(nil, alice:ActionOn("H"))
end)

test("a character tab slot doesn't share its key", function()
    local session = wow.NewWorld():Login(wow.Character({ name = "Bob" }))
    local slot = session:PlaceItem(2, 1, "Hearthstone")
    assert_equal(nil, slot.isForAllCharacters)
end)

test("existing General slots keep their per-character key", function()
    local world = wow.NewWorld()
    local bob = world:Login(wow.Character({ name = "Bob" }))
    bob:UseCharacterBindings()
    bob:PlaceSpell(1, 1, "Fireball") -- a slot saved by an older version: no flag
    bob:Bind(1, 1, "F1")
    bob:Logout()

    local alice = world:Login(wow.Character({ name = "Alice" }))
    assert_equal(nil, alice:ActionOn("F1"))
    assert_equal(nil, alice:Core().GetSlotInfoInTab(1, 1).isForAllCharacters)
end)
