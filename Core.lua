local ADDON, ns = ...

ns.PLUGIN = "ForeverWayfinder"
ns.VERSION = "1.12.0"
ns.PREFIX = "|cffd4af37Forever Wayfinder|r"

local floor = math.floor

--------------------------------------------------------------------------------------------
-- Visual identity: native WoW dialog chrome. Dark stone pages, ornate gold borders,
-- classic red buttons and gold Morpheus headings, shared by every Wayfinder window.
--------------------------------------------------------------------------------------------

ns.Colors = {
    gold = { 0.83, 0.69, 0.32 },
    brightGold = { 1.00, 0.82, 0.00 },
    goldLine = { 0.72, 0.58, 0.30, 1 },
    parchment = { 0.95, 0.92, 0.82 },
    muted = { 0.62, 0.59, 0.52 },
    text = { 0.90, 0.87, 0.78 },
    textMuted = { 0.55, 0.52, 0.45 },
    leather = { 0.13, 0.10, 0.07, 1 },
    leatherDark = { 0.07, 0.055, 0.04, 1 },
    page = { 0.04, 0.033, 0.025, 0.82 },
    pageHover = { 0.33, 0.26, 0.12, 1 },
    maroon = { 0.45, 0.10, 0.10, 1 },
    maroonHover = { 0.60, 0.16, 0.14, 1 },
}

-- The column's falloff palette, shared by the map sidebar and the settings
-- window so both surfaces fade the same way.
ns.Column = {
    pageTop = { 0.115, 0.093, 0.066 },
    pageBottom = { 0.045, 0.036, 0.027 },
    spineTop = { 0.075, 0.060, 0.043 },
    spineBottom = { 0.030, 0.024, 0.018 },
    pageFill = { 0.045, 0.037, 0.028, 1 },
}

ns.MEDIA = {
    white = "Interface\\Buttons\\WHITE8X8",
    checkbox = "Interface\\Buttons\\UI-CheckBox-Check",
    checkboxUp = "Interface\\Buttons\\UI-CheckBox-Up",
    checkboxHighlight = "Interface\\Buttons\\UI-CheckBox-Highlight",
    sliderBg = "Interface\\Buttons\\UI-SliderBar-Background",
    sliderThumb = "Interface\\Buttons\\UI-SliderBar-Button-Horizontal",
    buttonUp = "Interface\\Buttons\\UI-DialogBox-Button-Up",
    buttonDown = "Interface\\Buttons\\UI-DialogBox-Button-Down",
    buttonDisabled = "Interface\\Buttons\\UI-DialogBox-Button-Disabled",
    buttonHighlight = "Interface\\Buttons\\UI-DialogBox-Button-Highlight",
    minimapBg = "Interface\\Minimap\\UI-Minimap-Background",
    minimapHighlight = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
    trackingBorder = "Interface\\Minimap\\MiniMap-TrackingBorder",
    addonIcon = "Interface\\Icons\\INV_Misc_Map_01",
}

ns.Journal = {}
local Journal = ns.Journal
local fontCache = {}

-- Serif display face for the book feel; falls back to the client default if the
-- legacy font alias is unavailable on a given client build.
function Journal.Font(size, outline)
    local key = size .. ":" .. (outline or "")
    if not fontCache[key] then
        local font = CreateFont("ForeverWayfinderJournal" .. key:gsub("%W", "_"))
        -- SetFont's return value and failure behaviour vary between client
        -- builds, so verify the face the object actually holds afterwards.
        local ok = pcall(font.SetFont, font, "Fonts\\MORPHEUS.TTF", size, outline or "")
        local path = font.GetFont and font:GetFont()
        if not ok or type(path) ~= "string" or not path:lower():find("morpheus", 1, true) then
            pcall(font.SetFont, font, STANDARD_TEXT_FONT, size, outline or "")
        end
        fontCache[key] = font
    end
    return fontCache[key]
end

function Journal.Text(parent, size, text, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(Journal.Font(size))
    fs:SetText(text or "")
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    if justify then fs:SetJustifyH(justify) end
    return fs
end

-- List copy uses the client's own UI face: the serif display face loses
-- legibility at list sizes, so it stays reserved for headings.
function Journal.Body(parent, size, text, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(STANDARD_TEXT_FONT, size, "")
    fs:SetText(text or "")
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    if justify then fs:SetJustifyH(justify) end
    return fs
end

local function Solid(frame, color, layer)
    local tex = frame:CreateTexture(nil, layer or "BACKGROUND")
    tex:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    return tex
end
Journal.Solid = Solid

-- Atlas availability varies by client build; every atlas-based piece below keeps
-- a solid-art fallback so the windows render on any Forever build.
local function AtlasInfo(name)
    if C_Texture and C_Texture.GetAtlasInfo then
        return C_Texture.GetAtlasInfo(name)
    end
    return nil
end
Journal.AtlasInfo = AtlasInfo

-- Native dialog chrome: dark stone background inside the ornate gold diamond
-- border, the same pairing Questie and WhatsTraining use on this client.
function Journal.Decorate(frame)
    if AtlasInfo("UI-DialogBox-Background-Dark") and AtlasInfo("UI-DiamondDialogBox-Border") then
        local background = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        background:SetPoint("TOPLEFT", 7, -7)
        background:SetPoint("BOTTOMRIGHT", -7, 7)
        background:SetAtlas("UI-DialogBox-Background-Dark")
        local border = frame:CreateTexture(nil, "BACKGROUND", nil, -4)
        border:SetAllPoints()
        border:SetAtlas("UI-DiamondDialogBox-Border")
        return
    end
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = ns.MEDIA.white,
            edgeFile = ns.MEDIA.white,
            edgeSize = 2,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        frame:SetBackdropColor(ns.Colors.leather[1], ns.Colors.leather[2], ns.Colors.leather[3], 1)
        frame:SetBackdropBorderColor(ns.Colors.goldLine[1], ns.Colors.goldLine[2], ns.Colors.goldLine[3], 1)
    end
    local inner = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    inner:SetPoint("TOPLEFT", 6, -6)
    inner:SetPoint("BOTTOMRIGHT", -6, 6)
    if inner.SetBackdrop then
        inner:SetBackdrop({
            bgFile = ns.MEDIA.white, edgeFile = ns.MEDIA.white, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        inner:SetBackdropColor(0, 0, 0, 0)
        inner:SetBackdropBorderColor(ns.Colors.goldLine[1], ns.Colors.goldLine[2], ns.Colors.goldLine[3], 0.6)
    end
end

-- A dark inset page within the chrome, like the client's own options panels.
function Journal.Page(parent, left, top, right, bottom)
    local page = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    page:SetPoint("TOPLEFT", left, top)
    page:SetPoint("BOTTOMRIGHT", right, bottom)
    if page.SetBackdrop then
        page:SetBackdrop({
            bgFile = ns.MEDIA.white, edgeFile = ns.MEDIA.white, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        page:SetBackdropColor(ns.Colors.page[1], ns.Colors.page[2], ns.Colors.page[3], ns.Colors.page[4])
        page:SetBackdropBorderColor(ns.Colors.goldLine[1], ns.Colors.goldLine[2], ns.Colors.goldLine[3], 0.45)
    end
    return page
end

function Journal.Header(frame, height)
    local band = Solid(frame, ns.Colors.leatherDark)
    band:SetPoint("TOPLEFT", 10, -10)
    band:SetPoint("TOPRIGHT", -10, -10)
    band:SetHeight(height)
    local rule = Solid(frame, ns.Colors.goldLine)
    rule:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT", 0, 0)
    rule:SetHeight(1)
    return band
end

-- Classic red lacquer button with gold lettering, the client's own dialog art.
function Journal.Button(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    button:SetSize(width, 24)
    button.label = Journal.Text(button, 14, text, ns.Colors.gold)
    button.label:SetPoint("CENTER", 0, 1)
    button:SetFontString(button.label)

    local normal = button:CreateTexture(nil, "ARTWORK")
    if normal:SetTexture(ns.MEDIA.buttonUp) then
        button:SetNormalTexture(normal)
        button:SetPushedTexture(ns.MEDIA.buttonDown)
        button:SetDisabledTexture(ns.MEDIA.buttonDisabled)
        button:SetHighlightTexture(ns.MEDIA.buttonHighlight, "ADD")
        -- The source art carries an empty strip below the button face.
        for _, texture in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(),
            button:GetDisabledTexture(), button:GetHighlightTexture() }) do
            texture:SetTexCoord(0, 1, 0, 0.71875)
        end
    else
        normal:Hide()
        if button.SetBackdrop then
            button:SetBackdrop({
                bgFile = ns.MEDIA.white, edgeFile = ns.MEDIA.white, edgeSize = 1,
                insets = { left = 0, right = 0, top = 0, bottom = 0 },
            })
            button:SetBackdropColor(ns.Colors.maroon[1], ns.Colors.maroon[2], ns.Colors.maroon[3], 1)
            button:SetBackdropBorderColor(ns.Colors.goldLine[1], ns.Colors.goldLine[2], ns.Colors.goldLine[3], 1)
        end
        button:SetScript("OnEnter", function(self)
            if self.SetBackdropColor then
                self:SetBackdropColor(ns.Colors.maroonHover[1], ns.Colors.maroonHover[2], ns.Colors.maroonHover[3], 1)
            end
            self.label:SetTextColor(ns.Colors.brightGold[1], ns.Colors.brightGold[2], ns.Colors.brightGold[3])
        end)
        button:SetScript("OnLeave", function(self)
            if self.SetBackdropColor then
                self:SetBackdropColor(ns.Colors.maroon[1], ns.Colors.maroon[2], ns.Colors.maroon[3], 1)
            end
            self.label:SetTextColor(ns.Colors.gold[1], ns.Colors.gold[2], ns.Colors.gold[3])
        end)
    end
    button:SetScript("OnClick", onClick)
    return button
end

function Journal.Input(parent, width, height)
    local input = CreateFrame("EditBox", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    input:SetAutoFocus(false)
    input:SetSize(width, height)
    if input.SetBackdrop then
        input:SetBackdrop({
            bgFile = ns.MEDIA.white, edgeFile = ns.MEDIA.white, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        input:SetBackdropColor(0, 0, 0, 0.5)
        input:SetBackdropBorderColor(ns.Colors.goldLine[1], ns.Colors.goldLine[2], ns.Colors.goldLine[3], 0.5)
    end
    input:SetFont(STANDARD_TEXT_FONT, 13, "")
    input:SetTextColor(ns.Colors.text[1], ns.Colors.text[2], ns.Colors.text[3])
    input:SetTextInsets(8, 8, 0, 0)
    input:SetMaxLetters(80)
    input:HookScript("OnEditFocusGained", function(self)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(ns.Colors.brightGold[1], ns.Colors.brightGold[2], ns.Colors.brightGold[3], 0.8)
        end
    end)
    input:HookScript("OnEditFocusLost", function(self)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(ns.Colors.goldLine[1], ns.Colors.goldLine[2], ns.Colors.goldLine[3], 0.5)
        end
    end)
    return input
end

-- Horizontal slider with the client's minimal gold track and thumb.
function Journal.Slider(parent, width, minValue, maxValue, step)
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(width, 16)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetThumbTexture(ns.MEDIA.sliderThumb)
    local thumb = slider:GetThumbTexture()

    if thumb and AtlasInfo("Minimal_SliderBar_Button") and AtlasInfo("Minimal_SliderBar_Left")
        and AtlasInfo("Minimal_SliderBar_Right") and AtlasInfo("_Minimal_SliderBar_Middle") then
        thumb:SetAtlas("Minimal_SliderBar_Button", true)
        thumb:SetSize(16, 16)
        local trackLeft = slider:CreateTexture(nil, "BACKGROUND")
        trackLeft:SetAtlas("Minimal_SliderBar_Left", true)
        trackLeft:SetPoint("LEFT", slider, "LEFT", 0, 0)
        local trackRight = slider:CreateTexture(nil, "BACKGROUND")
        trackRight:SetAtlas("Minimal_SliderBar_Right", true)
        trackRight:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
        local trackMiddle = slider:CreateTexture(nil, "BACKGROUND")
        trackMiddle:SetAtlas("_Minimal_SliderBar_Middle", false)
        trackMiddle:SetPoint("LEFT", trackLeft, "RIGHT", 0, 0)
        trackMiddle:SetPoint("RIGHT", trackRight, "LEFT", 0, 0)
        trackMiddle:SetHeight(trackLeft:GetHeight())
    else
        local background = slider:CreateTexture(nil, "BACKGROUND")
        background:SetTexture(ns.MEDIA.sliderBg)
        background:SetAllPoints()
    end
    return slider
end

-- The client's own red close button; every Wayfinder window closes the same way.
function Journal.CloseButton(parent, onClick)
    local ok, button = pcall(CreateFrame, "Button", nil, parent, "UIPanelCloseButton")
    if ok and button and button:GetNormalTexture() then
        button:SetSize(22, 22)
        button:SetScript("OnClick", onClick)
        return button
    end
    button = CreateFrame("Button", nil, parent)
    button:SetSize(18, 18)
    button.fill = Solid(button, ns.Colors.maroon)
    button.fill:SetAllPoints()
    button.mark = Journal.Text(button, 11, "X", ns.Colors.gold)
    button.mark:SetPoint("CENTER", 0, 1)
    button:SetScript("OnEnter", function(self)
        self.fill:SetColorTexture(ns.Colors.maroonHover[1], ns.Colors.maroonHover[2],
            ns.Colors.maroonHover[3], 1)
        self.mark:SetTextColor(ns.Colors.brightGold[1], ns.Colors.brightGold[2], ns.Colors.brightGold[3])
    end)
    button:SetScript("OnLeave", function(self)
        self.fill:SetColorTexture(ns.Colors.maroon[1], ns.Colors.maroon[2], ns.Colors.maroon[3], 1)
        self.mark:SetTextColor(ns.Colors.gold[1], ns.Colors.gold[2], ns.Colors.gold[3])
    end)
    button:SetScript("OnClick", onClick)
    return button
end

--------------------------------------------------------------------------------------------
-- Cartographer's Column: the chrome shared by the map sidebar and the
-- settings window, so both surfaces read as one product.
--------------------------------------------------------------------------------------------

-- Four hairline rules that frame a rectangle. The client has no border widget
-- that survives a resize, and thin rules read as a printed map border.
function Journal.HairlineRect(parent, inset, color, alpha, layer)
    layer = layer or "OVERLAY"
    local rules = {}

    local function Rule()
        local tex = Solid(parent, color, layer)
        tex:SetAlpha(alpha or 1)
        rules[#rules + 1] = tex
        return tex
    end

    local top = Rule()
    top:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -inset)
    top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, -inset)
    top:SetHeight(1)

    local bottom = Rule()
    bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", inset, inset)
    bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset, inset)
    bottom:SetHeight(1)

    local left = Rule()
    left:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -inset)
    left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", inset, inset)
    left:SetWidth(1)

    local right = Rule()
    right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, -inset)
    right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset, inset)
    right:SetWidth(1)

    return rules
end

-- The client has no gradient primitive on this build, so a soft vertical
-- falloff is a stack of flat bands, re-laid out whenever the column changes
-- height. Each band spans the full width of its parent: a colour texture has
-- no intrinsic size, so without the right-hand anchor the band would be zero
-- pixels wide and the column would show the map through it.
function Journal.Bands(parent, count, color)
    local bands = {}
    for index = 1, count do
        local band = Solid(parent, color)
        band:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        band:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
        band:SetHeight(1)
        bands[index] = band
    end
    return bands
end

function Journal.LayoutBands(parent, bands, topColor, bottomColor, explicitHeight)
    local count = #bands
    if count == 0 or not parent then return end
    local height = explicitHeight or parent:GetHeight() or 0
    if height <= 0 then return end
    local bandHeight = math.floor(height / count)
    for index, band in ipairs(bands) do
        local t = count > 1 and (index - 1) / (count - 1) or 0
        local offset = (index - 1) * bandHeight
        band:ClearAllPoints()
        band:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -offset)
        band:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -offset)
        band:SetHeight(bandHeight)
        band:SetColorTexture(
            topColor[1] + (bottomColor[1] - topColor[1]) * t,
            topColor[2] + (bottomColor[2] - topColor[2]) * t,
            topColor[3] + (bottomColor[3] - topColor[3]) * t,
            1)
    end
    local last = bands[count]
    last:ClearAllPoints()
    last:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((count - 1) * bandHeight))
    last:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -((count - 1) * bandHeight))
    last:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
end

-- The branded rail that runs down the map-facing edge of a column: a gold
-- socket with the addon icon, vertical lettering, and a gold hairline that
-- separates the rail from the page.
function Journal.Spine(parent, word, width)
    local spine = CreateFrame("Frame", nil, parent)
    spine:SetPoint("TOPLEFT", 0, 0)
    spine:SetPoint("BOTTOMLEFT", 0, 0)
    spine:SetWidth(width)
    spine.bands = Journal.Bands(spine, 6, ns.Column.spineTop)

    local edge = Solid(parent, ns.Colors.goldLine)
    edge:SetPoint("TOPLEFT", spine, "TOPRIGHT", 0, 0)
    edge:SetPoint("BOTTOMLEFT", spine, "BOTTOMRIGHT", 0, 0)
    edge:SetWidth(1)
    edge:SetAlpha(0.55)

    local socket = CreateFrame("Frame", nil, spine)
    socket:SetSize(20, 20)
    socket:SetPoint("TOPLEFT", spine, "TOPLEFT", 4, -10)
    local socketFill = Solid(socket, ns.Colors.leatherDark)
    socketFill:SetAllPoints()
    Journal.HairlineRect(socket, 0, ns.Colors.goldLine, 0.9)
    local icon = socket:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ns.MEDIA.addonIcon)
    icon:SetSize(15, 15)
    icon:SetPoint("CENTER")

    -- Vertical lettering down the rail: the column names itself.
    local letters = {}
    for index = 1, #word do letters[index] = word:sub(index, index) end
    local label = Journal.Text(spine, 10, table.concat(letters, "\n"), ns.Colors.gold, "CENTER")
    label:SetWidth(width)
    label:SetPoint("TOPLEFT", spine, "TOPLEFT", 0, -42)
    label:SetJustifyH("CENTER")
    spine.label = label
    return spine
end

-- A leather band with a gold edge and a serif heading: the section marker in
-- the map ledger and in the settings window.
function Journal.SectionBand(parent, x, y, width, title, count)
    local band = CreateFrame("Frame", nil, parent)
    band:SetSize(width, 28)
    band:SetPoint("TOPLEFT", x, y)
    local fill = Solid(band, ns.Colors.leather)
    fill:SetAllPoints()
    fill:SetAlpha(0.55)
    local edge = Solid(band, ns.Colors.gold)
    edge:SetPoint("TOPLEFT", 0, -5)
    edge:SetPoint("BOTTOMLEFT", 0, 5)
    edge:SetWidth(2)

    band.heading = Journal.Text(band, 13, title:upper(), ns.Colors.gold, "LEFT")
    band.heading:SetPoint("LEFT", 12, 1)
    if count ~= nil then
        band.count = Journal.Body(band, 11, tostring(count), ns.Colors.goldLine, "RIGHT")
        band.count:SetPoint("RIGHT", -8, 0)
    end
    return band
end

-- A ledger row: the category glyph in a dark badge on the left, the label in
-- the middle and the state control on the right. The whole row is the click
-- target, so the control never has to be hit precisely.
function Journal.LedgerRow(parent, x, y, width, height, label, iconPath, getter, setter, labelSize)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, height)
    row:SetPoint("TOPLEFT", x, y)

    row.hover = Solid(row, ns.Colors.pageHover)
    row.hover:SetAllPoints()
    row.hover:SetAlpha(0)

    local textOffset = 8
    if iconPath then
        row.badge = CreateFrame("Frame", nil, row)
        row.badge:SetSize(20, 20)
        row.badge:SetPoint("LEFT", 6, 0)
        row.badgeFill = Solid(row.badge, ns.Colors.leatherDark)
        row.badgeFill:SetAllPoints()
        row.icon = row.badge:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(15, 15)
        row.icon:SetPoint("CENTER")
        row.icon:SetTexture(iconPath)
        textOffset = 34
    end

    row.label = Journal.Body(row, labelSize or 13, label, ns.Colors.text, "LEFT")
    row.label:SetPoint("LEFT", textOffset, 0)
    local labelWidth = math.max(width - textOffset - 30, 20)
    row.label:SetWidth(labelWidth)
    if row.label.SetWordWrap then row.label:SetWordWrap(false) end
    -- A long label is trimmed instead of running under the checkbox.
    Journal.FitText(row.label, label, labelWidth)

    local ok, box = pcall(CreateFrame, "CheckButton", nil, row, "SettingsCheckboxTemplate")
    if not ok or not box or not box:GetNormalTexture() then
        box = CreateFrame("CheckButton", nil, row)
        box:SetNormalTexture(ns.MEDIA.checkboxUp)
        box:SetCheckedTexture(ns.MEDIA.checkbox)
        box:SetHighlightTexture(ns.MEDIA.checkboxHighlight)
    end
    box:SetSize(20, 20)
    box:SetPoint("RIGHT", -6, 0)
    box:EnableMouse(false)
    row.box = box

    function row:Refresh()
        local enabled = getter()
        self.box:SetChecked(enabled)
        local color = enabled and ns.Colors.text or ns.Colors.textMuted
        self.label:SetTextColor(color[1], color[2], color[3])
    end

    row:SetScript("OnEnter", function(self) self.hover:SetAlpha(0.45) end)
    row:SetScript("OnLeave", function(self) self.hover:SetAlpha(0) end)
    row:SetScript("OnClick", function(self)
        setter(not getter())
        self:Refresh()
        ns:Refresh()
    end)
    row:Refresh()
    return row
end

-- Font strings wrap by default, and a wrapped row spills into the row below
-- it. Trim the label to the room the row gives it so every line stays single
-- line and the right-hand column keeps its place.
function Journal.FitText(fontString, text, maxWidth)
    if type(text) ~= "string" or text == "" then
        if fontString and fontString.SetText then fontString:SetText(text or "") end
        return text or ""
    end
    fontString:SetText(text)
    if type(fontString.GetStringWidth) ~= "function" then return text end
    local ok, width = pcall(fontString.GetStringWidth, fontString)
    if not ok or type(width) ~= "number" or width <= maxWidth then return text end
    local keep = math.max(1, math.floor((maxWidth / width) * #text) - 1)
    while keep >= 1 do
        local candidate = text:sub(1, keep) .. "…"
        fontString:SetText(candidate)
        local cutOk, cutWidth = pcall(fontString.GetStringWidth, fontString)
        if cutOk and type(cutWidth) == "number" and cutWidth <= maxWidth then
            return candidate
        end
        keep = keep - 1
    end
    fontString:SetText(text)
    return text
end

-- The client's scrollbar carries buttons and a wide thumb; the column wants a
-- slim gold rule instead.
function Journal.SkinScrollBar(scroll)
    local bar = scroll.ScrollBar
    if not bar and scroll.GetName then
        local name = scroll:GetName()
        if name then bar = _G[name .. "ScrollBar"] end
    end
    if not bar then return end
    if bar.ScrollUpButton then bar.ScrollUpButton:Hide() end
    if bar.ScrollDownButton then bar.ScrollDownButton:Hide() end
    local thumb = bar.ThumbTexture
    if thumb then
        thumb:SetTexture(ns.MEDIA.white)
        thumb:SetVertexColor(ns.Colors.goldLine[1], ns.Colors.goldLine[2], ns.Colors.goldLine[3], 0.45)
        if thumb.SetWidth then thumb:SetWidth(5) end
    end
    if bar.SetWidth then bar:SetWidth(8) end
    return bar
end

--------------------------------------------------------------------------------------------
-- Categories
--------------------------------------------------------------------------------------------

-- Icons use paths that ship with the Forever client. Service categories lean on the
-- built-in tracking textures so a pin reads at a glance on the world map.
ns.categoryList = {
    -- Services
    { key = "vendor", group = "services", name = "Vendors", icon = "Interface\\Icons\\INV_Misc_Bag_10" },
    { key = "repair", group = "services", name = "Repair", icon = "Interface\\Icons\\Trade_BlackSmithing" },
    { key = "innkeeper", group = "services", name = "Innkeepers", icon = "Interface\\Icons\\INV_Misc_Food_15" },
    { key = "mailbox", group = "services", name = "Mailboxes", icon = "Interface\\Minimap\\tracking\\mailbox" },
    { key = "auctioneer", group = "services", name = "Auctioneers", icon = "Interface\\Icons\\INV_Misc_Coin_01" },
    { key = "banker", group = "services", name = "Bankers", icon = "Interface\\Icons\\INV_Misc_Coin_02" },
    { key = "flight", group = "services", name = "Flight Masters", icon = "Interface\\Minimap\\tracking\\flightmaster" },
    { key = "stable", group = "services", name = "Stable Masters", icon = "Interface\\Minimap\\tracking\\stablemaster" },

    -- Trainers
    { key = "classTrainer", group = "trainers", name = "Class Trainers", icon = "Interface\\Minimap\\tracking\\class" },
    { key = "portal", group = "trainers", name = "Portal Trainers", icon = "Interface\\Minimap\\vehicle-alliancemageportal" },
    { key = "weapon", group = "trainers", name = "Weapon Masters", icon = "Interface\\Icons\\INV_Sword_04" },
    { key = "pet", group = "trainers", name = "Battle Pet Trainers", icon = "Interface\\Icons\\Ability_Hunter_BeastCall" },
    { key = "otherTrainer", group = "trainers", name = "Other Trainers", icon = "Interface\\Icons\\INV_Misc_Book_11" },

    -- Profession trainers keep their own group so they can be filtered apart
    -- from class, portal and battle pet trainers.
    { key = "profession", group = "professions", name = "Profession Trainers", icon = "Interface\\Minimap\\tracking\\profession" },

    -- Other points of interest
    { key = "spirit", group = "other", name = "Spirit Healers", icon = "Interface\\raidframe\\raid-icon-rez" },
    { key = "battlemaster", group = "other", name = "Battlemasters", icon = "Interface\\Icons\\INV_Banner_02" },
    { key = "barber", group = "other", name = "Barbers", icon = "Interface\\Icons\\INV_Misc_Comb_01" },
    { key = "transmog", group = "other", name = "Transmogrifiers", icon = "Interface\\Minimap\\tracking\\transmogrifier" },
    { key = "tabard", group = "other", name = "Tabard Designers", icon = "Interface\\Icons\\INV_Shirt_GuildTabard_01" },
}

ns.categoryByKey = {}
for _, category in ipairs(ns.categoryList) do
    ns.categoryByKey[category.key] = category
end

-- Short labels for the map sidebar's category chips. The full name is kept
-- for the tooltip, the section band and the settings window.
ns.categoryShort = {
    vendor = "Vendors", repair = "Repair", innkeeper = "Inns", mailbox = "Mailboxes",
    auctioneer = "Auctioneers", banker = "Bankers", flight = "Flight", stable = "Stable",
    classTrainer = "Class", portal = "Portal", weapon = "Weapon", pet = "Battle Pets",
    otherTrainer = "Other", profession = "Professions", spirit = "Spirit",
    battlemaster = "Battlemasters", barber = "Barbers", transmog = "Transmog",
    tabard = "Tabards",
}

-- Used to pick one icon when a node belongs to several enabled categories. Specific service
-- roles win over the generic vendor flag, trainers win over vendors.
ns.iconPriority = {
    "repair", "auctioneer", "banker", "innkeeper", "stable", "flight", "mailbox",
    "portal", "profession", "classTrainer", "weapon", "pet", "otherTrainer",
    "vendor", "spirit", "battlemaster", "barber", "transmog", "tabard",
}

ns.categoryGroups = {
    { key = "services", title = "SERVICES", chip = "SERVICES", keys = { "vendor", "repair", "innkeeper", "mailbox", "auctioneer", "banker", "flight", "stable" } },
    { key = "trainers", title = "TRAINERS", chip = "TRAINERS", keys = { "classTrainer", "portal", "weapon", "pet", "otherTrainer" } },
    { key = "professions", title = "PROFESSION TRAINERS", chip = "PROFESSIONS", keys = { "profession" } },
    { key = "other", title = "OTHER POINTS OF INTEREST", chip = "OTHER", keys = { "spirit", "battlemaster", "barber", "transmog", "tabard" } },
}

-- One source of truth for the group names. The sidebar chips, the settings
-- bands and the status lines all read these, so the three surfaces cannot
-- drift apart when a group is renamed or added.
ns.groupOrder = { "all" }
ns.groupInfo = {
    all = { title = "ALL LOCATIONS", chip = "ALL", short = "All" },
}
for index = 1, #ns.categoryGroups do
    local group = ns.categoryGroups[index]
    ns.groupOrder[#ns.groupOrder + 1] = group.key
    ns.groupInfo[group.key] = {
        title = group.title,
        chip = group.chip or group.title,
        short = group.chip or group.title,
    }
end

-- The keys of one group, in the order the sidebar lists them.
function ns.GetGroupKeys(groupKey)
    for index = 1, #ns.categoryGroups do
        local group = ns.categoryGroups[index]
        if group.key == groupKey then return group.keys or {} end
    end
    return {}
end

ns.defaultCategories = {
    vendor = true,
    repair = true,
    innkeeper = true,
    mailbox = true,
    auctioneer = true,
    banker = true,
    flight = true,
    stable = true,
    classTrainer = true,
    profession = true,
    portal = true,
    weapon = true,
    pet = true,
    otherTrainer = true,
    spirit = true,
    battlemaster = true,
    barber = true,
    transmog = true,
    tabard = true,
}

ns.defaults = {
    enabled = true,
    showWorldMap = true,
    showMinimap = true,
    showOnContinent = false,
    factionFilter = true,
    pinScale = 1.0,
    minimapAngle = 220,
    showMinimapButton = true,
    browserEnabled = true,
    browserMode = "map",
    browserGroup = "all",
    browserCollapsed = false,
    browserCoords = true,
    browserNearMe = false,
}

--------------------------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------------------------

local band
if bit and bit.band then
    band = bit.band
else
    function band(a, b)
        local result, place = 0, 1
        while a > 0 and b > 0 do
            if a % 2 == 1 and b % 2 == 1 then result = result + place end
            a = floor(a / 2)
            b = floor(b / 2)
            place = place * 2
        end
        return result
    end
end
ns.band = band

function ns:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(self.PREFIX .. " " .. tostring(message))
end

-- Show diagnostic output in a selectable edit box. WoW does not expose a general
-- clipboard API to addons, but EditBox text can be copied with Ctrl+A / Ctrl+C.
function ns:ShowCopyableReport(title, lines)
    if not self.copyReportFrame then
        local frame = CreateFrame("Frame", "ForeverWayfinderCopyReportFrame", UIParent,
            BackdropTemplateMixin and "BackdropTemplate" or nil)
        frame:SetSize(760, 520)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetClampedToScreen(true)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        Journal.Decorate(frame)

        local heading = Journal.Text(frame, 18, "", ns.Colors.gold, "LEFT")
        heading:SetPoint("TOPLEFT", 20, -18)
        frame.heading = heading

        local instructions = Journal.Body(frame, 12,
            "Click the report, press Ctrl+A, then Ctrl+C to copy. Press Esc to close.", ns.Colors.muted, "LEFT")
        instructions:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)

        local close = Journal.CloseButton(frame, function() frame:Hide() end)
        close:SetPoint("TOPRIGHT", -12, -12)

        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 18, -76)
        scroll:SetPoint("BOTTOMRIGHT", -38, 18)

        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(690)
        edit:SetTextInsets(6, 6, 6, 6)
        edit:SetScript("OnEscapePressed", function() frame:Hide() end)
        edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        scroll:SetScrollChild(edit)

        frame.editBox = edit
        frame.scrollFrame = scroll
        self.copyReportFrame = frame
    end

    local frame = self.copyReportFrame
    frame.heading:SetText(title or "Forever Wayfinder Report")
    local text = table.concat(lines or {}, "\n")
    frame.editBox:SetText(text)
    frame.editBox:SetHeight(math.max(480, (select(2, text:gsub("\n", "")) + 2) * 16))
    frame:Show()
    frame.editBox:SetFocus()
    frame.editBox:HighlightText()
end

function ns:CopyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = value
        end
    end
end

local DEFAULT_VENDOR_ICON = "Interface\\Icons\\INV_Misc_Bag_10"

function ns:GetNodeIcon(node)
    local categories = self.db.categories
    -- Most vendors can also repair, which would otherwise paint them all with the anvil.
    -- When the vendor's stock is known, show what they sell instead of the incidental service.
    local showVendorStock = categories.vendor and node.vendorIcon

    for index = 1, #self.iconPriority do
        local key = self.iconPriority[index]
        if node.cats[key] and categories[key] then
            if not (key == "repair" and showVendorStock) then
                if key == "vendor" then
                    return node.vendorIcon or DEFAULT_VENDOR_ICON
                end
                return self.categoryByKey[key].icon
            end
        end
    end
    return nil
end

function ns:GetNodeTitle(node)
    local entry = node.entries[1]
    if not entry then return "Service NPC" end
    if entry.sub and entry.sub ~= "" then
        return entry.name .. " - " .. entry.sub
    end
    return entry.name
end

function ns:GetNodeCategoryNames(node, onlyEnabled)
    local names = {}
    for index = 1, #self.categoryList do
        local category = self.categoryList[index]
        if node.cats[category.key] and (not onlyEnabled or self.db.categories[category.key]) then
            names[#names + 1] = category.name
        end
    end
    return table.concat(names, " · ")
end

function ns:GetNode(mapID, coord)
    local map = self.index and self.index[mapID]
    return map and map[coord]
end

--------------------------------------------------------------------------------------------
-- Saved variables
--------------------------------------------------------------------------------------------

local VALID_POSITION_ANCHORS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
    RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

-- Normalises a saved window position, or returns nil when the table is
-- corrupted. Shared by the settings window and the map browser.
function ns:ValidateSavedPosition(position)
    if type(position) ~= "table" or not VALID_POSITION_ANCHORS[position.point] then return nil end
    local x, y = position.x, position.y
    if type(x) ~= "number" or x ~= x or x == math.huge or x == -math.huge then return nil end
    if type(y) ~= "number" or y ~= y or y == math.huge or y == -math.huge then return nil end
    return {
        point = position.point,
        relativePoint = VALID_POSITION_ANCHORS[position.relativePoint] and position.relativePoint or position.point,
        x = x,
        y = y,
        relative = position.relative == "ui" and "ui" or "frame",
    }
end

function ns:InitDB()
    if type(ForeverWayfinderDB) ~= "table" then ForeverWayfinderDB = {} end
    local db = ForeverWayfinderDB
    -- The old flag was inverted; move the user's choice to the positive name
    -- before the defaults are filled in.
    if type(db.hideMinimapButton) == "boolean" then
        db.showMinimapButton = not db.hideMinimapButton
        db.hideMinimapButton = nil
    end
    self:CopyDefaults(db, self.defaults)
    if type(db.categories) ~= "table" then db.categories = {} end
    self:CopyDefaults(db.categories, self.defaultCategories)

    local booleanKeys = { "enabled", "showWorldMap", "showMinimap", "showOnContinent",
        "factionFilter", "showMinimapButton", "browserEnabled", "browserCollapsed",
        "browserCoords", "browserNearMe" }
    for i = 1, #booleanKeys do
        local key = booleanKeys[i]
        if type(db[key]) ~= "boolean" then db[key] = self.defaults[key] end
    end
    if db.browserMode ~= "map" and db.browserMode ~= "all" then
        db.browserMode = self.defaults.browserMode
    end
    if not self.groupInfo[db.browserGroup] then
        db.browserGroup = self.defaults.browserGroup
    end
    -- The category filter is optional; an unknown key is dropped rather than
    -- resetting the group it was chosen from.
    if type(db.browserCategory) ~= "string" or not self.categoryByKey[db.browserCategory] then
        db.browserCategory = nil
    end
    for key, defaultValue in pairs(self.defaultCategories) do
        if type(db.categories[key]) ~= "boolean" then db.categories[key] = defaultValue end
    end
    if type(db.pinScale) ~= "number" or db.pinScale ~= db.pinScale
        or db.pinScale == math.huge or db.pinScale == -math.huge then
        db.pinScale = self.defaults.pinScale
    else
        db.pinScale = math.max(0.5, math.min(1.5, db.pinScale))
    end
    if type(db.minimapAngle) ~= "number" or db.minimapAngle ~= db.minimapAngle
        or db.minimapAngle == math.huge or db.minimapAngle == -math.huge then
        db.minimapAngle = self.defaults.minimapAngle
    else
        db.minimapAngle = db.minimapAngle % 360
    end
    db.uiPosition = self:ValidateSavedPosition(db.uiPosition)
    db.browserPosition = self:ValidateSavedPosition(db.browserPosition)
    self.db = db
end

function ns:ResetSettings()
    local db = self.db
    local refilter = db.factionFilter ~= self.defaults.factionFilter
    for key in pairs(db) do
        if key ~= "uiPosition" and key ~= "minimapAngle" and key ~= "browserPosition" then
            db[key] = nil
        end
    end
    self:CopyDefaults(db, self.defaults)
    db.categories = {}
    self:CopyDefaults(db.categories, self.defaultCategories)
    self:Refresh()
    if self.UpdateUI then self:UpdateUI() end
    if self.browser and self.browser.ApplyLayout then self.browser:ApplyLayout() end
    -- Reset can flip the browser group, sort and collapse state; restyle the
    -- chips and re-render so the panel never shows pre-reset state.
    if self.browser and self.browser.ScheduleRefresh then self.browser:ScheduleRefresh(0) end
    -- Faction filtering happens while indexing, so rebuild when the reset
    -- changed it and pins would otherwise keep the old filter.
    if refilter and self.StartScan then self:StartScan() end
    self:Print("Settings reset to defaults.")
end

--------------------------------------------------------------------------------------------
-- QuestieDB / HandyNotes availability
--------------------------------------------------------------------------------------------

function ns:CheckDependencies()
    local lib = _G.LibQuestieDB
    if not lib then
        return false, "QuestieDB is not loaded."
    end
    if type(lib.RequireContract) ~= "function" then
        return false, "QuestieDB is missing the public API. Update QuestieDB."
    end

    local ok, message = lib.RequireContract(4)
    if not ok then
        return false, message or "QuestieDB contract mismatch."
    end

    if not NpcDB or not ObjectDB then
        return false, "QuestieDB did not expose NpcDB/ObjectDB."
    end
    if not HandyNotes or not HandyNotes.RegisterPluginDB then
        return false, "HandyNotes is not loaded."
    end

    if self.BuildZoneMap then
        local callOk, zonesOk, zoneMessage = pcall(self.BuildZoneMap, self)
        if not callOk then
            return false, "QuestieDB zone map initialization failed: " .. tostring(zonesOk)
        end
        if not zonesOk then
            return false, zoneMessage or "QuestieDB zone data could not be read."
        end
    end

    return true
end

--------------------------------------------------------------------------------------------
-- Refresh
--------------------------------------------------------------------------------------------

function ns:Refresh()
    if self.blocked then return end

    if HandyNotes and HandyNotes.UpdatePluginMap then
        HandyNotes:UpdatePluginMap(nil, self.PLUGIN)
    end
    if self.UpdateMinimapButton then
        self:UpdateMinimapButton()
    end
    if self.UpdateUIStatus then
        self:UpdateUIStatus()
    end
    if self.browser then
        self.browser:ScheduleRefresh(0)
    end
end

--------------------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------------------

local function PrintHelp()
    ns:Print("Commands:")
    ns:Print("  /fw - open or close the settings panel")
    ns:Print("  /fw on | off - enable or disable all pins")
    ns:Print("  /fw refresh - rebuild the NPC index")
    ns:Print("  /fw reset - restore default settings")
    ns:Print("  /fw search - search NPCs by name, category, or zone")
    ns:Print("  /fw browse - open or close the world map location browser (this map or all zones)")
    ns:Print("  /fw find [text] - open the map and focus the location filter")
    ns:Print("  /fw clear - clear the last Forever Wayfinder waypoint")
    ns:Print("  /fw status - show index statistics")
    ns:Print("  /fw icon - diagnose the world map icon stack and spacing")
    ns:Print("  /fw map - diagnose map pins for the current map")
end

local function SlashOn()
    ns.db.enabled = true
    ns:Refresh()
    ns:Print("Pins enabled.")
end

local function SlashOff()
    ns.db.enabled = false
    ns:Refresh()
    ns:Print("Pins disabled.")
end

local function SlashRefresh()
    ns:StartScan()
    ns:Print("Rebuilding the NPC index.")
end

local function SlashReset()
    ns:ResetSettings()
end

local function SlashSearch()
    if ns.ToggleSearchUI then ns:ToggleSearchUI() end
end

local function SlashBrowse()
    if ns.ToggleBrowser then ns:ToggleBrowser() end
end

local function SlashFind(raw)
    -- The query keeps its case while the command word is lowercased.
    local text = raw:match("^%S+%s*(.*)$") or ""
    if ns.FocusBrowserFilter then ns:FocusBrowserFilter(text) end
end

local function SlashClear()
    local ok, reason = ns.Waypoints:ClearLast()
    ns:Print(ok and "Waypoint cleared." or reason)
end

local function SlashStatus()
    local lines = {}
    local function ReportLine(text)
        text = tostring(text)
        lines[#lines + 1] = text
        ns:Print(text)
    end

    if ns.browser and ns.browser.panel then
        -- Name the dock the panel is really using right now: the quest
        -- sidebar only appears while the player has a quest tracked.
        local dock = "world map"
        local liveSidebar = ns.GetQuestSidebar and ns.GetQuestSidebar()
        if liveSidebar then
            dock = "quest sidebar"
        elseif ns.db.browserPosition then
            dock = "custom position"
        end
        local groupLabel = ns.groupInfo[ns.db.browserGroup]
            and ns.groupInfo[ns.db.browserGroup].short or ns.db.browserGroup
        ReportLine(("Browser: %s, %s, %s group, %s, %s dock."):format(
            ns.db.browserCollapsed and "collapsed" or "expanded",
            ns.db.browserMode == "all" and "all zones" or "this map",
            groupLabel,
            ns.db.browserNearMe and "near me" or "by name",
            dock))
    end

    local scan = ns.scan
    if ns.blocked then
        ReportLine("Disabled: " .. ns.blocked)
    elseif not ns.ready then
        local status = "Indexing"
        if scan then
            status = status .. (" (%d / %d NPCs"):format(scan.npcPos - 1, #scan.npcIds)
            if scan.phase == "objects" then
                status = status .. (", %d / %d objects"):format(scan.objPos - 1, #scan.objIds)
            end
            status = status .. ")"
        elseif ns.lastScan and ns.lastScan.state then
            status = status .. " (last scan: " .. ns.lastScan.state .. ")"
        end
        ReportLine(status)
        if ns.lastScan and ns.lastScan.reason then ReportLine(ns.lastScan.reason) end
    else
        ReportLine(("%d pins across %d maps from %d NPCs and %d mailboxes."):format(
            ns.stat.nodes, ns.stat.mapCount, ns.stat.npcs, ns.stat.mailboxes))
        ReportLine(("%d invalid records, %d invalid spawns, %d unavailable positions, %d suppressed spawns, %d unmapped areas."):format(
            ns.stat.invalidRecords or 0, ns.stat.invalidSpawns or 0,
            ns.stat.unavailablePositions or 0, ns.stat.suppressedSpawns or 0, ns.stat.unmappedAreas or 0))
        for reason, count in pairs(ns.stat.invalidSpawnReasons or {}) do
            ReportLine(("Invalid spawn reason: %s = %d"):format(reason, count))
        end
        for index, item in ipairs(ns.stat.invalidSpawnSamples or {}) do
            ReportLine(("Invalid spawn %d: %s (NPC/Object %s), zone %s, map %s, x=%s, y=%s, reason=%s"):format(
                index, tostring(item.name), tostring(item.id), tostring(item.zoneID),
                tostring(item.mapID), tostring(item.x), tostring(item.y), tostring(item.reason)))
        end
        for index, item in ipairs(ns.stat.unavailablePositionSamples or {}) do
            ReportLine(("Unavailable position %d: %s (NPC/Object %s), area %s, map %s; QuestieDB has no coordinates."):format(
                index, tostring(item.name), tostring(item.id), tostring(item.zoneID), tostring(item.mapID)))
        end
        for index, item in ipairs(ns.stat.unmappedAreaSamples or {}) do
            ReportLine(("Unmapped area %d: %s (NPC/Object %s), area %s, spawn records %d"):format(
                index, tostring(item.name), tostring(item.id), tostring(item.areaID), item.spawnCount or 0))
        end
        if ns.lastScan then
            ReportLine(("Last scan: %s; enumeration %.3fs; duration %.3fs; NPC errors %d; object errors %d."):format(
                ns.lastScan.state or "unknown", ns.lastScan.enumerationDuration or 0,
                ns.lastScan.duration or 0, ns.stat.npcErrors or 0, ns.stat.objectErrors or 0))
            ReportLine(("Max scan slice: %.4fs / %d records."):format(
                ns.lastScan.maxSliceDuration or 0, ns.lastScan.maxSliceProcessed or 0))
            for index, item in ipairs(ns.lastScan.errors or {}) do
                ReportLine(("Sample error %d (%s %s): %s"):format(
                    index, item.kind, tostring(item.id), item.message))
            end
        end
        if ns.cancelledScan then
            ReportLine(("Interrupted scan: %s after %.3fs."):format(
                ns.cancelledScan.state, ns.cancelledScan.duration or 0))
        end
    end
    ns:ShowCopyableReport("Forever Wayfinder - Status", lines)
end

local function SlashIcon()
    local browser = ns.browser
    if not browser or not browser.DescribeIcon then
        ns:Print("Open the world map once, then run /fw icon again.")
        return
    end
    local lines = browser:DescribeIcon()
    for _, line in ipairs(lines) do ns:Print(line) end
end

local function SlashMap()
    local lines = {}
    local function ReportLine(msg)
        msg = tostring(msg)
        lines[#lines + 1] = msg
        ns:Print(msg)
    end
    local function Safe(label, fn)
        local ok, a = pcall(fn)
        if ok then return a end
        ReportLine(label .. " ERROR: " .. tostring(a))
        return nil
    end

    ReportLine(("ready=%s enabled=%s showWorldMap=%s showMinimap=%s showOnContinent=%s"):format(
        tostring(ns.ready), tostring(ns.db and ns.db.enabled), tostring(ns.db and ns.db.showWorldMap),
        tostring(ns.db and ns.db.showMinimap), tostring(ns.db and ns.db.showOnContinent)))
    ReportLine(("blocked=%s registered=%s plugin=%s"):format(
        tostring(ns.blocked), tostring(ns.registered), tostring(ns.PLUGIN)))
    if ns.lastScan then ReportLine("lastScan=" .. tostring(ns.lastScan.state)) end

    if HandyNotes then
        ReportLine(("HandyNotes enabled=%s pluginRegistered=%s"):format(
            tostring(HandyNotes.IsEnabled and HandyNotes:IsEnabled()),
            tostring(HandyNotes.plugins and HandyNotes.plugins[ns.PLUGIN] ~= nil)))
        local enabledPlugins = HandyNotes.db and HandyNotes.db.profile and HandyNotes.db.profile.enabledPlugins
        if enabledPlugins then
            ReportLine("enabledPlugins[plugin]=" .. tostring(enabledPlugins[ns.PLUGIN]))
        end
        local provider = HandyNotes.WorldMapDataProvider
        if provider and WorldMapFrame and WorldMapFrame.dataProviders then
            ReportLine("worldMapProviderRegistered=" .. tostring(WorldMapFrame.dataProviders[provider] ~= nil))
        end
    else
        ReportLine("HandyNotes missing")
    end

    local wmID = WorldMapFrame and WorldMapFrame.GetMapID and
        Safe("WorldMapFrame:GetMapID", function() return WorldMapFrame:GetMapID() end)
    local playerID = Safe("GetBestMapForUnit", function() return C_Map.GetBestMapForUnit("player") end)
    ReportLine(("worldMapShown=%s worldMapID=%s playerMapID=%s"):format(
        tostring(WorldMapFrame and WorldMapFrame:IsShown()), tostring(wmID), tostring(playerID)))

    local target = wmID or playerID
    if target then
        local info = Safe("GetMapInfo", function() return C_Map.GetMapInfo(target) end)
        if info then
            ReportLine(("target map %s: name=%s type=%s parent=%s"):format(
                tostring(target), tostring(info.name), tostring(info.mapType), tostring(info.parentMapID)))
        end
        local nodeCount = 0
        if ns.index and ns.index[target] then
            for _ in pairs(ns.index[target]) do nodeCount = nodeCount + 1 end
        end
        ReportLine(("index[%s] nodes=%d"):format(tostring(target), nodeCount))

        local maps = Safe("GetMapsFor", function() return ns:GetMapsFor(target, false) end)
        if maps then
            ReportLine(("GetMapsFor -> %d maps: %s"):format(#maps, table.concat(maps, ",")))
            local iterOk, iter, state, var = pcall(ns.MakeNodeIterator, ns, maps)
            if not iterOk then
                ReportLine("MakeNodeIterator ERROR: " .. tostring(iter))
            else
                local yielded, samples = 0, {}
                local loopOk, loopErr = pcall(function()
                    for coord, mapID, icon in iter, state, var do
                        yielded = yielded + 1
                        if #samples < 5 then
                            samples[#samples + 1] = ("coord=%s map=%s icon=%s"):format(
                                tostring(coord), tostring(mapID), tostring(icon))
                        end
                        if yielded >= 500 then break end
                    end
                end)
                ReportLine(("iterator yielded=%d%s"):format(
                    yielded, (not loopOk) and (" ERROR: " .. tostring(loopErr)) or ""))
                for _, s in ipairs(samples) do ReportLine("  " .. s) end
            end
        end
    end

    if ns.db and ns.db.categories then
        local enabledCats = {}
        for key, value in pairs(ns.db.categories) do
            if value == true then enabledCats[#enabledCats + 1] = key end
        end
        table.sort(enabledCats)
        ReportLine("enabled categories: " .. table.concat(enabledCats, ","))
    end
    if target and ns.index and ns.index[target] then
        local catTally, skippedTally = {}, {}
        local total, withIcon, skipped = 0, 0, 0
        local skippedSamples = {}
        for _, node in pairs(ns.index[target]) do
            total = total + 1
            for key in pairs(node.cats or {}) do
                catTally[key] = (catTally[key] or 0) + 1
            end
            if ns:GetNodeIcon(node) then
                withIcon = withIcon + 1
            else
                skipped = skipped + 1
                local keys = {}
                for key in pairs(node.cats or {}) do
                    keys[#keys + 1] = key
                    skippedTally[key] = (skippedTally[key] or 0) + 1
                end
                if #skippedSamples < 6 then
                    local first = node.entries and node.entries[1]
                    skippedSamples[#skippedSamples + 1] = ("%s cats=[%s]"):format(
                        (first and first.name) or "?", table.concat(keys, ","))
                end
            end
        end
        ReportLine(("target nodes: total=%d withIcon=%d skipped=%d"):format(total, withIcon, skipped))
        local catParts = {}
        for key, count in pairs(catTally) do catParts[#catParts + 1] = key .. "=" .. count end
        table.sort(catParts)
        ReportLine("node cats: " .. table.concat(catParts, " "))
        local skipParts = {}
        for key, count in pairs(skippedTally) do skipParts[#skipParts + 1] = key .. "=" .. count end
        table.sort(skipParts)
        ReportLine("skipped-node cats: " .. table.concat(skipParts, " "))
        for _, s in ipairs(skippedSamples) do ReportLine("  skipped: " .. s) end
    end

    local sampleMaps = {}
    if ns.index then
        for mapID in pairs(ns.index) do
            sampleMaps[#sampleMaps + 1] = mapID
            if #sampleMaps >= 25 then break end
        end
        table.sort(sampleMaps)
    end
    ReportLine("index mapIDs sample: " .. table.concat(sampleMaps, ","))

    local tester = CreateFrame("Frame")
    local tex = tester:CreateTexture(nil, "ARTWORK")
    local badIcons, seen = {}, {}
    for _, category in ipairs(ns.categoryList) do
        local icon = category.icon
        if icon and not seen[icon] then
            seen[icon] = true
            if not tex:SetTexture(icon) then
                badIcons[#badIcons + 1] = category.key .. "=" .. icon
            end
        end
    end
    if not tex:SetTexture("Interface\\Icons\\INV_Misc_Bag_10") then
        badIcons[#badIcons + 1] = "defaultVendor=Interface\\Icons\\INV_Misc_Bag_10"
    end
    tester:Hide()
    ReportLine(("icon check: %d invalid%s"):format(
        #badIcons, #badIcons > 0 and (": " .. table.concat(badIcons, "; ")) or ""))

    if HandyNotes and HandyNotes.WorldMapDataProvider and WorldMapFrame and WorldMapFrame:IsShown() then
        local ok, err = pcall(HandyNotes.WorldMapDataProvider.RefreshPlugin,
            HandyNotes.WorldMapDataProvider, ns.PLUGIN)
        ReportLine("RefreshPlugin direct: " .. (ok and "ok" or ("ERROR: " .. tostring(err))))
    end

    ns:ShowCopyableReport("Forever Wayfinder - Map", lines)
end

-- One entry per command; the dispatcher only has to find the handler.
local SLASH_COMMANDS = {
    on = SlashOn,
    off = SlashOff,
    refresh = SlashRefresh,
    reset = SlashReset,
    search = SlashSearch,
    browse = SlashBrowse,
    find = SlashFind,
    clear = SlashClear,
    status = SlashStatus,
    icon = SlashIcon,
    map = SlashMap,
}

local function HandleSlash(message)
    local raw = (message or ""):match("^%s*(.-)%s*$")
    local command = raw:lower()

    if command == "" then
        ns:ToggleUI()
        return
    end

    local handler = SLASH_COMMANDS[command]
    if handler then
        handler(raw)
        return
    end

    -- "/fw find <text>" carries an argument, so it does not match the table.
    if command:match("^find%s") then
        SlashFind(raw)
        return
    end

    PrintHelp()
end

SLASH_FOREVERWAYFINDER1 = "/fw"
SLASH_FOREVERWAYFINDER2 = "/foreverwayfinder"
SlashCmdList.FOREVERWAYFINDER = HandleSlash

--------------------------------------------------------------------------------------------
-- Startup
--------------------------------------------------------------------------------------------

function ns:Init()
    if self.initialized then return end
    self.initialized = true

    self:InitDB()

    local ok, reason = self:CheckDependencies()
    if not ok then
        self.blocked = reason
        self.lastScan = { state = "blocked", reason = reason }
        self:Print("Disabled: " .. reason)
        if self.CreateUI then self:CreateUI() end
        return
    end

    if self.ResetIndex then
        self:ResetIndex()
    else
        self.index = {}
        self.descCache = {}
        self.stat = { nodes = 0, mapCount = 0, npcs = 0, mailboxes = 0 }
        self.ready = false
    end

    self:RegisterHandyNotes()
    if self.CreateUI then self:CreateUI() end
    if self.CreateMinimapButton then self:CreateMinimapButton() end
    if self.SetupBrowser then
        -- The browser hooks the world map frame; a client-specific layout must not
        -- take down the rest of the addon.
        local ok, err = pcall(self.SetupBrowser, self)
        if not ok then self:Print("World map browser unavailable: " .. tostring(err)) end
    end
end

local startup = CreateFrame("Frame")
startup:RegisterEvent("ADDON_LOADED")
startup:RegisterEvent("PLAYER_LOGIN")
startup:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        self:UnregisterEvent("ADDON_LOADED")
        ns:Init()
    elseif event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        if not ns.initialized then ns:Init() end
        if not ns.blocked then
            ns:StartScan()
        end
    end
end)
