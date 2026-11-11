-- Lightweight WoW-frame mock for the search window lifecycle.
-- Run after tests/run.lua with Lua 5.1: lua tests/search_ui.lua
local ns = {
    MEDIA = { white = "white", tooltipBorder = "border" },
    ready = false,
    index = {},
    categoryByKey = {},
}
ns.ClassificationNormalizeText = function(value)
    return type(value) == "string" and value:lower() or ""
end
ns.ClassificationIsPositiveInteger = function(value)
    return type(value) == "number" and value > 0 and value % 1 == 0
end

local function mockObject()
    local object = { scripts = {}, shown = false, frameLevel = 1, points = {} }
    function object:SetScript(name, callback) self.scripts[name] = callback end
    function object:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function object:SetSize() end
    function object:SetHeight() end
    function object:SetWidth() end
    function object:SetText() end
    function object:SetFormattedText() end
    function object:SetTextColor() end
    function object:SetColorTexture() end
    function object:SetVertexColor() end
    function object:SetAlpha() end
    function object:SetAllPoints() end
    function object:SetAutoFocus() end
    function object:SetTextInsets() end
    function object:SetMaxLetters() end
    function object:SetJustifyH() end
    function object:SetFontObject() end
    function object:SetMultiLine() end
    function object:SetBackdrop() end
    function object:SetBackdropColor() end
    function object:SetBackdropBorderColor() end
    function object:SetClampedToScreen() end
    function object:SetMovable() end
    function object:EnableMouse() end
    function object:RegisterForDrag() end
    function object:RegisterForClicks() end
    function object:SetScrollChild(child) self.scrollChild = child end
    function object:SetFrameStrata(value) self.frameStrata = value end
    function object:SetFrameLevel(value) self.frameLevel = value end
    function object:GetFrameLevel() return self.frameLevel end
    function object:SetFocus() self.focused = true end
    function object:ClearFocus() self.focused = false end
    function object:HighlightText() end
    function object:GetText() return "" end
    function object:IsShown() return self.shown end
    function object:Show()
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function object:Hide() self.shown = false end
    function object:CreateTexture() return mockObject() end
    function object:CreateFontString() return mockObject() end
    return object
end

UIParent = mockObject()
BackdropTemplateMixin = nil
UISpecialFrames = {}
C_Timer = nil
CreateFrame = function()
    return mockObject()
end

local chunk, err = loadfile("Search.lua")
assert(chunk, err)
chunk("ForeverWayfinder", ns)

local opener = { GetFrameLevel = function() return 25 end }
ns.uiFrame = { searchButton = opener }

ns:ToggleSearchUI()
local frame = ns.searchFrame
assert(type(frame) == "table", "search frame is created")
assert(frame:IsShown(), "search frame opens")
assert(frame.queryInput.focused, "search input receives focus")
assert(frame.frameStrata == "FULLSCREEN_DIALOG", "search frame uses dialog strata")
assert(frame.frameLevel == 35, "search frame is above its settings button")
assert(#frame.points > 0, "search frame is explicitly anchored")
local centered = false
for _, point in ipairs(frame.points) do
    if point[1] == "CENTER" and point[2] == UIParent and point[3] == "CENTER" then
        centered = true
    end
end
assert(centered, "search frame starts centered on UIParent")

ns:ToggleSearchUI()
assert(not frame:IsShown(), "search frame closes on second toggle")
ns:ToggleSearchUI()
assert(frame:IsShown(), "search frame reopens on third toggle")
assert(frame.queryInput.focused, "search input receives focus after reopening")

print("Forever Wayfinder search UI lifecycle tests passed.")
