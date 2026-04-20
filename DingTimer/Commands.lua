local _, NS = ...

local ROOT_COMMANDS = {}
local REMOVED_MESSAGE = "Removed in HUD-first build; use /ding settings"

local function parseWords(msg)
  local trimmed = (msg or ""):lower()
  local cmd, arg = trimmed:match("^(%S+)%s*(.*)$")
  return cmd or "", arg or ""
end

local function chat(text)
  NS.chat(NS.C.base .. "[DING]" .. NS.C.r .. " " .. text)
end

local function showHelp()
  NS.chat(NS.C.base .. "=== DingTimer Commands (/ding or /dt) ===" .. NS.C.r)
  NS.chat("  " .. NS.C.val .. "/ding settings" .. NS.C.r .. " - Open the HUD popup")
  NS.chat("  " .. NS.C.val .. "/ding on|off" .. NS.C.r .. " - Toggle chat output")
  NS.chat("  " .. NS.C.val .. "/ding mode full|ttl" .. NS.C.r .. " - Change chat output mode")
  NS.chat("  " .. NS.C.val .. "/ding window <seconds>" .. NS.C.r .. " - Set the rolling window")
  NS.chat("  " .. NS.C.val .. "/ding float on|off|lock|unlock" .. NS.C.r .. " - Manage the HUD")
  NS.chat("  " .. NS.C.val .. "/ding reset" .. NS.C.r .. " - Reset the current session")
  NS.chat("  Advanced dashboard commands from prior versions now redirect to /ding settings.")
end

local function removedCommand()
  chat(REMOVED_MESSAGE)
end

ROOT_COMMANDS[""] = showHelp
ROOT_COMMANDS.help = showHelp

ROOT_COMMANDS.settings = function()
  if NS.OpenSettingsPopup then
    NS.OpenSettingsPopup()
  end
end

ROOT_COMMANDS.on = function()
  if NS.SetChatOutputEnabled then
    NS.SetChatOutputEnabled(true)
  end
  chat("chat output enabled.")
end

ROOT_COMMANDS.off = function()
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
  chat("Unknown float command. Use 'on', 'off', 'lock', or 'unlock'.")
end

ROOT_COMMANDS.reset = function()
  if NS.ResetSession then
    NS.ResetSession("MANUAL_RESET")
  end
end

ROOT_COMMANDS.live = removedCommand
ROOT_COMMANDS.ui = removedCommand
ROOT_COMMANDS.stats = removedCommand
ROOT_COMMANDS.analysis = removedCommand
ROOT_COMMANDS.graph = removedCommand
ROOT_COMMANDS.history = removedCommand
ROOT_COMMANDS.insights = removedCommand
ROOT_COMMANDS.goal = removedCommand
ROOT_COMMANDS.split = removedCommand
ROOT_COMMANDS.recap = removedCommand
ROOT_COMMANDS.pvp = removedCommand

function NS.ExecuteSlashCommand(msg)
  local cmd, arg = parseWords(msg)
  local handler = ROOT_COMMANDS[cmd]
  if handler then
    handler(arg)
    return
  end
  chat("unknown command. Try /ding help")
end
