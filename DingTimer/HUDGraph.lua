local _, NS = ...

local math_floor = math.floor
local math_max = math.max
local math_sqrt = math.sqrt

local HUDGraph = NS.HUDGraph or {}
NS.HUDGraph = HUDGraph

local function normalizeWindowSeconds(windowSeconds)
  local value = tonumber(windowSeconds) or 1
  if value <= 0 then
    return 1
  end
  return value
end

local function normalizeBucketCount(bucketCount)
  local value = math_floor(tonumber(bucketCount) or 18)
  if value < 1 then
    return 18
  end
  return value
end

function HUDGraph.BuildBuckets(events, now, windowSeconds, bucketCount)
  local buckets = {}
  local peak = 0
  now = tonumber(now) or 0
  windowSeconds = normalizeWindowSeconds(windowSeconds)
  bucketCount = normalizeBucketCount(bucketCount)
  local bucketSeconds = windowSeconds / bucketCount

  for i = 1, bucketCount do
    buckets[i] = 0
  end

  for i = 1, #(events or {}) do
    local event = events[i]
    local eventTime = tonumber(event and event.t)
    local amount = tonumber(event and event.xp)
    local age = eventTime and (now - eventTime) or nil
    if amount and amount > 0 and age and age >= 0 and age <= windowSeconds then
      local index = bucketCount - math_floor(age / bucketSeconds)
      if index < 1 then
        index = 1
      elseif index > bucketCount then
        index = bucketCount
      end
      buckets[index] = buckets[index] + amount
      if buckets[index] > peak then
        peak = buckets[index]
      end
    end
  end

  return buckets, peak
end

function HUDGraph.FormatBucketRange(data)
  local bucketCount = normalizeBucketCount(data and data.count)
  local bucketIndex = math_floor(tonumber(data and data.index) or bucketCount)
  if bucketIndex < 1 then
    bucketIndex = 1
  elseif bucketIndex > bucketCount then
    bucketIndex = bucketCount
  end

  local windowSeconds = tonumber(data and data.windowSeconds) or 0
  if windowSeconds <= 0 then
    return "Rolling window bucket"
  end

  local fmtTime = NS.fmtTime or function(seconds)
    return tostring(seconds) .. "s"
  end
  local bucketSeconds = windowSeconds / bucketCount
  local newerSeconds = math_max(0, math_floor(((bucketCount - bucketIndex) * bucketSeconds) + 0.5))
  local olderSeconds = math_max(1, math_floor(((bucketCount - bucketIndex + 1) * bucketSeconds) + 0.5))
  if newerSeconds <= 0 then
    return "Latest " .. fmtTime(olderSeconds)
  end
  return fmtTime(newerSeconds) .. "-" .. fmtTime(olderSeconds) .. " ago"
end

function HUDGraph.ShowTooltip(self)
  local data = self and self._dingGraphBucket
  if not data or not GameTooltip then
    return
  end

  local amount = tonumber(data.amount) or 0
  local colors = NS.C or {}
  local formatNumber = NS.FormatNumber or function(value)
    return tostring(value)
  end

  GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
  if GameTooltip.ClearLines then
    GameTooltip:ClearLines()
  end
  GameTooltip:AddLine((colors.base or "") .. "DingTimer Graph" .. (colors.r or ""))
  if amount > 0 then
    GameTooltip:AddLine("+" .. formatNumber(amount) .. " XP", 1, 1, 1)
  else
    GameTooltip:AddLine("No XP", 1, 1, 1)
  end
  GameTooltip:AddLine(HUDGraph.FormatBucketRange(data), 0.82, 0.88, 0.92)

  local peak = tonumber(data.peak) or 0
  if peak > 0 then
    GameTooltip:AddLine("Peak bucket +" .. formatNumber(peak), 0.78, 0.9, 0.95)
  end
  GameTooltip:Show()
end

function HUDGraph.HideTooltip()
  if GameTooltip and GameTooltip.Hide then
    GameTooltip:Hide()
  end
end

function HUDGraph.UpdateTooltipData(frame, buckets, peak, snapshot, bucketCount)
  if not frame or not frame.graphHitboxes then
    return
  end

  bucketCount = normalizeBucketCount(bucketCount)
  for i = 1, #frame.graphHitboxes do
    local hitbox = frame.graphHitboxes[i]
    if hitbox then
      hitbox._dingGraphBucket = {
        index = i,
        count = bucketCount,
        amount = buckets and buckets[i] or 0,
        peak = peak or 0,
        windowSeconds = snapshot and snapshot.rollingWindow or 0,
      }
    end
  end
end

function HUDGraph.Render(frame, snapshot, profile, events)
  if not frame or not frame.graphBars or not snapshot or not profile then
    return
  end

  local graphHeight = profile.graphHeight or 28
  local usableHeight = math_max(6, graphHeight - ((profile.graphBarBaseY or 1) + 5))
  local bucketCount = normalizeBucketCount(profile.graphBucketCount or #frame.graphBars)
  local buckets, peak = HUDGraph.BuildBuckets(events, snapshot.now, snapshot.rollingWindow, bucketCount)
  local minimumHeight = 3

  for i = 1, #frame.graphBars do
    local graphBar = frame.graphBars[i]
    if graphBar then
      local amount = buckets[i] or 0
      local ratio = (peak > 0) and (amount / peak) or 0
      local barHeight = 0
      if amount > 0 and peak > 0 then
        barHeight = math_max(minimumHeight, math_floor((math_sqrt(ratio) * usableHeight) + 0.5))
      end
      graphBar:SetHeight(barHeight)
      if amount > 0 then
        local recency = i / #frame.graphBars
        local red = 0.10 + (0.16 * recency)
        local green = 0.58 + (0.24 * ratio) + (0.08 * recency)
        local blue = 0.76 + (0.18 * recency)
        graphBar:SetColorTexture(red, green, blue, 0.9)
        graphBar:Show()
      else
        graphBar:SetColorTexture(0.07, 0.16, 0.20, 0.36)
        graphBar:SetHeight(2)
        graphBar:Show()
      end
    end
  end

  HUDGraph.UpdateTooltipData(frame, buckets, peak, snapshot, bucketCount)

  if frame.graphPeakText then
    local formatNumber = NS.FormatNumber or function(value)
      return tostring(value)
    end
    if peak > 0 then
      frame.graphPeakText:SetText("Peak bucket +" .. formatNumber(peak))
    else
      frame.graphPeakText:SetText("No XP")
    end
  end
end

function NS.BuildXPGraphBuckets(events, now, windowSeconds, bucketCount)
  return HUDGraph.BuildBuckets(events, now, windowSeconds, bucketCount)
end
