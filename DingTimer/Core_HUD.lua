local _, NS = ...

local math_abs = math.abs
local math_floor = math.floor
local math_max = math.max
local math_min = math.min

---@class DingTimerTextRegion: FontString
---@field SetText fun(self: DingTimerTextRegion, text: string)
---@field SetWidth fun(self: DingTimerTextRegion, width: number)?
---@field SetFontObject fun(self: DingTimerTextRegion, fontObject: string)?
---@field SetTextColor fun(self: DingTimerTextRegion, r: number, g: number, b: number, a: number?)?
---@field SetShadowColor fun(self: DingTimerTextRegion, r: number, g: number, b: number, a: number)?
---@field ClearAllPoints fun(self: DingTimerTextRegion)?
---@field SetPoint fun(self: DingTimerTextRegion, point: string, relativeTo: any, relativePoint: string, xOfs: number, yOfs: number)?
---@field SetJustifyH fun(self: DingTimerTextRegion, justify: string)?
---@field Show fun(self: DingTimerTextRegion)?
---@field Hide fun(self: DingTimerTextRegion)?

---@class DingTimerTexture: Texture
---@field SetWidth fun(self: DingTimerTexture, width: number)
---@field GetWidth fun(self: DingTimerTexture): number
---@field SetAlpha fun(self: DingTimerTexture, alpha: number)
---@field GetAlpha fun(self: DingTimerTexture): number
---@field Show fun(self: DingTimerTexture)
---@field Hide fun(self: DingTimerTexture)
---@field IsShown fun(self: DingTimerTexture): boolean
---@field ClearAllPoints fun(self: DingTimerTexture)
---@field SetPoint fun(self: DingTimerTexture, point: string, relativeTo: any, relativePoint: string, xOfs: number, yOfs: number)

---@class DingTimerFloatFrame: Button
---@field Show fun(self: DingTimerFloatFrame)
---@field Hide fun(self: DingTimerFloatFrame)
---@field IsShown fun(self: DingTimerFloatFrame): boolean
---@field SetBackdropBorderColor fun(self: DingTimerFloatFrame, r: number, g: number, b: number, a: number)?
---@field titleText DingTimerTextRegion?
---@field subText DingTimerTextRegion?
---@field progressBar Frame?
---@field progressFill DingTimerTexture?
---@field progressSheen DingTimerTexture?
---@field progressPulse DingTimerTexture?
---@field progressSpark DingTimerTexture?
---@field progressCap DingTimerTexture?
---@field progressTicks DingTimerTexture[]?
---@field progressFillShade DingTimerTexture?
---@field graphArea Frame?
---@field graphBackdrop DingTimerTexture?
---@field graphBars DingTimerTexture[]?
---@field graphHitboxes Frame[]?
---@field graphBaseline DingTimerTexture?
---@field graphGuides DingTimerTexture[]?
---@field graphPeakText DingTimerTextRegion?
---@field _dingAccent DingTimerTexture?
---@field _dingGlow DingTimerTexture?
---@field _hudGlow DingTimerTexture?
---@field _hudBottomLine DingTimerTexture?
---@field _hudProfile string?
---@field progressBarWidth number?
---@field _displayedProgress number?
---@field _targetProgress number?
---@field _progressAnim table?
---@field _gainPulse table?
---@field _hovered boolean?

---@type DingTimerFloatFrame?
local floatFrame = nil

local HUD_DEFAULT_PROFILE = "full"
local HUD_PROFILES = {
  full = {
    id = "full",
    label = "Full",
    width = 385,
    height = 66,
    barWidth = 345,
    barHeight = 9,
    barYOffset = 11,
    titleTemplate = "GameFontHighlightLarge",
    titleStyle = "title",
    titleYOffset = -7,
    titleWidthExtra = 10,
    titleColor = { 0.92, 0.98, 1.0 },
    titleShadowAlpha = 0.92,
    subVisible = true,
    subYOffset = 4,
    subWidthExtra = 16,
    subTextMaxChars = 64,
  },
  compact = {
    id = "compact",
    label = "Compact",
    width = 308,
    height = 54,
    barWidth = 276,
    barHeight = 8,
    barYOffset = 9,
    titleTemplate = "GameFontHighlight",
    titleStyle = "value",
    titleYOffset = -6,
    titleWidthExtra = 8,
    titleColor = { 0.95, 0.98, 1.0 },
    titleShadowAlpha = 0.88,
    subVisible = true,
    subYOffset = 3,
    subWidthExtra = 12,
    subTextMaxChars = 48,
  },
  bar_ttl = {
    id = "bar_ttl",
    label = "Bar+TTL",
    width = 260,
    height = 38,
    barWidth = 232,
    barHeight = 8,
    barYOffset = 8,
    titleTemplate = "GameFontHighlight",
    titleStyle = "value",
    titleYOffset = -6,
    titleWidthExtra = 6,
    titleColor = { 0.92, 0.98, 1.0 },
    titleShadowAlpha = 0.9,
    subVisible = false,
    subYOffset = 3,
    subWidthExtra = 0,
    subTextMaxChars = 0,
    shortTTL = true,
  },
  graph = {
    id = "graph",
    label = "Graph",
    width = 385,
    height = 96,
    barWidth = 345,
    barHeight = 8,
    barYOffset = 8,
    titleTemplate = "GameFontHighlight",
    titleStyle = "value",
    titleYOffset = -6,
    titleWidthExtra = 10,
    titleColor = { 0.92, 0.98, 1.0 },
    titleShadowAlpha = 0.88,
    subVisible = true,
    subYOffset = 11,
    subWidthExtra = 16,
    subTextMaxChars = 58,
    graphVisible = true,
    graphWidth = 345,
    graphHeight = 46,
    graphYOffset = 10,
    graphBucketCount = 18,
    graphGap = 2,
    graphPaddingX = 4,
    graphBarBaseY = 3,
  },
}
local HUD_PROFILE_CHOICES = {
  HUD_PROFILES.full,
  HUD_PROFILES.compact,
  HUD_PROFILES.bar_ttl,
  HUD_PROFILES.graph,
}
local HUD_DEFAULT = HUD_PROFILES[HUD_DEFAULT_PROFILE]
local HUD_PROGRESS_ANIM_DURATION = 0.28
local HUD_GAIN_PULSE_DURATION = 0.65
local HUD_PROGRESS_EPSILON = 0.0005

local function anchorFloatToDefault(frame)
  if not frame then
    return
  end

  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
end

local function clampProgress(value)
  value = tonumber(value) or 0
  if value < 0 then
    return 0
  end
  if value > 1 then
    return 1
  end
  return value
end

local function easeOutCubic(value)
  local t = math_min(1, math_max(0, value or 0))
  local inv = 1 - t
  return 1 - (inv * inv * inv)
end

local function resolveHUDProfile(profileId)
  return HUD_PROFILES[profileId] or HUD_DEFAULT
end

local function getActiveHUDProfile()
  return resolveHUDProfile(DingTimerDB and DingTimerDB.hudProfile)
end

local function setProgressWidgetsShown(frame, shown)
  if not frame then
    return
  end

  local widgets = {
    frame.progressBar,
    frame.progressFill,
    frame.progressSheen,
    frame.progressPulse,
    frame.progressSpark,
    frame.progressCap,
    frame.progressFillShade,
  }
  for i = 1, #widgets do
    local widget = widgets[i]
    if widget then
      if shown and widget.Show then
        widget:Show()
      elseif not shown and widget.Hide then
        widget:Hide()
      end
    end
  end
  if frame.progressTicks then
    for i = 1, #frame.progressTicks do
      local tick = frame.progressTicks[i]
      if tick then
        if shown and tick.Show then
          tick:Show()
        elseif not shown and tick.Hide then
          tick:Hide()
        end
      end
    end
  end
end

local function setGraphWidgetsShown(frame, shown)
  if not frame then
    return
  end

  local widgets = {
    frame.graphArea,
    frame.graphBackdrop,
    frame.graphBaseline,
    frame.graphPeakText,
  }
  for i = 1, #widgets do
    local widget = widgets[i]
    if widget then
      if shown and widget.Show then
        widget:Show()
      elseif not shown and widget.Hide then
        widget:Hide()
      end
    end
  end
  if frame.graphBars then
    for i = 1, #frame.graphBars do
      local bar = frame.graphBars[i]
      if bar then
        if shown and bar.Show then
          bar:Show()
        elseif not shown and bar.Hide then
          bar:Hide()
        end
      end
    end
  end
  if frame.graphHitboxes then
    for i = 1, #frame.graphHitboxes do
      local hitbox = frame.graphHitboxes[i]
      if hitbox then
        if shown and hitbox.Show then
          hitbox:Show()
        elseif not shown and hitbox.Hide then
          hitbox:Hide()
        end
      end
    end
  end
  if frame.graphGuides then
    for i = 1, #frame.graphGuides do
      local guide = frame.graphGuides[i]
      if guide then
        if shown and guide.Show then
          guide:Show()
        elseif not shown and guide.Hide then
          guide:Hide()
        end
      end
    end
  end
  if not shown and GameTooltip and GameTooltip.Hide then
    GameTooltip:Hide()
  end
end

local function applyTitleStyle(title, profile)
  if not title or not profile then
    return
  end

  if NS.UI and NS.UI.ApplyTextStyle then
    NS.UI.ApplyTextStyle(title, profile.titleStyle or "value")
  elseif title.SetFontObject then
    title:SetFontObject(profile.titleTemplate or "GameFontHighlight")
  end
  if title.SetTextColor and profile.titleColor then
    title:SetTextColor(profile.titleColor[1], profile.titleColor[2], profile.titleColor[3])
  end
  if title.SetShadowColor then
    title:SetShadowColor(0, 0, 0, profile.titleShadowAlpha or 0.85)
  end
  if title.SetJustifyH then
    title:SetJustifyH("CENTER")
  end
end

local function applySubTextStyle(sub)
  if not sub then
    return
  end

  if NS.UI and NS.UI.ApplyTextStyle then
    NS.UI.ApplyTextStyle(sub, "subtle")
  end
  if sub.SetTextColor then
    sub:SetTextColor(0.82, 0.88, 0.92)
  end
  if sub.SetJustifyH then
    sub:SetJustifyH("CENTER")
  end
end

local function applyFloatProfileLayout(frame, profile)
  if not frame or not profile then
    return
  end

  frame._hudProfile = profile.id
  frame:SetSize(profile.width, profile.height)

  local bar = frame.progressBar
  if bar then
    bar:SetSize(profile.barWidth, profile.barHeight)
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOM", frame, "BOTTOM", 0, profile.barYOffset)
    frame.progressBarWidth = profile.barWidth
  end
  setProgressWidgetsShown(frame, profile.graphVisible ~= true)
  setGraphWidgetsShown(frame, profile.graphVisible == true)

  if frame.graphArea then
    local graphWidth = profile.graphWidth or profile.barWidth
    local graphHeight = profile.graphHeight or 28
    frame.graphArea:SetSize(graphWidth, graphHeight)
    frame.graphArea:ClearAllPoints()
    frame.graphArea:SetPoint("BOTTOM", frame, "BOTTOM", 0, profile.graphYOffset or profile.barYOffset or 8)
    if frame.graphBars then
      local bucketCount = profile.graphBucketCount or #frame.graphBars
      local gap = profile.graphGap or 2
      local paddingX = profile.graphPaddingX or 0
      local barBaseY = profile.graphBarBaseY or 1
      local barWidth = math_max(2, math_floor((graphWidth - (paddingX * 2) - ((bucketCount - 1) * gap)) / bucketCount))
      for i = 1, #frame.graphBars do
        local graphBar = frame.graphBars[i]
        if graphBar then
          graphBar:ClearAllPoints()
          graphBar:SetWidth(barWidth)
          graphBar:SetPoint("BOTTOMLEFT", frame.graphArea, "BOTTOMLEFT", paddingX + math_floor((i - 1) * (barWidth + gap)), barBaseY)
        end
      end
      if frame.graphHitboxes then
        for i = 1, #frame.graphHitboxes do
          local hitbox = frame.graphHitboxes[i]
          if hitbox then
            hitbox:ClearAllPoints()
            hitbox:SetSize(barWidth, graphHeight)
            hitbox:SetPoint("BOTTOMLEFT", frame.graphArea, "BOTTOMLEFT", paddingX + math_floor((i - 1) * (barWidth + gap)), 0)
          end
        end
      end
    end
  end
  if frame.graphBackdrop and frame.graphArea then
    frame.graphBackdrop:ClearAllPoints()
    frame.graphBackdrop:SetPoint("TOPLEFT", frame.graphArea, "TOPLEFT", 0, 0)
    frame.graphBackdrop:SetPoint("BOTTOMRIGHT", frame.graphArea, "BOTTOMRIGHT", 0, 0)
    frame.graphBackdrop:SetColorTexture(0.02, 0.05, 0.07, 0.64)
  end
  if frame.graphBaseline and frame.graphArea then
    frame.graphBaseline:ClearAllPoints()
    frame.graphBaseline:SetPoint("BOTTOMLEFT", frame.graphArea, "BOTTOMLEFT", profile.graphPaddingX or 0, 1)
    frame.graphBaseline:SetPoint("BOTTOMRIGHT", frame.graphArea, "BOTTOMRIGHT", -(profile.graphPaddingX or 0), 1)
    frame.graphBaseline:SetHeight(1)
  end
  if frame.graphGuides and frame.graphArea then
    local guideGraphHeight = profile.graphHeight or 28
    for i = 1, #frame.graphGuides do
      local guide = frame.graphGuides[i]
      if guide then
        guide:ClearAllPoints()
        guide:SetPoint("LEFT", frame.graphArea, "LEFT", profile.graphPaddingX or 0, math_floor((guideGraphHeight * i / (#frame.graphGuides + 1)) + 0.5))
        guide:SetPoint("RIGHT", frame.graphArea, "RIGHT", -(profile.graphPaddingX or 0), math_floor((guideGraphHeight * i / (#frame.graphGuides + 1)) + 0.5))
        guide:SetHeight(1)
      end
    end
  end

  if frame.progressSheen then
    frame.progressSheen:SetHeight(math_max(3, math_floor(profile.barHeight * 0.42)))
  end
  if frame.progressFillShade then
    frame.progressFillShade:SetWidth(profile.barWidth)
    frame.progressFillShade:SetHeight(math_max(3, math_floor(profile.barHeight * 0.4)))
  end
  if frame.progressTicks and bar then
    for i = 1, 3 do
      local tick = frame.progressTicks[i]
      if tick then
        tick:ClearAllPoints()
        tick:SetWidth(1)
        tick:SetHeight(math_max(2, profile.barHeight - 4))
        tick:SetPoint("CENTER", bar, "LEFT", math_floor((profile.barWidth * i / 4) + 0.5), 0)
        tick:SetColorTexture(0.74, 0.92, 1.0, 0.34)
      end
    end
  end
  if frame.progressSpark then
    frame.progressSpark:SetSize(14, profile.barHeight + 6)
  end
  if frame.progressCap then
    frame.progressCap:SetSize(2, profile.barHeight + 2)
  end

  local title = frame.titleText
  if title then
    if title.ClearAllPoints then
      title:ClearAllPoints()
    end
    if title.SetPoint then
      title:SetPoint("TOP", frame, "TOP", 0, profile.titleYOffset)
    end
    if title.SetWidth then
      title:SetWidth(profile.barWidth + (profile.titleWidthExtra or 0))
    end
    applyTitleStyle(title, profile)
    if title.Show then
      title:Show()
    end
  end

  local sub = frame.subText
  if sub then
    if sub.ClearAllPoints then
      sub:ClearAllPoints()
    end
    local subAnchor = profile.graphVisible and frame.graphArea or bar
    if sub.SetPoint and subAnchor then
      sub:SetPoint("BOTTOM", subAnchor, "TOP", 0, profile.subYOffset or 0)
    end
    if sub.SetWidth then
      sub:SetWidth(profile.barWidth + (profile.subWidthExtra or 0))
    end
    applySubTextStyle(sub)
    if profile.subVisible == false then
      if sub.Hide then
        sub:Hide()
      end
    elseif sub.Show then
      sub:Show()
    end
  end
end

local function updateFloatBarVisual(frame, progress, pulseAlpha)
  if not frame or not frame.progressBar or not frame.progressFill then
    return
  end
  if frame._hudProfile == "graph" then
    setProgressWidgetsShown(frame, false)
    return
  end

  local fill = frame.progressFill
  local sheen = frame.progressSheen
  local pulse = frame.progressPulse
  local spark = frame.progressSpark
  local cap = frame.progressCap
  local barWidth = frame.progressBarWidth or HUD_DEFAULT.barWidth

  progress = clampProgress(progress)
  pulseAlpha = tonumber(pulseAlpha) or 0
  local hoverAlpha = frame._hovered and 1 or 0

  local fillWidth = math_floor((barWidth * progress) + 0.5)
  if progress > 0 and fillWidth < 2 then
    fillWidth = 2
  end

  if frame._hudGlow then
    frame._hudGlow:SetAlpha(0.12 + (pulseAlpha * 0.24) + (hoverAlpha * 0.12))
  end
  if frame._hudBottomLine then
    frame._hudBottomLine:SetColorTexture(0.05, 0.12, 0.16, 0.58 + (hoverAlpha * 0.14))
  end

  if fillWidth > 0 then
    fill:SetWidth(fillWidth)
    fill:Show()
    fill:SetColorTexture(0.16, 0.78, 0.92, 0.76 + (pulseAlpha * 0.09))

    if sheen then
      sheen:SetWidth(fillWidth)
      sheen:SetColorTexture(0.94, 0.99, 1.0, 0.10 + (pulseAlpha * 0.12))
      sheen:Show()
    end
  else
    fill:SetWidth(0)
    fill:Hide()
    if sheen then
      sheen:SetWidth(0)
      sheen:Hide()
    end
  end

  if pulse and fillWidth > 0 and pulseAlpha > 0 then
    pulse:SetWidth(math_min(barWidth, fillWidth + 18))
    pulse:SetAlpha(0.05 + (pulseAlpha * 0.26))
    pulse:Show()
  elseif pulse then
    pulse:SetWidth(fillWidth)
    pulse:SetAlpha(0)
    pulse:Hide()
  end

  if spark and fillWidth > 0 then
    spark:ClearAllPoints()
    spark:SetPoint("CENTER", frame.progressBar, "LEFT", fillWidth, 0)
    spark:SetAlpha(0.12 + (pulseAlpha * 0.58) + (hoverAlpha * 0.08))
    spark:Show()
  elseif spark then
    spark:SetAlpha(0)
    spark:Hide()
  end

  if cap and fillWidth > 0 then
    cap:ClearAllPoints()
    cap:SetPoint("CENTER", frame.progressBar, "LEFT", fillWidth, 0)
    cap:SetAlpha(0.46 + (pulseAlpha * 0.2) + (hoverAlpha * 0.12))
    cap:Show()
  elseif cap then
    cap:SetAlpha(0)
    cap:Hide()
  end
end

local function showXPGraphBucketTooltip(self)
  if NS.HUDGraph and NS.HUDGraph.ShowTooltip then
    NS.HUDGraph.ShowTooltip(self)
  end
end

local function hideXPGraphBucketTooltip()
  if NS.HUDGraph and NS.HUDGraph.HideTooltip then
    NS.HUDGraph.HideTooltip()
  end
end

local function handleFloatDragStart(frame)
  if not frame or DingTimerDB.floatLocked then
    return
  end
  frame:StartMoving()
end

local function handleFloatDragStop(frame)
  if not frame or DingTimerDB.floatLocked then
    return
  end
  frame:StopMovingOrSizing()
  local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
  DingTimerDB.floatPosition = {
    point = point,
    relativePoint = relativePoint,
    xOfs = xOfs,
    yOfs = yOfs,
  }
end

local function handleFloatClick(frame, button)
  if button == "RightButton" and NS.ToggleHUDPopup then
    NS.ToggleHUDPopup(frame)
    return
  end
  if button == "LeftButton" and DingTimerDB.floatLocked and NS.ToggleHUDPopup then
    NS.ToggleHUDPopup(frame)
  end
end

local function animateFloatOnUpdate(self, elapsed)
  local displayed = self._displayedProgress or 0
  local pulseAlpha = 0

  if self._progressAnim then
    local animation = self._progressAnim
    animation.elapsed = (animation.elapsed or 0) + elapsed

    local t = 1
    if (animation.duration or 0) > 0 then
      t = math_min(animation.elapsed / animation.duration, 1)
    end

    displayed = animation.start + ((animation.target - animation.start) * easeOutCubic(t))
    self._displayedProgress = displayed

    if t >= 1 then
      displayed = animation.target
      self._displayedProgress = displayed
      self._progressAnim = nil
    end
  else
    displayed = self._targetProgress or displayed
    self._displayedProgress = displayed
  end

  if self._gainPulse then
    local pulse = self._gainPulse
    pulse.elapsed = (pulse.elapsed or 0) + elapsed

    local t = 1
    if (pulse.duration or 0) > 0 then
      t = math_min(pulse.elapsed / pulse.duration, 1)
    end

    local fade = 1 - t
    pulseAlpha = fade * fade

    if t >= 1 then
      self._gainPulse = nil
      pulseAlpha = 0
    end
  end

  updateFloatBarVisual(self, displayed, pulseAlpha)

  if not self._progressAnim and not self._gainPulse then
    self:SetScript("OnUpdate", nil)
  end
end

local function ensureFloatAnimation(frame)
  if not frame then
    return
  end

  local current = frame.GetScript and frame:GetScript("OnUpdate") or nil
  if current ~= animateFloatOnUpdate then
    frame:SetScript("OnUpdate", animateFloatOnUpdate)
  end
end

local function setFloatProgress(frame, progress, animate)
  if not frame or not frame.progressBar then
    return
  end

  progress = clampProgress(progress)

  if frame._displayedProgress == nil or frame._targetProgress == nil then
    frame._displayedProgress = progress
    frame._targetProgress = progress
    frame._progressAnim = nil
    updateFloatBarVisual(frame, progress, 0)
    return
  end

  if math_abs(progress - (frame._targetProgress or 0)) < HUD_PROGRESS_EPSILON then
    if not frame._progressAnim then
      frame._displayedProgress = progress
      frame._targetProgress = progress
      updateFloatBarVisual(frame, progress, frame._gainPulse and 1 or 0)
    end
    return
  end

  frame._targetProgress = progress

  if not animate or progress < (frame._displayedProgress or 0) then
    frame._displayedProgress = progress
    frame._progressAnim = nil
    updateFloatBarVisual(frame, progress, frame._gainPulse and 1 or 0)
    return
  end

  frame._progressAnim = {
    start = frame._displayedProgress or progress,
    target = progress,
    elapsed = 0,
    duration = HUD_PROGRESS_ANIM_DURATION,
  }
  updateFloatBarVisual(frame, frame._displayedProgress or progress, frame._gainPulse and 1 or 0)
  ensureFloatAnimation(frame)
end

function NS.TriggerFloatGainPulse(progress)
  local frame = floatFrame
  if not frame or not frame.progressBar or not (frame.IsShown and frame:IsShown()) then
    return
  end

  progress = clampProgress(progress)

  if frame._displayedProgress == nil then
    frame._displayedProgress = progress
    frame._targetProgress = progress
  elseif progress < frame._displayedProgress then
    frame._displayedProgress = progress
    frame._targetProgress = progress
    frame._progressAnim = nil
  end

  frame._gainPulse = {
    elapsed = 0,
    duration = HUD_GAIN_PULSE_DURATION,
  }

  updateFloatBarVisual(frame, frame._displayedProgress or progress, 1)
  ensureFloatAnimation(frame)
end

function NS.GetFloatFrame()
  return floatFrame
end

function NS.IsFloatVisible()
  return floatFrame ~= nil and floatFrame.IsShown and floatFrame:IsShown() or false
end

function NS.IsFloatAnimating()
  return floatFrame ~= nil and (floatFrame._progressAnim ~= nil or floatFrame._gainPulse ~= nil)
end

function NS.GetHUDProfiles()
  return HUD_PROFILE_CHOICES
end

function NS.GetHUDProfile()
  return getActiveHUDProfile().id
end

function NS.SetHUDProfile(profileId)
  local profile = resolveHUDProfile(profileId)
  if DingTimerDB then
    DingTimerDB.hudProfile = profile.id
  end

  if floatFrame then
    applyFloatProfileLayout(floatFrame, profile)
    updateFloatBarVisual(floatFrame, floatFrame._displayedProgress or floatFrame._targetProgress or 0, floatFrame._gainPulse and 1 or 0)
  end
  if NS.RefreshFloatingHUD then
    NS.RefreshFloatingHUD()
  end
  if NS.RefreshHUDPopup then
    NS.RefreshHUDPopup()
  end
  return profile.id
end

function NS.ensureFloat()
  if floatFrame then
    return
  end

  local profile = getActiveHUDProfile()
  local frame = CreateFrame("Button", nil, UIParent, "BackdropTemplate") --[[@as DingTimerFloatFrame]]
  floatFrame = frame
  floatFrame:SetSize(profile.width, profile.height)
  floatFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
  floatFrame:SetMovable(true)
  floatFrame:EnableMouse(true)
  floatFrame:RegisterForDrag("LeftButton")
  floatFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  floatFrame:SetClampedToScreen(true)
  if NS.ApplyThemeToFrame then
    NS.ApplyThemeToFrame(floatFrame, true)
  end
  if floatFrame._dingAccent then
    floatFrame._dingAccent:Hide()
  end
  if floatFrame._dingGlow then
    floatFrame._dingGlow:Hide()
  end
  if floatFrame.SetBackdropBorderColor then
    floatFrame:SetBackdropBorderColor(0.18, 0.58, 0.72, 0.88)
  end

  local hudGlow = floatFrame:CreateTexture(nil, "BACKGROUND") --[[@as DingTimerTexture]]
  hudGlow:SetPoint("TOPLEFT", floatFrame, "TOPLEFT", -4, 4)
  hudGlow:SetPoint("BOTTOMRIGHT", floatFrame, "BOTTOMRIGHT", 4, -4)
  hudGlow:SetColorTexture(0.08, 0.28, 0.36, 1)
  hudGlow:SetAlpha(0.12)
  floatFrame._hudGlow = hudGlow

  local bottomLine = floatFrame:CreateTexture(nil, "BORDER") --[[@as DingTimerTexture]]
  bottomLine:SetHeight(1)
  bottomLine:SetPoint("BOTTOMLEFT", floatFrame, "BOTTOMLEFT", 12, 6)
  bottomLine:SetPoint("BOTTOMRIGHT", floatFrame, "BOTTOMRIGHT", -12, 6)
  bottomLine:SetColorTexture(0.05, 0.12, 0.16, 0.58)
  floatFrame._hudBottomLine = bottomLine

  floatFrame:SetScript("OnDragStart", handleFloatDragStart)
  floatFrame:SetScript("OnDragStop", handleFloatDragStop)
  floatFrame:SetScript("OnClick", handleFloatClick)

  floatFrame:SetScript("OnEnter", function(self)
    self._hovered = true
    updateFloatBarVisual(self, self._targetProgress or self._displayedProgress or 0, self._gainPulse and 1 or 0)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(NS.C.base .. "DingTimer" .. NS.C.r)
    if DingTimerDB.floatLocked then
      GameTooltip:AddLine("Left-click to toggle settings", 1, 1, 1)
    else
      GameTooltip:AddLine("Left-drag to move the HUD", 1, 1, 1)
    end
    GameTooltip:AddLine("Right-click to toggle settings", 1, 1, 1)
    GameTooltip:Show()
  end)

  floatFrame:SetScript("OnLeave", function(self)
    self._hovered = false
    updateFloatBarVisual(self, self._targetProgress or self._displayedProgress or 0, 0)
    GameTooltip:Hide()
  end)

  floatFrame:SetScript("OnHide", function(self)
    self._gainPulse = nil
    self._progressAnim = nil
    self:SetScript("OnUpdate", nil)
    updateFloatBarVisual(self, self._targetProgress or self._displayedProgress or 0, 0)
  end)

  if DingTimerDB.floatPosition then
    local pos = DingTimerDB.floatPosition
    floatFrame:ClearAllPoints()
    floatFrame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.xOfs or 0, pos.yOfs or 0)
  else
    anchorFloatToDefault(floatFrame)
  end

  local bar = CreateFrame("Frame", nil, floatFrame)
  bar:SetSize(profile.barWidth, profile.barHeight)
  bar:SetPoint("BOTTOM", floatFrame, "BOTTOM", 0, profile.barYOffset)
  floatFrame.progressBar = bar
  floatFrame.progressBarWidth = profile.barWidth

  local barShadow = bar:CreateTexture(nil, "BACKGROUND")
  barShadow:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
  barShadow:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
  barShadow:SetColorTexture(0, 0, 0, 0.35)

  local track = bar:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints(bar)
  track:SetColorTexture(0.03, 0.05, 0.08, 0.92)

  local trackEdge = bar:CreateTexture(nil, "BORDER")
  trackEdge:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
  trackEdge:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 1, 1)
  trackEdge:SetHeight(1)
  trackEdge:SetColorTexture(0.34, 0.44, 0.52, 0.55)

  local trackGlow = bar:CreateTexture(nil, "BORDER")
  trackGlow:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
  trackGlow:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
  trackGlow:SetColorTexture(0.12, 0.24, 0.32, 0.22)

  local fill = bar:CreateTexture(nil, "ARTWORK") --[[@as DingTimerTexture]]
  fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
  fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  fill:SetWidth(0)
  fill:SetColorTexture(0.16, 0.78, 0.92, 0.76)
  fill:Hide()
  floatFrame.progressFill = fill

  local sheen = bar:CreateTexture(nil, "OVERLAY") --[[@as DingTimerTexture]]
  sheen:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -1)
  sheen:SetWidth(0)
  sheen:SetHeight(math_max(3, math_floor(profile.barHeight * 0.42)))
  sheen:SetColorTexture(0.94, 0.99, 1.0, 0.10)
  sheen:Hide()
  floatFrame.progressSheen = sheen

  local fillShade = bar:CreateTexture(nil, "OVERLAY") --[[@as DingTimerTexture]]
  fillShade:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  fillShade:SetWidth(profile.barWidth)
  fillShade:SetHeight(math_max(3, math_floor(profile.barHeight * 0.4)))
  fillShade:SetColorTexture(0.03, 0.08, 0.12, 0.18)
  floatFrame.progressFillShade = fillShade

  floatFrame.progressTicks = {}
  for i = 1, 3 do
    local tick = bar:CreateTexture(nil, "OVERLAY", nil, 2) --[[@as DingTimerTexture]]
    tick:SetWidth(1)
    tick:SetHeight(math_max(2, profile.barHeight - 4))
    tick:SetPoint("CENTER", bar, "LEFT", math_floor((profile.barWidth * i / 4) + 0.5), 0)
    tick:SetColorTexture(0.74, 0.92, 1.0, 0.34)
    floatFrame.progressTicks[i] = tick
  end

  local pulse = bar:CreateTexture(nil, "OVERLAY") --[[@as DingTimerTexture]]
  pulse:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
  pulse:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  pulse:SetWidth(0)
  pulse:SetTexture("Interface\\Buttons\\WHITE8X8")
  pulse:SetBlendMode("ADD")
  pulse:SetVertexColor(0.78, 0.96, 1, 1)
  pulse:SetAlpha(0)
  pulse:Hide()
  floatFrame.progressPulse = pulse

  local spark = bar:CreateTexture(nil, "OVERLAY") --[[@as DingTimerTexture]]
  spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
  spark:SetBlendMode("ADD")
  spark:SetSize(14, profile.barHeight + 6)
  spark:SetAlpha(0)
  spark:Hide()
  floatFrame.progressSpark = spark

  local cap = bar:CreateTexture(nil, "OVERLAY") --[[@as DingTimerTexture]]
  cap:SetSize(2, profile.barHeight + 2)
  cap:SetTexture("Interface\\Buttons\\WHITE8X8")
  cap:SetBlendMode("ADD")
  cap:SetVertexColor(0.86, 0.98, 1.0, 1)
  cap:SetAlpha(0)
  cap:Hide()
  floatFrame.progressCap = cap

  local graphArea = CreateFrame("Frame", nil, floatFrame)
  graphArea:SetSize(HUD_PROFILES.graph.graphWidth, HUD_PROFILES.graph.graphHeight)
  graphArea:SetPoint("BOTTOM", floatFrame, "BOTTOM", 0, HUD_PROFILES.graph.graphYOffset)
  graphArea:Hide()
  floatFrame.graphArea = graphArea

  local graphBackdrop = graphArea:CreateTexture(nil, "BACKGROUND") --[[@as DingTimerTexture]]
  graphBackdrop:SetAllPoints(graphArea)
  graphBackdrop:SetColorTexture(0.02, 0.05, 0.07, 0.64)
  graphBackdrop:Hide()
  floatFrame.graphBackdrop = graphBackdrop

  floatFrame.graphGuides = {}
  for i = 1, 2 do
    local guide = graphArea:CreateTexture(nil, "BORDER") --[[@as DingTimerTexture]]
    guide:SetPoint("LEFT", graphArea, "LEFT", HUD_PROFILES.graph.graphPaddingX, math_floor((HUD_PROFILES.graph.graphHeight * i / 3) + 0.5))
    guide:SetPoint("RIGHT", graphArea, "RIGHT", -HUD_PROFILES.graph.graphPaddingX, math_floor((HUD_PROFILES.graph.graphHeight * i / 3) + 0.5))
    guide:SetHeight(1)
    guide:SetColorTexture(0.22, 0.34, 0.40, 0.18)
    guide:Hide()
    floatFrame.graphGuides[i] = guide
  end

  local graphBaseline = graphArea:CreateTexture(nil, "BORDER") --[[@as DingTimerTexture]]
  graphBaseline:SetPoint("BOTTOMLEFT", graphArea, "BOTTOMLEFT", HUD_PROFILES.graph.graphPaddingX, 1)
  graphBaseline:SetPoint("BOTTOMRIGHT", graphArea, "BOTTOMRIGHT", -HUD_PROFILES.graph.graphPaddingX, 1)
  graphBaseline:SetHeight(1)
  graphBaseline:SetColorTexture(0.34, 0.48, 0.56, 0.62)
  graphBaseline:Hide()
  floatFrame.graphBaseline = graphBaseline

  floatFrame.graphBars = {}
  floatFrame.graphHitboxes = {}
  local graphBucketCount = HUD_PROFILES.graph.graphBucketCount
  local graphGap = HUD_PROFILES.graph.graphGap
  local graphPaddingX = HUD_PROFILES.graph.graphPaddingX
  local graphBarWidth = math_max(2, math_floor((HUD_PROFILES.graph.graphWidth - (graphPaddingX * 2) - ((graphBucketCount - 1) * graphGap)) / graphBucketCount))
  for i = 1, graphBucketCount do
    local graphBar = graphArea:CreateTexture(nil, "ARTWORK") --[[@as DingTimerTexture]]
    graphBar:SetWidth(graphBarWidth)
    graphBar:SetHeight(2)
    graphBar:SetPoint("BOTTOMLEFT", graphArea, "BOTTOMLEFT", graphPaddingX + math_floor((i - 1) * (graphBarWidth + graphGap)), HUD_PROFILES.graph.graphBarBaseY)
    graphBar:SetColorTexture(0.07, 0.16, 0.20, 0.36)
    graphBar:Hide()
    floatFrame.graphBars[i] = graphBar

    local graphHitbox = CreateFrame("Button", nil, graphArea)
    graphHitbox:SetSize(graphBarWidth, HUD_PROFILES.graph.graphHeight)
    graphHitbox:SetPoint("BOTTOMLEFT", graphArea, "BOTTOMLEFT", graphPaddingX + math_floor((i - 1) * (graphBarWidth + graphGap)), 0)
    graphHitbox:EnableMouse(true)
    graphHitbox:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    graphHitbox:RegisterForDrag("LeftButton")
    graphHitbox:SetScript("OnEnter", showXPGraphBucketTooltip)
    graphHitbox:SetScript("OnLeave", hideXPGraphBucketTooltip)
    graphHitbox:SetScript("OnClick", function(_, button)
      handleFloatClick(floatFrame, button)
    end)
    graphHitbox:SetScript("OnDragStart", function()
      handleFloatDragStart(floatFrame)
    end)
    graphHitbox:SetScript("OnDragStop", function()
      handleFloatDragStop(floatFrame)
    end)
    graphHitbox:Hide()
    floatFrame.graphHitboxes[i] = graphHitbox
  end

  local graphPeakText = floatFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall") --[[@as DingTimerTextRegion]]
  graphPeakText:SetPoint("BOTTOMRIGHT", graphArea, "TOPRIGHT", -4, 1)
  if graphPeakText.SetWidth then
    graphPeakText:SetWidth(96)
  end
  if NS.UI and NS.UI.ApplyTextStyle then
    NS.UI.ApplyTextStyle(graphPeakText, "subtle")
  end
  if graphPeakText.SetTextColor then
    graphPeakText:SetTextColor(0.78, 0.9, 0.95, 0.95)
  end
  if graphPeakText.SetJustifyH then
    graphPeakText:SetJustifyH("RIGHT")
  end
  graphPeakText:SetText("")
  graphPeakText:Hide()
  floatFrame.graphPeakText = graphPeakText

  local title = floatFrame:CreateFontString(nil, "OVERLAY", profile.titleTemplate) --[[@as DingTimerTextRegion]]
  title:SetPoint("TOP", floatFrame, "TOP", 0, profile.titleYOffset)
  if title.SetWidth then
    title:SetWidth(profile.barWidth + (profile.titleWidthExtra or 0))
  end
  applyTitleStyle(title, profile)
  floatFrame.titleText = title

  local sub = floatFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall") --[[@as DingTimerTextRegion]]
  sub:SetPoint("BOTTOM", bar, "TOP", 0, profile.subYOffset)
  if sub.SetWidth then
    sub:SetWidth(profile.barWidth + (profile.subWidthExtra or 0))
  end
  applySubTextStyle(sub)
  if profile.subVisible == false then
    sub:Hide()
  end
  floatFrame.subText = sub

  applyFloatProfileLayout(floatFrame, profile)
  updateFloatBarVisual(floatFrame, 0, 0)

  floatFrame:Hide()
end

function NS.ResetFloatPosition()
  NS.ensureFloat()
  if not floatFrame then
    return false
  end

  DingTimerDB.floatPosition = nil
  anchorFloatToDefault(floatFrame)
  return true
end

local function shouldShowFloat()
  if not DingTimerDB or not DingTimerDB.float then
    return false
  end

  if InCombatLockdown() and not DingTimerDB.floatShowInCombat then
    return false
  end

  return true
end

function NS.setFloatVisible(on)
  if on and shouldShowFloat() then
    NS.ensureFloat()
    local frame = floatFrame
    if not frame then
      return
    end
    frame:Show()
    if NS.RefreshFloatingHUD then
      NS.RefreshFloatingHUD()
    end
  elseif floatFrame then
    floatFrame:Hide()
    if on and DingTimerDB and DingTimerDB.float and InCombatLockdown() and not DingTimerDB.floatShowInCombat then
      if NS.HideHUDPopup then
        NS.HideHUDPopup()
      end
    end
  end

  if NS.RefreshHUDPopup then
    NS.RefreshHUDPopup()
  end
  if NS.UpdateHeartbeatTicker then
    NS.UpdateHeartbeatTicker()
  end
end

function NS.RefreshFloatingHUD(now)
  if not DingTimerDB or not DingTimerDB.float then
    return
  end

  NS.ensureFloat()
  local frame = floatFrame
  if not frame then
    return
  end
  local profile = getActiveHUDProfile()
  if frame._hudProfile ~= profile.id then
    applyFloatProfileLayout(frame, profile)
  end
  now = now or GetTime()

  local snapshot = NS.GetSessionSnapshot(now)
  if not snapshot then
    return
  end

  local effectiveTrackingMode = snapshot.effectiveTrackingMode or "xp"
  local showProgress = profile.graphVisible ~= true
    and effectiveTrackingMode == "xp"
    and snapshot.isMaxLevel ~= true
  if showProgress then
    setProgressWidgetsShown(frame, true)
    setFloatProgress(frame, snapshot.progress, frame._displayedProgress ~= nil)
  else
    frame._gainPulse = nil
    frame._progressAnim = nil
    frame:SetScript("OnUpdate", nil)
    updateFloatBarVisual(frame, 0, 0)
    setProgressWidgetsShown(frame, false)
  end

  if profile.graphVisible and NS.HUDGraph and NS.HUDGraph.Render then
    local graphValueKey = effectiveTrackingMode == "gold" and "money" or "xp"
    local graphEvents = graphValueKey == "money" and (NS.state and NS.state.moneyEvents) or (NS.state and NS.state.events)
    NS.HUDGraph.Render(frame, snapshot, profile, graphEvents, graphValueKey)
  end

  local header, paceText = NS.BuildHUDText(snapshot, {
    shortTTL = profile.shortTTL,
    subTextMaxChars = profile.subTextMaxChars,
  })

  local titleText = frame.titleText
  local subText = frame.subText
  if not titleText or not subText then
    return
  end

  titleText:SetText(header)
  if profile.subVisible == false then
    subText:SetText("")
    if subText.Hide then
      subText:Hide()
    end
  else
    if subText.Show then
      subText:Show()
    end
    subText:SetText("|cffc6d2db" .. paceText .. "|r")
  end
end
