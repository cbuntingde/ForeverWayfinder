local ADDON, ns = ...

-- The minimap's offsets are expressed in the coordinate space of its parent,
-- so the raw cursor position is converted into that space before the two are
-- compared. GetCursorPosition is not affected by the UI scale, the frame
-- offsets are.
local function CursorPosition()
    local parent = (Minimap and Minimap.GetParent and Minimap:GetParent()) or UIParent
    local scale = parent and parent.GetEffectiveScale and parent:GetEffectiveScale() or 1
    if type(scale) ~= "number" or scale == 0 then scale = 1 end
    local x, y = GetCursorPosition()
    return x / scale, y / scale
end

function ns:UpdateMinimapButtonPosition()
    local button = self.minimapButton
    if not button then return end

    local angle = math.rad(self.db.minimapAngle or 220)
    local radius = (Minimap:GetWidth() or 140) * 0.55 + 4

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function ns:UpdateMinimapButton()
    local button = self.minimapButton
    if not button then return end

    button:SetShown(self.db.showMinimapButton ~= false)
    button.icon:SetDesaturated(not self.db.enabled or not self.db.showMinimap)
    self:UpdateMinimapButtonPosition()
end

function ns:CreateMinimapButton()
    if self.minimapButton then return end

    local button = CreateFrame("Button", "ForeverWayfinderMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:SetClampedToScreen(true)
    -- Buttons do not receive every click type by default. Drag starts on mouse-down, so
    -- register both edges explicitly; OnMouseUp then decides between click and drag.
    button:RegisterForClicks("AnyDown", "AnyUp")

    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetTexture(ns.MEDIA.minimapBg)
    button.background:SetAllPoints()

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture(ns.MEDIA.addonIcon)
    button.icon:SetSize(20, 20)
    button.icon:SetPoint("CENTER")
    button.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)

    button:SetHighlightTexture(ns.MEDIA.minimapHighlight)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Forever Wayfinder", 1.00, 0.82, 0.00)
        if ns.ready then
            GameTooltip:AddLine(("%d pins across %d maps"):format(ns.stat.nodes, ns.stat.mapCount), 0.70, 0.67, 0.60)
        else
            GameTooltip:AddLine("Indexing NPC data...", 0.70, 0.67, 0.60)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click: settings", 0.86, 0.83, 0.74)
        GameTooltip:AddLine(
            "Right-click: minimap pins " .. (ns.db.showMinimap and "|cff66cc66on|r" or "|cffff6666off|r"),
            0.86, 0.83, 0.74)
        GameTooltip:AddLine("Drag: move around the minimap", 0.55, 0.55, 0.50)
        if not ns.db.enabled then
            GameTooltip:AddLine("All pins are currently disabled.", 0.85, 0.35, 0.30)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton ~= "LeftButton" then return end
        self.dragging = true
        self.dragMoved = false
        self.dragStartX, self.dragStartY = CursorPosition()
    end)

    button:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        -- The button does not own the mouse during the drag, so a release
        -- outside it is delivered elsewhere and OnMouseUp never runs. The
        -- real button state is the only reliable end-of-drag signal.
        if type(IsMouseButtonDown) == "function" and not IsMouseButtonDown("LeftButton") then
            self.dragging = false
            self.dragMoved = false
            return
        end

        local cursorX, cursorY = CursorPosition()
        local minimapX, minimapY = Minimap:GetCenter()
        if not minimapX then return end

        local deltaX, deltaY = cursorX - minimapX, cursorY - minimapY
        if not self.dragMoved then
            local movedX = cursorX - (self.dragStartX or cursorX)
            local movedY = cursorY - (self.dragStartY or cursorY)
            if math.abs(movedX) + math.abs(movedY) > 4 then
                self.dragMoved = true
            end
        end

        if self.dragMoved then
            ns.db.minimapAngle = math.deg(math.atan2(deltaY, deltaX))
            ns:UpdateMinimapButtonPosition()
        end
    end)

    button:SetScript("OnMouseUp", function(self, mouseButton)
        if mouseButton == "RightButton" then
            ns.db.showMinimap = not ns.db.showMinimap
            ns:Refresh()
            ns:UpdateUI()
            GameTooltip:Hide()
            ns:Print("Minimap pins " .. (ns.db.showMinimap and "enabled." or "disabled."))
            return
        end

        if mouseButton ~= "LeftButton" then return end
        local moved = self.dragMoved
        self.dragging = false
        self.dragMoved = false
        if not moved then
            ns:ToggleUI()
        end
    end)

    self.minimapButton = button
    self:UpdateMinimapButton()
end
