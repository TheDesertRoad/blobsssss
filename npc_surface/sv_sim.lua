NPC_SURFACE = NPC_SURFACE or {}
local C = NPC_SURFACE

local sqrt, min, max, sin, cos, abs, floor, atan2 = math.sqrt, math.min, math.max, math.sin, math.cos, math.abs, math.floor, math.atan2
local pi = math.pi
local IsValid, CurTime = IsValid, CurTime
local Force = Vector()
local F2 = Vector()
local pcPos = Vector()

C.Managers = C.Managers or {}
C.Blobs = C.Blobs or {}

local lastHitT, lastHitN = 0, 0

function C.WaterHit(pos, spd, ent, floorHit)
    if !pos then return end
    spd = spd or 80
    if spd < 110 then return end
    if floorHit and spd < 140 then return end
    local now = CurTime()
    if IsValid(ent) then
        if (ent._splashT or 0) > now then return end
        ent._splashT = now + 0.9
        local mgr = ent.Surf
        if IsValid(mgr) then
            if (mgr._splashT or 0) > now then return end
            mgr._splashT = now + (floorHit and 1.1 or 0.75)
        end
    elseif now - lastHitT < 0.18 then
        lastHitN = lastHitN + 1
        if lastHitN > 1 then return end
    else
        lastHitT, lastHitN = now, 0
    end
    local vol = spd / 1100
    if vol > 0.38 then vol = 0.38 elseif vol < 0.12 then vol = 0.12 end
    local pitch = math.random(86, 114)
    if spd > 220 then
        sound.Play("ambient/water/water_splash"..math.random(1, 3)..".wav", pos, 68, pitch, vol)
    else
        sound.Play("player/footsteps/slosh"..math.random(1, 4)..".wav", pos, 60, pitch, vol)
    end
end

local function splash(pos)
    if !pos then return end
    C.WaterHit(pos, 140)
end

local function drip(pos)
    if !pos then return end
    sound.Play("ambient/water/drip"..math.random(1, 4)..".wav", pos, 60, math.random(95, 115), 0.32)
end

local function blobColor(e)
    if !IsValid(e) or !e.GetGelR then return nil end
    local r, g, b = e:GetGelR(), e:GetGelG(), e:GetGelB()
    if r == 0 and g == 0 and b == 0 then return nil end
    return { r = r, g = g, b = b }
end

function C.SpawnFlecks(pos, count, col, dir)
    if !pos then return end
    count = count or 3
    if count < 1 then return end
    C.FleckN = C.FleckN or 0
    if C.FleckN >= 40 then return end
    local C0 = NPC_SURFACE
    local base = math.Rand(0, pi * 2)
    local aimx, aimy, haveAim = 0, 0, false
    if isvector(dir) then
        local hl = sqrt(dir.x * dir.x + dir.y * dir.y)
        if hl > 0.15 then
            aimx, aimy, haveAim = dir.x / hl, dir.y / hl, true
            base = math.atan2(aimy, aimx)
        end
    end
    for i = 1, count do
        if C.FleckN >= 40 then break end
        local e = ents.Create("npc_surface_fleck")
        if IsValid(e) then
            local a
            if haveAim then
                a = base + math.Rand(-0.7, 0.7)
            else
                a = base + (i - 1) * (2 * pi / count) + math.Rand(-0.28, 0.28)
            end
            local spread = math.Rand(10, 26)
            local roll = math.Rand(0, 1)
            local spd, lift
            if roll < 0.34 then
                spd = math.Rand(22, 58)
                lift = math.Rand(12, 48)
            elseif roll < 0.72 then
                spd = math.Rand(70, 125)
                lift = math.Rand(36, 95)
            else
                spd = math.Rand(150, 240)
                lift = math.Rand(70, 185)
            end
            if haveAim then
                spd = spd * math.Rand(0.85, 1.25)
            end
            local dirx, diry = cos(a), sin(a)
            e:SetPos(pos + Vector(dirx * spread, diry * spread, 8 + math.Rand(0, 12)))
            e.LaunchVel = Vector(dirx * spd, diry * spd, lift)
            e.DragMul = math.Rand(0.35, 2.6)
            e.DampLin = math.Rand(0.04, 0.85)
            e:Spawn()
            e:Activate()
            e:SetSeed(math.Rand(0.3, 90))
            e._counted = true
            C.FleckN = C.FleckN + 1
            if col then
                e:SetGelR(col.r or C0.COL_R)
                e:SetGelG(col.g or C0.COL_G)
                e:SetGelB(col.b or C0.COL_B)
            end
        end
    end
end

function C.RegManager(ent)
    local t = C.Managers
    t[#t + 1] = ent
end

local function killBullseye(mgr)
    if !IsValid(mgr) then return end
    local b = mgr._bull
    mgr._bull = nil
    if IsValid(b) then
        b.Surf = nil
        b:Remove()
    end
end

function C.UnregManager(ent)
    killBullseye(ent)
    local t = C.Managers
    for i = 1, #t do
        if t[i] == ent then
            t[i] = t[#t]
            t[#t] = nil
            return
        end
    end
end

function C.RegBlob(ent)
    local t = C.Blobs
    t[#t + 1] = ent
end

function C.UnregBlob(ent)
    local t = C.Blobs
    for i = 1, #t do
        if t[i] == ent then
            t[i] = t[#t]
            t[#t] = nil
            return
        end
    end
end

local function prune(mgr)
    local src = mgr.Blobs
    if !src then
        mgr.Blobs = {}
        return 0
    end
    local n = 0
    for i = 1, #src do
        local b = src[i]
        if IsValid(b) then
            n = n + 1
            src[n] = b
        end
    end
    for i = n + 1, #src do
        src[i] = nil
    end
    return n
end

function C.MakeBlob(mgr, pos)
    if !(mgr and mgr.FreeSpawn) then
        if C.CanMakeBlob and !C.CanMakeBlob(pos) then return nil end
    end
    local e = ents.Create("npc_surface_blob")
    if !IsValid(e) then return nil end
    e:SetPos(pos)
    e.Surf = mgr
    e.IsGel = mgr.IsGel and true or false
    e:Spawn()
    e:Activate()
    local hp = C.ChunkHP and C.ChunkHP() or C.CHUNK_HP or 60
    e.SurfHP = hp
    e:SetHealth(hp)
    e:SetMaxHealth(hp)
    mgr.Blobs[#mgr.Blobs + 1] = e
    return e
end

function C.SpawnRing(mgr, n, radius)
    mgr.Blobs = mgr.Blobs or {}
    if !mgr.FreeSpawn then
        n = min(n, C.MAX)
    end
    local origin = mgr:GetPos()
    local golden = 2.399963229
    local R = C.RADIUS
    if mgr.IsGel then
        local restZ = R + 0.6
        for i = 1, n do
            local a = golden * (i - 1)
            local r = radius * sqrt((i - 0.35) / n)
            C.MakeBlob(mgr, origin + Vector(cos(a) * r, sin(a) * r, restZ))
        end
    else
        local rest = R * (C.REST or 1.68)
        local rad = rest * 0.58 * (n ^ (1 / 3))
        if rad < rest * 0.85 then
            rad = rest * 0.85
        end
        local ox, oy, oz = {}, {}, {}
        local minz = 1e9
        for i = 1, n do
            local y = 1 - (i - 0.5) / n * 2
            local rxy = sqrt(max(0, 1 - y * y))
            local th = golden * i
            ox[i] = cos(th) * rxy * rad
            oy[i] = sin(th) * rxy * rad
            oz[i] = y * rad
            if oz[i] < minz then
                minz = oz[i]
            end
            if n <= 8 then
                ox[i] = ox[i] + math.Rand(-R * 0.42, R * 0.42)
                oy[i] = oy[i] + math.Rand(-R * 0.42, R * 0.42)
            end
        end
        local lift = R + 0.8 - minz
        for i = 1, n do
            C.MakeBlob(mgr, origin + Vector(ox[i], oy[i], oz[i] + lift))
        end
    end
    local blobs = mgr.Blobs
    local total = #blobs
    for i = 1, total do
        C.PaintBlob(blobs[i], i, total)
    end
    splash(origin)
end

local hasNav, navReady = false, false
local function navok()
    if navReady then return hasNav end
    navReady = true
    hasNav = navmesh and #navmesh.GetAllNavAreas() > 0
    return hasNav
end

local function path2(from, to)
    local a = navmesh.GetNearestNavArea(from, false, 600, false, false)
    local b = navmesh.GetNearestNavArea(to, false, 600, false, false)
    if !a or !b then return nil end
    if a == b then
        return { b:GetClosestPointOnArea(to) }
    end
    local open = { a }
    local gscore, came, inopen, closed = {}, {}, {}, {}
    gscore[a:GetID()] = 0
    inopen[a:GetID()] = true
    local goal = b:GetID()
    local steps = 0
    while #open > 0 and steps < 80 do
        steps = steps + 1
        local bi, bf = 1, 1e12
        for i = 1, #open do
            local ar = open[i]
            local id = ar:GetID()
            local f = (gscore[id] or 1e12) + ar:GetCenter():DistToSqr(b:GetCenter())
            if f < bf then
                bf, bi = f, i
            end
        end
        local cur = open[bi]
        open[bi] = open[#open]
        open[#open] = nil
        local cid = cur:GetID()
        inopen[cid] = nil
        if cid == goal then
            local chain = { b:GetClosestPointOnArea(to) }
            local x = cur
            while came[x:GetID()] do
                x = came[x:GetID()]
                chain[#chain + 1] = x:GetCenter()
            end
            local out = {}
            for i = #chain, 1, -1 do
                out[#out + 1] = chain[i]
            end
            if #out > 1 then
                local t = {}
                for i = 2, #out do
                    t[#t + 1] = out[i]
                end
                return t
            end
            return out
        end
        closed[cid] = true
        local adj = cur:GetAdjacentAreas()
        for i = 1, #adj do
            local nb = adj[i]
            local id = nb:GetID()
            if closed[id] then continue end
            local cost = (gscore[cid] or 0) + cur:GetCenter():DistToSqr(nb:GetCenter())
            if !gscore[id] or cost < gscore[id] then
                gscore[id] = cost
                came[id] = cur
                if !inopen[id] then
                    open[#open + 1] = nb
                    inopen[id] = true
                end
            end
        end
    end
    return nil
end

local function followpath(mgr, cx, cy, cz, goal)
    if !navok() then return nil end
    local now = CurTime()
    local path = mgr._path
    local gp = mgr._pathGoal
    local dead = !path or #path < 1 or (mgr._pathI or 1) > #path
    local moved = !gp or (gp.x - goal.x) * (gp.x - goal.x) + (gp.y - goal.y) * (gp.y - goal.y) > 220 * 220
    local stuck = (mgr._stuckAt or 0) > 0 and now >= mgr._stuckAt
    local canRebuild = (mgr._pathT or 0) <= now
    if dead or ((moved or stuck) and canRebuild) then
        mgr._pathT = now + 1.25
        mgr._pathGoal = Vector(goal.x, goal.y, goal.z)
        mgr._path = path2(Vector(cx, cy, cz), goal)
        mgr._pathI = 1
        mgr._stuckAt = 0
        mgr._wpDist = 1e12
        path = mgr._path
        if path then
            while mgr._pathI <= #path do
                local p = path[mgr._pathI]
                local dx, dy = p.x - cx, p.y - cy
                if dx * dx + dy * dy > 72 * 72 then break end
                mgr._pathI = mgr._pathI + 1
            end
        end
    end
    path = mgr._path
    if !path or #path < 1 then return nil end
    while (mgr._pathI or 1) <= #path do
        local p = path[mgr._pathI]
        local dx, dy = p.x - cx, p.y - cy
        local d2 = dx * dx + dy * dy
        if d2 > 56 * 56 then
            if d2 + 80 < (mgr._wpDist or 1e12) then
                mgr._wpDist = d2
                mgr._stuckAt = now + 1.6
            elseif (mgr._stuckAt or 0) == 0 then
                mgr._stuckAt = now + 1.6
            end
            return p
        end
        mgr._pathI = (mgr._pathI or 1) + 1
        mgr._wpDist = 1e12
        mgr._stuckAt = 0
    end
    return goal
end

local function nearestPlayer(cx, cy, cz)
    if C.IgnorePlayers and C.IgnorePlayers() then
        return nil, 1e12
    end
    local best, bd = nil, 1e12
    local plys = player.GetAll()
    for i = 1, #plys do
        local p = plys[i]
        if IsValid(p) and p:Alive() then
            local w = p:WorldSpaceCenter()
            local dx, dy, dz = w.x - cx, w.y - cy, w.z - cz
            local d = dx * dx + dy * dy + dz * dz
            if d < bd then
                bd, best = d, p
            end
        end
    end
    return best, bd
end

local function isSurfaceEnt(e)
    if !IsValid(e) then return false end
    if e.IsSurfBullseye or e.IsSurfBlob then return true end
    local c = e:GetClass()
    return c == "npc_surface" or c == "npc_surface_cluster" or c == "npc_surface_blob" or c == "npc_surface_fleck" or c == "npc_bullseye"
end

local FEAR_CLS = {
    npc_citizen = true,
    npc_fisherman = true,
    npc_dog = true,
    npc_crow = true,
    npc_pigeon = true,
    npc_seagull = true,
    npc_barnacle = true,
}

local function bullDisp(npc)
    if !IsValid(npc) then return D_HT end
    local cls = npc:GetClass()
    if FEAR_CLS[cls] or FEAR_CLS[string.lower(cls)] then
        return D_FR
    end
    if npc.GetActiveWeapon and !IsValid(npc:GetActiveWeapon()) then
        if string.find(cls, "citizen", 1, true) then
            return D_FR
        end
    end
    return D_HT
end

local function ensureBullseye(mgr, cx, cy, cz, n)
    if !IsValid(mgr) or mgr.IsGel then
        killBullseye(mgr)
        return
    end
    local bull = mgr._bull
    if !IsValid(bull) then
        bull = ents.Create("npc_bullseye")
        if !IsValid(bull) then return end
        bull:SetPos(Vector(cx, cy, cz + 8))

        bull:SetKeyValue("spawnflags", "196608")
        bull:SetKeyValue("health", "99999")
        bull:SetName("npc_surface_bull_" .. mgr:EntIndex())
        bull:Spawn()
        bull:Activate()
        bull:SetNoDraw(true)
        bull:SetNotSolid(true)
        bull:SetCollisionGroup(COLLISION_GROUP_WORLD)
        bull:SetHealth(99999)
        bull.IsSurfBullseye = true
        bull.Surf = mgr
        mgr._bull = bull
    end
    local lift = 10 + min(28, n * 0.55)
    bull:SetPos(Vector(cx, cy, cz + lift))
    local now = CurTime()
    if (mgr._bullRelT or 0) > now then return end
    mgr._bullRelT = now + 0.65
    local found = ents.FindInSphere(Vector(cx, cy, cz), 1400)
    for i = 1, #found do
        local e = found[i]
        if IsValid(e) and e:IsNPC() and e ~= bull and !isSurfaceEnt(e) and !e._surfMeal then
            local disp = bullDisp(e)
            e:AddEntityRelationship(bull, disp, 88)
            if e.SetEnemy and disp == D_HT then
                local cur = e.GetEnemy and e:GetEnemy()
                if !IsValid(cur) or cur == bull then
                    e:SetEnemy(bull)
                    if e.UpdateEnemyMemory then
                        e:UpdateEnemyMemory(bull, bull:GetPos())
                    end
                end
            end
        end
    end
end

local function isMob(e)
    if !IsValid(e) or e:IsPlayer() or isSurfaceEnt(e) then return false end
    if e:Health() <= 0 then return false end
    if e:IsNPC() then return true end
    if e.IsNextBot and e:IsNextBot() then return true end
    return false
end

local SMALL_CLS = {
    npc_headcrab = true,
    npc_headcrab_fast = true,
    npc_headcrab_black = true,
    npc_headcrab_poison = true,
    npc_manhack = true,
    npc_crow = true,
    npc_pigeon = true,
    npc_seagull = true,
    npc_antlion_grub = true,
    npc_rollermine = true,
    npc_barnacle_tongue_tip = true,
    monster_headcrab = true,
    monster_babycrab = true,
    monster_snark = true,
}

local function isSmallPrey(e)
    if !isMob(e) then return false end
    local cls = e:GetClass()
    if SMALL_CLS[cls] or SMALL_CLS[string.lower(cls)] then return true end
    local mn, mx = e:GetCollisionBounds()
    local h = mx.z - mn.z
    local w = mx.x - mn.x
    local d = mx.y - mn.y
    if w < d then w = d end
    return h < 42 and w < 44
end

local function canEatProp(e)
    if !IsValid(e) or e:IsPlayer() or e:IsVehicle() or isSurfaceEnt(e) then return false end
    if e:IsNPC() or (e.IsNextBot and e:IsNextBot()) then return false end
    if e:IsPlayerHolding() or e._surfMeal or e._surfEaten or e.SurfTrap then return false end
    local cls = e:GetClass()
    if e:IsRagdoll() or cls == "prop_ragdoll" then return false end
    if e:GetMoveType() ~= MOVETYPE_VPHYSICS then return false end
    local ph = e:GetPhysicsObject()
    if !IsValid(ph) or !ph:IsMotionEnabled() then return false end
    local mass = ph:GetMass()
    if mass < 0.35 or mass > 24 then return false end
    local mn, mx = e:GetCollisionBounds()
    local sx, sy, sz = mx.x - mn.x, mx.y - mn.y, mx.z - mn.z
    local big = sx
    if sy > big then big = sy end
    if sz > big then big = sz end
    if big >= 42 then return false end
    if sx * sy * sz > 32000 then return false end
    return true
end

local function scanWorld(mgr, cx, cy, cz)
    local now = CurTime()
    if (mgr._scanT or 0) > now then return end
    mgr._scanT = now + 0.42
    local found = ents.FindInSphere(Vector(cx, cy, cz), 1050)
    local mb, md = nil, 1e12
    local sb, sd = nil, 1e12
    local trapped = mgr._trapped
    local snackOk = !(trapped and #trapped >= 4)
    for i = 1, #found do
        local e = found[i]
        if isMob(e) and !e._surfMeal then
            local w = e:WorldSpaceCenter()
            local dx, dy, dz = w.x - cx, w.y - cy, w.z - cz
            local d = dx * dx + dy * dy + dz * dz
            if d < md then
                md, mb = d, e
            end
        elseif snackOk and canEatProp(e) then
            local w = e:WorldSpaceCenter()
            local dx, dy, dz = w.x - cx, w.y - cy, w.z - cz
            local d = dx * dx + dy * dy + dz * dz
            if d < sd and d < 420 * 420 then
                sd, sb = d, e
            end
        end
    end
    mgr._mob, mgr._mobD = mb, md
    mgr._snack, mgr._snackD = sb, sd
end

local function liveMob(mgr, cx, cy, cz)
    local e = mgr._mob
    if !IsValid(e) or !isMob(e) or e._surfMeal then
        mgr._mob = nil
        return nil, 1e12
    end
    local w = e:WorldSpaceCenter()
    local dx, dy, dz = w.x - cx, w.y - cy, w.z - cz
    return e, dx * dx + dy * dy + dz * dz
end

local function liveSnack(mgr, cx, cy, cz)
    local e = mgr._snack
    if !IsValid(e) or !canEatProp(e) then
        mgr._snack = nil
        return nil, 1e12
    end
    local w = e:WorldSpaceCenter()
    local dx, dy, dz = w.x - cx, w.y - cy, w.z - cz
    return e, dx * dx + dy * dy + dz * dz
end

local function nearestPrey(mgr, cx, cy, cz)
    scanWorld(mgr, cx, cy, cz)
    local ply, pd = nearestPlayer(cx, cy, cz)
    local mob, md = liveMob(mgr, cx, cy, cz)
    local snack, sd = liveSnack(mgr, cx, cy, cz)

    if mob then
        if ply and pd + (60 * 60) < md and md > (380 * 380) then
            mgr._enemy = ply
            return ply, pd
        end
        mgr._enemy = mob
        return mob, md
    end
    if ply then
        mgr._enemy = ply
        return ply, pd
    end
    if snack and sd < (260 * 260) then
        mgr._enemy = snack
        return snack, sd
    end
    mgr._enemy = nil
    return nil, 1e12
end

local parent, rank, px, py, pz, vx, vy, vz, grounded, held, nopull, physA, entsA = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}

local function find(i)
    local p = parent[i]
    if p ~= i then
        p = find(p)
        parent[i] = p
    end
    return p
end

local function union(a, b)
    a, b = find(a), find(b)
    if a == b then return end
    if rank[a] < rank[b] then
        parent[a] = b
    elseif rank[a] > rank[b] then
        parent[b] = a
    else
        parent[b] = a
        rank[a] = rank[a] + 1
    end
end

local function collect(mgr)
    local src = mgr.Blobs
    local n = 0
    for i = 1, #src do
        local b = src[i]
        if IsValid(b) then
            local ph = b:GetPhysicsObject()
            if IsValid(ph) then
                n = n + 1
                entsA[n] = b
                local p = ph:GetPos()
                local v = ph:GetVelocity()
                px[n], py[n], pz[n] = p.x, p.y, p.z
                vx[n], vy[n], vz[n] = v.x, v.y, v.z
                physA[n] = ph
                parent[n], rank[n] = n, 0
                held[n] = b:IsPlayerHolding()
                nopull[n] = (b._noPullUntil or 0) > CurTime()
                grounded[n] = (b._groundedUntil or 0) > CurTime()
            end
        end
    end
    return n
end

local function centroid(n)
    if n < 1 then return 0, 0, 0 end
    local sx, sy, sz = 0, 0, 0
    for i = 1, n do
        sx, sy, sz = sx + px[i], sy + py[i], sz + pz[i]
    end
    local inv = 1 / n
    return sx * inv, sy * inv, sz * inv
end

local function probeFloor(cx, cy, cz, floorZ)
    local tr = util.TraceLine({
        start = Vector(cx, cy, floorZ + 8),
        endpos = Vector(cx, cy, floorZ - 96),
        mask = MASK_SOLID_BRUSHONLY
    })
    if tr.Hit and !tr.StartSolid then
        return tr
    end
    return util.TraceLine({
        start = Vector(cx, cy, cz + 10),
        endpos = Vector(cx, cy, cz - 240),
        mask = MASK_SOLID_BRUSHONLY
    })
end

local function onWorldFloor(n, cx, cy, cz, floorZ)
    if n < 1 then return false, floorZ end
    local tr = probeFloor(cx, cy, cz, floorZ)
    if tr.StartSolid or !tr.Hit then
        return false, floorZ
    end
    if tr.HitNormal and tr.HitNormal.z < 0.35 then
        return false, floorZ
    end
    local worldZ = tr.HitPos.z
    local gap = floorZ - worldZ
    return gap < (C.RADIUS + 16), worldZ
end

local function transfer(blob, dst)
    local src = blob.Surf
    if IsValid(src) and src.Blobs then
        local t = src.Blobs
        for i = 1, #t do
            if t[i] == blob then
                t[i] = t[#t]
                t[#t] = nil
                break
            end
        end
    end
    blob.Surf = dst
    blob.IsGel = dst.IsGel and true or false
    dst.Blobs[#dst.Blobs + 1] = blob
end

local function knockVel(kick, awayx, awayy)
    local kx, ky, kz = awayx or 0, awayy or 0, 0
    local spd = 0
    if isvector(kick) then
        local ls = kick.x * kick.x + kick.y * kick.y + kick.z * kick.z
        if ls > 16 then
            kx, ky, kz = kick.x, kick.y, kick.z
            spd = sqrt(ls)
        end
    end
    local h = sqrt(kx * kx + ky * ky)
    if h < 0.08 then
        kx, ky, h = 1, 0, 1
    else
        kx, ky = kx / h, ky / h
    end
    if spd < 1 then
        spd = 78
    elseif spd > 900 then
        spd = 118 + (spd - 900) * 0.004
    elseif spd > 220 then
        spd = 96 + (spd - 220) * 0.08
    end
    if spd < 62 then spd = 62 elseif spd > 175 then spd = 175 end
    local up = 14 + math.min(28, math.max(0, kz) * 0.012)
    return Vector(kx * spd, ky * spd, up)
end

local function knockVelSoft(kick, awayx, awayy)
    local v = knockVel(kick, awayx, awayy)
    v.x, v.y, v.z = v.x * 0.22, v.y * 0.22, min(8, v.z * 0.25)
    return v
end

local function splitByEnts(src, group, ng, gx, gy, gz, kick, mergeWait, gentle)
    if ng < 1 then return end
    local cls = src:GetClass()
    if ng <= 1 then
        cls = "npc_surface"
    elseif cls == "npc_surface" then
        cls = "npc_surface_cluster"
    end
    local e = ents.Create(cls)
    if !IsValid(e) then return end
    e:SetPos(Vector(gx, gy, gz))
    e.SkipSpawn = true
    e.IsGel = src.IsGel
    e:Spawn()
    e:Activate()
    e.Blobs = e.Blobs or {}
    for i = 1, ng do
        local b = group[i]
        if IsValid(b) then
            transfer(b, e)
        end
    end
    drip(Vector(gx, gy, gz))
    local ax, ay = gx - (src._cx or gx), gy - (src._cy or gy)
    local vel = gentle and knockVelSoft(kick, ax, ay) or knockVel(kick, ax, ay)
    C.SpawnFlecks(Vector(gx, gy, gz), gentle and math.random(4, 8) or math.random(8, 14), blobColor(group[1]), vel)
    local now = CurTime()
    mergeWait = mergeWait or (gentle and 4.2 or 2.2)
    e._noBubUntil = now + (gentle and 1.6 or 2.8)
    e._splitFrom = src
    e._noMergeUntil = math.max(e._noMergeUntil or 0, now + mergeWait)
    e._blastApartUntil = math.max(e._blastApartUntil or 0, now + mergeWait)
    src._blastApartUntil = math.max(src._blastApartUntil or 0, now + mergeWait)
    src._noMergeUntil = math.max(src._noMergeUntil or 0, now + mergeWait)
    e._noSplitUntil = math.max(e._noSplitUntil or 0, now + (gentle and 5.5 or 2.4))
    src._noSplitUntil = math.max(src._noSplitUntil or 0, now + (gentle and 5.5 or 2.4))
    e._kickUntil = gentle and 0 or now + 0.85
    e._airUntil = now + (gentle and 0.18 or 0.55)
    src._airUntil = math.max(src._airUntil or 0, now + (gentle and 0.08 or 0.2))
    local hold = gentle and 0.28 or min(mergeWait, 1.8)
    for i = 1, ng do
        local b = group[i]
        if IsValid(b) then
            local bp = b:GetPhysicsObject()
            if IsValid(bp) then
                bp:EnableGravity(true)
                b._gravOn = true
                bp:SetDamping(gentle and 1.6 or 0.45, gentle and 2.0 or 0.7)
                bp:Wake()
                bp:SetVelocity(vel + Vector(math.Rand(-18, 18), math.Rand(-18, 18), math.Rand(0, 12)))
            end
            b._noPullUntil = now + hold
            b._groundedUntil = 0
            b._wallUntil = 0
        end
    end
    return e
end

local function shotgunScatter(mgr, origin, force)
    if !IsValid(mgr) or !mgr.Blobs then return end
    local blobs = mgr.Blobs
    local list, n = {}, 0
    for i = 1, #blobs do
        local b = blobs[i]
        if IsValid(b) and !b:IsPlayerHolding() then
            n = n + 1
            list[n] = b
        end
    end
    if n < 3 then return end
    local rPick = C.RADIUS * 4.2
    local r2 = rPick * rPick
    local near = {}
    for i = 1, n do
        local p = list[i]:GetPos()
        local dx, dy, dz = p.x - origin.x, p.y - origin.y, p.z - origin.z
        local d2 = dx * dx + dy * dy + dz * dz
        if d2 <= r2 then
            near[#near + 1] = { e = list[i], d = d2 }
        end
    end
    if #near < 1 then
        local best, bd = list[1], 1e12
        for i = 1, n do
            local p = list[i]:GetPos()
            local dx, dy, dz = p.x - origin.x, p.y - origin.y, p.z - origin.z
            local d2 = dx * dx + dy * dy + dz * dz
            if d2 < bd then
                bd, best = d2, list[i]
            end
        end
        near[1] = { e = best, d = bd }
    end
    for a = 1, #near do
        for b = a + 1, #near do
            if near[a].d > near[b].d then
                near[a], near[b] = near[b], near[a]
            end
        end
    end
    local take = min(5, #near)
    if n - take < 3 then
        take = max(1, n - 3)
    end
    if take < 1 then return end
    local fx, fy = 0, 1
    if isvector(force) then
        local hl = sqrt(force.x * force.x + force.y * force.y)
        if hl > 0.08 then
            fx, fy = force.x / hl, force.y / hl
        end
    end
    local rx, ry = -fy, fx
    local now = CurTime()
    mgr._blastApartUntil = math.max(mgr._blastApartUntil or 0, now + 1.6)
    mgr._noMergeUntil = math.max(mgr._noMergeUntil or 0, now + 1.6)
    mgr._noBubUntil = now + 1.2
    mgr._airUntil = math.max(mgr._airUntil or 0, now + 0.35)
    mgr._dmgKick = Vector(fx * 160, fy * 160, 20)
    mgr._dmgKickT = now + 0.35
    splash(origin)
    for i = 1, take do
        local b = near[i].e
        if !IsValid(b) then continue end
        local p = b:GetPos()
        local t = (i - 0.5) / take - 0.5
        local side = t * 2.4
        local fwd = 0.55 + math.Rand(0.15, 0.55)
        local kx = fx * fwd + rx * side + math.Rand(-0.22, 0.22)
        local ky = fy * fwd + ry * side + math.Rand(-0.22, 0.22)
        local kl = sqrt(kx * kx + ky * ky)
        if kl < 0.08 then
            kx, ky = fx, fy
            kl = 1
        else
            kx, ky = kx / kl, ky / kl
        end
        local spd = math.Rand(95, 140)
        local lift = math.Rand(16, 32)
        local kick = Vector(kx * spd, ky * spd, lift)
        local baby = splitByEnts(mgr, { b }, 1, p.x, p.y, p.z, kick, 2.4, false)
        if IsValid(baby) and baby.Blobs then
            local chunk = baby.Blobs[1]
            if IsValid(chunk) then
                local bp = chunk:GetPhysicsObject()
                if IsValid(bp) then
                    bp:EnableGravity(true)
                    chunk._gravOn = true
                    bp:SetDamping(1.1, 1.4)
                    bp:Wake()
                    bp:SetVelocity(kick)
                end
                chunk._noPullUntil = now + 1.35
            end
            baby._kickUntil = now + 0.45
            baby._airUntil = now + 0.18
        end
    end
    C.SpawnFlecks(origin, math.random(8, 14), blobColor(near[1].e), Vector(fx * 90, fy * 90, 40))
end

local function absorb(big, small)
    local sb = small.Blobs
    if !sb then
        small:Remove()
        return
    end
    local bigN = prune(big)
    local cap = C.MAX - bigN
    local moved = 0
    for i = 1, #sb do
        local b = sb[i]
        if IsValid(b) then
            if moved < cap then
                transfer(b, big)
                moved = moved + 1
                local ph = b:GetPhysicsObject()
                if IsValid(ph) and !big.IsGel then
                    ph:EnableGravity(true)
                    ph:SetDamping(2.6, 3.2)
                end
            end
        end
    end
    if bigN < 10 then
        big._noMergeUntil = math.max(big._noMergeUntil or 0, small._noMergeUntil or 0)
        if !IsValid(big._splitFrom) then
            big._splitFrom = small._splitFrom
        end
    end
    splash(big:GetPos())
    C.SpawnFlecks(big:GetPos(), math.random(8, 14), blobColor(sb[1]) or blobColor(big.Blobs and big.Blobs[1]), small:GetPos() - big:GetPos())
    big._airUntil = 0
    big._pounceEnd = 0
    if prune(small) < 1 then
        small.Blobs = {}
        small:Remove()
    end
end

local tmpG = {}
local tmpC = {}
local tmpN = {}
local tmpE = {}

local function trySplit(mgr, n, cx, cy, cz)
    if mgr.IsGel or n < 2 then return end
    if (mgr._noSplitUntil or 0) > CurTime() then return end
    local R = C.RADIUS
    local link = R * 4.7
    local link2 = link * link
    for i = 1, n do
        for j = i + 1, n do
            local dx, dy, dz = px[i] - px[j], py[i] - py[j], pz[i] - pz[j]
            if dx * dx + dy * dy + dz * dz <= link2 then
                union(i, j)
            end
        end
    end
    for i = 1, n do
        tmpN[i] = 0
        tmpC[i] = 0
    end
    local roots = 0
    for i = 1, n do
        local r = find(i)
        tmpN[r] = tmpN[r] + 1
        if tmpC[r] == 0 then
            roots = roots + 1
            tmpC[r] = 1
        end
    end
    if roots < 2 then
        mgr._splitT = nil
        return
    end
    local main, mn = 1, 0
    for i = 1, n do
        if tmpN[i] > mn then
            mn, main = tmpN[i], i
        end
    end
    local mx, my, mz, mc = 0, 0, 0, 0
    for i = 1, n do
        if find(i) == main then
            mx, my, mz, mc = mx + px[i], my + py[i], mz + pz[i], mc + 1
        end
    end
    if mc < 1 then return end
    mx, my, mz = mx / mc, my / mc, mz / mc
    local far = C.SPLIT_MUL * R
    local far2 = far * far
    mgr._splitT = mgr._splitT or {}
    local timers = mgr._splitT
    local seen = tmpG
    for i = 1, n do
        seen[i] = false
    end
    local now = CurTime()
    if !mgr.IsGel then
        for i = 1, n do
            local b = entsA[i]
            if IsValid(b) then
                if (b._spdT or 0) < now then
                    b._spdT = now + math.Rand(0.45, 1.35)
                    if math.Rand(0, 1) < 0.32 then
                        b._spdWant = math.Rand(0.52, 1.48)
                    else
                        b._spdWant = math.Rand(0.72, 1.28)
                    end
                end
                local cur = b.SpeedMul or 1
                b.SpeedMul = cur + ((b._spdWant or 1) - cur) * 0.24
            end
        end
    end
    for i = 1, n do
        local r = find(i)
        if r ~= main and !seen[r] then
            seen[r] = true
            local sx, sy, sz, sc = 0, 0, 0, 0
            local anyHold = false
            local ng = 0
            for j = 1, n do
                if find(j) == r then
                    sx, sy, sz, sc = sx + px[j], sy + py[j], sz + pz[j], sc + 1
                    ng = ng + 1
                    tmpE[ng] = entsA[j]
                    if held[j] then anyHold = true end
                end
            end
            sx, sy, sz = sx / sc, sy / sc, sz / sc
            local dx, dy, dz = sx - mx, sy - my, sz - mz
            local d2 = dx * dx + dy * dy + dz * dz
            local key = 1e9
            for k = 1, ng do
                if IsValid(tmpE[k]) then
                    local id = tmpE[k]:EntIndex()
                    if id < key then key = id end
                end
            end
            if d2 >= far2 then
                local keep = n - sc
                local minHalf = 3
                if n >= 10 then
                    minHalf = max(4, floor(n * 0.22 + 0.5))
                end
                if sc < minHalf or keep < minHalf then
                    timers[key] = nil
                    continue
                end
                timers[key] = timers[key] or now
                local wait = (anyHold or sc <= 4) and (C.SPLIT_T + 0.7) or C.SPLIT_T
                if n < 10 then
                    wait = wait + 0.8
                end
                if now - timers[key] >= wait then
                    local g = {}
                    for k = 1, ng do
                        g[k] = tmpE[k]
                    end
                    timers[key] = nil
                    local kick
                    if (mgr._dmgKickT or 0) > now then
                        kick = mgr._dmgKick
                    else
                        for k = 1, ng do
                            local b = g[k]
                            if IsValid(b) and (b._hitKickT or 0) > now then
                                kick = b._hitKick
                                break
                            end
                        end
                    end
                    splitByEnts(mgr, g, ng, sx, sy, sz, kick, 4.2, true)
                    return
                end
            else
                timers[key] = nil
            end
        end
    end
end

local function parentBlocked(a, b, now)
    if !IsValid(a) or !IsValid(b) then return true end
    if (a._blastApartUntil or 0) > now or (b._blastApartUntil or 0) > now then return true end
    if a._splitFrom == b and (a._noMergeUntil or 0) > now then return true end
    if b._splitFrom == a and (b._noMergeUntil or 0) > now then return true end
    return false
end

local function tryMerge(mgr, n, cx, cy, cz)
    if n < 1 then return end
    splash(origin)
    local now = CurTime()
    if (mgr._blastApartUntil or 0) > now then return end
    if (mgr._mergeT or 0) > now then return end
    mgr._mergeT = now + 0.14
    local R = C.RADIUS
    local list = C.Managers
    for i = 1, #list do
        local o = list[i]
        if o ~= mgr and IsValid(o) and o.IsGel == mgr.IsGel and !parentBlocked(mgr, o, now) then
            local on = o._n or prune(o)
            if on < 1 then
                o:Remove()
            else
                local tiny = n < 10 and on < 10
                local eitherTiny = n < 10 or on < 10
                local centR = tiny and (R * 8.4) or (eitherTiny and (R * 5.6) or (R * 3.4))
                local closeR = tiny and (R * 5.8) or (eitherTiny and (R * 4.2) or (R * 2.6))
                local cent2 = centR * centR
                local close2 = closeR * closeR
                local ocx, ocy, ocz = o._cx or 0, o._cy or 0, o._cz or 0
                local dx, dy, dz = cx - ocx, cy - ocy, cz - ocz
                local near = dx * dx + dy * dy + dz * dz < cent2
                if !near then
                    local ob = o.Blobs
                    if ob then
                        for a = 1, n do
                            for b = 1, #ob do
                                local e = ob[b]
                                if IsValid(e) then
                                    local p = e:GetPos()
                                    local ex, ey, ez = px[a] - p.x, py[a] - p.y, pz[a] - p.z
                                    if ex * ex + ey * ey + ez * ez < close2 then
                                        near = true
                                        break
                                    end
                                end
                            end
                            if near then break end
                        end
                    end
                end
                if near then
                    if n >= on then
                        absorb(mgr, o)
                        return
                    else
                        absorb(o, mgr)
                        return
                    end
                end
            end
        end
    end
end

local function pullTinyPeers(mgr, n, cx, cy, cz)
    if n >= 10 or mgr.IsGel then return end
    local now = CurTime()
    if (mgr._blastApartUntil or 0) > now then return end
    local list = C.Managers
    local reach = C.RADIUS * 13
    local reach2 = reach * reach
    local fx, fy = 0, 0
    for i = 1, #list do
        local o = list[i]
        if o ~= mgr and IsValid(o) and !o.IsGel and (o._blastApartUntil or 0) <= now then
            local on = o._n or 0
            if on > 0 and on < 10 then
                local dx = (o._cx or 0) - cx
                local dy = (o._cy or 0) - cy
                local d2 = dx * dx + dy * dy
                if d2 < reach2 and d2 > 16 then
                    local d = sqrt(d2)
                    local w = (1 - d / reach) * 48
                    fx = fx + dx / d * w
                    fy = fy + dy / d * w
                end
            end
        end
    end
    if fx == 0 and fy == 0 then return end
    local mass = C.MASS
    for i = 1, n do
        local ph = physA[i]
        if IsValid(ph) and !held[i] then
            Force.x = fx * mass
            Force.y = fy * mass
            Force.z = 0
            ph:ApplyForceCenter(Force)
        end
    end
end

local function steerMove(mgr, hx, hy, want, cap, hopping, n)
    local dt = FrameTime()
    if dt < 0.008 then dt = 0.015 elseif dt > 0.05 then dt = 0.05 end
    local mx, my = mgr._mx, mgr._my
    if mx == nil then
        mx, my = hx, hy
        mgr._msp = 0
    end
    local ml = sqrt(mx * mx + my * my)
    if ml > 0.08 then
        mx, my = mx / ml, my / ml
    else
        mx, my = hx, hy
        ml = sqrt(mx * mx + my * my)
        if ml > 0.08 then
            mx, my = mx / ml, my / ml
        else
            mx, my = 0, 1
        end
    end
    if hopping then
        mgr._mx, mgr._my = mx, my
        local msp = mgr._msp or 0
        if msp < want * 0.5 then
            msp = want * 0.5
        end
        mgr._msp = msp
        return mx, my, msp
    end
    local wl = sqrt(hx * hx + hy * hy)
    local wx, wy = mx, my
    local aim = want
    if wl > 0.08 then
        wx, wy = hx / wl, hy / wl
    else
        aim = 0
    end
    if aim > cap then aim = cap end
    local now = CurTime()
    local gait = (mgr._gait or 0) + dt * (n <= 2 and 2.05 or 2.55)
    mgr._gait = gait
    if (mgr._surgeT or 0) < now then
        mgr._surgeT = now + math.Rand(0.35, 1.05)
        mgr._surgeWant = math.Rand(0.88, 1.14)
    end
    local surge = mgr._surge or 1
    surge = surge + ((mgr._surgeWant or 1) - surge) * min(1, 3.2 * dt)
    mgr._surge = surge
    local beat = 0.94 + 0.07 * sin(gait) + 0.05 * sin(gait * 2.17 + 1.1)
    local live = beat * surge
    if live < 0.82 then live = 0.82 elseif live > 1.18 then live = 1.18 end
    local msp = mgr._msp or 0
    local dang = atan2(mx * wy - my * wx, mx * wx + my * wy)
    local adang = abs(dang)
    local baseTurn = n <= 2 and 3.6 or 4.4
    local turn = baseTurn * max(0.42, 1.25 / (1 + msp * 0.022))
    if adang > 1.05 then
        turn = turn * 1.12
    end
    local maxA = turn * dt
    local step = dang
    if step > maxA then step = maxA elseif step < -maxA then step = -maxA end
    local ca, sa = cos(step), sin(step)
    local nx, ny = mx * ca - my * sa, mx * sa + my * ca
    local blend = min(1, (1.6 + turn * 0.28) * dt)
    nx = nx + (wx - nx) * blend
    ny = ny + (wy - ny) * blend
    local nl = sqrt(nx * nx + ny * ny)
    if nl > 0.08 then
        mx, my = nx / nl, ny / nl
    end
    local wob = 0.025 * sin(gait * 0.71 + 0.5) * dt
    local ox, oy = mx, my
    mx, my = ox - oy * wob, oy + ox * wob
    nl = sqrt(mx * mx + my * my)
    if nl > 0.08 then
        mx, my = mx / nl, my / nl
    end
    local align = mx * wx + my * wy
    local cruise = 0.52 + 0.48 * (align * 0.5 + 0.5)
    if cruise < 0.52 then cruise = 0.52 elseif cruise > 1 then cruise = 1 end
    local accel = n <= 2 and 52 or 88
    local brake = n <= 2 and 38 or 58
    local target = aim * live * cruise
    if aim < 4 then
        target = cap * 0.12 * live
    end
    local err = target - msp
    if err > 0 then
        local stepSpd = accel * dt * (0.55 + 0.45 * max(0, align))
        msp = msp + min(err, stepSpd)
    else
        local cut = brake * dt
        if align < 0.35 then
            cut = cut + (0.35 - align) * 28 * dt
        end
        msp = msp - cut
        if msp < target then msp = target end
    end
    if msp > 6 then
        msp = msp + sin(gait * 3.05 + 0.3) * (n <= 2 and 6 or 10) * dt
    end
    if msp < 0 then msp = 0 end
    local ceil = cap * (0.97 + 0.06 * live)
    if msp > ceil then msp = ceil end
    mgr._mx, mgr._my, mgr._msp = mx, my, msp
    mgr._lx, mgr._ly = mx, my
    return mx, my, msp
end

local function simForces(mgr, n, cx, cy, cz, chase, hx, hy, speed, restMul, onGround)
    local R = C.RADIUS
    local interact = R * C.INTERACT * (restMul or 1)
    local interact2 = interact * interact
    local gel = mgr.IsGel
    local sinA = C.SIN
    local str2 = C.STRAGGLE * C.STRAGGLE
    local now = CurTime()
    local mass = C.MASS
    local hopping = (mgr._pounceEnd or 0) > now
    local kVel = (!gel and (onGround or hopping)) and 0.92 or 0
    local maxSpd = (C.Speed and C.Speed() or C.SPEED) * 1.46
    local rest = R * (C.REST or 1.68)
    local spring = C.SPRING or 24
    if chase then
        maxSpd = maxSpd * 1.08
    end
    if n <= 2 then
        maxSpd = (C.Speed and C.Speed() or C.SPEED) * 0.52
        if chase then
            maxSpd = maxSpd * 1.08
        end
        kVel = (!gel and (onGround or hopping)) and 0.38 or 0
    end
    local floorZ = mgr._floorZ or (cz - rest)
    local gCut = floorZ + rest * 0.55
    local hard = R * 2
    local hard2 = hard * hard
    local hdx, hdy = hx - cx, hy - cy
    local hl = sqrt(hdx * hdx + hdy * hdy)
    local headx, heady = 0, 0
    if hl > 1 then
        headx, heady = hdx / hl, hdy / hl
    end
    local gox, goy, goSpd = headx, heady, speed
    if !gel and (onGround or hopping) then
        local aim = speed
        if aim > maxSpd then aim = maxSpd end
        gox, goy, goSpd = steerMove(mgr, headx, heady, aim, maxSpd, hopping, n)
    end
    local rolling = !gel and onGround and n >= 8 and speed > 12
    for i = 1, n do
        if held[i] then
            goto cont
        end
        local ph = physA[i]
        if !IsValid(ph) then
            goto cont
        end
        local tiny = n < 10
        local bHit = entsA[i]
        local onW = IsValid(bHit) and (bHit._wallUntil or 0) > now
        local ix, iy, iz = px[i], py[i], pz[i]
        local along = (ix - cx) * headx + (iy - cy) * heady
        local tumble = 0
        if rolling then
            tumble = along / (rest * 1.45)
            if tumble > 1 then tumble = 1 elseif tumble < -1 then tumble = -1 end
        end
        if !gel then
            local wantG = true
            if !tiny and onGround and iz <= (mgr._worldZ or floorZ) + R * 1.35 then
                wantG = false
            end
            if iz > (mgr._worldZ or floorZ) + R * 1.15 then
                wantG = true
            end
            if bHit._gravOn ~= wantG then
                bHit._gravOn = wantG
                ph:EnableGravity(wantG)
            end
            local wantL, wantA
            if onW then
                wantL, wantA = 1.6, 2.0
            elseif tiny then
                if (mgr._kickUntil or 0) > now then
                    wantL, wantA = 0.85, 1.1
                else
                    wantL, wantA = 1.7, 2.2
                end
            else
                wantL, wantA = 0.85, 1.1
            end
            if bHit._dampLin ~= wantL then
                bHit._dampLin = wantL
                ph:SetDamping(wantL, wantA)
            end
        end
        local fx, fy, fz = 0, 0, 0
        if !gel then
            local arm = (!tiny) and mgr._reachRank and (mgr._reachRank[i] or 0) > 0
            local support = 0
            for j = 1, n do
                if i ~= j then
                    local dx, dy, dz = px[j] - ix, py[j] - iy, pz[j] - iz
                    local d2 = dx * dx + dy * dy + dz * dz
                    if d2 < interact2 and d2 > 0.01 then
                        local dist = sqrt(d2)
                        if d2 < hard2 then
                            local invd = 1 / dist
                            local nx, ny, nz = dx * invd, dy * invd, dz * invd
                            local pen = hard - dist
                            local sep = pen * mass * 11
                            fx = fx - nx * sep
                            fy = fy - ny * sep
                            fz = fz - nz * sep
                            local close = (vx[i] - vx[j]) * nx + (vy[i] - vy[j]) * ny + (vz[i] - vz[j]) * nz
                            if close > 0 then
                                fx = fx - nx * close * mass * 0.45
                                fy = fy - ny * close * mass * 0.45
                                fz = fz - nz * close * mass * 0.45
                            end
                        end
                        if !nopull[i] and !held[j] then
                            local mag = (dist - rest) / rest * spring
                            if mag > 18 then mag = 18 elseif mag < -28 then mag = -28 end
                            if mag > 0 and arm then
                                mag = mag * 0.55
                            end
                            if tumble < 0 and mag < 0 then
                                mag = mag * 0.5
                            end
                            mag = mag * mass
                            local inv = mag / dist
                            fx = fx + dx * inv
                            fy = fy + dy * inv
                            fz = fz + dz * inv
                            local dxy2 = dx * dx + dy * dy
                            if onGround and dz < -6 and dxy2 < rest * rest then
                                local want = pz[j] + rest * 0.88
                                support = support + (want - iz)
                            end
                        elseif held[j] and d2 < (R * 1.8) * (R * 1.8) then
                            local push = (1 - dist / (R * 1.8)) * mass * 10
                            local inv = push / dist
                            fx = fx - dx * inv
                            fy = fy - dy * inv
                            fz = fz - dz * inv
                        end
                    end
                end
            end
            if support ~= 0 then
                if tiny then
                    if support > 10 then support = 10 elseif support < -8 then support = -8 end
                    fz = fz + support * mass * 1.2
                else
                    if support > 22 then support = 22 elseif support < -16 then support = -16 end
                    fz = fz + support * mass * 2.8
                end
            end
            if !nopull[i] then
                if arm then
                    fx = fx + (cx - ix) * 8
                    fy = fy + (cy - iy) * 8
                else
                    local pullC = 10
                    if mgr._coat then
                        pullC = 2.5
                    elseif rolling then
                        if tumble > 0 then
                            pullC = 13
                        else
                            pullC = 7
                        end
                    elseif chase and along < 0 then
                        pullC = 3.5
                    end
                    fx = fx + (cx - ix) * pullC
                    fy = fy + (cy - iy) * pullC
                    if onGround and !hopping and !mgr._coat then
                        local zPull = onW and 8 or 18
                        if tiny then zPull = onW and 4 or 7 end
                        fz = fz + (cz - iz) * zPull
                        local dx, dy, dz = ix - cx, iy - cy, iz - cz
                        if dx * dx + dy * dy + dz * dz > str2 then
                            fx = fx + (cx - ix) * 14
                            fy = fy + (cy - iy) * 14
                            if !tiny then
                                fz = fz + (cz - iz) * 14
                            end
                        end
                    end
                end
            end
            if onW then
                local nx = bHit._hitNx or 0
                local ny = bHit._hitNy or 0
                local nz = bHit._hitNz or 0
                fx = fx - nx * mass * 46
                fy = fy - ny * mass * 46
                fz = fz - nz * mass * 46
                local lx, ly, lz = ix - cx, iy - cy, iz - cz
                local d2 = lx * lx + ly * ly + lz * lz
                local maxD = rest * 2.2
                if d2 > maxD * maxD then
                    local d = sqrt(d2)
                    local pull = mass * 20 / d
                    fx = fx - lx * pull
                    fy = fy - ly * pull
                    fz = fz - lz * pull
                end
            end
            if (bHit._pcT or 0) < now then
                bHit._pcT = now + 0.15
                pcPos.x, pcPos.y, pcPos.z = ix, iy, iz
                bHit._pcGrate = bit.band(util.PointContents(pcPos), CONTENTS_GRATE) ~= 0
            end
            if bHit._pcGrate then
                local lx, ly = mgr._lx or headx, mgr._ly or heady
                fx = fx + lx * mass * 42
                fy = fy + ly * mass * 42
            end
            if onGround and !arm and iz <= gCut then
                fz = fz - mass * (C.GRAV or 120)
            end
        else
            for j = 1, n do
                if i ~= j then
                    local dx, dy, dz = px[j] - ix, py[j] - iy, pz[j] - iz
                    local d2 = dx * dx + dy * dy + dz * dz
                    local min2 = (R * 1.65) * (R * 1.65)
                    if d2 < min2 and d2 > 0.01 then
                        local dist = sqrt(d2)
                        local push = (1 - dist / (R * 1.65)) * mass * 12
                        local inv = push / dist
                        fx = fx - dx * inv
                        fy = fy - dy * inv
                        fz = fz - dz * inv
                    end
                end
            end
        end
        if !gel and !nopull[i] and onGround then
            local rank = mgr._reachRank and mgr._reachRank[i] or 0
            local nArm = mgr._nArm or 0
            if rank > 0 and mgr._reach and nArm > 0 and n >= 10 then
                local t = rank / nArm
                local h = mgr._reachH or rest
                local wantX = cx + (mgr._rdx or 0) * 7 * t
                local wantY = cy + (mgr._rdy or 0) * 7 * t
                local worldZ = mgr._worldZ or (floorZ - R)
                local wantZ = worldZ + R + rest * 0.25 + h * t * 0.55
                local lx, ly, lz = ix - cx, iy - cy, iz - (floorZ + rest)
                local d2 = lx * lx + ly * ly + lz * lz
                local maxD = h + rest * 0.85
                if d2 > maxD * maxD then
                    local d = sqrt(d2)
                    local pull = mass * 18 / d
                    fx = fx - lx * pull
                    fy = fy - ly * pull
                else
                    local vxw = (wantX - ix) * 1.25
                    local vyw = (wantY - iy) * 1.25
                    local vzw = (wantZ - iz) * 1.25
                    local spd = sqrt(vxw * vxw + vyw * vyw + vzw * vzw)
                    if spd > 8 then
                        local s = 8 / spd
                        vxw, vyw, vzw = vxw * s, vyw * s, vzw * s
                    end
                    fx = fx + (vxw - vx[i]) * mass * 0.95
                    fy = fy + (vyw - vy[i]) * mass * 0.95
                end
            else
                local b = entsA[i]
                local mul = (IsValid(b) and b.SpeedMul) or 1
                local idleMul = chase and 1 or (C.IDLE_CRAWL * ((IsValid(b) and b.Rnd80) or 1))
                local sp = goSpd * mul * idleMul
                if sp > maxSpd then sp = maxSpd end
                local lx, ly = mgr._lx or gox, mgr._ly or goy
                sp = sp * (1 - tumble * 0.4)
                if sp < speed * 0.38 then sp = speed * 0.38 end
                sp = sp * (1 + 0.1 * sin(now * 1.55 + along * 0.05 + i * 0.4))
                local dx, dy, dzv = gox * sp, goy * sp, 0
                if tumble < 0 then
                    local u = -tumble
                    dx = dx + lx * sp * 0.42 * u
                    dy = dy + ly * sp * 0.42 * u
                    if !tiny then
                        fz = fz + mass * (14 + 18 * u)
                    end
                elseif tumble > 0.12 then
                    fz = fz - mass * 16 * tumble
                end
                if IsValid(b) then
                    local s = sin(now * b.SineFreq + b.SinePhase) * sinA * b.SineAmp
                    local rx, ry = -ly, lx
                    local rl = sqrt(rx * rx + ry * ry)
                    if rl > 1 then
                        rx, ry = rx / rl, ry / rl
                        dx, dy = dx + rx * s, dy + ry * s
                    end
                end
                local onW = onGround and IsValid(b) and (b._wallUntil or 0) > now
                if onW then
                    local wxn = b._hitNx or 0
                    local wyn = b._hitNy or 0
                    local wzn = b._hitNz or 1
                    local ex = (mgr._ex or hx) - ix
                    local ey = (mgr._ey or hy) - iy
                    local ez = (mgr._ez or iz) - iz
                    local el = sqrt(ex * ex + ey * ey + ez * ez)
                    if el > 1 then
                        ex, ey, ez = ex / el, ey / el, ez / el
                        dx, dy, dzv = ex * sp, ey * sp, ez * sp
                    end
                    local d = dx * wxn + dy * wyn + dzv * wzn
                    dx, dy, dzv = dx - wxn * d, dy - wyn * d, dzv - wzn * d
                end
                local kMul = 0.42 + 0.58 * mul
                fx = fx + (dx - vx[i]) * mass * kVel * kMul
                fy = fy + (dy - vy[i]) * mass * kVel * kMul
                if !hopping then
                    fz = fz - vz[i] * mass * 0.35
                end
            end
            if mgr._bubOn and mgr._bubOn[i] and !tiny then
                fz = fz + mass * (6 + 3 * sin(now * 5 + i))
            end
            if (mgr._lungeEnd or 0) > now and mgr._lungeOn and mgr._lungeOn[i] then
                fx = fx + (mgr._lx or 0) * mass * 3.2
                fy = fy + (mgr._ly or 0) * mass * 3.2
            end
        end
        local fl = abs(fx) + abs(fy) + abs(fz)
        local capF = (mgr._reach or mgr._coat or onW) and 8500 or 4000
        if tiny then
            capF = 2200
        elseif mgr._coat then
            capF = 11000
        end
        if fl > capF then
            local s = capF / fl
            fx, fy, fz = fx * s, fy * s, fz * s
        end
        if fl > 0.01 then
            Force.x, Force.y, Force.z = fx, fy, fz
            ph:Wake()
            ph:ApplyForceCenter(Force)
        end
        local vel = ph:GetVelocity()
        local changed = false
        local zCap = tiny and 36 or 68
        if vel.z > zCap then
            vel.z = zCap
            changed = true
        end
        if !nopull[i] then
            local hs = vel.x * vel.x + vel.y * vel.y
            local cap = maxSpd * maxSpd
            if hs > cap then
                local s = maxSpd / sqrt(hs)
                vel.x, vel.y = vel.x * s, vel.y * s
                changed = true
            end
        end
        if changed then
            ph:SetVelocity(vel)
        end
        ::cont::
    end
end

local function growFromEat(mgr, pos)
    if !IsValid(mgr) or mgr.IsGel then return end
    local n = prune(mgr)
    if n >= C.GrowUntil() then return end
    pos = pos or mgr:GetPos()
    local e = C.MakeBlob(mgr, pos + Vector(0, 0, C.RADIUS + 4))
    if !IsValid(e) then return end
    C.PaintBlob(e, n + 1, n + 1)
    splash(pos)
end

local function swallow(mgr, e, n, cx, cy, cz)
    if !IsValid(e) or e._surfMeal then return end
    e._surfMeal = true
    e:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    e:SetSolid(SOLID_NONE)
    if e.SetNPCState then
        e:SetNPCState(NPC_STATE_NONE)
    end
    if e.StopMoving then
        e:StopMoving()
    end
    e:SetMoveType(MOVETYPE_NONE)
    e:SetPos(Vector(cx, cy, cz))
    local meals = mgr._meals
    if !meals then
        meals = {}
        mgr._meals = meals
    end
    meals[#meals + 1] = { e = e, die = CurTime() + math.Rand(7, 11) }
end

local function tickMeals(mgr, n, cx, cy, cz)
    local meals = mgr._meals
    if !meals then return end
    local now = CurTime()
    for i = #meals, 1, -1 do
        local m = meals[i]
        local e = m.e
        if !IsValid(e) then
            meals[i] = meals[#meals]
            meals[#meals] = nil
        elseif now >= m.die then
            local p = e:GetPos()
            C.SpawnFlecks(p, math.random(5, 8), blobColor(entsA[1]))
            e:Remove()
            meals[i] = meals[#meals]
            meals[#meals] = nil
            growFromEat(mgr, p)
        else
            e:SetPos(Vector(
                cx + math.sin(now * 1.1 + i) * 10,
                cy + math.cos(now * 0.85 + i * 1.3) * 10,
                cz + 3 + math.sin(now * 0.7 + i) * 6
            ))
        end
    end
end

local function doDamage(mgr, n, cx, cy, cz, enemy)
    if mgr.IsGel or n < 1 then return end
    local now = CurTime()
    local function touching(e)
        if !IsValid(e) then return false end
        local w = e:WorldSpaceCenter()
        local p = e:GetPos()
        local mn, mx = e:GetCollisionBounds()
        local hx = mx.x - mn.x
        local hy = mx.y - mn.y
        local hz = mx.z - mn.z
        local pad = C.RADIUS + 22
        local rx = hx * 0.55 + pad
        local ry = hy * 0.55 + pad
        local rz = hz * 0.55 + pad
        local r2 = max(rx, ry) * max(rx, ry)
        local function nearPoint(wx, wy, wz, zr)
            local dx, dy, dz = wx - cx, wy - cy, wz - cz
            if dx * dx + dy * dy + dz * dz < 55 * 55 then return true end
            for i = 1, n do
                dx, dy, dz = px[i] - wx, py[i] - wy, pz[i] - wz
                if dx * dx + dy * dy < r2 and abs(dz) < zr then return true end
            end
            return false
        end
        if nearPoint(w.x, w.y, w.z, rz) then return true end
        if nearPoint(p.x, p.y, p.z + hz * 0.25, rz) then return true end
        return false
    end
    local function tryHurt(e)
        if !IsValid(e) or e._surfMeal then return end
        if e:IsPlayer() then
            if C.IgnorePlayers and C.IgnorePlayers() then return end
            if !e:Alive() then return end
        elseif !isMob(e) then
            return
        end
        if !touching(e) then return end
        if isSmallPrey(e) then
            swallow(mgr, e, n, cx, cy, cz)
            return
        end
        if (e._surfDmgT or 0) > now then return end
        e._surfDmgT = now + C.DMG_CD
        local info = DamageInfo()
        info:SetAttacker(mgr)
        info:SetInflictor(mgr)
        info:SetDamage(C.DMG)
        info:SetDamageType(bit.bor(DMG_SLASH, DMG_CLUB))
        F2.x, F2.y, F2.z = 0, 0, 12
        info:SetDamageForce(F2)
        info:SetDamagePosition(e:WorldSpaceCenter())
        e:TakeDamageInfo(info)
    end
    tryHurt(enemy)
    if (mgr._mobDmgT or 0) > now then return end
    mgr._mobDmgT = now + 0.14
    local found = ents.FindInSphere(Vector(cx, cy, cz), 140)
    for i = 1, #found do
        local e = found[i]
        if e ~= enemy then
            tryHurt(e)
        end
    end
end

local function coatEnemy(mgr, n, cx, cy, cz, enemy)
    if mgr.IsGel or n < 1 or !IsValid(enemy) then
        mgr._coat = false
        return
    end
    if enemy:IsPlayer() then
        if C.IgnorePlayers and C.IgnorePlayers() then
            mgr._coat = false
            return
        end
    elseif !isMob(enemy) or isSmallPrey(enemy) then
        mgr._coat = false
        return
    end
    local w = enemy:WorldSpaceCenter()
    local p = enemy:GetPos()
    local dx, dy = w.x - cx, w.y - cy
    local dxy = sqrt(dx * dx + dy * dy)
    if dxy > 125 then
        mgr._coat = false
        return
    end
    mgr._coat = true
    local mn, mx = enemy:GetCollisionBounds()
    local hz = mx.z - mn.z
    local mass = C.MASS
    local now = CurTime()
    for i = 1, n do
        if held[i] or nopull[i] then
            goto coatCont
        end
        local ph = physA[i]
        if !IsValid(ph) then
            goto coatCont
        end

        local t = ((i * 0.37) % 1)
        local tx = w.x + sin(now * 1.2 + i) * 8
        local ty = w.y + cos(now * 1.1 + i * 1.3) * 8
        local tz = p.z + hz * (0.18 + t * 0.72)
        local ox, oy, oz = tx - px[i], ty - py[i], tz - pz[i]
        local d2 = ox * ox + oy * oy + oz * oz
        if d2 < 4 or d2 > 160 * 160 then
            goto coatCont
        end
        local dist = sqrt(d2)
        local pull = mass * (22 + (1 - dist / 160) * 28)
        Force.x = ox / dist * pull
        Force.y = oy / dist * pull
        Force.z = oz / dist * pull + mass * 10
        ph:Wake()
        ph:ApplyForceCenter(Force)
        local b = entsA[i]
        if IsValid(b) and b._gravOn ~= false then
            b._gravOn = false
            ph:EnableGravity(false)
        end
        ::coatCont::
    end
end

local function nearChunk(n, wx, wy, wz, r2)
    for i = 1, n do
        local dx, dy, dz = wx - px[i], wy - py[i], wz - pz[i]
        if dx * dx + dy * dy + dz * dz < r2 then
            return true
        end
    end
    return false
end

local function hurtProp(mgr, e, n, cx, cy, cz, now)
    if !IsValid(e) or e:IsPlayer() or e:IsNPC() or e:IsVehicle() then return end
    if e.IsNextBot and e:IsNextBot() then return end
    if isSurfaceEnt(e) or e:IsPlayerHolding() or e._surfMeal then return end
    if (e._surfPropDmg or 0) > now then return end
    local cls = e:GetClass()
    local rag = e:IsRagdoll() or cls == "prop_ragdoll"
    local breakable = cls == "func_breakable" or cls == "func_breakable_surf" or cls == "func_physbox"
    local phys = e:GetMoveType() == MOVETYPE_VPHYSICS or rag
    if !breakable and !phys then return end
    local w = e:WorldSpaceCenter()
    local hitR = C.RADIUS * 2.2
    if !nearChunk(n, w.x, w.y, w.z, hitR * hitR) then return end
    e._surfPropDmg = now + C.DMG_CD
    local info = DamageInfo()
    info:SetAttacker(mgr)
    info:SetInflictor(mgr)
    info:SetDamage(C.DMG * 1.75)
    info:SetDamageType(bit.bor(DMG_SLASH, DMG_CLUB, DMG_CRUSH))
    F2.x = (w.x - cx) * 4
    F2.y = (w.y - cy) * 4
    F2.z = 28
    info:SetDamageForce(F2)
    info:SetDamagePosition(w)
    e:TakeDamageInfo(info)
    local ph = e:GetPhysicsObject()
    if IsValid(ph) and ph:IsMotionEnabled() then
        ph:Wake()
        local mass = ph:GetMass()
        if mass < 0.2 then mass = 0.2 end
        if mass > 80 then mass = 80 end
        Force.x = (w.x - cx) * mass * 2.2
        Force.y = (w.y - cy) * mass * 2.2
        Force.z = mass * 18
        ph:ApplyForceCenter(Force)
    end
end

local function trapProps(mgr, n, cx, cy, cz)
    if n < 1 then return end
    local now = CurTime()
    if (mgr._propT or 0) > now then return end
    mgr._propT = now + 0.12
    local trapped = mgr._trapped
    if !trapped then
        trapped = {}
        mgr._trapped = trapped
    end
    for i = #trapped, 1, -1 do
        local e = trapped[i]
        if !IsValid(e) then
            trapped[i] = trapped[#trapped]
            trapped[#trapped] = nil
        end
    end
    local origin = mgr:GetPos()
    local rad = C.RADIUS * 3.4 + 18
    local found = ents.FindInSphere(origin, rad)
    local cap = 6
    for i = 1, #found do
        local e = found[i]
        if !IsValid(e) or e:IsPlayer() or e:IsVehicle() or isSurfaceEnt(e) or e:IsPlayerHolding() then
            goto nextFound
        end
        hurtProp(mgr, e, n, cx, cy, cz, now)
        if isSmallPrey(e) and !e._surfMeal then
            local p = e:WorldSpaceCenter()
            if nearChunk(n, p.x, p.y, p.z, (C.RADIUS * 2.4) * (C.RADIUS * 2.4)) then
                swallow(mgr, e, n, cx, cy, cz)
            end
        end
        if #trapped >= cap then
            goto nextFound
        end
        local cls = e:GetClass()
        local rag = e:IsRagdoll() or cls == "prop_ragdoll"
        local physok = e:GetMoveType() == MOVETYPE_VPHYSICS or rag
        if physok and (rag or !e:IsNPC()) then
            local ph = e:GetPhysicsObject()
            if IsValid(ph) then
                local mass = ph:GetMass()
                local mn, mx = e:GetCollisionBounds()
                local sx, sy, sz = mx.x - mn.x, mx.y - mn.y, mx.z - mn.z
                local big = sx
                if sy > big then big = sy end
                if sz > big then big = sz end
                local ok = rag and mass < 160 and big < 110 or (mass > 0.25 and mass < 32 and big < 52)
                if ok and !e.SurfTrap then
                    local p = e:GetPos()
                    if nearChunk(n, p.x, p.y, p.z, (C.RADIUS * 2.1) * (C.RADIUS * 2.1)) then
                        e.SurfTrap = true
                        if rag then
                            e:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
                        end
                        local lin, ang = ph:GetDamping()
                        e._surfLin, e._surfAng = lin, ang
                        trapped[#trapped + 1] = e
                        growFromEat(mgr, p)
                    end
                end
            end
        end
        ::nextFound::
    end
    local visc = Vector()
    for i = #trapped, 1, -1 do
        local e = trapped[i]
        if !IsValid(e) then
            trapped[i] = trapped[#trapped]
            trapped[#trapped] = nil
        else
            hurtProp(mgr, e, n, cx, cy, cz, now)
            local ph = e:GetPhysicsObject()
            if !IsValid(ph) then
                e.SurfTrap = nil
                trapped[i] = trapped[#trapped]
                trapped[#trapped] = nil
            else
                local p = e:GetPos()
                local best, bd = 1, 1e12
                for k = 1, n do
                    local dx, dy, dz = p.x - px[k], p.y - py[k], p.z - pz[k]
                    local d2 = dx * dx + dy * dy + dz * dz
                    if d2 < bd then
                        bd, best = d2, k
                    end
                end
                local rag = e:IsRagdoll() or e:GetClass() == "prop_ragdoll"
                local maxKeep = (C.RADIUS * (rag and 5.8 or 3.6))
                maxKeep = maxKeep * maxKeep
                if rag and !e._surfDigest then
                    e._surfDigest = now + 1.25
                end
                if rag and now >= (e._surfDigest or 0) then
                    C.SpawnFlecks(e:GetPos(), math.random(5, 8), blobColor(entsA[1]))
                    local p = e:GetPos()
                    e.SurfTrap = nil
                    e:Remove()
                    trapped[i] = trapped[#trapped]
                    trapped[#trapped] = nil
                    growFromEat(mgr, p)
                elseif bd > maxKeep or e:IsPlayerHolding() then
                    e.SurfTrap = nil
                    if e._surfLin then
                        ph:SetDamping(e._surfLin, e._surfAng or e._surfLin)
                    end
                    trapped[i] = trapped[#trapped]
                    trapped[#trapped] = nil
                else
                    ph:SetDamping(rag and 6 or 4.2, rag and 7 or 5.5)
                    ph:Wake()
                    if rag then
                        local nc = e:GetPhysicsObjectCount()
                        for bi = 0, nc - 1 do
                            local bp = e:GetPhysicsObjectNum(bi)
                            if IsValid(bp) then
                                bp:Wake()
                                bp:SetDamping(6, 7)
                                local pp = bp:GetPos()
                                local bm = bp:GetMass()
                                if bm < 0.2 then bm = 0.2 end
                                Force.x = (cx - pp.x) * bm * 4.6
                                Force.y = (cy - pp.y) * bm * 4.6
                                Force.z = (cz + 4 - pp.z) * bm * 3.5
                                bp:ApplyForceCenter(Force)
                            end
                        end
                    else
                        local vel = ph:GetVelocity()
                        local mix = 0.30
                        visc.x = vel.x * (1 - mix) + vx[best] * mix
                        visc.y = vel.y * (1 - mix) + vy[best] * mix
                        visc.z = vel.z * (1 - mix) + vz[best] * mix + 10
                        ph:SetVelocity(visc)
                        local mass = ph:GetMass()
                        Force.x = (cx - p.x) * mass * 3.2
                        Force.y = (cy - p.y) * mass * 3.2
                        Force.z = (cz + 6 - p.z) * mass * 2.4
                        ph:ApplyForceCenter(Force)
                    end
                end
            end
        end
    end
end

local function pounceToward(n, tx, ty, tz, cx, cy, cz)
    local dx, dy = tx - cx, ty - cy
    local dxy = sqrt(dx * dx + dy * dy)
    if dxy < 1 then
        dx, dy = 0, 1
    else
        dx, dy = dx / dxy, dy / dxy
    end
    local lift = 28 + min(14, max(0, tz + 10 - cz) * 0.25)
    if lift > 42 then lift = 42 end
    if n < 10 then
        lift = lift * 0.55
    end
    local fwd = 48 + min(58, dxy * 0.45)
    for i = 1, n do
        if held[i] or nopull[i] then continue end
        local ph = physA[i]
        if !IsValid(ph) then continue end
        ph:Wake()
        ph:SetVelocity(Vector(dx * fwd, dy * fwd, lift))
    end
end

function C.Sim(mgr)
    if !IsValid(mgr) then return end
    local n = prune(mgr)
    if n < 1 then
        mgr:Remove()
        return
    end
    n = collect(mgr)
    if n < 1 then
        mgr:Remove()
        return
    end
    local cx, cy, cz = centroid(n)
    mgr._cx, mgr._cy, mgr._cz = cx, cy, cz
    mgr._n = n
    local floorZ = pz[1]
    for i = 2, n do
        if pz[i] < floorZ then
            floorZ = pz[i]
        end
    end
    mgr._floorZ = floorZ
    mgr:SetPos(Vector(cx, cy, cz))
    ensureBullseye(mgr, cx, cy, cz, n)
    local now = CurTime()
    local worldOk, worldZ = onWorldFloor(n, cx, cy, cz, floorZ)
    mgr._worldZ = worldZ
    local onGround = worldOk
    if (mgr._airUntil or 0) > now then
        onGround = false
    end
    if C.AIDisabled and C.AIDisabled() then
        mgr._reach = false
        mgr._reachH = 0
        simForces(mgr, n, cx, cy, cz, false, cx, cy, 0, 1, onGround)
        tryMerge(mgr, n, cx, cy, cz)
        return
    end
    local enemy, ed2 = nearestPrey(mgr, cx, cy, cz)
    local chase, hx, hy, speed = false, cx, cy, C.Speed()
    local restMul = 1
    local dist = 1e9
    if !mgr.IsGel then
        for i = 1, n do
            local b = entsA[i]
            if IsValid(b) then
                if (b._spdT or 0) < now then
                    b._spdT = now + math.Rand(0.5, 1.3)
                    b._spdWant = math.Rand(0.78, 1.26)
                end
                local cur = b.SpeedMul or 1
                b.SpeedMul = cur + ((b._spdWant or 1) - cur) * 0.11
            end
        end
    end
    if IsValid(enemy) and !mgr.IsGel then
        local snack = canEatProp(enemy)
        local huntBody = !snack and (enemy:IsPlayer() or isMob(enemy))
        mgr._huntSnack = snack
        local w = enemy:WorldSpaceCenter()
        local dx, dy = w.x - cx, w.y - cy
        local dxy = sqrt(dx * dx + dy * dy)
        dist = sqrt(ed2)
        local t = 0
        if dist > C.SWARM_R_CLOSE then
            t = min(1, (dist - C.SWARM_R_CLOSE) / (C.SWARM_R - C.SWARM_R_CLOSE))
        end
        restMul = 0.62 + 0.38 * t
        mgr._ex, mgr._ey, mgr._ez = w.x, w.y, w.z
        local hopping = (mgr._pounceEnd or 0) > now
        if onGround or (snack and hopping) or (huntBody and dxy < 140) then
            local ax, ay = w.x, w.y
            if onGround and dxy > 90 and navok() then
                local wp = followpath(mgr, cx, cy, cz, w)
                if wp then
                    ax, ay = wp.x, wp.y
                end
            end
            local adx, ady = ax - cx, ay - cy
            local adxy = sqrt(adx * adx + ady * ady)
            if adxy > 1 then
                adx, ady = adx / adxy, ady / adxy
                if snack then
                    if dxy < 95 then
                        hx, hy = w.x, w.y
                    else
                        hx, hy = ax, ay
                    end
                elseif dxy < 18 then
                    local lx, ly = mgr._lx or 0, mgr._ly or 1
                    local ll = sqrt(lx * lx + ly * ly)
                    if ll > 0.08 then
                        hx = cx + lx / ll * 28
                        hy = cy + ly / ll * 28
                    else
                        hx, hy = w.x, w.y
                    end
                elseif dxy < 90 then
                    hx = w.x + adx * C.PAST
                    hy = w.y + ady * C.PAST
                else
                    hx, hy = ax, ay
                end
                if dxy >= 18 then
                    mgr._lx, mgr._ly = adx, ady
                end
            else
                hx, hy = w.x, w.y
                mgr._lx, mgr._ly = 0, 1
            end
            chase = true
            speed = C.Speed() * (snack and 1.38 or (huntBody and 1.28 or 1.22))
            if dist > 900 then
                speed = C.Speed() * C.IDLE
            end
            local groundZ = mgr._worldZ or floorZ
            local feet = IsValid(enemy) and enemy:GetPos().z or w.z
            local elev = feet - groundZ
            local tall = (w.z - feet) > 36
            if huntBody and ((elev > 40 and dxy < 130) or (tall and dxy < 110) or dxy < 72) then
                mgr._reach = true
                hx, hy = w.x, w.y
            elseif !snack and elev > 72 and dxy > 36 and dxy < 95 and elev < dxy * 1.55 then
                mgr._reach = true
                hx, hy = w.x, w.y
            else
                mgr._reach = false
            end
            if snack and onGround and dxy > 20 and dxy < 170 and (w.z - cz) < 86 then
                if (mgr._pounceT or 0) < now then
                    mgr._pounceT = now + 1.15
                    mgr._pounceEnd = now + 0.42
                    mgr._airUntil = now + 0.24
                    pounceToward(n, w.x, w.y, w.z, cx, cy, cz)
                end
            end
        else
            chase = false
            mgr._reach = false
            mgr._reachH = 0
            hx, hy = cx, cy
            mgr._lx, mgr._ly = 0, 0
        end
    else
        mgr._huntSnack = false
        mgr._reach = false
        mgr._coat = false
        if !onGround then
            mgr._reachH = 0
        end
    end
    if !chase and !mgr.IsGel and onGround then
        if (mgr._wandT or 0) < now or !mgr._wx then
            mgr._wandT = now + math.Rand(2.2, 4.0)
            local a = math.Rand(0, pi * 2)
            local d = math.Rand(18, 36)
            mgr._wx = cx + cos(a) * d
            mgr._wy = cy + sin(a) * d
        end
        hx, hy = mgr._wx, mgr._wy
        if navok() then
            local wp = followpath(mgr, cx, cy, cz, Vector(hx, hy, cz))
            if wp then
                hx, hy = wp.x, wp.y
            end
        end
        local dx, dy = hx - cx, hy - cy
        local l = sqrt(dx * dx + dy * dy)
        if l > 1 then
            mgr._lx, mgr._ly = dx / l, dy / l
        end
        speed = C.Speed() * C.IDLE_CRAWL
    end
    if !mgr.IsGel then
        restMul = restMul * (1 + 0.07 * sin(now * 1.15))
    end
    local sleepy = !chase and onGround and (mgr._dmgKickT or 0) < now and (mgr._blastApartUntil or 0) < now
    if sleepy then
        for i = 1, n do
            if held[i] or abs(vx[i]) + abs(vy[i]) + abs(vz[i]) > 22 then
                sleepy = false
                break
            end
        end
    end
    mgr._idleN = (mgr._idleN or 0) + 1
    local light = sleepy and (mgr._idleN % 2 == 0)
    if !mgr.IsGel and onGround and n >= 3 and now >= (mgr._noBubUntil or 0) and !light then
        if (mgr._bubT or 0) < now then
            mgr._bubT = now + math.Rand(0.38, 0.82)
            mgr._bubOn = mgr._bubOn or {}
            for i = 1, n do
                mgr._bubOn[i] = false
            end
            for k = 1, min(3, n) do
                local best, bd = 1, 1e12
                for i = 1, n do
                    if !mgr._bubOn[i] and !held[i] then
                        local dx, dy = px[i] - cx, py[i] - cy
                        local d2 = dx * dx + dy * dy
                        if d2 < bd then
                            bd, best = d2, i
                        end
                    end
                end
                mgr._bubOn[best] = true
            end
        end
        if chase and !mgr._huntSnack and dist < 115 then
            if (mgr._lungeT or 0) < now then
                mgr._lungeT = now + math.Rand(2.4, 3.8)
                mgr._lungeEnd = now + 0.55
                mgr._lungeOn = mgr._lungeOn or {}
                for i = 1, n do mgr._lungeOn[i] = false end
                local lx, ly = mgr._lx or 0, mgr._ly or 0
                for k = 1, min(2, n) do
                    local best, bv = 1, -1e9
                    for i = 1, n do
                        if !mgr._lungeOn[i] and !held[i] then
                            local d = (px[i] - cx) * lx + (py[i] - cy) * ly
                            if d > bv then
                                bv, best = d, i
                            end
                        end
                    end
                    mgr._lungeOn[best] = true
                end
            end
        end
    end
    mgr._lcx, mgr._lcy = cx, cy
    if !light then
    local restH = C.RADIUS * (C.REST or 1.68)
    local maxH = restH * 1.62
    mgr._reachRank = mgr._reachRank or {}
    for i = 1, n do
        mgr._reachRank[i] = 0
    end
    mgr._nArm = 0
    mgr._rdx, mgr._rdy = 0, 0
    if mgr._reach and n >= 10 then
        local want = (mgr._ez or cz) - floorZ - 12
        if want < restH then want = restH end
        if want > maxH then want = maxH end
        local h = mgr._reachH or restH
        mgr._reachH = h + (want - h) * 0.05
        local dx, dy = (mgr._ex or cx) - cx, (mgr._ey or cy) - cy
        local dxy = sqrt(dx * dx + dy * dy)
        if dxy > 1 then
            mgr._rdx, mgr._rdy = dx / dxy, dy / dxy
        end
        local nArm = min(3, max(2, floor(n * 0.12)))
        local pick = {}
        for k = 1, nArm do
            local best, bd = 1, 1e12
            for i = 1, n do
                if mgr._reachRank[i] == 0 and !held[i] then
                    local ex, ey = (mgr._ex or cx) - px[i], (mgr._ey or cy) - py[i]
                    local d2 = ex * ex + ey * ey
                    if d2 < bd then
                        bd, best = d2, i
                    end
                end
            end
            mgr._reachRank[best] = -1
            pick[k] = { i = best, d = bd }
        end
        for a = 1, nArm do
            for b = a + 1, nArm do
                if pick[a].d < pick[b].d then
                    pick[a], pick[b] = pick[b], pick[a]
                end
            end
        end
        for k = 1, nArm do
            mgr._reachRank[pick[k].i] = k
        end
        mgr._nArm = nArm
    else
        local h = mgr._reachH or 0
        h = h * 0.82
        if h < 3 then h = 0 end
        mgr._reachH = h
    end
    end
    simForces(mgr, n, cx, cy, cz, chase, hx, hy, speed, restMul, onGround)
    coatEnemy(mgr, n, cx, cy, cz, enemy)
    doDamage(mgr, n, cx, cy, cz, enemy)
    trapProps(mgr, n, cx, cy, cz)
    tickMeals(mgr, n, cx, cy, cz)
    pullTinyPeers(mgr, n, cx, cy, cz)
    trySplit(mgr, n, cx, cy, cz)
    tryMerge(mgr, n, cx, cy, cz)
end

local function clusterBlast(mgr, origin)
    if !IsValid(mgr) or !mgr.Blobs then return end
    local blobs = mgr.Blobs
    local list, n = {}, 0
    for i = 1, #blobs do
        local b = blobs[i]
        if IsValid(b) and !b:IsPlayerHolding() then
            n = n + 1
            list[n] = b
        end
    end
    if n < 1 then return end
    splash(origin)
    local now = CurTime()
    mgr._noBubUntil = now + 1.5
    mgr._blastApartUntil = math.max(mgr._blastApartUntil or 0, now + 2)
    mgr._noMergeUntil = math.max(mgr._noMergeUntil or 0, now + 2)
    local ox, oy, oz = origin.x, origin.y, origin.z
    local function pushGroup(arr, extra, doFleck)
        local m = #arr
        if m < 1 then return end
        local sx, sy, sz = 0, 0, 0
        for i = 1, m do
            local p = arr[i]:GetPos()
            sx, sy, sz = sx + p.x, sy + p.y, sz + p.z
        end
        sx, sy, sz = sx / m, sy / m, sz / m
        local dx, dy, dz = sx - ox, sy - oy, sz - oz
        local d = sqrt(dx * dx + dy * dy + dz * dz)
        if d < 8 then d = 8 end
        local spd = 72 + extra
        local Imp = Vector(dx / d * spd, dy / d * spd, 14 + extra * 0.12)
        for i = 1, m do
            local bp = arr[i]:GetPhysicsObject()
            if IsValid(bp) then
                bp:Wake()
                bp:AddVelocity(Imp)
                arr[i]._noPullUntil = now + 2
                arr[i]._groundedUntil = 0
                arr[i]._wallUntil = 0
            end
        end
        if doFleck then
            C.SpawnFlecks(Vector(sx, sy, sz + 6), math.random(6, 10), blobColor(arr[1]))
        end
    end
    mgr._airUntil = now + 0.85
    mgr._reach = false
    mgr._reachH = 0
    if n < 14 then
        pushGroup(list, 18, true)
        return
    end
    local k = 2
    local groups = {}
    for c = 1, k do
        groups[c] = {}
    end
    for i = 1, n do
        local p = list[i]:GetPos()
        local ang = math.atan2(p.y - oy, p.x - ox)
        local slot = floor((ang + pi) / (2 * pi) * k) + 1
        if slot < 1 then slot = 1 elseif slot > k then slot = k end
        groups[slot][#groups[slot] + 1] = list[i]
    end
    local main, mn = 1, 0
    for c = 1, k do
        if #groups[c] > mn then
            mn, main = #groups[c], c
        end
    end
    for c = 1, k do
        if c ~= main and #groups[c] < 6 then
            for i = 1, #groups[c] do
                groups[main][#groups[main] + 1] = groups[c][i]
            end
            groups[c] = {}
        end
    end
    pushGroup(groups[main], 8, true)
    for c = 1, k do
        if c ~= main and #groups[c] >= 6 then
            local arr = groups[c]
            local sx, sy, sz = 0, 0, 0
            for i = 1, #arr do
                local p = arr[i]:GetPos()
                sx, sy, sz = sx + p.x, sy + p.y, sz + p.z
            end
            local m = #arr
            sx, sy, sz = sx / m, sy / m, sz / m
            splitByEnts(mgr, arr, m, sx, sy, sz, Vector(sx - ox, sy - oy, 8), 3.8, true)
        end
    end
end

local function bulletPinch(mgr, origin, force)
    if !IsValid(mgr) or !mgr.Blobs then return end
    local blobs = mgr.Blobs
    local list, n = {}, 0
    for i = 1, #blobs do
        local b = blobs[i]
        if IsValid(b) and !b:IsPlayerHolding() then
            n = n + 1
            list[n] = b
        end
    end
    if n < 10 then
        local hit = list[1]
        local best, bd = nil, 1e12
        for i = 1, n do
            local p = list[i]:GetPos()
            local dx, dy, dz = p.x - origin.x, p.y - origin.y, p.z - origin.z
            local d2 = dx * dx + dy * dy + dz * dz
            if d2 < bd then
                bd, best = d2, list[i]
            end
        end
        hit = best or hit
        if IsValid(hit) then
            local bp = hit:GetPhysicsObject()
            if IsValid(bp) then
                local dir = force:Length() > 1 and force:GetNormalized() or Vector(0, 0, 1)
                dir.z = 0
                if dir:LengthSqr() < 0.04 then dir = Vector(0, 0, 1) else dir:Normalize() end
                bp:AddVelocity(dir * 70 + Vector(0, 0, 16))
            end
        end
        C.SpawnFlecks(origin, 2, blobColor(hit), force)
        return
    end
    local rPick = C.RADIUS * 2.7
    local r2 = rPick * rPick
    local near = {}
    for i = 1, n do
        local p = list[i]:GetPos()
        local dx, dy, dz = p.x - origin.x, p.y - origin.y, p.z - origin.z
        local d2 = dx * dx + dy * dy + dz * dz
        if d2 <= r2 then
            near[#near + 1] = { e = list[i], d = d2 }
        end
    end
    if #near < 2 then
        local best, bd = list[1], 1e12
        for i = 1, n do
            local p = list[i]:GetPos()
            local dx, dy, dz = p.x - origin.x, p.y - origin.y, p.z - origin.z
            local d2 = dx * dx + dy * dy + dz * dz
            if d2 < bd then
                bd, best = d2, list[i]
            end
        end
        local bp = best:GetPhysicsObject()
        if IsValid(bp) then
            local dir = force:Length() > 1 and force:GetNormalized() or Vector(0, 0, 1)
            dir.z = 0
            if dir:LengthSqr() < 0.04 then dir = Vector(0, 0, 1) else dir:Normalize() end
            bp:AddVelocity(dir * 62 + Vector(0, 0, 14))
        end
        C.SpawnFlecks(origin, 2, blobColor(best), force)
        return
    end
    for a = 1, #near do
        for b = a + 1, #near do
            if near[a].d > near[b].d then
                near[a], near[b] = near[b], near[a]
            end
        end
    end
    local take = min(4, #near)
    if n - take < 5 then
        take = min(3, n - 5)
    end
    if take < 2 then return end
    local arr = {}
    local sx, sy, sz = 0, 0, 0
    for i = 1, take do
        arr[i] = near[i].e
        local p = arr[i]:GetPos()
        sx, sy, sz = sx + p.x, sy + p.y, sz + p.z
    end
    sx, sy, sz = sx / take, sy / take, sz / take
    local dir
    if force:Length() > 1 then
        dir = force:GetNormalized()
    else
        dir = Vector(sx - origin.x, sy - origin.y, sz - origin.z)
        if dir:LengthSqr() < 1 then dir = Vector(0, 0, 1) else dir:Normalize() end
    end
    dir.z = 0
    if dir:LengthSqr() < 0.04 then
        dir = Vector(sx - (mgr._cx or origin.x), sy - (mgr._cy or origin.y), 0)
        if dir:LengthSqr() < 0.04 then dir = Vector(1, 0, 0) else dir:Normalize() end
    else
        dir:Normalize()
    end
    local now = CurTime()
    mgr._dmgKick = dir * 140
    mgr._dmgKickT = now + 0.4
    mgr._airUntil = math.max(mgr._airUntil or 0, now + 0.45)
    local baby = splitByEnts(mgr, arr, take, sx, sy, sz, dir * 140, 2.2)
    if IsValid(baby) then
        baby._splitFrom = mgr
    end
end

local function hurtBlob(ent, amt, pos, force)
    if !IsValid(ent) or !ent.IsSurfBlob then return false end
    amt = tonumber(amt) or 0
    if amt < 1 then amt = 12 end
    local hp = ent.SurfHP
    if hp == nil then
        hp = ent:Health()
        if !hp or hp <= 0 then
            hp = C.ChunkHP and C.ChunkHP() or C.CHUNK_HP or 60
        end
    end
    hp = hp - amt
    ent.SurfHP = hp
    ent:SetHealth(max(0, floor(hp + 0.5)))
    if hp > 0 then return false end
    local p = pos or ent:GetPos()
    C.SpawnFlecks(p, math.random(3, 6), blobColor(ent), force)
    splash(p)
    ent:Remove()
    return true
end

local function rayHitBlob(src, dir, maxDist)
    local t = C.Blobs
    if !t then return nil, nil, nil end
    local R = C.RADIUS * 1.2
    local r2 = R * R
    local dx, dy, dz = dir.x, dir.y, dir.z
    local dl = sqrt(dx * dx + dy * dy + dz * dz)
    if dl < 1e-4 then return nil, nil, nil end
    dx, dy, dz = dx / dl, dy / dl, dz / dl
    local best, hit, pos = maxDist, nil, nil
    local sx, sy, sz = src.x, src.y, src.z
    for i = 1, #t do
        local e = t[i]
        if IsValid(e) then
            local p = e:GetPos()
            local ox, oy, oz = p.x - sx, p.y - sy, p.z - sz
            local proj = ox * dx + oy * dy + oz * dz
            if proj > 0 and proj < best then
                local cx, cy, cz = ox - dx * proj, oy - dy * proj, oz - dz * proj
                if cx * cx + cy * cy + cz * cz <= r2 then
                    best = proj
                    hit = e
                    pos = Vector(sx + dx * proj, sy + dy * proj, sz + dz * proj)
                end
            end
        end
    end
    return hit, pos, best
end

hook.Add("EntityFireBullets", "npc_surface_hit", function(atk, data)
    if !data or !data.Src or !data.Dir then return end
    local src = data.Src
    local dir0 = data.Dir
    local dist = data.Distance or 4096
    if dist < 128 then dist = 128 end
    local num = data.Num or 1
    if num < 1 then num = 1 elseif num > 14 then num = 14 end
    local spread = data.Spread
    local hit, pos, along
    for i = 1, num do
        local dir = dir0
        if spread and (spread.x > 0 or spread.y > 0) and i > 1 then
            dir = Vector(dir0.x, dir0.y, dir0.z)
            dir.x = dir.x + (math.Rand(-1, 1)) * spread.x * 2
            dir.y = dir.y + (math.Rand(-1, 1)) * spread.y * 2
            dir:Normalize()
        end
        local e, p, d = rayHitBlob(src, dir, dist)
        if IsValid(e) then
            hit, pos, along = e, p, d
            break
        end
    end
    if !IsValid(hit) then return end
    local mgr = hit.Surf
    local now = CurTime()
    C.MuteShotSoundUntil = now + 0.14
    C.MuteShotSoundPos = pos
    local f = dir0 * 420
    local dmgAmt = tonumber(data.Damage) or 0
    if dmgAmt < 1 then
        dmgAmt = 18
    end
    if num > 1 then
        dmgAmt = dmgAmt * max(1, min(num, 6)) * 0.55
    end
    local dead = hurtBlob(hit, dmgAmt, pos, f)
    if IsValid(mgr) then
        if (mgr._shotT or 0) <= now then
            mgr._shotT = now + 0.22
            mgr._dmgKick = f
            mgr._dmgKickT = now + 0.4
            if !dead then
                if num >= 4 then
                    shotgunScatter(mgr, pos, f)
                else
                    bulletPinch(mgr, pos, f)
                end
            end
        end
    elseif !dead then
        local ph = hit:GetPhysicsObject()
        if IsValid(ph) then
            ph:Wake()
            ph:AddVelocity(dir0 * 80 + Vector(0, 0, 18))
        end
    end
    data.Distance = along + 6
    return true
end)

hook.Add("EntityTakeDamage", "npc_surface_blob", function(ent, dmg)
    if !IsValid(ent) or !ent.IsSurfBlob then return end
    local ph = ent:GetPhysicsObject()
    if !IsValid(ph) then return true end

    if dmg:IsDamageType(DMG_BLAST) or dmg:IsExplosionDamage() then
        local mgr = ent.Surf
        local now = CurTime()
        local origin = dmg:GetDamagePosition()
        if !origin or origin:LengthSqr() < 1 then
            origin = ent:GetPos()
        end
        if IsValid(mgr) then
            if (mgr._blastT or 0) <= now then
                mgr._blastT = now + 0.2
                local f = dmg:GetDamageForce()
                if f and f:LengthSqr() > 1 then
                    mgr._dmgKick = f
                    mgr._dmgKickT = now + 0.55
                end
                clusterBlast(mgr, origin)
            end
        else
            local f = dmg:GetDamageForce()
            local dir = (f and f:LengthSqr() > 1) and f:GetNormalized() or (ent:GetPos() - origin):GetNormalized()
            if dir:LengthSqr() < 0.04 then dir = Vector(0, 0, 1) end
            ph:Wake()
            ph:AddVelocity(dir * 120 + Vector(0, 0, 48))
            ent._noPullUntil = now + 0.85
            C.SpawnFlecks(ent:GetPos(), 3, blobColor(ent), dir)
        end
        return true
    end
    local f = dmg:GetDamageForce()
    local amt = dmg:GetDamage()
    if amt < 1 then amt = 12 end
    local origin = dmg:GetDamagePosition()
    if !origin or origin:LengthSqr() < 1 then
        origin = ent:GetPos()
    end
    local buck = dmg:IsDamageType(DMG_BUCKSHOT)
    local dead = hurtBlob(ent, amt, origin, f)
    if buck then
        local mgr = ent.Surf
        local now = CurTime()
        if IsValid(mgr) and (mgr._blastT or 0) > now then
            return true
        end
        if IsValid(mgr) then
            mgr._blastT = now + 0.12
            mgr._dmgKick = f
            mgr._dmgKickT = now + 0.45
            if !dead then
                shotgunScatter(mgr, origin, f)
            end
        elseif !dead then
            ph:AddVelocity(f:GetNormalized() * 160 + Vector(0, 0, 70))
            ent._noPullUntil = now + 0.2
            C.SpawnFlecks(ent:GetPos(), 2, blobColor(ent))
        end
    else
        local mgr = ent.Surf
        local now = CurTime()
        if IsValid(mgr) and (mgr._shotT or 0) > now then
            return true
        end
        if IsValid(mgr) then
            mgr._shotT = now + 0.22
            mgr._dmgKick = f
            mgr._dmgKickT = now + 0.4
            if !dead then
                bulletPinch(mgr, origin, f)
            end
        elseif !dead then
            local dir = f:Length() > 1 and f:GetNormalized() or vector_up
            ph:AddVelocity(dir * 16)
        end
        C.MuteShotSoundUntil = now + 0.14
        C.MuteShotSoundPos = origin
    end
    return true
end)

hook.Add("ShouldCollide", "npc_surface_trap", function(a, b)
    if !(a.SurfTrap or b.SurfTrap) then return end
    if a.IsSurfBlob or b.IsSurfBlob then
        return false
    end
end)
