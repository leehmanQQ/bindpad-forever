-- Runs BindPad's tests: `lua5.1 tests/run.lua` or `luajit tests/run.lua` from the repository root.
-- No dependencies. Exits with status 1 if any test fails.

local DIR = debug.getinfo(1, "S").source:match("^@(.*)run%.lua$") or "./"
package.path = DIR .. "?.lua;" .. package.path

local FILES = {
    "test_character_profiles",
    "test_general_bindings",
    "test_character_bindings",
}

local tests = {}
function test(name, fn)
    tests[#tests + 1] = { name = name, fn = fn }
end

local function Describe(value)
    if type(value) == "string" then
        return string.format("%q", value)
    end
    return tostring(value)
end

function assert_equal(expected, actual, message)
    if expected ~= actual then
        error(
            string.format(
                "%sexpected %s, got %s",
                message and (message .. ": ") or "",
                Describe(expected),
                Describe(actual)
            ),
            2
        )
    end
end

local passed, failed = 0, 0
for _, file in ipairs(FILES) do
    tests = {}
    require(file)
    print(file)
    for _, t in ipairs(tests) do
        local ok, err = xpcall(t.fn, debug.traceback)
        if ok then
            passed = passed + 1
            print("  ok    " .. t.name)
        else
            failed = failed + 1
            print("  FAIL  " .. t.name .. "\n" .. err:gsub("\n", "\n        "))
        end
    end
end

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
