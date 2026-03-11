require("tests.mocks")

local NS = {}
LoadAddonFile("DingTimer/Util.lua", "DingTimer", NS)
LoadAddonFile("DingTimer/UI_XPGraphWindow.lua", "DingTimer", NS)

assert_near(NS.ResolveGraphScaleForTest("visible", 80000, 60000, 140000, 100000), 89600, 0.001, "visible scale should fit the visible peak with headroom")
assert_near(NS.ResolveGraphScaleForTest("session", 80000, 60000, 140000, 100000), 156800, 0.001, "session scale should fit retained history with headroom")
assert_eq(NS.ResolveGraphScaleForTest("fixed", 80000, 60000, 140000, 100000), 100000, "fixed scale should preserve the configured cap")
assert_near(NS.ResolveGraphScaleForTest("auto", 50000, 40000, 100000, 75000), 56000, 0.001, "legacy auto alias should behave like visible scale")

print("Graph scale mode test passed!")
