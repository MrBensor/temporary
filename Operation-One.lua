local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/MrBensor/Roblox-Scripts/refs/heads/main/GsLib.lua"))()

local Players               = game:GetService("Players")
local RunService            = game:GetService("RunService")
local UserInputService      = game:GetService("UserInputService")
local ContextActionService  = game:GetService("ContextActionService")
local HttpService           = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- =====================
--   UNLOAD TRACKING
-- =====================
local Connections = {}
local Drawings    = {}

local function track(conn)
    table.insert(Connections, conn)
    return conn
end

local function newDrawing(class)
    local d = Drawing.new(class)
    table.insert(Drawings, d)
    return d
end

local Settings = {
    ESPEnabled      = false,
    ESPTeamCheck    = false,
    ESPBoxes        = true,
    ESPNames        = true,
    ESPShowRegion   = false,
    ESPHealthBar    = true,
    ESPTracers      = true,
    ESPTracerOrigin = "Bottom",
    ESPDistance     = true,
    ESPSkeleton     = false,
    ESPShowPing     = false,
    ESPMaxDistance  = 1000,
    ESPColor        = Color3.fromRGB(255, 0, 0),
    ESPColorAlpha   = 1,
    ESPUseTeamColor = false,
    ESPCombatEnabled = false,
    ESPShowKills    = false,
    ESPShowDeaths   = false,
    ESPShowAssists  = false,
    ESPShowKD       = false,

    ESPHitbox     = false,
    ESPFilling    = false,
    ESPHeadCircle = false,

    GadgetESPEnabled    = false,
    GadgetShow          = {},
    GadgetMaxDistance   = 1000,
    GadgetColor         = Color3.fromRGB(0, 255, 255),
    GadgetColorAlpha    = 1,
    GadgetShowDistance  = true,
    GrenadeTrail        = false,

    GadgetPerItem        = {},   -- [gameName] = { hitbox, filling, trail }
    GadgetItemColors     = {},   -- [gameName] = Color3
    GadgetItemColorAlpha = {},   -- [gameName] = number

    AntiSmokeHitbox = false,
    SmokeDebug      = false,

    GunNoRecoil      = false,
    GunNoSpread      = false,
    GunRapidFire     = false,
    GunFireRate      = 100,
    GunInfiniteAmmo  = false,
    GunInstantReload = false,
    GunForceAuto     = false,
    AccentColor      = Color3.fromRGB(161, 212, 59),

    AntiSmoke = false,
    AntiFlash = false,

    FullbrightEnabled    = false,
    FullbrightBrightness = 2,
    FullbrightClockTime  = 14,

    ThirdPerson         = false,
    ThirdPersonDistance = 12,
    FreecamEnabled      = false,
    FreecamSpeed        = 3,

    AimbotEnabled    = false,
    AimbotFOV        = 10,
    AimbotShowFOV    = false,
    AimbotSmoothing  = 0,
    AimbotWallcheck  = false,
    AimbotHeld       = false,
    AimbotKeybind    = false,

    SelectedSkin     = false,
    SelectedOutfit   = false,
    SelectedHat      = false,
    SelectedCharm    = false,

    GlobalPrimSkin   = "-",
    GlobalSecSkin    = "-",
    PerWeaponSkins   = {},
}

-- widget → Settings sync functions; populated alongside widget creation
local Bindings = {}

local CUSTOM_BONES = {
    {"head",      "torso"},
    {"torso",     "shoulder1"},
    {"torso",     "shoulder2"},
    {"shoulder1", "arm1"},
    {"shoulder2", "arm2"},
    {"torso",     "hip1"},
    {"torso",     "hip2"},
    {"hip1",      "leg1"},
    {"hip2",      "leg2"},
}
local MAX_BONES = #CUSTOM_BONES

local AIMBONE_MAP = {
    ["Head"]       = "head",
    ["Torso"]      = "torso",
    ["L Shoulder"] = "shoulder1",
    ["R Shoulder"] = "shoulder2",
    ["L Arm"]      = "arm1",
    ["R Arm"]      = "arm2",
    ["L Hip"]      = "hip1",
    ["R Hip"]      = "hip2",
    ["L Leg"]      = "leg1",
    ["R Leg"]      = "leg2",
}

-- game name → display label for all tracked gadgets
local GADGET_DEFS = {
    { Game = "FragGrenade",       Label = "Grenade"            },
    { Game = "BreachCharge",      Label = "Soft Breach"        },
    { Game = "Claymore",          Label = "Claymore"           },
    { Game = "HardBreachCharge",  Label = "Hard Breach"        },
    { Game = "RemoteC4",          Label = "C4"                 },
    { Game = "Drone",             Label = "Drone"              },
    { Game = "StickyCamera",      Label = "Sticky Cam"         },
    { Game = "ShockBattery",      Label = "Shock Battery"      },
    { Game = "BulletproofCamera", Label = "Bulletproof Camera" },
    { Game = "ThermiteCharge",    Label = "Thermite"           },
    { Game = "DefaultCamera",     Label = "Default Camera"     },
    { Game = "BarbedWire",       Label = "Barbed Wire"        },
}
-- fast lookup: game name → display label
local GADGET_LABEL = {}
for _, d in ipairs(GADGET_DEFS) do GADGET_LABEL[d.Game] = d.Label end

-- camera-type gadgets that have a "Cam" child with LocalTransparency attribute
local CAMERA_GADGETS = {
    DefaultCamera     = true,
    BulletproofCamera = true,
    StickyCamera      = true,
    Drone             = true,
}

local ESPObjects = {}

local aimbotFOVCircle = Drawing.new("Circle")
aimbotFOVCircle.Filled    = false
aimbotFOVCircle.Thickness = 1
aimbotFOVCircle.NumSides  = 64
aimbotFOVCircle.Color     = Color3.fromRGB(255, 255, 255)
aimbotFOVCircle.Visible   = false
table.insert(Drawings, aimbotFOVCircle)

local hiddenParts  = setmetatable({}, { __mode = "k" })
local handledSmoke = setmetatable({}, { __mode = "k" })
local tinySize     = Vector3.new(0.001, 0.001, 0.001)
local flashGui     = nil   -- PlayerGui.Flash reference

local Lighting      = game:GetService("Lighting")
local _origLighting = nil

local CHAR_HEIGHT = 5.5
local CHAR_RATIO  = 0.4

local function calcBox(char)
    -- GetBoundingBox() gives animation-stable AABB (handles prone/crouch/animation)
    local ok, bbCF, bbSz = pcall(function() return char:GetBoundingBox() end)
    if ok and bbCF and bbSz and bbSz.Y > 0.3 then
        local center = bbCF.Position
        local topW   = center + Vector3.new(0, bbSz.Y * 0.5, 0)
        local botW   = center - Vector3.new(0, bbSz.Y * 0.5, 0)
        local spc, onc = Camera:WorldToViewportPoint(center)
        local spt       = Camera:WorldToViewportPoint(topW)
        local spb       = Camera:WorldToViewportPoint(botW)
        if onc and spc.Z > 0 then
            local topY = math.min(spt.Y, spb.Y) - 2
            local botY = math.max(spt.Y, spb.Y) + 2
            local h    = math.max(botY - topY, 4)
            local w    = h * CHAR_RATIO
            local cx   = spc.X
            return cx, cx - w/2, topY, w, h, true
        end
    end

    -- Fallback: named collision parts
    local topPart = char:FindFirstChild("collision3", true)
    local botPart = char:FindFirstChild("legs", true)
    if topPart and botPart then
        local sp1, on1 = Camera:WorldToViewportPoint(topPart.Position)
        local sp2, on2 = Camera:WorldToViewportPoint(botPart.Position)
        if on1 and on2 and sp1.Z > 0 then
            local pad  = math.abs(sp2.Y - sp1.Y) * 0.12
            local topY = math.min(sp1.Y, sp2.Y) - pad
            local botY = math.max(sp1.Y, sp2.Y) + pad * 0.4
            local h    = botY - topY
            local w    = h * CHAR_RATIO
            local cx   = (sp1.X + sp2.X) / 2
            return cx, cx - w/2, topY, w, h, true
        end
    end

    local ref = char:FindFirstChild("collision", true)
             or char:FindFirstChild("HumanoidRootPart")
             or char:FindFirstChildWhichIsA("BasePart", true)
    if ref then
        local rp, onScreen = Camera:WorldToViewportPoint(ref.Position)
        if onScreen and rp.Z > 0 then
            local fovTan = math.tan(math.rad(Camera.FieldOfView) / 2)
            local pps    = Camera.ViewportSize.Y / (2 * rp.Z * fovTan)
            local h      = CHAR_HEIGHT * pps
            local w      = h * CHAR_RATIO
            local yOff   = (ref.Name == "collision") and 0.55 or 0.35
            return rp.X, rp.X - w/2, rp.Y - h * yOff, w, h, true
        end
    end

    return 0, 0, 0, 0, 0, false
end

local function getESPColor(player)
    if Settings.ESPUseTeamColor then
        local ok, col = pcall(function() return player.TeamColor.Color end)
        if ok and col then return col end
    end
    return Settings.ESPColor
end

local function findPlayerModel(player)
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and obj.Name == player.Name then
            local team = obj:GetAttribute("Team")
            if team == "Red" or team == "Blue" then return obj end
        end
    end
    return nil
end

-- =====================
--   FLAG IMAGES (flagcdn)
-- =====================
local FlagCache   = {}
local FlagPending = {}

local function requestFlag(code)
    code = code:lower()
    if FlagCache[code] ~= nil or FlagPending[code] then return end
    FlagPending[code] = true
    task.spawn(function()
        local ok, data = pcall(function()
            return game:HttpGet("https://flagcdn.com/w40/" .. code .. ".png")
        end)
        FlagCache[code]   = (ok and data and #data > 0) and data or false
        FlagPending[code] = nil
    end)
end

local function buildCombatText(player)
    local lines   = {}
    local kills   = player:GetAttribute("Kills")   or 0
    local deaths  = player:GetAttribute("Deaths")  or 0
    local assists = player:GetAttribute("Assists") or 0
    if Settings.ESPShowKills   then table.insert(lines, "K: "  .. kills)   end
    if Settings.ESPShowDeaths  then table.insert(lines, "D: "  .. deaths)  end
    if Settings.ESPShowAssists then table.insert(lines, "A: "  .. assists) end
    if Settings.ESPShowKD then
        local kd = string.format("%.2f", kills / math.max(deaths, 1))
        table.insert(lines, "KD: " .. kd)
    end
    return table.concat(lines, "\n")
end

-- =====================
--       LOOK & FEEL
--  (alles zum GUI-Aussehen steht hier, nicht in GsLib)
-- =====================
local MyTheme = {
    -- Farben
    -- leicht warmer Grundton (weniger Blaulicht, „Augenschonmodus"): R ≥ G ≥ B, nur dezent
    Accent      = Color3.fromRGB(161, 212, 59),    -- #a1d43b
    Bg          = Color3.fromRGB(19, 18, 18),    -- außerhalb der Inseln (am dunkelsten)
    OuterBg     = Color3.fromRGB(6,  5,  5),     -- schwarzer Streifen im doppelten Rand
    Sidebar     = Color3.fromRGB(15, 14, 14),
    Panel       = Color3.fromRGB(27, 26, 26),    -- Insel-Innenfläche (etwas heller als Bg)
    Elem        = Color3.fromRGB(37, 36, 36),    -- Slider-Track / Eingabefelder
    ElemHov     = Color3.fromRGB(48, 47, 47),
    Border      = Color3.fromRGB(56, 55, 54),    -- äußere + innere Randlinie
    BorderDim   = Color3.fromRGB(35, 34, 33),
    IslandBorder= Color3.fromRGB(64, 63, 62),    -- hellgraue Linie um die Inseln
    Text        = Color3.fromRGB(238, 237, 236),
    Dim         = Color3.fromRGB(228, 227, 226),
    Muted       = Color3.fromRGB(146, 144, 143),
    CheckOff    = Color3.fromRGB(42,  41,  41),
    -- Schrift
    Font        = Enum.Font.Gotham,
    Bold        = Enum.Font.GothamBold,
    Sz          = 13,
    -- obere Leiste: Regenbogen-Verlauf (beliebig viele Farben)
    TopBarColors = {
        Color3.fromRGB(255,  51,  51),   -- rot
        Color3.fromRGB(255, 140,   0),   -- orange
        Color3.fromRGB(255, 230,   0),   -- gelb
        Color3.fromRGB( 51, 220,  51),   -- grün
        Color3.fromRGB( 51, 160, 255),   -- blau
        Color3.fromRGB(160,  51, 255),   -- lila
        Color3.fromRGB(255,  51, 180),   -- pink
    },
}

-- =====================
--       WINDOW
-- =====================
local Window = Lib:CreateWindow({
    Title  = "Operation One",
    Size   = Vector2.new(720, 510),
    Theme  = MyTheme,
})
Window:SetToggleKey(Enum.KeyCode.Delete)
Lib:Notify({ Title = "Operation One", Text = "Loaded. Press Delete to toggle.", Duration = 4 })

-- =====================
--         TABS
-- =====================
local RagebotTab = Window:CreateTab({ Name = "Ragebot" })
local LegitbotTab = Window:CreateTab({ Name = "Legitbot" })
local ESPTab    = Window:CreateTab({ Name = "ESP" })
local GadgetTab = Window:CreateTab({ Name = "Gadget" })
local GunTab    = Window:CreateTab({ Name = "Gun" })
local MiscTab   = Window:CreateTab({ Name = "Misc" })
local SkinTab   = Window:CreateTab({ Name = "Skins" })
local ConfigTab = Window:CreateTab({ Name = "Config" })

-- =====================
--     RAGEBOT TAB
-- =====================
local RagebotLeft  = RagebotTab:CreateGroup({ Name = "Aimbot",   Side = "Left" })
local RagebotRight = RagebotTab:CreateGroup({ Name = "Settings", Side = "Right" })
RagebotRight:AddParagraph({ Title = "Coming soon", Text = "Ragebot features will be added here." })

-- =====================
--     LEGITBOT TAB
-- =====================
local LegitbotLeft  = LegitbotTab:CreateGroup({ Name = "Aimbot",   Side = "Left" })
local LegitbotRight = LegitbotTab:CreateGroup({ Name = "Settings", Side = "Right" })

local wAimbotEnabled = LegitbotLeft:AddToggle({
    Text = "Enable Aimbot", Default = false,
    Callback = function(v) Settings.AimbotEnabled = v end,
})
wAimbotEnabled:AddKeybind({ Mode = "Hold", Callback = function(v) Settings.AimbotHeld = v end })
Bindings[#Bindings+1] = function()
    wAimbotEnabled:Set(Settings.AimbotEnabled)
    pcall(function()
        if Settings.AimbotKeybind and wAimbotEnabled.Keybind then
            local s = Settings.AimbotKeybind
            local etype, ename = s:match("Enum%.(%a+)%.(.+)")
            if etype and ename then
                local ok, key = pcall(function() return Enum[etype][ename] end)
                if ok and key then wAimbotEnabled.Keybind:Set(key) end
            end
        end
    end)
end

LegitbotLeft:AddSection("FOV")
local wAimbotFOV = LegitbotLeft:AddSlider({
    Text = "FOV", Min = 1, Max = 180, Default = 10, Suffix = "°",
    Callback = function(v) Settings.AimbotFOV = v end,
})
Bindings[#Bindings+1] = function() wAimbotFOV:Set(Settings.AimbotFOV) end

local wAimbotShowFOV = LegitbotLeft:AddToggle({
    Text = "Show FOV", Default = false,
    Callback = function(v) Settings.AimbotShowFOV = v end,
})
Bindings[#Bindings+1] = function() wAimbotShowFOV:Set(Settings.AimbotShowFOV) end

LegitbotLeft:AddSection("Target")
local wAimbotBones = LegitbotLeft:AddDropdown({
    Text    = "Aimbones",
    Multi   = true,
    Options = { "Head", "Torso", "L Shoulder", "R Shoulder", "L Arm", "R Arm", "L Hip", "R Hip", "L Leg", "R Leg" },
    Default = { "Head", "Torso" },
    Callback = function(v) Settings.AimbotBones = v end,
})
Bindings[#Bindings+1] = function() wAimbotBones:Set(Settings.AimbotBones) end

LegitbotLeft:AddSection("Smoothing")
local wAimbotSmoothing = LegitbotLeft:AddSlider({
    Text = "Smoothing", Min = 0, Max = 100, Default = 0, Suffix = "%",
    Callback = function(v) Settings.AimbotSmoothing = v end,
})
Bindings[#Bindings+1] = function() wAimbotSmoothing:Set(Settings.AimbotSmoothing) end

LegitbotLeft:AddSection("Misc")
local wAimbotWallcheck = LegitbotLeft:AddToggle({
    Text = "Wallcheck", Default = false,
    Callback = function(v) Settings.AimbotWallcheck = v end,
})
Bindings[#Bindings+1] = function() wAimbotWallcheck:Set(Settings.AimbotWallcheck) end

LegitbotRight:AddParagraph({
    Title = "Aimbot",
    Text  = "Hold keybind or toggle. Aims at the nearest bone to the crosshair within the FOV. Smoothing = 0 is instant, 100 is very slow. Wallcheck filters targets behind walls.",
})

-- =====================
--       ESP TAB
-- =====================
local ESPLeft  = ESPTab:CreateGroup({ Name = "Player ESP", Side = "Left" })
local ESPRight = ESPTab:CreateGroup({ Name = "Options",    Side = "Right" })

local wESPEnabled = ESPLeft:AddToggle({
    Text = "Enable ESP", Default = false,
    Callback = function(v)
        Settings.ESPEnabled = v
        if not v then
            for _, obj in pairs(ESPObjects) do
                for _, d in pairs(obj) do
                    if type(d) == "table" then
                        for _, line in pairs(d) do pcall(function() line.Visible = false end) end
                    else
                        pcall(function() d.Visible = false end)
                    end
                end
            end
        end
    end,
})
Bindings[#Bindings+1] = function() wESPEnabled:Set(Settings.ESPEnabled) end

local wESPTeamCheck  = ESPLeft:AddToggle({ Text = "Team Check",  Default = true,  Callback = function(v) Settings.ESPTeamCheck  = v end })
Bindings[#Bindings+1] = function() wESPTeamCheck:Set(Settings.ESPTeamCheck) end
local wESPBoxes      = ESPLeft:AddToggle({ Text = "Boxes",       Default = false, Callback = function(v) Settings.ESPBoxes      = v end })
Bindings[#Bindings+1] = function() wESPBoxes:Set(Settings.ESPBoxes) end
local wESPSkeleton   = ESPLeft:AddToggle({ Text = "Skeleton",    Default = false, Callback = function(v) Settings.ESPSkeleton   = v end })
Bindings[#Bindings+1] = function() wESPSkeleton:Set(Settings.ESPSkeleton) end
local wESPNames      = ESPLeft:AddToggle({ Text = "Names",       Default = false, Callback = function(v) Settings.ESPNames      = v end })
Bindings[#Bindings+1] = function() wESPNames:Set(Settings.ESPNames) end
local wESPShowRegion = ESPLeft:AddToggle({ Text = "Show Region", Default = false, Callback = function(v) Settings.ESPShowRegion = v end })
Bindings[#Bindings+1] = function() wESPShowRegion:Set(Settings.ESPShowRegion) end
local wESPHealthBar  = ESPLeft:AddToggle({ Text = "Health Bar",  Default = false, Callback = function(v) Settings.ESPHealthBar  = v end })
Bindings[#Bindings+1] = function() wESPHealthBar:Set(Settings.ESPHealthBar) end
local wESPHitbox = ESPLeft:AddToggle({ Text = "Hitbox (Outline)", Default = false, Callback = function(v) Settings.ESPHitbox = v end })
Bindings[#Bindings+1] = function() wESPHitbox:Set(Settings.ESPHitbox) end
local wESPFilling = ESPLeft:AddToggle({ Text = "Hitbox (Fill)", Default = false, Callback = function(v) Settings.ESPFilling = v end })
Bindings[#Bindings+1] = function() wESPFilling:Set(Settings.ESPFilling) end
local wESPHeadCircle = ESPLeft:AddToggle({ Text = "Head Circle", Default = false, Callback = function(v) Settings.ESPHeadCircle = v end })
Bindings[#Bindings+1] = function() wESPHeadCircle:Set(Settings.ESPHeadCircle) end
local wTracerOrigin  -- forward declared
local wESPTracers = ESPLeft:AddToggle({
    Text = "Tracers", Default = false,
    Callback = function(v)
        Settings.ESPTracers = v
        if wTracerOrigin then wTracerOrigin:SetVisible(v) end
    end,
})
Bindings[#Bindings+1] = function()
    wESPTracers:Set(Settings.ESPTracers)
end

wTracerOrigin = ESPLeft:AddDropdown({
    Text     = "Tracer Origin",
    Options  = { "Bottom", "Middle", "Top" },
    Callback = function(v) Settings.ESPTracerOrigin = v end,
})
wTracerOrigin:SetVisible(Settings.ESPTracers)
Bindings[#Bindings+1] = function()
    wTracerOrigin:Set(Settings.ESPTracerOrigin)
    wTracerOrigin:SetVisible(Settings.ESPTracers)
end
local wESPDistance   = ESPLeft:AddToggle({ Text = "Distance",    Default = false, Callback = function(v) Settings.ESPDistance   = v end })
Bindings[#Bindings+1] = function() wESPDistance:Set(Settings.ESPDistance) end
local wESPShowPing   = ESPLeft:AddToggle({ Text = "Show Ping",   Default = false, Callback = function(v) Settings.ESPShowPing   = v end })
Bindings[#Bindings+1] = function() wESPShowPing:Set(Settings.ESPShowPing) end

ESPRight:AddSection("Color")

local wESPColor = ESPRight:AddColorPicker({
    Text    = "ESP Color",
    Default = Color3.fromRGB(255, 0, 0),
    Callback = function(c, a) Settings.ESPColor = c; Settings.ESPColorAlpha = a or 1 end,
})
Bindings[#Bindings+1] = function() wESPColor:Set(Settings.ESPColor) end

local wESPUseTeamColor = ESPRight:AddToggle({
    Text = "Use Team Colors", Default = false,
    Callback = function(v) Settings.ESPUseTeamColor = v end,
})
Bindings[#Bindings+1] = function() wESPUseTeamColor:Set(Settings.ESPUseTeamColor) end

-- Combat Stats: ein Toggle, der darunter ein Dropdown mit den Flags einblendet
local wCombatFlags  -- forward declared so the toggle callback can reach it
local wCombatStats = ESPRight:AddToggle({
    Text = "Combat Stats", Default = false,
    Callback = function(v)
        Settings.ESPCombatEnabled = v
        if wCombatFlags then wCombatFlags:SetVisible(v) end
    end,
})
Bindings[#Bindings+1] = function() wCombatStats:Set(Settings.ESPCombatEnabled) end

wCombatFlags = ESPRight:AddDropdown({
    Text    = "Flags",
    Options = { "Kills", "Deaths", "Assists", "K/D" },
    Multi   = true,
    Callback = function(v)
        Settings.ESPShowKills   = table.find(v, "Kills")   ~= nil
        Settings.ESPShowDeaths  = table.find(v, "Deaths")  ~= nil
        Settings.ESPShowAssists = table.find(v, "Assists") ~= nil
        Settings.ESPShowKD      = table.find(v, "K/D")     ~= nil
    end,
})
wCombatFlags:SetVisible(Settings.ESPCombatEnabled)
Bindings[#Bindings+1] = function()
    local flags = {}
    if Settings.ESPShowKills   then table.insert(flags, "Kills")   end
    if Settings.ESPShowDeaths  then table.insert(flags, "Deaths")  end
    if Settings.ESPShowAssists then table.insert(flags, "Assists") end
    if Settings.ESPShowKD      then table.insert(flags, "K/D")     end
    wCombatFlags:Set(flags)
    wCombatFlags:SetVisible(Settings.ESPCombatEnabled)
end

ESPRight:AddSection("Range")

local wESPMaxDist = ESPRight:AddSlider({
    Text = "Max Distance", Min = 100, Max = 2000, Default = 1000, Suffix = "m",
    Callback = function(v) Settings.ESPMaxDistance = v end,
})
Bindings[#Bindings+1] = function() wESPMaxDist:Set(Settings.ESPMaxDistance) end

-- =====================
--     GADGET ESP TAB
-- =====================
local GadgetLeft  = GadgetTab:CreateGroup({ Name = "Gadgets",  Side = "Left" })
local GadgetRight = GadgetTab:CreateGroup({ Name = "Settings", Side = "Right" })

local wGadgetEnabled = GadgetLeft:AddToggle({
    Text = "Enable Gadget ESP", Default = false,
    Callback = function(v) Settings.GadgetESPEnabled = v end,
})
Bindings[#Bindings+1] = function() wGadgetEnabled:Set(Settings.GadgetESPEnabled) end

GadgetLeft:AddSection("Types")

local wGadgetToggles  = {}
local gadgetPopupRows = {}   -- [gn] = row Frame (from T2.Row)

-- =====================
--  PER-GADGET POPUP
-- Opens in Window.Overlay at current mouse position.
-- =====================
local function openGadgetPopup(gn)
    Window.CloseOverlays()
    local perItem = Settings.GadgetPerItem[gn]
    if not perItem then
        perItem = { hitbox = false, filling = false, trail = false }
        Settings.GadgetPerItem[gn] = perItem
    end
    local label     = GADGET_LABEL[gn] or gn
    local isGrenade = (gn == "FragGrenade")

    -- rows: always Hitbox + Filling, Trail only for grenade
    local rows = {
        { key = "hitbox",  text = "Hitbox"  },
        { key = "filling", text = "Filling" },
    }
    if isGrenade then table.insert(rows, { key = "trail", text = "Trail" }) end

    local PAD      = 8
    local HDR_H    = 20
    local SEP_H    = 1
    local ROW_H    = 18
    local ROW_GAP  = 2
    local COLOR_H  = 18
    local POP_W    = 154
    local POP_H    = 2*PAD + HDR_H + SEP_H + 4 + #rows*(ROW_H+ROW_GAP) + SEP_H + 4 + COLOR_H

    -- anchor to current mouse cursor position (works regardless of GsLib internals)
    local mouse = UserInputService:GetMouseLocation()
    local ma  = Window.Main.AbsolutePosition
    local ms  = Window.Main.AbsoluteSize
    local px  = math.clamp(mouse.X - ma.X + 6, 4, ms.X - POP_W - 4)
    local py  = math.clamp(mouse.Y - ma.Y - 4, 4, ms.Y - POP_H - 4)

    -- click-outside closes popup
    local catch = Instance.new("TextButton")
    catch.Size = UDim2.fromScale(1,1); catch.BackgroundTransparency = 1
    catch.Text = ""; catch.ZIndex = 55; catch.AutoButtonColor = false
    catch.Parent = Window.Overlay
    catch.MouseButton1Click:Connect(function() Window.CloseOverlays() end)
    catch.MouseButton2Click:Connect(function() Window.CloseOverlays() end)

    -- popup frame
    local pop = Instance.new("Frame")
    pop.Size = UDim2.fromOffset(POP_W, POP_H)
    pop.Position = UDim2.fromOffset(px, py)
    pop.BackgroundColor3 = MyTheme.Panel
    pop.BorderSizePixel = 0; pop.ZIndex = 70
    pop.Parent = Window.Overlay
    local stroke = Instance.new("UIStroke")
    stroke.Color = MyTheme.IslandBorder; stroke.Thickness = 1
    stroke.Parent = pop

    -- header
    local hdr = Instance.new("TextLabel")
    hdr.Size = UDim2.new(1, -8, 0, HDR_H)
    hdr.Position = UDim2.fromOffset(PAD, PAD); hdr.BackgroundTransparency = 1; hdr.ZIndex = 71
    hdr.Font = Enum.Font.GothamBold; hdr.TextSize = 12
    hdr.Text = label; hdr.TextColor3 = MyTheme.Text
    hdr.TextXAlignment = Enum.TextXAlignment.Left; hdr.Parent = pop

    -- separator below header
    local function mkSep(yPos)
        local s = Instance.new("Frame")
        s.Size = UDim2.new(1, -2*PAD, 0, SEP_H)
        s.Position = UDim2.fromOffset(PAD, yPos)
        s.BackgroundColor3 = MyTheme.Border; s.BorderSizePixel = 0; s.ZIndex = 71
        s.Parent = pop
    end
    local sepY = PAD + HDR_H + 2
    mkSep(sepY)

    -- toggle rows inside popup
    local function mkPopToggle(key, text, yOff)
        local state = perItem[key] == true

        local sq2 = Instance.new("Frame")
        sq2.Size = UDim2.fromOffset(8, 8)
        sq2.Position = UDim2.fromOffset(PAD, yOff + (ROW_H-8)/2)
        sq2.BackgroundColor3 = state and MyTheme.Accent or MyTheme.CheckOff
        sq2.BorderSizePixel = 0; sq2.ZIndex = 72; sq2.Parent = pop

        local lbl3 = Instance.new("TextLabel")
        lbl3.Size = UDim2.new(1, -(PAD + 14), 0, ROW_H)
        lbl3.Position = UDim2.fromOffset(PAD + 14, yOff)
        lbl3.BackgroundTransparency = 1; lbl3.ZIndex = 72
        lbl3.Font = Enum.Font.Gotham; lbl3.TextSize = 13
        lbl3.Text = text; lbl3.TextColor3 = state and MyTheme.Text or MyTheme.Dim
        lbl3.TextXAlignment = Enum.TextXAlignment.Left; lbl3.Parent = pop

        local btn2 = Instance.new("TextButton")
        btn2.Size = UDim2.new(1, 0, 0, ROW_H)
        btn2.Position = UDim2.fromOffset(0, yOff)
        btn2.BackgroundTransparency = 1; btn2.Text = ""; btn2.ZIndex = 73
        btn2.AutoButtonColor = false; btn2.Parent = pop
        btn2.MouseButton1Click:Connect(function()
            perItem[key] = not perItem[key]
            local v = perItem[key]
            sq2.BackgroundColor3 = v and MyTheme.Accent or MyTheme.CheckOff
            lbl3.TextColor3      = v and MyTheme.Text   or MyTheme.Dim
        end)
    end

    local rowsY = sepY + SEP_H + 4
    for i, row in ipairs(rows) do
        mkPopToggle(row.key, row.text, rowsY + (i-1)*(ROW_H+ROW_GAP))
    end

    -- second separator before color row
    local sep2Y = rowsY + #rows*(ROW_H+ROW_GAP) + 1
    mkSep(sep2Y)

    -- color row
    local colorY = sep2Y + SEP_H + 4
    local colorLbl = Instance.new("TextLabel")
    colorLbl.Size = UDim2.fromOffset(50, ROW_H)
    colorLbl.Position = UDim2.fromOffset(PAD, colorY)
    colorLbl.BackgroundTransparency = 1; colorLbl.ZIndex = 72
    colorLbl.Font = Enum.Font.Gotham; colorLbl.TextSize = 13
    colorLbl.Text = "Color"; colorLbl.TextColor3 = MyTheme.Dim
    colorLbl.TextXAlignment = Enum.TextXAlignment.Left; colorLbl.Parent = pop

    -- color swatch (always shown; click closes popup and fires the row swatch)
    local swatchColor = Settings.GadgetItemColors[gn] or Settings.GadgetColor
    local swatch2 = Instance.new("TextButton")
    swatch2.Size = UDim2.fromOffset(26, 13)
    swatch2.Position = UDim2.fromOffset(PAD + 54, colorY + (ROW_H-13)/2)
    swatch2.BackgroundColor3 = swatchColor
    swatch2.BorderSizePixel = 0; swatch2.ZIndex = 73
    swatch2.Text = ""; swatch2.AutoButtonColor = false
    local sw2Stroke = Instance.new("UIStroke")
    sw2Stroke.Color = Color3.new(0,0,0); sw2Stroke.Thickness = 1
    sw2Stroke.Parent = swatch2; swatch2.Parent = pop
    swatch2.MouseButton1Click:Connect(function()
        Window.CloseOverlays()
        local toggle = wGadgetToggles[gn]
        if toggle and toggle.ColorPicker then
            toggle.ColorPicker:Open()
        end
    end)
end

-- populate toggle widgets
for _, def in ipairs(GADGET_DEFS) do
    local gn = def.Game
    local lb = def.Label
    if not Settings.GadgetShow[gn] then Settings.GadgetShow[gn] = false end
    if not Settings.GadgetPerItem[gn] then
        Settings.GadgetPerItem[gn] = { hitbox = false, filling = false, trail = false }
    end

    -- initialize per-gadget color with default so global color never overrides
    if not Settings.GadgetItemColors[gn] then
        Settings.GadgetItemColors[gn] = Color3.fromRGB(0, 255, 255)
    end
    if not Settings.GadgetItemColorAlpha[gn] then
        Settings.GadgetItemColorAlpha[gn] = 1
    end

    local w = GadgetLeft:AddToggle({
        Text     = lb,
        Default  = false,
        Callback = function(v) Settings.GadgetShow[gn] = v end,
    })
    wGadgetToggles[gn] = w

    w:AddColorPicker({
        Default  = Color3.fromRGB(0, 255, 255),
        Callback = function(c, a)
            Settings.GadgetItemColors[gn]     = c
            Settings.GadgetItemColorAlpha[gn] = a or 1
        end,
    })

    gadgetPopupRows[gn] = w.Row

    local gearBtn = Instance.new("TextButton")
    gearBtn.Size = UDim2.fromOffset(14, 13)
    gearBtn.BackgroundTransparency = 1
    gearBtn.BorderSizePixel = 0
    gearBtn.Text = "⚙"
    gearBtn.TextSize = 11
    gearBtn.Font = Enum.Font.Gotham
    gearBtn.TextColor3 = MyTheme.Muted
    gearBtn.ZIndex = 5
    gearBtn.LayoutOrder = 1
    gearBtn.AutoButtonColor = false
    gearBtn.MouseButton1Click:Connect(function() openGadgetPopup(gn) end)
    gearBtn.Parent = w.AddonHolder

    -- right-click on the toggle row opens the gadget popup
    if w.ClickButton then
        w.ClickButton.MouseButton2Click:Connect(function() openGadgetPopup(gn) end)
    end

    Bindings[#Bindings+1] = function()
        w:Set(Settings.GadgetShow[gn] == true)
        pcall(function()
            if w.ColorPicker and Settings.GadgetItemColors[gn] then
                w.ColorPicker:Set(Settings.GadgetItemColors[gn])
            end
        end)
    end
end

GadgetLeft:AddSection("Labels")
local wGadgetShowDist = GadgetLeft:AddToggle({
    Text = "Show Distance", Default = true,
    Callback = function(v) Settings.GadgetShowDistance = v end,
})
Bindings[#Bindings+1] = function() wGadgetShowDist:Set(Settings.GadgetShowDistance) end

local wGadgetMaxDist = GadgetRight:AddSlider({
    Text = "Max Distance", Min = 100, Max = 2000, Default = 1000, Suffix = "m",
    Callback = function(v) Settings.GadgetMaxDistance = v end,
})
Bindings[#Bindings+1] = function() wGadgetMaxDist:Set(Settings.GadgetMaxDistance) end


-- =====================
--       GUN TAB
-- =====================
local GunLeft  = GunTab:CreateGroup({ Name = "Weapon", Side = "Left" })
local GunRight = GunTab:CreateGroup({ Name = "Info",   Side = "Right" })

local wGunNoRecoil = GunLeft:AddToggle({ Text = "No Recoil", Default = false, Callback = function(v) Settings.GunNoRecoil = v end })
Bindings[#Bindings+1] = function() wGunNoRecoil:Set(Settings.GunNoRecoil) end
local wGunNoSpread = GunLeft:AddToggle({ Text = "No Spread", Default = false, Callback = function(v) Settings.GunNoSpread = v end })
Bindings[#Bindings+1] = function() wGunNoSpread:Set(Settings.GunNoSpread) end
local wGunRapidFire = GunLeft:AddToggle({ Text = "Rapid Fire", Default = false, Callback = function(v) Settings.GunRapidFire = v end })
Bindings[#Bindings+1] = function() wGunRapidFire:Set(Settings.GunRapidFire) end
local wGunFireRate = GunLeft:AddSlider({ Text = "Fire Rate", Min = 10, Max = 100, Default = 100, Suffix = "%",
    Callback = function(v) Settings.GunFireRate = v end })
Bindings[#Bindings+1] = function() wGunFireRate:Set(Settings.GunFireRate) end
local wGunInfiniteAmmo = GunLeft:AddToggle({ Text = "Infinite Ammo", Default = false, Callback = function(v) Settings.GunInfiniteAmmo = v end })
Bindings[#Bindings+1] = function() wGunInfiniteAmmo:Set(Settings.GunInfiniteAmmo) end
local wGunInstantReload = GunLeft:AddToggle({ Text = "Instant Reload", Default = false, Callback = function(v) Settings.GunInstantReload = v end })
Bindings[#Bindings+1] = function() wGunInstantReload:Set(Settings.GunInstantReload) end

-- saved originals for restore when Force Auto is turned off
local _forceAutoOriginals = {}

local function applyForceAuto(enable)
    Settings.GunForceAuto = enable
    if enable then
        -- patch module root
        pcall(function()
            local gnm = require(game:GetService("ReplicatedStorage").Modules.Items.Item.Gun)
            rawset(gnm, "automatic", true)
        end)
        -- patch every gc table that has automatic = false (semi-auto weapon configs)
        pcall(function()
            for _, obj in pairs(getgc(true)) do
                if type(obj) == "table" then
                    local ok, val = pcall(rawget, obj, "automatic")
                    if ok and val == false then
                        _forceAutoOriginals[obj] = false
                        rawset(obj, "automatic", true)
                    end
                end
            end
        end)
    else
        -- restore module root
        pcall(function()
            local gnm = require(game:GetService("ReplicatedStorage").Modules.Items.Item.Gun)
            rawset(gnm, "automatic", nil)
        end)
        -- restore all patched weapon tables
        for obj, orig in pairs(_forceAutoOriginals) do
            pcall(rawset, obj, "automatic", orig)
        end
        _forceAutoOriginals = {}
    end
end

GunLeft:AddSection("Force Auto")
local wGunForceAuto = GunLeft:AddToggle({
    Text = "Force Automatic", Default = false,
    Callback = applyForceAuto,
})
Bindings[#Bindings+1] = function() wGunForceAuto:Set(Settings.GunForceAuto) end

GunRight:AddParagraph({
    Title = "Cobalt-based hooks",
    Text  = "NoSpread replaces the shoot CFrame with clean camera aim + re-raycast. NoRecoil freezes the camera for 150ms after each shot.",
})
GunRight:AddParagraph({
    Title = "Force Automatic",
    Text  = "Sets automatic = true directly in the Gun module table via rawset, bypassing __newindex guards. Affects all weapons. Toggle off restores the original value.",
})

-- =====================
--     FULLBRIGHT
-- =====================
local function applyFullbright(enable)
    Settings.FullbrightEnabled = enable
    if enable then
        if not _origLighting then
            _origLighting = {
                Brightness    = Lighting.Brightness,
                ClockTime     = Lighting.ClockTime,
                FogEnd        = Lighting.FogEnd,
                GlobalShadows = Lighting.GlobalShadows,
                Ambient       = Lighting.Ambient,
            }
        end
        pcall(function()
            Lighting.Brightness    = Settings.FullbrightBrightness
            Lighting.ClockTime     = Settings.FullbrightClockTime
            Lighting.FogEnd        = 786543
            Lighting.GlobalShadows = false
            Lighting.Ambient       = Color3.fromRGB(178, 178, 178)
        end)
    else
        if _origLighting then
            pcall(function()
                Lighting.Brightness    = _origLighting.Brightness
                Lighting.ClockTime     = _origLighting.ClockTime
                Lighting.FogEnd        = _origLighting.FogEnd
                Lighting.GlobalShadows = _origLighting.GlobalShadows
                Lighting.Ambient       = _origLighting.Ambient
            end)
            _origLighting = nil
        end
    end
end

-- keep lighting locked every frame in case a game LocalScript fights back
RunService:BindToRenderStep("GsFullbright", Enum.RenderPriority.Last.Value, function()
    if Settings.FullbrightEnabled then
        pcall(function()
            Lighting.Brightness    = Settings.FullbrightBrightness
            Lighting.ClockTime     = Settings.FullbrightClockTime
            Lighting.FogEnd        = 786543
            Lighting.GlobalShadows = false
            Lighting.Ambient       = Color3.fromRGB(178, 178, 178)
        end)
    end
end)

-- forward declared here so the button callback below can capture the upvalue
local smokeSampleFn = nil

-- =====================
--       MISC TAB
-- =====================
local MiscLeft  = MiscTab:CreateGroup({ Name = "Visual",  Side = "Left" })
local MiscRight = MiscTab:CreateGroup({ Name = "Info",    Side = "Right" })

MiscLeft:AddSection("Grenades")

local wAntiSmoke = MiscLeft:AddToggle({
    Text = "Anti-Smoke", Default = false,
    Callback = function(v) Settings.AntiSmoke = v end,
})
Bindings[#Bindings+1] = function() wAntiSmoke:Set(Settings.AntiSmoke) end

local wAntiSmokeHitbox = MiscLeft:AddToggle({
    Text     = "  Show Hitbox",
    Default  = false,
    Callback = function(v) Settings.AntiSmokeHitbox = v end,
})
Bindings[#Bindings+1] = function() wAntiSmokeHitbox:Set(Settings.AntiSmokeHitbox) end

local wAntiFlash = MiscLeft:AddToggle({
    Text = "Anti-Flash", Default = false,
    Callback = function(v)
        Settings.AntiFlash = v
        if flashGui then
            pcall(function() flashGui.Enabled = not v end)
        end
    end,
})
Bindings[#Bindings+1] = function() wAntiFlash:Set(Settings.AntiFlash) end

MiscLeft:AddSection("Debug")

local wSmokeDebug = MiscLeft:AddToggle({
    Text = "Smoke Debug Overlay", Default = false,
    Callback = function(v) Settings.SmokeDebug = v end,
})
Bindings[#Bindings+1] = function() wSmokeDebug:Set(Settings.SmokeDebug) end

MiscLeft:AddButton({
    Text = "Sample Smoke Now",
    Callback = function()
        if smokeSampleFn then smokeSampleFn() end
    end,
})

MiscLeft:AddSection("Fullbright")

local wFullbright = MiscLeft:AddToggle({
    Text = "Fullbright", Default = false,
    Callback = applyFullbright,
})
Bindings[#Bindings+1] = function() wFullbright:Set(Settings.FullbrightEnabled) end

local wFBBrightness = MiscLeft:AddSlider({
    Text = "Brightness", Min = 0, Max = 5, Default = 2, Decimals = 1,
    Callback = function(v)
        Settings.FullbrightBrightness = v
        if Settings.FullbrightEnabled then
            pcall(function() Lighting.Brightness = v end)
        end
    end,
})
Bindings[#Bindings+1] = function() wFBBrightness:Set(Settings.FullbrightBrightness) end

local wFBClockTime = MiscLeft:AddSlider({
    Text = "Clock Time", Min = 0, Max = 24, Default = 14, Decimals = 1,
    Callback = function(v)
        Settings.FullbrightClockTime = v
        if Settings.FullbrightEnabled then
            pcall(function() Lighting.ClockTime = v end)
        end
    end,
})
Bindings[#Bindings+1] = function() wFBClockTime:Set(Settings.FullbrightClockTime) end

MiscLeft:AddSection("Camera")

local freecamCF      = nil
local origCamType    = nil
local origMouseBehav = nil
local FREECAM_STEP = "GsFreecam"
local TP_STEP      = "GsThirdPerson"

local function applyFreecam(enable)
    Settings.FreecamEnabled = enable
    if enable then
        local cam = workspace.CurrentCamera
        freecamCF      = cam.CFrame
        origCamType    = cam.CameraType
        origMouseBehav = UserInputService.MouseBehavior
        pcall(function() cam.CameraType = Enum.CameraType.Scriptable end)
        pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter end)
        RunService:BindToRenderStep(FREECAM_STEP, Enum.RenderPriority.Camera.Value + 2, function(dt)
            if not Settings.FreecamEnabled then return end
            local cam2 = workspace.CurrentCamera
            if cam2.CameraType ~= Enum.CameraType.Scriptable then
                pcall(function() cam2.CameraType = Enum.CameraType.Scriptable end)
            end
            local speed = Settings.FreecamSpeed * 40 * dt
            local delta = UserInputService:GetMouseDelta()
            local cf = freecamCF
            if delta.Magnitude > 0 then
                cf = CFrame.new(cf.Position)
                    * CFrame.Angles(0, math.rad(-delta.X * 0.3), 0)
                    * (cf - cf.Position)
                    * CFrame.Angles(math.rad(-delta.Y * 0.3), 0, 0)
            end
            local fwd  = UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0
            local back = UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0
            local rgt  = UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0
            local lft  = UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0
            local up   = UserInputService:IsKeyDown(Enum.KeyCode.E) and 1 or 0
            local down = UserInputService:IsKeyDown(Enum.KeyCode.Q) and 1 or 0
            local mv = cf.LookVector * (fwd - back) + cf.RightVector * (rgt - lft)
                       + Vector3.new(0, up - down, 0)
            if mv.Magnitude > 0.001 then
                cf = CFrame.new(cf.Position + mv.Unit * speed) * (cf - cf.Position)
            end
            freecamCF = cf
            cam2.CFrame = cf
        end)
    else
        RunService:UnbindFromRenderStep(FREECAM_STEP)
        pcall(function()
            workspace.CurrentCamera.CameraType = origCamType or Enum.CameraType.Custom
        end)
        pcall(function()
            UserInputService.MouseBehavior = origMouseBehav or Enum.MouseBehavior.Default
        end)
        freecamCF = nil; origCamType = nil; origMouseBehav = nil
    end
end

local _tpOrigCamType = nil
local _tpPitch       = 0

local function applyThirdPerson(enable)
    Settings.ThirdPerson = enable
    if enable then
        local cam = workspace.CurrentCamera
        _tpOrigCamType = cam.CameraType
        _tpPitch = 0
        pcall(function() cam.CameraType = Enum.CameraType.Scriptable end)
        RunService:BindToRenderStep(TP_STEP, Enum.RenderPriority.Camera.Value + 2, function()
            local cam2 = workspace.CurrentCamera
            if cam2.CameraType ~= Enum.CameraType.Scriptable then
                pcall(function() cam2.CameraType = Enum.CameraType.Scriptable end)
            end
            local char = LocalPlayer.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local delta = UserInputService:GetMouseDelta()
            _tpPitch = math.clamp(_tpPitch - delta.Y * 0.003, math.rad(-75), math.rad(75))
            local dist = Settings.ThirdPersonDistance
            cam2.CFrame = hrp.CFrame
                * CFrame.new(0, 1.5, 0)
                * CFrame.Angles(_tpPitch, 0, 0)
                * CFrame.new(0, 0, dist)
        end)
    else
        RunService:UnbindFromRenderStep(TP_STEP)
        pcall(function()
            workspace.CurrentCamera.CameraType = _tpOrigCamType or Enum.CameraType.Custom
        end)
        _tpOrigCamType = nil
        _tpPitch = 0
    end
end

local wFreecam = MiscLeft:AddToggle({
    Text = "Freecam", Default = false,
    Callback = applyFreecam,
})
wFreecam:AddKeybind({ Mode = "Toggle", Callback = function(v) wFreecam:Set(v) end })
Bindings[#Bindings+1] = function() wFreecam:Set(Settings.FreecamEnabled) end

local wFreecamSpeed = MiscLeft:AddSlider({
    Text = "Speed", Min = 1, Max = 20, Default = 3,
    Callback = function(v) Settings.FreecamSpeed = v end,
})
Bindings[#Bindings+1] = function() wFreecamSpeed:Set(Settings.FreecamSpeed) end

local wThirdPerson = MiscLeft:AddToggle({
    Text = "Third Person", Default = false,
    Callback = applyThirdPerson,
})
wThirdPerson:AddKeybind({ Mode = "Toggle", Callback = function(v) wThirdPerson:Set(v) end })
Bindings[#Bindings+1] = function() wThirdPerson:Set(Settings.ThirdPerson) end

local wTPDist = MiscLeft:AddSlider({
    Text = "View Distance", Min = 2, Max = 30, Default = 12,
    Callback = function(v)
        Settings.ThirdPersonDistance = v
        if Settings.ThirdPerson then
            pcall(function() LocalPlayer.CameraMaxZoomDistance = v end)
        end
    end,
})
Bindings[#Bindings+1] = function() wTPDist:Set(Settings.ThirdPersonDistance) end

MiscRight:AddParagraph({
    Title = "Anti-Smoke",
    Text  = "Hides SmokePart objects in workspace. Uses LocalTransparencyModifier (client-only, not server-visible).",
})
MiscRight:AddParagraph({
    Title = "Anti-Flash",
    Text  = "Keeps PlayerGui.Flash.Frame transparent every frame. GetPropertyChangedSignal hook prevents detection.",
})

-- =====================
--    CONFIG SYSTEM
-- =====================
local function applyBindings()
    for _, fn in ipairs(Bindings) do pcall(fn) end
end

local CFGS_FOLDER   = "OpOne_Configs"
local AUTOLOAD_FILE = CFGS_FOLDER .. "/autoload.txt"

local function cfgPath(name) return CFGS_FOLDER .. "/" .. name .. ".json" end

local function ensureFolder()
    pcall(function()
        if not isfolder(CFGS_FOLDER) then makefolder(CFGS_FOLDER) end
    end)
end

local function serializeValue(v)
    if typeof(v) == "Color3" then
        return { __c = true,
                 r = math.floor(v.R * 255 + .5),
                 g = math.floor(v.G * 255 + .5),
                 b = math.floor(v.B * 255 + .5) }
    elseif type(v) == "table" then
        local t = {}
        for k2, v2 in pairs(v) do t[k2] = serializeValue(v2) end
        return t
    else
        return v
    end
end

local function deserializeValue(v)
    if type(v) == "table" and v.__c then
        return Color3.fromRGB(v.r, v.g, v.b)
    elseif type(v) == "table" then
        local t = {}
        for k2, v2 in pairs(v) do t[k2] = deserializeValue(v2) end
        return t
    else
        return v
    end
end

local function saveConfig(name)
    ensureFolder()
    pcall(function()
        if wAimbotEnabled and wAimbotEnabled.Keybind then
            local key = wAimbotEnabled.Keybind:Get()
            if key then Settings.AimbotKeybind = tostring(key) end
        end
    end)
    local t = {}
    for k, v in pairs(Settings) do t[k] = serializeValue(v) end
    pcall(writefile, cfgPath(name), HttpService:JSONEncode(t))
end

local function loadConfig(name)
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(cfgPath(name)))
    end)
    if not ok or not data then return false end
    for k, v in pairs(data) do
        if Settings[k] ~= nil then
            Settings[k] = deserializeValue(v)
        end
    end
    -- refill any gadget entries missing from old configs
    for _, def in ipairs(GADGET_DEFS) do
        local gn = def.Game
        if not Settings.GadgetShow[gn] then Settings.GadgetShow[gn] = false end
        if not Settings.GadgetPerItem[gn] then
            Settings.GadgetPerItem[gn] = { hitbox = false, filling = false, trail = false }
        end
        if not Settings.GadgetItemColors[gn] then
            Settings.GadgetItemColors[gn] = Color3.fromRGB(0, 255, 255)
        end
        if not Settings.GadgetItemColorAlpha[gn] then
            Settings.GadgetItemColorAlpha[gn] = 1
        end
    end
    return true
end

local function listConfigs()
    ensureFolder()
    local out = {}
    pcall(function()
        for _, path in ipairs(listfiles(CFGS_FOLDER)) do
            -- match filename without extension, skip autoload.txt
            local n = path:match("[/\\]([^/\\]+)%.json$") or path:match("^([^/\\]+)%.json$")
            if n then table.insert(out, n) end
        end
    end)
    table.sort(out)
    return out
end

local function getAutoload()
    local ok, v = pcall(readfile, AUTOLOAD_FILE)
    return (ok and v and v ~= "") and v or nil
end

local function setAutoload(name)
    ensureFolder()
    pcall(writefile, AUTOLOAD_FILE, name or "")
end

-- =====================
--     SKINS TAB
-- =====================
do
local SkinLeft  = SkinTab:CreateGroup({ Name = "Weapon Skin", Side = "Left"  })
local SkinRight = SkinTab:CreateGroup({ Name = "Character",   Side = "Right" })

-- ---- Weapon database (primary / secondary guns) ----
local WEAPON_DB = {
    { name="M4",              wtype="primary",   display="M4"              },
    { name="MP5",             wtype="primary",   display="MP5"             },
    { name="M14",             wtype="primary",   display="M14"             },
    { name="AW50",            wtype="primary",   display="AW50"            },
    { name="M590",            wtype="primary",   display="M590"            },
    { name="SPAS12",          wtype="primary",   display="SPAS-12"         },
    { name="AA12",            wtype="primary",   display="AA-12"           },
    { name="M249",            wtype="primary",   display="M249"            },
    { name="AUG",             wtype="primary",   display="AUG"             },
    { name="MP7",             wtype="primary",   display="MP7"             },
    { name="AK12",            wtype="primary",   display="AK-12"           },
    { name="L85A2",           wtype="primary",   display="L85A2"           },
    { name="M60",             wtype="primary",   display="M60"             },
    { name="Vector",          wtype="primary",   display="Vector"          },
    { name="P90",             wtype="primary",   display="P90"             },
    { name="M16",             wtype="primary",   display="M16"             },
    { name="SCARH",           wtype="primary",   display="SCAR-H"          },
    { name="G36",             wtype="primary",   display="G36"             },
    { name="DP47",            wtype="primary",   display="DP-47"           },
    { name="Famas",           wtype="primary",   display="Famas"           },
    { name="CAL12",           wtype="primary",   display="CAL12"           },
    { name="M24",             wtype="primary",   display="M24"             },
    { name="L1A1",            wtype="primary",   display="L1A1"            },
    { name="M82",             wtype="primary",   display="Harrow M82"      },
    { name="HK69",            wtype="primary",   display="HK69"            },
    { name="M32",             wtype="primary",   display="M-32"            },
    { name="BallisticShield", wtype="primary",   display="Ballistic Shield"},
    { name="RiotShield",      wtype="primary",   display="Riot Shield"     },
    { name="Glock",           wtype="secondary", display="G7"              },
    { name="TaurusJudge",     wtype="secondary", display="T-Judge"         },
    { name="FN57",            wtype="secondary", display="FN-57"           },
    { name="Beretta",         wtype="secondary", display="Beretta"         },
    { name="Deagle",          wtype="secondary", display="Deagle"          },
    { name="Colt",            wtype="secondary", display="Colt"            },
    { name="CZ75",            wtype="secondary", display="CZ75"            },
    { name="Anaconda",        wtype="secondary", display="Anaconda"        },
    { name="Skorpion",        wtype="secondary", display="Skorpion"        },
    { name="RSh12",           wtype="secondary", display="RSh-12"          },
    { name="PT24",            wtype="secondary", display="PT24"            },
    { name="MAC11",           wtype="secondary", display="MAC-11"          },
    { name="Reaper",          wtype="secondary", display="Reaper"          },
    { name="SuperShorty",     wtype="secondary", display="Super Shorty"    },
}

-- ---- Skin database ----
-- weapons="all"  → inherited from base Skin (no t.items override) → all primary+secondary
-- weapons={...}  → weapon-specific skin
-- weapons={}     → empty (unknown sub-scripts / non-gun utility item)
-- variants={...} → per-weapon module name override (sub-scripts)
local SKIN_DB = {
    { display="Blue",              module="Blue",              weapons="all" },
    { display="Diamond",           module="Diamond",           weapons="all" },
    { display="Golden",            module="Golden",            weapons="all" },
    { display="Green",             module="Green",             weapons="all" },
    { display="Red",               module="Red",               weapons="all" },
    { display="Space",             module="Space",             weapons="all" },
    { display="Tan",               module="Tan",               weapons="all" },
    { display="White",             module="White",             weapons="all" },
    { display="Yellow",            module="Yellow",            weapons="all" },
    { display="Glacier",           module="Glacier",           weapons="all" },
    { display="Dark Ice",          module="BlackIce",          weapons={},
      variants={ MP5="BlackIceMP5", AK12="BlackIceAK12", M590="BlackIceM590",
                 M14="BlackIceM14", AW50="BlackIceAW50", TaurusJudge="BlackIceTaurusJudge",
                 BallisticShield="BlackIceBallisticShield" } },
    { display="Wood Finish",       module="Kalash",            weapons={"AK12","Skorpion"},
      variants={ M14="KalashM14" } },
    { display="Antique",           module="AntiqueAnaconda",   weapons={"Anaconda"} },
    { display="Black Camo",        module="BlackCamo",         weapons={"AW50"} },
    { display="Blue Flowers",      module="BlueFlowers",       weapons={"SPAS12"} },
    { display="Candy Cane",        module="CandyCane",         weapons={"P90","FN57"} },
    { display="Carbon Fiber",      module="CarbonFiber",       weapons={"CAL12"} },
    { display="Checkered",         module="CheckeredSkin",     weapons={"M24"} },
    { display="Cherry Blossom",    module="CherryBlossom",     weapons={"AUG","TaurusJudge"} },
    { display="Classic AA-12",     module="ClassicAA12",       weapons={"AA12"} },
    { display="Classic AUG",       module="Steyr",             weapons={"AUG"} },
    { display="Classic L85",       module="ClassicL85",        weapons={"L85A2"} },
    { display="Cracked Earth",     module="CrackedEarth",      weapons={"Deagle"} },
    { display="Dark Red Camo",     module="DarkRedCamo",       weapons={"Famas"} },
    { display="Deep Red",          module="DeepRed",           weapons={"SPAS12"} },
    { display="Desert Camo",       module="DesertCamo",        weapons={"M60"} },
    { display="Festive Lights",    module="FestiveLightsM4",   weapons={"M4"} },
    { display="Forest Camo",       module="ForestCamo",        weapons={"M24"} },
    { display="French Sticker",    module="FrenchSticker",     weapons={"Famas"} },
    { display="Ghillie",           module="Ghillie",           weapons={"AW50"} },
    { display="Ghost",             module="GhostSkin",         weapons={} },
    { display="Ghost Ship",        module="GhostShipSkin",     weapons={"HK69"} },
    { display="Ghost Sticker",     module="GhostStickerSkin",  weapons={"Vector"} },
    { display="Halloween Party",   module="HalloweenParty",    weapons={"MP7"} },
    { display="Hazard M4",         module="HazardSkin",        weapons={"M4"} },
    { display="Hazard MP7",        module="HazardMP7",         weapons={"MP7"} },
    { display="Hot Red",           module="HotRedL85",         weapons={"L85A2"} },
    { display="Makeshift",         module="MakeshiftBeretta",  weapons={"Beretta"} },
    { display="Medieval Shield",   module="MedievalShield",    weapons={"RiotShield"} },
    { display="Neon Shapes",       module="NeonShapesM249",    weapons={"M249"} },
    { display="Oil Spill",         module="OilSpill",          weapons={"Colt"} },
    { display="Purple Fade",       module="PurpleFadeCZ75",    weapons={"CZ75"} },
    { display="Red Line AW50",     module="RedLineAW50",       weapons={"AW50"} },
    { display="Red Line Reaper",   module="RedLineReaper",     weapons={"Reaper"} },
    { display="Red Roses",         module="RedRoses",          weapons={"M16"} },
    { display="Royal",             module="RoyalCAL12",        weapons={"CAL12"} },
    { display="Rusty",             module="RustyAUG",          weapons={"AUG"} },
    { display="Skulls",            module="Skulls",            weapons={"Glock"} },
    { display="Snow Camo",         module="SnowCamo",          weapons={"MP7"} },
    { display="Spider Web",        module="SpiderWebSkin",     weapons={"L1A1"} },
    { display="Splattered",        module="Splattered",        weapons={"Anaconda"} },
    { display="Synthwave",         module="Synthwave",         weapons={"L1A1"} },
    { display="Tidal Wave",        module="TidalWaveAK",       weapons={"AK12"} },
    { display="Tiger Camo",        module="TigerCamo",         weapons={"Vector"} },
    { display="Toy Gun",           module="ToyGunM4",          weapons={"M4"} },
    { display="Toxic",             module="Toxic",             weapons={"M82"} },
    { display="Wasteland",         module="WastelandRSh12",    weapons={"RSh12"} },
    { display="Yellow Pattern",    module="YellowPattern",     weapons={} },
    -- Utility / throwable item skins (★ for all guns)
    { display="Candy Cane Crowbar",module="CandyCaneCrowbar",  weapons={"Crowbar"} },
    { display="Dynamite",          module="DynamiteC4",        weapons={"RemoteC4"} },
    { display="Ice Drone",         module="IceDrone",          weapons={"Drone"} },
    { display="Karambit",          module="Karambit",          weapons={"MilitaryKnife"} },
    { display="Ornament",          module="OrnamentBall",      weapons={"FragGrenade"} },
    { display="Pumpkin Bomb",      module="PumpkinBomb",       weapons={"ImpactGrenade"} },
    { display="Scythe",            module="ScytheHammer",      weapons={"BreachingHammer"} },
    { display="Spider Hook",       module="SpiderHookSkin",    weapons={"GrapplingHook"} },
}

local OUTFIT_DEFS = {
    { label = "Bomb Suit",       name = "BombSuit"           },
    { label = "Fancy Bowtie",    name = "BowtieCostume"      },
    { label = "Commando",        name = "CommandoOutfit"     },
    { label = "Farmer",          name = "FarmerOutfit"       },
    { label = "Field",           name = "FieldOutfit"        },
    { label = "Ghillie Suit",    name = "GhillieSuit"        },
    { label = "Nutcracker",      name = "NutcrackerOutfit"   },
    { label = "Aviator",         name = "PilotOutfit"        },
    { label = "Rescue Mission",  name = "RescueMissionOutfit"},
    { label = "Robber",          name = "RobberOutfit"       },
    { label = "Rocker",          name = "RockerOutfit"       },
    { label = "Salon",           name = "SalonOutfit"        },
    { label = "Santa",           name = "SantaOutfit"        },
    { label = "Skeleton",        name = "SkeletonOutfit"     },
    { label = "Specter",         name = "SpecterOutfit"      },
}
local CHARM_DEFS = {
    { label = "8 Ball",          name = "8BallCharm"          },
    { label = "Ace",             name = "AceCharm"            },
    { label = "Banana",          name = "BananaCharm"         },
    { label = "Bell",            name = "BellCharm"           },
    { label = "Boom",            name = "BoomCharm"           },
    { label = "Bullet",          name = "BulletCharm"         },
    { label = "Christmas Tree",  name = "ChristmasTreeCharm"  },
    { label = "Diamond",         name = "DiamondCharm"        },
    { label = "Diamond Burger",  name = "DiamondBurgerCharm"  },
    { label = "Dog Tag",         name = "DogTagCharm"         },
    { label = "Eyeball",         name = "EyeballCharm"        },
    { label = "Fish",            name = "FishCharm"           },
    { label = "Ghost",           name = "GhostCharm"          },
    { label = "Hourglass",       name = "HourglassCharm"      },
    { label = "Jussis",          name = "JussisCharm"         },
    { label = "Lucky Clover",    name = "LuckyCharm"          },
    { label = "Medal",           name = "MedalTVCharm"        },
    { label = "NXT",             name = "NXTCharm"            },
    { label = "Pumpkin",         name = "PumpkinCharm"        },
    { label = "Snow Globe",      name = "SnowGlobeCharm"      },
    { label = "Snowflake",       name = "SnowflakeCharm"      },
    { label = "Staff",           name = "StaffCharm"          },
    { label = "Target Practice", name = "TargetPracticeCharm" },
    { label = "TSK",             name = "TSKCharm"            },
    { label = "Walkie Talkie",   name = "WalkieTalkieCharm"   },
    { label = "Yin Yang",        name = "YinYangCharm"        },
}
local HAT_DEFS = {
    { label = "Ballistic Helmet",       name = "BallisticHelmet"   },
    { label = "Beanie",                 name = "Beanie"            },
    { label = "Bomb Helmet",            name = "BombHelmet"        },
    { label = "Commando Bandana",       name = "CommandoBandana"   },
    { label = "Cowboy",                 name = "CowboyFedora"      },
    { label = "Cowl",                   name = "CowlHat"           },
    { label = "Farmer Hat",             name = "FarmerHat"         },
    { label = "Field Helmet",           name = "FieldHelmet"       },
    { label = "French Hat",             name = "FrenchHat"         },
    { label = "Gas Mask",               name = "GasMask"           },
    { label = "Ghillie Hood",           name = "GhillieHood"       },
    { label = "Ghost Mask",             name = "GhostMask"         },
    { label = "Goggles",                name = "Goggles"           },
    { label = "Headphones",             name = "Headphones"        },
    { label = "Killer Clown",           name = "KillerClown"       },
    { label = "Maska-1",                name = "Maska1"            },
    { label = "Military Hat",           name = "MilitaryHat"       },
    { label = "Nutcracker Hat",         name = "NutcrackerHat"     },
    { label = "Aviator Helmet",         name = "PilotHelmet"       },
    { label = "Pumpkin Head",           name = "PumpkinHead"       },
    { label = "Raindeer Headband",      name = "RaindeerHeadband"  },
    { label = "Red Bandana",            name = "RedBandana"        },
    { label = "Red Beret",              name = "RedBeret"          },
    { label = "Robber Mask",            name = "RobberMask"        },
    { label = "Rocker Mohawk",          name = "RockerMohawk"      },
    { label = "Neckerchief",            name = "SandNeckerchief"   },
    { label = "Santa Hat",              name = "SantaHat"          },
    { label = "Scout Cap",              name = "ScoutCap"          },
    { label = "Secret Service Glasses", name = "SecretSunglasses"  },
    { label = "Shutter Shades",         name = "ShutterShades"     },
    { label = "Ski Goggles",            name = "SkiGoggles"        },
    { label = "Ski Mask",               name = "SkiMask"           },
    { label = "Slasher",                name = "Slasher"           },
    { label = "Snowman Head",           name = "SnowmanHead"       },
    { label = "Specter Mask",           name = "SpecterMask"       },
    { label = "SWAT Helmet",            name = "SWATHelmet"        },
    { label = "Tophat",                 name = "Tophat"            },
    { label = "TV Head",                name = "TVHead"            },
    { label = "Witch Hat",              name = "WitchHat"          },
}

-- outfit / hat / charm lookups
local outfitLabelToName, hatLabelToName, charmLabelToName = {}, {}, {}
local outfitOptions, hatOptions, charmOptions = {}, {}, {}
for _, d in ipairs(OUTFIT_DEFS) do outfitLabelToName[d.label] = d.name; table.insert(outfitOptions, d.label) end
for _, d in ipairs(HAT_DEFS)    do hatLabelToName[d.label]    = d.name; table.insert(hatOptions,    d.label) end
for _, d in ipairs(CHARM_DEFS)  do charmLabelToName[d.label]  = d.name; table.insert(charmOptions,  d.label) end

-- skin helpers
local _skinByDisplay = {}
for _, def in ipairs(SKIN_DB) do _skinByDisplay[def.display] = def end

local function _scIsNative(def, wname)
    if def.weapons == "all" then return true end
    if def.variants and def.variants[wname] then return true end
    if type(def.weapons) == "table" then
        for _, w in ipairs(def.weapons) do if w == wname then return true end end
    end
    return false
end
local function _scResolveMod(def, wname)
    if wname and def.variants and def.variants[wname] then return def.variants[wname] end
    return def.module
end
local function _scFindDef(optStr)
    return _skinByDisplay[optStr:gsub("^%* ", "")]
end

local function _scPerWeaponOpts(wname)
    local native, nonnative = {}, {}
    for _, def in ipairs(SKIN_DB) do
        if _scIsNative(def, wname) then
            table.insert(native, def.display)
        else
            table.insert(nonnative, "* " .. def.display)
        end
    end
    table.sort(native); table.sort(nonnative)
    local out = {"Default", "-"}
    for _, v in ipairs(native)    do table.insert(out, v) end
    for _, v in ipairs(nonnative) do table.insert(out, v) end
    return out
end

-- skin option list: "all" weapons first (no marker), weapon-specific with "* " prefix
local _skinOptsAll = {}
do
    local a, b = {}, {}
    for _, def in ipairs(SKIN_DB) do
        if def.weapons == "all" then table.insert(a, def.display)
        else table.insert(b, "* " .. def.display) end
    end
    table.sort(a); table.sort(b)
    for _, v in ipairs(a) do table.insert(_skinOptsAll, v) end
    for _, v in ipairs(b) do table.insert(_skinOptsAll, v) end
end

-- weapon option list
local _weaponOpts = {}
local _weaponByOpt = {}
for _, w in ipairs(WEAPON_DB) do
    local opt = w.display
    table.insert(_weaponOpts, opt)
    _weaponByOpt[opt] = w
end

-- Net module (lazy)
local _scNet
local function scModules()
    if _scNet then return _scNet end
    local ok, Net = pcall(require, game.ReplicatedStorage.Modules.Net)
    if ok then _scNet = Net end
    return _scNet
end
local function scApplyAll(slot, itemName)
    pcall(function()
        local Net = scModules()
        if not Net then return end
        local event = "equip_class_" .. slot
        for i = 1, 10 do pcall(function() Net.send(event, i, itemName) end) end
    end)
end

local _origPartState = setmetatable({}, { __mode = "k" })

local function scSavePartState(part)
    if _origPartState[part] then return end
    local s = {
        Color        = part.Color,
        Material     = part.Material,
        Transparency = part.Transparency,
        Reflectance  = part.Reflectance,
    }
    pcall(function() s.MaterialVariant = part.MaterialVariant end)
    _origPartState[part] = s
end

local function scRestorePartState(part)
    local s = _origPartState[part]
    if not s then return end
    pcall(function() part.Color           = s.Color        end)
    pcall(function() part.Material        = s.Material     end)
    pcall(function() part.Transparency    = s.Transparency end)
    pcall(function() part.Reflectance     = s.Reflectance  end)
    pcall(function() part.MaterialVariant = s.MaterialVariant or "" end)
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("Texture") or child:IsA("Decal") or child:IsA("SurfaceAppearance") then
            pcall(function() child:Destroy() end)
        end
    end
end

-- Client-side skin fallbacks keyed by module name.
-- Each function receives the whole weapon Model, allowing multi-pass logic
-- such as camera-distance gradients that need to scan all parts first.
-- Only Metal is excluded — body parts are often dark/black, so no color-based split.
local _skinClientPartApply = {}
do
    local METAL = Color3.fromRGB(163, 162, 165)
    local function colClose(a, b)
        return math.abs(a.R-b.R)<0.03 and math.abs(a.G-b.G)<0.03 and math.abs(a.B-b.B)<0.03
    end

    -- Projects each part's center onto the camera's LookVector (barrel-axis depth).
    -- More accurate than euclidean distance for FPS viewmodels where all parts are
    -- at similar camera distances but spread along the barrel (Z) axis.
    -- t = 0 → grip end (shallow depth, dark); t = 1 → muzzle end (deep, bright).
    local function collectGradientParts(model, camCF)
        local camPos = camCF.Position
        local camFwd = camCF.LookVector
        local parts = {}
        local minD, maxD = math.huge, -math.huge
        for _, part in ipairs(model:GetDescendants()) do
            if not part:IsA("BasePart") then continue end
            if part.Transparency > 0.5 then continue end
            if colClose(part.Color, METAL) then continue end
            local d = (part.Position - camPos):Dot(camFwd)
            if d < minD then minD = d end
            if d > maxD then maxD = d end
            table.insert(parts, { p = part, d = d })
        end
        local range = maxD - minD
        for _, e in ipairs(parts) do
            e.t = (range > 0.05) and ((e.d - minD) / range) or 0.5
        end
        return parts
    end

    -- Dark Ice: dark teal at grip end → bright teal/ice at muzzle.
    local DARK_ICE = Color3.fromRGB(35,  88,  82)
    local ICE      = Color3.fromRGB(105, 176, 164)
    _skinClientPartApply["BlackIce"] = function(model)
        local parts = collectGradientParts(model, workspace.CurrentCamera.CFrame)
        for _, e in ipairs(parts) do
            e.p.Color    = DARK_ICE:Lerp(ICE, e.t)
            e.p.Material = Enum.Material.Ice
            pcall(function() e.p.MaterialVariant = "DarkIce" end)
        end
    end

    -- Glacier: smoothstep-Gradient dunkel (Grip) → hell (Mündung), alles Ice-Material.
    -- Keine Decals (überdecken die Part.Color), kein Size-Filter, kein native-Fallback.
    local GLACIER_DARK  = Color3.fromRGB(20,  20,  20 )
    local GLACIER_LIGHT = Color3.fromRGB(230, 230, 230)

    _skinClientPartApply["Glacier"] = function(model)
        local parts = collectGradientParts(model, workspace.CurrentCamera.CFrame)
        for _, e in ipairs(parts) do
            local p, t = e.p, e.t
            -- Transition erst ab t=0.35 → Body/Rail/Underbody (t≈0.29–0.33) bleiben bei DARK
            local tt = math.clamp((t - 0.35) / 0.65, 0, 1)
            local x  = tt * tt * (3 - 2 * tt)
            local gc = GLACIER_DARK:Lerp(GLACIER_LIGHT, x)
            p.Color       = gc
            p.Material    = Enum.Material.Ice
            p.Reflectance = 0.1
        end
    end
end

-- Apply a named skin module to all BaseParts inside a specific weapon Model.
-- _skinClientPartApply always wins if defined (e.g. Glacier gradient).
-- Falls back to native part_apply; if neither, does nothing.
local function scApplySkinToModel(model, moduleName)
    pcall(function()
        local modelApply = _skinClientPartApply[moduleName]
        local partApply, skinMod = nil, nil
        if not modelApply then
            local skinFolder = game.ReplicatedStorage.Modules.Items.Item.Attachment.Skin
            local modInst = skinFolder:FindFirstChild(moduleName, true)
            if modInst then
                local ok2, sm = pcall(require, modInst)
                if ok2 and sm then
                    skinMod   = sm
                    partApply = rawget(sm, "part_apply")
                end
            end
        end
        if not partApply and not modelApply then return end
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then scSavePartState(part) end
        end
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then scRestorePartState(part) end
        end
        if modelApply then
            pcall(modelApply, model)
        else
            for _, part in ipairs(model:GetDescendants()) do
                if part:IsA("BasePart") then pcall(partApply, skinMod, part) end
            end
        end
    end)
end

-- Reset all BaseParts in a weapon Model to their snapshotted original appearance
local function scResetModel(model)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then scRestorePartState(part) end
    end
end

-- Determine and apply the correct skin for a single weapon model child
local function scApplySkinToChild(child)
    local lt = child:GetAttribute("loadout_type")
    if lt ~= "primary" and lt ~= "secondary" then return end
    local wname   = child.Name
    local perSkin = Settings.PerWeaponSkins[wname]
    if perSkin == "Default" then
        scResetModel(child)
    elseif perSkin and perSkin ~= "-" then
        local def = _scFindDef(perSkin)
        if def then scApplySkinToModel(child, _scResolveMod(def, wname)) end
    else
        local globalSkin = (lt == "primary") and Settings.GlobalPrimSkin or Settings.GlobalSecSkin
        if globalSkin == "Default" then
            scResetModel(child)
        elseif globalSkin and globalSkin ~= "-" then
            local def = _scFindDef(globalSkin)
            if def then scApplySkinToModel(child, _scResolveMod(def, wname)) end
        end
    end
end

-- forward declared so scSnapshotWeaponModel can reference it before definition
local scApplyAllSkins

-- Batches rapid ChildAdded events into a single delayed scApplyAllSkins call.
local _applyScheduled = false
local function scheduleApply()
    if _applyScheduled then return end
    _applyScheduled = true
    task.delay(0.35, function()
        _applyScheduled = false
        if scApplyAllSkins then pcall(scApplyAllSkins) end
    end)
end

local function scSnapshotWeaponModel(model)
    -- 0.25s: enough time for loadout_type attribute and part streaming to settle.
    -- snapshot only if loadout_type is ready; scheduleApply fires unconditionally.
    task.delay(0.25, function()
        if not model or not model.Parent then return end
        local lt = model:GetAttribute("loadout_type")
        if lt == "primary" or lt == "secondary" then
            for _, part in ipairs(model:GetDescendants()) do
                if part:IsA("BasePart") then scSavePartState(part) end
            end
        end
        scheduleApply()
    end)
end

-- Re-connects ChildAdded on a (possibly freshly created) LocalViewmodel instance.
-- Called on initial load AND whenever the game re-creates LocalViewmodel (e.g. after loadout menu).
local function scConnectLvm(lvm)
    for _, child in ipairs(lvm:GetChildren()) do scSnapshotWeaponModel(child) end
    track(lvm.ChildAdded:Connect(function(child)
        if child:IsA("Model") then scSnapshotWeaponModel(child) end
    end))
end

pcall(function()
    local vms = workspace:FindFirstChild("Viewmodels")
    if not vms then return end
    local lvm = vms:FindFirstChild("LocalViewmodel")
    if lvm then scConnectLvm(lvm) end
    -- Watch for LocalViewmodel being re-created (happens when leaving/returning from loadout menu)
    track(vms.ChildAdded:Connect(function(child)
        if child.Name == "LocalViewmodel" then scConnectLvm(child) end
    end))
end)
pcall(function()
    local items = game.Players.LocalPlayer:FindFirstChild("Items")
    if items then
        for _, child in ipairs(items:GetChildren()) do scSnapshotWeaponModel(child) end
        track(items.ChildAdded:Connect(function(child) scSnapshotWeaponModel(child) end))
    end
end)

-- Re-apply all saved skin choices to currently loaded weapon models.
-- Per-weapon setting overrides global; "Default" restores original; "-" = no override.
-- Applies to both the viewmodel (equipped weapon) and LocalPlayer.Items (unequipped).
scApplyAllSkins = function()
    pcall(function()
        local lvm = workspace.Viewmodels.LocalViewmodel
        for _, child in ipairs(lvm:GetChildren()) do scApplySkinToChild(child) end
    end)
    pcall(function()
        local items = game.Players.LocalPlayer:FindFirstChild("Items")
        if items then
            for _, child in ipairs(items:GetChildren()) do scApplySkinToChild(child) end
        end
    end)
end

-- re-apply after config load
Bindings[#Bindings+1] = function() scApplyAllSkins() end

-- ---- LEFT: Weapon Skin ----

SkinLeft:AddSection("Global")

local _globalSkinOpts = {"Default", "-"}
for _, v in ipairs(_skinOptsAll) do table.insert(_globalSkinOpts, v) end

local wGlobPrimDrop = SkinLeft:AddDropdown({
    Text    = "Primary",
    Options = _globalSkinOpts,
    Default = "-",
    Callback = function(v)
        Settings.GlobalPrimSkin = v
        scApplyAllSkins()
    end,
})
Bindings[#Bindings+1] = function()
    pcall(function() wGlobPrimDrop:Set(Settings.GlobalPrimSkin or "-") end)
end

local wGlobSecDrop = SkinLeft:AddDropdown({
    Text    = "Secondary",
    Options = _globalSkinOpts,
    Default = "-",
    Callback = function(v)
        Settings.GlobalSecSkin = v
        scApplyAllSkins()
    end,
})
Bindings[#Bindings+1] = function()
    pcall(function() wGlobSecDrop:Set(Settings.GlobalSecSkin or "-") end)
end

SkinLeft:AddButton({ Text = "Remove all skins", Callback = function()
    for part in pairs(_origPartState) do scRestorePartState(part) end
end })

SkinLeft:AddSection("Per Weapon")

local _perWeaponDef = WEAPON_DB[1]

local wPerSkinDrop  -- forward declared so weapon callback can reach it

local wWeaponDrop = SkinLeft:AddDropdown({
    Text    = "Weapon",
    Options = _weaponOpts,
    Default = _weaponOpts[1],
    Callback = function(v)
        _perWeaponDef = _weaponByOpt[v]
        if _perWeaponDef then
            local opts = _scPerWeaponOpts(_perWeaponDef.name)
            pcall(function() wPerSkinDrop:SetOptions(opts) end)
            local saved = Settings.PerWeaponSkins[_perWeaponDef.name] or "-"
            pcall(function() wPerSkinDrop:Set(saved) end)
        end
    end,
})

wPerSkinDrop = SkinLeft:AddDropdown({
    Text    = "Skin",
    Options = _scPerWeaponOpts(WEAPON_DB[1].name),
    Default = Settings.PerWeaponSkins[WEAPON_DB[1].name] or "-",
    Callback = function(v)
        if _perWeaponDef then
            Settings.PerWeaponSkins[_perWeaponDef.name] = v
            scApplyAllSkins()
        end
    end,
})

Bindings[#Bindings+1] = function()
    if _perWeaponDef then
        local saved = Settings.PerWeaponSkins[_perWeaponDef.name] or "-"
        pcall(function() wPerSkinDrop:Set(saved) end)
    end
end

-- ---- RIGHT: Character ----
SkinRight:AddSection("Outfit")

local wOutfitDrop = SkinRight:AddDropdown({
    Text    = "Select Outfit",
    Options = outfitOptions,
    Callback = function(v) Settings.SelectedOutfit = v end,
})
Bindings[#Bindings+1] = function()
    if Settings.SelectedOutfit then pcall(function() wOutfitDrop:Set(Settings.SelectedOutfit) end) end
end

SkinRight:AddButton({
    Text = "Apply outfit",
    Callback = function()
        local itemName = outfitLabelToName[Settings.SelectedOutfit]
        if not itemName then return end
        scApplyAll("outfit", itemName)
    end,
})

SkinRight:AddButton({
    Text = "Remove outfit",
    Callback = function()
        scApplyAll("outfit", nil)
    end,
})

SkinRight:AddSection("Hat")

local wHatDrop = SkinRight:AddDropdown({
    Text    = "Select Hat",
    Options = hatOptions,
    Callback = function(v) Settings.SelectedHat = v end,
})
Bindings[#Bindings+1] = function()
    if Settings.SelectedHat then pcall(function() wHatDrop:Set(Settings.SelectedHat) end) end
end

SkinRight:AddButton({
    Text = "Apply hat",
    Callback = function()
        local itemName = hatLabelToName[Settings.SelectedHat]
        if not itemName then return end
        scApplyAll("hat", itemName)
    end,
})

SkinRight:AddButton({
    Text = "Remove hat",
    Callback = function()
        scApplyAll("hat", nil)
    end,
})

SkinRight:AddSection("Charm")

local wCharmDrop = SkinRight:AddDropdown({
    Text    = "Select Charm",
    Options = charmOptions,
    Callback = function(v) Settings.SelectedCharm = v end,
})
Bindings[#Bindings+1] = function()
    if Settings.SelectedCharm then pcall(function() wCharmDrop:Set(Settings.SelectedCharm) end) end
end

SkinRight:AddButton({
    Text = "Apply charm",
    Callback = function()
        local itemName = charmLabelToName[Settings.SelectedCharm]
        if not itemName then return end
        scApplyAll("charm", itemName)
    end,
})

SkinRight:AddButton({
    Text = "Remove charm",
    Callback = function()
        scApplyAll("charm", nil)
    end,
})
end -- SKINS TAB

-- =====================
--     CONFIG TAB
-- =====================
local ConfigLeft  = ConfigTab:CreateGroup({ Name = "Saved Configs", Side = "Left" })
local ConfigRight = ConfigTab:CreateGroup({ Name = "Manage",        Side = "Right" })

local selectedCfg = nil
local cfgNameInput  -- forward declared, assigned below
local autoloadLbl   -- forward declared, assigned below

local cfgListBox = ConfigLeft:AddListBox({ Height = 160 })

cfgListBox.OnSelect = function(name)
    selectedCfg = name
    if cfgNameInput then cfgNameInput:Set(name) end
end

local function refreshCfgList()
    cfgListBox:SetItems(listConfigs())
    local al = getAutoload()
    if autoloadLbl then
        autoloadLbl:SetText("Autoload: " .. (al or "none"))
    end
    if al then cfgListBox:SetSelected(al) end
end

ConfigLeft:AddSection("Theme")
local wAccentColor = ConfigLeft:AddColorPicker({
    Text     = "Accent Color",
    Default  = MyTheme.Accent,
    Callback = function(c)
        Settings.AccentColor = c
        Window:SetAccent(c)
    end,
})
Bindings[#Bindings+1] = function()
    if Settings.AccentColor then wAccentColor:Set(Settings.AccentColor) end
end

ConfigRight:AddSection("Config")

cfgNameInput = ConfigRight:AddInput({
    Text        = "Name",
    Placeholder = "config name…",
})

-- Save: overwrites/creates config with the name in the input field
ConfigRight:AddButton({
    Text = "Save",
    Callback = function()
        local name = cfgNameInput:Get():gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then return end
        saveConfig(name)
        refreshCfgList()
        cfgListBox:SetSelected(name)
    end,
})

-- Load: loads the config selected in the list
ConfigRight:AddButton({
    Text = "Load",
    Callback = function()
        local name = selectedCfg
        if not name or name == "" then return end
        if loadConfig(name) then
            applyBindings()
            Lib:Notify({ Title = "Config", Text = "Loaded: " .. name, Duration = 3 })
        end
    end,
})

-- Save As: same as Save but communicates intent to save under a new name
ConfigRight:AddButton({
    Text = "Save As",
    Callback = function()
        local name = cfgNameInput:Get():gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then return end
        saveConfig(name)
        selectedCfg = name
        refreshCfgList()
        cfgListBox:SetSelected(name)
        Lib:Notify({ Title = "Config", Text = "Saved as: " .. name, Duration = 3 })
    end,
})

ConfigRight:AddSection("Autoload")

autoloadLbl = ConfigRight:AddLabel("Autoload: none")

ConfigRight:AddButton({
    Text = "Set Autoload",
    Callback = function()
        local name = selectedCfg or cfgNameInput:Get():gsub("^%s+", ""):gsub("%s+$", "")
        if not name or name == "" then return end
        setAutoload(name)
        refreshCfgList()
        Lib:Notify({ Title = "Config", Text = "Autoload: " .. name, Duration = 3 })
    end,
})

ConfigRight:AddButton({
    Text = "Clear Autoload",
    Callback = function()
        setAutoload(nil)
        refreshCfgList()
    end,
})

ConfigRight:AddSection("Script")
ConfigRight:AddLabel("Operation One  v1.0")

local unloadScript

ConfigRight:AddButton({
    Text = "Unload Script",
    Callback = function()
        if unloadScript then unloadScript() end
    end,
})

refreshCfgList()

-- =====================
--       GUN HOOKS
-- Shoot remote (Cobalt intercept):
--   game:GetService("ReplicatedStorage").Objects:GetChildren()[N]
--   :FireServer("shoot", CFrame, {{Normal,Instance,Position},...})
--   → identified by argument signature (index N can shift between updates)
--   → uses hookmetamethod (Velocity/Synapse API, no setreadonly needed)
-- =====================
local hookActive  = false   -- set false to passthrough without restoring metamethod
local _hookOld    = nil
local preShotLook = nil
local shotTick    = 0
local _noSpreadParams = RaycastParams.new()
_noSpreadParams.FilterType = Enum.RaycastFilterType.Exclude

local menuOpen    = false
local MENU_SINK   = "OpOneMenuSink"
local MENU_CURSOR = "OpOneMenuCursor"

-- Keys/buttons to swallow while menu is open
local SINK_INPUTS = {
    Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
    Enum.KeyCode.Space, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift,
    Enum.KeyCode.R, Enum.KeyCode.E, Enum.KeyCode.Q, Enum.KeyCode.F,
    Enum.KeyCode.G, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.Z,
    Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three,
    Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six,
    Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2,
    Enum.UserInputType.MouseButton3,
}

local _savedMouseBehavior    = nil
local _savedMouseIconEnabled = nil

local function applyMenuState(open)
    menuOpen = open
    if open then
        -- Zustand des Spiels vor dem Öffnen speichern
        pcall(function()
            _savedMouseBehavior    = UserInputService.MouseBehavior
            _savedMouseIconEnabled = UserInputService.MouseIconEnabled
        end)
        -- run after camera script (Last=2000) so we win the fight every frame
        RunService:BindToRenderStep(MENU_CURSOR, 2001, function()
            pcall(function()
                UserInputService.MouseBehavior    = Enum.MouseBehavior.Default
                UserInputService.MouseIconEnabled = true
            end)
        end)
        -- sink keyboard + mouse button events before game handlers see them
        pcall(function()
            ContextActionService:BindAction(MENU_SINK, function()
                return Enum.ContextActionResult.Sink
            end, false, table.unpack(SINK_INPUTS))
        end)
    else
        RunService:UnbindFromRenderStep(MENU_CURSOR)
        pcall(function() ContextActionService:UnbindAction(MENU_SINK) end)
        -- Gespeicherten Zustand wiederherstellen statt LockCenter zu erzwingen
        pcall(function()
            if _savedMouseBehavior    ~= nil then UserInputService.MouseBehavior    = _savedMouseBehavior    end
            if _savedMouseIconEnabled ~= nil then UserInputService.MouseIconEnabled = _savedMouseIconEnabled end
        end)
        _savedMouseBehavior    = nil
        _savedMouseIconEnabled = nil
    end
end

track(UserInputService.InputBegan:Connect(function(i)
    if i.KeyCode == Enum.KeyCode.Delete then
        -- read actual GsLib state one frame later so it has already toggled
        task.defer(function()
            applyMenuState(Window.Visible == true)
        end)
    end
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        preShotLook = workspace.CurrentCamera.CFrame.LookVector
        shotTick    = tick()
    end
end))

-- also sync on load (window may start visible)
task.defer(function()
    applyMenuState(Window.Visible == true)
end)

do
    local ok, old = pcall(hookmetamethod, game, "__namecall", function(...)
        if not hookActive then
            return _hookOld(...)
        end
        local method = getnamecallmethod()
        -- block game inputs while menu is open
        if menuOpen then
            if method == "GetMouseDelta" then return Vector2.zero end
            if method == "IsKeyDown" or method == "IsMouseButtonPressed" then return false end
            if method == "GetMouseButtonsPressed" or method == "GetKeysPressed" then return {} end
        end
        if method == "FireServer" then
            local args = table.pack(...)
            -- args[1]=self  args[2]="shoot"  args[3]=CFrame  args[4]=hits
            if type(args[2]) == "string" and args[2] == "shoot"
               and typeof(args[3]) == "CFrame" and type(args[4]) == "table" then
                if menuOpen then return end  -- swallow shoot while menu open
                if Settings.GunNoSpread then
                    local cleanCF = workspace.CurrentCamera.CFrame
                    _noSpreadParams.FilterDescendantsInstances = {LocalPlayer.Character}
                    local hit  = workspace:Raycast(cleanCF.Position, cleanCF.LookVector * 2000, _noSpreadParams)
                    args[3]    = cleanCF
                    -- Build per-pellet hit table: preserve original pellet count for shotguns
                    local pellets = (type(args[4]) == "table" and #args[4] > 0) and #args[4] or 1
                    local hitRow  = hit and {{ Normal = hit.Normal, Instance = hit.Instance, Position = hit.Position }} or {}
                    local newHits = table.create(pellets)
                    for i = 1, pellets do newHits[i] = hitRow end
                    args[4] = newHits
                end
                return _hookOld(table.unpack(args, 1, args.n))
            end
        end
        return _hookOld(...)
    end)
    if ok then _hookOld = old; hookActive = true end
end

-- Camera lock runs at Camera+1 so it overrides the char module's recoil offsets.
-- Window: 450ms covers kick + recovery for all weapons (M590 worst-case ~600ms but
-- the recovery is minor past 450ms).  If the player moves the mouse we update the
-- reference look-vector so intentional aiming is never blocked.
RunService:BindToRenderStep("GsNoRecoil", Enum.RenderPriority.Camera.Value + 1, function()
    if not (Settings.GunNoRecoil and preShotLook) then return end
    if (tick() - shotTick) >= 0.45 then preShotLook = nil; return end
    -- If the player is actively moving the mouse, slide the reference forward so
    -- recoil suppression follows their aim (mouse input takes priority).
    if UserInputService:GetMouseDelta().Magnitude > 2 then
        preShotLook = workspace.CurrentCamera.CFrame.LookVector
        return
    end
    local cam = workspace.CurrentCamera
    cam.CFrame = CFrame.lookAt(cam.CFrame.Position, cam.CFrame.Position + preShotLook)
end)

-- =====================
--   ANTI-EFFECTS SYSTEM
-- Hook GetPropertyChangedSignal once so any game LocalScript that watches
-- Size/Transparency/etc. on our hidden parts receives a dead BindableEvent
-- instead of the real signal → never detects our overrides.
-- =====================
do
    local _origGPCS
    local hookOk = pcall(function()
        _origGPCS = hookfunction(
            game.GetPropertyChangedSignal,
            newcclosure(function(self, property)
                if hiddenParts[self] and (
                    property == "Size" or
                    property == "Transparency" or
                    property == "LocalTransparencyModifier" or
                    property == "Color"
                ) then
                    return Instance.new("BindableEvent").Event
                end
                return _origGPCS(self, property)
            end)
        )
    end)
    -- If hookfunction failed (shouldn't on Madium 98%), fall back silently
    if not hookOk then _origGPCS = nil end
end

local function hideVisually(part)
    if hiddenParts[part] then return end
    hiddenParts[part] = true
    pcall(function()
        part.LocalTransparencyModifier = 1
        part.Size = tinySize
    end)
end

local function processSmokePart(obj)
    if handledSmoke[obj] then return end
    handledSmoke[obj] = true
    pcall(function()
        if obj:IsA("BasePart") then
            hideVisually(obj)
        end
        for _, item in ipairs(obj:GetDescendants()) do
            if item:IsA("BasePart") then
                hideVisually(item)
            elseif item:IsA("ParticleEmitter") or item:IsA("Smoke") or item:IsA("Fire") then
                item.Enabled = false
            end
        end
    end)
end

-- scan what's already in workspace
for _, child in ipairs(workspace:GetChildren()) do
    if child.Name == "SmokePart" and Settings.AntiSmoke then
        processSmokePart(child)
    end
end

-- watch new objects entering workspace
track(workspace.ChildAdded:Connect(function(child)
    if child.Name == "SmokePart" and Settings.AntiSmoke then
        processSmokePart(child)
    end
end))

-- resolve Flash GUI reference (non-blocking); disable immediately if toggle already on
task.spawn(function()
    local ok, gui = pcall(function()
        return LocalPlayer.PlayerGui:WaitForChild("Flash", 10)
    end)
    if ok and gui then
        flashGui = gui
        if Settings.AntiFlash then
            pcall(function() flashGui.Enabled = false end)
        end
    end
end)

-- =====================
--    ESP DRAWING
-- =====================
local function newText(size, centered)
    local t = newDrawing("Text")
    t.Visible = false
    t.Size    = size or 13
    t.Center  = centered ~= false
    t.Outline = true
    return t
end

local function createESP(player)
    local o = {}
    -- 3-D highlight rendered by Roblox engine (through walls via AlwaysOnTop)
    o.Highlight = nil
    pcall(function()
        local h = Instance.new("Highlight")
        h.FillTransparency    = 0.5
        h.OutlineTransparency = 0
        pcall(function() h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop end)
        h.Enabled  = false
        h.Parent   = workspace
        o.Highlight = h
    end)
    o.HeadCircle = newDrawing("Circle")
    o.Box      = newDrawing("Square")
    o.Name     = newText(14, true)
    o.HealthBG = newDrawing("Square")
    o.Health   = newDrawing("Square")
    o.Tracer   = newDrawing("Line")
    o.Distance = newText(12, true)
    o.Ping     = newText(12, true)
    o.Combat   = newText(12, false)

    o.HeadCircle.Visible = false; o.HeadCircle.Filled = false; o.HeadCircle.Thickness = 1; o.HeadCircle.NumSides = 32
    o.Box.Visible = false; o.Box.Filled = false; o.Box.Thickness = 1
    o.Health.Visible = false; o.Health.Filled = true
    o.Health.Color = Color3.fromRGB(0, 255, 0)
    o.HealthBG.Visible = false; o.HealthBG.Filled = true
    o.HealthBG.Color = Color3.fromRGB(0, 0, 0); o.HealthBG.Transparency = 0.5
    o.Tracer.Visible = false; o.Tracer.Thickness = 1

    o.Flag = nil
    pcall(function()
        o.Flag = newDrawing("Image")
        o.Flag.Visible = false
    end)

    o.Bones     = {}
    o.BonesChar = nil
    o.BonesVM   = nil
    for i = 1, MAX_BONES do
        local l = newDrawing("Line")
        l.Visible = false; l.Thickness = 1
        o.Bones[i] = { A = nil, B = nil, Line = l }
    end

    ESPObjects[player] = o
end

local function removeESP(player)
    if ESPObjects[player] then
        local o = ESPObjects[player]
        if o.Highlight then pcall(function() o.Highlight:Destroy() end) end
        for _, k in ipairs({"HeadCircle","Box","Name","HealthBG","Health","Tracer","Distance","Ping","Combat"}) do
            if o[k] then pcall(function() o[k]:Remove() end) end
        end
        if o.Flag then pcall(function() o.Flag:Remove() end) end
        if o.Bones then
            for _, b in ipairs(o.Bones) do pcall(function() b.Line:Remove() end) end
        end
        ESPObjects[player] = nil
    end
end

for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then createESP(p) end
end
track(Players.PlayerAdded:Connect(createESP))
track(Players.PlayerRemoving:Connect(removeESP))

local function hideAll(o)
    if o.Highlight then pcall(function() o.Highlight.Enabled = false end) end
    o.HeadCircle.Visible = false
    o.Box.Visible = false; o.Name.Visible = false
    o.Health.Visible = false; o.HealthBG.Visible = false
    o.Tracer.Visible = false; o.Distance.Visible = false
    o.Ping.Visible = false; o.Combat.Visible = false
    if o.Flag then o.Flag.Visible = false end
    for _, b in ipairs(o.Bones) do b.Line.Visible = false end
end

local function findViewmodelNear(pos)
    local vms = workspace:FindFirstChild("Viewmodels")
    if not vms then return nil end
    local camPos = Camera.CFrame.Position
    local best, bestDist = nil, math.huge
    for _, vm in ipairs(vms:GetChildren()) do
        if not vm:IsA("Model") then continue end
        -- BBox-Mitte ist zuverlässiger als erster BasePart (Gewehrlauf kann weit rausragen)
        local center
        local ok, cf = pcall(function() return vm:GetBoundingBox() end)
        if ok and cf then
            center = cf.Position
        else
            local ref = vm:FindFirstChildWhichIsA("BasePart", true)
            if not ref then continue end
            center = ref.Position
        end
        -- FPS-Waffenviewmodel: BBox-Mitte immer < 1 Stud von Kamera
        -- Feind-Viewmodel: immer mind. 3+ Studs entfernt
        if (center - camPos).Magnitude < 3 then continue end
        local d = (center - pos).Magnitude
        if d < bestDist then bestDist = d; best = vm end
    end
    return best
end

-- Gibt die geometrische Mitte des Kopfes im Viewmodel zurück.
-- Bevorzugt direktes Kind "head": Model → GetBoundingBox, Part → Position.
-- Funktioniert korrekt beim Leanen, da das Part selbst sich mit der Animation bewegt.
local function getVMHeadCenter(vm)
    if not vm then return nil end
    local obj = vm:FindFirstChild("head")
    if obj then
        if obj:IsA("Model") then
            local ok, cf = pcall(function() return obj:GetBoundingBox() end)
            if ok and cf then return cf.Position end
        elseif obj:IsA("BasePart") then
            return obj.Position
        end
    end
    -- Fallback: rekursive Suche; Sub-Part in Parent-Model → Parent-BBox-Mitte
    local sub = vm:FindFirstChild("head", true)
    if sub and sub:IsA("BasePart") then
        local par = sub.Parent
        if par and par:IsA("Model") and par ~= vm then
            local ok, cf = pcall(function() return par:GetBoundingBox() end)
            if ok and cf then return cf.Position end
        end
        return sub.Position
    end
    return nil
end

local function drawSkeleton(o, vm, col, trans)
    if o.BonesVM ~= vm then
        o.BonesVM = vm
        for i = 1, MAX_BONES do
            local pair = CUSTOM_BONES[i]
            if vm then
                o.Bones[i].A = vm:FindFirstChild(pair[1], true)
                o.Bones[i].B = vm:FindFirstChild(pair[2], true)
            else
                o.Bones[i].A = nil; o.Bones[i].B = nil
            end
        end
    end

    for i = 1, MAX_BONES do
        local b = o.Bones[i]
        if b.A and b.B then
            local ok, sp1, on1 = pcall(Camera.WorldToViewportPoint, Camera, b.A.Position)
            if not ok then b.A = nil; b.Line.Visible = false; continue end
            local sp2, on2 = Camera:WorldToViewportPoint(b.B.Position)
            if on1 and on2 then
                b.Line.From         = Vector2.new(sp1.X, sp1.Y)
                b.Line.To           = Vector2.new(sp2.X, sp2.Y)
                b.Line.Color        = col
                b.Line.Transparency = trans or 0
                b.Line.Visible      = true
            else
                b.Line.Visible = false
            end
        else
            b.Line.Visible = false
        end
    end
end

track(RunService.RenderStepped:Connect(function()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local o = ESPObjects[player]
            if o then
                pcall(function()
                    if not Settings.ESPEnabled then hideAll(o); return end
                    local now = tick()
                    -- cache character model every 0.2s; invalidate if model was removed
                    if not o._charTime or (now - o._charTime) > 0.2
                       or (o._charCached and not o._charCached.Parent) then
                        o._charTime   = now
                        o._charCached = findPlayerModel(player)
                    end
                    local char    = o._charCached
                    local hum     = char and char:FindFirstChildOfClass("Humanoid")
                    local refPart = char and (
                        char:FindFirstChild("collision", true) or
                        char:FindFirstChild("HumanoidRootPart") or
                        char:FindFirstChildWhichIsA("BasePart", true)
                    )
                    local hrp = char and (
                        char:FindFirstChild("HumanoidRootPart") or refPart
                    )
                    local teamSame = Settings.ESPTeamCheck
                                     and LocalPlayer.Team ~= nil and player.Team ~= nil
                                     and player.Team == LocalPlayer.Team
                    local alive    = not hum or hum.Health > 0
                    local valid    = char and refPart and alive and not teamSame

                    -- cache viewmodel per player (~2/s), used by both glow and skeleton
                    local vm = nil
                    if valid and hrp then
                        if not o._vmTime or (now - o._vmTime) > 0.4 then
                            o._vmTime   = now
                            o._vmCached = findViewmodelNear(hrp.Position)
                        end
                        vm = o._vmCached
                    end

                    if not valid then
                        hideAll(o)
                    else
                        local dist = (Camera.CFrame.Position - refPart.Position).Magnitude
                        local cx, bx, by, bw, bh, boxOk = calcBox(char)

                        local col   = getESPColor(player)
                        local alpha = Settings.ESPColorAlpha
                        local trans = alpha

                        -- tracer: always drawn (on-screen, off-screen, or behind camera)
                        do
                            local vp = Camera.ViewportSize
                            local tracerOriginY
                            if Settings.ESPTracerOrigin == "Top" then
                                tracerOriginY = 0
                            elseif Settings.ESPTracerOrigin == "Middle" then
                                tracerOriginY = vp.Y / 2
                            else
                                tracerOriginY = vp.Y
                            end
                            local ox = vp.X / 2
                            local oy = tracerOriginY

                            if Settings.ESPTracers and dist <= Settings.ESPMaxDistance then
                                local sp = Camera:WorldToViewportPoint(refPart.Position)
                                local tx, ty = sp.X, sp.Y

                                if sp.Z <= 0 then
                                    -- behind camera: reflect around screen center and push far out
                                    local scx, scy = vp.X / 2, vp.Y / 2
                                    local ddx = (vp.X - sp.X) - scx
                                    local ddy = (vp.Y - sp.Y) - scy
                                    local dlen = math.sqrt(ddx*ddx + ddy*ddy)
                                    if dlen < 0.001 then
                                        tx, ty = scx, scy - 99999
                                    else
                                        local s = 99999 / dlen
                                        tx, ty = scx + ddx * s, scy + ddy * s
                                    end
                                end

                                -- clamp endpoint to screen edge (origin is always on screen)
                                local dx, dy = tx - ox, ty - oy
                                if math.abs(dx) > 0.001 or math.abs(dy) > 0.001 then
                                    local tMax = 1
                                    if     dx >  0.001 then tMax = math.min(tMax, (vp.X - ox) / dx)
                                    elseif dx < -0.001 then tMax = math.min(tMax, (0    - ox) / dx) end
                                    if     dy >  0.001 then tMax = math.min(tMax, (vp.Y - oy) / dy)
                                    elseif dy < -0.001 then tMax = math.min(tMax, (0    - oy) / dy) end
                                    tMax = math.max(0, math.min(1, tMax))
                                    tx = ox + dx * tMax
                                    ty = oy + dy * tMax
                                end

                                o.Tracer.From         = Vector2.new(ox, oy)
                                o.Tracer.To           = Vector2.new(tx, ty)
                                o.Tracer.Color        = col
                                o.Tracer.Transparency = trans
                                o.Tracer.Visible      = true
                            else
                                o.Tracer.Visible = false
                            end
                        end

                        -- 3-D highlight: Hitbox = outline only, Filling = fill
                        if o.Highlight then
                            pcall(function()
                                local needHL = (Settings.ESPHitbox or Settings.ESPFilling) and dist <= Settings.ESPMaxDistance and vm
                                if needHL then
                                    o.Highlight.Adornee             = vm
                                    o.Highlight.OutlineColor        = col
                                    o.Highlight.FillColor           = col
                                    o.Highlight.OutlineTransparency = Settings.ESPHitbox  and 0   or 1
                                    o.Highlight.FillTransparency    = Settings.ESPFilling and 0.5 or 1
                                    o.Highlight.Enabled             = true
                                else
                                    o.Highlight.Enabled = false
                                end
                            end)
                        end

                        -- head circle: geometrische Kopfmitte aus dem Viewmodel
                        do
                            local headPos = vm and getVMHeadCenter(vm)
                            local hpSP = headPos and Camera:WorldToViewportPoint(headPos)
                            if Settings.ESPHeadCircle and headPos and hpSP and hpSP.Z > 0
                               and dist <= Settings.ESPMaxDistance then
                                local fovTan = math.tan(math.rad(Camera.FieldOfView) / 2)
                                local pps    = Camera.ViewportSize.Y / (2 * hpSP.Z * fovTan)
                                o.HeadCircle.Position     = Vector2.new(hpSP.X, hpSP.Y)
                                o.HeadCircle.Radius       = math.max(2, 0.38 * pps)
                                o.HeadCircle.Color        = col
                                o.HeadCircle.Transparency = trans
                                o.HeadCircle.Visible      = true
                            else
                                o.HeadCircle.Visible = false
                            end
                        end

                        -- skeleton is independent of box coordinates
                        if Settings.ESPSkeleton then
                            drawSkeleton(o, vm, col, trans)
                        else
                            for _, b in ipairs(o.Bones) do b.Line.Visible = false end
                        end

                        if dist > Settings.ESPMaxDistance or not boxOk then
                            o.Box.Visible = false; o.Name.Visible = false
                            o.Health.Visible = false; o.HealthBG.Visible = false
                            o.Distance.Visible = false; o.Ping.Visible = false
                            o.Combat.Visible = false
                            if o.Flag then o.Flag.Visible = false end
                        else
                            o.Box.Visible      = Settings.ESPBoxes
                            o.Box.Position     = Vector2.new(bx, by)
                            o.Box.Size         = Vector2.new(bw, bh)
                            o.Box.Color        = col
                            o.Box.Thickness    = 1
                            o.Box.Transparency = trans

                            o.Name.Visible      = Settings.ESPNames
                            o.Name.Text         = player.Name
                            o.Name.Position     = Vector2.new(cx, by - 16)
                            o.Name.Color        = col
                            o.Name.Transparency = 1

                            local code = player:GetAttribute("CountryCode")
                            if Settings.ESPShowRegion and o.Flag
                               and type(code) == "string" and #code == 2 then
                                requestFlag(code)
                                local data = FlagCache[code:lower()]
                                if data and data ~= false then
                                    pcall(function()
                                        o.Flag.Data     = data
                                        o.Flag.Size     = Vector2.new(20, 13)
                                        o.Flag.Position = Vector2.new(cx - 10, by - 32)
                                        o.Flag.Visible  = true
                                    end)
                                else
                                    o.Flag.Visible = false
                                end
                            elseif o.Flag then
                                o.Flag.Visible = false
                            end

                            local showHealth = Settings.ESPHealthBar and hum ~= nil
                            local hp = hum and (hum.Health / math.max(hum.MaxHealth, 1)) or 1
                            o.HealthBG.Visible       = showHealth
                            o.HealthBG.Position      = Vector2.new(bx - 6, by)
                            o.HealthBG.Size          = Vector2.new(4, bh)
                            o.HealthBG.Transparency  = trans
                            o.Health.Visible         = showHealth
                            o.Health.Position        = Vector2.new(bx - 6, by + bh * (1 - hp))
                            o.Health.Size            = Vector2.new(4, bh * hp)
                            o.Health.Transparency    = trans
                            o.Health.Color           = Color3.fromRGB(
                                math.floor((1 - hp) * 255),
                                math.floor(hp * 255),
                                0
                            )

                            local belowY = by + bh + 2
                            o.Distance.Visible       = Settings.ESPDistance
                            o.Distance.Text          = string.format("%.0fm", dist)
                            o.Distance.Position      = Vector2.new(cx, belowY)
                            o.Distance.Color         = col
                            o.Distance.Transparency  = 1
                            if Settings.ESPDistance then belowY = belowY + 14 end

                            local pingMs = player:GetAttribute("Ping")
                            o.Ping.Visible       = Settings.ESPShowPing
                            o.Ping.Text          = pingMs and (tostring(pingMs) .. " ms") or "? ms"
                            o.Ping.Position      = Vector2.new(cx, belowY)
                            o.Ping.Color         = col
                            o.Ping.Transparency  = 1

                            local anyStats   = Settings.ESPCombatEnabled and (
                                           Settings.ESPShowKills or Settings.ESPShowDeaths
                                           or Settings.ESPShowAssists or Settings.ESPShowKD)
                            local combatText = anyStats and buildCombatText(player) or ""
                            o.Combat.Visible       = anyStats and combatText ~= ""
                            o.Combat.Text          = combatText
                            o.Combat.Position      = Vector2.new(bx + bw + 4, by)
                            o.Combat.Color         = col
                            o.Combat.Transparency  = 1

                        end
                    end
                end)
            end
        end
    end

end))

-- =====================
--    GADGET ESP DRAWING
-- =====================
local GadgetDrawings   = {}   -- [i] = Drawing Text
local GadgetHighlights = {}   -- [obj] = Highlight Instance

local GrenadeTrailLines = {}  -- [i] = Drawing Line (pool)
local GrenadeTrailData  = {}  -- [obj] = {points = {{pos, t}, ...}}
local TRAIL_DURATION    = 3   -- seconds trail stays visible

local function getTrailLine(i)
    if not GrenadeTrailLines[i] then
        local l = newDrawing("Line")
        l.Thickness = 2; l.Visible = false
        GrenadeTrailLines[i] = l
    end
    return GrenadeTrailLines[i]
end

-- smokeSampleFn declared earlier (before Misc tab) so the button closure captures it

local function getGadgetDrawing(i)
    if not GadgetDrawings[i] then
        local t = newDrawing("Text")
        t.Size = 13; t.Center = true; t.Outline = true; t.Visible = false
        GadgetDrawings[i] = t
    end
    return GadgetDrawings[i]
end

-- per-highlight color cache so we only write properties that changed
local GadgetHighlightCache = {}   -- [h] = { col, fillTransp }

local function getGadgetHighlight(obj, col, outlineT, fillT)
    if not GadgetHighlights[obj] then
        local h
        pcall(function()
            h = Instance.new("Highlight")
            h.FillTransparency    = fillT or 1
            h.OutlineTransparency = outlineT or 1
            pcall(function() h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop end)
            h.Adornee = obj
            h.Parent  = workspace
        end)
        if h then GadgetHighlights[obj] = h end
    end
    local h = GadgetHighlights[obj]
    if not h then return end
    local cache = GadgetHighlightCache[h]
    if not cache then cache = {}; GadgetHighlightCache[h] = cache end
    if cache.col ~= col then
        h.OutlineColor = col; h.FillColor = col; cache.col = col
    end
    if cache.ot ~= outlineT then
        h.OutlineTransparency = outlineT; cache.ot = outlineT
    end
    if cache.ft ~= fillT then
        h.FillTransparency = fillT; cache.ft = fillT
    end
    if not h.Enabled then h.Enabled = true end
end

local gadgetList  = {}
local gadgetTimer = 0

-- reused every frame (table.clear avoids per-frame allocation)
local glowEnabledThisFrame = {}

track(RunService.RenderStepped:Connect(function(dt)
    local gadgetActive = Settings.GadgetESPEnabled
    if not gadgetActive then
        for _, t in pairs(GadgetDrawings) do t.Visible = false end
        for _, h in pairs(GadgetHighlights) do pcall(function() h.Enabled = false end) end
    end

    if gadgetActive then
        -- rebuild gadget list every 0.5 s
        gadgetTimer = gadgetTimer + dt
        if gadgetTimer > 0.5 then
            gadgetTimer = 0
            gadgetList = {}
            pcall(function()
                for _, obj in ipairs(workspace:GetDescendants()) do
                    local label = GADGET_LABEL[obj.Name]
                    if label and Settings.GadgetShow[obj.Name] then
                        table.insert(gadgetList, { Obj = obj, Label = label })
                    end
                end
            end)
        end

        local globalCol = Settings.GadgetColor
        local globalAlp = Settings.GadgetColorAlpha
        local idx = 0
        table.clear(glowEnabledThisFrame)  -- reuse module-level table (no per-frame allocation)

        for _, entry in ipairs(gadgetList) do
            local obj = entry.Obj
            if not obj or not obj.Parent then continue end  -- skip destroyed objects

            local label   = entry.Label
            local perItem = Settings.GadgetPerItem[obj.Name] or {}
            local col     = Settings.GadgetItemColors[obj.Name]     or globalCol
            local alp     = Settings.GadgetItemColorAlpha[obj.Name] or globalAlp

            -- skip destroyed cameras
            if CAMERA_GADGETS[obj.Name] then
                local cam = obj:FindFirstChild("Cam", true)
                if cam and cam:GetAttribute("LocalTransparency") == 1 then continue end
            end

            local pos
            if obj:IsA("BasePart") then
                pos = obj.Position
            elseif obj:IsA("Model") then
                pos = (obj.PrimaryPart and obj.PrimaryPart.Position) or obj:GetPivot().Position
            end
            if not pos then continue end

            local dist = (Camera.CFrame.Position - pos).Magnitude
            if dist > Settings.GadgetMaxDistance then continue end

            -- 3-D highlight: per-gadget hitbox (outline) and filling (fill)
            local hasHL = perItem.hitbox or perItem.filling
            if hasHL then
                local outlineT = perItem.hitbox  and 0   or 1
                local fillT    = perItem.filling and 0.5 or 1
                getGadgetHighlight(obj, col, outlineT, fillT)
                glowEnabledThisFrame[obj] = true
            end

            -- 2-D text label
            local sp = Camera:WorldToViewportPoint(pos)
            if sp.Z <= 0 then continue end

            idx = idx + 1
            local t   = getGadgetDrawing(idx)
            local txt = label
            if Settings.GadgetShowDistance then
                txt = txt .. " [" .. string.format("%.0fm", dist) .. "]"
            end
            t.Text         = txt
            t.Position     = Vector2.new(sp.X, sp.Y - 14)
            t.Color        = col
            t.Transparency = alp
            t.Visible      = true
        end

        -- hide unused label slots
        for i = idx + 1, #GadgetDrawings do GadgetDrawings[i].Visible = false end

        -- disable highlights for gadgets that left range or have no hitbox/filling
        for obj, h in pairs(GadgetHighlights) do
            if not glowEnabledThisFrame[obj] and h.Enabled then
                h.Enabled = false
            end
        end
    end

    -- grenade trail: record positions every frame for active FragGrenades
    local trailIdx = 0
    local _grpItem = Settings.GadgetPerItem["FragGrenade"]
    if _grpItem and _grpItem.trail and Settings.GadgetShow["FragGrenade"] then
        local now = tick()
        local activeGrenades = {}
        pcall(function()
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj.Name == "FragGrenade" and Settings.GadgetShow["FragGrenade"] then
                    activeGrenades[obj] = true
                    local pos
                    if obj:IsA("BasePart") then pos = obj.Position
                    elseif obj:IsA("Model") then
                        pos = (obj.PrimaryPart and obj.PrimaryPart.Position) or obj:GetPivot().Position
                    end
                    if pos then
                        if not GrenadeTrailData[obj] then GrenadeTrailData[obj] = {points = {}} end
                        local pts = GrenadeTrailData[obj].points
                        if #pts == 0 or (pos - pts[#pts].pos).Magnitude > 0.05 then
                            table.insert(pts, {pos = pos, t = now})
                        end
                        while #pts > 0 and (now - pts[1].t) > TRAIL_DURATION do
                            table.remove(pts, 1)
                        end
                    end
                end
            end
        end)
        -- expire trail data for gone grenades
        for obj, data in pairs(GrenadeTrailData) do
            if not activeGrenades[obj] then
                local pts = data.points
                while #pts > 0 and (now - pts[1].t) > TRAIL_DURATION do
                    table.remove(pts, 1)
                end
                if #pts == 0 then GrenadeTrailData[obj] = nil end
            end
        end
        -- draw trail lines
        local tcol = Settings.GadgetItemColors["FragGrenade"]     or Settings.GadgetColor
        local talp = Settings.GadgetItemColorAlpha["FragGrenade"] or Settings.GadgetColorAlpha
        for _, data in pairs(GrenadeTrailData) do
            local pts = data.points
            for i = 1, #pts - 1 do
                pcall(function()
                    local p1, p2 = pts[i], pts[i+1]
                    local sp1 = Camera:WorldToViewportPoint(p1.pos)
                    local sp2 = Camera:WorldToViewportPoint(p2.pos)
                    if sp1.Z > 0 and sp2.Z > 0 then
                        local fade = math.max(0, 1 - (tick() - p1.t) / TRAIL_DURATION)
                        trailIdx = trailIdx + 1
                        local l = getTrailLine(trailIdx)
                        l.From         = Vector2.new(sp1.X, sp1.Y)
                        l.To           = Vector2.new(sp2.X, sp2.Y)
                        l.Color        = tcol
                        l.Transparency = fade * talp
                        l.Thickness    = 2
                        l.Visible      = true
                    end
                end)
            end
        end
    end
    for i = trailIdx + 1, #GrenadeTrailLines do GrenadeTrailLines[i].Visible = false end
end))

-- =====================
--   AIMBOT FOV CIRCLE
-- =====================
track(RunService.RenderStepped:Connect(function()
    if Settings.AimbotShowFOV then
        local vp     = Camera.ViewportSize
        local camFOV = Camera.FieldOfView
        local ratio  = math.tan(math.rad(Settings.AimbotFOV * 0.5)) / math.tan(math.rad(camFOV * 0.5))
        aimbotFOVCircle.Position = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
        aimbotFOVCircle.Radius   = ratio * (vp.Y * 0.5)
        aimbotFOVCircle.Visible  = true
    else
        aimbotFOVCircle.Visible = false
    end
end))

-- =====================
--   AIMBOT TARGETING
-- =====================
local AIMBOT_STEP = "GsAimbot"

-- Jeder Knochen sitzt am OBEREN Ende seines Segments (Gelenkpunkt).
-- Für Aimbot: Mittelpunkt des Segments = Mittelwert aus obem und unterem Knochen.
-- Skeleton head→torso = Kopfbereich; torso→hip = Rumpf usw.
local AIMBONE_MID = {
    ["Head"]       = {"head",      "torso"},
    ["Torso"]      = {"torso",     "hip1"},
    ["L Shoulder"] = {"shoulder1", "arm1"},
    ["R Shoulder"] = {"shoulder2", "arm2"},
    ["L Arm"]      = {"arm1",      nil},
    ["R Arm"]      = {"arm2",      nil},
    ["L Hip"]      = {"hip1",      "leg1"},
    ["R Hip"]      = {"hip2",      "leg2"},
    ["L Leg"]      = {"leg1",      nil},
    ["R Leg"]      = {"leg2",      nil},
}

-- Kopf: Viewmodel (lean-aware). Alle anderen Knochen: Character-BBox-Fraktionen.
-- Das Viewmodel enthält nur Waffenrig-Parts nahe der Feindkamera → alles
-- ausser dem Head-Part sitzt am Kopf, nicht am Körper.
local BONE_Y_FRAC = {
    ["Torso"]      = 0.55,
    ["L Shoulder"] = 0.72,
    ["R Shoulder"] = 0.72,
    ["L Arm"]      = 0.55,
    ["R Arm"]      = 0.55,
    ["L Hip"]      = 0.38,
    ["R Hip"]      = 0.38,
    ["L Leg"]      = 0.18,
    ["R Leg"]      = 0.18,
}

local function getAimboneWorldPos(char, vm, boneName)
    if boneName == "Head" then
        return vm and getVMHeadCenter(vm)
    end
    if not char then return nil end
    local ok, bbCF, bbSz = pcall(function() return char:GetBoundingBox() end)
    if ok and bbCF and bbSz and bbSz.Y > 0.5 then
        local bot  = bbCF.Position - Vector3.new(0, bbSz.Y * 0.5, 0)
        local frac = BONE_Y_FRAC[boneName] or 0.5
        return bot + Vector3.new(0, bbSz.Y * frac, 0)
    end
    local ref = char:FindFirstChild("HumanoidRootPart")
             or char:FindFirstChildWhichIsA("BasePart", true)
    return ref and ref.Position
end

local function aimHasLOS(targetPos, targetChar)
    local params = RaycastParams.new()
    local filter = {workspace.CurrentCamera}
    if LocalPlayer.Character then table.insert(filter, LocalPlayer.Character) end
    params.FilterDescendantsInstances = filter
    params.FilterType = Enum.RaycastFilterType.Exclude
    local origin = Camera.CFrame.Position
    local dir    = targetPos - origin
    local result = workspace:Raycast(origin, dir, params)
    if not result then return true end
    if targetChar and result.Instance:IsDescendantOf(targetChar) then return true end
    return false
end

RunService:BindToRenderStep(AIMBOT_STEP, Enum.RenderPriority.Last.Value - 1, function(dt)
    -- nur zielen während Hold-Taste gehalten UND Master-Toggle an
    if not (Settings.AimbotEnabled and Settings.AimbotHeld) then return end

    local vp     = Camera.ViewportSize
    local cx, cy = vp.X * 0.5, vp.Y * 0.5
    local fovRad = math.tan(math.rad(Settings.AimbotFOV * 0.5))
                 / math.tan(math.rad(Camera.FieldOfView * 0.5))
    local fovPx  = fovRad * (vp.Y * 0.5)

    local activeBones = Settings.AimbotBones
    if not activeBones or #activeBones == 0 then activeBones = {"Head"} end

    local bestWorldPos = nil
    local bestDist     = math.huge

    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Settings.ESPTeamCheck and LocalPlayer.Team and player.Team
           and player.Team == LocalPlayer.Team then continue end

        local char = findPlayerModel(player)
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health <= 0 then continue end

        local ref = char:FindFirstChild("HumanoidRootPart")
                 or char:FindFirstChildWhichIsA("BasePart", true)
        if not ref then continue end
        if (Camera.CFrame.Position - ref.Position).Magnitude > Settings.ESPMaxDistance then continue end

        local vm = findViewmodelNear(ref.Position)
        if not vm then continue end

        for _, boneName in ipairs(activeBones) do
            local worldPos = getAimboneWorldPos(char, vm, boneName)
            if not worldPos then continue end

            local sp, onScreen = Camera:WorldToViewportPoint(worldPos)
            if not onScreen or sp.Z <= 0 then continue end

            local dx = sp.X - cx
            local dy = sp.Y - cy
            local screenDist = math.sqrt(dx*dx + dy*dy)
            if screenDist >= fovPx or screenDist >= bestDist then continue end

            if Settings.AimbotWallcheck and not aimHasLOS(worldPos, char) then continue end

            bestDist     = screenDist
            bestWorldPos = worldPos
        end
    end

    if bestWorldPos then
        local cam       = workspace.CurrentCamera
        local currentCF = cam.CFrame
        local targetCF  = CFrame.lookAt(currentCF.Position, bestWorldPos)
        local s      = 1 - (Settings.AimbotSmoothing / 100) * 0.9
        local frameS = math.clamp(1 - (1 - s)^(dt * 60), 0.01, 1)
        cam.CFrame = currentCF:Lerp(targetCF, frameS)
    end
end)

-- =====================
--   SMOKE HITBOX + DEBUG
-- =====================
local SmokeHitboxDrawings = {}   -- [i] = Drawing Circle
local SmokeDebugLog       = {}   -- [{time, grenades=[pos...], parts=[pos...]}]
local smokeDebugText      = newDrawing("Text")
smokeDebugText.Size         = 12
smokeDebugText.Outline      = true
smokeDebugText.Center       = false
smokeDebugText.Position     = Vector2.new(10, 120)
smokeDebugText.Transparency = 1
smokeDebugText.Visible      = false

local SMOKE_LOG_FILE = "OpOne_Configs/smoke_log.json"

smokeSampleFn = function()
    local grenades, parts = {}, {}
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == "SmokeGrenade" then
                local pos
                if obj:IsA("BasePart") then pos = obj.Position
                elseif obj:IsA("Model") then pos = obj:GetPivot().Position end
                if pos then table.insert(grenades, pos) end
            elseif obj.Name == "SmokePart" and obj:IsA("BasePart") then
                table.insert(parts, obj.Position)
            end
        end
    end)

    -- convert Vector3 to serializable table
    local function v3(p) return {x=p.X,y=p.Y,z=p.Z} end
    local entry = {
        time     = os.time(),
        grenades = {},
        parts    = {},
    }
    for _, p in ipairs(grenades) do table.insert(entry.grenades, v3(p)) end
    for _, p in ipairs(parts)    do table.insert(entry.parts,    v3(p)) end

    table.insert(SmokeDebugLog, {time = tick(), grenades = grenades, parts = parts})
    while #SmokeDebugLog > 30 do table.remove(SmokeDebugLog, 1) end

    -- load existing file, append, save
    pcall(function()
        ensureFolder()
        local existing = {}
        pcall(function()
            existing = HttpService:JSONDecode(readfile(SMOKE_LOG_FILE))
        end)
        if type(existing) ~= "table" then existing = {} end
        table.insert(existing, entry)
        while #existing > 200 do table.remove(existing, 1) end
        writefile(SMOKE_LOG_FILE, HttpService:JSONEncode(existing))
    end)

    Lib:Notify({ Title = "Smoke Debug", Text = string.format("Sample saved (%dG %dP)", #grenades, #parts), Duration = 2 })
end

-- load previous samples from file on startup
pcall(function()
    ensureFolder()
    local data = HttpService:JSONDecode(readfile(SMOKE_LOG_FILE))
    if type(data) == "table" then
        for _, entry in ipairs(data) do
            local g, p = {}, {}
            for _, v in ipairs(entry.grenades or {}) do table.insert(g, Vector3.new(v.x,v.y,v.z)) end
            for _, v in ipairs(entry.parts    or {}) do table.insert(p, Vector3.new(v.x,v.y,v.z)) end
            table.insert(SmokeDebugLog, {time = 0, grenades = g, parts = p})
        end
    end
end)

local function getSmokeHitboxDrawing(i)
    if not SmokeHitboxDrawings[i] then
        local c = newDrawing("Circle")
        c.Filled    = false
        c.Thickness = 1
        c.NumSides  = 24
        c.Visible   = false
        SmokeHitboxDrawings[i] = c
    end
    return SmokeHitboxDrawings[i]
end

-- Shared 100ms cache for smoke object positions – avoids two GetDescendants() per frame.
local _smokeCacheTime     = 0
local _smokeCacheGrenades = {}
local _smokeCacheParts    = {}
local function _refreshSmokeCache()
    if (tick() - _smokeCacheTime) < 0.1 then return end
    _smokeCacheTime = tick()
    local g, p = {}, {}
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == "SmokeGrenade" then
                local pos
                if obj:IsA("BasePart") then pos = obj.Position
                elseif obj:IsA("Model") then pos = obj:GetPivot().Position end
                if pos then table.insert(g, pos) end
            elseif obj.Name == "SmokePart" and obj:IsA("BasePart") then
                table.insert(p, obj.Position)
            end
        end
    end)
    _smokeCacheGrenades, _smokeCacheParts = g, p
end

track(RunService.RenderStepped:Connect(function()
    -- smoke hitbox: one circle per SmokeGrenade at calibrated 6.5-stud radius
    local shIdx = 0
    if Settings.AntiSmokeHitbox then
        _refreshSmokeCache()
        pcall(function()
            for _, pos in ipairs(_smokeCacheGrenades) do
                local sp = Camera:WorldToViewportPoint(pos)
                if sp.Z > 0 then
                    local fovTan = math.tan(math.rad(Camera.FieldOfView) / 2)
                    local pps    = Camera.ViewportSize.Y / (2 * sp.Z * fovTan)
                    shIdx = shIdx + 1
                    local c = getSmokeHitboxDrawing(shIdx)
                    c.Position     = Vector2.new(sp.X, sp.Y)
                    c.Radius       = math.max(4, 6.5 * pps)
                    c.Color        = Color3.fromRGB(200, 200, 100)
                    c.Transparency = 0.6
                    c.Visible      = true
                end
            end
        end)
    end
    for i = shIdx + 1, #SmokeHitboxDrawings do SmokeHitboxDrawings[i].Visible = false end

    -- smoke debug overlay (always visible when enabled, regardless of menu)
    if Settings.SmokeDebug then
        _refreshSmokeCache()
        local grenades, parts = _smokeCacheGrenades, _smokeCacheParts
        local lines = {"=== SMOKE DEBUG ===",
            string.format("Live: %d SmokeGrenade  %d SmokePart", #grenades, #parts)}
        for i, g in ipairs(grenades) do
            local maxR = 0
            for _, s in ipairs(parts) do
                local r = (s - g).Magnitude
                if r > maxR then maxR = r end
            end
            lines[#lines+1] = string.format("G%d (%.1f,%.1f,%.1f)  liveR=%.1f", i, g.X,g.Y,g.Z, maxR)
        end
        -- stats from accumulated samples
        if #SmokeDebugLog > 0 then
            lines[#lines+1] = string.format("Samples: %d", #SmokeDebugLog)
            local allR = {}
            for _, smp in ipairs(SmokeDebugLog) do
                for _, g in ipairs(smp.grenades) do
                    for _, s in ipairs(smp.parts) do
                        table.insert(allR, (s - g).Magnitude)
                    end
                end
            end
            if #allR > 0 then
                table.sort(allR)
                local sum = 0; for _, r in ipairs(allR) do sum = sum + r end
                lines[#lines+1] = string.format("  R: min=%.1f  avg=%.1f  max=%.1f  n=%d",
                    allR[1], sum/#allR, allR[#allR], #allR)
            end
        end
        smokeDebugText.Text    = table.concat(lines, "\n")
        smokeDebugText.Color   = Color3.fromRGB(255, 240, 100)
        smokeDebugText.Visible = true
    else
        smokeDebugText.Visible = false
    end
end))

-- =====================
--       UNLOAD
-- =====================
unloadScript = function()
    for _, conn in pairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    Connections = {}

    for _, d in pairs(Drawings) do
        pcall(function() d:Remove() end)
    end
    Drawings       = {}
    ESPObjects     = {}
    GadgetDrawings = {}
    GrenadeTrailLines = {}; GrenadeTrailData = {}
    SmokeHitboxDrawings = {}
    for _, h in pairs(GadgetHighlights) do pcall(h.Destroy, h) end
    GadgetHighlights = {}
    SmokeDebugLog = {}

    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum.WalkSpeed = 16 end)
            pcall(function() hum.JumpPower = 50 end)
        end
    end

    RunService:UnbindFromRenderStep("GsNoRecoil")
    RunService:UnbindFromRenderStep("GsFullbright")
    RunService:UnbindFromRenderStep(MENU_CURSOR)
    RunService:UnbindFromRenderStep(FREECAM_STEP)
    RunService:UnbindFromRenderStep(TP_STEP)
    RunService:UnbindFromRenderStep(AIMBOT_STEP)
    if Settings.FreecamEnabled then applyFreecam(false) end
    if Settings.ThirdPerson    then applyThirdPerson(false) end
    pcall(function() ContextActionService:UnbindAction(MENU_SINK) end)
    if Settings.FullbrightEnabled then applyFullbright(false) end
    hookActive = false
    applyMenuState(false)

    if Settings.GunForceAuto then
        applyForceAuto(false)
    end

    if flashGui then
        pcall(function() flashGui.Enabled = true end)
        flashGui = nil
    end
    hiddenParts  = setmetatable({}, { __mode = "k" })
    handledSmoke = setmetatable({}, { __mode = "k" })

    -- defer destroy so this callback has already returned before the GUI is gone
    task.defer(function() pcall(function() Window:Destroy() end) end)
end

-- autoload on startup
do
    local al = getAutoload()
    if al then
        if loadConfig(al) then
            applyBindings()
            Lib:Notify({ Title = "Config", Text = "Autoloaded: " .. al, Duration = 4 })
        end
    end
end