-- WoW API Mocks
local currentTime = 0
local playerXP = 0
local playerMaxXP = 1000
local playerMoney = 0
local playerLevel = 1
local playerName = "TestPlayer"
local playerRealm = "TestRealm"
local playerClassLocalized = "Mage"
local playerClassToken = "MAGE"
local currentZone = "Unknown"
local currentHonor = 0
local maxHonor = 75000
local lifetimeHKs = 0
local inInstance = false
local instanceType = nil
local honorApiFlavor = "legacy"
local HONOR_CURRENCY_ID = 1792

function GetTime()
  return currentTime
end

function SetTime(t)
  currentTime = t
end

function UnitXP(unit)
  if unit == "player" then return playerXP end
end

function UnitXPMax(unit)
  if unit == "player" then return playerMaxXP end
end

function SetXP(xp, max)
  playerXP = xp
  if max then playerMaxXP = max end
end

function GetMoney()
  return playerMoney
end

function SetMoney(m)
  playerMoney = m
end

function UnitLevel(unit)
  if unit == "player" then return playerLevel end
end

function SetLevel(level)
  playerLevel = level
end

function UnitName(unit)
  if unit == "player" then
    return playerName, playerRealm
  end
end

function GetRealmName()
  return playerRealm
end

function UnitClass(unit)
  if unit == "player" then
    return playerClassLocalized, playerClassToken
  end
end

function GetZoneText()
  return currentZone
end

function SetZone(zone)
  currentZone = zone
end

function GetHonorCurrency()
  if honorApiFlavor == "legacy" then
    return currentHonor
  end
end

function GetMaxHonorCurrency()
  if honorApiFlavor == "legacy" then
    return maxHonor
  end
end

function SetHonor(honor, cap)
  currentHonor = honor
  if cap then
    maxHonor = cap
  end
end

function SetHonorApiFlavor(flavor)
  honorApiFlavor = flavor or "legacy"
end

function GetPVPLifetimeStats()
  return lifetimeHKs, 0, 0
end

function GetLifetimeHonorableKills()
  return lifetimeHKs
end

function SetLifetimeHKs(count)
  lifetimeHKs = count
end

function IsInInstance()
  return inInstance, instanceType
end

function SetInstanceState(isInside, kind)
  inInstance = isInside and true or false
  instanceType = kind
end

function SetProfileIdentity(name, realm, classToken, level, classLocalized)
  if name then playerName = name end
  if realm then playerRealm = realm end
  if classToken then playerClassToken = classToken end
  if classLocalized then playerClassLocalized = classLocalized end
  if level then playerLevel = level end
end

function InCombatLockdown()
  return false
end

DEFAULT_CHAT_LOG = {}
DEFAULT_CHAT_FRAME = {
  AddMessage = function(_, msg)
    table.insert(DEFAULT_CHAT_LOG, msg)
  end
}

function ClearChatLog()
  DEFAULT_CHAT_LOG = {}
end

function GetChatLog()
  return DEFAULT_CHAT_LOG
end

local function newFontString()
  local fs = { _text = "", _shown = true, _point = { "CENTER", nil, "CENTER", 0, 0 } }
  fs.SetPoint = function(self, point, relativeTo, relativePoint, xOfs, yOfs)
    self._point = { point, relativeTo, relativePoint, xOfs or 0, yOfs or 0 }
  end
  fs.GetPoint = function(self)
    return self._point[1], self._point[2], self._point[3], self._point[4], self._point[5]
  end
  fs.ClearAllPoints = function(self)
    self._point = { "CENTER", nil, "CENTER", 0, 0 }
  end
  fs.SetJustifyH = function() end
  fs.SetJustifyV = function() end
  fs.SetTextColor = function() end
  fs.SetFontObject = function() end
  fs.SetText = function(self, text) self._text = text end
  fs.GetText = function(self) return self._text end
  fs.GetStringWidth = function(self) return #(self._text or "") * 6 end
  fs.SetWidth = function() end
  fs.Show = function(self) self._shown = true end
  fs.Hide = function(self) self._shown = false end
  fs.SetShown = function(self, shown) self._shown = shown end
  return fs
end

local function newTexture()
  local tx = {}
  tx.SetTexture = function() end
  tx.SetSize = function() end
  tx.SetPoint = function() end
  tx.ClearAllPoints = function() end
  tx.SetAllPoints = function() end
  tx.SetColorTexture = function() end
  tx.SetVertexColor = function() end
  tx.SetAlpha = function() end
  tx.SetHeight = function() end
  tx.SetWidth = function() end
  tx.SetTexCoord = function() end
  tx.Hide = function() end
  tx.Show = function() end
  return tx
end

local function newLine()
  local ln = {}
  ln.SetStartPoint = function() end
  ln.SetEndPoint = function() end
  ln.SetColorTexture = function() end
  ln.SetThickness = function() end
  ln.Hide = function() end
  ln.Show = function() end
  return ln
end

local function newFrame(name)
  local frame = {
    _name = name,
    _shown = false,
    _scripts = {},
    _width = 320,
    _height = 240,
    _text = "",
    _point = { "CENTER", nil, "CENTER", 0, 0 },
  }

  frame.GetName = function(self) return self._name end
  frame.SetSize = function(self, w, h) self._width = w; self._height = h end
  frame.SetWidth = function(self, w) self._width = w end
  frame.SetHeight = function(self, h) self._height = h end
  frame.GetWidth = function(self) return self._width end
  frame.GetHeight = function(self) return self._height end
  frame.SetPoint = function(self, point, relativeTo, relativePoint, xOfs, yOfs)
    self._point = { point, relativeTo, relativePoint, xOfs or 0, yOfs or 0 }
  end
  frame.GetPoint = function(self)
    return self._point[1], self._point[2], self._point[3], self._point[4], self._point[5]
  end
  frame.ClearAllPoints = function(self)
    self._point = { "CENTER", nil, "CENTER", 0, 0 }
  end
  frame.SetAllPoints = function() end
  frame.LockHighlight = function() end
  frame.UnlockHighlight = function() end
  frame.SetMovable = function() end
  frame.SetResizable = function() end
  frame.SetMinResize = function() end
  frame.SetMaxResize = function() end
  frame.SetResizeBounds = function() end
  frame.EnableMouse = function() end
  frame.RegisterForDrag = function() end
  frame.RegisterForClicks = function() end
  frame.SetFrameStrata = function() end
  frame.SetFrameLevel = function() end
  frame.SetHighlightTexture = function() end
  frame.SetBackdrop = function() end
  frame.SetBackdropColor = function() end
  frame.SetBackdropBorderColor = function() end
  frame.SetClampedToScreen = function() end
  frame.SetHitRectInsets = function() end
  frame.RegisterEvent = function() end
  frame.SetChecked = function(self, checked) self._checked = checked and true or false end
  frame.GetChecked = function(self) return self._checked end
  frame.SetAutoFocus = function() end
  frame.SetNumeric = function() end
  frame.SetMaxLetters = function() end
  frame.SetNormalTexture = function() end
  frame.SetPushedTextOffset = function() end
  frame.SetNormalFontObject = function() end
  frame.SetHighlightFontObject = function() end
  frame.SetDisabledFontObject = function() end
  frame.StartSizing = function() end
  frame.SetText = function(self, text) self._text = text end
  frame.GetText = function(self) return self._text end
  frame.StartMoving = function() end
  frame.StopMovingOrSizing = function() end
  frame.SetScrollChild = function() end
  frame.SetScript = function(self, scriptName, fn)
    self._scripts[scriptName] = fn
  end
  frame.GetScript = function(self, scriptName)
    return self._scripts[scriptName]
  end
  frame.Show = function(self)
    self._shown = true
    local fn = self._scripts["OnShow"]
    if fn then fn(self) end
  end
  frame.Hide = function(self)
    self._shown = false
    local fn = self._scripts["OnHide"]
    if fn then fn(self) end
  end
  frame.IsShown = function(self)
    return self._shown
  end
  frame.CreateFontString = function() return newFontString() end
  frame.CreateTexture = function() return newTexture() end
  frame.CreateLine = function() return newLine() end
  return frame
end

function CreateFrame(_, name)
  local frame = newFrame(name)
  if type(name) == "string" and name ~= "" then
    _G[name] = frame
  end
  return frame
end

UIParent = newFrame("UIParent")
Minimap = newFrame("Minimap")
Minimap.GetCenter = function() return 0, 0 end
Minimap.GetEffectiveScale = function() return 1 end

function GetCursorPosition()
  return 0, 0
end

function GetMinimapShape()
  return "ROUND"
end

C_Timer = {
  NewTicker = function(_, _interval)
    return {
      Cancel = function() end
    }
  end,
  NewTimer = function(_, callback)
    return {
      Cancel = function() end,
      Fire = function(_self)
        if callback then callback() end
      end
    }
  end
}

C_CurrencyInfo = {
  GetCurrencyInfo = function(currencyId)
    if honorApiFlavor == "retail" and tonumber(currencyId) == HONOR_CURRENCY_ID then
      return {
        quantity = currentHonor,
        maxQuantity = maxHonor,
        name = "Honor",
      }
    end
    return nil
  end
}

GameTooltip = {
  SetOwner = function() end,
  SetText = function() end,
  AddLine = function() end,
  AddDoubleLine = function() end,
  ClearLines = function() end,
  Show = function() end,
  Hide = function() end,
}

function RegisterStateDriver() end
function UnregisterStateDriver() end

SlashCmdList = {}
UISpecialFrames = {}
tinsert = table.insert

-- Addon Loading Mock
-- Supported forms:
--   LoadAddonFile(path)
--   LoadAddonFile(path, NS)
--   LoadAddonFile(path, addonName, NS)
function LoadAddonFile(path, addonOrNS, maybeNS)
  local addonName = "DingTimer"
  local NS = nil

  if type(addonOrNS) == "table" then
    NS = addonOrNS
  elseif type(addonOrNS) == "string" and type(maybeNS) == "table" then
    addonName = addonOrNS
    NS = maybeNS
  elseif type(addonOrNS) == "string" and maybeNS == nil then
    addonName = addonOrNS
  end

  if not NS then
    if not _G.NS then _G.NS = {} end
    NS = _G.NS
  end

  local f, err = loadfile(path)
  if not f then error(err) end
  f(addonName, NS)
  return NS
end

-- assert_eq/assert_near for Core tests
function assert_eq(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s",
      message or "Assertion failed", tostring(expected), tostring(actual)), 2)
  end
end

function assert_true(value, message)
  if not value then
    error(message or "Assertion failed: expected true", 2)
  end
end

function assert_false(value, message)
  if value then
    error(message or "Assertion failed: expected false", 2)
  end
end

function assert_near(actual, expected, tolerance, message)
  if math.abs(actual - expected) > (tolerance or 0.001) then
    error(string.format("%s: expected ~%s, got %s",
      message or "Assertion failed", tostring(expected), tostring(actual)), 2)
  end
end

-- Test runner framework (it / assert_equal / run_tests)
local _tests = {}
local _passed = 0
local _failed = 0

function it(name, func)
  table.insert(_tests, { name = name, func = func })
end

function assert_equal(expected, actual, msg)
  if expected ~= actual then
    error(string.format("Expected '%s', got '%s'%s",
      tostring(expected), tostring(actual),
      msg and (" - " .. msg) or ""), 2)
  end
end

-- Compatibility aliases used by older test files
function assertEqual(expected, actual, msg)
  assert_equal(expected, actual, msg)
end

function assertStringMatch(needle, haystack, msg)
  local ok = type(haystack) == "string" and string.find(haystack, needle, 1, true) ~= nil
  if not ok then
    error(string.format("Expected '%s' to contain '%s'%s",
      tostring(haystack), tostring(needle),
      msg and (" - " .. msg) or ""), 2)
  end
end

function run_tests()
  print("Running tests...")
  for _, test in ipairs(_tests) do
    local status, err = pcall(test.func)
    if status then
      _passed = _passed + 1
      print("  [PASS] " .. test.name)
    else
      _failed = _failed + 1
      print("  [FAIL] " .. test.name)
      print("         " .. tostring(err))
    end
  end
  print(string.format("\nResults: %d passed, %d failed", _passed, _failed))
  if _failed > 0 then os.exit(1) end
end
