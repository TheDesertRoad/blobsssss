NPC_SURFACE = NPC_SURFACE or {}
local C = NPC_SURFACE

local sqrt, min, max, abs, floor, sin, cos, atan2 = math.sqrt, math.min, math.max, math.abs, math.floor, math.sin, math.cos, math.atan2
local band = bit.band
local EyePos, IsValid, FrameNumber, RealTime = EyePos, IsValid, FrameNumber, RealTime
local Vector, Color, mesh, render = Vector, Color, mesh, render
local MeshCtor = Mesh

local EDGE, TRI, mat
local vP, vN, vT = Vector(), Vector(), Vector()

local UX, UY, UZ = {}, {}, {}
local NX, NY, NZ = {}, {}, {}
local CR, CG, CB, CA = {}, {}, {}, {}
local UU, VV = {}, {}
local TX, TY, TZ = {}, {}, {}
local IX = {}
local nUnique, nIdx = 0, 0

local lastN = 0
local spx, spy, spz = {}, {}, {}
local scr, scg, scb = {}, {}, {}
local spr, sfl, sent = {}, {}, {}
local sux, suy, sst, ssq, szs = {}, {}, {}, {}, {}
local lpx, lpy, lpz = {}, {}, {}
local nSamp = 0
local lastBR, lastBG, lastBB = 86, 170, 208

local GW, GH, GD = 56, 56, 56
local GWH = GW * GH
local GSIZE = GW * GH * GD
local gVal, gR, gG, gB, gW = {}, {}, {}, {}, {}
local writeGen, cubeGen, nGen = {}, {}, {}
local NXG, NYG, NZG, NCR, NCG, NCB = {}, {}, {}, {}, {}, {}
local written, active = {}, {}
local nWritten, nActive = 0, 0
local gen = 1

local eStamp, eVid, edgeKeys = {}, {}, {}
local nEdgeClear = 0

local EBIT = { 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048 }
local CX = {0, 1, 1, 0, 0, 1, 1, 0}
local CY = {0, 0, 1, 1, 0, 0, 1, 1}
local CZ = {0, 0, 0, 0, 1, 1, 1, 1}
local EA = {0, 1, 0, 1, 0, 1, 0, 1, 2, 2, 2, 2}
local EX = {0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0}
local EY = {0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1}
local EZ = {0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0}
local EC0 = {0, 1, 2, 3, 4, 5, 6, 7, 0, 1, 2, 3}
local EC1 = {1, 2, 3, 0, 5, 6, 7, 4, 4, 5, 6, 7}

local ppx, ppy, ppz, pcr, pcg, pcb = {}, {}, {}, {}, {}, {}
local pR, pR2, pInv = {}, {}, {}
local pux, puy, pst, psq, pzs = {}, {}, {}, {}, {}
local pn, infR, infR2, invR2 = 0, 27, 729, 1 / 729
local clipX0, clipX1, clipY0, clipY1, clipZ0, clipZ1
local parent, rank = {}, {}
local cv = {0, 0, 0, 0, 0, 0, 0, 0}
local ev = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}

local tmp, seen, rlist, lonerIdx = {}, {}, {}, {}
local idxCap = 48000 * 3
local partA, partB = {}, {}

local useIMesh = true
local meshes, meshN = {}, {}
local nMeshes = 0
local CHUNK_VERTS = 4096 * 3
local vbuf, chunk = {}, {}
local bakedAlpha = 255
local bakeTrans = false
local lastQ, lastTrans, lastJelly, lastJellyCluster = -1, nil, nil, nil
local lastFrame, lastBuild = -1, 0
local lastIdSum, needBuild = 0, false

C.ClientBlobs = C.ClientBlobs or {}
C.ClientFlecks = C.ClientFlecks or {}

do
    for i = 1, GSIZE do
        gVal[i], gR[i], gG[i], gB[i], gW[i] = 0, 0, 0, 0, 0
        writeGen[i], cubeGen[i], nGen[i] = 0, 0, 0
    end
end

local function haveIMesh()
    if !useIMesh then return false end
    if !MeshCtor then
        useIMesh = false
        return false
    end
    return true
end

local function killMesh(i)
    local m = meshes[i]
    if !m then
        meshN[i] = nil
        return
    end
    pcall(function()
        if m.Destroy then m:Destroy() end
    end)
    meshes[i] = nil
    meshN[i] = nil
end

local function killAllMeshes()
    for i = 1, math.max(nMeshes, #meshes) do
        killMesh(i)
    end
    nMeshes = 0
end

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

local function gIndex(ix, iy, iz)
    return 1 + ix + iy * GW + iz * GWH
end

local function gridVal(ix, iy, iz)
    if ix < 0 or iy < 0 or iz < 0 or ix >= GW or iy >= GH or iz >= GD then
        return 0
    end
    local k = gIndex(ix, iy, iz)
    if writeGen[k] ~= gen then
        return 0
    end
    return gVal[k]
end

local function cornerShade(ix, iy, iz)
    if ix < 0 or iy < 0 or iz < 0 or ix >= GW or iy >= GH or iz >= GD then
        return 0, 0, 1, C.COL_R, C.COL_G, C.COL_B
    end
    local k = gIndex(ix, iy, iz)
    if nGen[k] == gen then
        return NXG[k], NYG[k], NZG[k], NCR[k], NCG[k], NCB[k]
    end
    local dx = gridVal(ix + 1, iy, iz) - gridVal(ix - 1, iy, iz)
    local dy = gridVal(ix, iy + 1, iz) - gridVal(ix, iy - 1, iz)
    local dz = gridVal(ix, iy, iz + 1) - gridVal(ix, iy, iz - 1)
    local len = sqrt(dx * dx + dy * dy + dz * dz)
    if len > 1e-8 then
        local inv = -1 / len
        dx, dy, dz = dx * inv, dy * inv, dz * inv
    else
        dx, dy, dz = 0, 0, 1
    end
    local r, g, b = C.COL_R, C.COL_G, C.COL_B
    if writeGen[k] == gen then
        local w = gW[k]
        if w > 1e-8 then
            local inv = 1 / w
            r, g, b = gR[k] * inv, gG[k] * inv, gB[k] * inv
        end
    end
    nGen[k] = gen
    NXG[k], NYG[k], NZG[k] = dx, dy, dz
    NCR[k], NCG[k], NCB[k] = r, g, b
    return dx, dy, dz, r, g, b
end

local function markCube(ix, iy, iz)
    if ix < 0 or iy < 0 or iz < 0 then return end
    if ix >= GW - 1 or iy >= GH - 1 or iz >= GD - 1 then return end
    local ck = gIndex(ix, iy, iz)
    if cubeGen[ck] == gen then return end
    cubeGen[ck] = gen
    nActive = nActive + 1
    active[nActive] = ck
end

local function bumpGen()
    gen = gen + 1
    if gen > 2000000000 then
        gen = 1
        for i = 1, GSIZE do
            writeGen[i], cubeGen[i], nGen[i] = 0, 0, 0
        end
    end
    for i = 1, nEdgeClear do
        local k = edgeKeys[i]
        eStamp[k] = nil
        eVid[k] = nil
    end
    nEdgeClear, nWritten, nActive = 0, 0, 0
end

local function splatField(nidx, ox, oy, oz, cell)
    local iso = C.ISO
    local near = iso * 2.2
    for i = 1, nidx do
        local x, y, z = ppx[i], ppy[i], ppz[i]
        local cr, cg, cb = pcr[i], pcg[i], pcb[i]
        local R = pR[i]
        local R2 = pR2[i]
        local inv = pInv[i]
        local st = pst[i] or 1
        local sq = psq[i] or 1
        local zs = pzs[i] or 1
        local ax, ay = pux[i] or 0, puy[i] or 1
        local aniso = abs(st - 1) > 0.05 or abs(sq - 1) > 0.05 or abs(zs - 1) > 0.08
        local Rm = R
        if aniso then
            Rm = R * st
            if R / sq > Rm then Rm = R / sq end
            if R * zs > Rm then Rm = R * zs end
        end
        local x0 = floor((x - Rm - ox) / cell)
        local x1 = floor((x + Rm - ox) / cell)
        local y0 = floor((y - Rm - oy) / cell)
        local y1 = floor((y + Rm - oy) / cell)
        local z0 = floor((z - Rm - oz) / cell)
        local z1 = floor((z + Rm - oz) / cell)
        if x0 < 0 then x0 = 0 end
        if y0 < 0 then y0 = 0 end
        if z0 < 0 then z0 = 0 end
        if x1 > GW - 1 then x1 = GW - 1 end
        if y1 > GH - 1 then y1 = GH - 1 end
        if z1 > GD - 1 then z1 = GD - 1 end
        if aniso then
            for iz = z0, z1 do
                local dz = (oz + iz * cell) - z
                local dzz = dz / zs
                local dz2 = dzz * dzz
                if dz2 < R2 then
                    for iy = y0, y1 do
                        local dy = (oy + iy * cell) - y
                        for ix = x0, x1 do
                            local dx = (ox + ix * cell) - x
                            local along = dx * ax + dy * ay
                            local px = dx - ax * along
                            local py = dy - ay * along
                            local d2 = (along * along) / (st * st) + (px * px + py * py) / (sq * sq) + dz2
                            if d2 < R2 then
                                local t = 1 - d2 * inv
                                local w = t * t
                                local k = gIndex(ix, iy, iz)
                                if writeGen[k] ~= gen then
                                    writeGen[k] = gen
                                    gVal[k] = w
                                    gR[k], gG[k], gB[k], gW[k] = cr * w, cg * w, cb * w, w
                                    nWritten = nWritten + 1
                                    written[nWritten] = k
                                else
                                    gVal[k] = gVal[k] + w
                                    gR[k] = gR[k] + cr * w
                                    gG[k] = gG[k] + cg * w
                                    gB[k] = gB[k] + cb * w
                                    gW[k] = gW[k] + w
                                end
                            end
                        end
                    end
                end
            end
        else
            for iz = z0, z1 do
                local dz = (oz + iz * cell) - z
                local dz2 = dz * dz
                if dz2 < R2 then
                    for iy = y0, y1 do
                        local dy = (oy + iy * cell) - y
                        local dy2 = dy * dy
                        for ix = x0, x1 do
                            local dx = (ox + ix * cell) - x
                            local d2 = dx * dx + dy2 + dz2
                            if d2 < R2 then
                                local t = 1 - d2 * inv
                                local w = t * t
                                local k = gIndex(ix, iy, iz)
                                if writeGen[k] ~= gen then
                                    writeGen[k] = gen
                                    gVal[k] = w
                                    gR[k], gG[k], gB[k], gW[k] = cr * w, cg * w, cb * w, w
                                    nWritten = nWritten + 1
                                    written[nWritten] = k
                                else
                                    gVal[k] = gVal[k] + w
                                    gR[k] = gR[k] + cr * w
                                    gG[k] = gG[k] + cg * w
                                    gB[k] = gB[k] + cb * w
                                    gW[k] = gW[k] + w
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    for i = 1, nWritten do
        local k = written[i]
        if gVal[k] < near then
            local t = k - 1
            local ix = t % GW
            local iy = floor(t / GW) % GH
            local iz = floor(t / GWH)
            markCube(ix, iy, iz)
            markCube(ix - 1, iy, iz)
            markCube(ix, iy - 1, iz)
            markCube(ix, iy, iz - 1)
            markCube(ix - 1, iy - 1, iz)
            markCube(ix - 1, iy, iz - 1)
            markCube(ix, iy - 1, iz - 1)
            markCube(ix - 1, iy - 1, iz - 1)
        end
    end
end

local function edgeVert(ix, iy, iz, e, ox, oy, oz, cell, iso)
    local k = EA[e] + (ix + EX[e]) * 4 + (iy + EY[e]) * (GW * 4) + (iz + EZ[e]) * (GWH * 4)
    if eStamp[k] == gen then return eVid[k] end
    local a, b = EC0[e] + 1, EC1[e] + 1
    local v1, v2 = cv[a], cv[b]
    local x1 = ox + (ix + CX[a]) * cell
    local y1 = oy + (iy + CY[a]) * cell
    local z1 = oz + (iz + CZ[a]) * cell
    local x2 = ox + (ix + CX[b]) * cell
    local y2 = oy + (iy + CY[b]) * cell
    local z2 = oz + (iz + CZ[b]) * cell
    local dv = v2 - v1
    local mu = abs(dv) < 1e-8 and 0.5 or (iso - v1) / dv
    if mu < 0 then mu = 0 elseif mu > 1 then mu = 1 end
    local x = x1 + (x2 - x1) * mu
    local y = y1 + (y2 - y1) * mu
    local z = z1 + (z2 - z1) * mu
    local ax, ay, az = ix + CX[a], iy + CY[a], iz + CZ[a]
    local bx, by, bz = ix + CX[b], iy + CY[b], iz + CZ[b]
    local nax, nay, naz, ra, ga, ba = cornerShade(ax, ay, az)
    local nbx, nby, nbz, rb, gb, bb = cornerShade(bx, by, bz)
    local nx = nax + (nbx - nax) * mu
    local ny = nay + (nby - nay) * mu
    local nz = naz + (nbz - naz) * mu
    local len = sqrt(nx * nx + ny * ny + nz * nz)
    if len > 1e-8 then
        local inv = 1 / len
        nx, ny, nz = nx * inv, ny * inv, nz * inv
    end
    local r = ra + (rb - ra) * mu
    local g = ga + (gb - ga) * mu
    local bl = ba + (bb - ba) * mu
    local ndot = max(0, nx * 0.16 + ny * 0.12 + nz * 0.86)
    local lit = 0.78 + 0.22 * ndot
    r = min(255, r * lit)
    g = min(255, g * lit)
    bl = min(255, bl * lit)
    nUnique = nUnique + 1
    local id = nUnique
    UX[id], UY[id], UZ[id] = x, y, z
    NX[id], NY[id], NZ[id] = nx, ny, nz
    CR[id], CG[id], CB[id] = floor(r + 0.5), floor(g + 0.5), floor(bl + 0.5)
    CA[id] = bakedAlpha
    eStamp[k], eVid[k] = gen, id
    nEdgeClear = nEdgeClear + 1
    edgeKeys[nEdgeClear] = k
    return id
end

local function march(idxs, nidx, cell, infMul, marchDepth)
    if nidx < 1 then return end
    pn = nidx
    infMul = infMul or 2
    local minx, miny, minz = 1e12, 1e12, 1e12
    local maxx, maxy, maxz = -1e12, -1e12, -1e12
    local maxR = 0
    for i = 1, nidx do
        local s = idxs[i]
        local x, y, z = spx[s], spy[s], spz[s]
        ppx[i], ppy[i], ppz[i] = x, y, z
        pcr[i], pcg[i], pcb[i] = scr[s], scg[s], scb[s]
        pux[i], puy[i] = sux[s] or 0, suy[s] or 1
        pst[i], psq[i], pzs[i] = sst[s] or 1, ssq[s] or 1, szs[s] or 1
        local R = (spr[s] or C.RADIUS) * infMul
        pR[i] = R
        pR2[i] = R * R
        pInv[i] = 1 / (R * R)
        if R > maxR then maxR = R end
        if x < minx then minx = x end
        if y < miny then miny = y end
        if z < minz then minz = z end
        if x > maxx then maxx = x end
        if y > maxy then maxy = y end
        if z > maxz then maxz = z end
    end
    infR = maxR
    infR2 = maxR * maxR
    invR2 = maxR > 1e-8 and (1 / infR2) or 1
    local pad = infR + cell
    local ox, oy, oz = minx - pad, miny - pad, minz - pad
    local sx = (maxx - minx) + pad * 2
    local sy = (maxy - miny) + pad * 2
    local sz = (maxz - minz) + pad * 2
    local need = sx / (GW - 2)
    local ny = sy / (GH - 2)
    local nz = sz / (GD - 2)
    if ny > need then need = ny end
    if nz > need then need = nz end
    local depth = marchDepth or 0
    if need > cell * 1.22 and depth < 5 then
        local na, nb = 0, 0
        local overlap = infR * 1.05
        local axis, mid = 1, (minx + maxx) * 0.5
        if sy >= sx and sy >= sz then
            axis, mid = 2, (miny + maxy) * 0.5
        elseif sz >= sx and sz >= sy then
            axis, mid = 3, (minz + maxz) * 0.5
        end
        for i = 1, nidx do
            local s = idxs[i]
            local v = axis == 1 and spx[s] or (axis == 2 and spy[s] or spz[s])
            if v < mid + overlap then
                na = na + 1
                partA[na] = s
            end
            if v >= mid - overlap then
                nb = nb + 1
                partB[nb] = s
            end
        end
        if na > 0 and nb > 0 and na < nidx and nb < nidx then
            local ox0, ox1, oy0, oy1, oz0, oz1 = clipX0, clipX1, clipY0, clipY1, clipZ0, clipZ1
            if !clipX0 then
                ox0, ox1 = -1e12, 1e12
                oy0, oy1 = -1e12, 1e12
                oz0, oz1 = -1e12, 1e12
            end
            local A, B = {}, {}
            for i = 1, na do A[i] = partA[i] end
            for i = 1, nb do B[i] = partB[i] end
            if axis == 1 then
                clipX0, clipX1, clipY0, clipY1, clipZ0, clipZ1 = ox0, mid, oy0, oy1, oz0, oz1
                march(A, na, cell, infMul, depth + 1)
                clipX0, clipX1 = mid, ox1
                march(B, nb, cell, infMul, depth + 1)
            elseif axis == 2 then
                clipX0, clipX1, clipY0, clipY1, clipZ0, clipZ1 = ox0, ox1, oy0, mid, oz0, oz1
                march(A, na, cell, infMul, depth + 1)
                clipY0, clipY1 = mid, oy1
                march(B, nb, cell, infMul, depth + 1)
            else
                clipX0, clipX1, clipY0, clipY1, clipZ0, clipZ1 = ox0, ox1, oy0, oy1, oz0, mid
                march(A, na, cell, infMul, depth + 1)
                clipZ0, clipZ1 = mid, oz1
                march(B, nb, cell, infMul, depth + 1)
            end
            clipX0, clipX1, clipY0, clipY1, clipZ0, clipZ1 = ox0, ox1, oy0, oy1, oz0, oz1
            if !ox0 or ox0 < -1e11 then
                clipX0, clipX1, clipY0, clipY1, clipZ0, clipZ1 = nil, nil, nil, nil, nil, nil
            end
            return
        end
    end
    if need > cell * 1.22 then
        cell = need
        pad = infR + cell
        ox, oy, oz = minx - pad, miny - pad, minz - pad
    end
    bumpGen()
    splatField(nidx, ox, oy, oz, cell)
    local iso = C.ISO
    for ci = 1, nActive do
        if nIdx >= idxCap then break end
        local ck = active[ci] - 1
        local ix = ck % GW
        local iy = floor(ck / GW) % GH
        local iz = floor(ck / GWH)
        cv[1] = gridVal(ix,     iy,     iz)
        cv[2] = gridVal(ix + 1, iy,     iz)
        cv[3] = gridVal(ix + 1, iy + 1, iz)
        cv[4] = gridVal(ix,     iy + 1, iz)
        cv[5] = gridVal(ix,     iy,     iz + 1)
        cv[6] = gridVal(ix + 1, iy,     iz + 1)
        cv[7] = gridVal(ix + 1, iy + 1, iz + 1)
        cv[8] = gridVal(ix,     iy + 1, iz + 1)
        local idx = 0
        if cv[1] < iso then idx = idx + 1 end
        if cv[2] < iso then idx = idx + 2 end
        if cv[3] < iso then idx = idx + 4 end
        if cv[4] < iso then idx = idx + 8 end
        if cv[5] < iso then idx = idx + 16 end
        if cv[6] < iso then idx = idx + 32 end
        if cv[7] < iso then idx = idx + 64 end
        if cv[8] < iso then idx = idx + 128 end
        if idx ~= 0 and idx ~= 255 then
            if clipX0 then
                local wx = ox + (ix + 0.5) * cell
                local wy = oy + (iy + 0.5) * cell
                local wz = oz + (iz + 0.5) * cell
                if wx < clipX0 or wx >= clipX1 or wy < clipY0 or wy >= clipY1 or wz < clipZ0 or wz >= clipZ1 then
                    continue
                end
            end
            local et = EDGE[idx + 1]
            if et ~= 0 then
                for e = 1, 12 do
                    if band(et, EBIT[e]) ~= 0 then
                        ev[e] = edgeVert(ix, iy, iz, e, ox, oy, oz, cell, iso)
                    end
                end
                local base = idx * 16
                for t = 1, 16, 3 do
                    local a = TRI[base + t]
                    if a < 0 then break end
                    if nIdx >= idxCap then break end
                    nIdx = nIdx + 3
                    IX[nIdx - 2] = ev[a + 1]
                    IX[nIdx - 1] = ev[TRI[base + t + 2] + 1]
                    IX[nIdx]     = ev[TRI[base + t + 1] + 1]
                end
            end
        end
    end
end

local function ingest(src, fn, a, n, idSum, isFleck)
    if !src then return n, idSum end
    if !isFleck then
        a = 1
    end
    local w = 1
    for i = 1, #src do
        local e = src[i]
        if IsValid(e) then
            if w ~= i then src[w] = e end
            w = w + 1
            if e._surfPick == fn then continue end
            e._surfPick = fn
            e:SetNoDraw(true)
            e:RemoveEffects(EF_NODRAW)
            e:SetRenderMode(RENDERMODE_NORMAL)
            local rb = (isFleck and 12 or (C.RADIUS or 14)) * 4
            e:SetRenderBounds(Vector(-rb, -rb, -rb), Vector(rb, rb, rb))
            local p = e:GetPos()
            local rawx, rawy, rawz = p.x, p.y, p.z
            local dt = FrameTime()
            if dt < 0.008 then dt = 0.016 end
            local vx, vy, vz = 0, 0, 0
            if e._rx then
                vx = (rawx - e._rx) / dt
                vy = (rawy - e._ry) / dt
                vz = (rawz - e._rz) / dt
            end
            local ov = e:GetVelocity()
            if ov and ov:LengthSqr() > vx * vx + vy * vy then
                vx, vy, vz = ov.x, ov.y, ov.z
            end
            e._svx = (e._svx or 0) * 0.78 + vx * 0.22
            e._svy = (e._svy or 0) * 0.78 + vy * 0.22
            e._svz = (e._svz or 0) * 0.78 + vz * 0.22
            e._rx, e._ry, e._rz = rawx, rawy, rawz
            local x, y, z = rawx, rawy, rawz
            if a < 1 and e._ex then
                x = e._ex + (x - e._ex) * a
                y = e._ey + (y - e._ey) * a
                z = e._ez + (z - e._ez) * a
            end
            e._ex, e._ey, e._ez = x, y, z
            n = n + 1
            idSum = idSum + e:EntIndex()
            sent[n] = e
            spx[n], spy[n], spz[n] = x, y, z
            sfl[n] = isFleck
            sux[n], suy[n], sst[n], ssq[n], szs[n] = 0, 1, 1, 1, 1
            if isFleck then
                local sz = e.GetSz and e:GetSz() or 0
                if sz < 0.2 then sz = 2.35 end
                spr[n] = 2.2 + sz * 1.35
            else
                spr[n] = C.RADIUS
            end
            local r, g, b
            if isFleck then
                r, g, b = lastBR, lastBG, lastBB
                if e.GetGelR then
                    local fr, fg, fb = e:GetGelR(), e:GetGelG(), e:GetGelB()
                    if fr ~= 0 or fg ~= 0 or fb ~= 0 then
                        r, g, b = fr, fg, fb
                    end
                end
            else
                r, g, b = C.ReadColor()
                if C.MultiColor() and e.GetGelR then
                    local fr, fg, fb = e:GetGelR(), e:GetGelG(), e:GetGelB()
                    if fr ~= 0 or fg ~= 0 or fb ~= 0 then
                        r, g, b = fr, fg, fb
                    end
                end
                lastBR, lastBG, lastBB = r, g, b
            end
            scr[n], scg[n], scb[n] = r, g, b
        end
    end
    for i = w, #src do
        src[i] = nil
    end
    return n, idSum
end

local function applyJellyAt(n, i, mode, rt, dt)
    local R = C.RADIUS
    local loner = mode == "loner"
    local cluster = mode == "cluster"
    local strCap = loner and 0.34 or 0.14
    local jellyMax = loner and 1.42 or 1.16
    local jellyMin = loner and 0.88 or 0.94
    local turnSpd = loner and 0.72 or 0.28
    local spdGate = loner and 18 or 28
    local e = sent[i]
    local bx, by, bz = spx[i], spy[i], spz[i]
    local br, bg, bb = scr[i], scg[i], scb[i]
    local vx, vy, vz = 0, 0, 0
    local jux, juy, jelly, jv = 0, 1, 1, 0
    if IsValid(e) then
        vx, vy, vz = e._svx or 0, e._svy or 0, e._svz or 0
        jux, juy = e._jux or 0, e._juy or 1
        jelly, jv = e._jelly or 1, e._jvel or 0
    end
    local spd = sqrt(vx * vx + vy * vy)
    local ux, uy = jux, juy
    if spd > spdGate then
        local tx, ty = vx / spd, vy / spd
        local jd = atan2(ux * ty - uy * tx, ux * tx + uy * ty)
        local maxA = turnSpd * dt
        if jd > maxA then jd = maxA elseif jd < -maxA then jd = -maxA end
        local ca, sa = cos(jd), sin(jd)
        ux, uy = ux * ca - uy * sa, ux * sa + uy * ca
        local ul = sqrt(ux * ux + uy * uy)
        if ul > 0.08 then
            ux, uy = ux / ul, uy / ul
        end
    end
    local want = 1 + min(strCap, spd * (loner and 0.008 or 0.0035))
    jv = jv + (want - jelly) * (loner and 28 or 18) * dt - jv * (loner and 4.2 or 5.5) * dt
    jelly = jelly + jv * dt
    if jelly < jellyMin then jelly = jellyMin elseif jelly > jellyMax then jelly = jellyMax end
    if IsValid(e) then
        e._jux, e._juy = ux, uy
        e._jelly, e._jvel = jelly, jv
    end
    local stretch = jelly
    local squish = 1 / sqrt(stretch)
    local onFloor = abs(vz) < 52 and spd < 95
    local idle = spd < (loner and 22 or 32) and abs(jv) < (loner and 0.10 or 0.12) and stretch < (loner and 1.05 or 1.03)
    if idle then
        stretch, squish = 1, 1
        if IsValid(e) then
            e._jelly, e._jvel = 1, 0
        end
    else
        local seed = (IsValid(e) and e:EntIndex() or i) * 0.173
        local shake = sin(rt * 5.5 + seed * 10) * min(loner and 0.08 or 0.03, abs(jv) * 0.12 + spd * 0.0008)
        local rx, ry = -uy, ux
        ux, uy = ux + rx * shake, uy + ry * shake
        local ul = sqrt(ux * ux + uy * uy)
        if ul > 0.08 then
            ux, uy = ux / ul, uy / ul
        end
    end
    spx[i], spy[i], spz[i] = bx, by, bz - R * (onFloor and (loner and 0.04 or 0.02) or 0.01)
    spr[i] = R
    sux[i], suy[i] = ux, uy
    sst[i], ssq[i], szs[i] = stretch, squish, 1
    if loner and onFloor then
        n = n + 1
        sent[n], sfl[n] = e, false
        spx[n], spy[n], spz[n] = bx, by, bz - R * 0.18
        spr[n] = R * 0.38
        scr[n], scg[n], scb[n] = br, bg, bb
        sux[n], suy[n] = ux, uy
        sst[n], ssq[n], szs[n] = 1.04 * squish, 1.04 * squish, 0.58
    end
    if idle then return n end
    local seed = (IsValid(e) and e:EntIndex() or i) * 0.173
    local bulgeMul = loner and 1.2 or 0.55
    local bulge = (stretch - 1) * R * bulgeMul + abs(jv) * R * (loner and 0.12 or 0.04)
    local bulgeMin = loner and 0.06 or 0.10
    if bulge > R * bulgeMin and spd > (cluster and 28 or 14) then
        n = n + 1
        sent[n], sfl[n] = e, false
        spx[n] = bx + ux * bulge
        spy[n] = by + uy * bulge
        spz[n] = bz - R * 0.04 + sin(rt * 6.0 + seed) * min(loner and 1.2 or 0.6, bulge * 0.2)
        spr[n] = R * (loner and (0.30 + min(0.12, bulge / R)) or (0.24 + min(0.06, bulge / R)))
        scr[n], scg[n], scb[n] = br, bg, bb
        sux[n], suy[n] = ux, uy
        sst[n], ssq[n], szs[n] = loner and 1.08 or 1.04, loner and 0.94 or 0.97, loner and 0.9 or 0.95
    end
    local trailAt = loner and 1.10 or 1.08
    if stretch > trailAt and spd > (cluster and 36 or 16) then
        n = n + 1
        sent[n], sfl[n] = e, false
        local back = (stretch - 1) * R * (loner and 0.5 or 0.22)
        spx[n] = bx - ux * back
        spy[n] = by - uy * back
        spz[n] = bz - R * 0.08
        spr[n] = R * (loner and 0.36 or 0.28)
        scr[n], scg[n], scb[n] = br, bg, bb
        sux[n], suy[n] = ux, uy
        sst[n], ssq[n], szs[n] = loner and 0.92 or 0.96, loner and 1.1 or 1.04, 0.88
    end
    return n
end

local function countReal(n)
    local nReal = 0
    for i = 1, n do
        if !sfl[i] then nReal = nReal + 1 end
    end
    return nReal
end

local function expandLoners(n)
    if !C.JellyMesh or !C.JellyMesh() then return n end
    local nReal = countReal(n)
    if nReal < 1 or nReal > 8 then return n end
    local R = C.RADIUS
    local isoR2 = (R * 2.7) * (R * 2.7)
    local loners = lonerIdx
    local nL = 0
    for i = 1, n do
        if sfl[i] then continue end
        local alone = true
        for j = 1, n do
            if i ~= j and !sfl[j] then
                local dx, dy, dz = spx[i] - spx[j], spy[i] - spy[j], spz[i] - spz[j]
                if dx * dx + dy * dy + dz * dz < isoR2 then
                    alone = false
                    break
                end
            end
        end
        if alone then
            nL = nL + 1
            loners[nL] = i
        end
    end
    if nL < 1 then return n end
    local rt = RealTime()
    local dt = FrameTime()
    if dt < 0.008 then dt = 0.016 elseif dt > 0.05 then dt = 0.05 end
    for u = 1, nL do
        n = applyJellyAt(n, loners[u], "loner", rt, dt)
    end
    return n
end

local function expandCluster(n)
    if !C.JellyClusterMesh or !C.JellyClusterMesh() then return n end
    local nReal = countReal(n)
    if nReal < 9 then return n end
    local rt = RealTime()
    local dt = FrameTime()
    if dt < 0.008 then dt = 0.016 elseif dt > 0.05 then dt = 0.05 end
    for i = 1, n do
        if sfl[i] then continue end
        n = applyJellyAt(n, i, "cluster", rt, dt)
    end
    return n
end
local function gather()
    local a = C.EMA or 1
    local fn = FrameNumber()
    local n, idSum = 0, 0
    n, idSum = ingest(C.ClientBlobs, fn, a, n, idSum, false)
    n = expandLoners(n)
    n = expandCluster(n)
    n, idSum = ingest(C.ClientFlecks, fn, a, n, idSum, true)
    nSamp = n
    if n == lastN and lastN > 8 then
        local stick = 1.65 + min(1.8, (n - 8) * 0.045)
        for i = 1, n do
            if sfl[i] then continue end
            local dx, dy, dz = spx[i] - lpx[i], spy[i] - lpy[i], spz[i] - lpz[i]
            if abs(dx) <= stick and abs(dy) <= stick and abs(dz) <= stick then
                spx[i], spy[i], spz[i] = lpx[i], lpy[i], lpz[i]
            end
        end
    end
    if idSum ~= lastIdSum then
        needBuild = true
        lastIdSum = idSum
    end
    return n
end

local function moved(n)
    if n ~= lastN then return true end
    local eps = C.MOVE_EPS or 0.5
    local hits = 0
    local need = 1
    if n > 8 then
        need = max(3, floor(n * 0.16 + 0.5))
    end
    for i = 1, n do
        local dx, dy, dz = spx[i] - lpx[i], spy[i] - lpy[i], spz[i] - lpz[i]
        if abs(dx) > eps or abs(dy) > eps or abs(dz) > eps then
            hits = hits + 1
            if hits >= need then return true end
        end
    end
    return false
end

local function commit(n)
    lastN = n
    for i = 1, n do
        lpx[i], lpy[i], lpz[i] = spx[i], spy[i], spz[i]
    end
end

local function ensureVert(i)
    local v = vbuf[i]
    if v then return v end
    v = {
        pos = Vector(0, 0, 0),
        normal = Vector(0, 0, 0),
        tangent = Vector(1, 0, 0),
        userdata = {1, 0, 0, 1},
        u = 0,
        v = 0,
        color = Color(255, 255, 255, 255)
    }
    vbuf[i] = v
    return v
end

local function fillVert(slot, id, a)
    local v = ensureVert(slot)
    v.pos.x, v.pos.y, v.pos.z = UX[id], UY[id], UZ[id]
    v.normal.x, v.normal.y, v.normal.z = NX[id], NY[id], NZ[id]
    local tan = v.tangent
    tan.x, tan.y, tan.z = TX[id] or 1, TY[id] or 0, TZ[id] or 0
    local ud = v.userdata
    if !ud then
        ud = {tan.x, tan.y, tan.z, 1}
        v.userdata = ud
    else
        ud[1], ud[2], ud[3], ud[4] = tan.x, tan.y, tan.z, 1
    end
    v.u, v.v = UU[id] or 0, VV[id] or 0
    v.color = Color(CR[id] or 86, CG[id] or 170, CB[id] or 208, CA[id] or a)
    return v
end

local function newMesh()
    local ok, obj = pcall(MeshCtor)
    if ok and obj then return obj end
    useIMesh = false
    return nil
end

local function upload(a)
    if nIdx < 3 then
        killAllMeshes()
        return
    end
    if !haveIMesh() then
        killAllMeshes()
        return
    end
    local ci = 0
    local i = 1
    while i <= nIdx do
        local remain = nIdx - i + 1
        if remain > CHUNK_VERTS then remain = CHUNK_VERTS - (CHUNK_VERTS % 3) end
        ci = ci + 1
        local nv = 0
        local last = i + remain - 1
        for j = i, last do
            nv = nv + 1
            chunk[nv] = fillVert(nv, IX[j], a)
        end
        for k = nv + 1, #chunk do
            chunk[k] = nil
        end
        local m = meshes[ci]
        if m and meshN[ci] ~= nv then
            killMesh(ci)
            m = nil
        end
        if !m then
            m = newMesh()
            if !m then
                killAllMeshes()
                return
            end
            meshes[ci] = m
        end
        local ok = pcall(m.BuildFromTriangles, m, chunk)
        if !ok then
            killMesh(ci)
            m = newMesh()
            if !m then
                killAllMeshes()
                return
            end
            meshes[ci] = m
            ok = pcall(m.BuildFromTriangles, m, chunk)
            if !ok then
                useIMesh = false
                killAllMeshes()
                return
            end
        end
        meshN[ci] = nv
        i = last + 1
    end
    for j = ci + 1, math.max(nMeshes, #meshes) do
        killMesh(j)
    end
    nMeshes = ci
end

local function emit(a)
    a = a or 255
    local i = 1
    local cap = min(nIdx, 8000 * 3)
    while i <= cap do
        local remain = cap - i + 1
        if remain > 30000 then remain = 30000 - (30000 % 3) end
        mesh.Begin(MATERIAL_TRIANGLES, remain / 3)
        local last = i + remain - 1
        for j = i, last do
            local id = IX[j]
            vP.x, vP.y, vP.z = UX[id], UY[id], UZ[id]
            vN.x, vN.y, vN.z = NX[id], NY[id], NZ[id]
            vT.x, vT.y, vT.z = TX[id] or 1, TY[id] or 0, TZ[id] or 0
            mesh.Position(vP)
            mesh.Normal(vN)
            mesh.TexCoord(0, UU[id] or 0, VV[id] or 0)
            if mesh.UserData then
                mesh.UserData(vT.x, vT.y, vT.z, 1)
            end
            mesh.Color(CR[id], CG[id], CB[id], CA[id] or a)
            mesh.AdvanceVertex()
        end
        mesh.End()
        i = last + 1
    end
end

local function build(n, q, qt, dist, trans)
    if !EDGE then
        EDGE, TRI = C.EDGE, C.TRI
    end
    local R = C.RADIUS
    infR = R * qt.inf
    infR2 = infR * infR
    invR2 = 1 / infR2
    C.MOVE_EPS = qt.eps
    idxCap = 48000 * 3
    local minx, miny, minz = 1e12, 1e12, 1e12
    local maxx, maxy, maxz = -1e12, -1e12, -1e12
    for i = 1, n do
        local x, y, z = spx[i], spy[i], spz[i]
        if x < minx then minx = x end
        if y < miny then miny = y end
        if z < minz then minz = z end
        if x > maxx then maxx = x end
        if y > maxy then maxy = y end
        if z > maxz then maxz = z end
    end
    local span = maxx - minx
    local sy = maxy - miny
    local sz = maxz - minz
    if sy > span then span = sy end
    if sz > span then span = sz end
    local cell = qt.cell
    if dist > 1600 then
        cell = qt.cellFar
    elseif dist > 1200 then
        cell = (qt.cell + qt.cellFar) * 0.5
    end
    nUnique, nIdx = 0, 0
    local packed = span < infR * 3.35
    if packed then
        for i = 1, n do tmp[i] = i end
        march(tmp, n, cell)
    else
        local link = infR * 1.58
        local link2 = link * link
        for i = 1, n do
            parent[i], rank[i] = i, 0
        end
        for i = 1, n do
            for j = i + 1, n do
                local ax, ay, az = spx[i] - spx[j], spy[i] - spy[j], spz[i] - spz[j]
                if ax * ax + ay * ay + az * az <= link2 then
                    union(i, j)
                end
            end
        end
        local nr = 0
        for i = 1, n do seen[i] = false end
        for i = 1, n do
            local r = find(i)
            if !seen[r] then
                seen[r] = true
                nr = nr + 1
                rlist[nr] = r
            end
        end
        for ri = 1, nr do
            if nIdx >= idxCap then break end
            local r = rlist[ri]
            local cn = 0
            for i = 1, n do
                if find(i) == r then
                    cn = cn + 1
                    tmp[cn] = i
                end
            end
            march(tmp, cn, cell)
        end
    end
    upload(bakedAlpha)
    commit(n)
end

local matSolid, matGel, matGlass

local function makeGel(name, mode)
    local trans = mode > 1
    local tint = "[0.20 0.26 0.32]"
    local fres = 0.22
    if mode == 2 then
        tint = "[0.18 0.24 0.30]"
        fres = 0.20
    elseif mode == 3 then
        tint = "[0.22 0.30 0.38]"
        fres = 0.28
    end
    local m = CreateMaterial(name, "UnlitGeneric", {
        ["$basetexture"] = "vgui/white",
        ["$vertexcolor"] = 1,
        ["$vertexalpha"] = trans and 1 or 0,
        ["$translucent"] = trans and 1 or 0,
        ["$nocull"] = 0,
        ["$ignorez"] = 0,
        ["$nofog"] = 1,
        ["$envmap"] = "env_cubemap",
        ["$envmaptint"] = tint,
        ["$envmapfresnel"] = 1,
        ["$envmapfresnelminmaxexp"] = "[0.40 0.90 4.5]",
        ["$fresnelreflection"] = fres,
        ["$color"] = "[1 1 1]"
    })
    if m and !m:IsError() then
        m:SetInt("$vertexcolor", 1)
        m:SetInt("$vertexalpha", trans and 1 or 0)
        m:SetVector("$color", Vector(1, 1, 1))
    end
    return m
end

local function gelMats()
    if !matSolid or matSolid:IsError() then
        matSolid = makeGel("npc_surface_gel_op_v12", 1)
    end
    if !matGel or matGel:IsError() then
        matGel = makeGel("npc_surface_gel_mid_v12", 2)
    end
    if !matGlass or matGlass:IsError() then
        matGlass = makeGel("npc_surface_gel_gl_v12", 3)
    end
end

local function drawIMesh(m)
    m:Draw()
end

local function draw()
    if nMeshes < 1 and nIdx < 3 then return end
    local trans = C.cvTranslucent and C.cvTranslucent:GetBool()
    if trans then
        if !matClear or matClear:IsError() then
            matClear = Material("npc_surface/gel")
        end
        mat = matClear
    else
        if !matSolid or matSolid:IsError() then
            matSolid = Material("npc_surface/gel_opaque")
        end
        mat = matSolid
    end
    if !mat or mat:IsError() then return end
    render.SetColorModulation(1, 1, 1)
    render.SetBlend(1)
    render.SetMaterial(mat)
    render.OverrideDepthEnable(true, true)
    render.CullMode(MATERIAL_CULLMODE_CCW)
    if useIMesh and nMeshes > 0 then
        local ok = true
        for i = 1, nMeshes do
            if !pcall(drawIMesh, meshes[i]) then
                ok = false
                break
            end
        end
        if !ok then
            useIMesh = false
            nMeshes = 0
            emit(trans and 176 or 255)
        end
    else
        emit(trans and 176 or 255)
    end
    render.OverrideDepthEnable(false, false)
    render.CullMode(MATERIAL_CULLMODE_CCW)
end

hook.Add("PreRender", "npc_surface_mesh", function()
    local fn = FrameNumber()
    if fn == lastFrame then return end
    lastFrame = fn
    local n = gather()
    if n < 1 then
        nUnique, nIdx, lastN, nMeshes = 0, 0, 0, 0
        lastIdSum = 0
        killAllMeshes()
        return
    end
    local q = (C.ReadQuality and C.ReadQuality()) or 1
    if q < 1 then q = 1 elseif q > 3 then q = 3 end
    local trans = (C.ReadMat and C.ReadMat()) or 1
    local jelly = C.JellyMesh and C.JellyMesh() or false
    local jellyCluster = C.JellyClusterMesh and C.JellyClusterMesh() or false
    local qt = C.QUALITY[q] or C.QUALITY[1]
    if q ~= lastQ or trans ~= lastTrans or jelly ~= lastJelly or jellyCluster ~= lastJellyCluster then
        needBuild = true
        lastBuild = 0
        killAllMeshes()
    end
    local minx, miny, minz = 1e12, 1e12, 1e12
    local maxx, maxy, maxz = -1e12, -1e12, -1e12
    for i = 1, n do
        local x, y, z = spx[i], spy[i], spz[i]
        if x < minx then minx = x end
        if y < miny then miny = y end
        if z < minz then minz = z end
        if x > maxx then maxx = x end
        if y > maxy then maxy = y end
        if z > maxz then maxz = z end
    end
    local eye = EyePos()
    local dx, dy, dz = eye.x - (minx + maxx) * 0.5, eye.y - (miny + maxy) * 0.5, eye.z - (minz + maxz) * 0.5
    local dist = sqrt(dx * dx + dy * dy + dz * dz)
    C.MOVE_EPS = qt.eps
    if !needBuild and q == lastQ and trans == lastTrans and !moved(n) and nIdx >= 3 then
        return
    end
    local hz = qt.hz or 60
    if dist > 1600 then
        hz = 20
    elseif dist > 1100 then
        hz = 30
    end
    local now = RealTime()
    if !needBuild and nIdx >= 3 and q == lastQ and trans == lastTrans and (now - lastBuild) < (1 / hz) then
        return
    end
    needBuild = false
    lastBuild = now
    lastQ, lastTrans, lastJelly, lastJellyCluster = q, trans, jelly, jellyCluster
    build(n, q, qt, dist, trans)
end)

hook.Add("PostDrawTranslucentRenderables", "npc_surface_draw", function(depth, sky, sky3d)
    if depth or sky or sky3d then return end
    draw()
end)

hook.Add("OnEntityCreated", "npc_surface_blob", function(ent)
    timer.Simple(0, function()
        if !IsValid(ent) or ent:GetClass() ~= "npc_surface_blob" then return end
        ent.IsSurfBlob = true
        local t = C.ClientBlobs
        if !t then
            t = {}
            C.ClientBlobs = t
        end
        for i = 1, #t do
            if t[i] == ent then
                needBuild = true
                return
            end
        end
        t[#t + 1] = ent
        ent:SetNoDraw(true)
        ent:AddEffects(EF_NODRAW)
        needBuild = true
    end)
end)

hook.Add("EntityRemoved", "npc_surface_blob", function(ent)
    if !ent or !ent.IsSurfBlob then return end
    needBuild = true
    local t = C.ClientBlobs
    if !t then return end
    for i = 1, #t do
        if t[i] == ent then
            t[i] = t[#t]
            t[#t] = nil
            return
        end
    end
end)

cvars.AddChangeCallback("npc_surface_quality", function()
    needBuild = true
    lastQ = -1
    killAllMeshes()
end, "npc_surface_quality_live")

cvars.AddChangeCallback("npc_surface_mat", function()
    needBuild = true
    lastTrans = nil
    lastBuild = 0
    killAllMeshes()
end, "npc_surface_mat_live")

cvars.AddChangeCallback("npc_surface_jelly", function()
    needBuild = true
    lastJelly = nil
    lastBuild = 0
    killAllMeshes()
end, "npc_surface_jelly_live")

cvars.AddChangeCallback("npc_surface_jelly_cluster", function()
    needBuild = true
    lastJellyCluster = nil
    lastBuild = 0
    killAllMeshes()
end, "npc_surface_jelly_cluster_live")

local function colorLive()
    if C.ReadColor then C.ReadColor() end
    needBuild = true
    lastBuild = 0
end
cvars.AddChangeCallback("npc_surface_multicolor", colorLive, "npc_surface_multicolor_live")
cvars.AddChangeCallback("npc_surface_col_r", colorLive, "npc_surface_colr_live")
cvars.AddChangeCallback("npc_surface_col_g", colorLive, "npc_surface_colg_live")
cvars.AddChangeCallback("npc_surface_col_b", colorLive, "npc_surface_colb_live")
