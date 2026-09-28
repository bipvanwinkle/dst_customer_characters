local Image = require("widgets/image")
local Text = require("widgets/text")
local Widget = require("widgets/widget")

-- Mirrors the layout of Combined Status's naughtiness counter: a round portrait badge with a
-- "count/max" number beside it, sized to sit in the same column as its extra rows
local ROW_X = 65.5
local ROW_HEIGHT = 30
local AVATAR_ATLAS = "images/avatars.xml"
local FRAME_TINT = { 80 / 255, 60 / 255, 30 / 255, 1 }

-- Combined Status's extra rows, top to bottom
local EXTRA_ROWS = { "naughtiness", "temperature", "worldtemp" }

local WXGearBadge = Class(Widget, function(self, owner, max_gears)
	Widget._ctor(self, "WXGearBadge")
	self.owner = owner
	self.max_gears = max_gears
	self:SetClickable(false)

	self.badge = self:AddChild(Widget("badge"))
	self.badge:SetPosition(41, -35.5)
	self.badge:SetScale(0.35 * 0.8)
	self.badge:AddChild(Image(AVATAR_ATLAS, "avatar_bg.tex"))
	local gear = self.badge:AddChild(Image(GetInventoryItemAtlas("gears.tex"), "gears.tex"))
	gear:SetScale(0.6)
	local frame = self.badge:AddChild(Image(AVATAR_ATLAS, "avatar_frame_white.tex"))
	frame:SetTint(unpack(FRAME_TINT))

	self.counter = self:AddChild(Widget("counter"))
	self.counter:SetPosition(ROW_X, 0)
	self.counter:SetScale(0.9)
	-- The number backing ships with Combined Status; without it the number stands alone
	local bg_atlas = softresolvefilepath("images/status_bgs.xml")
	if bg_atlas ~= nil then
		local bg = self.counter:AddChild(Image(bg_atlas, "status_bgs.tex"))
		bg:SetPosition(4, -40)
		bg:SetScale(0.55, 0.43, 1)
	end
	self.num = self.counter:AddChild(Text(NUMBERFONT, 28))
	self.num:SetHAlign(ANCHOR_MIDDLE)
	self.num:SetPosition(10, -40.5)
	self.num:SetScale(0.9, 0.7, 1)

	self.inst:ListenForEvent("wx78_gearsdirty", function()
		self:Refresh()
	end, owner)
	self:Refresh()
end)

function WXGearBadge:Refresh()
	local gears = self.owner._gears_eaten_net ~= nil and self.owner._gears_eaten_net:value() or 0
	self.num:SetString(gears .. "/" .. self.max_gears)
end

-- Places the badge on the first free row below Combined Status's naughtiness and temperature rows
function WXGearBadge:PlaceBelowExtraRows(status)
	local y = 0
	for _, name in ipairs(EXTRA_ROWS) do
		if status[name] ~= nil then
			y = y - ROW_HEIGHT
		end
	end

	-- The compact season badge is a double-height row directly below the others
	local season = status.season
	if season ~= nil and season.parent == status then
		y = math.min(y, season:GetPosition().y - 45)
	end

	self:SetPosition(0, y)
end

return WXGearBadge
