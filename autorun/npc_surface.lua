AddCSLuaFile("npc_surface/sh_const.lua")
AddCSLuaFile("npc_surface/cl_tables.lua")
AddCSLuaFile("npc_surface/cl_mesh.lua")

include("npc_surface/sh_const.lua")

if SERVER then
    include("npc_surface/sv_sim.lua")
    for i = 1, 4 do
        util.PrecacheSound("player/footsteps/slosh"..i..".wav")
        util.PrecacheSound("ambient/water/drip"..i..".wav")
    end
    for i = 1, 3 do
        util.PrecacheSound("ambient/water/water_splash"..i..".wav")
    end
end

if CLIENT then
    include("npc_surface/cl_tables.lua")
    include("npc_surface/cl_mesh.lua")
end

list.Set("NPC", "npc_surface", {
    Name = "npc_surface",
    Class = "npc_surface",
    Category = "#spawnmenu.category.zombies_aliens"
})

hook.Add("ShouldCollide", "npc_surface_pass", function(a, b)
    local ab, bb = a.IsSurfBlob, b.IsSurfBlob
    if !ab and !bb then return end
    if ab and bb then return false end
    if a.SurfTrap or b.SurfTrap then return false end
    local other = ab and b or a
    if other:IsPlayer() or other:IsNPC() or (other.IsNextBot and other:IsNextBot()) then
        return false
    end
    if NPC_SURFACE.BulletsPassEnt and NPC_SURFACE.BulletsPassEnt(other) then
        return false
    end
end)

local function muteTileShot(pos)
    local C = NPC_SURFACE
    if !C then return false end
    if (C.MuteShotSoundUntil or 0) > CurTime() then
        local mp = C.MuteShotSoundPos
        if !mp or !pos then return true end
        local dx, dy, dz = pos.x - mp.x, pos.y - mp.y, pos.z - mp.z
        return dx * dx + dy * dy + dz * dz < 220 * 220
    end
    return pos and C.NearBlob and C.NearBlob(pos, 86)
end

hook.Add("EntityFireBullets", "npc_surface_quietshot", function(ent, data)
    local C = NPC_SURFACE
    if !C or !C.NearBlob then return end
    local t = SERVER and C.Blobs or C.ClientBlobs
    if !t or #t == 0 then return end
    local src, dir = data.Src, data.Dir
    if !src or !dir then return end
    local tr = util.TraceLine({
        start = src,
        endpos = src + dir * 2048,
        mask = MASK_SHOT,
        filter = ent
    })
    if tr.Hit and C.NearBlob(tr.HitPos, 86) then
        C.MuteShotSoundUntil = CurTime() + 0.14
        C.MuteShotSoundPos = tr.HitPos
    end
end)

hook.Add("EntityEmitSound", "npc_surface_quiet", function(data)
    local e = data.Entity
    if IsValid(e) then
        local c = e:GetClass()
        if c == "npc_surface_blob" or c == "npc_surface_fleck" then
            return false
        end
    end
    local n = string.lower(tostring(data.SoundName or "") .. " " .. tostring(data.OriginalSoundName or ""))
    local pos = data.Pos
    if (!pos or pos:LengthSqr() < 1) and IsValid(e) and !e:IsWorld() then
        pos = e:GetPos()
    end
    local tile = n:find("tile", 1, true) or n:find("ceramic", 1, true) or n:find("ceiling", 1, true)
    local shot = n:find("impact", 1, true) or n:find("bullet", 1, true) or n:find("ricochet", 1, true)
    if tile and shot and muteTileShot(pos) then
        return false
    end
    if shot or n:find("physics", 1, true) or n:find("dirt", 1, true) or n:find("sand", 1, true) or n:find("dust", 1, true) or n:find("concrete", 1, true) or n:find("grass", 1, true) then
        if muteTileShot(pos) then
            return false
        end
    end
end)

if CLIENT then
    hook.Add("AddToolMenuCategories", "npc_surface", function()
        spawnmenu.AddToolCategory("Utilities", "NPCSurface", "NPC Surface")
    end)
    hook.Add("PopulateToolMenu", "npc_surface", function()
        spawnmenu.AddToolMenuOption("Utilities", "NPCSurface", "npc_surface_vis", "NPC Surface", "", "", function(p)
            p:ClearControls()
            p:Help("Visual")
            p:CheckBox("Multicolor", "npc_surface_multicolor")
            p:CheckBox("Jelly forming", "npc_surface_jelly")
            p:CheckBox("Jelly on clusters", "npc_surface_jelly_cluster")
            p:ControlHelp("Lone: full squash/stretch. Clusters: softer per-chunk jelly on piles.")
            p:NumSlider("Mesh Hz", "npc_surface_hz", 20, 180, 0)
            local mix = vgui.Create("DColorMixer")
            mix:SetPalette(true)
            mix:SetAlphaBar(false)
            mix:SetWangs(true)
            mix:SetTall(140)
            mix:SetColor(Color(
                math.floor(GetConVarNumber("npc_surface_col_r") or 86),
                math.floor(GetConVarNumber("npc_surface_col_g") or 170),
                math.floor(GetConVarNumber("npc_surface_col_b") or 208)
            ))
            mix.ValueChanged = function(_, c)
                RunConsoleCommand("npc_surface_col_r", tostring(math.floor(c.r + 0.5)))
                RunConsoleCommand("npc_surface_col_g", tostring(math.floor(c.g + 0.5)))
                RunConsoleCommand("npc_surface_col_b", tostring(math.floor(c.b + 0.5)))
            end
            p:AddItem(mix)
            p:Help("Movement")
            p:NumSlider("Speed", "npc_surface_speed", 20, 200, 0)
            p:NumSlider("HP multiplier", "npc_surface_hp", 0.25, 4, 2)
            p:NumSlider("Nearby radius", "npc_surface_near_dist", 200, 2000, 0)
            p:Help("AI")
            p:CheckBox("Always chase player", "npc_surface_always_chase")
        end)
    end)
end

