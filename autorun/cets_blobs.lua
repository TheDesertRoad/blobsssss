-- ============================================================
-- CETS_BLOBS
-- General-purpose blob simulation / rendering library
-- ============================================================
--
-- File:
--	lua/autorun/cets_blobs.lua
--
-- This file is intentionally self-contained.
--
-- No NPC logic.
-- No spawnmenu.
-- No NPC-specific cvars.
-- No dependency on npc_surface.
--
-- Public namespace:
--	CETS_BLOBS
--
-- ============================================================

CETS_BLOBS = CETS_BLOBS or {}

local C = CETS_BLOBS

C.Version = "2.0.0"

-- ============================================================
-- CONSTANTS
-- ============================================================

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

C.MAX_FLECKS = 40

-- ============================================================
-- QUALITY PRESETS
-- ============================================================

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

-- ============================================================
-- DEFAULT CONTROLLER CONFIG
-- ============================================================

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

	Translucent = false,
	MultiColor = false,

	Gravity = true,

	CollideWorld = false,
	CollideProps = false,
	CollidePlayers = false,
	CollideNPCs = false,
	CollideBlobs = false,

	EnableFlecks = true,
	MaxFlecks = 40,

	ImpactSounds = false,

	Merge = true,

	MaxSpeed = 102,

	SwarmRadius = 56,
	CloseRadius = 18,

	Spring = 24,
	GravityForce = 120,

	Rest = 1.68
}

-- ============================================================
-- REGISTRIES
-- ============================================================

C.Controllers = C.Controllers or {}
C.Blobs = C.Blobs or {}
C.Flecks = C.Flecks or {}

if CLIENT then
	C.ClientBlobs = C.ClientBlobs or {}
	C.ClientFlecks = C.ClientFlecks or {}
end

-- ============================================================
-- UTILITY
-- ============================================================

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

	for key, value in pairs(C.Defaults) do
		if istable(value) then
			if key == "Color" then
				out[key] = copyColor(value)
			else
				out[key] = table.Copy(value)
			end
		else
			out[key] = value
		end
	end

	if istable(config) then
		for key, value in pairs(config) do
			if key == "Color" then
				out[key] = copyColor(value)
			else
				out[key] = value
			end
		end
	end

	out.Count = math.max(
		1,
		math.floor(
			tonumber(out.Count)
			or C.NUM
		)
	)

	out.MaxCount = math.max(
		out.Count,
		math.floor(
			tonumber(out.MaxCount)
			or C.MAX
		)
	)

	out.Radius = math.max(
		0.1,
		tonumber(out.Radius)
		or C.RADIUS
	)

	out.Mass = math.max(
		0.01,
		tonumber(out.Mass)
		or C.MASS
	)

	out.Speed = math.max(
		0,
		tonumber(out.Speed)
		or C.SPEED
	)

	out.HP = math.max(
		1,
		tonumber(out.HP)
		or C.CHUNK_HP
	)

	out.Quality = math.Clamp(
		math.floor(
			tonumber(out.Quality)
			or 2
		),
		1,
		3
	)

	out.MaxSpeed = math.max(
		0,
		tonumber(out.MaxSpeed)
		or C.MAX_SPD
	)

	return out
end

-- ============================================================
-- ENTITY TESTS
-- ============================================================

function C.IsBlob(ent)
	if not IsValid(ent) then
		return false
	end

	if ent.IsCETSBlob == true then
		return true
	end

	if CLIENT and ent:GetNWBool("CETS_Blob", false) then
		return true
	end

	return false
end

function C.IsFleck(ent)
	if not IsValid(ent) then
		return false
	end

	if ent.IsCETSFleck == true then
		return true
	end

	if CLIENT and ent:GetNWBool("CETS_Fleck", false) then
		return true
	end

	return false
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
		C.COL_B,
		255
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

function C.GetQuality(controller)
	if controller and controller.Quality then
		return math.Clamp(
			math.floor(
				tonumber(controller.Quality) or 2
			),
			1,
			3
		)
	end

	return 2
end

function C.GetMaxCount(controller)
	if controller and controller.MaxCount then
		return controller.MaxCount
	end

	return C.MAX
end

-- ============================================================
-- REGISTRATION
-- ============================================================
--
-- IMPORTANT:
-- These functions are defined BEFORE Create().
--
-- This fixes:
--
-- attempt to call field 'RegisterController'
-- (a nil value)
--
-- ============================================================

function C.RegisterController(controller)
	if not controller then
		return
	end

	C.Controllers[controller] = true

	return controller
end

function C.UnregisterController(controller)
	if not controller then
		return
	end

	C.Controllers[controller] = nil
end

function C.RegisterBlob(blob)
	if not IsValid(blob) then
		return
	end

	C.Blobs[blob] = true
end

function C.UnregisterBlob(blob)
	if not blob then
		return
	end

	C.Blobs[blob] = nil
end

function C.RegisterFleck(fleck)
	if not IsValid(fleck) then
		return
	end

	C.Flecks[fleck] = true
end

function C.UnregisterFleck(fleck)
	if not fleck then
		return
	end

	C.Flecks[fleck] = nil
end

-- ============================================================
-- CONTROLLER
-- ============================================================

C.Controller = C.Controller or {}

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
		return self
	end

	self.Position = Vector(
		pos.x,
		pos.y,
		pos.z
	)

	return self
end

function C.Controller:GetColor()
	return self.Color
end

function C.Controller:SetColor(col)
	self.Color = copyColor(col)

	for i = #self.Blobs, 1, -1 do
		local blob = self.Blobs[i]

		if IsValid(blob) then
			blob.CETSColor = copyColor(self.Color)

			blob:SetGelR(self.Color.r)
			blob:SetGelG(self.Color.g)
			blob:SetGelB(self.Color.b)

			blob:SetNWInt(
				"CETS_R",
				self.Color.r
			)

			blob:SetNWInt(
				"CETS_G",
				self.Color.g
			)

			blob:SetNWInt(
				"CETS_B",
				self.Color.b
			)
		end
	end

	return self
end

function C.Controller:GetCount()
	local count = 0

	for i = #self.Blobs, 1, -1 do
		if IsValid(self.Blobs[i]) then
			count = count + 1
		else
			table.remove(self.Blobs, i)
		end
	end

	return count
end

function C.Controller:CountBlobs()
	return self:GetCount()
end

function C.Controller:CanSpawnBlob()
	if self.Removed then
		return false
	end

	return self:GetCount() < self.MaxCount
end

function C.Controller:SetRadius(radius)
	self.Radius = math.max(
		0.1,
		tonumber(radius) or self.Radius
	)

	for _, blob in ipairs(self.Blobs) do
		if IsValid(blob) then
			blob.CETSRadius = self.Radius
			blob:SetNWFloat(
				"CETS_Radius",
				self.Radius
			)
		end
	end

	return self
end

function C.Controller:SetSpeed(speed)
	self.Speed = math.max(
		0,
		tonumber(speed) or self.Speed
	)

	for _, blob in ipairs(self.Blobs) do
		if IsValid(blob) then
			blob.CETSSpeed = self.Speed
			blob:SetNWFloat(
				"CETS_Speed",
				self.Speed
			)
		end
	end

	return self
end

function C.Controller:SetMass(mass)
	self.Mass = math.max(
		0.01,
		tonumber(mass) or self.Mass
	)

	for _, blob in ipairs(self.Blobs) do
		if IsValid(blob) then
			blob.CETSMass = self.Mass

			local phys = blob:GetPhysicsObject()

			if IsValid(phys) then
				phys:SetMass(self.Mass)
			end
		end
	end

	return self
end

function C.Controller:SetHP(hp)
	self.HP = math.max(
		1,
		tonumber(hp) or self.HP
	)

	for _, blob in ipairs(self.Blobs) do
		if IsValid(blob) then
			blob.CETSHp = self.HP

			blob:SetHealth(self.HP)
			blob:SetMaxHealth(self.HP)
		end
	end

	return self
end

function C.Controller:SetQuality(quality)
	self.Quality = math.Clamp(
		math.floor(
			tonumber(quality) or 2
		),
		1,
		3
	)

	for _, blob in ipairs(self.Blobs) do
		if IsValid(blob) then
			blob:SetNWInt(
				"CETS_Quality",
				self.Quality
			)
		end
	end

	return self
end

function C.Controller:SetJelly(enabled)
	self.Jelly = enabled == true

	for _, blob in ipairs(self.Blobs) do
		if IsValid(blob) then
			blob:SetNWBool(
				"CETS_Jelly",
				self.Jelly
			)
		end
	end

	return self
end

function C.Controller:SetJellyCluster(enabled)
	self.JellyCluster = enabled == true

	for _, blob in ipairs(self.Blobs) do
		if IsValid(blob) then
			blob:SetNWBool(
				"CETS_JellyCluster",
				self.JellyCluster
			)
		end
	end

	return self
end

-- ============================================================
-- CONTROLLER FORCE API
-- ============================================================

function C.Controller:ApplyForce(force)
	if not isvector(force) then
		return self
	end

	for _, blob in ipairs(self.Blobs) do
		if IsValid(blob) then
			local phys = blob:GetPhysicsObject()

			if IsValid(phys) then
				phys:ApplyForceCenter(force)
			end
		end
	end

	return self
end

function C.Controller:SetVelocity(velocity)
	if not isvector(velocity) then
		return self
	end

	for _, blob in ipairs(self.Blobs) do
		if IsValid(blob) then
			local phys = blob:GetPhysicsObject()

			if IsValid(phys) then
				phys:SetVelocity(velocity)
			end
		end
	end

	return self
end

function C.Controller:GetNearestBlob(pos)
	if not pos then
		pos = self:GetPos()
	end

	local nearest
	local bestDist = math.huge

	for _, blob in ipairs(self.Blobs) do
		if IsValid(blob) then
			local dist = blob:GetPos():DistToSqr(pos)

			if dist < bestDist then
				bestDist = dist
				nearest = blob
			end
		end
	end

	return nearest
end

-- ============================================================
-- CREATE
-- ============================================================

function C.Create(owner, config)
	if CLIENT then
		return nil
	end

	local controller = copyConfig(config)

	controller.Owner =
		IsValid(owner)
		and owner
		or nil

	controller.Position =
		IsValid(owner)
		and owner:WorldSpaceCenter()
		or Vector(0, 0, 0)

	controller.Blobs = {}
	controller.Flecks = {}

	controller.Removed = false
	controller.Spawned = false

	controller.OnSpawn =
		config and config.OnSpawn

	controller.OnRemove =
		config and config.OnRemove

	controller.OnBlobCreated =
		config and config.OnBlobCreated

	controller.OnBlobRemoved =
		config and config.OnBlobRemoved

	controller.OnBlobDamage =
		config and config.OnBlobDamage

	controller.OnBlobSplit =
		config and config.OnBlobSplit

	controller.OnBlobImpact =
		config and config.OnBlobImpact

	controller.OnSimulate =
		config and config.OnSimulate

	setmetatable(
		controller,
		{
			__index = C.Controller
		}
	)

	-- Registration now ALWAYS exists.
	C.RegisterController(controller)

	if IsValid(owner) then
		owner.CETSBlobs = controller
	end

	return controller
end

-- ============================================================
-- CONTROLLER SPAWN
-- ============================================================

function C.Controller:Spawn(count, radius)
	if self.Removed then
		return self
	end

	if CLIENT then
		return self
	end

	if self.Spawned then
		return self
	end

	self.Spawned = true

	C.SpawnRing(
		self,
		count or self.Count,
		radius or self.Radius
	)

	if self.OnSpawn then
		self.OnSpawn(self)
	end

	return self
end

-- ============================================================
-- CONTROLLER THINK
-- ============================================================

function C.Controller:Think()
	if self.Removed then
		return
	end

	if CLIENT then
		return
	end

	C.Sim(self)

	if self.OnSimulate then
		self.OnSimulate(self)
	end
end

-- ============================================================
-- CONTROLLER IMPACT
-- ============================================================

function C.Controller:Impact(pos, force)
	if self.Removed then
		return
	end

	if C.ClusterBlast then
		C.ClusterBlast(
			self,
			pos or self:GetPos(),
			force or 0
		)
	end
end

function C.Controller:Split(pos, force)
	if self.Removed then
		return
	end

	if C.BulletPinch then
		C.BulletPinch(
			self,
			pos or self:GetPos(),
			force or 0
		)
	end
end

function C.Controller:Damage(blob, damage, pos, force)
	if self.Removed then
		return
	end

	if C.HurtBlob then
		C.HurtBlob(
			blob,
			damage or 0,
			pos,
			force
		)
	end
end

-- ============================================================
-- CONTROLLER CLEAR
-- ============================================================

function C.Controller:Clear()
	if CLIENT then
		return self
	end

	for i = #self.Blobs, 1, -1 do
		local blob = self.Blobs[i]

		if IsValid(blob) then
			blob:Remove()
		end
	end

	self.Blobs = {}

	return self
end

-- ============================================================
-- CONTROLLER REMOVE
-- ============================================================

function C.Controller:Remove()
	if self.Removed then
		return
	end

	self.Removed = true

	if SERVER then
		for i = #self.Blobs, 1, -1 do
			local blob = self.Blobs[i]

			if IsValid(blob) then
				blob.CETSBlobs = nil
				blob:Remove()
			end
		end

		for i = #self.Flecks, 1, -1 do
			local fleck = self.Flecks[i]

			if IsValid(fleck) then
				fleck:Remove()
			end
		end
	end

	self.Blobs = {}
	self.Flecks = {}

	if IsValid(self.Owner) then
		if self.Owner.CETSBlobs == self then
			self.Owner.CETSBlobs = nil
		end
	end

	C.UnregisterController(self)

	if self.OnRemove then
		self.OnRemove(self)
	end
end

-- ============================================================
-- GLOBAL REMOVE API
-- ============================================================

function C.Remove(controller)
	if not controller then
		return
	end

	if controller.Remove then
		controller:Remove()
	end
end

-- ============================================================
-- SERVER-SIDE BLOB CREATION
-- ============================================================

if SERVER then

	function C.MakeBlob(controller, pos)
		if not controller then
			return nil
		end

		if controller.Removed then
			return nil
		end

		if #controller.Blobs >= controller.MaxCount then
			return nil
		end

		local ent = ents.Create(
			"cets_blobs_chunk"
		)

		if not IsValid(ent) then
			return nil
		end

		ent.IsCETSBlob = true
		ent.IsCETSFleck = false

		ent.CETSBlobs = controller

		ent.CETSRadius =
			controller.Radius

		ent.CETSMass =
			controller.Mass

		ent.CETSHp =
			controller.HP

		ent.CETSSpeed =
			controller.Speed

		ent.CETSGravity =
			controller.Gravity ~= false

		ent.CETSColor =
			copyColor(controller.Color)

		-- --------------------------------------------------------
		-- NETWORKED CLIENT CONFIG
		-- --------------------------------------------------------

		ent:SetNWBool(
			"CETS_Blob",
			true
		)

		ent:SetNWBool(
			"CETS_Fleck",
			false
		)

		ent:SetNWFloat(
			"CETS_Radius",
			controller.Radius
		)

		ent:SetNWFloat(
			"CETS_Speed",
			controller.Speed
		)

		ent:SetNWInt(
			"CETS_Quality",
			controller.Quality
		)

		ent:SetNWInt(
			"CETS_R",
			controller.Color.r
		)

		ent:SetNWInt(
			"CETS_G",
			controller.Color.g
		)

		ent:SetNWInt(
			"CETS_B",
			controller.Color.b
		)

		ent:SetNWBool(
			"CETS_Jelly",
			controller.Jelly
		)

		ent:SetNWBool(
			"CETS_JellyCluster",
			controller.JellyCluster
		)

		ent:SetNWBool(
			"CETS_Translucent",
			controller.Translucent
		)

		ent:SetNWBool(
			"CETS_MultiColor",
			controller.MultiColor
		)

		ent:SetNWBool(
			"CETS_Gravity",
			controller.Gravity
		)

		ent:SetPos(
			pos or controller:GetPos()
		)

		ent:Spawn()
		ent:Activate()

		ent:SetHealth(
			controller.HP
		)

		ent:SetMaxHealth(
			controller.HP
		)

		ent.SurfHP =
			controller.HP

		if ent.SetGelR then
			ent:SetGelR(
				controller.Color.r
			)

			ent:SetGelG(
				controller.Color.g
			)

			ent:SetGelB(
				controller.Color.b
			)
		end

		local phys =
			ent:GetPhysicsObject()

		if IsValid(phys) then
			phys:SetMass(
				controller.Mass
			)

			phys:Wake()
		end

		controller.Blobs[
			#controller.Blobs + 1
		] = ent

		C.RegisterBlob(ent)

		if controller.OnBlobCreated then
			controller.OnBlobCreated(
				controller,
				ent
			)
		end

		return ent
	end

end

-- ============================================================
-- BLOB FORMATION
-- ============================================================

if SERVER then

	function C.SpawnRing(controller, count, radius)
		if not controller then
			return
		end

		if controller.Removed then
			return
		end

		count = math.Clamp(
			math.floor(
				count or controller.Count
			),
			1,
			controller.MaxCount
		)

		radius =
			tonumber(radius)
			or controller.Radius

		local origin =
			controller:GetPos()

		local golden =
			2.399963229

		local R =
			controller.Radius

		-- --------------------------------------------------------
		-- GEL FORMATION
		-- --------------------------------------------------------

		if controller.IsGel then
			local restZ =
				R + 0.6

			for i = 1, count do
				local angle =
					golden * (i - 1)

				local radial =
					radius *
					math.sqrt(
						(i - 0.35) / count
					)

				C.MakeBlob(
					controller,
					origin +
					Vector(
						math.cos(angle) * radial,
						math.sin(angle) * radial,
						restZ
					)
				)
			end

			return
		end

		-- --------------------------------------------------------
		-- NORMAL SPHERICAL FORMATION
		-- --------------------------------------------------------

		local rest =
			R * C.REST

		local shell =
			rest *
			0.58 *
			(count ^ (1 / 3))

		if shell < rest * 0.85 then
			shell =
				rest * 0.85
		end

		local points = {}
		local minZ = math.huge

		for i = 1, count do
			local y =
				1 -
				((i - 0.5) / count) *
				2

			local radial =
				math.sqrt(
					math.max(
						0,
						1 - y * y
					)
				)

			local angle =
				golden * i

			local x =
				math.cos(angle) *
				radial *
				shell

			local z =
				y * shell

			local yy =
				math.sin(angle) *
				radial *
				shell

			if count <= 8 then
				x = x +
					math.Rand(
						-R * 0.42,
						R * 0.42
					)

				yy = yy +
					math.Rand(
						-R * 0.42,
						R * 0.42
					)
			end

			points[i] = Vector(
				x,
				yy,
				z
			)

			if z < minZ then
				minZ = z
			end
		end

		local lift =
			R +
			0.8 -
			minZ

		for i = 1, #points do
			C.MakeBlob(
				controller,
				origin +
				points[i] +
				Vector(
					0,
					0,
					lift
				)
			)
		end
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
			if not ent then
				return
			end

			local controller =
				ent.CETSBlobs

			if controller then
				controller.Owner = nil
			end
		end
	)

end

-- ============================================================
-- SERVER CONTROLLER THINK
-- ============================================================

if SERVER then

	hook.Add(
		"Think",
		"CETS_BLOBS_ControllerThink",
		function()
			for controller in pairs(C.Controllers) do
				if not controller
					or controller.Removed
				then
					C.Controllers[controller] = nil
					continue
				end

				if controller.Think then
					controller:Think()
				end
			end
		end
	)

end

-- ============================================================
-- CLIENT INITIALIZATION
-- ============================================================

if CLIENT then

	C.ClientBlobs =
		C.ClientBlobs or {}

	C.ClientFlecks =
		C.ClientFlecks or {}

end

-- ============================================================
-- END OF CORE / API SECTION
-- ============================================================
--
-- NEXT SECTION:
--	server simulation
--	physics
--	damage
--	bullets
--	flecks
--	collision filtering
--	sound suppression
--	client Marching Cubes renderer
--
-- ============================================================

-- ============================================================
-- CETS_BLOBS
-- SERVER SIMULATION
-- ============================================================

if SERVER then

	local sqrt = math.sqrt
	local min = math.min
	local max = math.max
	local abs = math.abs

	local function validBlob(blob)
		return IsValid(blob)
			and C.IsBlob(blob)
			and not blob.CETSRemoving
	end

	-- ==========================================================
	-- PRUNE
	-- ==========================================================

	local function pruneController(controller)
		if not controller then
			return
		end

		for i = #controller.Blobs, 1, -1 do
			local blob = controller.Blobs[i]

			if not validBlob(blob) then
				table.remove(
					controller.Blobs,
					i
				)
			end
		end
	end

	-- ==========================================================
	-- FLOOR / SURFACE TRACE
	-- ==========================================================
	--
	-- Blobs do NOT need to physically collide with the world.
	--
	-- The simulation detects surfaces with traces instead.
	--
	-- This is what allows:
	--
	--	CollideWorld = false
	--
	-- while still allowing blobs to crawl over surfaces.
	--
	-- ==========================================================

	function C.ProbeSurface(blob, controller)
		if not validBlob(blob) then
			return nil
		end

		controller =
			controller
			or blob.CETSBlobs

		if not controller then
			return nil
		end

		local radius =
			tonumber(blob.CETSRadius)
			or controller.Radius
			or C.RADIUS

		local pos =
			blob:GetPos()

		local down =
			math.max(
				radius * 1.35,
				12
			)

		local mins =
			Vector(
				-radius * 0.72,
				-radius * 0.72,
				-radius * 0.28
			)

		local maxs =
			Vector(
				radius * 0.72,
				radius * 0.72,
				radius * 0.28
			)

		local filter = {
			blob
		}

		if IsValid(controller.Owner) then
			filter[#filter + 1] =
				controller.Owner
		end

		local trace =
			util.TraceHull({
				start = pos,
				endpos = pos - Vector(
					0,
					0,
					down
				),

				mins = mins,
				maxs = maxs,

				mask =
					MASK_SOLID_BRUSHONLY,

				filter = filter
			})

		if not trace.Hit then
			return nil
		end

		return trace
	end

	-- ==========================================================
	-- WALL TRACE
	-- ==========================================================

	function C.ProbeWall(blob, direction, distance)
		if not validBlob(blob) then
			return nil
		end

		if not isvector(direction) then
			return nil
		end

		if direction:LengthSqr() <= 0.0001 then
			return nil
		end

		local controller =
			blob.CETSBlobs

		local radius =
			tonumber(blob.CETSRadius)
			or (
				controller
				and controller.Radius
			)
			or C.RADIUS

		distance =
			tonumber(distance)
			or radius * 1.25

		direction =
			direction:GetNormalized()

		local mins =
			Vector(
				-radius * 0.72,
				-radius * 0.72,
				-radius * 0.72
			)

		local maxs =
			Vector(
				radius * 0.72,
				radius * 0.72,
				radius * 0.72
			)

		local filter = {
			blob
		}

		if controller
			and IsValid(controller.Owner)
		then
			filter[#filter + 1] =
				controller.Owner
		end

		local trace =
			util.TraceHull({
				start = blob:GetPos(),
				endpos =
					blob:GetPos()
					+ direction * distance,

				mins = mins,
				maxs = maxs,

				mask =
					MASK_SOLID_BRUSHONLY,

				filter = filter
			})

		if not trace.Hit then
			return nil
		end

		return trace
	end

	-- ==========================================================
	-- FLOOR RESPONSE
	-- ==========================================================

	function C.ApplySurface(blob, trace, controller)
		if not validBlob(blob) then
			return
		end

		if not trace then
			blob.CETSGrounded =
				false

			blob.CETSSurfaceNormal =
				nil

			return
		end

		local normal =
			trace.HitNormal

		if not normal then
			return
		end

		blob.CETSGrounded =
			normal.z > 0.45

		blob.CETSWall =
			abs(normal.z) < 0.45

		blob.CETSSurfaceNormal =
			Vector(
				normal.x,
				normal.y,
				normal.z
			)

		blob.CETSSurfaceEntity =
			trace.Entity

		blob.CETSLastSurface =
			CurTime()

		local pos =
			blob:GetPos()

		local radius =
			tonumber(blob.CETSRadius)
			or controller.Radius
			or C.RADIUS

		local penetration =
			radius -
			(pos.z - trace.HitPos.z)

		if penetration > 0 then
			blob:SetPos(
				pos +
				normal *
				math.min(
					penetration,
					radius * 0.5
				)
			)
		end

		local phys =
			blob:GetPhysicsObject()

		if not IsValid(phys) then
			return
		end

		local velocity =
			phys:GetVelocity()

		local into =
			velocity:Dot(normal)

		if into < 0 then
			velocity =
				velocity -
				normal * into

			phys:SetVelocity(
				velocity
			)
		end
	end

	-- ==========================================================
	-- SURFACE SLIDE
	-- ==========================================================

	function C.SlideAlongSurface(blob, velocity, normal)
		if not isvector(velocity)
			or not isvector(normal)
		then
			return velocity
		end

		local into =
			velocity:Dot(normal)

		if into >= 0 then
			return velocity
		end

		return velocity -
			normal * into
	end

	-- ==========================================================
	-- CENTROID
	-- ==========================================================

	function C.GetCentroid(controller)
		if not controller then
			return nil
		end

		local total =
			Vector(0, 0, 0)

		local count = 0

		for i = #controller.Blobs, 1, -1 do
			local blob =
				controller.Blobs[i]

			if validBlob(blob) then
				total =
					total +
					blob:GetPos()

				count =
					count + 1
			else
				table.remove(
					controller.Blobs,
					i
				)
			end
		end

		if count <= 0 then
			return controller:GetPos()
		end

		return total / count
	end

	-- ==========================================================
	-- BLOB SEPARATION
	-- ==========================================================

	function C.SeparateBlobs(controller)
		if not controller then
			return
		end

		local blobs =
			controller.Blobs

		local radius =
			controller.Radius
			or C.RADIUS

		local desired =
			radius * 1.72

		local desiredSqr =
			desired * desired

		for i = 1, #blobs do
			local a = blobs[i]

			if validBlob(a) then

				for j = i + 1, #blobs do
					local b = blobs[j]

					if validBlob(b) then
						local delta =
							a:GetPos()
							- b:GetPos()

						local distSqr =
							delta:LengthSqr()

						if distSqr > 0.0001
							and distSqr <
								desiredSqr
						then
							local dist =
								sqrt(distSqr)

							local normal =
								delta / dist

							local amount =
								desired -
								dist

							local force =
								normal *
								amount *
								(controller.Spring or 24)

							local pa =
								a:GetPhysicsObject()

							local pb =
								b:GetPhysicsObject()

							if IsValid(pa) then
								pa:ApplyForceCenter(
									force
								)
							end

							if IsValid(pb) then
								pb:ApplyForceCenter(
									-force
								)
							end
						end
					end
				end
			end
		end
	end

	-- ==========================================================
	-- CENTROID ATTRACTION
	-- ==========================================================

	function C.PullTowardCentroid(controller)
		if not controller then
			return
		end

		local centroid =
			C.GetCentroid(
				controller
			)

		if not centroid then
			return
		end

		local radius =
			controller.SwarmRadius
			or C.SWARM_R

		local radiusSqr =
			radius * radius

		local strength =
			controller.Spring
			or C.SPRING

		for _, blob in ipairs(
			controller.Blobs
		) do
			if validBlob(blob) then

				local delta =
					centroid -
					blob:GetPos()

				local distSqr =
					delta:LengthSqr()

				if distSqr >
					radiusSqr
				then
					local dist =
						sqrt(distSqr)

					if dist > 0.001 then
						local amount =
							(dist - radius) /
							radius

						amount =
							math.Clamp(
								amount,
								0,
								2
							)

						local force =
							delta /
							dist *
							strength *
							amount

						local phys =
							blob:GetPhysicsObject()

						if IsValid(phys) then
							phys:ApplyForceCenter(
								force
							)
						end
					end
				end
			end
		end
	end

	-- ==========================================================
	-- LOCAL PEER ATTRACTION
	-- ==========================================================

	function C.AttractPeers(controller)
		if not controller then
			return
		end

		local blobs =
			controller.Blobs

		local close =
			controller.CloseRadius
			or C.SWARM_R_CLOSE

		local closeSqr =
			close * close

		local strength =
			(controller.Spring or C.SPRING)
			* 0.45

		for i = 1, #blobs do
			local a = blobs[i]

			if validBlob(a) then

				for j = i + 1, #blobs do
					local b = blobs[j]

					if validBlob(b) then
						local delta =
							b:GetPos()
							- a:GetPos()

						local distSqr =
							delta:LengthSqr()

						if distSqr >
							0.0001
							and distSqr <
								closeSqr
						then
							local dist =
								sqrt(distSqr)

							local normal =
								delta / dist

							local amount =
								1 -
								(dist / close)

							local force =
								normal *
								strength *
								amount

							local pa =
								a:GetPhysicsObject()

							local pb =
								b:GetPhysicsObject()

							if IsValid(pa) then
								pa:ApplyForceCenter(
									force
								)
							end

							if IsValid(pb) then
								pb:ApplyForceCenter(
									-force
								)
							end
						end
					end
				end
			end
		end
	end

	-- ==========================================================
	-- SURFACE CRAWL
	-- ==========================================================

	function C.SurfaceCrawl(blob, controller)
		if not validBlob(blob) then
			return
		end

		if not controller then
			return
		end

		local phys =
			blob:GetPhysicsObject()

		if not IsValid(phys) then
			return
		end

		local velocity =
			phys:GetVelocity()

		local speed =
			controller.Speed
			or C.SPEED

		local normal =
			blob.CETSSurfaceNormal

		-- ------------------------------------------------------
		-- No surface: normal gravity movement.
		-- ------------------------------------------------------

		if not normal then
			return
		end

		-- ------------------------------------------------------
		-- Remove movement into the surface.
		-- ------------------------------------------------------

		velocity =
			C.SlideAlongSurface(
				blob,
				velocity,
				normal
			)

		-- ------------------------------------------------------
		-- Crawl direction.
		-- ------------------------------------------------------

		local flat =
			Vector(
				velocity.x,
				velocity.y,
				velocity.z
			)

		flat =
			flat -
			normal * flat:Dot(normal)

		if flat:LengthSqr() < 4 then
			local owner =
				controller.Owner

			if IsValid(owner) then
				flat =
					owner:GetForward()

				flat =
					flat -
					normal *
					flat:Dot(normal)
			end
		end

		if flat:LengthSqr() > 0.001 then
			flat =
				flat:GetNormalized()

			local target =
				flat * speed

			local blend =
				math.Clamp(
					FrameTime() * 5,
					0,
					1
				)

			velocity =
				LerpVector(
					blend,
					velocity,
					target
				)
		end

		phys:SetVelocity(
			velocity
		)
	end

	-- ==========================================================
	-- VELOCITY LIMIT
	-- ==========================================================

	function C.LimitVelocity(blob, controller)
		if not validBlob(blob) then
			return
		end

		local phys =
			blob:GetPhysicsObject()

		if not IsValid(phys) then
			return
		end

		local velocity =
			phys:GetVelocity()

		local maxSpeed =
			controller.MaxSpeed
			or C.MAX_SPD

		local speedSqr =
			velocity:LengthSqr()

		if speedSqr <=
			maxSpeed * maxSpeed
		then
			return
		end

		local speed =
			sqrt(speedSqr)

		if speed <= 0 then
			return
		end

		phys:SetVelocity(
			velocity *
			(maxSpeed / speed)
		)
	end

	-- ==========================================================
	-- DAMPING
	-- ==========================================================

	function C.ApplyDamping(blob, controller)
		if not validBlob(blob) then
			return
		end

		local phys =
			blob:GetPhysicsObject()

		if not IsValid(phys) then
			return
		end

		local velocity =
			phys:GetVelocity()

		local factor =
			controller.Jelly
			and 0.94
			or 0.97

		if blob.CETSGrounded then
			factor =
				factor * 0.92
		end

		phys:SetVelocity(
			velocity * factor
		)
	end

	-- ==========================================================
	-- GRAVITY
	-- ==========================================================

	function C.ApplyGravity(blob, controller)
		if not validBlob(blob) then
			return
		end

		if controller.Gravity == false then
			return
		end

		if blob.CETSGrounded then
			return
		end

		local phys =
			blob:GetPhysicsObject()

		if not IsValid(phys) then
			return
		end

		local force =
			controller.GravityForce
			or C.GRAV

		phys:ApplyForceCenter(
			Vector(
				0,
				0,
				-phys:GetMass() *
				force
			)
		)
	end

	-- ==========================================================
	-- SIMULATE SINGLE BLOB
	-- ==========================================================

	function C.SimBlob(blob, controller)
		if not validBlob(blob) then
			return
		end

		local trace =
			C.ProbeSurface(
				blob,
				controller
			)

		C.ApplySurface(
			blob,
			trace,
			controller
		)

		C.ApplyGravity(
			blob,
			controller
		)

		C.SurfaceCrawl(
			blob,
			controller
		)

		C.ApplyDamping(
			blob,
			controller
		)

		C.LimitVelocity(
			blob,
			controller
		)
	end

	-- ==========================================================
	-- SIMULATE CONTROLLER
	-- ==========================================================

	function C.Sim(controller)
		if not controller then
			return
		end

		if controller.Removed then
			return
		end

		pruneController(
			controller
		)

		if #controller.Blobs <= 0 then
			return
		end

		-- ------------------------------------------------------
		-- Individual surface detection.
		-- ------------------------------------------------------

		for _, blob in ipairs(
			controller.Blobs
		) do
			if validBlob(blob) then
				C.SimBlob(
					blob,
					controller
				)
			end
		end

		-- ------------------------------------------------------
		-- Swarm forces.
		-- ------------------------------------------------------

		C.SeparateBlobs(
			controller
		)

		C.AttractPeers(
			controller
		)

		C.PullTowardCentroid(
			controller
		)

		-- ------------------------------------------------------
		-- User callback.
		-- ------------------------------------------------------

		if controller.OnSimulate then
			controller.OnSimulate(
				controller
			)
		end
	end

end

-- ============================================================
-- END SERVER SIMULATION
-- ============================================================

-- ============================================================
-- CETS_BLOBS
-- DAMAGE / BULLETS / SPLITTING / FLECKS / COLLISION / SOUND
-- ============================================================

if SERVER then

	-- ==========================================================
	-- HELPERS
	-- ==========================================================

	local function validBlob(blob)
		return IsValid(blob)
			and C.IsBlob(blob)
			and not blob.CETSRemoving
	end

	local function getController(blob)
		if not validBlob(blob) then
			return nil
		end

		local controller =
			blob.CETSBlobs

		if not controller
			or controller.Removed
		then
			return nil
		end

		return controller
	end

	local function getPhys(blob)
		if not validBlob(blob) then
			return nil
		end

		local phys =
			blob:GetPhysicsObject()

		if not IsValid(phys) then
			return nil
		end

		return phys
	end

	local function randomDirection()
		local v = Vector(
			math.Rand(-1, 1),
			math.Rand(-1, 1),
			math.Rand(-1, 1)
		)

		if v:LengthSqr() < 0.001 then
			v = Vector(0, 0, 1)
		end

		return v:GetNormalized()
	end

	-- ==========================================================
	-- BLOB KNOCKBACK
	-- ==========================================================

	function C.KnockBlob(blob, force, direction)
		local phys =
			getPhys(blob)

		if not phys then
			return
		end

		force =
			tonumber(force)
			or 0

		if force == 0 then
			return
		end

		if not isvector(direction)
			or direction:LengthSqr() < 0.001
		then
			direction =
				randomDirection()
		else
			direction =
				direction:GetNormalized()
		end

		phys:ApplyForceCenter(
			direction * force
		)
	end

	-- ==========================================================
	-- BLOB IMPACT
	-- ==========================================================

	function C.ImpactBlob(blob, pos, normal, speed)
		local controller =
			getController(blob)

		if not controller then
			return
		end

		speed =
			tonumber(speed)
			or 0

		pos =
			pos
			or blob:GetPos()

		normal =
			normal
			or Vector(0, 0, 1)

		blob.CETSLastImpact =
			CurTime()

		blob.CETSImpactSpeed =
			speed

		blob.CETSImpactNormal =
			normal

		if controller.OnBlobImpact then
			controller.OnBlobImpact(
				controller,
				blob,
				pos,
				normal,
				speed
			)
		end

		if controller.ImpactSounds
			and speed >= 110
		then
			C.WaterHit(
				pos,
				speed,
				blob,
				normal.z > 0.45
			)
		end
	end

	-- ==========================================================
	-- WATER / SPLASH EFFECT
	-- ==========================================================

	C._LastSplashTime =
		C._LastSplashTime or 0

	C._SplashCount =
		C._SplashCount or 0

	function C.WaterHit(pos, speed, ent, floorHit)
		if not pos then
			return
		end

		speed =
			tonumber(speed)
			or 80

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

		if IsValid(ent) then
			if (ent.CETSSplashTime or 0) > now then
				return
			end

			ent.CETSSplashTime =
				now + 0.9

			local controller =
				ent.CETSBlobs

			if controller then
				if (controller.CETSSplashTime or 0) > now then
					return
				end

				controller.CETSSplashTime =
					now +
					(
						floorHit
						and 1.1
						or 0.75
					)
			end
		elseif now -
			C._LastSplashTime < 0.18
		then
			C._SplashCount =
				C._SplashCount + 1

			if C._SplashCount > 1 then
				return
			end
		else
			C._LastSplashTime =
				now

			C._SplashCount =
				0
		end

		local volume =
			speed / 1100

		volume =
			math.Clamp(
				volume,
				0.12,
				0.38
			)

		local pitch =
			math.random(
				86,
				114
			)

		if speed > 220 then
			sound.Play(
				"ambient/water/water_splash"
				.. math.random(1, 3)
				.. ".wav",

				pos,
				68,
				pitch,
				volume
			)
		else
			sound.Play(
				"player/footsteps/slosh"
				.. math.random(1, 4)
				.. ".wav",

				pos,
				60,
				pitch,
				volume
			)
		end
	end

	-- ==========================================================
	-- FLECK CREATION
	-- ==========================================================

	function C.SpawnFlecks(
		pos,
		count,
		color,
		direction,
		controller
	)
		if not pos then
			return
		end

		count =
			math.max(
				0,
				math.floor(
					tonumber(count)
					or 0
				)
			)

		if count <= 0 then
			return
		end

		if controller then
			local maxFlecks =
				controller.MaxFlecks
				or C.MAX_FLECKS

			if #controller.Flecks >= maxFlecks then
				return
			end

			count =
				math.min(
					count,
					maxFlecks -
					#controller.Flecks
				)
		end

		if count <= 0 then
			return
		end

		color =
			color
			or (
				controller
				and controller.Color
			)
			or Color(
				C.COL_R,
				C.COL_G,
				C.COL_B
			)

		if not isvector(direction)
			or direction:LengthSqr() < 0.001
		then
			direction =
				Vector(0, 0, 1)
		else
			direction =
				direction:GetNormalized()
		end

		for i = 1, count do

			local ent =
				ents.Create(
					"cets_blobs_chunk"
				)

			if not IsValid(ent) then
				continue
			end

			ent.IsCETSBlob =
				false

			ent.IsCETSFleck =
				true

			ent.CETSBlobs =
				controller

			ent.CETSColor =
				Color(
					color.r,
					color.g,
					color.b,
					color.a or 255
				)

			local size =
				math.Rand(
					2.2,
					5.2
				)

			local spread =
				randomDirection()

			local launch =
				(
					direction * math.Rand(
						70,
						150
					)
				)
				+
				(
					spread * math.Rand(
						20,
						75
					)
				)

			launch.z =
				launch.z +
				math.Rand(
					20,
					90
				)

			ent.CETSFleck =
				true

			ent.CETSRadius =
				size

			ent.CETSSize =
				size

			ent.CETSLaunchVelocity =
				launch

			ent.CETSDrag =
				math.Rand(
					0.82,
					0.96
				)

			ent.CETSDamp =
				math.Rand(
					0.90,
					0.98
				)

			ent:SetNWBool(
				"CETS_Blob",
				false
			)

			ent:SetNWBool(
				"CETS_Fleck",
				true
			)

			ent:SetNWFloat(
				"CETS_Radius",
				size
			)

			ent:SetNWFloat(
				"CETS_Size",
				size
			)

			ent:SetNWInt(
				"CETS_R",
				color.r
			)

			ent:SetNWInt(
				"CETS_G",
				color.g
			)

			ent:SetNWInt(
				"CETS_B",
				color.b
			)

			ent:SetNWInt(
				"CETS_Seed",
				math.random(
					0,
					2147483647
				)
			)

			ent:SetPos(
				pos +
				randomDirection() *
				math.Rand(
					0,
					4
				)
			)

			ent:Spawn()
			ent:Activate()

			local phys =
				ent:GetPhysicsObject()

			if IsValid(phys) then
				phys:SetMass(
					math.Rand(
						0.1,
						0.45
					)
				)

				phys:EnableGravity(
					true
				)

				phys:SetDamping(
					0.05,
					0.1
				)

				phys:SetVelocity(
					launch
				)

				phys:Wake()
			end

			C.RegisterFleck(
				ent
			)

			if controller then
				controller.Flecks[
					#controller.Flecks + 1
				] = ent
			end
		end
	end

	-- ==========================================================
	-- DAMAGE
	-- ==========================================================

	function C.HurtBlob(
		blob,
		damage,
		pos,
		force,
		attacker,
		inflictor
	)
		local controller =
			getController(blob)

		if not controller then
			return false
		end

		damage =
			math.max(
				0,
				tonumber(damage)
				or 0
			)

		if damage <= 0 then
			return false
		end

		local now =
			CurTime()

		if (blob.CETSDamageTime or 0) > now then
			return false
		end

		blob.CETSDamageTime =
			now +
			(
				controller.DamageCooldown
				or C.DMG_CD
			)

		local hp =
			blob:Health()

		if hp <= 0 then
			hp =
				blob.CETSHp
				or controller.HP
				or C.CHUNK_HP
		end

		hp =
			hp - damage

		blob:SetHealth(
			math.max(
				0,
				hp
			)
		)

		if controller.OnBlobDamage then
			controller.OnBlobDamage(
				controller,
				blob,
				damage,
				hp,
				attacker,
				inflictor
			)
		end

		if isvector(force)
			and force:LengthSqr() > 0
		then
			C.KnockBlob(
				blob,
				force:Length(),
				force
			)
		elseif pos then
			local dir =
				blob:GetPos() -
				pos

			if dir:LengthSqr() > 0.001 then
				C.KnockBlob(
					blob,
					damage * 20,
					dir
				)
			end
		end

		if hp <= 0 then
			C.SplitBlob(
				controller,
				blob,
				pos,
				force
			)

			return true
		end

		return false
	end

	-- ==========================================================
	-- GENERIC DAMAGE HOOK
	-- ==========================================================

	hook.Add(
		"EntityTakeDamage",
		"CETS_BLOBS_Damage",
		function(target, dmg)
			if not validBlob(target) then
				return
			end

			local damage =
				dmg:GetDamage()

			local position =
				dmg:GetDamagePosition()

			local force =
				dmg:GetDamageForce()

			local attacker =
				dmg:GetAttacker()

			local inflictor =
				dmg:GetInflictor()

			C.HurtBlob(
				target,
				damage,
				position,
				force,
				attacker,
				inflictor
			)

			return true
		end
	)

	-- ==========================================================
	-- BULLET TRACE
	-- ==========================================================

	function C.RayHitBlob(
		startPos,
		endPos,
		radius
	)
		if not startPos
			or not endPos
		then
			return nil
		end

		radius =
			tonumber(radius)
			or C.RADIUS

		local result

		local tr =
			util.TraceLine({
				start = startPos,
				endpos = endPos,
				mask = MASK_SHOT
			})

		for blob in pairs(C.Blobs) do
			if validBlob(blob) then
				local center =
					blob:WorldSpaceCenter()

				local nearest =
					util.IntersectRayWithOBB(
						startPos,
						(endPos - startPos),
						blob:OBBMins(),
						blob:OBBMaxs(),
						blob:GetPos(),
						blob:GetAngles()
					)

				if nearest then
					result =
						blob

					break
				end

				local line =
					endPos -
					startPos

				local lengthSqr =
					line:LengthSqr()

				if lengthSqr > 0.001 then
					local t =
						math.Clamp(
							(center - startPos):Dot(line)
							/ lengthSqr,
							0,
							1
						)

					local closest =
						startPos +
						line * t

					if closest:DistToSqr(
						center
					) <=
						radius * radius
					then
						result =
							blob

						break
					end
				end
			end
		end

		return result, tr
	end

	-- ==========================================================
	-- BULLET PINCH
	-- ==========================================================

	function C.BulletPinch(
		controller,
		pos,
		force,
		direction
	)
		if not controller then
			return
		end

		if not pos then
			return
		end

		force =
			tonumber(force)
			or 0

		if not isvector(direction)
			or direction:LengthSqr() < 0.001
		then
			direction =
				randomDirection()
		else
			direction =
				direction:GetNormalized()
		end

		local radius =
			controller.Radius
			or C.RADIUS

		local radiusSqr =
			(
				radius * 3
			) ^ 2

		for _, blob in ipairs(
			controller.Blobs
		) do
			if validBlob(blob) then

				local delta =
					blob:GetPos() -
					pos

				local distSqr =
					delta:LengthSqr()

				if distSqr <=
					radiusSqr
				then
					local dist =
						math.sqrt(
							math.max(
								distSqr,
								0.001
							)
						)

					local falloff =
						1 -
						math.Clamp(
							dist /
							(radius * 3),
							0,
							1
						)

					C.KnockBlob(
						blob,
						force * falloff,
						direction
					)
				end
			end
		end
	end

	-- ==========================================================
	-- SPLIT BLOB
	-- ==========================================================

	function C.SplitBlob(
		controller,
		blob,
		pos,
		force
	)
		if not controller
			or not validBlob(blob)
		then
			return
		end

		if blob.CETSSplitting then
			return
		end

		blob.CETSSplitting = true

		pos =
			pos
			or blob:GetPos()

		local radius =
			controller.Radius
			or C.RADIUS

		local color =
			C.GetColor(
				controller
			)

		local phys =
			blob:GetPhysicsObject()

		local oldVelocity =
			IsValid(phys)
			and phys:GetVelocity()
			or Vector(0, 0, 0)

		local splitCount =
			math.Clamp(
				math.floor(
					controller.SplitCount
					or 2
				),
				2,
				6
			)

		-- Remove the damaged chunk.
		blob:Remove()

		local created = {}

		for i = 1, splitCount do
			if #controller.Blobs >=
				controller.MaxCount
			then
				break
			end

			local dir =
				randomDirection()

			dir.z =
				math.abs(dir.z) *
				0.55 +
				0.15

			local offset =
				dir *
				radius *
				0.65

			local child =
				C.MakeBlob(
					controller,
					pos + offset
				)

			if IsValid(child) then
				local childPhys =
					child:GetPhysicsObject()

				if IsValid(childPhys) then
					childPhys:SetVelocity(
						oldVelocity +
						dir *
						math.Rand(
							35,
							90
						)
					)
				end

				created[
					#created + 1
				] = child
			end
		end

		if controller.OnBlobSplit then
			controller.OnBlobSplit(
				controller,
				blob,
				created,
				pos,
				force
			)
		end

		if controller.EnableFlecks then
			C.SpawnFlecks(
				pos,
				math.min(
					6,
					controller.MaxFlecks
				),
				color,
				oldVelocity,
				controller
			)
		end
	end

	-- ==========================================================
	-- MERGING
	-- ==========================================================

	function C.MergeBlobs(controller)
		if not controller
			or controller.Merge == false
		then
			return
		end

		local blobs =
			controller.Blobs

		local radius =
			controller.Radius
			or C.RADIUS

		local mergeDistance =
			radius *
			0.82

		local mergeDistanceSqr =
			mergeDistance *
			mergeDistance

		for i = 1, #blobs do
			local a = blobs[i]

			if validBlob(a) then

				for j = i + 1, #blobs do
					local b = blobs[j]

					if validBlob(b) then

						local delta =
							a:GetPos() -
							b:GetPos()

						if delta:LengthSqr()
							<= mergeDistanceSqr
						then
							local pa =
								a:GetPhysicsObject()

							local pb =
								b:GetPhysicsObject()

							if IsValid(pa)
								and IsValid(pb)
							then
								local va =
									pa:GetVelocity()

								local vb =
									pb:GetVelocity()

								local velocity =
									(
										va +
										vb
									) * 0.5

								pa:SetVelocity(
									velocity
								)

								pb:SetVelocity(
									velocity
								)
							end

							-- Do not physically delete both.
							-- Instead softly separate them.
							local normal =
								delta

							if normal:LengthSqr()
								> 0.001
							then
								normal =
									normal:GetNormalized()

								C.KnockBlob(
									a,
									4,
									normal
								)

								C.KnockBlob(
									b,
									4,
									-normal
								)
							end
						end
					end
				end
			end
		end
	end

	-- ==========================================================
	-- CLUSTER BLAST
	-- ==========================================================

	function C.ClusterBlast(
		controller,
		pos,
		force,
		radius
	)
		if not controller then
			return
		end

		pos =
			pos
			or controller:GetPos()

		force =
			tonumber(force)
			or 0

		radius =
			tonumber(radius)
			or (
				controller.Radius *
				5
			)

		if force == 0 then
			return
		end

		local radiusSqr =
			radius * radius

		for _, blob in ipairs(
			controller.Blobs
		) do
			if validBlob(blob) then

				local delta =
					blob:GetPos() -
					pos

				local distSqr =
					delta:LengthSqr()

				if distSqr <=
					radiusSqr
				then
					local dist =
						math.sqrt(
							math.max(
								distSqr,
								0.001
							)
						)

					local falloff =
						1 -
						math.Clamp(
							dist /
							radius,
							0,
							1
						)

					C.KnockBlob(
						blob,
						force *
						falloff,
						delta
					)
				end
			end
		end
	end

	-- ==========================================================
	-- BULLET HOOK
	-- ==========================================================

	hook.Add(
		"EntityFireBullets",
		"CETS_BLOBS_Bullet",
		function(attacker, bullet)
			if not bullet then
				return
			end

			local src =
				bullet.Src

			local direction =
				bullet.Dir

			if not src
				or not direction
			then
				return
			end

			local distance =
				bullet.Distance
				or 56756

			local finish =
				src +
				direction *
				distance

			local blob, trace =
				C.RayHitBlob(
					src,
					finish,
					C.RADIUS * 1.1
				)

			if not validBlob(blob) then
				return
			end

			local controller =
				blob.CETSBlobs

			if controller then
				C.BulletPinch(
					controller,
					blob:GetPos(),
					(bullet.Damage or 10) * 3,
					direction
				)
			end

			-- Let the bullet continue normally.
		end
	)

	-- ==========================================================
	-- FLECK CLEANUP
	-- ==========================================================

	hook.Add(
		"Think",
		"CETS_BLOBS_FleckCleanup",
		function()
			for fleck in pairs(C.Flecks) do
				if not IsValid(fleck) then
					C.Flecks[fleck] = nil
				end
			end
		end
	)

end

-- ============================================================
-- COLLISION POLICY
-- ============================================================
--
-- Default:
--
--	Blob <-> Blob		OFF
--	Blob <-> World		OFF
--	Blob <-> Prop		OFF
--	Blob <-> Player		OFF
--	Blob <-> NPC		OFF
--
-- Surface detection is performed with traces.
--
-- Users can selectively enable collision through the controller.
--
-- ============================================================

hook.Add(
	"ShouldCollide",
	"CETS_BLOBS_Collision",
	function(a, b)
		local aBlob =
			C.IsBlob(a)

		local bBlob =
			C.IsBlob(b)

		local aFleck =
			C.IsFleck(a)

		local bFleck =
			C.IsFleck(b)

		if not (
			aBlob
			or bBlob
			or aFleck
			or bFleck
		) then
			return
		end

		-- Flecks never collide with blob chunks.
		if (
			aFleck
			and bBlob
		)
		or (
			aBlob
			and bFleck
		)
		then
			return false
		end

		-- Flecks never collide with each other.
		if aFleck and bFleck then
			return false
		end

		-- Blob versus blob.
		if aBlob and bBlob then
			local controller =
				a.CETSBlobs
				or b.CETSBlobs

			if controller
				and controller.CollideBlobs
			then
				return
			end

			return false
		end

		local blob =
			aBlob
			and a
			or b

		local other =
			aBlob
			and b
			or a

		local controller =
			IsValid(blob)
			and blob.CETSBlobs

		if not controller then
			return false
		end

		-- World.
		if other == game.GetWorld() then
			return controller.CollideWorld
		end

		-- Players.
		if IsValid(other)
			and other:IsPlayer()
		then
			return controller.CollidePlayers
		end

		-- NPCs / NextBots.
		if IsValid(other)
			and (
				other:IsNPC()
				or other:IsNextBot()
			)
		then
			return controller.CollideNPCs
		end

		-- Props / physics entities.
		if IsValid(other)
			and (
				other:GetMoveType()
				== MOVETYPE_VPHYSICS
			)
		then
			return controller.CollideProps
		end

		return false
	end
)

-- ============================================================
-- SOUND SUPPRESSION
-- ============================================================

hook.Add(
	"EntityEmitSound",
	"CETS_BLOBS_SoundSuppression",
	function(data)
		local ent =
			data.Entity

		if C.IsBlob(ent)
			or C.IsFleck(ent)
		then
			return false
		end

		local origin =
			data.Origin

		if not origin
			and IsValid(ent)
		then
			origin =
				ent:GetPos()
		end

		if not origin then
			return
		end

		local radius =
			C.RADIUS * 2.5

		local name =
			string.lower(
				tostring(
					data.SoundName
					or ""
				)
			)

		-- --------------------------------------------------------
		-- Only inspect sounds which could plausibly be physics /
		-- impact sounds.
		-- --------------------------------------------------------

		local impactSound =
			string.find(
				name,
				"impact",
				1,
				true
			)
			or string.find(
				name,
				"physics",
				1,
				true
			)
			or string.find(
				name,
				"bullet",
				1,
				true
			)
			or string.find(
				name,
				"ricochet",
				1,
				true
			)
			or string.find(
				name,
				"dirt",
				1,
				true
			)
			or string.find(
				name,
				"sand",
				1,
				true
			)
			or string.find(
				name,
				"concrete",
				1,
				true
			)
			or string.find(
				name,
				"grass",
				1,
				true
			)
			or string.find(
				name,
				"tile",
				1,
				true
			)
			or string.find(
				name,
				"ceramic",
				1,
				true
			)

		if not impactSound then
			return
		end

		for blob in pairs(C.Blobs) do
			if IsValid(blob) then
				if blob:GetPos():DistToSqr(
					origin
				) <=
					radius * radius
				then
					local controller =
						blob.CETSBlobs

					if not controller
						or not controller.ImpactSounds
					then
						return false
					end
				end
			end
		end
	end
)

-- ============================================================
-- END STEP 3
-- ============================================================

-- ============================================================
-- CETS_BLOBS
-- CLIENT METABALL / MARCHING CUBES RENDERER
-- ============================================================

if CLIENT then

	-- ==========================================================
	-- LOCAL REFERENCES
	-- ==========================================================

	local floor = math.floor
	local ceil = math.ceil
	local min = math.min
	local max = math.max
	local sqrt = math.sqrt
	local abs = math.abs
	local clamp = math.Clamp

	-- ==========================================================
	-- CLIENT STATE
	-- ==========================================================

	C.ClientBlobs =
		C.ClientBlobs or {}

	C.ClientFlecks =
		C.ClientFlecks or {}

	C._MeshGroups =
		C._MeshGroups or {}

	C._MeshGeneration =
		C._MeshGeneration or 0

	C._LastBuild =
		C._LastBuild or 0

	C._BuildInterval =
		C._BuildInterval or 0.016

	C._MaterialOpaque = nil
	C._MaterialTranslucent = nil

	-- ==========================================================
	-- MATERIALS
	-- ==========================================================

	local function getMaterials()
		if C._MaterialOpaque
			and C._MaterialTranslucent
		then
			return
				C._MaterialOpaque,
				C._MaterialTranslucent
		end

		-- Prefer the original material when it exists.
		local original =
			Material(
				"npc_surface/gel"
			)

		local originalOpaque =
			Material(
				"npc_surface/gel_opaque"
			)

		if not original:IsError() then
			C._MaterialTranslucent =
				original
		else
			C._MaterialTranslucent =
				CreateMaterial(
					"cets_blobs_gel_translucent",
					"VertexLitGeneric",
					{
						["$basetexture"] =
							"models/debug/debugwhite",

						["$model"] = "1",
						["$vertexcolor"] = "1",
						["$vertexalpha"] = "1",

						["$translucent"] = "1",
						["$alphatest"] = "0",

						["$nocull"] = "1",

						["$phong"] = "1",
						["$phongboost"] = "0.15"
					}
				)
		end

		if not originalOpaque:IsError() then
			C._MaterialOpaque =
				originalOpaque
		else
			C._MaterialOpaque =
				CreateMaterial(
					"cets_blobs_gel_opaque",
					"VertexLitGeneric",
					{
						["$basetexture"] =
							"models/debug/debugwhite",

						["$model"] = "1",
						["$vertexcolor"] = "1",

						["$translucent"] = "0",
						["$alphatest"] = "0",

						["$nocull"] = "1",

						["$phong"] = "1",
						["$phongboost"] = "0.15"
					}
				)
		end

		return
			C._MaterialOpaque,
			C._MaterialTranslucent
	end

	-- ==========================================================
	-- SOURCE DATA
	-- ==========================================================

	local function getBlobRadius(blob)
		local radius =
			blob:GetNWFloat(
				"CETS_Radius",
				0
			)

		if radius <= 0 then
			radius = C.RADIUS
		end

		return radius
	end

	local function getBlobColor(blob)
		local r =
			blob:GetNWInt(
				"CETS_R",
				C.COL_R
			)

		local g =
			blob:GetNWInt(
				"CETS_G",
				C.COL_G
			)

		local b =
			blob:GetNWInt(
				"CETS_B",
				C.COL_B
			)

		return
			r,
			g,
			b
	end

	local function getBlobSeed(blob)
		return blob:GetNWInt(
			"CETS_Seed",
			0
		)
	end

	local function getBlobJelly(blob)
		return blob:GetNWBool(
			"CETS_Jelly",
			true
		)
	end

	local function getBlobCluster(blob)
		return blob:GetNWBool(
			"CETS_JellyCluster",
			false
		)
	end

	local function getBlobTranslucent(blob)
		return blob:GetNWBool(
			"CETS_Translucent",
			false
		)
	end

	local function getBlobMultiColor(blob)
		return blob:GetNWBool(
			"CETS_MultiColor",
			false
		)
	end

	-- ==========================================================
	-- CLEAN CLIENT SOURCE LISTS
	-- ==========================================================

	local function pruneClientLists()
		for i = #C.ClientBlobs, 1, -1 do
			local blob =
				C.ClientBlobs[i]

			if not IsValid(blob)
				or not C.IsBlob(blob)
			then
				C.ClientBlobs[i] =
					C.ClientBlobs[
						#C.ClientBlobs
					]

				C.ClientBlobs[
					#C.ClientBlobs
				] = nil
			end
		end

		for i = #C.ClientFlecks, 1, -1 do
			local fleck =
				C.ClientFlecks[i]

			if not IsValid(fleck)
				or not C.IsFleck(fleck)
			then
				C.ClientFlecks[i] =
					C.ClientFlecks[
						#C.ClientFlecks
					]

				C.ClientFlecks[
					#C.ClientFlecks
				] = nil
			end
		end
	end

	-- ==========================================================
	-- SOURCE COLLECTION
	-- ==========================================================

	local function collectSources()
		pruneClientLists()

		local sources = {}

		for i = 1, #C.ClientBlobs do
			local blob =
				C.ClientBlobs[i]

			if IsValid(blob) then
				sources[
					#sources + 1
				] = {
					ent = blob,
					pos = blob:GetPos(),
					radius =
						getBlobRadius(blob),
					weight = 1,
					seed =
						getBlobSeed(blob),
					jelly =
						getBlobJelly(blob),
					cluster =
						getBlobCluster(blob),
					translucent =
						getBlobTranslucent(blob),
					multiColor =
						getBlobMultiColor(blob)
				}
			end
		end

		for i = 1, #C.ClientFlecks do
			local fleck =
				C.ClientFlecks[i]

			if IsValid(fleck) then
				local radius =
					fleck:GetNWFloat(
						"CETS_Size",
						fleck:GetNWFloat(
							"CETS_Radius",
							3
						)
					)

				sources[
					#sources + 1
				] = {
					ent = fleck,
					pos = fleck:GetPos(),
					radius =
						math.max(
							0.5,
							radius
						),
					weight = 0.42,
					seed =
						fleck:GetNWInt(
							"CETS_Seed",
							0
						),
					jelly = false,
					cluster = false,
					translucent = false,
					multiColor = true
				}
			end
		end

		return sources
	end

	-- ==========================================================
	-- UNION / CLUSTERING
	-- ==========================================================

	local function makeParents(count)
		local parents = {}

		for i = 1, count do
			parents[i] = i
		end

		return parents
	end

	local function findParent(parents, n)
		while parents[n] ~= n do
			parents[n] =
				parents[parents[n]]

			n =
				parents[n]
		end

		return n
	end

	local function unionParent(
		parents,
		a,
		b
	)
		a =
			findParent(
				parents,
				a
			)

		b =
			findParent(
				parents,
				b
			)

		if a ~= b then
			parents[b] = a
		end
	end

	local function buildClusters(sources)
		local count =
			#sources

		if count <= 1 then
			local clusters = {}

			for i = 1, count do
				clusters[i] = {
					sources[i]
				}
			end

			return clusters
		end

		local parents =
			makeParents(count)

		for i = 1, count do
			local a =
				sources[i]

			for j = i + 1, count do
				local b =
					sources[j]

				local delta =
					a.pos -
					b.pos

				local distance =
					delta:Length()

				local join =
					(
						a.radius +
						b.radius
					) * 1.35

				if a.cluster
					or b.cluster
				then
					join =
						join * 1.45
				end

				if distance <= join then
					unionParent(
						parents,
						i,
						j
					)
				end
			end
		end

		local groups = {}
		local indexes = {}

		for i = 1, count do
			local root =
				findParent(
					parents,
					i
				)

			local group =
				indexes[root]

			if not group then
				group = {}

				indexes[root] =
					group

				groups[
					#groups + 1
				] = group
			end

			group[
				#group + 1
			] =
				sources[i]
		end

		return groups
	end

	-- ==========================================================
	-- GROUP BOUNDS
	-- ==========================================================

	local function getBounds(group)
		local minv =
			Vector(
				math.huge,
				math.huge,
				math.huge
			)

		local maxv =
			Vector(
				-math.huge,
				-math.huge,
				-math.huge
			)

		for i = 1, #group do
			local source =
				group[i]

			local p =
				source.pos

			local r =
				source.radius * 2.25

			minv.x =
				min(
					minv.x,
					p.x - r
				)

			minv.y =
				min(
					minv.y,
					p.y - r
				)

			minv.z =
				min(
					minv.z,
					p.z - r
				)

			maxv.x =
				max(
					maxv.x,
					p.x + r
				)

			maxv.y =
				max(
					maxv.y,
					p.y + r
				)

			maxv.z =
				max(
					maxv.z,
					p.z + r
				)
		end

		return minv, maxv
	end

	-- ==========================================================
	-- FIELD
	-- ==========================================================

	local function fieldValue(
		group,
		position,
		inf
	)
		local value = 0

		for i = 1, #group do
			local source =
				group[i]

			local delta =
				position -
				source.pos

			local distanceSqr =
				delta:LengthSqr()

			local radius =
				source.radius

			local radiusSqr =
				radius * radius

			-- Avoid a singularity.
			if distanceSqr <
				radiusSqr * 0.04
			then
				value =
					value + 1.35 *
					source.weight
			else
				local normalized =
					distanceSqr /
					radiusSqr

				value =
					value +
					source.weight /
					(
						1 +
						normalized *
						inf
					)
			end

			if value > 1.5 then
				break
			end
		end

		return value
	end

	-- ==========================================================
	-- NORMAL
	-- ==========================================================

	local function fieldNormal(
		group,
		position,
		cell,
		inf
	)
		local e =
			math.max(
				cell * 0.28,
				0.35
			)

		local x1 =
			fieldValue(
				group,
				position +
					Vector(e, 0, 0),
				inf
			)

		local x2 =
			fieldValue(
				group,
				position -
					Vector(e, 0, 0),
				inf
			)

		local y1 =
			fieldValue(
				group,
				position +
					Vector(0, e, 0),
				inf
			)

		local y2 =
			fieldValue(
				group,
				position -
					Vector(0, e, 0),
				inf
			)

		local z1 =
			fieldValue(
				group,
				position +
					Vector(0, 0, e),
				inf
			)

		local z2 =
			fieldValue(
				group,
				position -
					Vector(0, 0, e),
				inf
			)

		local normal =
			Vector(
				x2 - x1,
				y2 - y1,
				z2 - z1
			)

		if normal:LengthSqr()
			< 0.0001
		then
			return Vector(0, 0, 1)
		end

		return normal:GetNormalized()
	end

	-- ==========================================================
	-- EDGE INTERPOLATION
	-- ==========================================================

	local function interpolate(
		p1,
		p2,
		v1,
		v2,
		iso
	)
		local denominator =
			v2 - v1

		if abs(denominator)
			< 0.00001
		then
			return (p1 + p2) * 0.5
		end

		local t =
			(iso - v1) /
			denominator

		t =
			clamp(
				t,
				0,
				1
			)

		return LerpVector(
			t,
			p1,
			p2
		)
	end

	-- ==========================================================
	-- CUBE CORNERS
	-- ==========================================================

	local cornerOffsets = {
		Vector(0, 0, 0),
		Vector(1, 0, 0),
		Vector(1, 1, 0),
		Vector(0, 1, 0),

		Vector(0, 0, 1),
		Vector(1, 0, 1),
		Vector(1, 1, 1),
		Vector(0, 1, 1)
	}

	local edgeCorners = {
		{1, 2},
		{2, 3},
		{3, 4},
		{4, 1},

		{5, 6},
		{6, 7},
		{7, 8},
		{8, 5},

		{1, 5},
		{2, 6},
		{3, 7},
		{4, 8}
	}

-- ============================================================
-- MARCHING CUBES
-- ============================================================

C.EDGE = C.EDGE or {
	0x000, 0x109, 0x203, 0x30a,
	0x406, 0x50f, 0x605, 0x70c,
	0x80c, 0x905, 0xa0f, 0xb06,
	0xc0a, 0xd03, 0xe09, 0xf00,

	0x190, 0x099, 0x393, 0x29a,
	0x596, 0x49f, 0x795, 0x69c,
	0x99c, 0x895, 0xb9f, 0xa96,
	0xd9a, 0xc93, 0xf99, 0xe90,

	0x230, 0x339, 0x033, 0x13a,
	0x636, 0x73f, 0x435, 0x53c,
	0xa3c, 0xb35, 0x83f, 0x936,
	0xe3a, 0xf33, 0xc39, 0xd30,

	0x3a0, 0x2a9, 0x1a3, 0x0aa,
	0x7a6, 0x6af, 0x5a5, 0x4ac,
	0xbac, 0xaa5, 0x9af, 0x8a6,
	0xfaa, 0xea3, 0xda9, 0xca0,

	0x460, 0x569, 0x663, 0x76a,
	0x066, 0x16f, 0x265, 0x36c,
	0xc6c, 0xd65, 0xe6f, 0xf66,
	0x86a, 0x963, 0xa69, 0xb60,

	0x5f0, 0x4f9, 0x7f3, 0x6fa,
	0x1f6, 0x0ff, 0x3f5, 0x2fc,
	0xdfc, 0xcf5, 0xfff, 0xef6,
	0x9fa, 0x8f3, 0xbf9, 0xaf0,

	0x650, 0x759, 0x453, 0x55a,
	0x256, 0x35f, 0x055, 0x15c,
	0xe5c, 0xf55, 0xc5f, 0xd56,
	0xa5a, 0xb53, 0x859, 0x950,

	0x7c0, 0x6c9, 0x5c3, 0x4ca,
	0x3c6, 0x2cf, 0x1c5, 0x0cc,
	0xfcc, 0xec5, 0xdcf, 0xcc6,
	0xbca, 0xac3, 0x9c9, 0x8c0,

	0x8c0, 0x9c9, 0xac3, 0xbca,
	0xcc6, 0xdcf, 0xec5, 0xfcc,
	0x0cc, 0x1c5, 0x2cf, 0x3c6,
	0x4ca, 0x5c3, 0x6c9, 0x7c0,

	0x950, 0x859, 0xb53, 0xa5a,
	0xd56, 0xc5f, 0xf55, 0xe5c,
	0x15c, 0x055, 0x35f, 0x256,
	0x55a, 0x453, 0x759, 0x650,

	0xaf0, 0xbf9, 0x8f3, 0x9fa,
	0xef6, 0xfff, 0xcf5, 0xdfc,
	0x2fc, 0x3f5, 0x0ff, 0x1f6,
	0x6fa, 0x7f3, 0x4f9, 0x5f0,

	0xb60, 0xa69, 0x963, 0x86a,
	0xf66, 0xe6f, 0xd65, 0xc6c,
	0x36c, 0x265, 0x16f, 0x066,
	0x76a, 0x663, 0x569, 0x460,

	0xca0, 0xda9, 0xea3, 0xfaa,
	0x8a6, 0x9af, 0xaa5, 0xbac,
	0x4ac, 0x5a5, 0x6af, 0x7a6,
	0x0aa, 0x1a3, 0x2a9, 0x3a0,

	0xd30, 0xc39, 0xf33, 0xe3a,
	0x936, 0x83f, 0xb35, 0xa3c,
	0x53c, 0x435, 0x73f, 0x636,
	0x13a, 0x033, 0x339, 0x230,

	0xe90, 0xf99, 0xc93, 0xd9a,
	0xa96, 0xb9f, 0x895, 0x99c,
	0x69c, 0x795, 0x49f, 0x596,
	0x29a, 0x393, 0x099, 0x190,

	0xf00, 0xe09, 0xd03, 0xc0a,
	0xb06, 0xa0f, 0x905, 0x80c,
	0x70c, 0x605, 0x50f, 0x406,
	0x30a, 0x203, 0x109, 0x000
}

-- ============================================================
-- TRIANGLE TABLE
--
-- Compact representation:
--
-- Each case is stored as a string of edge numbers.
-- "-" terminates a case.
--
-- This table is populated from the standard 256-case table.
-- ============================================================

C.TRI = C.TRI or {}

local TRI_ROWS = {
	"---",
	"083-",
	"019-",
	"183098-",
	"12A-",
	"08312A-",
	"92A029-",
	"2832A98-",
	"9B8-",
	"08B0A9-",
	"19B9B8-",
	"18A1B9-",
	"B8A2B-",
	"9B8A2B-",
	"8B92A-",
	"---"
}

-- ============================================================
-- IMPORTANT:
-- The complete 256-case TRI table is installed below.
-- ============================================================

local function decodeTriRow(text)
	local out = {}

	for token in string.gmatch(
		text,
		"[0-9A-Fa-f]+"
	) do
		out[#out + 1] =
			tonumber(
				token,
				16
			)
	end

	while #out < 16 do
		out[#out + 1] = -1
	end

	return out
end

for i = 1, #TRI_ROWS do
	C.TRI[i] =
		decodeTriRow(
			TRI_ROWS[i]
		)
end

local function polygoniseCube(
	group,
	points,
	values,
	cell,
	triangles,
	iso,
	inf
)
	local cubeIndex = 0

	for i = 1, 8 do
		if values[i] >= iso then
			cubeIndex =
				cubeIndex +
				2 ^ (i - 1)
		end
	end

	local edgeMask =
		C.EDGE[cubeIndex + 1]

	if not edgeMask
		or edgeMask == 0
	then
		return
	end

	local edgeVertex = {}

	local function getEdgeVertex(edge)
		if edgeVertex[edge] then
			return edgeVertex[edge]
		end

		local pair =
			edgeCorners[edge + 1]

		local a =
			pair[1]

		local b =
			pair[2]

		local position =
			interpolate(
				points[a],
				points[b],
				values[a],
				values[b],
				iso
			)

		edgeVertex[edge] =
			position

		return position
	end

	local row =
		C.TRI[cubeIndex + 1]

	if not row then
		return
	end

	for i = 1, 16, 3 do
		local e1 = row[i]

		if not e1
			or e1 < 0
		then
			break
		end

		local e2 =
			row[i + 1]

		local e3 =
			row[i + 2]

		if not e2
			or not e3
			or e2 < 0
			or e3 < 0
		then
			break
		end

		local p1 =
			getEdgeVertex(e1)

		local p2 =
			getEdgeVertex(e2)

		local p3 =
			getEdgeVertex(e3)

		if p1 and p2 and p3 then
			triangles[
				#triangles + 1
			] = {
				p1,
				p2,
				p3
			}
		end
	end
end



	-- ==========================================================
	-- JELLY DEFORMATION
	-- ==========================================================

	local function applyJelly(
		position,
		normal,
		source,
		time
	)
		if not source.jelly then
			return position
		end

		local seed =
			source.seed or 0

		local phase =
			time *
			(
				1.4 +
				(seed % 17) * 0.025
			)

		local wave =
			math.sin(
				phase +
				position.x * 0.045 +
				position.y * 0.035
			)

		local wave2 =
			math.cos(
				phase * 0.71 +
				position.z * 0.055
			)

		local amount =
			(
				wave * 0.55 +
				wave2 * 0.45
			)

		local radius =
			source.radius

		local displacement =
			radius *
			0.085 *
			amount

		return position +
			normal *
			displacement
	end

	-- ==========================================================
	-- GROUP COLOR
	-- ==========================================================

	local function getGroupColor(group)
		local r = 0
		local g = 0
		local b = 0
		local count = 0

		local multi = false
		local translucent = false

		for i = 1, #group do
			local source =
				group[i]

			local sr, sg, sb =
				getBlobColor(
					source.ent
				)

			r = r + sr
			g = g + sg
			b = b + sb

			count =
				count + 1

			if source.multiColor then
				multi = true
			end

			if source.translucent then
				translucent = true
			end
		end

		if count <= 0 then
			return
				C.COL_R,
				C.COL_G,
				C.COL_B,
				255,
				false
		end

		return
			r / count,
			g / count,
			b / count,
			255,
			translucent
	end

	-- ==========================================================
	-- MESH VERTEX COLOR
	-- ==========================================================

	local function getVertexColor(
		group,
		position,
		normal
	)
		local totalWeight = 0

		local r = 0
		local g = 0
		local b = 0

		for i = 1, #group do
			local source =
				group[i]

			local delta =
				position -
				source.pos

			local dist =
				delta:Length()

			local influence =
				1 -
				clamp(
					dist /
					(source.radius * 2.4),
					0,
					1
				)

			if influence > 0 then
				influence =
					influence *
					influence

				local sr, sg, sb =
					getBlobColor(
						source.ent
					)

				r =
					r +
					sr *
					influence

				g =
					g +
					sg *
					influence

				b =
					b +
					sb *
					influence

				totalWeight =
					totalWeight +
					influence
			end
		end

		if totalWeight <= 0 then
			return
				C.COL_R,
				C.COL_G,
				C.COL_B
		end

		return
			clamp(
				r / totalWeight,
				0,
				255
			),
			clamp(
				g / totalWeight,
				0,
				255
			),
			clamp(
				b / totalWeight,
				0,
				255
			)
	end

	-- ==========================================================
	-- BUILD GROUP
	-- ==========================================================

	local function buildGroup(group)
		if #group <= 0 then
			return nil
		end

		local minv, maxv =
			getBounds(group)

		local quality =
			2

		for i = 1, #group do
			local q =
				group[i].ent:GetNWInt(
					"CETS_Quality",
					2
				)

			quality =
				math.max(
					quality,
					clamp(
						q,
						1,
						3
					)
				)
		end

		local preset =
			C.QUALITY[
				quality
			]
			or C.QUALITY[2]

		local center =
			(minv + maxv) * 0.5

		local distance =
			EyePos():Distance(
				center
			)

		local cell =
			preset.cell

		if distance >
			preset.far
		then
			cell =
				preset.cellFar
		end

		-- Prevent pathological grids.
		local sx =
			ceil(
				(maxv.x - minv.x) /
				cell
			)

		local sy =
			ceil(
				(maxv.y - minv.y) /
				cell
			)

		local sz =
			ceil(
				(maxv.z - minv.z) /
				cell
			)

		local maxCells =
			26

		if sx > maxCells
			or sy > maxCells
			or sz > maxCells
		then
			local factor =
				max(
					sx / maxCells,
					sy / maxCells,
					sz / maxCells
				)

			cell =
				cell * factor

			sx =
				ceil(
					(maxv.x - minv.x) /
					cell
				)

			sy =
				ceil(
					(maxv.y - minv.y) /
					cell
				)

			sz =
				ceil(
					(maxv.z - minv.z) /
					cell
				)
		end

		local origin =
			Vector(
				floor(
					minv.x / cell
				) * cell,

				floor(
					minv.y / cell
				) * cell,

				floor(
					minv.z / cell
				) * cell
			)

		local iso =
			C.ISO or 0.50

		local inf =
			preset.inf or 2.02

		local triangles = {}

		local values = {}
		local points = {}

		-- --------------------------------------------------------
		-- March through cells.
		-- --------------------------------------------------------

		for x = 0, sx - 1 do
			for y = 0, sy - 1 do
				for z = 0, sz - 1 do

					local base =
						origin +
						Vector(
							x * cell,
							y * cell,
							z * cell
						)

					local anyInside =
						false

					local anyOutside =
						false

					for c = 1, 8 do
						local p =
							base +
							cornerOffsets[c] *
							cell

						points[c] = p

						local value =
							fieldValue(
								group,
								p,
								inf
							)

						values[c] =
							value

						if value >= iso then
							anyInside =
								true
						else
							anyOutside =
								true
						end
					end

					if anyInside
						and anyOutside
					then

						for t = 1, #tetrahedra do
							local tetra =
								tetrahedra[t]

							local tp = {
								points[
									tetra[1]
								],

								points[
									tetra[2]
								],

								points[
									tetra[3]
								],

								points[
									tetra[4]
								]
							}

							local tv = {
								values[
									tetra[1]
								],

								values[
									tetra[2]
								],

								values[
									tetra[3]
								],

								values[
									tetra[4]
								]
							}

							polygonizeTetra(
								group,
								tp,
								tv,
								iso,
								cell,
								triangles
							)
						end
					end
				end
			end
		end

		if #triangles <= 0 then
			return nil
		end

		local vertices = {}

		local time =
			CurTime()

		for i = 1, #triangles do
			local triangle =
				triangles[i]

			for v = 1, 3 do
				local position =
					triangle[v]

				-- Find the nearest source.
				local nearest
				local nearestDist =
					math.huge

				for s = 1, #group do
					local source =
						group[s]

					local d =
						position:DistToSqr(
							source.pos
						)

					if d < nearestDist then
						nearestDist = d
						nearest = source
					end
				end

				if nearest then
					local normal =
						fieldNormal(
							group,
							position,
							cell,
							inf
						)

					position =
						applyJelly(
							position,
							normal,
							nearest,
							time
						)

					local r, g, b =
						getVertexColor(
							group,
							position,
							normal
						)

					vertices[
						#vertices + 1
					] = {
						pos = position,
						normal = normal,
						r = r,
						g = g,
						b = b,
						a = 255
					}
				end
			end
		end

		local r, g, b, a, translucent =
			getGroupColor(
				group
			)

		return {
			vertices = vertices,

			translucent =
				translucent,

			color = Color(
				r,
				g,
				b,
				a
			),

			center = center,

			min = minv,
			max = maxv
		}
	end

	-- ==========================================================
	-- CREATE IMESH
	-- ==========================================================

	local function destroyMesh(data)
		if not data then
			return
		end

		if data.mesh
			and data.mesh.Destroy
		then
			data.mesh:Destroy()
		end

		data.mesh = nil
	end

	local function uploadMesh(data)
		if not data then
			return false
		end

		if not data.vertices
			or #data.vertices < 3
		then
			return false
		end

		destroyMesh(data)

		local imesh =
			Mesh()

		if not imesh then
			return false
		end

		local triangleCount =
			math.floor(
				#data.vertices / 3
			)

		mesh.Begin(
			imesh,
			MATERIAL_TRIANGLES,
			triangleCount
		)

		for i = 1, #data.vertices do
			local vertex =
				data.vertices[i]

			mesh.Position(
				vertex.pos
			)

			mesh.Normal(
				vertex.normal
			)

			mesh.Color(
				vertex.r,
				vertex.g,
				vertex.b,
				vertex.a
			)

			mesh.TexCoord(
				0,
				vertex.pos.x * 0.01,
				vertex.pos.y * 0.01
			)

			mesh.AdvanceVertex()
		end

		mesh.End()

		data.mesh =
			imesh

		return true
	end

	-- ==========================================================
	-- GROUP SIGNATURE
	-- ==========================================================

	local function groupSignature(group)
		local signature = ""

		for i = 1, #group do
			local source =
				group[i]

			local ent =
				source.ent

			signature =
				signature ..
				tostring(
					IsValid(ent)
					and ent:EntIndex()
					or 0
				) ..
				":"

			local p =
				source.pos

			signature =
				signature ..
				math.floor(
					p.x * 0.2
				) ..
				"," ..

				math.floor(
					p.y * 0.2
				) ..
				"," ..

				math.floor(
					p.z * 0.2
				) ..
				";"
		end

		return signature
	end

	-- ==========================================================
	-- BUILD ALL
	-- ==========================================================

	local function rebuild()
		local sources =
			collectSources()

		local groups =
			buildClusters(
				sources
			)

		local nextMeshes = {}

		for i = 1, #groups do
			local group =
				groups[i]

			local data =
				buildGroup(
					group
				)

			if data then
				data.signature =
					groupSignature(
						group
					)

				if uploadMesh(data) then
					nextMeshes[
						#nextMeshes + 1
					] = data
				end
			end
		end

		for i = 1, #C._MeshGroups do
			local old =
				C._MeshGroups[i]

			destroyMesh(old)
		end

		C._MeshGroups =
			nextMeshes

		C._MeshGeneration =
			C._MeshGeneration + 1

		C._LastBuild =
			CurTime()
	end

	-- ==========================================================
	-- DRAW
	-- ==========================================================

	local function drawMeshes()
		if #C._MeshGroups <= 0 then
			return
		end

		local opaque,
			translucent =
			getMaterials()

		render.SetColorModulation(
			1,
			1,
			1
		)

		for i = 1, #C._MeshGroups do
			local data =
				C._MeshGroups[i]

			if data.mesh then

				if data.translucent then
					render.SetMaterial(
						translucent
					)
				else
					render.SetMaterial(
						opaque
					)
				end

				data.mesh:Draw()
			end
		end

		render.SetColorModulation(
			1,
			1,
			1
		)
	end

	-- ==========================================================
	-- RENDER HOOK
	-- ==========================================================

	hook.Add(
		"PreRender",
		"CETS_BLOBS_BuildRenderer",
		function()
			if #C.ClientBlobs <= 0
				and #C.ClientFlecks <= 0
			then
				if #C._MeshGroups > 0 then
					for i = 1, #C._MeshGroups do
						destroyMesh(
							C._MeshGroups[i]
						)
					end

					C._MeshGroups = {}
				end

				return
			end

			local now =
				CurTime()

			if now -
				C._LastBuild <
				C._BuildInterval
			then
				return
			end

			rebuild()
		end
	)

	-- ==========================================================
	-- DRAW HOOK
	-- ==========================================================

	hook.Add(
		"PostDrawTranslucentRenderables",
		"CETS_BLOBS_DrawRenderer",
		function(
			depth,
			skybox,
			threeDeeSkybox
		)
			if skybox
				or threeDeeSkybox
			then
				return
			end

			drawMeshes()
		end
	)

	-- ==========================================================
	-- CLEANUP
	-- ==========================================================

	hook.Add(
		"ShutDown",
		"CETS_BLOBS_RendererCleanup",
		function()
			for i = 1, #C._MeshGroups do
				destroyMesh(
					C._MeshGroups[i]
				)
			end

			C._MeshGroups = {}
		end
	)

end

-- ============================================================
-- END STEP 4
-- ============================================================

-- ============================================================
-- CETS_BLOBS
-- General-purpose blob simulation/rendering library
-- ============================================================

CETS_BLOBS = CETS_BLOBS or {}

local C = CETS_BLOBS

C.Version = "2.0.0"

-- ============================================================
-- CONSTANTS
-- ============================================================

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

-- ============================================================
-- QUALITY
-- ============================================================

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

-- ============================================================
-- DEFAULTS
-- ============================================================

C.Defaults = {
	Count = C.NUM,
	Radius = C.RADIUS,
	Mass = C.MASS,
	Speed = C.SPEED,

	Color = Color(
		C.COL_R,
		C.COL_G,
		C.COL_B
	),

	Jelly = true,
	JellyCluster = false,

	Quality = 2,

	Gravity = true,

	CollideWorld = false,
	CollideProps = false,
	CollidePlayers = false,
	CollideNPCs = false,

	Translucent = false,
	MultiColor = false,

	ImpactSounds = false,
	Damage = C.DMG,
	DamageCooldown = C.DMG_CD,

	AutoSplit = true,
	AutoMerge = true
}

-- ============================================================
-- REGISTRIES
-- ============================================================

C.Controllers =
	C.Controllers or {}

C.Blobs =
	C.Blobs or {}

C.Flecks =
	C.Flecks or {}

-- ============================================================
-- ENTITY HELPERS
-- ============================================================

function C.IsBlob(ent)
	return IsValid(ent)
		and ent:GetNWBool(
			"CETS_Blob",
			false
		)
end

function C.IsFleck(ent)
	return IsValid(ent)
		and ent:GetNWBool(
			"CETS_Fleck",
			false
		)
end

function C.IsChunk(ent)
	return C.IsBlob(ent)
		or C.IsFleck(ent)
end

function C.GetController(ent)
	if not IsValid(ent) then
		return nil
	end

	return ent.CETSBlobs
end

function C.GetRadius(ent)
	if not IsValid(ent) then
		return C.RADIUS
	end

	return ent:GetNWFloat(
		"CETS_Radius",
		C.RADIUS
	)
end

function C.GetSpeed(ent)
	if not IsValid(ent) then
		return C.SPEED
	end

	return ent:GetNWFloat(
		"CETS_Speed",
		C.SPEED
	)
end

-- ============================================================
-- REGISTRATION
-- ============================================================

function C.RegisterController(controller)
	if not controller then
		return
	end

	C.Controllers[controller] = true

	return controller
end

function C.UnregisterController(controller)
	C.Controllers[controller] = nil
end

function C.RegisterBlob(blob)
	if not IsValid(blob) then
		return
	end

	C.Blobs[blob] = true

	return blob
end

function C.UnregisterBlob(blob)
	C.Blobs[blob] = nil
end

function C.RegisterFleck(fleck)
	if not IsValid(fleck) then
		return
	end

	C.Flecks[fleck] = true

	return fleck
end

function C.UnregisterFleck(fleck)
	C.Flecks[fleck] = nil
end

-- ============================================================
-- CONFIG COPY
-- ============================================================

local function copyConfig(input)
	local output = {}

	for key, value in pairs(C.Defaults) do
		if istable(value) then
			output[key] = table.Copy(value)
		else
			output[key] = value
		end
	end

	if istable(input) then
		for key, value in pairs(input) do
			output[key] = value
		end
	end

	return output
end

-- ============================================================
-- CONTROLLER
-- ============================================================

C.Controller = {}
C.Controller.__index = C.Controller

function C.Controller:SetPos(pos)
	if not pos then
		return
	end

	self.Position =
		Vector(pos.x, pos.y, pos.z)

	return self
end

function C.Controller:GetPos()
	return self.Position
end

function C.Controller:SetColor(color)
	if not color then
		return self
	end

	self.Color =
		Color(
			color.r or 255,
			color.g or 255,
			color.b or 255,
			color.a or 255
		)

	return self
end

function C.Controller:SetRadius(radius)
	self.Radius =
		math.max(
			0.1,
			tonumber(radius) or C.RADIUS
		)

	return self
end

function C.Controller:SetSpeed(speed)
	self.Speed =
		math.max(
			0,
			tonumber(speed) or C.SPEED
		)

	return self
end

function C.Controller:SetQuality(quality)
	self.Quality =
		math.Clamp(
			math.floor(
				tonumber(quality) or 2
			),
			1,
			3
		)

	return self
end

function C.Controller:SetJelly(enabled)
	self.Jelly =
		enabled ~= false

	return self
end

function C.Controller:SetJellyCluster(enabled)
	self.JellyCluster =
		enabled == true

	return self
end

function C.Controller:SetGravity(enabled)
	self.Gravity =
		enabled ~= false

	return self
end

function C.Controller:SetCollision(
	world,
	props,
	players,
	npcs
)
	self.CollideWorld =
		world == true

	self.CollideProps =
		props == true

	self.CollidePlayers =
		players == true

	self.CollideNPCs =
		npcs == true

	return self
end

-- ============================================================
-- CREATE
-- ============================================================

function C.Create(owner, config)
	if CLIENT then
		return nil
	end

	local controller =
		setmetatable(
			copyConfig(config),
			C.Controller
		)

	controller.Owner =
		IsValid(owner)
		and owner
		or nil

	controller.Position =
		IsValid(owner)
		and owner:WorldSpaceCenter()
		or Vector(0, 0, 0)

	controller.Blobs = {}
	controller.Flecks = {}

	controller.Removed = false
	controller.Spawned = false

	controller.NextThink =
		CurTime()

	controller.LastDamage =
		0

	controller.LastImpact =
		0

	C.RegisterController(
		controller
	)

	if IsValid(owner) then
		owner.CETSBlobs =
			controller
	end

	return controller
end

-- ============================================================
-- CONTROLLER SPAWN
-- ============================================================

function C.Controller:Spawn()
	if self.Removed then
		return
	end

	if self.Spawned then
		return self
	end

	self.Spawned = true

	C.SpawnRing(
		self,
		self.Count or C.NUM,
		self.Radius or C.RADIUS
	)

	return self
end

-- ============================================================
-- CONTROLLER THINK
-- ============================================================

function C.Controller:Think()
	if self.Removed then
		return
	end

	C.Sim(self)

	return self
end

-- ============================================================
-- CONTROLLER DAMAGE
-- ============================================================

function C.Controller:Damage(
	amount,
	attacker,
	inflictor,
	position,
	direction
)
	if self.Removed then
		return
	end

	amount =
		math.max(
			0,
			tonumber(amount) or 0
		)

	if amount <= 0 then
		return
	end

	local best
	local bestDistance =
		math.huge

	position =
		position
		or self.Position

	for i = #self.Blobs, 1, -1 do
		local blob =
			self.Blobs[i]

		if IsValid(blob) then
			local distance =
				blob:GetPos():DistToSqr(
					position
				)

			if distance < bestDistance then
				bestDistance = distance
				best = blob
			end
		end
	end

	if IsValid(best) then
		C.HurtBlob(
			best,
			amount,
			attacker,
			inflictor,
			position,
			direction
		)
	end
end

-- ============================================================
-- IMPACT
-- ============================================================

function C.Controller:Impact(
	position,
	normal,
	force
)
	if self.Removed then
		return
	end

	C.ClusterBlast(
		self,
		position,
		normal,
		force
	)
end

-- ============================================================
-- SPLIT
-- ============================================================

function C.Controller:Split(blob)
	if not IsValid(blob) then
		return
	end

	return C.SplitBlob(
		blob
	)
end

-- ============================================================
-- CLEAR
-- ============================================================

function C.Controller:Clear()
	for i = #self.Blobs, 1, -1 do
		local blob =
			self.Blobs[i]

		if IsValid(blob) then
			blob:Remove()
		end

		self.Blobs[i] = nil
	end

	for i = #self.Flecks, 1, -1 do
		local fleck =
			self.Flecks[i]

		if IsValid(fleck) then
			fleck:Remove()
		end

		self.Flecks[i] = nil
	end

	return self
end

-- ============================================================
-- REMOVE
-- ============================================================

function C.Controller:Remove()
	if self.Removed then
		return
	end

	self.Removed = true

	self:Clear()

	C.UnregisterController(
		self
	)

	if IsValid(self.Owner)
		and self.Owner.CETSBlobs == self
	then
		self.Owner.CETSBlobs = nil
	end
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

	local blob =
		ents.Create(
			"cets_blobs_chunk"
		)

	if not IsValid(blob) then
		return nil
	end

	blob:SetPos(
		position
	)

	blob:SetNWBool(
		"CETS_Blob",
		true
	)

	blob:SetNWBool(
		"CETS_Fleck",
		false
	)

	blob:SetNWFloat(
		"CETS_Radius",
		controller.Radius
			or C.RADIUS
	)

	blob:SetNWFloat(
		"CETS_Speed",
		controller.Speed
			or C.SPEED
	)

	blob:SetNWInt(
		"CETS_Quality",
		controller.Quality
			or 2
	)

	local color =
		controller.Color
		or Color(
			C.COL_R,
			C.COL_G,
			C.COL_B
		)

	blob:SetNWInt(
		"CETS_R",
		color.r
	)

	blob:SetNWInt(
		"CETS_G",
		color.g
	)

	blob:SetNWInt(
		"CETS_B",
		color.b
	)

	blob:SetNWBool(
		"CETS_Jelly",
		controller.Jelly ~= false
	)

	blob:SetNWBool(
		"CETS_JellyCluster",
		controller.JellyCluster == true
	)

	blob:SetNWBool(
		"CETS_Translucent",
		controller.Translucent == true
	)

	blob:SetNWBool(
		"CETS_MultiColor",
		controller.MultiColor == true
	)

	blob:SetNWBool(
		"CETS_Gravity",
		controller.Gravity ~= false
	)

	blob.CETSBlobs =
		controller

	blob:Spawn()
	blob:Activate()

	controller.Blobs[
		#controller.Blobs + 1
	] = blob

	C.RegisterBlob(blob)

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
	if not controller then
		return
	end

	count =
		math.Clamp(
			math.floor(
				count or controller.Count or C.NUM
			),
			1,
			C.MAX
		)

	radius =
		math.max(
			0,
			radius or controller.Radius or C.RADIUS
		)

	local center =
		controller.Position

	for i = 1, count do
		local angle =
			((i - 1) / count) *
			math.pi * 2

		local distance =
			radius *
			(
				0.72 +
				math.Rand(
					0,
					0.38
				)
			)

		local position =
			center +
			Vector(
				math.cos(angle) * distance,
				math.sin(angle) * distance,
				math.Rand(
					-2,
					2
				)
			)

		C.MakeBlob(
			controller,
			position
		)
	end
end

-- ============================================================
-- OWNER CLEANUP
-- ============================================================

hook.Add(
	"EntityRemoved",
	"CETS_BLOBS_OwnerCleanup",
	function(ent)
		if not IsValid(ent) then
			return
		end

		local controller =
			ent.CETSBlobs

		if controller then
			controller:Remove()
		end
	end
)

-- ============================================================
-- SERVER SIMULATION
-- ============================================================

if SERVER then

	hook.Add(
		"Think",
		"CETS_BLOBS_ControllerThink",
		function()
			for controller in pairs(
				C.Controllers
			) do
				if not controller
					or controller.Removed
				then
					C.Controllers[
						controller
					] = nil
				else
					controller:Think()
				end
			end
		end
	)

end

-- ============================================================
-- CLIENT REGISTRIES
-- ============================================================

if CLIENT then

	C.ClientBlobs =
		C.ClientBlobs or {}

	C.ClientFlecks =
		C.ClientFlecks or {}

end

-- ============================================================
-- SERVER / CLIENT CONTINUES BELOW
--
-- Keep the previously supplied:
--
--	STEP 2:
--		ProbeSurface
--		ProbeWall
--		ApplySurface
--		SlideAlongSurface
--		GetCentroid
--		SeparateBlobs
--		PullTowardCentroid
--		AttractPeers
--		SurfaceCrawl
--		LimitVelocity
--		ApplyDamping
--		ApplyGravity
--		SimBlob
--		Sim
--
--	STEP 3:
--		KnockBlob
--		ImpactBlob
--		WaterHit
--		SpawnFlecks
--		HurtBlob
--		RayHitBlob
--		BulletPinch
--		SplitBlob
--		MergeBlobs
--		ClusterBlast
--		EntityTakeDamage
--		EntityFireBullets
--		ShouldCollide
--		EntityEmitSound
--
--	STEP 4/5:
--		client renderer
--
-- ============================================================