-- Bindings of character tabs belong to that character only.

local wow = require("wow")

local ACTION = "CLICK BindPadKey:SPELL Hunter's Mark"

local function Hunter()
    return wow.Character({ name = "Hunter" })
end

local function Banker()
    return wow.Character({ name = "Banker" })
end

test("character bindings come back on the next login", function()
    local world = wow.NewWorld()
    local hunter = world:Login(Hunter())
    hunter:UseCharacterBindings()
    hunter:PlaceSpell(2, 1, "Hunter's Mark")
    hunter:Bind(2, 1, "Q")
    hunter:Logout()

    local again = world:Login(Hunter())
    assert_equal(ACTION, again:ActionOn("Q"))
end)

test("character bindings don't show up on another character", function()
    local world = wow.NewWorld()
    local hunter = world:Login(Hunter())
    hunter:UseCharacterBindings()
    hunter:PlaceSpell(2, 1, "Hunter's Mark")
    hunter:Bind(2, 1, "Q")
    hunter:Logout()

    local banker = world:Login(Banker())
    assert_equal(nil, banker:ActionOn("Q"))
end)

-- A character binding that ended up in the account binding set, which every character
-- without its own set loads.
local function WorldWithLeakedBinding()
    local world = wow.NewWorld()
    local hunter = world:Login(Hunter())
    hunter:PlaceSpell(2, 1, "Hunter's Mark")
    hunter:Bind(2, 1, "Q")
    hunter:Logout()
    assert_equal(ACTION, world.accountBindings.Q, "setup: binding should be in the account set")
    return world
end

test("another character's binding left in the account set is removed", function()
    local world = WorldWithLeakedBinding()
    local banker = world:Login(Banker())
    assert_equal(nil, banker:ActionOn("Q"))
    assert(banker:Said("Removed 1 key binding"), "no notice about the removal")
    banker:Logout()
    assert_equal(nil, world.saved["PROFILE_TestRealm_Banker"][1].AllKeyBindings.Q)
    assert_equal(nil, world.accountBindings.Q)
end)

test("the leftover cleanup keeps the character's own binding of the same action", function()
    local world = WorldWithLeakedBinding()
    local banker = world:Login(Banker())
    banker:PlaceSpell(2, 1, "Hunter's Mark")
    banker:Bind(2, 1, "Q")
    banker:Logout()

    local again = world:Login(Banker())
    assert_equal(ACTION, again:ActionOn("Q"))
end)

test("the leftover cleanup leaves general bindings alone", function()
    local world = WorldWithLeakedBinding()
    local banker = world:Login(Banker())
    banker:PlaceSpell(1, 1, "Fireball")
    banker:Bind(1, 1, "F1", true)
    banker:Logout()

    local hunter = world:Login(Hunter())
    assert_equal("CLICK BindPadKey:SPELL Fireball", hunter:ActionOn("F1"))
    assert_equal(ACTION, hunter:ActionOn("Q"))
end)

test("the leftover notice is shown only once", function()
    local world = WorldWithLeakedBinding()
    world:Login(Banker()):Logout()
    local again = world:Login(Banker())
    assert_equal(0, #again.output)
end)

test("a character without leftovers gets no notice", function()
    local world = wow.NewWorld()
    local hunter = world:Login(Hunter())
    hunter:UseCharacterBindings()
    hunter:PlaceSpell(2, 1, "Hunter's Mark")
    hunter:Bind(2, 1, "Q")
    hunter:Logout()
    local banker = world:Login(Banker())
    assert_equal(0, #banker.output)
end)
