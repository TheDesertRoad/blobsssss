AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Surface Fleck"
ENT.Category = "Fun"
ENT.Spawnable = false
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_OTHER
ENT.DisableDuplicator = true

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "GelR")
    self:NetworkVar("Int", 1, "GelG")
    self:NetworkVar("Int", 2, "GelB")
    self:NetworkVar("Float", 0, "Seed")
    self:NetworkVar("Float", 1, "Sz")
    self:NetworkVar("Bool", 0, "Loop")
end

local function addClientFleck(self)
    self.IsSurfFleck = true
    local t = NPC_SURFACE.ClientFlecks
    if !t then
        t = {}
        NPC_SURFACE.ClientFlecks = t
    end
    for i = 1, #t do
        if t[i] == self then return end
    end
    t[#t + 1] = self
    self:SetNoDraw(true)
    self:RemoveEffects(EF_NODRAW)
    self:SetRenderMode(RENDERMODE_NORMAL)
    self:DrawShadow(false)
end

function ENT:Initialize()
    self.Born = CurTime()
    self.IsSurfFleck = true
    if CLIENT then
        addClientFleck(self)
        return
    end
    local stay = self.LaunchVel == nil
    local sc = self.SzMul or 1.6
    if sc < 0.4 then sc = 0.4 end
    self:SetLoop(stay)
    self.DieAt = stay and math.huge or (CurTime() + math.Rand(0.22, 0.42))
    self:SetModel("models/hunter/misc/sphere025x025.mdl")
    self:PhysicsInitSphere(stay and 3.2 or (1.1 + sc * 0.85), "gmod_silent")
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    self:DrawShadow(false)
    self:SetNoDraw(true)
    self:AddEffects(EF_NODRAW)
    self:SetRenderMode(RENDERMODE_NONE)
    self:SetCustomCollisionCheck(true)
    if self:GetSeed() == 0 then
        self:SetSeed(math.Rand(0.2, 80))
    end
    local C = NPC_SURFACE
    if C and self:GetGelR() == 0 and self:GetGelG() == 0 and self:GetGelB() == 0 then
        self:SetGelR(C.COL_R)
        self:SetGelG(C.COL_G)
        self:SetGelB(C.COL_B)
    end
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        local damp = stay and 2.4 or (self.DampLin or math.Rand(0.12, 0.9))
        local drag = stay and 5 or (self.DragMul or math.Rand(0.55, 2.4))
        phys:SetMass(stay and 1.6 or math.Rand(0.18, 0.7) * sc)
        phys:SetMaterial("gmod_silent")
        phys:SetDamping(damp, stay and 2.8 or (damp * 1.2 + 0.12))
        phys:EnableGravity(!stay)
        phys:EnableDrag(true)
        phys:SetDragCoefficient(drag)
        phys:Wake()
        if stay then
            phys:EnableMotion(true)
            phys:SetVelocity(VectorRand() * 14)
            phys:AddAngleVelocity(Vector(70, 110, 40))
            self.HoverZ = self:GetPos().z + 12
        elseif self.LaunchVel then
            phys:SetVelocity(self.LaunchVel)
            phys:AddAngleVelocity(VectorRand() * (140 + math.Rand(0, 420)))
        end
    end
    self:CollisionRulesChanged()
end

function ENT:PhysicsCollide(data)
    if CLIENT then return end
    if self:GetLoop() then return end
    local spd = data.Speed or 0
    local C = NPC_SURFACE
    if spd > 48 and C and C.WaterHit then
        local n = data.HitNormal
        C.WaterHit(data.HitPos or self:GetPos(), spd, self, n and n.z > 0.55)
    end
    self:Remove()
end

function ENT:Think()
    if CLIENT then return end
    if CurTime() >= (self.DieAt or 0) then
        self:Remove()
        return
    end
    if self:GetLoop() then
        local ph = self:GetPhysicsObject()
        if IsValid(ph) then
            local p = self:GetPos()
            local v = ph:GetVelocity()
            local want = self.HoverZ or (p.z + 12)
            local t = CurTime()
            local mass = ph:GetMass()
            ph:Wake()
            ph:ApplyForceCenter(Vector(
                (math.sin(t * 0.7) * 16 - v.x) * mass * 1.3,
                (math.cos(t * 0.55) * 14 - v.y) * mass * 1.3,
                ((want - p.z) * 10 - v.z * 3) * mass
            ))
        end
        self:NextThink(CurTime())
        return true
    end
    self:NextThink(CurTime() + 0.04)
    return true
end

function ENT:OnRemove()
    if SERVER then
        if self._counted then
            local C = NPC_SURFACE
            if C then
                C.FleckN = math.max(0, (C.FleckN or 1) - 1)
            end
        end
        return
    end
    local t = NPC_SURFACE.ClientFlecks
    if !t then return end
    for i = 1, #t do
        if t[i] == self then
            t[i] = t[#t]
            t[#t] = nil
            return
        end
    end
end

function ENT:Draw()
end

function ENT:UpdateTransmitState()
    return TRANSMIT_PVS
end
