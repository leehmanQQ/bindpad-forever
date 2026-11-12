-- Which profile a character uses, and the move from shared first-name profiles on WoW Forever.

local wow = require("wow")

local function Forever(surname, ruleset)
    return wow.Character({
        name = "Leehman",
        surname = surname,
        ruleset = ruleset,
        realm = "CAMWOW EU5 Realm 7 PvE",
        regional = true,
    })
end

local LEGACY = "PROFILE_CAMWOW EU5 Realm 7 PvE_Leehman"

-- Saved variables from before 1.4, where every "Leehman ..." character shared one profile.
local function WorldWithLegacyProfile()
    local world = wow.NewWorld()
    local old = world:Login(wow.Character({ name = "Leehman", realm = "CAMWOW EU5 Realm 7 PvE" }))
    old:PlaceSpell(2, 1, "Hunter's Mark")
    old:Logout()
    world.saved.version = 1.3
    assert(world.saved[LEGACY], "legacy profile was not created")
    return world
end

test("realm servers keep the PROFILE_<realm>_<name> key", function()
    local session = wow.NewWorld():Login(wow.Character({ name = "Bob", realm = "Blackrock" }))
    assert_equal("PROFILE_Blackrock_Bob", session:Core().character)
end)

test("regional servers key profiles by ruleset and full name", function()
    local session = wow.NewWorld():Login(Forever("Trueshot"))
    assert_equal("PROFILE_PvE_Leehman Trueshot", session:Core().character)
end)

test("each ruleset gets its own profile", function()
    for ruleset, expected in pairs({ PvP = "PvP", RP = "RP", RPPvP = "RPPvP", HC = "HC" }) do
        local session = wow.NewWorld():Login(Forever("Trueshot", ruleset))
        assert_equal("PROFILE_" .. expected .. "_Leehman Trueshot", session:Core().character)
    end
end)

test("characters sharing a first name don't share character tabs", function()
    local world = wow.NewWorld()
    local hunter = world:Login(Forever("Trueshot"))
    hunter:PlaceSpell(2, 1, "Hunter's Mark")
    hunter:Logout()

    local bank = world:Login(Forever("Bank"))
    assert_equal(nil, bank:Core().GetSlotInfoInTab(2, 1))
end)

test("a shared pre-1.4 profile is copied to each character", function()
    local world = WorldWithLegacyProfile()
    for _, surname in ipairs({ "Trueshot", "Bank" }) do
        local session = world:Login(Forever(surname))
        local slot = session:Core().GetSlotInfoInTab(2, 1)
        assert(slot, surname .. " did not get a copy")
        assert_equal("Hunter's Mark", slot.name)
        assert(session:Said("first name Leehman"), surname .. " was not told about the copy")
        session:Logout()
    end
    assert(world.saved[LEGACY], "legacy profile was deleted too early")
end)

test("copies of a shared profile are independent", function()
    local world = WorldWithLegacyProfile()
    local hunter = world:Login(Forever("Trueshot"))
    hunter:Logout()
    local bank = world:Login(Forever("Bank"))
    bank:Core().GetSlotInfoInTab(2, 1, true).name = "Changed"
    bank:Logout()

    assert_equal("Hunter's Mark", world.saved["PROFILE_PvE_Leehman Trueshot"][1].CharacterSpecificTab1[1].name)
end)

test("a character is copied the shared profile only once", function()
    local world = WorldWithLegacyProfile()
    local first = world:Login(Forever("Trueshot"))
    first:Core().GetSlotInfoInTab(2, 1).name = "Kept"
    first:Logout()

    local again = world:Login(Forever("Trueshot"))
    assert_equal("Kept", again:Core().GetSlotInfoInTab(2, 1).name)
    assert(not again:Said("first name"), "told about the copy twice")
end)

test("the shared profile is retired after 30 days", function()
    local world = WorldWithLegacyProfile()
    world:Login(Forever("Trueshot")):Logout()

    world:AdvanceDays(29)
    local bank = world:Login(Forever("Bank"))
    assert(bank:Core().GetSlotInfoInTab(2, 1), "copy refused before 30 days")
    bank:Logout()

    world:AdvanceDays(2)
    local newcomer = world:Login(Forever("Newcomer"))
    assert_equal(nil, newcomer:Core().GetSlotInfoInTab(2, 1))
    newcomer:Logout()
    assert_equal(nil, world.saved[LEGACY])
    assert(world.saved["PROFILE_PvE_Leehman Trueshot"], "a migrated profile was deleted")
end)

test("/bp copyfrom takes the new profile names", function()
    local world = wow.NewWorld()
    local hunter = world:Login(Forever("Trueshot"))
    hunter:PlaceSpell(2, 1, "Hunter's Mark")
    hunter:Logout()

    local bank = world:Login(Forever("Bank"))
    bank.env.BindPad_SlashCmd("copyfrom PvE_Leehman Trueshot")
    assert_equal("Hunter's Mark", bank:Core().GetSlotInfoInTab(2, 1).name)
    assert_equal("PROFILE_PvE_Leehman Bank", bank:Core().character)
end)

test("the copy notice says how long other characters have left", function()
    local world = WorldWithLegacyProfile()
    world:Login(Forever("Trueshot")):Logout()
    world:AdvanceDays(10)
    local bank = world:Login(Forever("Bank"))
    assert(bank:Said("within 20 days"), "wrong or missing days left")
end)

test("characters that never shared a profile get no notice", function()
    local world = wow.NewWorld()
    local hunter = world:Login(Forever("Trueshot"))
    assert_equal(0, #hunter.output)
    hunter:Logout()
    local realm = world:Login(wow.Character({ name = "Bob", realm = "Blackrock" }))
    assert_equal(0, #realm.output)
end)

test("upgrading on a realm server leaves the profile alone, without a notice", function()
    local world = wow.NewWorld()
    local bob = world:Login(wow.Character({ name = "Bob", realm = "Blackrock" }))
    bob:PlaceSpell(2, 1, "Fireball")
    bob:Logout()
    world.saved.version = 1.3

    local again = world:Login(wow.Character({ name = "Bob", realm = "Blackrock" }))
    assert_equal("Fireball", again:Core().GetSlotInfoInTab(2, 1).name)
    assert_equal(0, #again.output)
end)
