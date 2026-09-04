AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Surface Blob Element"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_OTHER
ENT.DisableDuplicator = true

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "GelR")
    self:NetworkVar("Int", 1, "GelG")
    self:NetworkVar("Int", 2, "GelB")
end

function ENT:Initialize()
    self.IsSurfBlob = true
    if CLIENT then
        local t = NPC_SURFACE.ClientBlobs
        if !t then
            t = {}
            NPC_SURFACE.ClientBlobs = t
        end
        t[#t + 1] = self
        self:SetNoDraw(true)
        self:AddEffects(EF_NODRAW)
        self:DrawShadow(false)
        return
    end
    local C = NPC_SURFACE
    util.PrecacheModel("models/hunter/misc/sphere075x075.mdl")
    self:SetModel("models/hunter/misc/sphere075x075.mdl")
    self:PhysicsInitSphere(C.RADIUS, "gmod_silent")
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    self:SetCollisionBounds(Vector(-C.RADIUS, -C.RADIUS, -C.RADIUS), Vector(C.RADIUS, C.RADIUS, C.RADIUS))
    self:DrawShadow(false)
    self:SetNoDraw(true)
    self:AddEffects(EF_NODRAW)
    self:SetRenderMode(RENDERMODE_NONE)
    local hp = (C.ChunkHP and C.ChunkHP()) or (C.CHUNK_HP or 60)
    self:SetHealth(hp)
    self:SetMaxHealth(hp)
    self.SurfHP = hp
    self.SpeedMul = math.Rand(0.58, 1.42)
    self._spdWant = self.SpeedMul
    self._spdT = CurTime() + math.Rand(0.25, 1.1)
    self.SinePhase = math.Rand(0.01, 0.9)
    self.SineFreq = math.Rand(2.4, 6.5)
    self.SineAmp = math.Rand(0.85, 1.45)
    self.Rnd80 = math.Rand(0.8, 1)
    local r, g, b = C.COL_R, C.COL_G, C.COL_B
    if C.ReadColor then
        r, g, b = C.ReadColor()
    end
    self:SetGelR(r)
    self:SetGelG(g)
    self:SetGelB(b)
    NPC_SURFACE.RegBlob(self)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetMass(C.MASS)
        phys:SetMaterial("gmod_silent")
        phys:SetDamping(self.IsGel and 2.8 or 1.7, self.IsGel and 3.5 or 2.1)
        phys:SetBuoyancyRatio(0)
        phys:EnableGravity(true)
        self._gravOn = true
        self._dampLin = self.IsGel and 2.8 or 1.7
        phys:EnableDrag(true)
        phys:SetDragCoefficient(self.IsGel and 4.0 or 2.0)
        phys:EnableMotion(true)
        phys:SetVelocity(vector_origin)
        phys:Wake()
    end
    self:SetCustomCollisionCheck(true)
    self:CollisionRulesChanged()
end

function ENT:PhysicsCollide(data)
    local hit = data.HitEntity
    if IsValid(hit) and hit.IsSurfBlob then return end
    local n = data.HitNormal
    local spd = data.Speed or 0
    if n then
        self._hitNx, self._hitNy, self._hitNz = n.x, n.y, n.z
        if n.z > 0.52 then
            self._groundedUntil = CurTime() + 0.9
        else

            self._wallUntil = CurTime() + 1.15
        end
    end
    if spd < 52 then return end
    local floorHit = (!IsValid(hit) or hit:IsWorld()) and n and n.z > 0.55
    local C = NPC_SURFACE
    if !floorHit and C and C.HitIsBulletPass and C.HitIsBulletPass(self, data) then
        local ph = self:GetPhysicsObject()
        if IsValid(ph) then
            local ov = data.OurOldVelocity or ph:GetVelocity()
            local v = Vector(ov.x, ov.y, ov.z)
            if n then
                local vn = v.x * n.x + v.y * n.y + v.z * n.z
                if vn < 0 then
                    v.x = v.x - n.x * vn
                    v.y = v.y - n.y * vn
                    v.z = v.z - n.z * vn
                end
                v.x = v.x - n.x * 70
                v.y = v.y - n.y * 70
                v.z = v.z - n.z * 12
                ph:SetVelocity(v)
                ph:SetPos(ph:GetPos() - n * 6)
            else
                ph:SetVelocity(v)
            end
        end
        return
    end
    local surf = self.Surf
    local tiny = !IsValid(surf) or !surf.Blobs or #surf.Blobs < 10
    if tiny and (!n or n.z > 0.55) then
        local ph = self:GetPhysicsObject()
        if IsValid(ph) then
            local v = ph:GetVelocity()
            if v.z > 18 then
                v.z = v.z * 0.06
                ph:SetVelocity(v)
            end
        end
    end
    if spd > 80 and !floorHit then
        local their = data.TheirOldVelocity
        local ours = data.OurOldVelocity
        local kick
        if their and their:LengthSqr() > 900 then
            kick = their
        elseif ours and ours:LengthSqr() > 400 then
            kick = ours
        elseif n then
            kick = Vector(-n.x, -n.y, -n.z) * spd
        end
        if kick then
            self._hitKick = kick
            self._hitKickT = CurTime() + 0.4
            if IsValid(surf) then
                surf._dmgKick = kick
                surf._dmgKickT = CurTime() + 0.4
            end
        end
    end
    if !floorHit and spd > 110 and (self._splashT or 0) < CurTime() then
        self._splashT = CurTime() + 0.45
        local vol = spd / 900
        if vol > 0.4 then vol = 0.4 elseif vol < 0.12 then vol = 0.12 end
        sound.Play("player/footsteps/slosh" .. math.random(1, 4) .. ".wav", data.HitPos, 58, math.random(88, 112), vol)
    end
end

function ENT:OnRemove()
    if SERVER then
        NPC_SURFACE.UnregBlob(self)
        return
    end
    local t = NPC_SURFACE.ClientBlobs
    if !t then return end
    for i = 1, #t do
        if t[i] == self then
            t[i] = t[#t]
            t[#t] = nil
            return
        end
    end
end

function ENT:Think()
    if CLIENT then
        self:SetNextClientThink(CurTime())
        return true
    end
end

function ENT:Draw()
end

function ENT:UpdateTransmitState()
    return TRANSMIT_PVS
end
