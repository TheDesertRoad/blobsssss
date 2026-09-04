-- ==============================================================
-- CETS_BLOBS: CORE
-- ==============================================================
--
-- lua/autorun/cets_blobs.lua
--
-- FIRST SECTION
--

CETS_BLOBS = CETS_BLOBS or {}

local C = CETS_BLOBS

C.Version = "1.0.0"

C.RADIUS = 13.5
C.MASS = 16

C.NUM = 32
C.MAX = 72

C.GEL_NUM = 10

C.SPEED = 70
C.IDLE = 0.55

C.SIN = 9

C.SWARM_R = 56
C.SWARM_R_CLOSE = 18
C.STRAGGLE = 78

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

C.ISO = 0.50
C.INF = 2.02

C.CELL = 4.5
C.CELL_FAR = 6.0

C.CHUNK_HP = 60

C.COL_R = 86
C.COL_G = 170
C.COL_B = 208

C.QUALITY = {
	[1] = {
		cell = 5.8,
		cellFar = 7.2,
		inf = 1.96,
		eps = 0.85,
		far = 900,
		hz = 60
	},

	[2] = {
		cell = 4.4,
		cellFar = 5.8,
		inf = 2.02,
		eps = 0.70,
		far = 900,
		hz = 60
	},

	[3] = {
		cell = 3.15,
		cellFar = 4.6,
		inf = 2.08,
		eps = 0.58,
		far = 1100,
		hz = 60
	}
}

C.FLECK_Q = {
	cell = 7.4,
	cellFar = 9.2,
	inf = 2.02,
	eps = 0.75,
	hz = 40
}


C.Defaults = {
	Count = 32,
	MaxCount = 72,

	Radius = 13.5,
	Mass = 16,

	Speed = 70,

	HP = 60,

	Color = Color(86, 170, 208),

	IsGel = false,

	Jelly = true,
	JellyCluster = false,

	Quality = 2,

	CollideWorld = false,
	CollideProps = false,
	CollidePlayers = false,
	CollideNPCs = false,
	CollideBlobs = false,

	Gravity = true,

	EnableFlecks = true,
	MaxFlecks = 40,

	ImpactSounds = false
}


C.Controllers = C.Controllers or {}

C.Blobs = C.Blobs or {}

C.ClientBlobs = C.ClientBlobs or {}

C.ClientFlecks = C.ClientFlecks or {}


local function copyColor(col)
	col = col or C.Defaults.Color

	return Color(
		math.Clamp(tonumber(col.r) or 86, 0, 255),
		math.Clamp(tonumber(col.g) or 170, 0, 255),
		math.Clamp(tonumber(col.b) or 208, 0, 255),
		math.Clamp(tonumber(col.a) or 255, 0, 255)
	)
end


local function copyConfig(config)
	local out = {}

	for k, v in pairs(C.Defaults) do
		if istable(v) then
			if k == "Color" then
				out[k] = copyColor(v)
			else
				out[k] = table.Copy(v)
			end
		else
			out[k] = v
		end
	end

	if istable(config) then
		for k, v in pairs(config) do
			if k == "Color" then
				out[k] = copyColor(v)
			else
				out[k] = v
			end
		end
	end

	out.Count = math.max(
		1,
		math.floor(tonumber(out.Count) or C.NUM)
	)

	out.MaxCount = math.max(
		out.Count,
		math.floor(tonumber(out.MaxCount) or C.MAX)
	)

	out.Radius = math.max(
		0.1,
		tonumber(out.Radius) or C.RADIUS
	)

	out.Mass = math.max(
		0.01,
		tonumber(out.Mass) or C.MASS
	)

	out.Speed = math.max(
		0,
		tonumber(out.Speed) or C.SPEED
	)

	out.HP = math.max(
		1,
		tonumber(out.HP) or C.CHUNK_HP
	)

	out.Quality = math.Clamp(
		math.floor(tonumber(out.Quality) or 2),
		1,
		3
	)

	return out
end


function C.IsBlob(ent)
	return IsValid(ent) and ent.IsCETSBlob == true
end


function C.IsFleck(ent)
	return IsValid(ent) and ent.IsCETSFleck == true
end


function C.GetController(ent)
	if not IsValid(ent) then
		return nil
	end

	return ent.CETSBlobs
end


function C.GetColor(controller)
	if controller and controller.Color then
		return controller.Color
	end

	return Color(
		C.COL_R,
		C.COL_G,
		C.COL_B
	)
end


function C.ReadColor(controller)
	local col = C.GetColor(controller)

	return col.r, col.g, col.b
end


function C.GetQuality(controller)
	local q = 2

	if controller then
		q = tonumber(controller.Quality) or 2
	end

	return math.Clamp(
		math.floor(q),
		1,
		3
	)
end


function C.GetRadius(controller)
	if controller and controller.Radius then
		return controller.Radius
	end

	return C.RADIUS
end


function C.GetMass(controller)
	if controller and controller.Mass then
		return controller.Mass
	end

	return C.MASS
end


function C.GetSpeed(controller)
	if controller and controller.Speed then
		return controller.Speed
	end

	return C.SPEED
end


function C.GetHP(controller)
	if controller and controller.HP then
		return controller.HP
	end

	return C.CHUNK_HP
end


function C.GetMaxCount(controller)
	if controller and controller.MaxCount then
		return controller.MaxCount
	end

	return C.MAX
end


function C.Create(owner, config)
	if CLIENT then
		return nil
	end

	local controller = copyConfig(config)

	controller.Owner = IsValid(owner) and owner or nil

	controller.Position =
		IsValid(owner)
		and owner:WorldSpaceCenter()
		or vector_origin

	controller.Blobs = {}

	controller.Removed = false

	setmetatable(controller, {
		__index = C.Controller
	})

	C.Controllers[#C.Controllers + 1] = controller

	if IsValid(owner) then
		owner.CETSBlobs = controller
	end

	return controller
end


C.Controller = {}


function C.Controller:IsValid()
	return not self.Removed
end


function C.Controller:GetOwner()
	if IsValid(self.Owner) then
		return self.Owner
	end

	return nil
end


function C.Controller:GetPos()
	if IsValid(self.Owner) then
		return self.Owner:WorldSpaceCenter()
	end

	return self.Position or vector_origin
end


function C.Controller:SetPos(pos)
	if not isvector(pos) then
		return
	end

	self.Position = Vector(
		pos.x,
		pos.y,
		pos.z
	)
end


function C.Controller:SetColor(col)
	self.Color = copyColor(col)

	for i = 1, #self.Blobs do
		local blob = self.Blobs[i]

		if IsValid(blob) then
			blob:SetGelR(self.Color.r)
			blob:SetGelG(self.Color.g)
			blob:SetGelB(self.Color.b)
		end
	end
end


function C.Controller:GetColor()
	return self.Color
end


function C.Controller:GetCount()
	return #self.Blobs
end


function C.Controller:Spawn(count, radius)
	if self.Removed then
		return
	end

	C.SpawnRing(
		self,
		count or self.Count,
		radius or 38
	)
end


function C.Controller:Think()
	if self.Removed then
		return
	end

	C.Sim(self)
end


function C.Controller:Impact(pos, force)
	if self.Removed then
		return
	end

	C.ClusterBlast(
		self,
		pos or self:GetPos(),
		force or 0
	)
end


function C.Controller:Split(pos, force)
	if self.Removed then
		return
	end

	C.BulletPinch(
		self,
		pos or self:GetPos(),
		force or 0
	)
end


function C.Controller:Damage(blob, damage, pos, force)
	if self.Removed then
		return
	end

	C.HurtBlob(
		blob,
		damage or 0,
		pos,
		force
	)
end


function C.Controller:Remove()
	if self.Removed then
		return
	end

	self.Removed = true

	for i = #self.Blobs, 1, -1 do
		local blob = self.Blobs[i]

		if IsValid(blob) then
			blob.CETSBlobs = nil
			blob:Remove()
		end
	end

	self.Blobs = {}

	if IsValid(self.Owner) and self.Owner.CETSBlobs == self then
		self.Owner.CETSBlobs = nil
	end

	for i = #C.Controllers, 1, -1 do
		if C.Controllers[i] == self then
			C.Controllers[i] =
				C.Controllers[#C.Controllers]

			C.Controllers[#C.Controllers] = nil

			break
		end
	end
end

-- ==============================================================
-- SERVER REGISTRATION
-- ==============================================================
--
-- Continue in the SAME cets_blobs.lua file.
--

if SERVER then

	function C.RegBlob(ent)
		if not IsValid(ent) then
			return
		end

		C.Blobs[#C.Blobs + 1] = ent
	end


	function C.UnregBlob(ent)
		for i = 1, #C.Blobs do
			if C.Blobs[i] == ent then
				C.Blobs[i] = C.Blobs[#C.Blobs]
				C.Blobs[#C.Blobs] = nil

				break
			end
		end

		local controller = ent.CETSBlobs

		if not controller then
			return
		end

		for i = 1, #controller.Blobs do
			if controller.Blobs[i] == ent then
				controller.Blobs[i] =
					controller.Blobs[#controller.Blobs]

				controller.Blobs[#controller.Blobs] = nil

				break
			end
		end
	end


	function C.MakeBlob(controller, pos)
		if not controller or controller.Removed then
			return nil
		end

		if #controller.Blobs >= controller.MaxCount then
			return nil
		end

		local ent = ents.Create("cets_blobs_chunk")

		if not IsValid(ent) then
			return nil
		end

		ent:SetPos(pos)

		ent.CETSBlobs = controller
		ent.IsCETSBlob = true

		ent.IsGel = controller.IsGel == true

		ent.CETSRadius = controller.Radius
		ent.CETSMass = controller.Mass
		ent.CETSHp = controller.HP
		ent.CETSSpeed = controller.Speed
		ent.CETSGravity = controller.Gravity ~= false

		ent:Spawn()
		ent:Activate()

		ent:SetHealth(controller.HP)
		ent:SetMaxHealth(controller.HP)

		ent.SurfHP = controller.HP

		ent:SetGelR(controller.Color.r)
		ent:SetGelG(controller.Color.g)
		ent:SetGelB(controller.Color.b)

		controller.Blobs[#controller.Blobs + 1] = ent

		C.RegBlob(ent)

		return ent
	end


	function C.SpawnRing(controller, n, radius)
		if not controller or controller.Removed then
			return
		end

		n = math.Clamp(
			math.floor(n or controller.Count),
			1,
			controller.MaxCount
		)

		local origin = controller:GetPos()

		local golden = 2.399963229
		local R = controller.Radius

		if controller.IsGel then

			local restZ = R + 0.6

			for i = 1, n do
				local a = golden * (i - 1)

				local r =
					radius *
					math.sqrt(
						(i - 0.35) / n
					)

				C.MakeBlob(
					controller,
					origin +
					Vector(
						math.cos(a) * r,
						math.sin(a) * r,
						restZ
					)
				)
			end

		else

			local rest = R * C.REST

			local rad =
				rest *
				0.58 *
				(n ^ (1 / 3))

			if rad < rest * 0.85 then
				rad = rest * 0.85
			end

			local ox = {}
			local oy = {}
			local oz = {}

			local minz = 1e9

			for i = 1, n do

				local y =
					1 -
					(i - 0.5) /
					n *
					2

				local rxy =
					math.sqrt(
						math.max(
							0,
							1 - y * y
						)
					)

				local th =
					golden * i

				ox[i] =
					math.cos(th) *
					rxy *
					rad

				oy[i] =
					math.sin(th) *
					rxy *
					rad

				oz[i] =
					y * rad

				if oz[i] < minz then
					minz = oz[i]
				end

				if n <= 8 then
					ox[i] =
						ox[i] +
						math.Rand(
							-R * 0.42,
							R * 0.42
						)

					oy[i] =
						oy[i] +
						math.Rand(
							-R * 0.42,
							R * 0.42
						)
				end
			end

			local lift =
				R +
				0.8 -
				minz

			for i = 1, n do

				C.MakeBlob(
					controller,
					origin +
					Vector(
						ox[i],
						oy[i],
						oz[i] + lift
					)
				)
			end
		end
	end
end

-- ==============================================================
-- ENTITY COLLISION POLICY
-- ==============================================================
--
-- This is the important change from the old implementation.
--
-- The chunk has VPhysics because the original simulation uses its
-- physics object for velocity, forces, gravity and damping.
--
-- But it does NOT have to physically collide with everything.
--
-- CETS_BLOBS controls that explicitly.
--

-- ============================================================
-- STEP 5 IMPORTANT
-- ============================================================
--
-- Replace the previous ShouldCollide hook with this global hook
-- in cets_blobs.lua.
--
-- This catches the OTHER entity's collision decision too.
--
-- Result with the default configuration:
--
--	blob <-> blob		NO
--	blob <-> world		NO
--	blob <-> prop		NO
--	blob <-> player	NO
--	blob <-> NPC		NO
--	blob <-> NextBot	NO
--
-- The renderer still sees the blobs.
-- sv_sim still detects floors/walls with traces.
-- Therefore the invisible physics sphere is no longer responsible
-- for physically smashing into the map or props.
-- ============================================================

if SERVER then

	hook.Add(
		"ShouldCollide",
		"CETS_BLOBS_Collision",
		function(
			ent1,
			ent2
		)

			local blob1 =
				IsValid(ent1)
				and ent1.IsCETSBlob

			local blob2 =
				IsValid(ent2)
				and ent2.IsCETSBlob


			if not blob1 and not blob2 then
				return
			end


			-- ------------------------------------------------
			-- BLOB <-> BLOB
			-- ------------------------------------------------

			if blob1 and blob2 then
				return false
			end


			local blob =
				blob1
				and ent1
				or ent2


			local other =
				blob1
				and ent2
				or ent1


			local controller =
				blob.CETSBlobs


			if not controller then
				return false
			end


			-- ------------------------------------------------
			-- WORLD
			-- ------------------------------------------------

			if IsValid(other)
				and other:IsWorld()
			then

				if controller.CollideWorld
					== true
				then
					return
				end

				return false
			end


			-- ------------------------------------------------
			-- PLAYERS
			-- ------------------------------------------------

			if IsValid(other)
				and other:IsPlayer()
			then

				if controller.CollidePlayers
					== true
				then
					return
				end

				return false
			end


			-- ------------------------------------------------
			-- NPC / NEXTBOT
			-- ------------------------------------------------

			if IsValid(other)
				and (
					other:IsNPC()
					or other:IsNextBot()
				)
			then

				if controller.CollideNPCs
					== true
				then
					return
				end

				return false
			end


			-- ------------------------------------------------
			-- PROPS / PHYSICS
			-- ------------------------------------------------

			if IsValid(other) then

				local phys =
					other:GetPhysicsObject()


				if IsValid(phys) then

					if controller.CollideProps
						== true
					then
						return
					end

					return false
				end
			end


			-- ------------------------------------------------
			-- DEFAULT
			-- ------------------------------------------------

			return false
		end
	)


	-- ========================================================
	-- SOUND SUPPRESSION
	-- ========================================================
	--
	-- The physical entity is invisible and should not generate
	-- normal impact/physics sounds.
	--
	-- This also protects against sounds generated by nearby
	-- physics interactions involving the hidden blob.
	-- ========================================================

	hook.Add(
		"EntityEmitSound",
		"CETS_BLOBS_Silence",
		function(data)

			local entity =
				data.Entity


			if IsValid(entity) then

				if entity.IsCETSBlob
					or entity.IsCETSFleck
				then
					return false
				end
			end


			-- ------------------------------------------------
			-- Suppress physics impact sounds immediately around
			-- a blob.
			-- ------------------------------------------------

			local soundName =
				string.lower(
					data.SoundName
					or ""
				)


			if
				string.find(
					soundName,
					"physics/",
					1,
					true
				)
				or
				string.find(
					soundName,
					"impact",
					1,
					true
				)
				or
				string.find(
					soundName,
					"bullet",
					1,
					true
				)
				or
				string.find(
					soundName,
					"ricochet",
					1,
					true
				)
			then

				local pos =
					data.Pos


				if pos then

					local nearest =
						CETS_BLOBS.FindNearest(
							pos,
							28
						)


					if IsValid(nearest) then
						return false
					end
				end
			end
		end
	)


	-- ========================================================
	-- NEAREST BLOB
	-- ========================================================

	function CETS_BLOBS.FindNearest(
		position,
		distance
	)

		if not position then
			return nil
		end


		distance =
			distance or
			math.huge


		local best
		local bestDist2 =
			distance * distance


		for i = 1, #CETS_BLOBS.Blobs do

			local blob =
				CETS_BLOBS.Blobs[i]


			if not IsValid(blob) then
				continue
			end


			local delta =
				blob:GetPos() -
				position


			local dist2 =
				delta:LengthSqr()


			if dist2 < bestDist2 then

				bestDist2 =
					dist2

				best =
					blob
			end
		end


		return best
	end

end

if CLIENT then

	local sqrt = math.sqrt
	local min = math.min
	local max = math.max
	local abs = math.abs
	local floor = math.floor
	local sin = math.sin
	local cos = math.cos
	local atan2 = math.atan2

	local band = bit.band

	local EyePos = EyePos
	local IsValid = IsValid
	local FrameNumber = FrameNumber
	local RealTime = RealTime
	local FrameTime = FrameTime

	local Vector = Vector
	local Color = Color
	local mesh = mesh
	local render = render

	local MeshCtor = Mesh

	local EDGE
	local TRI
	local mat

	local vP = Vector()
	local vN = Vector()
	local vT = Vector()

	local UX = {}
	local UY = {}
	local UZ = {}

	local NX = {}
	local NY = {}
	local NZ = {}

	local CR = {}
	local CG = {}
	local CB = {}
	local CA = {}

	local UU = {}
	local VV = {}

	local TX = {}
	local TY = {}
	local TZ = {}

	local IX = {}

	local nUnique = 0
	local nIdx = 0

	local lastN = 0

	local spx = {}
	local spy = {}
	local spz = {}

	local scr = {}
	local scg = {}
	local scb = {}

	local spr = {}
	local sfl = {}
	local sent = {}

	local sux = {}
	local suy = {}
	local sst = {}
	local ssq = {}
	local szs = {}

	local lpx = {}
	local lpy = {}
	local lpz = {}

	local nSamp = 0

	local lastBR = 86
	local lastBG = 170
	local lastBB = 208

	local GW = 56
	local GH = 56
	local GD = 56

	local GWH = GW * GH
	local GSIZE = GW * GH * GD

	local gVal = {}
	local gR = {}
	local gG = {}
	local gB = {}
	local gW = {}

	local writeGen = {}
	local cubeGen = {}
	local nGen = {}

	local NXG = {}
	local NYG = {}
	local NZG = {}

	local NCR = {}
	local NCG = {}
	local NCB = {}

	local written = {}
	local active = {}

	local nWritten = 0
	local nActive = 0

	local gen = 1

	local eStamp = {}
	local eVid = {}
	local edgeKeys = {}

	local nEdgeClear = 0

	local EBIT = {
		1,
		2,
		4,
		8,
		16,
		32,
		64,
		128,
		256,
		512,
		1024,
		2048
	}

	local CX = {
		0, 1, 1, 0,
		0, 1, 1, 0
	}

	local CY = {
		0, 0, 1, 1,
		0, 0, 1, 1
	}

	local CZ = {
		0, 0, 0, 0,
		1, 1, 1, 1
	}

	local EA = {
		0, 1, 0, 1,
		0, 1, 0, 1,
		2, 2, 2, 2
	}

	local EX = {
		0, 1, 0, 0,
		0, 1, 0, 0,
		0, 1, 1, 0
	}

	local EY = {
		0, 0, 1, 0,
		0, 0, 1, 0,
		0, 0, 1, 1
	}

	local EZ = {
		0, 0, 0, 0,
		1, 1, 1, 1,
		0, 0, 0, 0
	}

	local EC0 = {
		0, 1, 2, 3,
		4, 5, 6, 7,
		0, 1, 2, 3
	}

	local EC1 = {
		1, 2, 3, 0,
		5, 6, 7, 4,
		4, 5, 6, 7
	}

	local ppx = {}
	local ppy = {}
	local ppz = {}

	local pcr = {}
	local pcg = {}
	local pcb = {}

	local pR = {}
	local pR2 = {}
	local pInv = {}

	local pux = {}
	local puy = {}
	local pst = {}
	local psq = {}
	local pzs = {}

	local pn = 0

	local infR = 27
	local infR2 = 729
	local invR2 = 1 / 729

	local clipX0
	local clipX1
	local clipY0
	local clipY1
	local clipZ0
	local clipZ1

	local parent = {}
	local rank = {}

	local cv = {
		0, 0, 0, 0,
		0, 0, 0, 0
	}

	local ev = {
		0, 0, 0, 0,
		0, 0, 0, 0,
		0, 0, 0, 0
	}

	local tmp = {}
	local seen = {}
	local rlist = {}
	local lonerIdx = {}

	local idxCap = 48000 * 3

	local partA = {}
	local partB = {}

	local useIMesh = true

	local meshes = {}
	local meshN = {}

	local nMeshes = 0

	local CHUNK_VERTS = 4096 * 3

	local vbuf = {}
	local chunk = {}

	local bakedAlpha = 255

	local lastQ = -1
	local lastTrans
	local lastJelly
	local lastJellyCluster

	local lastFrame = -1
	local lastBuild = 0

	local lastIdSum = 0
	local needBuild = true


	-- ============================================================
	-- GRID INITIALIZATION
	-- ============================================================

	for i = 1, GSIZE do
		gVal[i] = 0
		gR[i] = 0
		gG[i] = 0
		gB[i] = 0
		gW[i] = 0

		writeGen[i] = 0
		cubeGen[i] = 0
		nGen[i] = 0
	end


	-- ============================================================
	-- MESH MANAGEMENT
	-- ============================================================

	local function haveIMesh()
		if not useIMesh then
			return false
		end

		if not MeshCtor then
			useIMesh = false
			return false
		end

		return true
	end


	local function killMesh(i)
		local m = meshes[i]

		if not m then
			meshN[i] = nil
			return
		end

		pcall(function()
			if m.Destroy then
				m:Destroy()
			end
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


	-- ============================================================
	-- UNION FIND
	-- ============================================================

	local function find(i)
		local p = parent[i]

		if p ~= i then
			p = find(p)
			parent[i] = p
		end

		return p
	end


	local function union(a, b)
		a = find(a)
		b = find(b)

		if a == b then
			return
		end

		if rank[a] < rank[b] then
			parent[a] = b

		elseif rank[a] > rank[b] then
			parent[b] = a

		else
			parent[b] = a
			rank[a] = rank[a] + 1
		end
	end


	-- ============================================================
	-- GRID
	-- ============================================================

	local function gIndex(ix, iy, iz)
		return 1 + ix + iy * GW + iz * GWH
	end


	local function gridVal(ix, iy, iz)
		if
			ix < 0 or
			iy < 0 or
			iz < 0 or
			ix >= GW or
			iy >= GH or
			iz >= GD
		then
			return 0
		end

		local k = gIndex(ix, iy, iz)

		if writeGen[k] ~= gen then
			return 0
		end

		return gVal[k]
	end


	local function cornerShade(ix, iy, iz)
		if
			ix < 0 or
			iy < 0 or
			iz < 0 or
			ix >= GW or
			iy >= GH or
			iz >= GD
		then
			return 0, 0, 1,
				C.COL_R,
				C.COL_G,
				C.COL_B
		end

		local k = gIndex(ix, iy, iz)

		if nGen[k] == gen then
			return
				NXG[k],
				NYG[k],
				NZG[k],
				NCR[k],
				NCG[k],
				NCB[k]
		end

		local dx =
			gridVal(ix + 1, iy, iz) -
			gridVal(ix - 1, iy, iz)

		local dy =
			gridVal(ix, iy + 1, iz) -
			gridVal(ix, iy - 1, iz)

		local dz =
			gridVal(ix, iy, iz + 1) -
			gridVal(ix, iy, iz - 1)

		local len =
			sqrt(
				dx * dx +
				dy * dy +
				dz * dz
			)

		if len > 1e-8 then
			local inv = -1 / len

			dx = dx * inv
			dy = dy * inv
			dz = dz * inv
		else
			dx = 0
			dy = 0
			dz = 1
		end

		local r = C.COL_R
		local g = C.COL_G
		local b = C.COL_B

		nGen[k] = gen

		NXG[k] = dx
		NYG[k] = dy
		NZG[k] = dz

		NCR[k] = r
		NCG[k] = g
		NCB[k] = b

		return dx, dy, dz, r, g, b
	end


	local function markCube(ix, iy, iz)
		if ix < 0 or iy < 0 or iz < 0 then
			return
		end

		if
			ix >= GW - 1 or
			iy >= GH - 1 or
			iz >= GD - 1
		then
			return
		end

		local ck = gIndex(ix, iy, iz)

		if cubeGen[ck] == gen then
			return
		end

		cubeGen[ck] = gen

		nActive = nActive + 1
		active[nActive] = ck
	end


	local function bumpGen()
		gen = gen + 1

		if gen > 2000000000 then
			gen = 1

			for i = 1, GSIZE do
				writeGen[i] = 0
				cubeGen[i] = 0
				nGen[i] = 0
			end
		end

		for i = 1, nEdgeClear do
			local k = edgeKeys[i]

			eStamp[k] = nil
			eVid[k] = nil
		end

		nEdgeClear = 0
		nWritten = 0
		nActive = 0
	end


	-- ============================================================
	-- METABALL FIELD
	-- ============================================================

	local function splatField(nidx, ox, oy, oz, cellSize)
		local iso = C.ISO
		local near = iso * 2.2

		for i = 1, nidx do

			local x = ppx[i]
			local y = ppy[i]
			local z = ppz[i]

			local cr = pcr[i]
			local cg = pcg[i]
			local cb = pcb[i]

			local R = pR[i]
			local R2 = pR2[i]
			local inv = pInv[i]

			local st = pst[i] or 1
			local sq = psq[i] or 1
			local zs = pzs[i] or 1

			local ax = pux[i] or 0
			local ay = puy[i] or 1

			local aniso =
				abs(st - 1) > 0.05
				or abs(sq - 1) > 0.05
				or abs(zs - 1) > 0.08

			local Rm = R

			if aniso then
				Rm = R * st

				if R / sq > Rm then
					Rm = R / sq
				end

				if R * zs > Rm then
					Rm = R * zs
				end
			end

			local x0 =
				floor(
					(x - Rm - ox) /
					cellSize
				)

			local x1 =
				floor(
					(x + Rm - ox) /
					cellSize
				)

			local y0 =
				floor(
					(y - Rm - oy) /
					cellSize
				)

			local y1 =
				floor(
					(y + Rm - oy) /
					cellSize
				)

			local z0 =
				floor(
					(z - Rm - oz) /
					cellSize
				)

			local z1 =
				floor(
					(z + Rm - oz) /
					cellSize
				)

			x0 = max(0, x0)
			y0 = max(0, y0)
			z0 = max(0, z0)

			x1 = min(GW - 1, x1)
			y1 = min(GH - 1, y1)
			z1 = min(GD - 1, z1)


			if aniso then

				for iz = z0, z1 do

					local dz =
						(oz + iz * cellSize) - z

					local dzz = dz / zs
					local dz2 = dzz * dzz

					if dz2 < R2 then

						for iy = y0, y1 do

							local dy =
								(oy + iy * cellSize) - y

							for ix = x0, x1 do

								local dx =
									(ox + ix * cellSize) - x

								local along =
									dx * ax +
									dy * ay

								local px =
									dx -
									ax * along

								local py =
									dy -
									ay * along

								local d2 =
									(along * along) /
									(st * st)
									+
									(px * px + py * py) /
									(sq * sq)
									+
									dz2

								if d2 < R2 then

									local t =
										1 -
										d2 * inv

									local w = t * t

									local k =
										gIndex(
											ix,
											iy,
											iz
										)

									if writeGen[k] ~= gen then

										writeGen[k] = gen

										gVal[k] = w

										gR[k] = cr * w
										gG[k] = cg * w
										gB[k] = cb * w

										gW[k] = w

										nWritten =
											nWritten + 1

										written[nWritten] = k

									else

										gVal[k] =
											gVal[k] + w

										gR[k] =
											gR[k] + cr * w

										gG[k] =
											gG[k] + cg * w

										gB[k] =
											gB[k] + cb * w

										gW[k] =
											gW[k] + w
									end
								end
							end
						end
					end
				end

			else

				for iz = z0, z1 do

					local dz =
						(oz + iz * cellSize) - z

					local dz2 = dz * dz

					if dz2 < R2 then

						for iy = y0, y1 do

							local dy =
								(oy + iy * cellSize) - y

							local dy2 = dy * dy

							for ix = x0, x1 do

								local dx =
									(ox + ix * cellSize) - x

								local d2 =
									dx * dx +
									dy2 +
									dz2

								if d2 < R2 then

									local t =
										1 -
										d2 * inv

									local w = t * t

									local k =
										gIndex(
											ix,
											iy,
											iz
										)

									if writeGen[k] ~= gen then

										writeGen[k] = gen

										gVal[k] = w

										gR[k] = cr * w
										gG[k] = cg * w
										gB[k] = cb * w

										gW[k] = w

										nWritten =
											nWritten + 1

										written[nWritten] = k

									else

										gVal[k] =
											gVal[k] + w

										gR[k] =
											gR[k] + cr * w

										gG[k] =
											gG[k] + cg * w

										gB[k] =
											gB[k] + cb * w

										gW[k] =
											gW[k] + w
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

				local ix =
					t % GW

				local iy =
					floor(t / GW) % GH

				local iz =
					floor(t / GWH)

				markCube(ix, iy, iz)
				markCube(ix - 1, iy, iz)
				markCube(ix, iy - 1, iz)
				markCube(ix, iy, iz - 1)

				markCube(
					ix - 1,
					iy - 1,
					iz
				)

				markCube(
					ix - 1,
					iy,
					iz - 1
				)

				markCube(
					ix,
					iy - 1,
					iz - 1
				)

				markCube(
					ix - 1,
					iy - 1,
					iz - 1
				)
			end
		end
	end

	-- ============================================================
	-- EDGE VERTEX
	-- ============================================================

	local function edgeVert(
		ix,
		iy,
		iz,
		e,
		ox,
		oy,
		oz,
		cellSize,
		iso
	)

		local k =
			EA[e] +
			(ix + EX[e]) * 4 +
			(iy + EY[e]) * (GW * 4) +
			(iz + EZ[e]) * (GWH * 4)

		if eStamp[k] == gen then
			return eVid[k]
		end

		local a =
			EC0[e] + 1

		local b =
			EC1[e] + 1

		local v1 = cv[a]
		local v2 = cv[b]

		local x1 =
			ox +
			(ix + CX[a]) *
			cellSize

		local y1 =
			oy +
			(iy + CY[a]) *
			cellSize

		local z1 =
			oz +
			(iz + CZ[a]) *
			cellSize

		local x2 =
			ox +
			(ix + CX[b]) *
			cellSize

		local y2 =
			oy +
			(iy + CY[b]) *
			cellSize

		local z2 =
			oz +
			(iz + CZ[b]) *
			cellSize

		local dv = v2 - v1

		local mu

		if abs(dv) < 1e-8 then
			mu = 0.5
		else
			mu = (iso - v1) / dv
		end

		mu = math.Clamp(mu, 0, 1)

		local x =
			x1 +
			(x2 - x1) * mu

		local y =
			y1 +
			(y2 - y1) * mu

		local z =
			z1 +
			(z2 - z1) * mu


		local ax =
			ix + CX[a]

		local ay =
			iy + CY[a]

		local az =
			iz + CZ[a]

		local bx =
			ix + CX[b]

		local by =
			iy + CY[b]

		local bz =
			iz + CZ[b]


		local nax, nay, naz, ra, ga, ba =
			cornerShade(
				ax,
				ay,
				az
			)

		local nbx, nby, nbz, rb, gb, bb =
			cornerShade(
				bx,
				by,
				bz
			)

		local nx =
			nax +
			(nbx - nax) *
			mu

		local ny =
			nay +
			(nby - nay) *
			mu

		local nz =
			naz +
			(nbz - naz) *
			mu

		local len =
			sqrt(
				nx * nx +
				ny * ny +
				nz * nz
			)

		if len > 1e-8 then
			local inv = 1 / len

			nx = nx * inv
			ny = ny * inv
			nz = nz * inv
		end

		local r =
			ra +
			(rb - ra) *
			mu

		local g =
			ga +
			(gb - ga) *
			mu

		local bl =
			ba +
			(bb - ba) *
			mu


		local ndot =
			max(
				0,
				nx * 0.16 +
				ny * 0.12 +
				nz * 0.86
			)

		local lit =
			0.78 +
			0.22 * ndot

		r = min(255, r * lit)
		g = min(255, g * lit)
		bl = min(255, bl * lit)


		nUnique = nUnique + 1

		local id = nUnique

		UX[id] = x
		UY[id] = y
		UZ[id] = z

		NX[id] = nx
		NY[id] = ny
		NZ[id] = nz

		CR[id] = floor(r + 0.5)
		CG[id] = floor(g + 0.5)
		CB[id] = floor(bl + 0.5)

		CA[id] = bakedAlpha

		eStamp[k] = gen
		eVid[k] = id

		nEdgeClear =
			nEdgeClear + 1

		edgeKeys[nEdgeClear] = k

		return id
	end


	-- ============================================================
	-- MARCHING CUBES
	-- ============================================================

	local function march(
		idxs,
		nidx,
		cellSize,
		infMul,
		depth
	)

		if nidx < 1 then
			return
		end

		infMul = infMul or 2
		depth = depth or 0

		pn = nidx

		local minx = 1e12
		local miny = 1e12
		local minz = 1e12

		local maxx = -1e12
		local maxy = -1e12
		local maxz = -1e12

		local maxR = 0


		for i = 1, nidx do

			local s = idxs[i]

			local x = spx[s]
			local y = spy[s]
			local z = spz[s]

			ppx[i] = x
			ppy[i] = y
			ppz[i] = z

			pcr[i] = scr[s]
			pcg[i] = scg[s]
			pcb[i] = scb[s]

			pux[i] = sux[s] or 0
			puy[i] = suy[s] or 1

			pst[i] = sst[s] or 1
			psq[i] = ssq[s] or 1
			pzs[i] = szs[s] or 1

			local R =
				(spr[s] or C.RADIUS) *
				infMul

			pR[i] = R
			pR2[i] = R * R
			pInv[i] = 1 / (R * R)

			if R > maxR then
				maxR = R
			end

			if x < minx then minx = x end
			if y < miny then miny = y end
			if z < minz then minz = z end

			if x > maxx then maxx = x end
			if y > maxy then maxy = y end
			if z > maxz then maxz = z end
		end


		infR = maxR
		infR2 = maxR * maxR

		invR2 =
			maxR > 1e-8
			and 1 / infR2
			or 1


		local pad =
			infR +
			cellSize

		local ox =
			minx - pad

		local oy =
			miny - pad

		local oz =
			minz - pad


		local sx =
			(maxx - minx) +
			pad * 2

		local sy =
			(maxy - miny) +
			pad * 2

		local sz =
			(maxz - minz) +
			pad * 2


		local need =
			sx /
			(GW - 2)

		local ny =
			sy /
			(GH - 2)

		local nz =
			sz /
			(GD - 2)

		if ny > need then
			need = ny
		end

		if nz > need then
			need = nz
		end


		if
			need >
			cellSize * 1.22
			and depth < 5
		then

			local na = 0
			local nb = 0

			local overlap =
				infR * 1.05

			local axis = 1

			local mid =
				(minx + maxx) *
				0.5


			if sy >= sx and sy >= sz then

				axis = 2

				mid =
					(miny + maxy) *
					0.5

			elseif sz >= sx and sz >= sy then

				axis = 3

				mid =
					(minz + maxz) *
					0.5
			end


			for i = 1, nidx do

				local s = idxs[i]

				local v =
					axis == 1
					and spx[s]
					or (
						axis == 2
						and spy[s]
						or spz[s]
					)

				if v < mid + overlap then
					na = na + 1
					partA[na] = s
				end

				if v >= mid - overlap then
					nb = nb + 1
					partB[nb] = s
				end
			end


			if
				na > 0
				and nb > 0
				and na < nidx
				and nb < nidx
			then

				local oldX0 = clipX0
				local oldX1 = clipX1
				local oldY0 = clipY0
				local oldY1 = clipY1
				local oldZ0 = clipZ0
				local oldZ1 = clipZ1

				local A = {}
				local B = {}

				for i = 1, na do
					A[i] = partA[i]
				end

				for i = 1, nb do
					B[i] = partB[i]
				end


				if axis == 1 then

					clipX0 = oldX0 or -1e12
					clipX1 = mid

					clipY0 = oldY0 or -1e12
					clipY1 = oldY1 or 1e12

					clipZ0 = oldZ0 or -1e12
					clipZ1 = oldZ1 or 1e12

					march(
						A,
						na,
						cellSize,
						infMul,
						depth + 1
					)

					clipX0 = mid
					clipX1 = oldX1 or 1e12

					march(
						B,
						nb,
						cellSize,
						infMul,
						depth + 1
					)

				elseif axis == 2 then

					clipX0 = oldX0 or -1e12
					clipX1 = oldX1 or 1e12

					clipY0 = oldY0 or -1e12
					clipY1 = mid

					clipZ0 = oldZ0 or -1e12
					clipZ1 = oldZ1 or 1e12

					march(
						A,
						na,
						cellSize,
						infMul,
						depth + 1
					)

					clipY0 = mid
					clipY1 = oldY1 or 1e12

					march(
						B,
						nb,
						cellSize,
						infMul,
						depth + 1
					)

				else

					clipX0 = oldX0 or -1e12
					clipX1 = oldX1 or 1e12

					clipY0 = oldY0 or -1e12
					clipY1 = oldY1 or 1e12

					clipZ0 = oldZ0 or -1e12
					clipZ1 = mid

					march(
						A,
						na,
						cellSize,
						infMul,
						depth + 1
					)

					clipZ0 = mid
					clipZ1 = oldZ1 or 1e12

					march(
						B,
						nb,
						cellSize,
						infMul,
						depth + 1
					)
				end


				clipX0 = oldX0
				clipX1 = oldX1
				clipY0 = oldY0
				clipY1 = oldY1
				clipZ0 = oldZ0
				clipZ1 = oldZ1

				return
			end
		end


		if need > cellSize * 1.22 then
			cellSize = need

			pad =
				infR +
				cellSize

			ox = minx - pad
			oy = miny - pad
			oz = minz - pad
		end


		bumpGen()

		splatField(
			nidx,
			ox,
			oy,
			oz,
			cellSize
		)


		local iso = C.ISO


		for ci = 1, nActive do

			if nIdx >= idxCap then
				break
			end

			local ck =
				active[ci] - 1

			local ix =
				ck % GW

			local iy =
				floor(ck / GW) % GH

			local iz =
				floor(ck / GWH)


			cv[1] =
				gridVal(
					ix,
					iy,
					iz
				)

			cv[2] =
				gridVal(
					ix + 1,
					iy,
					iz
				)

			cv[3] =
				gridVal(
					ix + 1,
					iy + 1,
					iz
				)

			cv[4] =
				gridVal(
					ix,
					iy + 1,
					iz
				)

			cv[5] =
				gridVal(
					ix,
					iy,
					iz + 1
				)

			cv[6] =
				gridVal(
					ix + 1,
					iy,
					iz + 1
				)

			cv[7] =
				gridVal(
					ix + 1,
					iy + 1,
					iz + 1
				)

			cv[8] =
				gridVal(
					ix,
					iy + 1,
					iz + 1
				)


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

					local wx =
						ox +
						(ix + 0.5) *
						cellSize

					local wy =
						oy +
						(iy + 0.5) *
						cellSize

					local wz =
						oz +
						(iz + 0.5) *
						cellSize


					if
						wx < clipX0
						or wx >= clipX1
						or wy < clipY0
						or wy >= clipY1
						or wz < clipZ0
						or wz >= clipZ1
					then
						continue
					end
				end


				local et =
					EDGE[idx + 1]

				if et ~= 0 then

					for e = 1, 12 do

						if band(
							et,
							EBIT[e]
						) ~= 0 then

							ev[e] =
								edgeVert(
									ix,
									iy,
									iz,
									e,
									ox,
									oy,
									oz,
									cellSize,
									iso
								)
						end
					end


					local base =
						idx * 16


					for t = 1, 16, 3 do

						local a =
							TRI[
								base + t
							]

						if a < 0 then
							break
						end

						if nIdx >= idxCap then
							break
						end


						nIdx =
							nIdx + 3


						IX[nIdx - 2] =
							ev[a + 1]

						IX[nIdx - 1] =
							ev[
								TRI[
									base + t + 2
								] + 1
							]

						IX[nIdx] =
							ev[
								TRI[
									base + t + 1
								] + 1
							]
					end
				end
			end
		end
	end

	-- ============================================================
	-- ENTITY INGEST
	-- ============================================================

	local function ingest(
		source,
		frame,
		alpha,
		n,
		idSum,
		isFleck
	)

		if not source then
			return n, idSum
		end

		local write = 1

		for i = 1, #source do

			local ent = source[i]

			if IsValid(ent) then

				if write ~= i then
					source[write] = ent
				end

				write = write + 1


				if ent._CETS_BLOBS_Pick == frame then
					continue
				end

				ent._CETS_BLOBS_Pick = frame

				ent:SetNoDraw(true)
				ent:RemoveEffects(EF_NODRAW)
				ent:SetRenderMode(RENDERMODE_NORMAL)


				local radius =
					(isFleck and 12 or C.RADIUS) * 4

				ent:SetRenderBounds(
					Vector(
						-radius,
						-radius,
						-radius
					),
					Vector(
						radius,
						radius,
						radius
					)
				)


				local p = ent:GetPos()

				local rawx = p.x
				local rawy = p.y
				local rawz = p.z

				local dt = FrameTime()

				if dt < 0.008 then
					dt = 0.016
				end


				local vx = 0
				local vy = 0
				local vz = 0


				if ent._CETS_RX then

					vx =
						(rawx - ent._CETS_RX) /
						dt

					vy =
						(rawy - ent._CETS_RY) /
						dt

					vz =
						(rawz - ent._CETS_RZ) /
						dt
				end


				local velocity =
					ent:GetVelocity()

				if
					velocity
					and velocity:LengthSqr() >
						vx * vx +
						vy * vy
				then

					vx = velocity.x
					vy = velocity.y
					vz = velocity.z
				end


				ent._CETS_SVX =
					(ent._CETS_SVX or 0) *
					0.78 +
					vx * 0.22

				ent._CETS_SVY =
					(ent._CETS_SVY or 0) *
					0.78 +
					vy * 0.22

				ent._CETS_SVZ =
					(ent._CETS_SVZ or 0) *
					0.78 +
					vz * 0.22


				ent._CETS_RX = rawx
				ent._CETS_RY = rawy
				ent._CETS_RZ = rawz


				local x = rawx
				local y = rawy
				local z = rawz


				if alpha < 1 and ent._CETS_EX then

					x =
						ent._CETS_EX +
						(x - ent._CETS_EX) *
						alpha

					y =
						ent._CETS_EY +
						(y - ent._CETS_EY) *
						alpha

					z =
						ent._CETS_EZ +
						(z - ent._CETS_EZ) *
						alpha
				end


				ent._CETS_EX = x
				ent._CETS_EY = y
				ent._CETS_EZ = z


				n = n + 1

				idSum =
					idSum +
					ent:EntIndex()


				sent[n] = ent

				spx[n] = x
				spy[n] = y
				spz[n] = z

				sfl[n] = isFleck


				sux[n] = 0
				suy[n] = 1

				sst[n] = 1
				ssq[n] = 1
				szs[n] = 1


				if isFleck then

					local sz =
						ent.GetSz
						and ent:GetSz()
						or 0

					if sz < 0.2 then
						sz = 2.35
					end

					spr[n] =
						2.2 +
						sz * 1.35

				else

					local controller =
						ent.CETSBlobs

					spr[n] =
						controller
						and controller.Radius
						or C.RADIUS
				end


				local r
				local g
				local b


				if isFleck then

					r = lastBR
					g = lastBG
					b = lastBB

					if ent.GetGelR then

						local er =
							ent:GetGelR()

						local eg =
							ent:GetGelG()

						local eb =
							ent:GetGelB()

						if
							er ~= 0
							or eg ~= 0
							or eb ~= 0
						then
							r = er
							g = eg
							b = eb
						end
					end

				else

					local controller =
						ent.CETSBlobs

					if controller then
						r, g, b =
							controller.Color.r,
							controller.Color.g,
							controller.Color.b
					else
						r, g, b =
							C.COL_R,
							C.COL_G,
							C.COL_B
					end

					lastBR = r
					lastBG = g
					lastBB = b
				end


				scr[n] = r
				scg[n] = g
				scb[n] = b
			end
		end


		for i = write, #source do
			source[i] = nil
		end


		return n, idSum
	end

	-- ============================================================
	-- JELLY
	-- ============================================================

	local function applyJellyAt(
		n,
		i,
		mode,
		rt,
		dt
	)

		local R = C.RADIUS

		local loner =
			mode == "loner"

		local cluster =
			mode == "cluster"


		local strCap =
			loner and 0.34 or 0.14

		local jellyMax =
			loner and 1.42 or 1.16

		local jellyMin =
			loner and 0.88 or 0.94

		local turnSpd =
			loner and 0.72 or 0.28

		local spdGate =
			loner and 18 or 28


		local ent = sent[i]

		local bx = spx[i]
		local by = spy[i]
		local bz = spz[i]

		local br = scr[i]
		local bg = scg[i]
		local bb = scb[i]


		local vx = 0
		local vy = 0
		local vz = 0

		local jux = 0
		local juy = 1

		local jelly = 1
		local jv = 0


		if IsValid(ent) then

			vx =
				ent._CETS_SVX or 0

			vy =
				ent._CETS_SVY or 0

			vz =
				ent._CETS_SVZ or 0

			jux =
				ent._CETS_JUX or 0

			juy =
				ent._CETS_JUY or 1

			jelly =
				ent._CETS_JELLY or 1

			jv =
				ent._CETS_JVEL or 0
		end


		local spd =
			sqrt(
				vx * vx +
				vy * vy
			)


		local ux = jux
		local uy = juy


		if spd > spdGate then

			local tx = vx / spd
			local ty = vy / spd

			local jd =
				atan2(
					ux * ty -
					uy * tx,

					ux * tx +
					uy * ty
				)

			local maxA =
				turnSpd * dt

			if jd > maxA then
				jd = maxA
			elseif jd < -maxA then
				jd = -maxA
			end


			local ca = cos(jd)
			local sa = sin(jd)

			ux =
				ux * ca -
				uy * sa

			uy =
				ux * sa +
				uy * ca


			local ul =
				sqrt(
					ux * ux +
					uy * uy
				)

			if ul > 0.08 then
				ux = ux / ul
				uy = uy / ul
			end
		end


		local want =
			1 +
			min(
				strCap,
				spd *
				(loner and 0.008 or 0.0035)
			)


		jv =
			jv +
			(want - jelly) *
			(loner and 28 or 18) *
			dt -
			jv *
			(loner and 4.2 or 5.5) *
			dt


		jelly =
			jelly +
			jv * dt


		jelly =
			math.Clamp(
				jelly,
				jellyMin,
				jellyMax
			)


		if IsValid(ent) then

			ent._CETS_JUX = ux
			ent._CETS_JUY = uy

			ent._CETS_JELLY = jelly
			ent._CETS_JVEL = jv
		end


		local stretch = jelly

		local squish =
			1 / sqrt(stretch)


		local onFloor =
			abs(vz) < 52
			and spd < 95


		local idle =
			spd <
				(loner and 22 or 32)
			and abs(jv) <
				(loner and 0.10 or 0.12)
			and stretch <
				(loner and 1.05 or 1.03)


		if idle then

			stretch = 1
			squish = 1

			if IsValid(ent) then
				ent._CETS_JELLY = 1
				ent._CETS_JVEL = 0
			end

		else

			local seed =
				(IsValid(ent)
				and ent:EntIndex()
				or i) *
				0.173

			local shake =
				sin(
					rt * 5.5 +
					seed * 10
				) *
				min(
					loner and 0.08 or 0.03,
					abs(jv) * 0.12 +
					spd * 0.0008
				)


			local rx = -uy
			local ry = ux

			ux =
				ux +
				rx * shake

			uy =
				uy +
				ry * shake


			local ul =
				sqrt(
					ux * ux +
					uy * uy
				)

			if ul > 0.08 then
				ux = ux / ul
				uy = uy / ul
			end
		end


		spx[i] =
			bx

		spy[i] =
			by

		spz[i] =
			bz -
			R *
			(onFloor
			and (loner and 0.04 or 0.02)
			or 0.01)


		spr[i] = R

		sux[i] = ux
		suy[i] = uy

		sst[i] = stretch
		ssq[i] = squish
		szs[i] = 1


		if loner and onFloor then

			n = n + 1

			sent[n] = ent
			sfl[n] = false

			spx[n] =
				bx

			spy[n] =
				by

			spz[n] =
				bz -
				R * 0.18

			spr[n] =
				R * 0.38

			scr[n] = br
			scg[n] = bg
			scb[n] = bb

			sux[n] = ux
			suy[n] = uy

			sst[n] =
				1.04 * squish

			ssq[n] =
				1.04 * squish

			szs[n] = 0.58
		end


		if idle then
			return n
		end


		local seed =
			(IsValid(ent)
			and ent:EntIndex()
			or i) *
			0.173


		local bulgeMul =
			loner and 1.2 or 0.55

		local bulge =
			(stretch - 1) *
			R *
			bulgeMul +
			abs(jv) *
			R *
			(loner and 0.12 or 0.04)


		local bulgeMin =
			loner and 0.06 or 0.10


		if
			bulge > R * bulgeMin
			and spd >
				(cluster and 28 or 14)
		then

			n = n + 1

			sent[n] = ent
			sfl[n] = false

			spx[n] =
				bx +
				ux * bulge

			spy[n] =
				by +
				uy * bulge

			spz[n] =
				bz -
				R * 0.04 +
				sin(
					rt * 6.0 +
					seed
				) *
				min(
					loner and 1.2 or 0.6,
					bulge * 0.2
				)

			spr[n] =
				R *
				(
					loner
					and (
						0.30 +
						min(
							0.12,
							bulge / R
						)
					)
					or (
						0.24 +
						min(
							0.06,
							bulge / R
						)
					)
				)

			scr[n] = br
			scg[n] = bg
			scb[n] = bb

			sux[n] = ux
			suy[n] = uy

			sst[n] =
				loner and 1.08 or 1.04

			ssq[n] =
				loner and 0.94 or 0.97

			szs[n] =
				loner and 0.9 or 0.95
		end


		local trailAt =
			loner and 1.10 or 1.08


		if
			stretch > trailAt
			and spd >
				(cluster and 36 or 16)
		then

			n = n + 1

			sent[n] = ent
			sfl[n] = false

			local back =
				(stretch - 1) *
				R *
				(loner and 0.5 or 0.22)

			spx[n] =
				bx -
				ux * back

			spy[n] =
				by -
				uy * back

			spz[n] =
				bz -
				R * 0.08

			spr[n] =
				R *
				(loner and 0.36 or 0.28)

			scr[n] = br
			scg[n] = bg
			scb[n] = bb

			sux[n] = ux
			suy[n] = uy

			sst[n] =
				loner and 0.92 or 0.96

			ssq[n] =
				loner and 1.1 or 1.04

			szs[n] =
				0.88
		end


		return n
	end


	local function countReal(n)
		local count = 0

		for i = 1, n do
			if not sfl[i] then
				count = count + 1
			end
		end

		return count
	end


	local function expandLoners(n)
		if not C.EnableJelly then
			return n
		end

		local real = countReal(n)

		if real < 1 or real > 8 then
			return n
		end


		local R = C.RADIUS

		local rr = R * 2.7

		local rr2 = rr * rr

		local nL = 0


		for i = 1, n do

			if sfl[i] then
				continue
			end

			local alone = true

			for j = 1, n do

				if
					i ~= j
					and not sfl[j]
				then

					local dx =
						spx[i] -
						spx[j]

					local dy =
						spy[i] -
						spy[j]

					local dz =
						spz[i] -
						spz[j]


					if
						dx * dx +
						dy * dy +
						dz * dz <
						rr2
					then

						alone = false
						break
					end
				end
			end


			if alone then
				nL = nL + 1
				lonerIdx[nL] = i
			end
		end


		if nL < 1 then
			return n
		end


		local rt = RealTime()

		local dt = FrameTime()

		if dt < 0.008 then
			dt = 0.016
		elseif dt > 0.05 then
			dt = 0.05
		end


		for i = 1, nL do

			n =
				applyJellyAt(
					n,
					lonerIdx[i],
					"loner",
					rt,
					dt
				)
		end


		return n
	end


	local function expandCluster(n)
		if not C.EnableJellyCluster then
			return n
		end

		local real = countReal(n)

		if real < 9 then
			return n
		end


		local rt = RealTime()
		local dt = FrameTime()

		if dt < 0.008 then
			dt = 0.016
		elseif dt > 0.05 then
			dt = 0.05
		end


		local original = n

		for i = 1, original do

			if not sfl[i] then

				n =
					applyJellyAt(
						n,
						i,
						"cluster",
						rt,
						dt
					)
			end
		end


		return n
	end


	-- ============================================================
	-- GATHER
	-- ============================================================

	local function gather()
		local frame =
			FrameNumber()

		local n = 0
		local idSum = 0

		local alpha =
			C.EMA or 1


		n, idSum =
			ingest(
				C.ClientBlobs,
				frame,
				alpha,
				n,
				idSum,
				false
			)


		n =
			expandLoners(n)

		n =
			expandCluster(n)


		n, idSum =
			ingest(
				C.ClientFlecks,
				frame,
				alpha,
				n,
				idSum,
				true
			)


		nSamp = n


		if
			n == lastN
			and lastN > 8
		then

			local stick =
				1.65 +
				min(
					1.8,
					(n - 8) * 0.045
				)


			for i = 1, n do

				if sfl[i] then
					continue
				end


				local dx =
					spx[i] -
					lpx[i]

				local dy =
					spy[i] -
					lpy[i]

				local dz =
					spz[i] -
					lpz[i]


				if
					abs(dx) <= stick
					and abs(dy) <= stick
					and abs(dz) <= stick
				then

					spx[i] =
						lpx[i]

					spy[i] =
						lpy[i]

					spz[i] =
						lpz[i]
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
		if n ~= lastN then
			return true
		end


		local eps =
			C.MOVE_EPS or 0.5

		local hits = 0

		local needed = 1

		if n > 8 then
			needed =
				max(
					3,
					floor(
						n * 0.16 +
						0.5
					)
				)
		end


		for i = 1, n do

			local dx =
				spx[i] -
				lpx[i]

			local dy =
				spy[i] -
				lpy[i]

			local dz =
				spz[i] -
				lpz[i]


			if
				abs(dx) > eps
				or abs(dy) > eps
				or abs(dz) > eps
			then

				hits = hits + 1

				if hits >= needed then
					return true
				end
			end
		end


		return false
	end


	local function commit(n)
		lastN = n

		for i = 1, n do
			lpx[i] = spx[i]
			lpy[i] = spy[i]
			lpz[i] = spz[i]
		end
	end

	-- ============================================================
	-- IMESH
	-- ============================================================

	local function ensureVert(i)
		local v = vbuf[i]

		if v then
			return v
		end


		v = {
			pos = Vector(),
			normal = Vector(),
			tangent = Vector(1, 0, 0),

			userdata = {
				1,
				0,
				0,
				1
			},

			u = 0,
			v = 0,

			color =
				Color(
					255,
					255,
					255,
					255
				)
		}


		vbuf[i] = v

		return v
	end


	local function fillVert(slot, id, alpha)
		local v =
			ensureVert(slot)


		v.pos.x = UX[id]
		v.pos.y = UY[id]
		v.pos.z = UZ[id]


		v.normal.x = NX[id]
		v.normal.y = NY[id]
		v.normal.z = NZ[id]


		local tangent =
			v.tangent

		tangent.x =
			TX[id] or 1

		tangent.y =
			TY[id] or 0

		tangent.z =
			TZ[id] or 0


		local ud =
			v.userdata

		ud[1] = tangent.x
		ud[2] = tangent.y
		ud[3] = tangent.z
		ud[4] = 1


		v.u =
			UU[id] or 0

		v.v =
			VV[id] or 0


		v.color =
			Color(
				CR[id] or C.COL_R,
				CG[id] or C.COL_G,
				CB[id] or C.COL_B,
				CA[id] or alpha
			)


		return v
	end


	local function newMesh()
		local ok, obj =
			pcall(MeshCtor)

		if ok and obj then
			return obj
		end

		useIMesh = false

		return nil
	end


	local function upload(alpha)
		if nIdx < 3 then
			killAllMeshes()
			return
		end


		if not haveIMesh() then
			killAllMeshes()
			return
		end


		local chunkIndex = 0
		local first = 1


		while first <= nIdx do

			local remain =
				nIdx - first + 1

			if remain > CHUNK_VERTS then
				remain =
					CHUNK_VERTS -
					(CHUNK_VERTS % 3)
			end


			chunkIndex =
				chunkIndex + 1


			local vertexCount = 0

			local last =
				first +
				remain -
				1


			for j = first, last do

				vertexCount =
					vertexCount + 1

				chunk[vertexCount] =
					fillVert(
						vertexCount,
						IX[j],
						alpha
					)
			end


			for i = vertexCount + 1, #chunk do
				chunk[i] = nil
			end


			local m =
				meshes[chunkIndex]


			if
				m
				and meshN[chunkIndex] ~=
					vertexCount
			then

				killMesh(chunkIndex)
				m = nil
			end


			if not m then

				m =
					newMesh()

				if not m then
					killAllMeshes()
					return
				end

				meshes[chunkIndex] = m
			end


			local ok =
				pcall(
					m.BuildFromTriangles,
					m,
					chunk
				)


			if not ok then

				killMesh(chunkIndex)

				m =
					newMesh()

				if not m then
					killAllMeshes()
					return
				end

				meshes[chunkIndex] = m


				ok =
					pcall(
						m.BuildFromTriangles,
						m,
						chunk
					)


				if not ok then
					useIMesh = false
					killAllMeshes()
					return
				end
			end


			meshN[chunkIndex] =
				vertexCount

			first =
				last + 1
		end


		for i =
			chunkIndex + 1,
			math.max(
				nMeshes,
				#meshes
			)
		do

			killMesh(i)
		end


		nMeshes = chunkIndex
	end

	-- ============================================================
	-- FALLBACK IMMEDIATE MESH
	-- ============================================================

	local function emit(alpha)
		alpha = alpha or 255

		local first = 1

		local cap =
			min(
				nIdx,
				8000 * 3
			)


		while first <= cap do

			local remain =
				cap - first + 1

			if remain > 30000 then
				remain =
					30000 -
					(30000 % 3)
			end


			mesh.Begin(
				MATERIAL_TRIANGLES,
				remain / 3
			)


			local last =
				first +
				remain -
				1


			for j = first, last do

				local id =
					IX[j]


				vP.x = UX[id]
				vP.y = UY[id]
				vP.z = UZ[id]


				vN.x = NX[id]
				vN.y = NY[id]
				vN.z = NZ[id]


				vT.x =
					TX[id] or 1

				vT.y =
					TY[id] or 0

				vT.z =
					TZ[id] or 0


				mesh.Position(vP)
				mesh.Normal(vN)

				mesh.TexCoord(
					0,
					UU[id] or 0,
					VV[id] or 0
				)


				if mesh.UserData then
					mesh.UserData(
						vT.x,
						vT.y,
						vT.z,
						1
					)
				end


				mesh.Color(
					CR[id],
					CG[id],
					CB[id],
					CA[id] or alpha
				)

				mesh.AdvanceVertex()
			end


			mesh.End()

			first =
				last + 1
		end
	end

	-- ============================================================
	-- BUILD
	-- ============================================================

	local function build(
		n,
		quality,
		qt,
		distance
	)

		EDGE = C.EDGE
		TRI = C.TRI

		if not EDGE or not TRI then
			return
		end


		local R =
			C.GetRadius
			and C.GetRadius(
				sent[1] and
				sent[1].CETSBlobs
			)
			or C.RADIUS


		infR =
			R *
			(qt.inf or C.INF)

		infR2 =
			infR * infR

		invR2 =
			1 / infR2


		idxCap =
			48000 * 3


		local minx = 1e12
		local miny = 1e12
		local minz = 1e12

		local maxx = -1e12
		local maxy = -1e12
		local maxz = -1e12


		for i = 1, n do

			local x = spx[i]
			local y = spy[i]
			local z = spz[i]

			if x < minx then minx = x end
			if y < miny then miny = y end
			if z < minz then minz = z end

			if x > maxx then maxx = x end
			if y > maxy then maxy = y end
			if z > maxz then maxz = z end
		end


		local span =
			maxx - minx

		local sy =
			maxy - miny

		local sz =
			maxz - minz


		if sy > span then
			span = sy
		end

		if sz > span then
			span = sz
		end


		local cell =
			qt.cell


		if distance > 1600 then

			cell =
				qt.cellFar

		elseif distance > 1200 then

			cell =
				(qt.cell +
				qt.cellFar) *
				0.5
		end


		nUnique = 0
		nIdx = 0


		local packed =
			span <
			infR * 3.35


		if packed then

			for i = 1, n do
				tmp[i] = i
			end


			march(
				tmp,
				n,
				cell
			)

		else

			local link =
				infR * 1.58

			local link2 =
				link * link


			for i = 1, n do
				parent[i] = i
				rank[i] = 0
			end


			for i = 1, n do

				for j = i + 1, n do

					local dx =
						spx[i] -
						spx[j]

					local dy =
						spy[i] -
						spy[j]

					local dz =
						spz[i] -
						spz[j]


					if
						dx * dx +
						dy * dy +
						dz * dz <=
						link2
					then

						union(i, j)
					end
				end
			end


			local roots = 0

			for i = 1, n do
				seen[i] = false
			end


			for i = 1, n do

				local root =
					find(i)

				if not seen[root] then

					seen[root] = true

					roots =
						roots + 1

					rlist[roots] =
						root
				end
			end


			for ri = 1, roots do

				if nIdx >= idxCap then
					break
				end


				local root =
					rlist[ri]

				local count = 0


				for i = 1, n do

					if find(i) == root then

						count =
							count + 1

						tmp[count] =
							i
					end
				end


				march(
					tmp,
					count,
					cell
				)
			end
		end


		upload(
			bakedAlpha
		)


		commit(n)
	end

	-- ============================================================
	-- MATERIAL
	-- ============================================================

	local matSolid
	local matClear


	local function getMaterial()
		local translucent = false

		local firstBlob =
			C.ClientBlobs[1]

		if IsValid(firstBlob) then

			local controller =
				firstBlob.CETSBlobs

			if controller then
				translucent =
					controller.Translucent == true
			end
		end


		if translucent then

			if
				not matClear
				or matClear:IsError()
			then

				matClear =
					Material(
						"npc_surface/gel"
					)
			end

			return matClear, 176
		end


		if
			not matSolid
			or matSolid:IsError()
		then

			matSolid =
				Material(
					"npc_surface/gel_opaque"
				)
		end


		return matSolid, 255
	end

	-- ============================================================
	-- DRAW
	-- ============================================================

	local function draw()
		if
			nMeshes < 1
			and nIdx < 3
		then
			return
		end


		mat, bakedAlpha =
			getMaterial()


		if not mat or mat:IsError() then
			return
		end


		render.SetColorModulation(
			1,
			1,
			1
		)

		render.SetBlend(1)

		render.SetMaterial(mat)

		render.OverrideDepthEnable(
			true,
			true
		)

		render.CullMode(
			MATERIAL_CULLMODE_CCW
		)


		if
			useIMesh
			and nMeshes > 0
		then

			local ok = true


			for i = 1, nMeshes do

				local success =
					pcall(
						function()
							meshes[i]:Draw()
						end
					)

				if not success then
					ok = false
					break
				end
			end


			if not ok then

				useIMesh = false
				nMeshes = 0

				emit(bakedAlpha)
			end

		else

			emit(bakedAlpha)
		end


		render.OverrideDepthEnable(
			false,
			false
		)

		render.CullMode(
			MATERIAL_CULLMODE_CCW
		)
	end

	-- ============================================================
	-- MAIN RENDER UPDATE
	-- ============================================================

	hook.Add(
		"PreRender",
		"CETS_BLOBS_Mesh",
		function()

			local frame =
				FrameNumber()

			if frame == lastFrame then
				return
			end

			lastFrame = frame


			local n =
				gather()


			if n < 1 then

				nUnique = 0
				nIdx = 0
				lastN = 0

				lastIdSum = 0

				killAllMeshes()

				return
			end


			local controller =
				sent[1] and
				sent[1].CETSBlobs


			local q =
				C.GetQuality(controller)


			local qt =
				C.QUALITY[q]
				or C.QUALITY[1]


			local jelly =
				controller
				and controller.Jelly
				or false


			local jellyCluster =
				controller
				and controller.JellyCluster
				or false


			local translucent =
				controller
				and controller.Translucent
				or false


			if
				q ~= lastQ
				or translucent ~= lastTrans
				or jelly ~= lastJelly
				or jellyCluster ~= lastJellyCluster
			then

				needBuild = true
				lastBuild = 0

				killAllMeshes()
			end


			local minx = 1e12
			local miny = 1e12
			local minz = 1e12

			local maxx = -1e12
			local maxy = -1e12
			local maxz = -1e12


			for i = 1, n do

				local x = spx[i]
				local y = spy[i]
				local z = spz[i]

				if x < minx then minx = x end
				if y < miny then miny = y end
				if z < minz then minz = z end

				if x > maxx then maxx = x end
				if y > maxy then maxy = y end
				if z > maxz then maxz = z end
			end


			local eye =
				EyePos()


			local dx =
				eye.x -
				(minx + maxx) *
				0.5

			local dy =
				eye.y -
				(miny + maxy) *
				0.5

			local dz =
				eye.z -
				(minz + maxz) *
				0.5


			local distance =
				sqrt(
					dx * dx +
					dy * dy +
					dz * dz
				)


			if
				not needBuild
				and q == lastQ
				and translucent == lastTrans
				and not moved(n)
				and nIdx >= 3
			then
				return
			end


			local hz =
				qt.hz or 60


			if distance > 1600 then
				hz = 20
			elseif distance > 1100 then
				hz = 30
			end


			local now =
				RealTime()


			if
				not needBuild
				and nIdx >= 3
				and q == lastQ
				and translucent == lastTrans
				and now - lastBuild <
					1 / hz
			then
				return
			end


			needBuild = false
			lastBuild = now

			lastQ = q
			lastTrans = translucent
			lastJelly = jelly
			lastJellyCluster = jellyCluster


			build(
				n,
				q,
				qt,
				distance
			)
		end
	)


	hook.Add(
		"PostDrawTranslucentRenderables",
		"CETS_BLOBS_Draw",
		function(
			depth,
			sky,
			sky3d
		)

			if depth or sky or sky3d then
				return
			end

			draw()
		end
	)


	-- ============================================================
	-- ENTITY DISCOVERY
	-- ============================================================

	hook.Add(
		"OnEntityCreated",
		"CETS_BLOBS_ClientRegister",
		function(ent)

			timer.Simple(
				0,
				function()

					if not IsValid(ent) then
						return
					end

					if not ent.IsCETSBlob then
						return
					end


					for i = 1, #C.ClientBlobs do

						if
							C.ClientBlobs[i] ==
							ent
						then
							return
						end
					end


					C.ClientBlobs[
						#C.ClientBlobs + 1
					] = ent


					ent:SetNoDraw(true)

					ent:AddEffects(
						EF_NODRAW
					)

					ent:SetRenderMode(
						RENDERMODE_NORMAL
					)


					needBuild = true
				end
			)
		end
	)


	hook.Add(
		"EntityRemoved",
		"CETS_BLOBS_ClientRemove",
		function(ent)

			if
				not ent
				or not ent.IsCETSBlob
			then
				return
			end


			needBuild = true


			for i = 1, #C.ClientBlobs do

				if
					C.ClientBlobs[i] ==
					ent
				then

					C.ClientBlobs[i] =
						C.ClientBlobs[
							#C.ClientBlobs
						]

					C.ClientBlobs[
						#C.ClientBlobs
					] = nil

					return
				end
			end
		end
	)


	-- ============================================================
	-- RENDER INVALIDATION
	-- ============================================================

	function C.InvalidateRender()
		needBuild = true
		lastBuild = 0
	end


	function C.SetQuality(quality)
		quality =
			math.Clamp(
				math.floor(
					tonumber(quality) or 2
				),
				1,
				3
			)

		C.Quality = quality

		needBuild = true

		killAllMeshes()
	end


	function C.SetJelly(enabled)
		C.EnableJelly =
			enabled == true

		needBuild = true

		killAllMeshes()
	end


	function C.SetJellyCluster(enabled)
		C.EnableJellyCluster =
			enabled == true

		needBuild = true

		killAllMeshes()
	end


	C.EnableJelly = true
	C.EnableJellyCluster = false

end

if SERVER then

	-- ============================================================
	-- LOCAL REFERENCES
	-- ============================================================

	local C = CETS_BLOBS

	local sqrt = math.sqrt
	local min = math.min
	local max = math.max
	local abs = math.abs
	local sin = math.sin
	local cos = math.cos
	local floor = math.floor

	local IsValid = IsValid
	local CurTime = CurTime
	local Vector = Vector


	-- ============================================================
	-- GLOBAL REGISTRIES
	-- ============================================================

	C.Controllers = C.Controllers or {}
	C.Blobs = C.Blobs or {}
	C.Flecks = C.Flecks or {}

	C.FleckCount = C.FleckCount or 0


	-- ============================================================
	-- INTERNAL HELPERS
	-- ============================================================

	local function validController(controller)
		return controller
			and controller.Blobs
			and controller.Owner ~= nil
	end


	local function pruneBlobs(controller)
		local blobs = controller.Blobs

		if not blobs then
			controller.Blobs = {}
			return 0
		end

		local n = 0

		for i = 1, #blobs do
			local blob = blobs[i]

			if IsValid(blob) then
				n = n + 1
				blobs[n] = blob
			end
		end

		for i = n + 1, #blobs do
			blobs[i] = nil
		end

		return n
	end


	local function blobController(blob)
		if not IsValid(blob) then
			return nil
		end

		return blob.CETSBlobs
	end


	local function getRadius(controller)
		return controller.Radius
			or C.RADIUS
			or 13.5
	end


	local function getMass(controller)
		return controller.Mass
			or C.MASS
			or 16
	end


	local function getSpeed(controller)
		return controller.Speed
			or C.SPEED
			or 70
	end


	local function getMaxSpeed(controller)
		return controller.MaxSpeed
			or C.MAX_SPD
			or 102
	end


	local function getRest(controller)
		return controller.Rest
			or C.REST
			or 1.68
	end


	local function getSpring(controller)
		return controller.Spring
			or C.SPRING
			or 24
	end


	local function getGravity(controller)
		return controller.Gravity
			or C.GRAV
			or 120
	end


	local function getSwarmRadius(controller)
		return controller.SwarmRadius
			or C.SWARM_R
			or 56
	end


	local function getCloseRadius(controller)
		return controller.CloseRadius
			or C.SWARM_R_CLOSE
			or 18
	end


	-- ============================================================
	-- REGISTRATION
	-- ============================================================

	function C.RegisterController(controller)

		if not controller then
			return
		end

		for i = 1, #C.Controllers do
			if C.Controllers[i] == controller then
				return
			end
		end

		C.Controllers[#C.Controllers + 1] = controller
	end


	function C.UnregisterController(controller)

		for i = 1, #C.Controllers do

			if C.Controllers[i] == controller then

				C.Controllers[i] =
					C.Controllers[#C.Controllers]

				C.Controllers[#C.Controllers] = nil

				return
			end
		end
	end


	function C.RegisterBlob(blob)

		if not IsValid(blob) then
			return
		end

		for i = 1, #C.Blobs do

			if C.Blobs[i] == blob then
				return
			end
		end

		C.Blobs[#C.Blobs + 1] = blob
	end


	function C.UnregisterBlob(blob)

		for i = 1, #C.Blobs do

			if C.Blobs[i] == blob then

				C.Blobs[i] =
					C.Blobs[#C.Blobs]

				C.Blobs[#C.Blobs] = nil

				return
			end
		end
	end


	-- ============================================================
	-- PHYSICS ACCESS
	-- ============================================================

	local function getPhys(blob)

		if not IsValid(blob) then
			return nil
		end

		local phys =
			blob:GetPhysicsObject()

		if not IsValid(phys) then
			return nil
		end

		return phys
	end


	local function getVelocity(blob)

		local phys =
			getPhys(blob)

		if not phys then
			return Vector()
		end

		return phys:GetVelocity()
	end


	-- ============================================================
	-- FLOOR PROBE
	-- ============================================================

	local function probeFloor(blob, controller)

		if not IsValid(blob) then
			return false, nil
		end


		local pos =
			blob:GetPos()

		local radius =
			getRadius(controller)


		local tr =
			util.TraceHull({
				start = pos + Vector(0, 0, 3),
				endpos = pos - Vector(0, 0, radius * 1.8),
				mins = Vector(
					-radius * 0.72,
					-radius * 0.72,
					0
				),
				maxs = Vector(
					radius * 0.72,
					radius * 0.72,
					radius * 0.35
				),
				mask = MASK_SOLID_BRUSHONLY
			})


		if not tr.Hit then
			return false, nil
		end


		return
			tr.HitNormal.z > 0.52,
			tr
	end


	-- ============================================================
	-- WORLD FLOOR RESPONSE
	-- ============================================================

	local function applyFloor(blob, controller)

		local grounded, tr =
			probeFloor(
				blob,
				controller
			)

		if not grounded then
			blob._CETS_Grounded = false
			return false
		end


		blob._CETS_Grounded = true
		blob._CETS_GroundNormal =
			tr.HitNormal


		local phys =
			getPhys(blob)

		if not phys then
			return true
		end


		local vel =
			phys:GetVelocity()


		if vel.z < 0 then
			vel.z =
				vel.z * 0.08

			phys:SetVelocity(vel)
		end


		return true
	end


	-- ============================================================
	-- BLOB COLLECTION
	-- ============================================================

	local function collect(controller)

		local source =
			controller.Blobs

		if not source then
			return
		end


		local n = 0


		for i = 1, #source do

			local blob =
				source[i]

			if IsValid(blob) then

				n = n + 1

				source[n] =
					blob
			end
		end


		for i = n + 1, #source do
			source[i] = nil
		end
	end


	-- ============================================================
	-- CENTROID
	-- ============================================================

	local function centroid(controller)

		local blobs =
			controller.Blobs

		local n =
			#blobs


		if n < 1 then
			return controller.Position
				or Vector()
		end


		local x = 0
		local y = 0
		local z = 0


		for i = 1, n do

			local p =
				blobs[i]:GetPos()

			x = x + p.x
			y = y + p.y
			z = z + p.z
		end


		local inv =
			1 / n


		return Vector(
			x * inv,
			y * inv,
			z * inv
		)
	end


	-- ============================================================
	-- BLOB SEPARATION
	-- ============================================================

	local function separateBlob(
		a,
		b,
		dx,
		dy,
		dz,
		dist,
		controller
	)

		if dist < 0.001 then

			dx =
				math.Rand(-1, 1)

			dy =
				math.Rand(-1, 1)

			dz =
				math.Rand(-0.2, 0.2)

			dist =
				sqrt(
					dx * dx +
					dy * dy +
					dz * dz
				)
		end


		local nx =
			dx / dist

		local ny =
			dy / dist

		local nz =
			dz / dist


		local radius =
			getRadius(controller)

		local close =
			getCloseRadius(controller)


		local wanted =
			radius *
			2 *
			0.82


		if dist >= wanted then
			return
		end


		local strength


		if dist < close then

			strength =
				(
					1 -
					dist / close
				) *
				2.8

		else

			strength =
				(
					1 -
					dist / wanted
				) *
				0.9
		end


		local pa =
			getPhys(a)

		local pb =
			getPhys(b)


		if IsValid(pa) then

			pa:ApplyForceCenter(
				Vector(
					nx * strength,
					ny * strength,
					nz * strength
				) *
				getMass(controller) *
				18
			)
		end


		if IsValid(pb) then

			pb:ApplyForceCenter(
				Vector(
					-nx * strength,
					-ny * strength,
					-nz * strength
				) *
				getMass(controller) *
				18
			)
		end
	end


	-- ============================================================
	-- BLOB ATTRACTION
	-- ============================================================

	local function attractBlob(
		a,
		b,
		dx,
		dy,
		dz,
		dist,
		controller
	)

		if dist < 0.001 then
			return
		end


		local radius =
			getRadius(controller)

		local swarm =
			getSwarmRadius(controller)


		if dist > swarm then
			return
		end


		local nx =
			dx / dist

		local ny =
			dy / dist

		local nz =
			dz / dist


		local t =
			1 -
			dist / swarm


		local strength =
			t * t *
			getSpring(controller)


		if dist < radius * 1.7 then
			strength = strength * 0.18
		end


		local pa =
			getPhys(a)

		local pb =
			getPhys(b)


		if IsValid(pa) then

			pa:ApplyForceCenter(
				Vector(
					-nx,
					-ny,
					-nz
				) *
				strength
			)
		end


		if IsValid(pb) then

			pb:ApplyForceCenter(
				Vector(
					nx,
					ny,
					nz
				) *
				strength
			)
		end
	end


	-- ============================================================
	-- PAIR FORCES
	-- ============================================================

	local function pairForces(controller)

		local blobs =
			controller.Blobs

		local count =
			#blobs


		for i = 1, count - 1 do

			local a =
				blobs[i]

			if not IsValid(a) then
				continue
			end


			local pa =
				a:GetPos()


			for j = i + 1, count do

				local b =
					blobs[j]

				if not IsValid(b) then
					continue
				end


				local pb =
					b:GetPos()


				local dx =
					pb.x - pa.x

				local dy =
					pb.y - pa.y

				local dz =
					pb.z - pa.z


				local dist2 =
					dx * dx +
					dy * dy +
					dz * dz


				local limit =
					getSwarmRadius(controller)


				if dist2 > limit * limit then
					continue
				end


				local dist =
					sqrt(dist2)


				separateBlob(
					a,
					b,
					dx,
					dy,
					dz,
					dist,
					controller
				)


				attractBlob(
					a,
					b,
					dx,
					dy,
					dz,
					dist,
					controller
				)
			end
		end
	end


	-- ============================================================
	-- CENTROID SPRING
	-- ============================================================

	local function centroidForces(controller)

		local blobs =
			controller.Blobs

		local count =
			#blobs

		if count < 2 then
			return
		end


		local center =
			centroid(controller)


		local radius =
			getSwarmRadius(controller)


		for i = 1, count do

			local blob =
				blobs[i]

			if not IsValid(blob) then
				continue
			end


			local p =
				blob:GetPos()


			local dx =
				center.x - p.x

			local dy =
				center.y - p.y

			local dz =
				center.z - p.z


			local dist =
				sqrt(
					dx * dx +
					dy * dy +
					dz * dz
				)


			if dist < radius * 0.45 then
				continue
			end


			if dist < 0.001 then
				continue
			end


			local strength =
				min(
					dist * 0.45,
					18
				)


			local phys =
				getPhys(blob)

			if not phys then
				continue
			end


			phys:ApplyForceCenter(
				Vector(
					dx,
					dy,
					dz
				) *
				strength
			)
		end
	end


	-- ============================================================
	-- MOVEMENT DAMPING
	-- ============================================================

	local function dampBlob(blob, controller)

		local phys =
			getPhys(blob)

		if not phys then
			return
		end


		local vel =
			phys:GetVelocity()


		local grounded =
			blob._CETS_Grounded


		local damping =
			grounded
			and 0.88
			or 0.96


		vel.x =
			vel.x * damping

		vel.y =
			vel.y * damping


		if grounded and vel.z < 0 then
			vel.z =
				vel.z * 0.15
		end


		phys:SetVelocity(vel)
	end


	-- ============================================================
	-- SPEED LIMIT
	-- ============================================================

	local function limitVelocity(blob, controller)

		local phys =
			getPhys(blob)

		if not phys then
			return
		end


		local maxSpeed =
			getMaxSpeed(controller)


		local vel =
			phys:GetVelocity()


		local len2 =
			vel:LengthSqr()


		if len2 <= maxSpeed * maxSpeed then
			return
		end


		local len =
			sqrt(len2)

		local scale =
			maxSpeed / len


		phys:SetVelocity(
			vel * scale
		)
	end


	-- ============================================================
	-- GENERIC STEERING
	-- ============================================================

	function C.SteerBlob(
		blob,
		direction,
		strength
	)

		if not IsValid(blob) then
			return
		end


		if not isvector(direction) then
			return
		end


		local controller =
			blobController(blob)

		if not controller then
			return
		end


		local phys =
			getPhys(blob)

		if not phys then
			return
		end


		local len =
			direction:Length()

		if len < 0.001 then
			return
		end


		local dir =
			direction / len


		strength =
			strength or
			getSpeed(controller)


		phys:ApplyForceCenter(
			dir *
			strength *
			getMass(controller)
		)
	end


	-- ============================================================
	-- GENERIC IMPULSE
	-- ============================================================

	function C.KnockBlob(
		blob,
		velocity,
		strength
	)

		if not IsValid(blob) then
			return
		end


		if not isvector(velocity) then
			return
		end


		local phys =
			getPhys(blob)

		if not phys then
			return
		end


		strength =
			strength or 1


		phys:SetVelocity(
			phys:GetVelocity() +
			velocity * strength
		)
	end


	-- ============================================================
	-- IMPACT RESPONSE
	-- ============================================================

	function C.ImpactBlob(
		blob,
		data
	)

		if not IsValid(blob) then
			return
		end


		if not data then
			return
		end


		local controller =
			blobController(blob)

		if not controller then
			return
		end


		local normal =
			data.HitNormal


		if normal then

			blob._CETS_HitNX =
				normal.x

			blob._CETS_HitNY =
				normal.y

			blob._CETS_HitNZ =
				normal.z


			if normal.z > 0.52 then

				blob._CETS_GroundedUntil =
					CurTime() + 0.9

			else

				blob._CETS_WallUntil =
					CurTime() + 1.15
			end
		end


		local speed =
			data.Speed or 0


		if speed < 80 then
			return
		end


		local kick


		if data.TheirOldVelocity
			and data.TheirOldVelocity:LengthSqr() > 900
		then

			kick =
				data.TheirOldVelocity

		elseif data.OurOldVelocity
			and data.OurOldVelocity:LengthSqr() > 400
		then

			kick =
				data.OurOldVelocity

		elseif normal then

			kick =
				-normal * speed
		end


		if kick then

			blob._CETS_HitKick =
				kick

			blob._CETS_HitKickUntil =
				CurTime() + 0.4


			controller._CETS_HitKick =
				kick

			controller._CETS_HitKickUntil =
				CurTime() + 0.4
		end
	end


	-- ============================================================
	-- BULLET RESPONSE
	-- ============================================================

	function C.BulletHit(
		blob,
		position,
		direction,
		damage
	)

		if not IsValid(blob) then
			return false
		end


		local controller =
			blobController(blob)

		if not controller then
			return false
		end


		damage =
			damage or 0


		if damage <= 0 then
			return false
		end


		local hp =
			blob.SurfHP
			or blob:Health()


		hp =
			hp - damage


		blob.SurfHP =
			hp


		blob:SetHealth(hp)


		if isvector(direction) then

			C.KnockBlob(
				blob,
				direction,
				math.Clamp(
					damage * 0.04,
					0.15,
					2
				)
			)
		end


		if hp <= 0 then

			C.SplitBlob(
				controller,
				blob,
				position
			)

			return true
		end


		return true
	end


	-- ============================================================
	-- SPLIT
	-- ============================================================

	function C.SplitBlob(
		controller,
		blob,
		position
	)

		if not validController(controller) then
			return
		end


		if not IsValid(blob) then
			return
		end


		local blobs =
			controller.Blobs


		if #blobs <= 2 then

			blob.SurfHP =
				controller.ChunkHP
				or 60

			blob:SetHealth(
				blob.SurfHP
			)

			return
		end


		local radius =
			getRadius(controller)


		local pos =
			position
			or blob:GetPos()


		local sourcePhys =
			getPhys(blob)


		local sourceVel =
			sourcePhys
			and sourcePhys:GetVelocity()
			or Vector()


		blob:Remove()


		local amount = 1


		if controller.SplitCount then
			amount =
				math.Clamp(
					controller.SplitCount,
					1,
					4
				)
		end


		for i = 1, amount do

			local offset =
				VectorRand() *
				radius *
				0.5

			offset.z =
				math.abs(offset.z)


			local newBlob =
				C.MakeBlob(
					controller,
					pos + offset
				)


			if IsValid(newBlob) then

				local phys =
					getPhys(newBlob)


				if phys then

					local impulse =
						VectorRand() *
						math.Rand(
							25,
							65
						)

					impulse.z =
						math.Rand(
							20,
							65
						)


					phys:SetVelocity(
						sourceVel +
						impulse
					)
				end
			end
		end


		C.SpawnFlecks(
			pos,
			math.min(
				4,
				#blobs
			),
			controller.Color
		)
	end


	-- ============================================================
	-- MERGE
	-- ============================================================

	local function mergeBlobs(
		controller,
		a,
		b
	)

		if not IsValid(a)
			or not IsValid(b)
		then
			return false
		end


		if a == b then
			return false
		end


		local pa =
			a:GetPos()

		local pb =
			b:GetPos()


		local midpoint =
			(pa + pb) *
			0.5


		local pA =
			getPhys(a)

		local pB =
			getPhys(b)


		local va =
			pA and
			pA:GetVelocity()
			or Vector()


		local vb =
			pB and
			pB:GetVelocity()
			or Vector()


		local velocity =
			(va + vb) *
			0.5


		local hpA =
			a.SurfHP
			or a:Health()


		local hpB =
			b.SurfHP
			or b:Health()


		local maxHP =
			(controller.ChunkHP or 60)


		local hp =
			math.min(
				maxHP,
				hpA + hpB
			)


		a:Remove()
		b:Remove()


		local blob =
			C.MakeBlob(
				controller,
				midpoint
			)


		if not IsValid(blob) then
			return false
		end


		blob.SurfHP =
			hp

		blob:SetHealth(hp)


		local phys =
			getPhys(blob)

		if phys then
			phys:SetVelocity(
				velocity
			)
		end


		return true
	end


	-- ============================================================
	-- MERGE SEARCH
	-- ============================================================

	local function tryMerge(controller)

		if controller.Merge == false then
			return
		end


		local blobs =
			controller.Blobs


		local radius =
			getRadius(controller)


		local mergeDistance =
			radius *
			1.18


		local mergeDistance2 =
			mergeDistance *
			mergeDistance


		for i = 1, #blobs - 1 do

			local a =
				blobs[i]

			if not IsValid(a) then
				continue
			end


			local pa =
				a:GetPos()


			for j = i + 1, #blobs do

				local b =
					blobs[j]

				if not IsValid(b) then
					continue
				end


				local pb =
					b:GetPos()


				local dx =
					pa.x - pb.x

				local dy =
					pa.y - pb.y

				local dz =
					pa.z - pb.z


				if
					dx * dx +
					dy * dy +
					dz * dz
					<= mergeDistance2
				then

					local va =
						getVelocity(a)

					local vb =
						getVelocity(b)


					if
						(va - vb):LengthSqr()
						<
						90 * 90
					then

						mergeBlobs(
							controller,
							a,
							b
						)

						return true
					end
				end
			end
		end


		return false
	end


	-- ============================================================
	-- FLECKS
	-- ============================================================

	function C.SpawnFlecks(
		position,
		count,
		color,
		direction
	)

		if not position then
			return
		end


		count =
			math.Clamp(
				math.floor(
					count or 3
				),
				1,
				12
			)


		local maxFlecks =
			C.MaxFlecks
			or 40


		if C.FleckCount >= maxFlecks then
			return
		end


		local remaining =
			maxFlecks -
			C.FleckCount


		count =
			math.min(
				count,
				remaining
			)


		for i = 1, count do

			local fleck =
				ents.Create(
					"cets_blobs_chunk"
				)


			if not IsValid(fleck) then
				continue
			end


			fleck.IsCETSFleck = true
			fleck.CETS_Fleck = true


			fleck:SetPos(
				position +
				VectorRand() *
				math.Rand(
					4,
					16
				)
			)


			fleck.CETS_FleckSize =
				math.Rand(
					0.7,
					1.8
				)


			if color then

				fleck.CETSColor =
					Color(
						color.r,
						color.g,
						color.b
					)
			end


			local velocity

			if isvector(direction)
				and direction:LengthSqr() > 0.01
			then

				local dir =
					direction:GetNormalized()

				velocity =
					dir *
					math.Rand(
						35,
						140
					)

				velocity.z =
					math.Rand(
						30,
						110
					)

			else

				velocity =
					VectorRand() *
					math.Rand(
						20,
						100
					)

				velocity.z =
					math.Rand(
						30,
						110
					)
			end


			fleck.CETSLaunchVelocity =
				velocity


			fleck:Spawn()
			fleck:Activate()


			C.FleckCount =
				C.FleckCount + 1

			fleck.CETSCounted =
				true
		end
	end


	-- ============================================================
	-- DAMAGE API
	-- ============================================================

	function C.DamageBlob(
		blob,
		damageInfo
	)

		if not IsValid(blob) then
			return false
		end


		local controller =
			blobController(blob)

		if not controller then
			return false
		end


		local damage =
			damageInfo
			and damageInfo:GetDamage()
			or 0


		if damage <= 0 then
			return false
		end


		local hp =
			blob.SurfHP
			or blob:Health()


		hp =
			hp - damage


		blob.SurfHP =
			hp

		blob:SetHealth(hp)


		local force =
			damageInfo
			and damageInfo:GetDamageForce()
			or Vector()


		if force:LengthSqr() > 0 then

			C.KnockBlob(
				blob,
				force:GetNormalized(),
				math.Clamp(
					damage * 0.02,
					0.1,
					2
				)
			)
		end


		if hp <= 0 then

			C.SplitBlob(
				controller,
				blob,
				blob:GetPos()
			)

			return true
		end


		return false
	end


	-- ============================================================
	-- SIMULATION
	-- ============================================================

	function C.Sim(controller)

		if not validController(controller) then
			return
		end


		pruneBlobs(controller)


		local count =
			#controller.Blobs


		if count <= 0 then
			return
		end


		-- --------------------------------------------------------
		-- FLOOR
		-- --------------------------------------------------------

		for i = 1, count do

			local blob =
				controller.Blobs[i]

			if not IsValid(blob) then
				continue
			end


			applyFloor(
				blob,
				controller
			)
		end


		-- --------------------------------------------------------
		-- PAIR INTERACTION
		-- --------------------------------------------------------

		pairForces(controller)


		-- --------------------------------------------------------
		-- KEEP THE CLUSTER TOGETHER
		-- --------------------------------------------------------

		centroidForces(controller)


		-- --------------------------------------------------------
		-- PHYSICS LIMITS
		-- --------------------------------------------------------

		for i = 1, count do

			local blob =
				controller.Blobs[i]

			if not IsValid(blob) then
				continue
			end


			dampBlob(
				blob,
				controller
			)


			limitVelocity(
				blob,
				controller
			)
		end


		-- --------------------------------------------------------
		-- MERGE
		-- --------------------------------------------------------

		if controller.Merge ~= false then

			local now =
				CurTime()


			if
				(controller._CETS_NextMerge or 0)
				<= now
			then

				controller._CETS_NextMerge =
					now + 0.08

				tryMerge(controller)
			end
		end


		-- --------------------------------------------------------
		-- CONTROLLER CALLBACK
		-- --------------------------------------------------------

		if controller.OnSimulate then

			controller:OnSimulate(
				controller.Blobs
			)
		end
	end


	-- ============================================================
	-- PHYSICS COLLISION
	-- ============================================================

	hook.Add(
		"PhysicsCollide",
		"CETS_BLOBS_Impact",
		function(
			data,
			phys
		)

			local ent =
				data.HitEntity


			if not IsValid(ent) then
				return
			end


			if not ent.IsCETSBlob then
				return
			end


			C.ImpactBlob(
				ent,
				data
			)
		end
	)


	-- ============================================================
	-- ENTITY DAMAGE
	-- ============================================================

	hook.Add(
		"EntityTakeDamage",
		"CETS_BLOBS_Damage",
		function(
			ent,
			damageInfo
		)

			if not IsValid(ent) then
				return
			end


			if not ent.IsCETSBlob then
				return
			end


			C.DamageBlob(
				ent,
				damageInfo
			)


			-- The blob owns its own damage model.
			--
			-- Do not allow normal base-entity damage to remove it
			-- independently of the CETS simulation.

			damageInfo:SetDamage(0)
		end
	)


	-- ============================================================
	-- BULLET DETECTION
	-- ============================================================

	hook.Add(
		"EntityFireBullets",
		"CETS_BLOBS_Bullets",
		function(
			shooter,
			data
		)

			if not data
				or not data.Src
				or not data.Dir
			then
				return
			end


			local start =
				data.Src

			local finish =
				start +
				data.Dir *
				4096


			local tr =
				util.TraceLine({
					start = start,
					endpos = finish,
					mask = MASK_SHOT,
					filter = shooter
				})


			local hit =
				tr.Entity


			if
				IsValid(hit)
				and hit.IsCETSBlob
			then

				C.BulletHit(
					hit,
					tr.HitPos,
					data.Dir,
					data.Damage
					or 10
				)

				-- The important part:
				--
				-- the bullet is not converted into a normal physics
				-- impact against the invisible sphere.

				return
			end
		end
	)


	-- ============================================================
	-- CONTROLLER THINK
	-- ============================================================

	hook.Add(
		"Think",
		"CETS_BLOBS_Simulation",
		function()

			local now =
				CurTime()


			for i = #C.Controllers, 1, -1 do

				local controller =
					C.Controllers[i]


				if not validController(controller) then

					table.remove(
						C.Controllers,
						i
					)

					continue
				end


				if
					(controller._CETS_NextThink or 0)
					> now
				then
					continue
				end


				controller._CETS_NextThink =
					now + (
						controller.TickInterval
						or 0
					)


				C.Sim(
					controller
				)
			end
		end
	)


	-- ============================================================
	-- FLECK CLEANUP
	-- ============================================================

	hook.Add(
		"EntityRemoved",
		"CETS_BLOBS_FleckCount",
		function(ent)

			if not ent.CETSCounted then
				return
			end


			ent.CETSCounted =
				false


			C.FleckCount =
				max(
					0,
					C.FleckCount - 1
				)
		end
	)


	-- ============================================================
	-- SPLASH API
	-- ============================================================

	local lastSplash = 0


	function C.WaterHit(
		position,
		speed,
		blob,
		floorHit
	)

		if not position then
			return
		end


		speed =
			speed or 80


		if speed < 110 then
			return
		end


		if floorHit
			and speed < 140
		then
			return
		end


		local now =
			CurTime()


		if IsValid(blob) then

			if
				(blob._CETS_SplashUntil or 0)
				> now
			then
				return
			end


			blob._CETS_SplashUntil =
				now + 0.9
		else

			if
				now - lastSplash <
				0.18
			then
				return
			end


			lastSplash =
				now
		end


		local volume =
			math.Clamp(
				speed / 1100,
				0.12,
				0.38
			)


		if speed > 220 then

			sound.Play(
				"ambient/water/water_splash" ..
				math.random(1, 3) ..
				".wav",

				position,
				68,
				math.random(
					86,
					114
				),
				volume
			)

		else

			sound.Play(
				"player/footsteps/slosh" ..
				math.random(1, 4) ..
				".wav",

				position,
				60,
				math.random(
					86,
					114
				),
				volume
			)
		end
	end


	-- ============================================================
	-- GENERIC CONTROLLER BLAST
	-- ============================================================

	function C.Blast(
		controller,
		position,
		radius,
		force
	)

		if not validController(controller) then
			return
		end


		position =
			position
			or centroid(controller)


		radius =
			radius
			or 96


		force =
			force
			or 500


		local radius2 =
			radius * radius


		for i = 1, #controller.Blobs do

			local blob =
				controller.Blobs[i]

			if not IsValid(blob) then
				continue
			end


			local p =
				blob:GetPos()


			local dx =
				p.x - position.x

			local dy =
				p.y - position.y

			local dz =
				p.z - position.z


			local dist2 =
				dx * dx +
				dy * dy +
				dz * dz


			if dist2 >= radius2 then
				continue
			end


			local dist =
				sqrt(
					max(
						dist2,
						0.001
					)
				)


			local falloff =
				1 -
				dist / radius


			local dir =
				Vector(
					dx / dist,
					dy / dist,
					dz / dist
				)


			local phys =
				getPhys(blob)

			if phys then

				phys:ApplyForceCenter(
					dir *
					force *
					falloff
				)
			end
		end


		C.SpawnFlecks(
			position,
			5,
			controller.Color
		)
	end

end

-- ============================================================
-- STEP 6
-- PUBLIC CONTROLLER / SPAWN API
-- ============================================================
--
-- Add this to:
--
--	lua/autorun/cets_blobs.lua
--
-- This is the part that makes CETS_BLOBS usable by:
--
--	* entities
--	* weapons
--	* tools
--	* scripted systems
--	* gamemodes
--
-- No NPC entity is required.
-- ============================================================


CETS_BLOBS = CETS_BLOBS or {}

local C = CETS_BLOBS


-- ============================================================
-- DEFAULTS
-- ============================================================

C.NUM =
	C.NUM or 32

C.MAX =
	C.MAX or 72

C.RADIUS =
	C.RADIUS or 13.5

C.SPEED =
	C.SPEED or 70

C.MASS =
	C.MASS or 16

C.CHUNK_HP =
	C.CHUNK_HP or 60

C.MAX_SPD =
	C.MAX_SPD or 102

C.SWARM_R =
	C.SWARM_R or 56

C.SWARM_R_CLOSE =
	C.SWARM_R_CLOSE or 18

C.SPRING =
	C.SPRING or 24

C.GRAV =
	C.GRAV or 120

C.REST =
	C.REST or 1.68

C.MAX_FLECKS =
	C.MAX_FLECKS or 40

C.COL_R =
	C.COL_R or 86

C.COL_G =
	C.COL_G or 170

C.COL_B =
	C.COL_B or 208


-- ============================================================
-- DEFAULT COLOR
-- ============================================================

local function copyColor(color)

	if not color then

		return Color(
			C.COL_R,
			C.COL_G,
			C.COL_B
		)
	end


	return Color(
		math.Clamp(
			color.r or C.COL_R,
			0,
			255
		),

		math.Clamp(
			color.g or C.COL_G,
			0,
			255
		),

		math.Clamp(
			color.b or C.COL_B,
			0,
			255
		),

		math.Clamp(
			color.a == nil
				and 255
				or color.a,
			0,
			255
		)
	)
end


-- ============================================================
-- CONTROLLER
-- ============================================================

local Controller = {}

Controller.__index =
	Controller


-- ============================================================
-- CREATE
-- ============================================================

function C.Create(
	owner,
	options
)

	options =
		options or {}


	local controller =
		setmetatable(
			{},
			Controller
		)


	-- --------------------------------------------------------
	-- OWNER
	-- --------------------------------------------------------

	controller.Owner =
		IsValid(owner)
		and owner
		or nil


	-- --------------------------------------------------------
	-- BLOB SETTINGS
	-- --------------------------------------------------------

	controller.Count =
		math.max(
			1,
			math.floor(
				options.Count
				or C.NUM
			)
		)


	controller.Max =
		math.max(
			controller.Count,
			math.floor(
				options.Max
				or C.MAX
			)
		)


	controller.Radius =
		options.Radius
		or C.RADIUS


	controller.Speed =
		options.Speed
		or C.SPEED


	controller.Mass =
		options.Mass
		or C.MASS


	controller.ChunkHP =
		options.HP
		or options.ChunkHP
		or C.CHUNK_HP


	controller.MaxSpeed =
		options.MaxSpeed
		or C.MAX_SPD


	-- --------------------------------------------------------
	-- SWARM SETTINGS
	-- --------------------------------------------------------

	controller.SwarmRadius =
		options.SwarmRadius
		or C.SWARM_R


	controller.CloseRadius =
		options.CloseRadius
		or C.SWARM_R_CLOSE


	controller.Spring =
		options.Spring
		or C.SPRING


	controller.Gravity =
		options.Gravity
		or C.GRAV


	controller.Rest =
		options.Rest
		or C.REST


	controller.Merge =
		options.Merge ~= false


	controller.SplitCount =
		options.SplitCount
		or 1


	-- --------------------------------------------------------
	-- PHYSICS COLLISION
	--
	-- ALL FALSE BY DEFAULT.
	-- --------------------------------------------------------

	controller.CollideWorld =
		options.CollideWorld == true


	controller.CollideProps =
		options.CollideProps == true


	controller.CollidePlayers =
		options.CollidePlayers == true


	controller.CollideNPCs =
		options.CollideNPCs == true


	-- --------------------------------------------------------
	-- VISUAL SETTINGS
	-- --------------------------------------------------------

	controller.Color =
		copyColor(
			options.Color
		)


	controller.MultiColor =
		options.MultiColor == true


	controller.Quality =
		math.Clamp(
			math.floor(
				options.Quality
				or 2
			),
			1,
			3
		)


	controller.Translucent =
		options.Translucent == true


	controller.Jelly =
		options.Jelly ~= false


	controller.JellyCluster =
		options.JellyCluster == true


	-- --------------------------------------------------------
	-- FLECK SETTINGS
	-- --------------------------------------------------------

	controller.MaxFlecks =
		options.MaxFlecks
		or C.MAX_FLECKS


	-- --------------------------------------------------------
	-- STATE
	-- --------------------------------------------------------

	controller.Blobs =
		{}


	controller.Position =
		IsValid(owner)
		and owner:GetPos()
		or Vector()


	controller.Spawned =
		false


	controller.Removed =
		false


	controller.TickInterval =
		options.TickInterval
		or 0


	controller._CETS_NextThink =
		0


	controller._CETS_NextMerge =
		0


	-- --------------------------------------------------------
	-- CALLBACKS
	-- --------------------------------------------------------

	controller.OnSpawn =
		options.OnSpawn


	controller.OnRemove =
		options.OnRemove


	controller.OnBlobCreated =
		options.OnBlobCreated


	controller.OnBlobRemoved =
		options.OnBlobRemoved


	controller.OnBlobDamage =
		options.OnBlobDamage


	controller.OnBlobSplit =
		options.OnBlobSplit


	controller.OnBlobImpact =
		options.OnBlobImpact


	controller.OnSimulate =
		options.OnSimulate


	-- --------------------------------------------------------
	-- OWNER REFERENCE
	-- --------------------------------------------------------

	if IsValid(owner) then

		owner.CETSBlobs =
			controller
	end


	C.RegisterController(
		controller
	)


	return controller
end


-- ============================================================
-- POSITION
-- ============================================================

function Controller:SetPos(position)

	if not isvector(position) then
		return
	end


	self.Position =
		position


	for i = 1, #self.Blobs do

		local blob =
			self.Blobs[i]


		if IsValid(blob) then

			local delta =
				position -
				self._CETS_LastPosition


			if self._CETS_LastPosition then

				blob:SetPos(
					blob:GetPos() +
					delta
				)

			end
		end
	end


	self._CETS_LastPosition =
		position
end


function Controller:GetPos()

	return self.Position
end


-- ============================================================
-- OWNER
-- ============================================================

function Controller:GetOwner()

	return self.Owner
end


-- ============================================================
-- BLOB COUNT
-- ============================================================

function Controller:CountBlobs()

	local count =
		0


	for i = 1, #self.Blobs do

		if IsValid(
			self.Blobs[i]
		) then

			count =
				count + 1
		end
	end


	return count
end


-- ============================================================
-- CAN SPAWN
-- ============================================================

function Controller:CanSpawnBlob()

	if self.Removed then
		return false
	end


	return self:CountBlobs()
		< self.Max
end


-- ============================================================
-- MAKE BLOB
-- ============================================================

function C.MakeBlob(
	controller,
	position
)

	if not controller
		or controller.Removed
	then
		return nil
	end


	if not controller:CanSpawnBlob() then
		return nil
	end


	position =
		position
		or controller.Position


	if not isvector(position) then
		return nil
	end


	local blob =
		ents.Create(
			"cets_blobs_chunk"
		)


	if not IsValid(blob) then
		return nil
	end


	-- --------------------------------------------------------
	-- TYPE
	-- --------------------------------------------------------

	blob.IsCETSBlob =
		true


	blob.IsCETSFleck =
		false


	-- --------------------------------------------------------
	-- CONTROLLER
	-- --------------------------------------------------------

	blob.CETSBlobs =
		controller


	-- --------------------------------------------------------
	-- COLOR
	-- --------------------------------------------------------

	blob.CETSColor =
		copyColor(
			controller.Color
		)


	-- --------------------------------------------------------
	-- POSITION
	-- --------------------------------------------------------

	blob:SetPos(
		position
	)


	-- --------------------------------------------------------
	-- SPAWN
	-- --------------------------------------------------------

	blob:Spawn()
	blob:Activate()


	-- --------------------------------------------------------
	-- HEALTH
	-- --------------------------------------------------------

	local hp =
		controller.ChunkHP


	blob.SurfHP =
		hp


	blob:SetHealth(hp)
	blob:SetMaxHealth(hp)


	-- --------------------------------------------------------
	-- INITIAL PHYSICS
	-- --------------------------------------------------------

	local phys =
		blob:GetPhysicsObject()


	if IsValid(phys) then

		phys:SetMass(
			controller.Mass
		)


		phys:SetVelocity(
			Vector()
		)


		phys:Wake()
	end


	-- --------------------------------------------------------
	-- ADD TO CONTROLLER
	-- --------------------------------------------------------

	controller.Blobs[
		#controller.Blobs + 1
	] =
		blob


	-- --------------------------------------------------------
	-- CALLBACK
	-- --------------------------------------------------------

	if controller.OnBlobCreated then

		controller:OnBlobCreated(
			blob
		)
	end


	return blob
end


-- ============================================================
-- SPAWN RING
-- ============================================================

function C.SpawnRing(
	controller,
	count,
	radius
)

	if not controller
		or controller.Removed
	then
		return
	end


	count =
		math.max(
			1,
			math.floor(
				count
				or controller.Count
			)
		)


	count =
		math.min(
			count,
			controller.Max
		)


	radius =
		radius
		or controller.Radius


	local center =
		controller.Position


	-- --------------------------------------------------------
	-- GOLDEN ANGLE
	-- --------------------------------------------------------

	local golden =
		math.pi *
		(3 - math.sqrt(5))


	for i = 1, count do

		local t =
			(i - 1) /
			math.max(
				count,
				1
			)


		local angle =
			t *
			math.pi *
			2


		local z =
			1 -
			t * 2


		local r =
			math.sqrt(
				math.max(
					0,
					1 - z * z
				)
			)


		-- Slightly irregular sphere/shell.
		local pos =
			center +
			Vector(
				math.cos(angle) * r,
				math.sin(angle) * r,
				z
			) *
			radius


		pos.z =
			pos.z +
			controller.Rest


		local blob =
			C.MakeBlob(
				controller,
				pos
			)


		if IsValid(blob) then

			local phys =
				blob:GetPhysicsObject()


			if IsValid(phys) then

				local randomVelocity =
					VectorRand() *
					math.Rand(
						0,
						8
					)


				phys:SetVelocity(
					randomVelocity
				)
			end
		end
	end


	controller._CETS_LastPosition =
		center


	if controller.OnSpawn then

		controller:OnSpawn(
			controller.Blobs
		)
	end
end


-- ============================================================
-- SPAWN SINGLE
-- ============================================================

function Controller:Spawn(
	count,
	radius
)

	if self.Removed then
		return self
	end


	if self.Spawned then
		return self
	end


	self.Spawned =
		true


	self.Position =
		self.Position
		or Vector()


	self._CETS_LastPosition =
		self.Position


	C.SpawnRing(
		self,
		count
			or self.Count,
		radius
			or self.Radius
	)


	return self
end


-- ============================================================
-- THINK
-- ============================================================

function Controller:Think()

	if self.Removed then
		return false
	end


	if not self.Spawned then

		self:Spawn()
	end


	C.Sim(
		self
	)


	return true
end


-- ============================================================
-- REMOVE
-- ============================================================

function Controller:Remove()

	if self.Removed then
		return
	end


	self.Removed =
		true


	-- --------------------------------------------------------
	-- REMOVE BLOBS
	-- --------------------------------------------------------

	for i = #self.Blobs, 1, -1 do

		local blob =
			self.Blobs[i]


		if IsValid(blob) then

			if self.OnBlobRemoved then

				self:OnBlobRemoved(
					blob
				)
			end


			blob.CETSBlobs =
				nil


			blob:Remove()
		end


		self.Blobs[i] =
			nil
	end


	-- --------------------------------------------------------
	-- OWNER
	-- --------------------------------------------------------

	if IsValid(self.Owner)
		and self.Owner.CETSBlobs == self
	then

		self.Owner.CETSBlobs =
			nil
	end


	-- --------------------------------------------------------
	-- REGISTRY
	-- --------------------------------------------------------

	C.UnregisterController(
		self
	)


	-- --------------------------------------------------------
	-- CALLBACK
	-- --------------------------------------------------------

	if self.OnRemove then

		self:OnRemove()
	end
end


-- ============================================================
-- SETTERS
-- ============================================================

function Controller:SetColor(
	color
)

	self.Color =
		copyColor(color)


	for i = 1, #self.Blobs do

		local blob =
			self.Blobs[i]


		if IsValid(blob) then

			blob.CETSColor =
				copyColor(
					self.Color
				)


			blob:SetNWVector(
				"CETS_Color",
				Vector(
					self.Color.r / 255,
					self.Color.g / 255,
					self.Color.b / 255
				)
			)
		end
	end
end


function Controller:SetRadius(
	radius
)

	self.Radius =
		math.max(
			0.1,
			radius or C.RADIUS
		)
end


function Controller:SetSpeed(
	speed
)

	self.Speed =
		math.max(
			0,
			speed or C.SPEED
		)
end


function Controller:SetMass(
	mass
)

	self.Mass =
		math.max(
			0.01,
			mass or C.MASS
		)


	for i = 1, #self.Blobs do

		local blob =
			self.Blobs[i]


		if IsValid(blob) then

			local phys =
				blob:GetPhysicsObject()


			if IsValid(phys) then

				phys:SetMass(
					self.Mass
				)
			end
		end
	end
end


function Controller:SetHP(
	hp
)

	self.ChunkHP =
		math.max(
			1,
			hp or C.CHUNK_HP
		)


	for i = 1, #self.Blobs do

		local blob =
			self.Blobs[i]


		if IsValid(blob) then

			blob.SurfHP =
				self.ChunkHP


			blob:SetMaxHealth(
				self.ChunkHP
			)


			blob:SetHealth(
				self.ChunkHP
			)
		end
	end
end


function Controller:SetQuality(
	quality
)

	self.Quality =
		math.Clamp(
			math.floor(
				quality or 2
			),
			1,
			3
		)


	if C.InvalidateRender then

		C.InvalidateRender()
	end
end


function Controller:SetJelly(
	enabled
)

	self.Jelly =
		enabled ~= false


	if C.InvalidateRender then

		C.InvalidateRender()
	end
end


function Controller:SetJellyCluster(
	enabled
)

	self.JellyCluster =
		enabled == true


	if C.InvalidateRender then

		C.InvalidateRender()
	end
end


-- ============================================================
-- APPLY FORCE TO ALL BLOBS
-- ============================================================

function Controller:ApplyForce(
	force
)

	if not isvector(force) then
		return
	end


	for i = 1, #self.Blobs do

		local blob =
			self.Blobs[i]


		if not IsValid(blob) then
			continue
		end


		local phys =
			blob:GetPhysicsObject()


		if IsValid(phys) then

			phys:ApplyForceCenter(
				force
			)
		end
	end
end


-- ============================================================
-- APPLY VELOCITY TO ALL BLOBS
-- ============================================================

function Controller:SetVelocity(
	velocity
)

	if not isvector(velocity) then
		return
	end


	for i = 1, #self.Blobs do

		local blob =
			self.Blobs[i]


		if not IsValid(blob) then
			continue
		end


		local phys =
			blob:GetPhysicsObject()


		if IsValid(phys) then

			phys:SetVelocity(
				velocity
			)
		end
	end
end


-- ============================================================
-- FIND NEAREST OWN BLOB
-- ============================================================

function Controller:GetNearestBlob(
	position,
	distance
)

	if not position then
		return nil
	end


	distance =
		distance
		or math.huge


	local best
	local bestDist2 =
		distance * distance


	for i = 1, #self.Blobs do

		local blob =
			self.Blobs[i]


		if not IsValid(blob) then
			continue
		end


		local delta =
			blob:GetPos() -
			position


		local dist2 =
			delta:LengthSqr()


		if dist2 < bestDist2 then

			best =
				blob

			bestDist2 =
				dist2
		end
	end


	return best
end


-- ============================================================
-- CLEAR BLOBS
-- ============================================================

function Controller:Clear()

	for i = #self.Blobs, 1, -1 do

		local blob =
			self.Blobs[i]


		if IsValid(blob) then

			blob:Remove()
		end


		self.Blobs[i] =
			nil
	end
end


-- ============================================================
-- MANUAL BLOB CREATION
-- ============================================================

function Controller:AddBlob(
	position
)

	return C.MakeBlob(
		self,
		position
	)
end


-- ============================================================
-- MANUAL SPLIT
-- ============================================================

function Controller:Split(
	blob,
	position
)

	return C.SplitBlob(
		self,
		blob,
		position
	)
end


-- ============================================================
-- BLAST
-- ============================================================

function Controller:Blast(
	position,
	radius,
	force
)

	return C.Blast(
		self,
		position,
		radius,
		force
	)
end


-- ============================================================
-- EXPOSE CONTROLLER METHODS
-- ============================================================

C.Controller =
	Controller


-- ============================================================
-- GLOBAL CONVENIENCE FUNCTIONS
-- ============================================================

function CETS_BLOBS.GetController(
	owner
)

	if not IsValid(owner) then
		return nil
	end


	return owner.CETSBlobs
end


function CETS_BLOBS.Remove(
	controller
)

	if controller
		and controller.Remove
	then

		controller:Remove()
	end
end


-- ============================================================
-- OWNER CLEANUP
-- ============================================================

if SERVER then

	hook.Add(
		"EntityRemoved",
		"CETS_BLOBS_OwnerCleanup",
		function(ent)

			local controller =
				ent.CETSBlobs


			if not controller then
				return
			end


			if controller.Owner ~= ent then
				return
			end


			controller:Remove()
		end
	)

end