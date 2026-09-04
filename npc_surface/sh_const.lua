NPC_SURFACE = NPC_SURFACE or {}
local C = NPC_SURFACE

C.NUM = 32
C.MAX = 72
C.GEL_NUM = 10
C.RADIUS = 13.5
C.SPEED = 70
C.IDLE = 0.55
C.SIN = 9
C.SWARM_R = 56
C.SWARM_R_CLOSE = 18
C.STRAGGLE = 78
C.DMG = 6
C.DMG_CD = 0.22
C.CHUNK_HP = 60
C.PAST = 80
C.ISO = 0.50
C.INF = 2.02
C.CELL = 4.5
C.CELL_FAR = 6.0
C.SPLIT_MUL = 8.6
C.SPLIT_T = 2.35
C.INTERACT = 3.1
C.LJ_ATTR = 4.2
C.LJ_REP = 1.05
C.ST = 14
C.MASS = 16
C.SQUASH_Z = 1.0
C.SQUASH_XY = 1.0
C.SAG = 0
C.REST = 1.68
C.SPRING = 24
C.GRAV = 120
C.IDLE_CRAWL = 0.62
C.MAX_SPD = 102
C.EMA = 0.38
C.MOVE_EPS = 0.5

C.COL_R = 86
C.COL_G = 170
C.COL_B = 208

C.QUALITY = {
    [1] = { cell = 5.8, cellFar = 7.2, inf = 1.96, eps = 0.85, far = 900, hz = 60 },
    [2] = { cell = 4.4, cellFar = 5.8, inf = 2.02, eps = 0.70, far = 900, hz = 60 },
    [3] = { cell = 3.15, cellFar = 4.6, inf = 2.08, eps = 0.58, far = 1100, hz = 60 },
}
C.FLECK_Q = { cell = 7.4, cellFar = 9.2, inf = 2.02, eps = 0.75, hz = 40 }

local flags = FCVAR_ARCHIVE
C.cvQuality = CreateConVar("npc_surface_quality", "1", flags, "Mesh quality 1 low .. 3 high.")
C.cvTranslucent = CreateConVar("npc_surface_translucent", "0", flags, "legacy, unused.")
C.cvMat = CreateConVar("npc_surface_mat", "1", flags, "Material preset 1 opaque, 2 gel, 3 glass.")
C.cvAlwaysChase = CreateConVar("npc_surface_always_chase", "1", flags, "Always chase nearest player.")
C.cvMaxChunks = CreateConVar("npc_surface_max_chunks", "150", flags, "Max chunks on the map.")
C.cvMaxNear = CreateConVar("npc_surface_max_near", "40", flags, "Max chunks nearby.")
C.cvNearDist = CreateConVar("npc_surface_near_dist", "720", flags, "Nearby chunk limit radius.")
C.cvGrowUntil = CreateConVar("npc_surface_grow_until", "8", flags, "Grow from eating until this many chunks.")
C.cvClusterSize = CreateConVar("npc_surface_cluster_size", "32", flags, "Chunks spawned by npc_surface_cluster.")
C.cvSpeed = CreateConVar("npc_surface_speed", "70", flags, "Slime move speed.")
C.cvHpMul = CreateConVar("npc_surface_hp", "1", flags, "Chunk HP multiplier 0.25 .. 4.")
C.cvMultiColor = CreateConVar("npc_surface_multicolor", "1", flags, "1 = rainbow chunks, 0 = custom color.")
C.cvColR = CreateConVar("npc_surface_col_r", "86", flags, "Slime color R.")
C.cvColG = CreateConVar("npc_surface_col_g", "170", flags, "Slime color G.")
C.cvColB = CreateConVar("npc_surface_col_b", "208", flags, "Slime color B.")
C.cvHz = CreateConVar("npc_surface_hz", "60", flags, "Mesh rebuild rate 20 .. 180.")
C.cvJelly = CreateConVar("npc_surface_jelly", "1", flags, "1 = jelly forming on lone chunks, 0 = spheres.")
C.cvJellyCluster = CreateConVar("npc_surface_jelly_cluster", "0", flags, "1 = softer jelly on big clusters, 0 = plain spheres.")

function C.ReadQuality()
    local q = math.floor((tonumber(GetConVarNumber("npc_surface_quality")) or 1) + 0.5)
    if q < 1 then q = 1 elseif q > 3 then q = 3 end
    return q
end

function C.ReadHz()
    local v = math.floor((tonumber(GetConVarNumber("npc_surface_hz")) or 60) + 0.5)
    if v < 20 then v = 20 elseif v > 180 then v = 180 end
    return v
end

function C.AIDisabled()
    return GetConVarNumber("ai_disabled") ~= 0
end

function C.IgnorePlayers()
    return GetConVarNumber("ai_ignoreplayers") ~= 0
end

function C.AlwaysChase()
    return GetConVarNumber("npc_surface_always_chase") ~= 0
end

function C.MaxChunks()
    local v = math.floor(GetConVarNumber("npc_surface_max_chunks") or 150)
    if v < 8 then v = 8 elseif v > 400 then v = 400 end
    return v
end

function C.MaxNear()
    local v = math.floor(GetConVarNumber("npc_surface_max_near") or 40)
    if v < 1 then v = 1 elseif v > 80 then v = 80 end
    return v
end

function C.NearDist()
    local v = GetConVarNumber("npc_surface_near_dist") or 720
    if v < 120 then v = 120 elseif v > 2500 then v = 2500 end
    return v
end

function C.GrowUntil()
    local v = math.floor(GetConVarNumber("npc_surface_grow_until") or 8)
    if v < 1 then v = 1 elseif v > 40 then v = 40 end
    return v
end

function C.ClusterSize()
    local v = math.floor(GetConVarNumber("npc_surface_cluster_size") or 32)
    if v < 2 then v = 2 end
    local cap = C.MaxNear()
    if v > cap then v = cap end
    return v
end

function C.Speed()
    local v = GetConVarNumber("npc_surface_speed") or C.SPEED
    if v < 20 then v = 20 elseif v > 200 then v = 200 end
    return v
end

function C.ChunkHP()
    local m = tonumber(GetConVarNumber("npc_surface_hp")) or 1
    if m < 0.25 then m = 0.25 elseif m > 4 then m = 4 end
    local hp = math.floor((C.CHUNK_HP or 60) * m + 0.5)
    if hp < 8 then hp = 8 elseif hp > 400 then hp = 400 end
    return hp
end

function C.MultiColor()
    return GetConVarNumber("npc_surface_multicolor") ~= 0
end

function C.JellyMesh()
    return GetConVarNumber("npc_surface_jelly") ~= 0
end

function C.JellyClusterMesh()
    return GetConVarNumber("npc_surface_jelly_cluster") ~= 0
end

function C.ReadMat()
    local v = math.floor((tonumber(GetConVarNumber("npc_surface_mat")) or 1) + 0.5)
    if v < 1 then v = 1 elseif v > 3 then v = 3 end
    return v
end

function C.MatAlpha()
    local m = C.ReadMat()
    if m == 2 then return 168 end
    if m == 3 then return 96 end
    return 255
end

function C.ReadAlpha()
    return C.MatAlpha()
end

function C.ReadColor()
    local r = math.floor(GetConVarNumber("npc_surface_col_r") or C.COL_R)
    local g = math.floor(GetConVarNumber("npc_surface_col_g") or C.COL_G)
    local b = math.floor(GetConVarNumber("npc_surface_col_b") or C.COL_B)
    if r < 0 then r = 0 elseif r > 255 then r = 255 end
    if g < 0 then g = 0 elseif g > 255 then g = 255 end
    if b < 0 then b = 0 elseif b > 255 then b = 255 end
    C.COL_R, C.COL_G, C.COL_B = r, g, b
    return r, g, b
end

function C.CountBlobs()
    local t = C.Blobs
    if !t then return 0 end
    local n = 0
    for i = 1, #t do
        if IsValid(t[i]) then n = n + 1 end
    end
    return n
end

function C.CountNear(pos, rad)
    if !pos then return 0 end
    rad = rad or C.NearDist()
    local r2 = rad * rad
    local t = C.Blobs
    if !t then return 0 end
    local n = 0
    for i = 1, #t do
        local e = t[i]
        if IsValid(e) then
            local p = e:GetPos()
            local dx, dy, dz = p.x - pos.x, p.y - pos.y, p.z - pos.z
            if dx * dx + dy * dy + dz * dz < r2 then
                n = n + 1
            end
        end
    end
    return n
end

function C.CanMakeBlob(pos)
    if C.CountBlobs() >= C.MaxChunks() then return false end
    if pos and C.CountNear(pos, C.NearDist()) >= C.MaxNear() then return false end
    return true
end

local floor = math.floor
function C.HSV(h, s, v)
    if h < 0 then h = h - floor(h) end
    if h >= 1 then h = h - floor(h) end
    local i = floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    local r, g, b = v, t, p
    if i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end
    return floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5)
end

function C.PaintBlob(e, idx, total)
    if !IsValid(e) or !e.SetGelR then return end
    local r, g, b
    if C.MultiColor() then
        local n = total < 1 and 1 or total
        r, g, b = C.HSV((idx - 1) / n, 0.50, 0.90)
    else
        r, g, b = C.ReadColor()
    end
    e:SetGelR(r)
    e:SetGelG(g)
    e:SetGelB(b)
end

function C.NearBlob(pos, rad)
    if !pos then return false end
    rad = rad or 56
    local r2 = rad * rad
    local t = SERVER and C.Blobs or C.ClientBlobs
    if !t then return false end
    for i = 1, #t do
        local e = t[i]
        if IsValid(e) then
            local p = e:GetPos()
            local dx, dy, dz = p.x - pos.x, p.y - pos.y, p.z - pos.z
            if dx * dx + dy * dy + dz * dz < r2 then
                return true
            end
        end
    end
    return false
end

local function skipSurf(e)
    return IsValid(e) and (e.IsSurfBlob or e.IsSurfFleck)
end

function C.IsClingEnt(ent)
    if !IsValid(ent) or ent:IsWorld() then return true end
    if ent.IsSurfBlob or ent.IsSurfFleck then return false end
    if ent:IsPlayer() or ent:IsNPC() or ent:IsWeapon() or ent:IsVehicle() then return false end
    if ent.IsNextBot and ent:IsNextBot() then return false end
    if ent:IsRagdoll() then return false end
    local cls = ent:GetClass() or ""
    if cls:find("npc_surface", 1, true) then return false end
    if cls:sub(1, 5) == "prop_" then return true end
    if cls:sub(1, 5) == "func_" then
        return cls ~= "func_illusionary" and cls ~= "func_smokevolume"
    end
    return false
end

function C.IsClingNormal(n)
    if !n then return false end
    if n.z < -0.40 then return true end
    return math.abs(n.z) < 0.42
end

local function surfPassName(nm)
    if !nm or nm == "" then return false end
    nm = string.lower(nm)
    if nm:find("glass", 1, true) or nm:find("window", 1, true) then
        return false
    end
    return nm:find("chain", 1, true) or nm:find("grate", 1, true)
end

local function texPassName(tex)
    if !tex or tex == "" or tex == "**studio**" or tex == "**empty**" then return false end
    tex = string.lower(tex)
    if tex:find("glass", 1, true) or tex:find("window", 1, true) then return false end
    return tex:find("grate", 1, true) or tex:find("chainlink", 1, true) or tex:find("fence", 1, true) or tex:find("chain_link", 1, true)
end

function C.BulletsPassEnt(ent)
    if !IsValid(ent) or ent:IsWorld() then return false end
    if ent._surfPass ~= nil then return ent._surfPass end
    if ent:IsPlayer() or ent:IsNPC() or ent:IsVehicle() or (ent.IsNextBot and ent:IsNextBot()) then
        ent._surfPass = false
        return false
    end
    local cls = ent:GetClass()
    if cls == "npc_surface_blob" or cls == "npc_surface" or cls == "npc_surface_cluster" or cls == "npc_surface_fleck" then
        ent._surfPass = false
        return false
    end
    if ent:GetCollisionGroup() == COLLISION_GROUP_BREAKABLE_GLASS then
        ent._surfPass = false
        return false
    end
    local c = ent.GetContents and (ent:GetContents() or 0) or 0
    if bit.band(c, CONTENTS_WINDOW) ~= 0 then
        ent._surfPass = false
        return false
    end
    local pass = false
    if bit.band(c, CONTENTS_GRATE) ~= 0 then
        pass = true
    else
        local mdl = string.lower(ent:GetModel() or "")
        if mdl:find("glass", 1, true) or mdl:find("window", 1, true) then
            pass = false
        elseif mdl:find("fence", 1, true) or mdl:find("chainlink", 1, true) or mdl:find("chain_link", 1, true) or mdl:find("gate_door", 1, true) or mdl:find("grate", 1, true) then
            pass = true
        elseif surfPassName(ent:GetMaterial()) then
            pass = true
        else
            local ph = ent:GetPhysicsObject()
            if IsValid(ph) and ph.GetMaterial and surfPassName(ph:GetMaterial()) then
                pass = true
            end
        end
    end
    ent._surfPass = pass
    return pass
end

function C.HitIsBulletPass(ent, data)
    if !data then return false end
    local hit = data.HitEntity
    if IsValid(hit) and !hit:IsWorld() then
        return C.BulletsPassEnt(hit)
    end
    local n = data.HitNormal
    if n and n.z > 0.55 then return false end
    if data.TheirSurfaceProps then
        local ok, name = pcall(util.GetSurfacePropName, data.TheirSurfaceProps)
        if ok and surfPassName(name) then return true end
    end
    local pos = data.HitPos
    if !pos then return false end
    if bit.band(util.PointContents(pos - (n or vector_up) * 2), CONTENTS_GRATE) ~= 0 then
        return true
    end
    if !n then return false end
    local trSolid = util.TraceLine({
        start = pos + n * 10,
        endpos = pos - n * 28,
        mask = MASK_SOLID,
        filter = skipSurf
    })
    if !trSolid.Hit then return false end
    if texPassName(trSolid.HitTexture) then return true end
    if bit.band(trSolid.Contents or 0, CONTENTS_GRATE) ~= 0 then return true end
    local trShot = util.TraceLine({
        start = pos + n * 10,
        endpos = pos - n * 28,
        mask = MASK_SHOT,
        filter = skipSurf
    })
    if !trShot.Hit then return true end
    return trShot.Fraction > trSolid.Fraction + 0.02
end
