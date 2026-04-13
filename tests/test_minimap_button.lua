dofile("tests/mocks.lua")

-- Create a private namespace for the addon
local NS = { C = { base = "", r = "" } }
-- Mock the database
DingTimerDB = { minimapAngle = 45, minimapHidden = false }

-- Load the minimap button module
LoadAddonFile("DingTimer/UI_MinimapButton.lua", NS)

it("should hide the button when minimapHidden is true", function()
    DingTimerDB.minimapHidden = true
    NS.InitMinimapButton()
    assert_false(DingTimerMinimapButton:IsShown(), "Button should be hidden")
end)

it("should show the button when minimapHidden is false", function()
    DingTimerDB.minimapHidden = false
    NS.InitMinimapButton()
    assert_true(DingTimerMinimapButton:IsShown(), "Button should be shown")
end)

it("should position the button correctly based on angle", function()
    -- Set a known angle: 0 degrees (pointing right)
    DingTimerDB.minimapHidden = false
    DingTimerDB.minimapAngle = 0

    -- In UpdatePosition():
    -- local angle = math.rad(0) = 0
    -- local x = math.cos(0) = 1
    -- local y = math.sin(0) = 0
    -- local radius = (Minimap:GetWidth() / 2) + 5
    -- Minimap width in mocks is 320, so radius = (320 / 2) + 5 = 165

    NS.InitMinimapButton()

    local point, relativeTo, relativePoint, xOfs, yOfs = DingTimerMinimapButton:GetPoint()
    assert_equal("CENTER", point)
    assert_equal(Minimap, relativeTo)
    assert_equal("CENTER", relativePoint)
    assert_near(165, xOfs, 0.1, "X offset should be 165")
    assert_near(0, yOfs, 0.1, "Y offset should be 0")
end)

run_tests()
