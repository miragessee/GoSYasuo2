if myHero.charName ~= "Yasuo" then return end

-- [ update ]
--[[ do

local Version = 4

local Files = {
Lua = {
Path = SCRIPT_PATH,
Name = "Akali.lua",
Url = "https://raw.githubusercontent.com/miragessee/GoSAkali/master/Akali.lua"
},
Version = {
Path = SCRIPT_PATH,
Name = "miragesakali.version",
Url = "https://raw.githubusercontent.com/miragessee/GoSAkali/master/miragesakali.version"
}
}

local function AutoUpdate()

local function DownloadFile(url, path, fileName)
DownloadFileAsync(url, path .. fileName, function() end)
while not FileExist(path .. fileName) do end
end

local function ReadFile(path, fileName)
local file = io.open(path .. fileName, "r")
local result = file:read()
file:close()
return result
end

DownloadFile(Files.Version.Url, Files.Version.Path, Files.Version.Name)

local NewVersion = tonumber(ReadFile(Files.Version.Path, Files.Version.Name))
if NewVersion > Version then
DownloadFile(Files.Lua.Url, Files.Lua.Path, Files.Lua.Name)
print(Files.Version.Name .. ": Updated to " .. tostring(NewVersion) .. ". Please Reload with 2x F6")
else
print(Files.Version.Name .. ": No Updates Found")
end

end

AutoUpdate()

end
]]
local _atan = math.atan2
local _min = math.min
local _abs = math.abs
local _sqrt = math.sqrt
local _floor = math.floor
local _max = math.max
local _pow = math.pow
local _huge = math.huge
local _pi = math.pi
local _insert = table.insert
local _contains = table.contains
local _sort = table.sort
local _pairs = pairs
local _find = string.find
local _sub = string.sub
local _len = string.len

local LocalDrawLine = Draw.Line;
local LocalDrawColor = Draw.Color;
local LocalDrawCircle = Draw.Circle;
local LocalDrawCircleMinimap = Draw.CircleMinimap;
local LocalDrawText = Draw.Text;
local LocalControlIsKeyDown = Control.IsKeyDown;
local LocalControlMouseEvent = Control.mouse_event;
local LocalControlSetCursorPos = Control.SetCursorPos;
local LocalControlCastSpell = Control.CastSpell;
local LocalControlKeyUp = Control.KeyUp;
local LocalControlKeyDown = Control.KeyDown;
local LocalControlMove = Control.Move;
local LocalGetTickCount = GetTickCount;
local LocalGamecursorPos = Game.cursorPos;
local LocalGameCanUseSpell = Game.CanUseSpell;
local LocalGameLatency = Game.Latency;
local LocalGameTimer = Game.Timer;
local LocalGameHeroCount = Game.HeroCount;
local LocalGameHero = Game.Hero;
local LocalGameMinionCount = Game.MinionCount;
local LocalGameMinion = Game.Minion;
local LocalGameTurretCount = Game.TurretCount;
local LocalGameTurret = Game.Turret;
local LocalGameWardCount = Game.WardCount;
local LocalGameWard = Game.Ward;
local LocalGameObjectCount = Game.ObjectCount;
local LocalGameObject = Game.Object;
local LocalGameMissileCount = Game.MissileCount;
local LocalGameMissile = Game.Missile;
local LocalGameParticleCount = Game.ParticleCount;
local LocalGameParticle = Game.Particle;
local LocalGameIsChatOpen = Game.IsChatOpen;
local LocalGameIsOnTop = Game.IsOnTop;

local writeChat = 0

function GetMode()
    if _G.SDK then
        if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
            return "Combo"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
            return "Harass"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
            return "Clear"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
            return "Flee"
        end
    else
        return GOS.GetMode()
    end
end

local function IsReady(spell)
    return Game.CanUseSpell(spell) == 0
end

function GetBestLinearFarmPos(range, width)
    local BestPos = nil
    local MostHit = 0
    for i = 1, Game.MinionCount() do
        local m = Game.Minion(i)
        if m and m.isEnemy and not m.dead then
            local EndPos = myHero.pos + (m.pos - myHero.pos):Normalized() * range
            local Count = MinionsOnLine(myHero.pos, EndPos, width, 300 - myHero.team)
            if Count > MostHit then
                MostHit = Count
                BestPos = m.pos
            end
        end
    end
    return BestPos, MostHit
end

function EnemiesAround(pos, range)
    local N = 0
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if ValidTarget(hero, range + hero.boundingRadius) and hero.isEnemy and not hero.dead then
            N = N + 1
        end
    end
    return N
end

function IsKnocked(unit)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and (buff.type == 29 or buff.type == 30 or buff.type == 31) and buff.count > 0 then
            return true
        end
    end
    return false
end

function IsImmobile(unit)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and (buff.type == 5 or buff.type == 11 or buff.type == 18 or buff.type == 22 or buff.type == 24 or buff.type == 28 or buff.type == 29 or buff.name == "recall") and buff.count > 0 then
            return true
        end
    end
    return false
end

function ValidTarget(target, range)
    range = range and range or math.huge
    return target ~= nil and target.valid and target.visible and not target.dead and target.distance <= range
end

local function GetDistanceSqr(Pos1, Pos2)
    local Pos2 = Pos2 or myHero.pos
    local dx = Pos1.x - Pos2.x
    local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
    return dx ^ 2 + dz ^ 2
end

local function GetDistanceE(Pos1, Pos2)
    return math.sqrt(GetDistanceSqr(Pos1, Pos2))
end

local function GetDistance(Pos1, Pos2)
    return math.sqrt(GetDistanceSqr(Pos1, Pos2))
end

function GetDistance2D(p1, p2)
    return _sqrt(_pow((p2.x - p1.x), 2) + _pow((p2.y - p1.y), 2))
end

local _OnWaypoint = {}
function OnWaypoint(unit)
    if _OnWaypoint[unit.networkID] == nil then _OnWaypoint[unit.networkID] = {pos = unit.posTo, speed = unit.ms, time = LocalGameTimer()} end
    if _OnWaypoint[unit.networkID].pos ~= unit.posTo then
        _OnWaypoint[unit.networkID] = {startPos = unit.pos, pos = unit.posTo, speed = unit.ms, time = LocalGameTimer()}
        DelayAction(function()
            local time = (LocalGameTimer() - _OnWaypoint[unit.networkID].time)
            local speed = GetDistance2D(_OnWaypoint[unit.networkID].startPos, unit.pos) / (LocalGameTimer() - _OnWaypoint[unit.networkID].time)
            if speed > 1250 and time > 0 and unit.posTo == _OnWaypoint[unit.networkID].pos and GetDistance(unit.pos, _OnWaypoint[unit.networkID].pos) > 200 then
                _OnWaypoint[unit.networkID].speed = GetDistance2D(_OnWaypoint[unit.networkID].startPos, unit.pos) / (LocalGameTimer() - _OnWaypoint[unit.networkID].time)
            end
        end, 0.05)
    end
    return _OnWaypoint[unit.networkID]
end

local function VectorPointProjectionOnLineSegment(v1, v2, v)
    local cx, cy, ax, ay, bx, by = v.x, (v.z or v.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y)
    local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) ^ 2 + (by - ay) ^ 2)
    local pointLine = {x = ax + rL * (bx - ax), y = ay + rL * (by - ay)}
    local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
    local isOnSegment = rS == rL
    local pointSegment = isOnSegment and pointLine or {x = ax + rS * (bx - ax), y = ay + rS * (by - ay)}
    return pointSegment, pointLine, isOnSegment
end

function GetMinionCollision(StartPos, EndPos, Width, Target)
    local Count = 0
    for i = 1, LocalGameMinionCount() do
        local m = LocalGameMinion(i)
        if m and not m.isAlly then
            local w = Width + m.boundingRadius
            local pointSegment, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(StartPos, EndPos, m.pos)
            if isOnSegment and GetDistanceSqr(pointSegment, m.pos) < w ^ 2 and GetDistanceSqr(StartPos, EndPos) > GetDistanceSqr(StartPos, m.pos) then
                Count = Count + 1
            end
        end
    end
    return Count
end

function GetEnemyHeroes()
    EnemyHeroes = {}
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isEnemy then
            table.insert(EnemyHeroes, Hero)
        end
    end
    return EnemyHeroes
end

function GetHeroByHandle(handle)
    for i = 1, Game.HeroCount() do
        local h = Game.Hero(i)
        if h.handle == handle then
            return h
        end
    end
end

function IsUnderTurret(unit)
    for i = 1, Game.TurretCount() do
        local turret = Game.Turret(i);
        if turret and turret.isEnemy and turret.valid and turret.health > 0 then
            if GetDistance(unit, turret.pos) <= 850 then
                return true
            end
        end
    end
    return false
end

function GetDashPos(unit)
    return myHero.pos + (unit.pos - myHero.pos):Normalized() * 500
end

function GetSpellQName()
    return myHero:GetSpellData(_Q).name
end

function GetSpellEName()
    return myHero:GetSpellData(_E).name
end

function GetSpellRName()
    return myHero:GetSpellData(_R).name
end

function QDmg()
    local Dmg1 = ((({20, 45, 70, 95, 120})[myHero:GetSpellData(_Q).level]) + myHero.totalDamage)
    return Dmg1
end

function EDmg()
    local Dmg1 = (({60, 70, 80, 90, 100})[myHero:GetSpellData(_E).level] + 0.20 * myHero.bonusDamage + 0.60 * myHero.ap)
    return Dmg1
end

function RDmg()
    if myHero:GetSpellData(_R).level == 0 then
        local Dmg1 = (({120, 180, 240})[1] + 0.5 * myHero.bonusDamage)
        return Dmg1
    else
        local Dmg1 = (({120, 180, 240})[myHero:GetSpellData(_R).level] + 0.5 * myHero.bonusDamage)
        return Dmg1
    end
end

function RbDmg(unit)
    if myHero:GetSpellData(_R).level == 0 then
        local missingHealthPercent = (1 - (unit.health / unit.maxHealth)) * 100
        local totalIncreasement = 1 + ((1.5 * missingHealthPercent) / 100)
        local RDmg = (({120, 180, 240})[1] + 0.3 * myHero.ap) * totalIncreasement
        return RDmg
    else
        local missingHealthPercent = (1 - (unit.health / unit.maxHealth)) * 100
        local totalIncreasement = 1 + ((1.5 * missingHealthPercent) / 100)
        local RDmg = (({120, 180, 240})[myHero:GetSpellData(_R).level] + 0.3 * myHero.ap) * totalIncreasement
        return RDmg
    end
end

function GotBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then
            return buff.count
        end
    end
    return 0
end

function GetEbTarget()
    for i, enemy in pairs(GetEnemyHeroes()) do
        if GotBuff(enemy, "AkaliEMis") then
            return enemy
        end
    end
end

function IsRecalling()
    for K, Buff in pairs(GetBuffs(myHero)) do
        if Buff.name == "recall" and Buff.duration > 0 then
            return true
        end
    end
    return false
end

function IsImmune(unit)
    if type(unit) ~= "userdata" then error("{IsImmune}: bad argument #1 (userdata expected, got " .. type(unit) .. ")") end
    for i, buff in pairs(GetBuffs(unit)) do
        if (buff.name == "KindredRNoDeathBuff" or buff.name == "UndyingRage") and GetPercentHP(unit) <= 10 then
            return true
        end
        if buff.name == "VladimirSanguinePool" or buff.name == "JudicatorIntervention" then
            return true
        end
    end
    return false
end

function MinionsOnLine(startpos, endpos, width, team)
    local Count = 0
    for i = 1, Game.MinionCount() do
        local m = Game.Minion(i)
        if m and m.team == team and not m.dead then
            local w = width + m.boundingRadius
            local pointSegment, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(startpos, endpos, m.pos)
            if isOnSegment and GetDistanceSqr(pointSegment, m.pos) < w ^ 2 and GetDistanceSqr(startpos, endpos) > GetDistanceSqr(startpos, m.pos) then
                Count = Count + 1
            end
        end
    end
    return Count
end

function GetPercentHP(unit)
    return 100 * unit.health / unit.maxHealth
end

local units = {}

for i = 1, Game.HeroCount() do
    local unit = Game.Hero(i)
    units[i] = {unit = unit, spell = nil}
end

local function ProcessSpell()
    for i = 1, #units do
        local unit = units[i].unit
        local last = units[i].spell
        local spell = unit.activeSpell
        if spell and last ~= (spell.name .. spell.startTime) and unit.isChanneling then
            units[i].spell = spell.name .. spell.startTime
            return unit, spell
        end
    end
    return nil, nil
end

class "Yasuo"

local HeroIcon = "https://www.mobafire.com/images/avatars/yasuo-classic.png"
local IgniteIcon = "http://pm1.narvii.com/5792/0ce6cda7883a814a1a1e93efa05184543982a1e4_hq.jpg"
local QIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e5/Steel_Tempest.png"
local Q3Icon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4b/Steel_Tempest_3.png"
local WIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/61/Wind_Wall.png"
local EIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f8/Sweeping_Blade.png"
local RIcon = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/c6/Last_Breath.png"

local Version, Author, LVersion = "v1", "miragessee & Ark223", "8.17"

local Q3Timer = 0

function Yasuo:LoadMenu()
    self.YasuoMenu = MenuElement({type = MENU, id = "Yasuo", name = "ArkMirage Yasuo", leftIcon = HeroIcon})
    
    self.YasuoMenu:MenuElement({id = "AutoWindWall", name = "AutoWindWall", type = MENU})
    self.YasuoMenu.AutoWindWall:MenuElement({id = "UseW", name = "Use W [Wind Wall]", value = true, leftIcon = WIcon})
    
    self.YasuoMenu:MenuElement({id = "Harass", name = "Harass", type = MENU})
    self.YasuoMenu.Harass:MenuElement({id = "UseQ", name = "Use Q [Steel Tempest]", value = true, leftIcon = QIcon})
    self.YasuoMenu.Harass:MenuElement({id = "UseQM", name = "Use Q is minion kill", value = true, leftIcon = QIcon})
    self.YasuoMenu.Harass:MenuElement({id = "UseQ3", name = "Use Q3 [Gathering Storm]", value = true, leftIcon = Q3Icon})
    --self.YasuoMenu.Harass:MenuElement({id = "UseE", name = "Use E [Sweeping Blade]", value = true, leftIcon = EIcon})
    --self.YasuoMenu.Harass:MenuElement({id = "UseEB", name = "Use Q3 or E attack E back", value = true, leftIcon = EIcon})
    --self.YasuoMenu.Harass:MenuElement({id = "Turret", name = "Under-Turret Logic", value = true})
    self.YasuoMenu:MenuElement({id = "Combo", name = "Combo", type = MENU})
    self.YasuoMenu.Combo:MenuElement({id = "UseQ", name = "Use Q [Steel Tempest]", value = true, leftIcon = QIcon})
    self.YasuoMenu.Combo:MenuElement({id = "UseQ3", name = "Use Q3 [Gathering Storm]", value = true, leftIcon = Q3Icon})
    self.YasuoMenu.Combo:MenuElement({id = "UseE", name = "Use E [Sweeping Blade]", value = true, leftIcon = EIcon})
    self.YasuoMenu.Combo:MenuElement({id = "UseWE", name = "Use W is E attack", value = true, leftIcon = WIcon})
    self.YasuoMenu.Combo:MenuElement({id = "UseR", name = "Use R [Last Breath]", value = true, leftIcon = RIcon})
    self.YasuoMenu.Combo:MenuElement({id = "Turret", name = "Under-Turret Logic", value = false})
    self.YasuoMenu.Combo:MenuElement({id = "X", name = "Minimum Enemies: R", value = 1, min = 0, max = 5, step = 1})
    self.YasuoMenu.Combo:MenuElement({id = "HP", name = "HP-Manager: R", value = 40, min = 0, max = 100, step = 5})
    
    self.YasuoMenu:MenuElement({id = "KillSteal", name = "KillSteal", type = MENU})
    self.YasuoMenu.KillSteal:MenuElement({id = "UseR", name = "Use R [Last Breath]", value = true, leftIcon = RIcon})
    self.YasuoMenu.KillSteal:MenuElement({id = "UseIgnite", name = "Use Ignite", value = true, leftIcon = IgniteIcon})
    
    self.YasuoMenu:MenuElement({id = "LaneClear", name = "LaneClear", type = MENU})
    self.YasuoMenu.LaneClear:MenuElement({id = "UseQ", name = "Use Q [Steel Tempest]", value = true, leftIcon = QIcon})
    self.YasuoMenu.LaneClear:MenuElement({id = "UseQ3", name = "Use Q3 [Gathering Storm]", value = true, leftIcon = Q3Icon})
    self.YasuoMenu.LaneClear:MenuElement({id = "UseE", name = "Use E [Sweeping Blade]", value = false, leftIcon = EIcon})
    self.YasuoMenu.LaneClear:MenuElement({id = "UseEM", name = "Use E is minion kill", value = false, leftIcon = EIcon})
    
    self.YasuoMenu:MenuElement({id = "LastHit", name = "LastHit", type = MENU})
    self.YasuoMenu.LastHit:MenuElement({id = "UseQ", name = "Use Q [Steel Tempest]", value = false, leftIcon = QIcon})
    self.YasuoMenu.LastHit:MenuElement({id = "UseE", name = "Use E [Sweeping Blade]", value = true, leftIcon = EIcon})
    
    self.YasuoMenu:MenuElement({id = "AntiGapcloser", name = "Anti-Gapcloser", type = MENU})
    self.YasuoMenu.AntiGapcloser:MenuElement({id = "UseQ3", name = "Use Q3 [Gathering Storm]", value = true, leftIcon = Q3Icon})
    self.YasuoMenu.AntiGapcloser:MenuElement({id = "Distance", name = "Distance: Q3", value = 400, min = 25, max = 500, step = 25})
    
    self.YasuoMenu:MenuElement({id = "Flee", name = "Flee", type = MENU})
    self.YasuoMenu.Flee:MenuElement({id = "UseQ", name = "Use Q [Steel Tempest]", value = true, leftIcon = QIcon})
    self.YasuoMenu.Flee:MenuElement({id = "UseE", name = "Use E [Sweeping Blade]", value = true, leftIcon = EIcon})
    
    self.YasuoMenu:MenuElement({id = "Drawings", name = "Drawings", type = MENU})
    self.YasuoMenu.Drawings:MenuElement({id = "DrawQE", name = "Draw QE Range", value = true})
    self.YasuoMenu.Drawings:MenuElement({id = "DrawQ3", name = "Draw Q3 Range", value = true})
    self.YasuoMenu.Drawings:MenuElement({id = "DrawW", name = "Draw W Range", value = true})
    self.YasuoMenu.Drawings:MenuElement({id = "DrawR", name = "Draw R Range", value = true})
    self.YasuoMenu.Drawings:MenuElement({id = "DrawAA", name = "Draw Killable AAs", value = true})
    self.YasuoMenu.Drawings:MenuElement({id = "DrawJng", name = "Draw Jungler Info", value = true})
    
    self.YasuoMenu:MenuElement({id = "Items", name = "Items", type = MENU})
    self.YasuoMenu.Items:MenuElement({id = "UseBC", name = "Use Bilgewater Cutlass", value = true})
    self.YasuoMenu.Items:MenuElement({id = "UseBOTRK", name = "Use BOTRK", value = true})
    self.YasuoMenu.Items:MenuElement({id = "UseHG", name = "Use Hextech Gunblade", value = true})
    --self.YasuoMenu.Items:MenuElement({id = "UseMS", name = "Use Mercurial Scimitar", value = true})
    --self.YasuoMenu.Items:MenuElement({id = "UseQS", name = "Use Quicksilver Sash", value = true})
    self.YasuoMenu.Items:MenuElement({id = "OI", name = "%HP To Use Offensive Items", value = 35, min = 0, max = 100, step = 5})
end

function Yasuo:LoadSpells()
    YasuoQ = {speed = math.huge, range = 475, delay = myHero.attackData.windUpTime, radius = 40, width = 40, collision = false, aoe = true, type = "line"}
    YasuoQ3 = {speed = 1200, range = 1000, delay = myHero.attackData.windUpTime, radius = 90, width = 90, collision = false, aoe = true, type = "line"}
    YasuoW = {range = 400}
    YasuoE = {range = 475}
    YasuoR = {range = 1400}
end

function Yasuo:__init()
    Item_HK = {}
    self:LoadMenu()
    self:LoadSpells()
    self.WallSpells = {
        ["AatroxW"] = {type = "linear", range = 825, radius = 80, collision = true},
        ["AhriOrbofDeception"] = {type = "linear", range = 880},
        ["AhriSeduce"] = {type = "linear", range = 975, radius = 60, collision = true},
        ["BandageToss"] = {type = "linear", range = 1100, radius = 80, collision = true},
        ["FlashFrostSpell"] = {type = "linear", range = 1075},
        ["Volley"] = {type = "linear", range = 1200},
        ["EnchantedCrystalArrow"] = {type = "linear", range = 12500},
        ["AurelionSolQ"] = {type = "linear", range = 1075},
        ["BardQ"] = {type = "linear", range = 950, radius = 60, collision = true},
        ["RocketGrab"] = {type = "linear", range = 925, radius = 70, collision = true},
        ["BrandQ"] = {type = "linear", range = 1050, radius = 60, collision = true},
        ["BraumQ"] = {type = "linear", range = 1000, radius = 60, collision = true},
        ["CaitlynPiltoverPeacemaker"] = {type = "linear", range = 1250},
        ["CaitlynEntrapment"] = {type = "linear", range = 750, radius = 70, collision = true},
        ["CassiopeiaW"] = {type = "circular", range = 800},
        ["PhosphorusBomb"] = {type = "circular", range = 825},
        ["MissileBarrageMissile"] = {type = "linear", range = 1225, radius = 40, collision = true},
        ["MissileBarrageMissile2"] = {type = "linear", range = 1225, radius = 40, collision = true},
        ["DianaArc"] = {type = "circular", range = 900},
        ["InfectedCleaverMissileCast"] = {type = "linear", range = 975, radius = 60, collision = true},
        ["DravenDoubleShot"] = {type = "linear", range = 1050},
        ["DravenRCast"] = {type = "linear", range = 12500},
        ["EkkoQ"] = {type = "linear", range = 1075},
        ["EliseHumanE"] = {type = "linear", range = 1075, radius = 55, collision = true},
        ["EvelynnQ"] = {type = "linear", range = 800},
        ["EzrealMysticShot"] = {type = "linear", range = 1150, radius = 60, collision = true},
        ["EzrealEssenceFlux"] = {type = "linear", range = 1000},
        ["EzrealTrueshotBarrage"] = {type = "linear", range = 12500},
        ["FioraW"] = {type = "linear", range = 750},
        ["FizzR"] = {type = "linear", range = 1300},
        ["GalioQ"] = {type = "circular", range = 825},
        ["GnarQMissile"] = {type = "linear", range = 1100},
        ["GnarBigQMissile"] = {type = "linear", range = 1100, radius = 90, collision = true},
        ["GragasQ"] = {type = "circular", range = 850},
        ["GragasR"] = {type = "circular", range = 1000},
        ["GravesQLineSpell"] = {type = "linear", range = 925},
        ["GravesSmokeGrenade"] = {type = "circular", range = 950},
        ["GravesChargeShot"] = {type = "linear", range = 1000},
        ["HecarimUlt"] = {type = "linear", range = 1000},
        ["HeimerdingerW"] = {type = "linear", radius = 1325, radius = 60, collision = true},
        ["HeimerdingerE"] = {type = "circular", range = 970},
        ["HeimerdingerEUlt"] = {type = "circular", range = 970},
        ["IllaoiE"] = {type = "linear", range = 900, radius = 50, collision = true},
        ["IreliaR"] = {type = "linear", range = 1000},
        ["IvernQ"] = {type = "linear", range = 1075, radius = 80, collision = true},
        ["HowlingGale"] = {type = "linear", range = 1000},
        ["JayceShockBlast"] = {type = "linear", range = 1175, radius = 70, collision = true},
        ["JhinQ"] = {type = "circular", range = 550},
        ["JhinW"] = {type = "linear", range = 3000},
        ["JinxWMissile"] = {type = "linear", range = 1450, radius = 60, collision = true},
        ["JinxE"] = {type = "circular", range = 900},
        ["JinxR"] = {type = "linear", range = 12500},
        ["KaisaW"] = {type = "linear", range = 3000, radius = 100, collision = true},
        ["KalistaMysticShot"] = {type = "linear", range = 1150, radius = 40, collision = true},
        ["KarmaQ"] = {type = "linear", range = 950, radius = 80, collision = true},
        ["KarmaQMantra"] = {type = "linear", range = 950, radius = 80, collision = true},
        ["KennenShurikenHurlMissile1"] = {type = "linear", range = 1050, radius = 50, collision = true},
        ["KhazixW"] = {type = "linear", range = 1000, radius = 70, collision = true},
        ["KhazixWLong"] = {type = "threeway", range = 1000, radius = 70, collision = true},
        ["KindredQ"] = {type = "linear", range = 340},
        ["KledQ"] = {type = "linear", range = 800, radius = 45, collision = true},
        ["KledRiderQ"] = {type = "linear", range = 700},
        ["KogMawQ"] = {type = "linear", range = 1175, radius = 70, collision = true},
        ["KogMawVoidOoze"] = {type = "linear", range = 1280},
        ["LeblancE"] = {type = "linear", range = 925, radius = 55, collision = true},
        ["LeblancRE"] = {type = "linear", range = 925, radius = 55, collision = true},
        ["BlinkMonkQOne"] = {type = "linear", range = 1200, radius = 60, collision = true},
        ["LeonaZenithBlade"] = {type = "linear", range = 875},
        ["LissandraQMissile"] = {type = "linear", range = 825},
        ["LissandraEMissile"] = {type = "linear", range = 1050},
        ["LucianW"] = {type = "linear", range = 900, radius = 55, collision = true},
        ["LucianR"] = {type = "linear", range = 1200, radius = 110, collision = true},
        ["LuluQ"] = {type = "linear", range = 925},
        ["LuxLightBinding"] = {type = "linear", range = 1175, radius = 50, collision = true},
        ["LuxLightStrikeKugel"] = {type = "circular", range = 1000},
        ["MaokaiQ"] = {type = "linear", range = 600},
        ["MissFortuneBulletTime"] = {type = "linear", range = 1400},
        ["DarkBindingMissile"] = {type = "linear", range = 1175, radius = 70, collision = true},
        ["NamiQ"] = {type = "circular", range = 875},
        ["NamiRMissile"] = {type = "linear", range = 2750},
        ["NautilusAnchorDragMissile"] = {type = "linear", radius = 1100, radius = 90, collision = true},
        ["JavelinToss"] = {type = "linear", range = 1500, radius = 40, collision = true},
        ["NocturneDuskbringer"] = {type = "linear", range = 1200},
        ["OlafAxeThrowCast"] = {type = "linear", range = 1000},
        ["OrnnQ"] = {type = "linear", range = 800},
        ["OrnnR"] = {type = "linear", range = 2500},
        ["OrnnRCharge"] = {type = "linear", range = 2500},
        ["PoppyRSpell"] = {type = "linear", range = 1900},
        ["PykeQRange"] = {type = "linear", range = 1100, radius = 70, collision = true},
        ["QuinnQ"] = {type = "linear", range = 1025, radius = 60, collision = true},
        ["RakanQ"] = {type = "linear", range = 900, radius = 65, collision = true},
        ["RekSaiQBurrowed"] = {type = "linear", radius = 1650, radius = 65, collision = true},
        ["RengarE"] = {type = "linear", range = 1000, radius = 70, collision = true},
        ["RivenIzunaBlade"] = {type = "linear", range = 900},
        ["RumbleGrenade"] = {type = "linear", range = 850, radius = 60, collision = true},
        ["RyzeQ"] = {type = "linear", range = 1000, radius = 55, collision = true},
        ["SejuaniR"] = {type = "circular", range = 1300},
        ["ShyvanaFireball"] = {type = "circular", range = 925},
        ["ShyvanaFireballDragon2"] = {type = "circular", range = 925},
        ["SionE"] = {type = "linear", range = 725},
        ["SivirQ"] = {type = "linear", range = 1250},
        ["SkarnerFractureMissile"] = {type = "linear", range = 1000},
        ["SonaR"] = {type = "linear", range = 900},
        ["SwainE"] = {type = "linear", range = 850},
        ["TahmKenchQ"] = {type = "linear", range = 800, radius = 70, collision = true},
        ["TaliyahQ"] = {type = "linear", range = 1000, radius = 100, collision = true},
        ["TalonW"] = {type = "linear", range = 650},
        ["TeemoRCast"] = {type = "circular", range = 900},
        ["ThreshQInternal"] = {type = "linear", range = 1100, radius = 70, collision = true},
        ["WildCards"] = {type = "threeway", range = 1450},
        ["TwitchVenomCask"] = {type = "circular", range = 950},
        ["UrgotQ"] = {type = "circular", range = 800},
        ["UrgotR"] = {type = "linear", range = 1600},
        ["VarusQ"] = {type = "linear", range = 1625},
        ["VarusR"] = {type = "linear", range = 1075},
        ["VeigarBalefulStrike"] = {type = "linear", range = 950, radius = 70, collision = true},
        ["VelKozQ"] = {type = "linear", range = 1050, radius = 50, collision = true},
        ["VelKozW"] = {type = "linear", range = 1050},
        ["VelKozE"] = {type = "circular", range = 850},
        ["ViktorDeathRay"] = {type = "linear", range = 1025},
        ["XayahQ"] = {type = "linear", range = 1100},
        ["XayahR"] = {type = "linear", range = 1100},
        ["XerathMageSpear"] = {type = "linear", range = 1050, radius = 60, collision = true},
        ["YasuoQ3"] = {type = "linear", range = 1000},
        ["YorickE"] = {type = "linear", range = 700},
        ["ZacQ"] = {type = "linear", range = 800, radius = 80, collision = true},
        ["ZedQ"] = {type = "linear", range = 900},
        ["ZiggsQ"] = {type = "circular", range = 1400},
        ["ZiggsW"] = {type = "circular", range = 1000},
        ["ZiggsE"] = {type = "circular", range = 900},
        ["ZileanQ"] = {type = "circular", range = 900},
        ["ZileanQAttachAudio"] = {type = "circular", range = 900},
        ["ZoeQMissile"] = {type = "linear", range = 800, radius = 50, collision = true},
        ["ZoeQRecast"] = {type = "linear", range = 1600, radius = 70, collision = true},
        ["ZoeE"] = {type = "linear", range = 800, radius = 50, collision = true},
        ["ZyraE"] = {type = "linear", range = 1100},
    }
    Callback.Add("Tick", function()self:ProcessSpell() end)
    Callback.Add("Tick", function()self:Tick() end)
    Callback.Add("Draw", function()self:Draw() end)
end

function Yasuo:CalculateEndPos(startPos, placementPos, unitPos, radius, range, collision, type)
    if type == "linear" or type == "threeway" then
        if collision then
            for i = 1, Game.MinionCount() do
                local minion = Game.Minion(i)
                if minion and minion.isAlly and GetDistance(minion.pos, startPos) < range then
                    local Collision = VectorPointProjectionOnLineSegment(startPos, placementPos, minion.pos)
                    if Collision and GetDistance(Collision, minion.pos) < (radius + minion.boundingRadius) then
                        local range2 = GetDistance(startPos, Collision)
                        local endPos = startPos - Vector(startPos - placementPos):Normalized() * range2
                        return endPos
                    end
                end
            end
            local endPos = startPos - Vector(startPos - placementPos):Normalized() * range
            return endPos
        else
            local endPos = startPos - Vector(startPos - placementPos):Normalized() * range
            return endPos
        end
    elseif type == "circular" then
        if range > 0 then
            if GetDistanceSqr(unitPos, placementPos) > (range ^ 2) then
                local endPos = startPos - Vector(startPos - placementPos):Normalized() * range
                return endPos
            else
                local endPos = placementPos
                return endPos
            end
        else
            local endPos = unitPos
            return endPos
        end
    end
end

function Yasuo:ProcessSpell()
    if IsReady(_W) then
        local unit, spell = ProcessSpell()
        if unit and unit.team ~= myHero.team then
            if spell.target == myHero and not spell.name:lower():find("attack") then
                local WPos = Vector(unit.pos)
                Control.CastSpell(HK_W, WPos)
            elseif self.WallSpells and self.WallSpells[spell.name] then
                local startPos = Vector(spell.startPos)
                local placementPos = Vector(spell.placementPos)
                local unitPos = Vector(unit.pos)
                local detectedSpell = self.WallSpells[spell.name]
                local range
                if self.WallSpells[spell.name] == "ThreshQInternal" or self.WallSpells[spell.name] == "YasuoQ3" then
                    range = -(detectedSpell.range)
                else
                    range = detectedSpell.range
                end
                local radius = detectedSpell.radius or 60
                local collision = detectedSpell.collision or false
                local type = detectedSpell.type
                local endPos = self:CalculateEndPos(startPos, placementPos, unitPos, radius, range, collision, type)
                endPos = Vector(endPos)
                local distance = GetDistance(unitPos, myHero.pos)
                local vectors = Vector(endPos.x - unitPos.x, 0, endPos.z - unitPos.z)
                local length = math.sqrt(vectors.x ^ 2 + vectors.z ^ 2)
                local spellPos = Vector(unitPos.x + distance * vectors.x / length, 0, unitPos.z + distance * vectors.z / length)
                if GetDistanceSqr(spellPos) < (myHero.boundingRadius * 3) ^ 2 or GetDistanceSqr(endPos) < (myHero.boundingRadius * 3) ^ 2 then
                    local WPos = Vector(unitPos)
                    Control.CastSpell(HK_W, WPos)
                end
            end
        end
    end
end

function Yasuo:Tick()
    if myHero.dead or Game.IsChatOpen() == true or IsRecalling() == true or ExtLibEvade and ExtLibEvade.Evading == true then return end
    
    --print(myHero:GetSpellData(_R)) -- YasuoRKnockUpComboW
    --if myHero.activeSpell and myHero.activeSpell.valid then
    --    print(myHero.activeSpell.name)
    --    print(myHero.activeSpell.windup)
    --    print(myHero.activeSpell.animation)
    --end
    Item_HK[ITEM_1] = HK_ITEM_1
    Item_HK[ITEM_2] = HK_ITEM_2
    Item_HK[ITEM_3] = HK_ITEM_3
    Item_HK[ITEM_4] = HK_ITEM_4
    Item_HK[ITEM_5] = HK_ITEM_5
    Item_HK[ITEM_6] = HK_ITEM_6
    Item_HK[ITEM_7] = HK_ITEM_7
    
    
    self:WindWall()
    self:KillSteal()
    
    if GetMode() == "Combo" then
        self:Items1()
        --self:Items2()
        self:Combo()
    end
    if GetMode() == "Harass" then
        self:Items1()
        --self:Items2()
        self:Harass()
    end
    if GetMode() == "Clear" then
        self:LaneClear()
        self:LastHit()
    end
    if GetMode() == "Flee" then
        self:Flee()
    end
end

function OnDraw()
    for u = 1, Game.MissileCount() do
        local missile = Game.Missile(u)
        local unit = GetHeroByHandle(missile.missileData.owner)
        if unit == myHero and missile and missile.missileData.name:lower():find("Yasuo") then
            print(missile.missileData.name)
            Draw.Circle(Vector(missile.missileData.endPos), 100, Draw.Color(192,255,255,255))
        end
    end
end

function Yasuo:Draw()
    if myHero.dead then return end

    for u = 1, Game.MissileCount() do
        local missile = Game.Missile(u)
        local unit = GetHeroByHandle(missile.missileData.owner)
        if unit == myHero and missile and missile.missileData.name:lower():find("yasuoq3mis") then
            print(missile.missileData.name)
            Draw.Circle(Vector(missile.missileData.endPos), 100, Draw.Color(192,255,255,255))
        end
    end

    if self.YasuoMenu.Drawings.DrawQE:Value() then Draw.Circle(myHero.pos, YasuoQ.range, 1, Draw.Color(255, 0, 191, 255)) end
    if self.YasuoMenu.Drawings.DrawQ3:Value() then Draw.Circle(myHero.pos, YasuoQ3.range, 1, Draw.Color(255, 65, 105, 225)) end
    if self.YasuoMenu.Drawings.DrawW:Value() then Draw.Circle(myHero.pos, YasuoW.range, 1, Draw.Color(255, 30, 144, 255)) end
    if self.YasuoMenu.Drawings.DrawR:Value() then Draw.Circle(myHero.pos, YasuoR.range, 1, Draw.Color(255, 0, 0, 255)) end
    for i, enemy in pairs(GetEnemyHeroes()) do
        if self.YasuoMenu.Drawings.DrawJng:Value() then
            if enemy:GetSpellData(SUMMONER_1).name == "SummonerSmite" or enemy:GetSpellData(SUMMONER_2).name == "SummonerSmite" then
                Smite = true
            else
                Smite = false
            end
            if Smite then
                if enemy.alive then
                    if ValidTarget(enemy) then
                        if GetDistance(myHero.pos, enemy.pos) > 3000 then
                            Draw.Text("Jungler: Visible", 17, myHero.pos2D.x - 45, myHero.pos2D.y + 10, Draw.Color(0xFF32CD32))
                        else
                            Draw.Text("Jungler: Near", 17, myHero.pos2D.x - 43, myHero.pos2D.y + 10, Draw.Color(0xFFFF0000))
                        end
                    else
                        Draw.Text("Jungler: Invisible", 17, myHero.pos2D.x - 55, myHero.pos2D.y + 10, Draw.Color(0xFFFFD700))
                    end
                else
                    Draw.Text("Jungler: Dead", 17, myHero.pos2D.x - 45, myHero.pos2D.y + 10, Draw.Color(0xFF32CD32))
                end
            end
        end
        if self.YasuoMenu.Drawings.DrawAA:Value() then
            if ValidTarget(enemy) then
                AALeft = enemy.health / myHero.totalDamage
                Draw.Text("AA Left: " .. tostring(math.ceil(AALeft)), 17, enemy.pos2D.x - 38, enemy.pos2D.y + 10, Draw.Color(0xFF00BFFF))
            end
        end
    end
end

function Yasuo:Items1()
    
    local targetBC = GOS:GetTarget(550, "AD")
    
    if targetBC then
        if (targetBC.health / targetBC.maxHealth) * 100 <= self.YasuoMenu.Items.OI:Value() then
            if self.YasuoMenu.Items.UseBC:Value() then
                if GetItemSlot(myHero, 3144) > 0 and ValidTarget(targetBC, 550) then
                    if myHero:GetSpellData(GetItemSlot(myHero, 3144)).currentCd == 0 then
                        Control.CastSpell(Item_HK[GetItemSlot(myHero, 3144)], targetBC)
                    end
                end
            end
        end
    end
    
    local targetBOTRK = GOS:GetTarget(550, "AD")
    
    if targetBOTRK then
        if (targetBOTRK.health / targetBOTRK.maxHealth) * 100 <= self.YasuoMenu.Items.OI:Value() then
            if self.YasuoMenu.Items.UseBOTRK:Value() then
                if GetItemSlot(myHero, 3153) > 0 and ValidTarget(targetBOTRK, 550) then
                    if myHero:GetSpellData(GetItemSlot(myHero, 3153)).currentCd == 0 then
                        Control.CastSpell(Item_HK[GetItemSlot(myHero, 3153)], targetBOTRK)
                    end
                end
            end
        end
    end
    
    local targetHG = GOS:GetTarget(700, "AD")
    
    if targetHG then
        if (targetHG.health / targetHG.maxHealth) * 100 <= self.YasuoMenu.Items.OI:Value() then
            if self.YasuoMenu.Items.UseHG:Value() then
                if GetItemSlot(myHero, 3146) > 0 and ValidTarget(targetHG, 700) then
                    if myHero:GetSpellData(GetItemSlot(myHero, 3146)).currentCd == 0 then
                        Control.CastSpell(Item_HK[GetItemSlot(myHero, 3146)], targetHG)
                    end
                end
            end
        end
    end
end

function Yasuo:Items2()
    if target == nil then return end
    if self.YasuoMenu.Items.UseMS:Value() then
        if GetItemSlot(myHero, 3139) > 0 then
            if myHero:GetSpellData(GetItemSlot(myHero, 3139)).currentCd == 0 then
                if IsImmobile(myHero) then
                    Control.CastSpell(Item_HK[GetItemSlot(myHero, 3139)], myHero)
                end
            end
        end
    end
    if self.YasuoMenu.Items.UseQS:Value() then
        if GetItemSlot(myHero, 3140) > 0 then
            if myHero:GetSpellData(GetItemSlot(myHero, 3140)).currentCd == 0 then
                if IsImmobile(myHero) then
                    Control.CastSpell(Item_HK[GetItemSlot(myHero, 3140)], myHero)
                end
            end
        end
    end
end

function Yasuo:KillSteal()
    for i, enemy in pairs(GetEnemyHeroes()) do
        if self.YasuoMenu.KillSteal.UseR:Value() then
            if IsReady(_R) then
                if ValidTarget(enemy, YasuoR.range) and IsKnocked(enemy) then
                    local YasuoRDmg = (({200, 300, 400})[myHero:GetSpellData(_R).level] + 1.5 * myHero.bonusDamage)
                    if (enemy.health + enemy.hpRegen * 6 + enemy.armor) < YasuoRDmg then
                        Control.CastSpell(HK_R, target)
                    end
                end
            end
        end
        if self.YasuoMenu.KillSteal.UseIgnite:Value() then
            local IgniteDmg = (55 + 25 * myHero.levelData.lvl)
            if ValidTarget(enemy, 600) and enemy.health + enemy.shieldAD < IgniteDmg then
                if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and IsReady(SUMMONER_1) then
                    Control.CastSpell(HK_SUMMONER_1, enemy)
                elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and IsReady(SUMMONER_2) then
                    Control.CastSpell(HK_SUMMONER_2, enemy)
                end
            end
        end
    end
end

function Yasuo:WindWall()
    if self.YasuoMenu.AutoWindWall.UseW:Value() then
        
        end
end

function Yasuo:CastQ(target, QcastPos)
    if LocalGameTimer() - OnWaypoint(target).time > 0.05 and (LocalGameTimer() - OnWaypoint(target).time < 0.125 or LocalGameTimer() - OnWaypoint(target).time > 1.25) then
        if GetDistance(myHero.pos, QcastPos) <= YasuoQ.range then
            LocalControlCastSpell(HK_Q, QcastPos)
        end
    end
end

function Yasuo:CastQ3(target, Q3castPos)
    if LocalGameTimer() - OnWaypoint(target).time > 0.05 and (LocalGameTimer() - OnWaypoint(target).time < 0.125 or LocalGameTimer() - OnWaypoint(target).time > 1.25) then
        if GetDistance(myHero.pos, Q3castPos) <= YasuoQ3.range then
            LocalControlCastSpell(HK_Q, Q3castPos)
        end
    end
end

function Yasuo:Harass()
    --(GetSpellQName())
    --writeChat = 0
    local targetQ = GOS:GetTarget(YasuoQ.range, "AD")
    local targetQ3 = GOS:GetTarget(YasuoQ3.range, "AD")
    
    if targetQ then
        if self.YasuoMenu.Harass.UseQ:Value() then
            if IsReady(_Q) then
                if GetSpellQName() == "YasuoQ1Wrapper" or GetSpellQName() == "YasuoQ2Wrapper" then
                    if ValidTarget(targetQ, YasuoQ.range) then
                        local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, targetQ, YasuoQ.range, YasuoQ.delay, YasuoQ.speed, YasuoQ.radius, true)
                        if hitChance and hitChance >= 2 then
                            self:CastQ(targetQ, aimPosition)
                        end
                    end
                end
            end
        end
    end
    
    if targetQ3 then
        if self.YasuoMenu.Harass.UseQ3:Value() then
            if IsReady(_Q) and GetSpellQName() == "YasuoQ3Wrapper" then
                if ValidTarget(targetQ3, YasuoQ3.range) then
                    DelayAction(function()
                        local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, targetQ3, YasuoQ3.range, YasuoQ3.delay, YasuoQ3.speed, YasuoQ3.radius, true)
                        if hitChance and hitChance >= 2 then
                            self:CastQ3(targetQ3, aimPosition)
                        end
                    end, 0.4)
                    DelayAction(function()
                        local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, targetQ3, YasuoQ3.range, YasuoQ3.delay, YasuoQ3.speed, YasuoQ3.radius, true)
                        if hitChance and hitChance >= 2 then
                            self:CastQ3(targetQ3, aimPosition)
                        end
                    end, 0.4)
                    DelayAction(function()
                        local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, targetQ3, YasuoQ3.range, YasuoQ3.delay, YasuoQ3.speed, YasuoQ3.radius, true)
                        if hitChance and hitChance >= 2 then
                            self:CastQ3(targetQ3, aimPosition)
                        end
                    end, 0.4)
                    DelayAction(function()
                        local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, targetQ3, YasuoQ3.range, YasuoQ3.delay, YasuoQ3.speed, YasuoQ3.radius, true)
                        if hitChance and hitChance >= 2 then
                            self:CastQ3(targetQ3, aimPosition)
                        end
                    end, 0.4)
                    
                    if GetSpellQName() == "YasuoQ3Wrapper" then
                        LocalControlCastSpell(HK_Q, targetQ3)
                    end
                --[[print(Game.Timer())
                print(Q3Timer)
                if Game.Timer() > Q3Timer + 5 then
                local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, targetQ3, YasuoQ3.range, YasuoQ3.delay, YasuoQ3.speed, YasuoQ3.radius, true)
                if hitChance and hitChance >= 2 then
                self:CastQ3(targetQ3, aimPosition)
                end
                Q3Timer = Game.Timer()
                else
                if GetSpellQName() == "YasuoQ3W" then
                LocalControlCastSpell(HK_Q, targetQ3)
                end
                end]]
                end
            end
        end
    end
    
    if self.YasuoMenu.Harass.UseQM:Value() then
        if GetSpellQName() == "YasuoQ1Wrapper" or GetSpellQName() == "YasuoQ2Wrapper" then
            for i = 1, LocalGameMinionCount() do
                local minion = LocalGameMinion(i)
                if minion and minion.isEnemy then
                    if IsReady(_Q) then
                        --local wRange = FizzW.range + myHero.boundingRadius + minion.boundingRadius - 35
                        local wRange = YasuoQ.range + myHero.boundingRadius + minion.boundingRadius - 35
                        if ValidTarget(minion, wRange) then
                            if minion.health < QDmg() then
                                LocalControlCastSpell(HK_Q, minion)
                            end
                        end
                    end
                end
            end
        end
    end
end

function Yasuo:Combo()
    --if writeChat == 0 then
    --	print(myHero:GetSpellData(_R))
    --	writeChat = 1
    --end
    local targetQ = GOS:GetTarget(YasuoQ.range, "AD")
    local targetQ3 = GOS:GetTarget(YasuoQ3.range, "AD")
    local targetE = GOS:GetTarget(2000, "AD")
    local targetR = GOS:GetTarget(YasuoR.range, "AD")
    
    if targetQ then
        if self.YasuoMenu.Combo.UseQ:Value() then
            if IsReady(_Q) then
                if GetSpellQName() == "YasuoQ1Wrapper" or GetSpellQName() == "YasuoQ2Wrapper" then
                    if ValidTarget(targetQ, YasuoQ.range) then
                        local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, targetQ, YasuoQ.range, YasuoQ.delay, YasuoQ.speed, YasuoQ.radius, true)
                        if hitChance and hitChance >= 2 then
                            self:CastQ(targetQ, aimPosition)
                        end
                    end
                end
            end
        end
    end
    
    if targetQ3 then
        if self.YasuoMenu.Combo.UseQ3:Value() then
            if IsReady(_Q) and GetSpellQName() == "YasuoQ3Wrapper" then
                if ValidTarget(targetQ3, YasuoQ3.range) then
                    DelayAction(function()
                        local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, targetQ3, YasuoQ3.range, YasuoQ3.delay, YasuoQ3.speed, YasuoQ3.radius, true)
                        if hitChance and hitChance >= 2 then
                            self:CastQ3(targetQ3, aimPosition)
                        end
                    end, 0.4)
                    DelayAction(function()
                        local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, targetQ3, YasuoQ3.range, YasuoQ3.delay, YasuoQ3.speed, YasuoQ3.radius, true)
                        if hitChance and hitChance >= 2 then
                            self:CastQ3(targetQ3, aimPosition)
                        end
                    end, 0.4)
                    DelayAction(function()
                        local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, targetQ3, YasuoQ3.range, YasuoQ3.delay, YasuoQ3.speed, YasuoQ3.radius, true)
                        if hitChance and hitChance >= 2 then
                            self:CastQ3(targetQ3, aimPosition)
                        end
                    end, 0.4)
                    DelayAction(function()
                        local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, targetQ3, YasuoQ3.range, YasuoQ3.delay, YasuoQ3.speed, YasuoQ3.radius, true)
                        if hitChance and hitChance >= 2 then
                            self:CastQ3(targetQ3, aimPosition)
                        end
                    end, 0.4)
                    
                    if GetSpellQName() == "YasuoQ3Wrapper" then
                        LocalControlCastSpell(HK_Q, targetQ3)
                    end
                --[[if Game.Timer() > Q3Timer + 5 then
                local hitChance, aimPosition = HPred:GetHitchance(myHero.pos, targetQ3, YasuoQ3.range, YasuoQ3.delay, YasuoQ3.speed, YasuoQ3.radius, true)
                if hitChance and hitChance >= 2 then
                self:CastQ3(targetQ3, aimPosition)
                end
                Q3Timer = Game.Timer()
                else
                if GetSpellQName() == "YasuoQ3W" then
                LocalControlCastSpell(HK_Q, targetQ3)
                end
                end]]
                end
            end
        end
    end
    
    if targetE then
        if self.YasuoMenu.Combo.UseE:Value() then
            if IsReady(_E) then
                if GetDistanceE(targetE.pos) < YasuoE.range and GetDistanceE(targetE.pos) > myHero.range then
                    if GotBuff(targetE, "YasuoDashWrapper") == 0 then
                        if self.YasuoMenu.Combo.Turret:Value() then
                            if not IsUnderTurret(GetDashPos(targetE)) then
                                DelayAction(function()
                                    LocalControlCastSpell(HK_E, targetE)
                                end, 0.1)
                                if self.YasuoMenu.Combo.UseWE:Value() then
                                    if IsReady(_W) then
                                        LocalControlCastSpell(HK_W, targetE)
                                    end
                                end
                            end
                        else
                            DelayAction(function()
                                LocalControlCastSpell(HK_E, targetE)
                            end, 0.1)
                            if self.YasuoMenu.Combo.UseWE:Value() then
                                if IsReady(_W) then
                                    LocalControlCastSpell(HK_W, targetE)
                                end
                            end
                        end
                    end
                elseif GetDistanceE(targetE.pos) < YasuoE.range + 1300 and GetDistanceE(targetE.pos) > myHero.range then
                    for i = 1, Game.MinionCount() do
                        local minion = Game.Minion(i)
                        if minion and minion.isEnemy then
                            if GetDistanceE(minion.pos) <= YasuoE.range and GotBuff(minion, "YasuoDashWrapper") == 0 then
                                local pointSegment, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(myHero.pos, targetE.pos, minion.pos)
                                if isOnSegment and GetDistanceE(pointSegment, minion.pos) < 300 then
                                    if self.YasuoMenu.Combo.Turret:Value() then
                                        if not IsUnderTurret(GetDashPos(minion)) then
                                            Control.CastSpell(HK_E, minion)
                                        end
                                    else
                                        Control.CastSpell(HK_E, minion)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    if targetR then
        if self.YasuoMenu.Combo.UseR:Value() then
            if ValidTarget(targetR, YasuoR.range) then
                if GetPercentHP(targetR) < self.YasuoMenu.Combo.HP:Value() then
                    if EnemiesAround(myHero, YasuoR.range) >= self.YasuoMenu.Combo.X:Value() then
                        Control.CastSpell(HK_R)
                    end
                end
            end
        end
    end
end

function Yasuo:LastHit()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.isEnemy then
            if self.YasuoMenu.LastHit.UseQ:Value() then
                if IsReady(_Q) and GotBuff(myHero, "YasuoQ3Wrapper") == 0 then
                    if ValidTarget(minion, YasuoQ.range) then
                        if minion.health < QDmg() then
                            Control.CastSpell(HK_Q, minion)
                        end
                    end
                end
            end
            if self.YasuoMenu.LastHit.UseE:Value() then
                if IsReady(_E) then
                    if ValidTarget(minion, YasuoE.range) and GotBuff(minion, "YasuoDashWrapper") == 0 then
                        if minion.health < EDmg() then
                            Control.CastSpell(HK_E, minion)
                        end
                    end
                end
            end
        end
    end
end

function Yasuo:LaneClear()
    if self.YasuoMenu.LaneClear.UseQ3:Value() then
        if IsReady(_Q) and GotBuff(myHero, "YasuoQ3Wrapper") > 0 then
            local BestPos, BestHit = GetBestLinearFarmPos(YasuoQ3.range, YasuoQ3.width)
            if BestPos and BestHit >= 3 then
                Control.CastSpell(HK_Q, BestPos)
            end
        end
    end
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.isEnemy then
            if self.YasuoMenu.LaneClear.UseQ:Value() then
                if IsReady(_Q) and GotBuff(myHero, "YasuoQ3Wrapper") == 0 then
                    if ValidTarget(minion, YasuoQ.range) then
                        Control.CastSpell(HK_Q, minion)
                    end
                end
            end
            if self.YasuoMenu.LaneClear.UseE:Value() then
                if IsReady(_E) and GotBuff(minion, "YasuoDashWrapper") == 0 then
                    if ValidTarget(minion, YasuoE.range) then
                        Control.CastSpell(HK_E, minion)
                    end
                end
            end
            if self.YasuoMenu.LaneClear.UseEM:Value() then
                if IsReady(_E) then
                    if ValidTarget(minion, YasuoE.range) and GotBuff(minion, "YasuoDashWrapper") == 0 then
                        if minion.health < EDmg() then
                            Control.CastSpell(HK_E, minion)
                        end
                    end
                end
            end
        end
    end
end

function OnLoad()
    Yasuo()
end

class "HPred"

local _tickFrequency = .2
local _nextTick = LocalGameTimer()
local _reviveLookupTable =
    {
        ["LifeAura.troy"] = 4,
        ["ZileanBase_R_Buf.troy"] = 3,
        ["Aatrox_Base_Passive_Death_Activate"] = 3
    }

local _blinkSpellLookupTable =
    {
        ["EzrealArcaneShift"] = 475,
        ["RiftWalk"] = 500,
        ["EkkoEAttack"] = 0,
        ["AlphaStrike"] = 0,
        ["KatarinaE"] = -255,
        ["KatarinaEDagger"] = {"Katarina_Base_Dagger_Ground_Indicator", "Katarina_Skin01_Dagger_Ground_Indicator", "Katarina_Skin02_Dagger_Ground_Indicator", "Katarina_Skin03_Dagger_Ground_Indicator", "Katarina_Skin04_Dagger_Ground_Indicator", "Katarina_Skin05_Dagger_Ground_Indicator", "Katarina_Skin06_Dagger_Ground_Indicator", "Katarina_Skin07_Dagger_Ground_Indicator", "Katarina_Skin08_Dagger_Ground_Indicator", "Katarina_Skin09_Dagger_Ground_Indicator"},
    }

local _blinkLookupTable =
    {
        "global_ss_flash_02.troy",
        "Lissandra_Base_E_Arrival.troy",
        "LeBlanc_Base_W_return_activation.troy"
    }

local _cachedBlinks = {}
local _cachedRevives = {}
local _cachedTeleports = {}
local _cachedMissiles = {}
local _incomingDamage = {}
local _windwall
local _windwallStartPos
local _windwallWidth

local _OnVision = {}
function HPred:OnVision(unit)
    if unit == nil or type(unit) ~= "userdata" then return end
    if _OnVision[unit.networkID] == nil then _OnVision[unit.networkID] = {visible = unit.visible, tick = LocalGetTickCount(), pos = unit.pos} end
    if _OnVision[unit.networkID].visible == true and not unit.visible then _OnVision[unit.networkID].visible = false _OnVision[unit.networkID].tick = LocalGetTickCount() end
    if _OnVision[unit.networkID].visible == false and unit.visible then _OnVision[unit.networkID].visible = true _OnVision[unit.networkID].tick = LocalGetTickCount()_OnVision[unit.networkID].pos = unit.pos end
    return _OnVision[unit.networkID]
end

function HPred:Tick()
    if _nextTick > LocalGameTimer() then return end
    _nextTick = LocalGameTimer() + _tickFrequency
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t then
            if t.isEnemy then
                HPred:OnVision(t)
            end
        end
    end
    if true then return end
    for _, teleport in _pairs(_cachedTeleports) do
        if teleport and LocalGameTimer() > teleport.expireTime + .5 then
            _cachedTeleports[_] = nil
        end
    end
    HPred:CacheTeleports()
    HPred:CacheParticles()
    for _, revive in _pairs(_cachedRevives) do
        if LocalGameTimer() > revive.expireTime + .5 then
            _cachedRevives[_] = nil
        end
    end
    for _, revive in _pairs(_cachedRevives) do
        if LocalGameTimer() > revive.expireTime + .5 then
            _cachedRevives[_] = nil
        end
    end
    for i = 1, LocalGameParticleCount() do
        local particle = LocalGameParticle(i)
        if particle and not _cachedRevives[particle.networkID] and _reviveLookupTable[particle.name] then
            _cachedRevives[particle.networkID] = {}
            _cachedRevives[particle.networkID]["expireTime"] = LocalGameTimer() + _reviveLookupTable[particle.name]
            local target = HPred:GetHeroByPosition(particle.pos)
            if target.isEnemy then
                _cachedRevives[particle.networkID]["target"] = target
                _cachedRevives[particle.networkID]["pos"] = target.pos
                _cachedRevives[particle.networkID]["isEnemy"] = target.isEnemy
            end
        end
        if particle and not _cachedBlinks[particle.networkID] and _blinkLookupTable[particle.name] then
            _cachedBlinks[particle.networkID] = {}
            _cachedBlinks[particle.networkID]["expireTime"] = LocalGameTimer() + _reviveLookupTable[particle.name]
            local target = HPred:GetHeroByPosition(particle.pos)
            if target.isEnemy then
                _cachedBlinks[particle.networkID]["target"] = target
                _cachedBlinks[particle.networkID]["pos"] = target.pos
                _cachedBlinks[particle.networkID]["isEnemy"] = target.isEnemy
            end
        end
    end

end

function HPred:GetEnemyNexusPosition()
    if myHero.team == 100 then return Vector(14340, 171.977722167969, 14390); else return Vector(396, 182.132507324219, 462); end
end


function HPred:GetGuarenteedTarget(source, range, delay, speed, radius, timingAccuracy, checkCollision)
    local target, aimPosition = self:GetHourglassTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetRevivingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetTeleportingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetImmobileTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
end


function HPred:GetReliableTarget(source, range, delay, speed, radius, timingAccuracy, checkCollision)
    local target, aimPosition = self:GetHourglassTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetRevivingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetTeleportingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetInstantDashTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetDashingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius, midDash)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetImmobileTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
    local target, aimPosition = self:GetBlinkTarget(source, range, speed, delay, checkCollision, radius)
    if target and aimPosition then
        return target, aimPosition
    end
end

function HPred:GetLineTargetCount(source, aimPos, delay, speed, width, targetAllies)
    local targetCount = 0
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t and self:CanTargetALL(t) and (targetAllies or t.isEnemy) then
            local predictedPos = self:PredictUnitPosition(t, delay + self:GetDistance(source, t.pos) / speed)
            local proj1, pointLine, isOnSegment = self:VectorPointProjectionOnLineSegment(source, aimPos, predictedPos)
            if proj1 and isOnSegment and (self:GetDistanceSqr(predictedPos, proj1) <= (t.boundingRadius + width) * (t.boundingRadius + width)) then
                targetCount = targetCount + 1
            end
        end
    end
    return targetCount
end

function HPred:GetUnreliableTarget(source, range, delay, speed, radius, checkCollision, minimumHitChance, whitelist, isLine)
    local _validTargets = {}
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t and self:CanTarget(t, true) and (not whitelist or whitelist[t.charName]) then
            local hitChance, aimPosition = self:GetHitchance(source, t, range, delay, speed, radius, checkCollision, isLine)
            if hitChance >= minimumHitChance then
                _insert(_validTargets, {aimPosition, hitChance, hitChance * 100 + self:CalculateMagicDamage(t, 400)})
            end
        end
    end
    _sort(_validTargets, function(a, b) return a[3] > b[3] end)
    if #_validTargets > 0 then
        return _validTargets[1][2], _validTargets[1][1]
    end
end

function HPred:GetHitchance(source, target, range, delay, speed, radius, checkCollision, isLine)
    if isLine == nil and checkCollision then
        isLine = true
    end
    local hitChance = 1
    local aimPosition = self:PredictUnitPosition(target, delay + self:GetDistance(source, target.pos) / speed)
    local interceptTime = self:GetSpellInterceptTime(source, aimPosition, delay, speed)
    local reactionTime = self:PredictReactionTime(target, .1, isLine)
    if isLine then
        local pathVector = aimPosition - target.pos
        local castVector = (aimPosition - myHero.pos):Normalized()
        if pathVector.x + pathVector.z ~= 0 then
            pathVector = pathVector:Normalized()
            if pathVector:DotProduct(castVector) < -.85 or pathVector:DotProduct(castVector) > .85 then
                if speed > 3000 then
                    reactionTime = reactionTime + .25
                else
                    reactionTime = reactionTime + .15
                end
            end
        end
    end
    Waypoints = self:GetCurrentWayPoints(target)
    if (#Waypoints == 1) then
        HitChance = 2
    end
    if self:isSlowed(target, delay, speed, source) then
        HitChance = 2
    end
    if self:GetDistance(source, target.pos) < 350 then
        HitChance = 2
    end
    local angletemp = Vector(source):AngleBetween(Vector(target.pos), Vector(aimPosition))
    if angletemp > 60 then
        HitChance = 1
    elseif angletemp < 10 then
        HitChance = 2
    end
    if not target.pathing or not target.pathing.hasMovePath then
        hitChancevisionData = 2
        hitChance = 2
    end
    local origin, movementRadius = self:UnitMovementBounds(target, interceptTime, reactionTime)
    if movementRadius - target.boundingRadius <= radius / 2 then
        origin, movementRadius = self:UnitMovementBounds(target, interceptTime, 0)
        if movementRadius - target.boundingRadius <= radius / 2 then
            hitChance = 4
        else
            hitChance = 3
        end
    end
    if target.activeSpell and target.activeSpell.valid then
        if target.activeSpell.startTime + target.activeSpell.windup - LocalGameTimer() >= delay then
            hitChance = 5
        else
            hitChance = 3
        end
    end
    local visionData = HPred:OnVision(target)
    if visionData and visionData.visible == false then
        local hiddenTime = visionData.tick - LocalGetTickCount()
        if hiddenTime < -1000 then
            hitChance = -1
        else
            local targetSpeed = self:GetTargetMS(target)
            local unitPos = target.pos + Vector(target.pos, target.posTo):Normalized() * ((LocalGetTickCount() - visionData.tick) / 1000 * targetSpeed)
            local aimPosition = unitPos + Vector(target.pos, target.posTo):Normalized() * (targetSpeed * (delay + (self:GetDistance(myHero.pos, unitPos) / speed)))
            if self:GetDistance(target.pos, aimPosition) > self:GetDistance(target.pos, target.posTo) then aimPosition = target.posTo end
            hitChance = _min(hitChance, 2)
        end
    end
    if not self:IsInRange(source, aimPosition, range) then
        hitChance = -1
    end
    if hitChance > 0 and checkCollision then
        if self:IsWindwallBlocking(source, aimPosition) then
            hitChance = -1
        elseif self:CheckMinionCollision(source, aimPosition, delay, speed, radius) then
            hitChance = -1
        end
    end
    
    return hitChance, aimPosition
end

function HPred:PredictReactionTime(unit, minimumReactionTime)
    local reactionTime = minimumReactionTime
    if unit.activeSpell and unit.activeSpell.valid then
        local windupRemaining = unit.activeSpell.startTime + unit.activeSpell.windup - LocalGameTimer()
        if windupRemaining > 0 then
            reactionTime = windupRemaining
        end
    end
    return reactionTime
end

function HPred:GetCurrentWayPoints(object)
    local result = {}
    if object.pathing.hasMovePath then
        _insert(result, Vector(object.pos.x, object.pos.y, object.pos.z))
        for i = object.pathing.pathIndex, object.pathing.pathCount do
            path = object:GetPath(i)
            _insert(result, Vector(path.x, path.y, path.z))
        end
    else
        _insert(result, object and Vector(object.pos.x, object.pos.y, object.pos.z) or Vector(object.pos.x, object.pos.y, object.pos.z))
    end
    return result
end

function HPred:GetDashingTarget(source, range, delay, speed, dashThreshold, checkCollision, radius, midDash)
    local target
    local aimPosition
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t and t.isEnemy and t.pathing.hasMovePath and t.pathing.isDashing and t.pathing.dashSpeed > 500 then
            local dashEndPosition = t:GetPath(1)
            if self:IsInRange(source, dashEndPosition, range) then
                local dashTimeRemaining = self:GetDistance(t.pos, dashEndPosition) / t.pathing.dashSpeed
                local skillInterceptTime = self:GetSpellInterceptTime(source, dashEndPosition, delay, speed)
                local deltaInterceptTime = skillInterceptTime - dashTimeRemaining
                if deltaInterceptTime > 0 and deltaInterceptTime < dashThreshold and (not checkCollision or not self:CheckMinionCollision(source, dashEndPosition, delay, speed, radius)) then
                    target = t
                    aimPosition = dashEndPosition
                    return target, aimPosition
                end
            end
        end
    end
end

function HPred:GetHourglassTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    local target
    local aimPosition
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t and t.isEnemy then
            local success, timeRemaining = self:HasBuff(t, "zhonyasringshield")
            if success then
                local spellInterceptTime = self:GetSpellInterceptTime(source, t.pos, delay, speed)
                local deltaInterceptTime = spellInterceptTime - timeRemaining
                if spellInterceptTime > timeRemaining and deltaInterceptTime < timingAccuracy and (not checkCollision or not self:CheckMinionCollision(source, interceptPosition, delay, speed, radius)) then
                    target = t
                    aimPosition = t.pos
                    return target, aimPosition
                end
            end
        end
    end
end

function HPred:GetRevivingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    local target
    local aimPosition
    for _, revive in _pairs(_cachedRevives) do
        if revive.isEnemy then
            local interceptTime = self:GetSpellInterceptTime(source, revive.pos, delay, speed)
            if interceptTime > revive.expireTime - LocalGameTimer() and interceptTime - revive.expireTime - LocalGameTimer() < timingAccuracy then
                target = revive.target
                aimPosition = revive.pos
                return target, aimPosition
            end
        end
    end
end

function HPred:GetInstantDashTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    local target
    local aimPosition
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t and t.isEnemy and t.activeSpell and t.activeSpell.valid and _blinkSpellLookupTable[t.activeSpell.name] then
            local windupRemaining = t.activeSpell.startTime + t.activeSpell.windup - LocalGameTimer()
            if windupRemaining > 0 then
                local endPos
                local blinkRange = _blinkSpellLookupTable[t.activeSpell.name]
                if type(blinkRange) == "table" then
                    elseif blinkRange > 0 then
                    endPos = Vector(t.activeSpell.placementPos.x, t.activeSpell.placementPos.y, t.activeSpell.placementPos.z)
                    endPos = t.activeSpell.startPos + (endPos - t.activeSpell.startPos):Normalized() * _min(self:GetDistance(t.activeSpell.startPos, endPos), range)
                    else
                        local blinkTarget = self:GetObjectByHandle(t.activeSpell.target)
                        if blinkTarget then
                            local offsetDirection
                            if blinkRange == 0 then
                                if t.activeSpell.name == "AlphaStrike" then
                                    windupRemaining = windupRemaining + .75
                                end
                                offsetDirection = (blinkTarget.pos - t.pos):Normalized()
                            elseif blinkRange == -1 then
                                offsetDirection = (t.pos - blinkTarget.pos):Normalized()
                            elseif blinkRange == -255 then
                                if radius > 250 then
                                    endPos = blinkTarget.pos
                                end
                            end
                            if offsetDirection then
                                endPos = blinkTarget.pos - offsetDirection * blinkTarget.boundingRadius
                            end
                        end
                end
                local interceptTime = self:GetSpellInterceptTime(source, endPos, delay, speed)
                local deltaInterceptTime = interceptTime - windupRemaining
                if self:IsInRange(source, endPos, range) and deltaInterceptTime < timingAccuracy and (not checkCollision or not self:CheckMinionCollision(source, endPos, delay, speed, radius)) then
                    target = t
                    aimPosition = endPos
                    return target, aimPosition
                end
            end
        end
    end
end

function HPred:GetBlinkTarget(source, range, speed, delay, checkCollision, radius)
    local target
    local aimPosition
    for _, particle in _pairs(_cachedBlinks) do
        if particle and self:IsInRange(source, particle.pos, range) then
            local t = particle.target
            local pPos = particle.pos
            if t and t.isEnemy and (not checkCollision or not self:CheckMinionCollision(source, pPos, delay, speed, radius)) then
                target = t
                aimPosition = pPos
                return target, aimPosition
            end
        end
    end
end

function HPred:GetChannelingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    local target
    local aimPosition
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t then
            local interceptTime = self:GetSpellInterceptTime(source, t.pos, delay, speed)
            if self:CanTarget(t) and self:IsInRange(source, t.pos, range) and self:IsChannelling(t, interceptTime) and (not checkCollision or not self:CheckMinionCollision(source, t.pos, delay, speed, radius)) then
                target = t
                aimPosition = t.pos
                return target, aimPosition
            end
        end
    end
end

function HPred:GetImmobileTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    local target
    local aimPosition
    for i = 1, LocalGameHeroCount() do
        local t = LocalGameHero(i)
        if t and self:CanTarget(t) and self:IsInRange(source, t.pos, range) then
            local immobileTime = self:GetImmobileTime(t)
            
            local interceptTime = self:GetSpellInterceptTime(source, t.pos, delay, speed)
            if immobileTime - interceptTime > timingAccuracy and (not checkCollision or not self:CheckMinionCollision(source, t.pos, delay, speed, radius)) then
                target = t
                aimPosition = t.pos
                return target, aimPosition
            end
        end
    end
end

function HPred:CacheTeleports()
    for i = 1, LocalGameTurretCount() do
        local turret = LocalGameTurret(i);
        if turret and turret.isEnemy and not _cachedTeleports[turret.networkID] then
            local hasBuff, expiresAt = self:HasBuff(turret, "teleport_target")
            if hasBuff then
                self:RecordTeleport(turret, self:GetTeleportOffset(turret.pos, 223.31), expiresAt)
            end
        end
    end
    for i = 1, LocalGameWardCount() do
        local ward = LocalGameWard(i);
        if ward and ward.isEnemy and not _cachedTeleports[ward.networkID] then
            local hasBuff, expiresAt = self:HasBuff(ward, "teleport_target")
            if hasBuff then
                self:RecordTeleport(ward, self:GetTeleportOffset(ward.pos, 100.01), expiresAt)
            end
        end
    end
    for i = 1, LocalGameMinionCount() do
        local minion = LocalGameMinion(i);
        if minion and minion.isEnemy and not _cachedTeleports[minion.networkID] then
            local hasBuff, expiresAt = self:HasBuff(minion, "teleport_target")
            if hasBuff then
                self:RecordTeleport(minion, self:GetTeleportOffset(minion.pos, 143.25), expiresAt)
            end
        end
    end
end

function HPred:RecordTeleport(target, aimPos, endTime)
    _cachedTeleports[target.networkID] = {}
    _cachedTeleports[target.networkID]["target"] = target
    _cachedTeleports[target.networkID]["aimPos"] = aimPos
    _cachedTeleports[target.networkID]["expireTime"] = endTime + LocalGameTimer()
end


function HPred:CalculateIncomingDamage()
    _incomingDamage = {}
    local currentTime = LocalGameTimer()
    for _, missile in _pairs(_cachedMissiles) do
        if missile then
            local dist = self:GetDistance(missile.data.pos, missile.target.pos)
            if missile.name == "" or currentTime >= missile.timeout or dist < missile.target.boundingRadius then
                _cachedMissiles[_] = nil
            else
                if not _incomingDamage[missile.target.networkID] then
                    _incomingDamage[missile.target.networkID] = missile.damage
                else
                    _incomingDamage[missile.target.networkID] = _incomingDamage[missile.target.networkID] + missile.damage
                end
            end
        end
    end
end

function HPred:GetIncomingDamage(target)
    local damage = 0
    if _incomingDamage[target.networkID] then
        damage = _incomingDamage[target.networkID]
    end
    return damage
end

local _maxCacheRange = 3000
function HPred:CacheParticles()
    if _windwall and _windwall.name == "" then
        _windwall = nil
    end
    
    for i = 1, LocalGameParticleCount() do
        local particle = LocalGameParticle(i)
        if particle and self:IsInRange(particle.pos, myHero.pos, _maxCacheRange) then
            if _find(particle.name, "W_windwall%d") and not _windwall then
                local owner = self:GetObjectByHandle(particle.handle)
                if owner and owner.isEnemy then
                    _windwall = particle
                    _windwallStartPos = Vector(particle.pos.x, particle.pos.y, particle.pos.z)
                    local index = _len(particle.name) - 5
                    local spellLevel = _sub(particle.name, index, index) - 1
                    if type(spellLevel) ~= "number" then
                        spellLevel = 1
                    end
                    _windwallWidth = 150 + spellLevel * 25
                end
            end
        end
    end
end

function HPred:CacheMissiles()
    local currentTime = LocalGameTimer()
    for i = 1, LocalGameMissileCount() do
        local missile = LocalGameMissile(i)
        if missile and not _cachedMissiles[missile.networkID] and missile.missileData then
            if missile.missileData.target and missile.missileData.owner then
                local missileName = missile.missileData.name
                local owner = self:GetObjectByHandle(missile.missileData.owner)
                local target = self:GetObjectByHandle(missile.missileData.target)
                if owner and target and _find(target.type, "Hero") then
                    if (_find(missileName, "BasicAttack") or _find(missileName, "CritAttack")) then
                        _cachedMissiles[missile.networkID] = {}
                        _cachedMissiles[missile.networkID].target = target
                        _cachedMissiles[missile.networkID].data = missile
                        _cachedMissiles[missile.networkID].danger = 1
                        _cachedMissiles[missile.networkID].timeout = currentTime + 1.5
                        local damage = owner.totalDamage
                        if _find(missileName, "CritAttack") then
                            damage = damage * 1.5
                        end
                        _cachedMissiles[missile.networkID].damage = self:CalculatePhysicalDamage(target, damage)
                    end
                end
            end
        end
    end
end

function HPred:CalculatePhysicalDamage(target, damage)
    local targetArmor = target.armor * myHero.armorPenPercent - myHero.armorPen
    local damageReduction = 100 / (100 + targetArmor)
    if targetArmor < 0 then
        damageReduction = 2 - (100 / (100 - targetArmor))
    end
    damage = damage * damageReduction
    return damage
end

function HPred:CalculateMagicDamage(target, damage)
    local targetMR = target.magicResist * myHero.magicPenPercent - myHero.magicPen
    local damageReduction = 100 / (100 + targetMR)
    if targetMR < 0 then
        damageReduction = 2 - (100 / (100 - targetMR))
    end
    damage = damage * damageReduction
    return damage
end


function HPred:GetTeleportingTarget(source, range, delay, speed, timingAccuracy, checkCollision, radius)
    local target
    local aimPosition
    for _, teleport in _pairs(_cachedTeleports) do
        if teleport.expireTime > LocalGameTimer() and self:IsInRange(source, teleport.aimPos, range) then
            local spellInterceptTime = self:GetSpellInterceptTime(source, teleport.aimPos, delay, speed)
            local teleportRemaining = teleport.expireTime - LocalGameTimer()
            if spellInterceptTime > teleportRemaining and spellInterceptTime - teleportRemaining <= timingAccuracy and (not checkCollision or not self:CheckMinionCollision(source, teleport.aimPos, delay, speed, radius)) then
                target = teleport.target
                aimPosition = teleport.aimPos
                return target, aimPosition
            end
        end
    end
end

function HPred:GetTargetMS(target)
    local ms = target.pathing.isDashing and target.pathing.dashSpeed or target.ms
    return ms
end

function HPred:Angle(A, B)
    local deltaPos = A - B
    local angle = _atan(deltaPos.x, deltaPos.z) * 180 / _pi
    if angle < 0 then angle = angle + 360 end
    return angle
end

function HPred:PredictUnitPosition(unit, delay)
    local predictedPosition = unit.pos
    local timeRemaining = delay
    local pathNodes = self:GetPathNodes(unit)
    for i = 1, #pathNodes - 1 do
        local nodeDistance = self:GetDistance(pathNodes[i], pathNodes[i + 1])
        local nodeTraversalTime = nodeDistance / self:GetTargetMS(unit)
        if timeRemaining > nodeTraversalTime then
            timeRemaining = timeRemaining - nodeTraversalTime
            predictedPosition = pathNodes[i + 1]
        else
            local directionVector = (pathNodes[i + 1] - pathNodes[i]):Normalized()
            predictedPosition = pathNodes[i] + directionVector * self:GetTargetMS(unit) * timeRemaining
            break;
        end
    end
    return predictedPosition
end

function HPred:IsChannelling(target, interceptTime)
    if target.activeSpell and target.activeSpell.valid and target.activeSpell.isChanneling then
        return true
    end
end

function HPred:HasBuff(target, buffName, minimumDuration)
    local duration = minimumDuration
    if not minimumDuration then
        duration = 0
    end
    local durationRemaining
    for i = 1, target.buffCount do
        local buff = target:GetBuff(i)
        if buff.duration > duration and buff.name == buffName then
            durationRemaining = buff.duration
            return true, durationRemaining
        end
    end
end

function HPred:GetTeleportOffset(origin, magnitude)
    local teleportOffset = origin + (self:GetEnemyNexusPosition() - origin):Normalized() * magnitude
    return teleportOffset
end

function HPred:GetSpellInterceptTime(startPos, endPos, delay, speed)
    local interceptTime = Game.Latency() / 2000 + delay + self:GetDistance(startPos, endPos) / speed
    return interceptTime
end

function HPred:CanTarget(target, allowInvisible)
    return target.isEnemy and target.alive and target.health > 0 and (allowInvisible or target.visible) and target.isTargetable
end

function HPred:CanTargetALL(target)
    return target.alive and target.health > 0 and target.visible and target.isTargetable
end

function HPred:UnitMovementBounds(unit, delay, reactionTime)
    local startPosition = self:PredictUnitPosition(unit, delay)
    local radius = 0
    local deltaDelay = delay - reactionTime - self:GetImmobileTime(unit)
    if (deltaDelay > 0) then
        radius = self:GetTargetMS(unit) * deltaDelay
    end
    return startPosition, radius
end

function HPred:GetImmobileTime(unit)
    local duration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i);
        if buff.count > 0 and buff.duration > duration and (buff.type == 5 or buff.type == 8 or buff.type == 21 or buff.type == 22 or buff.type == 24 or buff.type == 11 or buff.type == 29 or buff.type == 30 or buff.type == 39) then
            duration = buff.duration
        end
    end
    return duration
end

function HPred:isSlowed(unit, delay, speed, from)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i);
        if from and unit and buff.count > 0 and buff.duration >= (delay + GetDistance(unit.pos, from) / speed) then
            if (buff.type == 10) then
                return true
            end
        end
    end
    return false
end

function HPred:GetSlowedTime(unit)
    local duration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i);
        if buff.count > 0 and buff.duration > duration and buff.type == 10 then
            duration = buff.duration
            return duration
        end
    end
    return duration
end

function HPred:GetPathNodes(unit)
    local nodes = {}
    _insert(nodes, unit.pos)
    if unit.pathing.hasMovePath then
        for i = unit.pathing.pathIndex, unit.pathing.pathCount do
            path = unit:GetPath(i)
            _insert(nodes, path)
        end
    end
    return nodes
end

function HPred:GetObjectByHandle(handle)
    local target
    for i = 1, LocalGameHeroCount() do
        local enemy = LocalGameHero(i)
        if enemy and enemy.handle == handle then
            target = enemy
            return target
        end
    end
    for i = 1, LocalGameMinionCount() do
        local minion = LocalGameMinion(i)
        if minion and minion.handle == handle then
            target = minion
            return target
        end
    end
    for i = 1, LocalGameWardCount() do
        local ward = LocalGameWard(i);
        if ward and ward.handle == handle then
            target = ward
            return target
        end
    end
    for i = 1, LocalGameTurretCount() do
        local turret = LocalGameTurret(i)
        if turret and turret.handle == handle then
            target = turret
            return target
        end
    end
    for i = 1, LocalGameParticleCount() do
        local particle = LocalGameParticle(i)
        if particle and particle.handle == handle then
            target = particle
            return target
        end
    end
end

function HPred:GetHeroByPosition(position)
    local target
    for i = 1, LocalGameHeroCount() do
        local enemy = LocalGameHero(i)
        if enemy and enemy.pos.x == position.x and enemy.pos.y == position.y and enemy.pos.z == position.z then
            target = enemy
            return target
        end
    end
end

function HPred:GetObjectByPosition(position)
    local target
    for i = 1, LocalGameHeroCount() do
        local enemy = LocalGameHero(i)
        if enemy and enemy.pos.x == position.x and enemy.pos.y == position.y and enemy.pos.z == position.z then
            target = enemy
            return target
        end
    end
    for i = 1, LocalGameMinionCount() do
        local enemy = LocalGameMinion(i)
        if enemy and enemy.pos.x == position.x and enemy.pos.y == position.y and enemy.pos.z == position.z then
            target = enemy
            return target
        end
    end
    for i = 1, LocalGameWardCount() do
        local enemy = LocalGameWard(i);
        if enemy and enemy.pos.x == position.x and enemy.pos.y == position.y and enemy.pos.z == position.z then
            target = enemy
            return target
        end
    end
    for i = 1, LocalGameParticleCount() do
        local enemy = LocalGameParticle(i)
        if enemy and enemy.pos.x == position.x and enemy.pos.y == position.y and enemy.pos.z == position.z then
            target = enemy
            return target
        end
    end
end

function HPred:GetEnemyHeroByHandle(handle)
    local target
    for i = 1, LocalGameHeroCount() do
        local enemy = LocalGameHero(i)
        if enemy and enemy.handle == handle then
            target = enemy
            return target
        end
    end
end

function HPred:GetNearestParticleByNames(origin, names)
    local target
    local distance = 999999
    for i = 1, LocalGameParticleCount() do
        local particle = LocalGameParticle(i)
        if particle then
            local d = self:GetDistance(origin, particle.pos)
            if d < distance then
                distance = d
                target = particle
            end
        end
    end
    return target, distance
end

function HPred:GetPathLength(nodes)
    local result = 0
    for i = 1, #nodes - 1 do
        result = result + self:GetDistance(nodes[i], nodes[i + 1])
    end
    return result
end

function HPred:CheckMinionCollision(origin, endPos, delay, speed, radius, frequency)
    if not frequency then
        frequency = radius
    end
    local directionVector = (endPos - origin):Normalized()
    local checkCount = self:GetDistance(origin, endPos) / frequency
    for i = 1, checkCount do
        local checkPosition = origin + directionVector * i * frequency
        local checkDelay = delay + self:GetDistance(origin, checkPosition) / speed
        if self:IsMinionIntersection(checkPosition, radius, checkDelay, radius * 3) then
            return true
        end
    end
    return false
end

function HPred:IsMinionIntersection(location, radius, delay, maxDistance)
    if not maxDistance then
        maxDistance = 500
    end
    for i = 1, LocalGameMinionCount() do
        local minion = LocalGameMinion(i)
        if minion and self:CanTarget(minion) and self:IsInRange(minion.pos, location, maxDistance) then
            local predictedPosition = self:PredictUnitPosition(minion, delay)
            if self:IsInRange(location, predictedPosition, radius + minion.boundingRadius) then
                return true
            end
        end
    end
    return false
end

function HPred:VectorPointProjectionOnLineSegment(v1, v2, v)
    assert(v1 and v2 and v, "VectorPointProjectionOnLineSegment: wrong argument types (3 <Vector> expected)")
    local cx, cy, ax, ay, bx, by = v.x, (v.z or v.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y)
    local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) * (bx - ax) + (by - ay) * (by - ay))
    local pointLine = {x = ax + rL * (bx - ax), y = ay + rL * (by - ay)}
    local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
    local isOnSegment = rS == rL
    local pointSegment = isOnSegment and pointLine or {x = ax + rS * (bx - ax), y = ay + rS * (by - ay)}
    return pointSegment, pointLine, isOnSegment
end

function HPred:IsWindwallBlocking(source, target)
    if _windwall then
        local windwallFacing = (_windwallStartPos - _windwall.pos):Normalized()
        return self:DoLineSegmentsIntersect(source, target, _windwall.pos + windwallFacing:Perpendicular() * _windwallWidth, _windwall.pos + windwallFacing:Perpendicular2() * _windwallWidth)
    end
    return false
end

function HPred:DoLineSegmentsIntersect(A, B, C, D)
    local o1 = self:GetOrientation(A, B, C)
    local o2 = self:GetOrientation(A, B, D)
    local o3 = self:GetOrientation(C, D, A)
    local o4 = self:GetOrientation(C, D, B)
    if o1 ~= o2 and o3 ~= o4 then
        return true
    end
    if o1 == 0 and self:IsOnSegment(A, C, B) then return true end
    if o2 == 0 and self:IsOnSegment(A, D, B) then return true end
    if o3 == 0 and self:IsOnSegment(C, A, D) then return true end
    if o4 == 0 and self:IsOnSegment(C, B, D) then return true end
    
    return false
end

function HPred:GetOrientation(A, B, C)
    local val = (B.z - A.z) * (C.x - B.x) -
        (B.x - A.x) * (C.z - B.z)
    if val == 0 then
        return 0
    elseif val > 0 then
        return 1
    else
        return 2
    end

end

function HPred:IsOnSegment(A, B, C)
    return B.x <= _max(A.x, C.x) and
        B.x >= _min(A.x, C.x) and
        B.z <= _max(A.z, C.z) and
        B.z >= _min(A.z, C.z)
end

function HPred:GetSlope(A, B)
    return (B.z - A.z) / (B.x - A.x)
end

function HPred:GetEnemyByName(name)
    local target
    for i = 1, LocalGameHeroCount() do
        local enemy = LocalGameHero(i)
        if enemy and enemy.isEnemy and enemy.charName == name then
            target = enemy
            return target
        end
    end
end

function HPred:IsPointInArc(source, origin, target, angle, range)
    local deltaAngle = _abs(HPred:Angle(origin, target) - HPred:Angle(source, origin))
    if deltaAngle < angle and self:IsInRange(origin, target, range) then
        return true
    end
end

function HPred:GetDistanceSqr(p1, p2)
    if not p1 or not p2 then
        local dInfo = debug.getinfo(2)
        print("Undefined GetDistanceSqr target. Please report. Method: " .. dInfo.name .. "  Line: " .. dInfo.linedefined)
        return _huge
    end
    return (p1.x - p2.x) * (p1.x - p2.x) + ((p1.z or p1.y) - (p2.z or p2.y)) * ((p1.z or p1.y) - (p2.z or p2.y))
end

function HPred:IsInRange(p1, p2, range)
    if not p1 or not p2 then
        local dInfo = debug.getinfo(2)
        print("Undefined IsInRange target. Please report. Method: " .. dInfo.name .. "  Line: " .. dInfo.linedefined)
        return false
    end
    return (p1.x - p2.x) * (p1.x - p2.x) + ((p1.z or p1.y) - (p2.z or p2.y)) * ((p1.z or p1.y) - (p2.z or p2.y)) < range * range
end

function HPred:GetDistance(p1, p2)
    if not p1 or not p2 then
        local dInfo = debug.getinfo(2)
        _print("Undefined GetDistance target. Please report. Method: " .. dInfo.name .. "  Line: " .. dInfo.linedefined)
        return _huge
    end
    return _sqrt(self:GetDistanceSqr(p1, p2))
end
