
local NUMROWS, ICONSIZE, GAP, SCROLLSTEP = 14, 17, 4, 5
local knowns = GVS_SCANNER
local HONOR_POINTS, ARENA_POINTS = "|cffffffff|Hitem:43308:0:0:0:0:0:0:0:0|h[Honor Points]|h|r", "|cffffffff|Hitem:43307:0:0:0:0:0:0:0:0|h[Arena Points]|h|r"
GVS_SCANNER = nil


for _,f in pairs{MerchantNextPageButton, MerchantPrevPageButton, MerchantPageText} do
	f:Hide()
	f.Show = f.Hide
end


local GVS = CreateFrame("frame", "GVSFrame", MerchantFrame)
GVS:SetWidth(315)
GVS:SetHeight(294)
GVS:SetPoint("TOPLEFT", 10, -66)
GVS:SetScript("OnEvent", function(self, event, ...)
	if self[event] then
		return self[event](self, event, ...)
	end
end)
GVS:Hide()


local function OnClick(self, button)
	if IsAltKeyDown() and not self.altcurrency then self:BuyItem(true)
	elseif IsModifiedClick() then HandleModifiedItemClick(GetMerchantItemLink(self:GetID()))
	elseif self.altcurrency then
		local id = self:GetID()
		local link = GetMerchantItemLink(id)
		self.link, self.texture = GetMerchantItemLink(id), self.icon:GetTexture()
		MerchantFrame_ConfirmExtendedItemCost(self)
	else self:BuyItem() end
end


local function PopoutOnClick(self, button)
	local id = self:GetParent():GetID()
	local link = GetMerchantItemLink(id)
	if not link then return end

	local _, _, _, vendorStackSize, numAvailable = GetMerchantItemInfo(id)
	local maxPurchase = GetMerchantItemMaxStack(id)
	local _, _, _, _, _, _, _, itemStackSize = GetItemInfo(link)

	local size = numAvailable > 0 and numAvailable or itemStackSize
	-- OpenStackSplitFrame(size, self, "LEFT", "RIGHT")
	OpenStackSplitFrame(250, self, "LEFT", "RIGHT")
end


local function Purchase(id, quantity)
	local _, _, _, vendorStackSize, numAvailable = GetMerchantItemInfo(id)
	local maxPurchase = GetMerchantItemMaxStack(id)
	quantity = quantity/vendorStackSize

	if numAvailable > 0 and numAvailable < quantity then quantity = numAvailable end
	local purchased = 0
	while purchased < quantity do
		local buyamount = math.min(maxPurchase, quantity - purchased)
		purchased = purchased + buyamount
		BuyMerchantItem(id, buyamount)
	end
end


local function BuyItem(self, fullstack)
	local id = self:GetID()
	local link = GetMerchantItemLink(id)
	if not link then return end

	local _, _, _, _, _, _, _, stack = GetItemInfo(link)
	Purchase(id, fullstack and stack or 1)
end


local function PopoutSplitStack(self, qty)
	Purchase(self:GetParent():GetID(), qty)
end


local function OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if self.link then GameTooltip:SetHyperlink(self.link) else GameTooltip:SetMerchantCostItem(self.index, self.itemIndex) end
end


local function OnLeave()
	GameTooltip:Hide()
	ResetCursor()
end


local function GSC(cash)
	if not cash then return end
	local g, s, c = floor(cash/10000), floor((cash/100)%100), cash%100
	if g > 0 and s == 0 and c == 0 then return string.format(" |cffffd700%d", g)
	elseif g > 0 and c == 0 then return string.format(" |cffffd700%d.|cffc7c7cf%02d", g, s)
	elseif g > 0 then return string.format(" |cffffd700%d.|cffc7c7cf%02d.|cffeda55f%02d", g, s, c)
	elseif s > 0 and c == 0 then return string.format(" |cffc7c7cf%d", s)
	elseif s > 0 then return string.format(" |cffc7c7cf%d.|cffeda55f%02d", s, c)
	else return string.format(" |cffeda55f%02d", c) end
end


local function SetValue(self, text, icon, link)
	self.text:SetText(text)
	self.icon:SetTexture(icon)
	self.link, self.index, self.itemIndex = link
	if link == HONOR_POINTS then
		self.icon:SetPoint("RIGHT", -2, 0)
		self.text:SetPoint("RIGHT", self.icon, "LEFT", -GAP/2 + 2, 0)
	else
		self.icon:SetPoint("RIGHT")
		self.text:SetPoint("RIGHT", self.icon, "LEFT", -GAP/2, 0)
	end
	self:Show()
end


local function GetAltCurrencyFrame(frame)
	for i,v in ipairs(frame.altframes) do if not v:IsShown() then return v end end

	local anchor = #frame.altframes > 0 and frame.altframes[#frame.altframes].text
	local f = CreateFrame('Frame', nil, frame)
	f:SetWidth(ICONSIZE) f:SetHeight(ICONSIZE)
	f:SetPoint("RIGHT", anchor or frame.ItemPrice, "LEFT")

	f.icon = f:CreateTexture()
	f.icon:SetWidth(ICONSIZE) f.icon:SetHeight(ICONSIZE)

	f.text = f:CreateFontString(nil, nil, "NumberFontNormalSmall")

	f.SetValue = SetValue

	f:EnableMouse(true)
	f:SetScript("OnEnter", OnEnter)
	f:SetScript("OnLeave", OnLeave)

	table.insert(frame.altframes, f)
	return f
end


local function AddAltCurrency(frame, i)
	local lastframe = frame.ItemPrice
	local honorPoints, arenaPoints, itemCount = GetMerchantItemCostInfo(i)
	for j=itemCount,1,-1 do
		local f = frame:GetAltCurrencyFrame()
		local texture, price = GetMerchantItemCostItem(i, j)
		f:SetValue(price, texture)
		f.index, f.itemIndex, f.link = i, j
		lastframe = f.text
	end
	if arenaPoints > 0 then
		local f = frame:GetAltCurrencyFrame()
		f:SetValue(arenaPoints, "Interface\\PVPFrame\\PVP-ArenaPoints-Icon", ARENA_POINTS)
		lastframe = f.text
	end
	if honorPoints > 0 then
		local f = frame:GetAltCurrencyFrame()
		f:SetValue(honorPoints, "Interface\\PVPFrame\\PVP-Currency-".. UnitFactionGroup("player"), HONOR_POINTS)
		lastframe = f.text
	end
	frame.ItemName:SetPoint("RIGHT", lastframe, "LEFT", -GAP, 0)
end


local ROWHEIGHT = 21
local rows = {}
for i=1,NUMROWS do
	local row = CreateFrame('Button', nil, GVS) -- base frame
	row:SetHeight(ROWHEIGHT)
	row:SetPoint("TOP", i == 1 and GVS or rows[i-1], i == 1 and "TOP" or "BOTTOM")
	row:SetPoint("LEFT")
	row:SetPoint("RIGHT", -19, 0)

	row.BuyItem = BuyItem

	row:SetHighlightTexture("Interface\\HelpFrame\\HelpFrameButton-Highlight")
	row:GetHighlightTexture():SetTexCoord(0, 1, 0, 0.578125)

	row:RegisterForClicks("AnyUp")
	row:SetScript('OnClick', OnClick)
	row:SetScript('OnDragStart', function(self, button)
		MerchantFrame.extendedCost = nil
		PickupMerchantItem(self:GetID())
		if self.extendedCost then MerchantFrame.extendedCost = self end
	end)

	local backdrop = row:CreateTexture(nil, "BACKGROUND")
	backdrop:SetAllPoints()
	backdrop:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
	row.backdrop = backdrop

	local icon = CreateFrame('Frame', nil, row)
	icon:SetHeight(ICONSIZE)
	icon:SetWidth(ICONSIZE)
	icon:SetPoint('LEFT', 2, 0)

	row.icon = icon:CreateTexture(nil, "BORDER")
	row.icon:SetAllPoints()

	local ItemName = row:CreateFontString(nil, nil, "GameFontNormalSmall")
	ItemName:SetPoint('LEFT', icon, "RIGHT", GAP, 0)
	ItemName:SetJustifyH('LEFT')
	row.ItemName = ItemName

	local popout = CreateFrame("Button", nil, row)
	popout:SetPoint("RIGHT")
	popout:SetWidth(ROWHEIGHT/2) popout:SetHeight(ROWHEIGHT)
	popout:SetNormalTexture("Interface\\PaperDollInfoFrame\\UI-GearManager-FlyoutButton")
	popout:SetHighlightTexture("Interface\\PaperDollInfoFrame\\UI-GearManager-FlyoutButton")
	popout:GetNormalTexture():SetTexCoord(0.15625, 0.5, 0.84375, 0.5, 0.15625, 0, 0.84375, 0)
	popout:GetHighlightTexture():SetTexCoord(0.15625, 1, 0.84375, 1, 0.15625, 0.5, 0.84375, 0.5)
	popout:SetScript("OnClick", PopoutOnClick)
	popout.SplitStack = PopoutSplitStack
	row.popout = popout

	local ItemPrice = row:CreateFontString(nil, nil, "NumberFontNormalSmall")
	ItemPrice:SetPoint('RIGHT', popout, "LEFT", -2, 0)
	row.ItemPrice = ItemPrice

	row.altframes = {}
	row.AddAltCurrency, row.GetAltCurrencyFrame = AddAltCurrency, GetAltCurrencyFrame

	row:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip.merchantSlotIndex = self:GetID()
		GameTooltip:SetMerchantItem(self:GetID())
		GameTooltip_ShowCompareItem()
		MerchantFrame.itemHover = self:GetID()
		if IsModifiedClick("DRESSUP") then ShowInspectCursor() else ResetCursor() end
	end)
	row:SetScript('OnLeave', function()
		GameTooltip:Hide()
		ResetCursor()
		MerchantFrame.itemHover = nil
	end)

	rows[i] = row
end


local default_grad = {0,1,0,0.75, 0,1,0,0} -- green
local grads = setmetatable({
	red = {1,0,0,0.75, 1,0,0,0},
	[1] = {1,1,1,0.75, 1,1,1,0}, -- white
	[2] = default_grad, -- green
	[3] = {0.5,0.5,1,1, 0,0,1,0}, -- blue
	[4] = {1,0,1,0.75, 1,0,1,0}, -- purple
	[7] = {1,.75,.5,0.75, 1,.75,.5,0}, -- heirloom
}, {__index = function(t,i) t[i] = default_grad return default_grad end})
local _, _, _, _, _, _, _, _, RECIPE = GetAuctionItemClasses()
local quality_colors = setmetatable({}, {__index = function() return "|cffffffff" end})
for i=1,7 do quality_colors[i] = select(4, GetItemQualityColor(i)) end
local offset = 0
local searchstring
local function Refresh()
	local n = GetMerchantNumItems()
	for i,row in pairs(rows) do
		local j = i + offset
		if j > n then
			row:Hide()
		else
			row.backdrop:Hide()

			local color = quality_colors.default
			local name, itemTexture, itemPrice, itemStackCount, numAvailable, isUsable, extendedCost = GetMerchantItemInfo(j)
			local link = GetMerchantItemLink(j)
			if link then
				local name, link2, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(link)
				color = quality_colors[quality]

				if class == RECIPE and not knowns[link] then
					row.backdrop:SetGradientAlpha("HORIZONTAL", unpack(grads[quality]))
					row.backdrop:Show()
				end
				
				local honorPoints, arenaPoints = GetMerchantItemCostInfo(j)
				local requirementType, requiredRating = C_Item.GetRequiredPVPRating(link, honorPoints, arenaPoints)

				if requirementType == Enum.ItemRequirementType.None then
					isUsable = true
				elseif requirementType == Enum.ItemRequirementType.Battleground then
					local _, _, _, _, rating = GetRatedBattlegroundRankInfo()
					if rating >= requiredRating then
						isUsable = true
					end
				elseif requirementType == Enum.ItemRequirementType.Arena then
					local rating = math.max(GetArenaRating(1), GetArenaRating(2))
					if rating >= requiredRating then
						isUsable = true
					end
				end
			end

			if not isUsable then
				row.backdrop:SetGradientAlpha("HORIZONTAL", unpack(grads.red))
				row.backdrop:Show()
			end

			row:SetAlpha(searchstring and name and not name:lower():match(searchstring) and 0.5 or 1)

			row.icon:SetTexture(itemTexture)
			row.ItemName:SetText((numAvailable > -1 and ("["..numAvailable.."] ") or "").. color.. (name or "<Loading item data>").. (itemStackCount > 1 and ("|r x"..itemStackCount) or ""))

			for i,v in pairs(row.altframes) do v:Hide() end
			row.altcurrency = extendedCost
			if extendedCost then
				row:AddAltCurrency(j)
				row.link, row.texture, row.extendedCost = link, itemTexture, true
			end
			if itemPrice > 0 then
				row.ItemPrice:SetText(GSC(itemPrice))
				row.Price = itemPrice
			end
			if extendedCost and (itemPrice <= 0) then
				row.ItemPrice:SetText()
				row.Price = 0
			elseif extendedCost and (itemPrice > 0) then
				row.ItemPrice:SetText(GSC(itemPrice))
			else
				row.ItemName:SetPoint("RIGHT", row.ItemPrice, "LEFT", -GAP, 0)
				row.extendedCost = nil
			end

			if isUsable then row.icon:SetVertexColor(1, 1, 1) else row.icon:SetVertexColor(.9, 0, 0) end
			row:SetID(j)
			row:Show()
		end
	end
end


local editbox = CreateFrame('EditBox', nil, GVS, "SearchBoxTemplate")
editbox:SetAutoFocus(false)
editbox:SetPoint("TOPLEFT", GVS, "BOTTOMLEFT", -2, -51)
editbox:SetWidth(158)
editbox:SetHeight(32)
editbox:SetFontObject('GameFontHighlightSmall')
editbox:SetScript("OnTextChanged", function(self)
	SearchBoxTemplate_OnTextChanged(self)
	local t = self:GetText()
	searchstring = t ~= "" and t ~= "Search..." and t:lower() or nil
	Refresh()
end)

local scrollbar = LibStub("tekKonfig-Scroll").new(GVS, 0, SCROLLSTEP)
local f = scrollbar:GetScript("OnValueChanged")
scrollbar:SetScript("OnValueChanged", function(self, value, ...)
	offset = math.floor(value)
	Refresh()
	return f(self, value, ...)
end)


local offset = 0
GVS:EnableMouseWheel(true)
GVS:SetScript("OnMouseWheel", function(self, value) scrollbar:SetValue(scrollbar:GetValue() - value * SCROLLSTEP) end)
GVS:SetScript("OnShow", function(self, noreset)
	local max = math.max(0, GetMerchantNumItems() - NUMROWS)
	scrollbar:SetMinMaxValues(0, max)
	scrollbar:SetValue(noreset and math.min(scrollbar:GetValue(), max) or 0)
	Refresh()
end)
GVS:SetScript("OnHide", function() if StackSplitFrame:IsVisible() then StackSplitFrame:Hide() end end)


-- Reanchor the buyback button, it acts weird when switching tabs otherwise...
MerchantBuyBackItem:ClearAllPoints()
MerchantBuyBackItem:SetPoint("BOTTOMLEFT", 176, 33)


local function Show()
	for i=1,12 do _G["MerchantItem"..i]:Hide() end
	if GVS:IsShown() then GVS:GetScript("OnShow")(GVS, true) else GVS:Show() end
end
hooksecurefunc("MerchantFrame_UpdateMerchantInfo", Show)


hooksecurefunc("MerchantFrame_UpdateBuybackInfo", function()
	GVS:Hide()
	for i=1,12 do _G["MerchantItem"..i]:Show() end
end)


if MerchantFrame:IsVisible() and MerchantFrame.selectedTab == 1 then Show() end


LibStub("tekKonfig-AboutPanel").new(nil, "GnomishVendorShrinker")
