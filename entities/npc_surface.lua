AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Surface Slime"
ENT.Author = ""
ENT.Category = "NPCs"
ENT.Spawnable = false
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_OTHER

function ENT:Initialize()
    if CLIENT then
        self:SetNoDraw(true)
        return
    end
    self:SetModel("models/props_junk/PopCan01a.mdl")
    self:SetSolid(SOLID_NONE)
    self:SetMoveType(MOVETYPE_NONE)
    self:DrawShadow(false)
    self:SetCollisionGroup(COLLISION_GROUP_NONE)
    self:SetNoDraw(true)
    self.Blobs = {}
    self.IsGel = false
    NPC_SURFACE.RegManager(self)
    if !self.SkipSpawn then
        local n = NPC_SURFACE.ClusterSize and NPC_SURFACE.ClusterSize() or NPC_SURFACE.NUM
        self.FreeSpawn = true
        NPC_SURFACE.SpawnRing(self, n, 38)
        self.FreeSpawn = nil
    end
end

function ENT:Think()
    if SERVER then
        NPC_SURFACE.Sim(self)
        self:NextThink(CurTime())
        return true
    end
end

function ENT:OnRemove()
    if CLIENT then return end
    NPC_SURFACE.UnregManager(self)
    local t = self.Blobs
    if !t then return end
    for i = 1, #t do
        local b = t[i]
        if IsValid(b) then
            b.Surf = nil
            b:Remove()
        end
    end
    self.Blobs = {}
end

function ENT:Draw()
end

function ENT:UpdateTransmitState()
    return TRANSMIT_PVS
end
