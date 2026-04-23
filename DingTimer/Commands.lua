local _, NS = ...

local ROOT_COMMANDS = {}
local REMOVED_MESSAGE = "Removed in HUD-first build; use /ding settings"
local REMOVED_COMMANDS = {
  live = true,
  ui = true,
  stats = true,
  analysis = true,
  graph = true,
  history = true,
  insights = true,
  goal = true,
  split = true,
  recap = true,
  pvp = true,
}

local function parseWords(msg)
  local trimmed = (msg or ""):lower():match("^%s*(.-)%s*$")
  local cmd, arg = trimmed:match("^(%S+)%s*(.*)$")
  return cmd or "", arg or ""
end

local function chat(text)
  NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " " .. text)
end

local function showHelp(_arg)
  NS.chat(NS.C.base .. "=== DingTimer Commands (/ding or /dt) ===" .. NS.C.r)
  NS.chat("  " .. NS.C.val .. "/ding settings" .. NS.C.r .. " - Open the HUD popup")
  NS.chat("  " .. NS.C.val .. "/ding on|off" .. NS.C.r .. " - Toggle chat output")
  NS.chat("  " .. NS.C.val .. "/ding mode full|ttl" .. NS.C.r .. " - Change chat output mode")
  NS.chat("  " .. NS.C.val .. "/ding window <seconds>" .. NS.C.r .. " - Set the rolling window")
  NS.chat("  " .. NS.C.val .. "/ding float on|off|lock|unlock|reset" .. NS.C.r .. " - Manage the HUD")
  NS.chat("  " .. NS.C.val .. "/ding reset" .. NS.C.r .. " - Reset the current session")
  NS.chat("  Advanced dashboard commands from prior versions now redirect to /ding settings.")
end

local function removedCommand(_arg)
  chat(REMOVED_MESSAGE)
end

local function resolveRootCommand(cmd)
  if REMOVED_COMMANDS[cmd] then
    return removedCommand
  end
  return ROOT_COMMANDS[cmd]
end

ROOT_COMMANDS[""] = showHelp
ROOT_COMMANDS.help = showHelp

ROOT_COMMANDS.settings = function(_arg)
  if NS.OpenSettingsPopup then
    NS.OpenSettingsPopup()
  end
end

ROOT_COMMANDS.on = function(_arg)
  if NS.SetChatOutputEnabled then
    NS.SetChatOutputEnabled(true)
  end
  chat("chat output enabled.")
end

ROOT_COMMANDS.off = function(_arg)
  if NS.SetChatOutputEnabled then
    NS.SetChatOutputEnabled(false)
  end
  chat("chat output disabled.")
end

ROOT_COMMANDS.mode = function(arg)
  if NS.SetOutputMode then
    local ok, result = NS.SetOutputMode(arg)
    if not ok then
      chat(result)
      return
    end
    chat("mode = " .. result)
    return
  end
  chat("mode controls are unavailable.")
end

ROOT_COMMANDS.window = function(arg)
  local n = tonumber(arg)
  if not n then
    chat("Please provide a number (e.g., /ding window 600).")
    return
  end
  if NS.SetRollingWindowSeconds and NS.SetRollingWindowSeconds(n) then
    chat("windowSeconds = " .. math.floor(n))
  else
    chat("window must be between 30 and 86400 seconds (24h).")
  end
end

ROOT_COMMANDS.float = function(arg)
  if arg == "on" or arg == "off" then
    if NS.SetFloatEnabled then
      NS.SetFloatEnabled(arg == "on")
    end
    chat("float = " .. arg)
    return
  end
  if arg == "lock" or arg == "unlock" then
    if NS.SetFloatLocked then
      NS.SetFloatLocked(arg == "lock")
    end
    chat("floatLocked = " .. arg)
    return
  end
  if arg == "reset" then
    if NS.ResetFloatHUD then
      NS.ResetFloatHUD()
    end
    chat("float reset to center and enabled.")
    return
  end
  chat("Unknown float command. Use 'on', 'off', 'lock', 'unlock', or 'reset'.")
end

ROOT_COMMANDS.reset = function(_arg)
  if NS.ResetSession then
    NS.ResetSession("MANUAL_RESET")
  end
end

function NS.ExecuteSlashCommand(msg)
  local cmd, arg = parseWords(msg)
  local handler = resolveRootCommand(cmd)
  if handler then
    handler(arg)
    return
  end
  chat("unknown command. Try /ding help")
end
