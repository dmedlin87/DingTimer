local ADDON, NS = ...

NS.UI = NS.UI or {}

function NS.UI.CreateSectionTitle(parent, x, y, title, description)
  local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  header:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  header:SetText(title)

  local sub = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sub:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
  sub:SetText(description or "")

  return header, sub
end

function NS.UI.CreateMetricCard(parent, width, height, x, y, labelText)
  local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  card:SetSize(width, height)
  card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  NS.ApplyThemeToFrame(card, true)

  local accent = card:CreateTexture(nil, "ARTWORK")
  accent:SetHeight(2)
  accent:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -8)
  accent:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -8)
  accent:SetColorTexture(0.24, 0.78, 0.92, 0.72)

  local label = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  label:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -12)
  label:SetText(labelText or "")

  local value = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  value:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
  value:SetText("--")

  local sub = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sub:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 8)
  sub:SetText("")

  card.label = label
  card.value = value
  card.sub = sub
  return card
end

function NS.UI.SetMetricCard(card, value, subValue)
  if not card then
    return
  end
  card.value:SetText(value or "--")
  card.sub:SetText(subValue or "")
end

function NS.UI.CreateActionButton(parent, x, y, width, label, callback)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetSize(width, 24)
  btn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, y)
  btn:SetText(label)
  btn:SetScript("OnClick", callback)
  return btn
end

function NS.UI.CreateValueLabel(parent, x, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  fs:SetText("--")
  return fs
end

function NS.UI.CreateListRows(parent, startX, startY, width, rowCount, spacing, fontObject)
  local rows = {}
  for i = 1, rowCount do
    local fs = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", startX, startY - ((i - 1) * spacing))
    fs:SetJustifyH("LEFT")
    fs:SetWidth(width)
    fs:SetText("")
    rows[i] = fs
  end
  return rows
end

function NS.UI.SetRows(rows, values, emptyText)
  for i = 1, #rows do
    local value = values and values[i] or nil
    if value and value ~= "" then
      rows[i]:SetText(value)
    elseif i == 1 and emptyText then
      rows[i]:SetText(emptyText)
    else
      rows[i]:SetText("")
    end
  end
end

function NS.UI.CreateScrollFrame(parent, childWidth, childHeight)
  local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -50)
  scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -30, 40)

  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetSize(childWidth or 680, childHeight or 500)
  scrollFrame:SetScrollChild(scrollChild)

  return scrollFrame, scrollChild
end
