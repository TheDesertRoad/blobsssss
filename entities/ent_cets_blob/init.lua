AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")


------------------------------------------------------------
-- Configuration
------------------------------------------------------------

local PARTICLE_CLASS =
	"ent_cets_blob_particle"


local PARTICLE_RADIUS =
	5.0

local PARTICLE_SPACING =
	9.5


------------------------------------------------------------
-- Number of real physical liquid cells
------------------------------------------------------------

local MAX_PARTICLES =
	96


local INITIAL_SPAWN_PER_TICK =
	16


------------------------------------------------------------
-- Liquid simulation
--
-- This is intentionally NOT a rigid cluster solver.
--
-- Each cell remains an independent physics object.
-- The controller only adds small local corrections.
------------------------------------------------------------

local LIQUID_UPDATE_INTERVAL =
	0.035


------------------------------------------------------------
-- Spatial hash
------------------------------------------------------------

local NEIGHBOR_CELL_SIZE =
	18


local NEIGHBOR_RADIUS =
	17.5


local NEIGHBOR_RADIUS_SQR =
	NEIGHBOR_RADIUS
	*
	NEIGHBOR_RADIUS


------------------------------------------------------------
-- Desired spacing
------------------------------------------------------------

local REST_DISTANCE =
	10.0


local REPULSION_DISTANCE =
	8.0


------------------------------------------------------------
-- Liquid response
------------------------------------------------------------

local COHESION_RESPONSE =
	1.10


local COHESION_DAMPING =
	0.24


local REPULSION_RESPONSE =
	1.60


local MAX_LIQUID_VELOCITY_CHANGE =
	22


local MAX_LIQUID_SPEED =
	800


------------------------------------------------------------
-- Ground
------------------------------------------------------------

local GROUND_UPDATE_INTERVAL =
	0.12


local GROUND_TRACE_DISTANCE =
	8


local GROUND_NORMAL_Z =
	0.50


local GROUND_VERTICAL_DAMPING =
	0.10


------------------------------------------------------------
-- Entity interaction
------------------------------------------------------------

local ENTITY_UPDATE_INTERVAL =
	0.06


local ENTITY_SEARCH_RADIUS =
	96


local ENTITY_INFLUENCE_RADIUS =
	20


local ENTITY_INFLUENCE_RADIUS_SQR =
	ENTITY_INFLUENCE_RADIUS
	*
	ENTITY_INFLUENCE_RADIUS


local PLAYER_PUSH =
	0.075


local NPC_PUSH =
	0.085


local PROP_PUSH =
	0.12


local ENTITY_TRANSFER =
	0.09


local ENTITY_ENTRY_SPEED =
	65


local ENTITY_BREAK_SPEED =
	110


local DISTURB_TIME =
	0.38


local MAX_ENTITY_SPEED =
	450


------------------------------------------------------------
-- Tick helper
------------------------------------------------------------

local function ENGINE_TICK_INTERVAL()

	return math.min(
		engine.TickInterval(),
		0.05
	)

end


------------------------------------------------------------
-- Explosions
------------------------------------------------------------

local EXPLOSION_RADIUS =
	220


local EXPLOSION_VELOCITY_SCALE =
	0.22


local EXPLOSION_MAX_VELOCITY =
	320


local EXPLOSION_DISTURB_TIME =
	0.85


------------------------------------------------------------
-- Bullets
------------------------------------------------------------

local BULLET_RADIUS =
	17


local BULLET_RADIUS_SQR =
	BULLET_RADIUS
	*
	BULLET_RADIUS


local BULLET_VELOCITY =
	55


local BULLET_MAX_VELOCITY =
	220


local BULLET_DISTURB_TIME =
	0.45


------------------------------------------------------------
-- Collision group
------------------------------------------------------------

local BALL_COLLISION_GROUP =
	COLLISION_GROUP_INTERACTIVE_DEBRIS


------------------------------------------------------------
-- Collision filtering
--
-- World   = YES
-- Props   = YES
-- NPCs    = YES
-- Players = NO
-- Liquid  = NO
------------------------------------------------------------

hook.Add(
	"ShouldCollide",
	"CETS_LiquidParticle_CollisionFilter",
	function(
		ent1,
		ent2
	)

		if not IsValid(ent1)
		or not IsValid(ent2) then

			return

		end


		local liquid1 =
			ent1.CETS_LiquidBlobParticle

		local liquid2 =
			ent2.CETS_LiquidBlobParticle


		----------------------------------------------------
		-- Liquid / liquid.
		----------------------------------------------------

		if liquid1
		and liquid2 then

			return false

		end


		----------------------------------------------------
		-- Liquid / player.
		----------------------------------------------------

		if liquid1
		and ent2:IsPlayer() then

			return false

		end


		if liquid2
		and ent1:IsPlayer() then

			return false

		end

	end
)


------------------------------------------------------------
-- Prevent physgun pickup
------------------------------------------------------------

hook.Add(
	"PhysgunPickup",
	"CETS_LiquidParticle_NoPhysgun",
	function(
		ply,
		ent
	)

		if IsValid(ent)
		and ent.CETS_LiquidBlobParticle then

			return false

		end

	end
)


------------------------------------------------------------
-- Prevent USE
------------------------------------------------------------

hook.Add(
	"PlayerUse",
	"CETS_LiquidParticle_NoUse",
	function(
		ply,
		ent
	)

		if IsValid(ent)
		and ent.CETS_LiquidBlobParticle then

			return false

		end

	end
)


------------------------------------------------------------
-- Vector helpers
------------------------------------------------------------

local function ClampVectorLength(
	vector,
	maxLength
)

	local lengthSqr =
		vector:LengthSqr()


	local maxLengthSqr =
		maxLength
		*
		maxLength


	if lengthSqr <=
		maxLengthSqr then

		return vector

	end


	if lengthSqr <=
		0.000001 then

		return Vector(
			0,
			0,
			0
		)

	end


	return vector
		*
		(
			maxLength
			/
			math.sqrt(
				lengthSqr
			)
		)

end


local function GridKey(
	x,
	y,
	z
)

	return x
		*
		73856093
		+
		y
		*
		19349663
		+
		z
		*
		83492791

end


local function GetCell(
	position
)

	return
		math.floor(
			position.x
			/
			NEIGHBOR_CELL_SIZE
		),

		math.floor(
			position.y
			/
			NEIGHBOR_CELL_SIZE
		),

		math.floor(
			position.z
			/
			NEIGHBOR_CELL_SIZE
		)

end


local function GetSafeDirection(
	delta
)

	local lengthSqr =
		delta:LengthSqr()


	if lengthSqr >
		0.0001 then

		return
			delta
			/
			math.sqrt(
				lengthSqr
			)

	end


	return Vector(
		0,
		0,
		1
	)

end


------------------------------------------------------------
-- Add a real custom liquid particle
------------------------------------------------------------

function ENT:AddParticle(
	position
)

	if not self.Particles then
		return nil
	end


	if #self.Particles >=
		MAX_PARTICLES then

		return nil

	end


	local particle =
		ents.Create(
			PARTICLE_CLASS
		)


	if not IsValid(particle) then
		return nil
	end


	particle:SetPos(
		position
	)


	particle:SetAngles(
		Angle(
			0,
			0,
			0
		)
	)


	particle.CETS_LiquidParent =
		self


	particle:Spawn()
	particle:Activate()


	if not IsValid(particle) then
		return nil
	end


	self.Particles[
		#self.Particles + 1
	] =
		particle


	return particle

end


------------------------------------------------------------
-- Remove invalid references
------------------------------------------------------------

function ENT:RemoveInvalidParticles()

	if not self.Particles then
		return
	end


	for i = #self.Particles,
		1,
		-1 do

		local particle =
			self.Particles[i]


		if not IsValid(particle) then

			table.remove(
				self.Particles,
				i
			)

		end

	end

end


------------------------------------------------------------
-- Build initial spherical volume
------------------------------------------------------------

function ENT:BuildSpawnQueue()

	self.SpawnQueue = {}


	local half =
		3


	local positions = {}


	for x = -half,
		half do

		for y = -half,
			half do

			for z = -half,
				half do

				local position =
					Vector(
						x * PARTICLE_SPACING,
						y * PARTICLE_SPACING,
						z * PARTICLE_SPACING
					)


				local distanceSqr =
					position:LengthSqr()


				if distanceSqr
					<=
					(
						half
						*
						PARTICLE_SPACING
					)
					^
					2 then

					positions[
						#positions + 1
					] = {

						position =
							position,

						distanceSqr =
							distanceSqr

					}

				end

			end

		end

	end


	table.sort(
		positions,
		function(
			a,
			b
		)

			return
				a.distanceSqr
				<
				b.distanceSqr

		end
	)


	local amount =
		math.min(
			#positions,
			MAX_PARTICLES
		)


	local origin =
		self:GetPos()


	for i = 1,
		amount do

		self.SpawnQueue[
			#self.SpawnQueue + 1
		] =
			origin
			+
			positions[i].position

	end

end


------------------------------------------------------------
-- Process initial spawn queue
------------------------------------------------------------

function ENT:ProcessSpawnQueue()

	if not self.SpawnQueue then
		return
	end


	local amount =
		0


	while amount <
		INITIAL_SPAWN_PER_TICK
	and
		#self.SpawnQueue
		>
		0 do

		local position =
			self.SpawnQueue[
				#self.SpawnQueue
			]


		self.SpawnQueue[
			#self.SpawnQueue
		] =
			nil


		if position then

			self:AddParticle(
				position
			)

		end


		amount =
			amount
			+
			1

	end


	if #self.SpawnQueue ==
		0 then

		self.SpawnQueue =
			nil

	end

end


------------------------------------------------------------
-- Build spatial hash
------------------------------------------------------------

function ENT:BuildSpatialHash()

	self.SpatialHash =
		{}


	if not self.Particles then
		return
	end


	for i = 1,
		#self.Particles do

		local particle =
			self.Particles[i]


		if not IsValid(particle) then
			continue
		end


		local x,
			y,
			z =
			GetCell(
				particle:GetPos()
			)


		local key =
			GridKey(
				x,
				y,
				z
			)


		local bucket =
			self.SpatialHash[key]


		if not bucket then

			bucket =
				{}


			self.SpatialHash[key] =
				bucket

		end


		bucket[
			#bucket + 1
		] =
			particle

	end

end


------------------------------------------------------------
-- Query nearby particles from spatial hash
------------------------------------------------------------

function ENT:GetNearbyParticles(
	position,
	radius
)

	local result =
		{}


	local radiusSqr =
		radius
		*
		radius


	if not self.SpatialHash then
		return result
	end


	local minX,
		minY,
		minZ =
		GetCell(
			position
			-
			Vector(
				radius,
				radius,
				radius
			)
		)


	local maxX,
		maxY,
		maxZ =
		GetCell(
			position
			+
			Vector(
				radius,
				radius,
				radius
			)
		)


	for x = minX,
		maxX do

		for y = minY,
			maxY do

			for z = minZ,
				maxZ do

				local bucket =
					self.SpatialHash[
						GridKey(
							x,
							y,
							z
						)
					]


				if not bucket then
					continue
				end


				for i = 1,
					#bucket do

					local particle =
						bucket[i]


					if IsValid(
						particle
					)
					and
					particle:GetPos():DistToSqr(
						position
					)
					<=
					radiusSqr then

						result[
							#result + 1
						] =
							particle

					end

				end

			end

		end

	end


	return result

end


------------------------------------------------------------
-- Local liquid simulation
------------------------------------------------------------

function ENT:SimulateLiquid(
	deltaTime
)

	if not self.Particles
	or #self.Particles <=
		1 then

		return

	end


	self:RemoveInvalidParticles()

	self:BuildSpatialHash()


	local changes =
		{}


	for i = 1,
		#self.Particles do

		local particle =
			self.Particles[i]


		if IsValid(particle) then

			changes[particle] =
				Vector(
					0,
					0,
					0
				)

		end

	end


	local processed =
		{}


	local now =
		CurTime()


	for i = 1,
		#self.Particles do

		local particleA =
			self.Particles[i]


		if not IsValid(
			particleA
		) then

			continue

		end


		local positionA =
			particleA:GetPos()


		local cellX,
			cellY,
			cellZ =
			GetCell(
				positionA
			)


		for x = cellX - 1,
			cellX + 1 do

			for y = cellY - 1,
				cellY + 1 do

				for z = cellZ - 1,
					cellZ + 1 do

					local bucket =
						self.SpatialHash[
							GridKey(
								x,
								y,
								z
							)
						]


					if not bucket then
						continue
					end


					for n = 1,
						#bucket do

						local particleB =
							bucket[n]


						if not IsValid(
							particleB
						)
						or particleB
							==
							particleA
						or processed[
							particleB
						] then

							continue

						end


						local delta =
							particleB:GetPos()
							-
							positionA


						local distanceSqr =
							delta:LengthSqr()


						if distanceSqr
							>
							NEIGHBOR_RADIUS_SQR
						or
							distanceSqr
							<=
							0.000001 then

							continue

						end


						local distance =
							math.sqrt(
								distanceSqr
							)


						local direction =
							delta
							/
							distance


						local disturbed =
							(
								particleA.CETS_DisturbedUntil
								or
								0
							)
							>
							now

							or

							(
								particleB.CETS_DisturbedUntil
								or
								0
							)
							>
							now


						local scalar =
							0


						------------------------------------------------
						-- Too close = pressure/repulsion.
						------------------------------------------------

						if distance <
							REPULSION_DISTANCE then

							scalar =
								-(
									REPULSION_DISTANCE
									-
									distance
								)
								*
								REPULSION_RESPONSE


						------------------------------------------------
						-- Normal close-range surface cohesion.
						------------------------------------------------

						elseif distance >
							REST_DISTANCE then

							if disturbed then

								continue

							end


							scalar =
								(
									distance
									-
									REST_DISTANCE
								)
								*
								COHESION_RESPONSE

						end


						if math.abs(
							scalar
						)
						>
						0 then

							local velocityA =
								particleA:GetVelocity()


							local velocityB =
								particleB:GetVelocity()


							local relativeNormal =
								(
									velocityB
									-
									velocityA
								)
								:Dot(
									direction
								)


							scalar =
								scalar
								+
								relativeNormal
								*
								COHESION_DAMPING


							local deltaVelocity =
								direction
								*
								scalar
								*
								deltaTime


							changes[
								particleA
							] =
								changes[
									particleA
								]
								+
								deltaVelocity


							changes[
								particleB
							] =
								changes[
									particleB
								]
								-
								deltaVelocity

						end

					end

				end

			end

		end


		processed[
			particleA
		] =
			true

	end


	--------------------------------------------------------
	-- Apply accumulated local changes once per particle.
	--------------------------------------------------------

	for i = 1,
		#self.Particles do

		local particle =
			self.Particles[i]


		if not IsValid(
			particle
		) then

			continue

		end


		local deltaVelocity =
			changes[
				particle
			]


		if deltaVelocity then

			deltaVelocity =
				ClampVectorLength(
					deltaVelocity,
					MAX_LIQUID_VELOCITY_CHANGE
				)


			if deltaVelocity:LengthSqr()
				>
				0.000001 then

				local phys =
					particle:GetPhysicsObject()


				if IsValid(phys) then

					phys:AddVelocity(
						deltaVelocity
					)


					phys:Wake()

				end

			end

		end


		local velocity =
			particle:GetVelocity()


		local speed =
			velocity:Length()


		if speed >
			MAX_LIQUID_SPEED then

			particle:SetVelocity(
				velocity
				*
				(
					MAX_LIQUID_SPEED
					/
					speed
				)
			)

		end


		if (
			particle.CETS_DisturbedUntil
			or
			0
		)
		<=
		now then

			particle.CETS_DisturbedUntil =
				nil

		end

	end

end


------------------------------------------------------------
-- Entity velocity
------------------------------------------------------------

function ENT:GetEntityVelocity(
	ent,
	point
)

	if not IsValid(ent) then

		return Vector(
			0,
			0,
			0
		)

	end


	if ent:GetMoveType()
		==
		MOVETYPE_VPHYSICS then

		local phys =
			ent:GetPhysicsObject()


		if IsValid(phys) then

			return
				phys:GetVelocityAtPoint(
					point
				)

		end

	end


	return ent:GetVelocity()

end


------------------------------------------------------------
-- Entity interaction
--
-- Players are not physically colliding with the liquid.
-- They still disturb it as they move through it.
------------------------------------------------------------

function ENT:ApplyEntityDisturbance()

	if not self.Particles
	or #self.Particles == 0 then

		return

	end


	local entities =
		ents.FindInSphere(
			self:GetPos(),
			ENTITY_SEARCH_RADIUS
			+
			PARTICLE_SPACING * 3
		)


	for i = 1,
		#entities do

		local ent =
			entities[i]


		if not IsValid(ent)
		or ent == self
		or ent.CETS_LiquidBlobParticle then

			continue

		end


		local isPlayer =
			ent:IsPlayer()


		local isNPC =
			ent:IsNPC()


		local isPhysics =
			ent:GetMoveType()
			==
			MOVETYPE_VPHYSICS


		if not isPlayer
		and not isNPC
		and not isPhysics then

			continue

		end


		local entityCenter =
			ent:WorldSpaceCenter()


		local entityVelocity =
			ClampVectorLength(
				self:GetEntityVelocity(
					ent,
					entityCenter
				),
				MAX_ENTITY_SPEED
			)


		local speed =
			entityVelocity:Length()


		if speed < 1 then
			continue
		end


		local candidates =
			self:GetNearbyParticles(
				entityCenter,
				ENTITY_SEARCH_RADIUS
			)


		local pushScale


		if isPlayer then

			pushScale =
				PLAYER_PUSH

		elseif isNPC then

			pushScale =
				NPC_PUSH

		else

			pushScale =
				PROP_PUSH

		end


		for p = 1,
			#candidates do

			local particle =
				candidates[p]


			if not IsValid(
				particle
			) then

				continue

			end


			local particlePosition =
				particle:GetPos()


			local closest =
				ent:NearestPoint(
					particlePosition
				)


			local offset =
				particlePosition
				-
				closest


			local distanceSqr =
				offset:LengthSqr()


			if distanceSqr
				>
				ENTITY_INFLUENCE_RADIUS_SQR then

				continue

			end


			local distance =
				math.sqrt(
					math.max(
						distanceSqr,
						0.0001
					)
				)


			local direction =
				GetSafeDirection(
					offset
				)


			local strength =
				1
				-
				(
					distance
					/
					ENTITY_INFLUENCE_RADIUS
				)


			strength =
				math.Clamp(
					strength,
					0,
					1
				)


			local phys =
				particle:GetPhysicsObject()


			if not IsValid(
				phys
			) then

				continue

			end


			------------------------------------------------
			-- A moving object drags some liquid and also
			-- pushes nearby liquid away.
			------------------------------------------------

			local transfer =
				entityVelocity
				*
				(
					ENTITY_TRANSFER
					*
					strength
				)


			local away =
				direction
				*
				(
					math.max(
						speed - 20,
						0
					)
					*
					pushScale
					*
					strength
				)


			local deltaVelocity =
				(
					transfer
					+
					away
				)
				*
				math.min(
					ENGINE_TICK_INTERVAL()
					*
					8,
					1
				)


			deltaVelocity =
				ClampVectorLength(
					deltaVelocity,
					14
				)


			phys:AddVelocity(
				deltaVelocity
			)


			phys:Wake()


			------------------------------------------------
			-- Fast movement through the liquid suppresses
			-- cohesion locally, creating the desired
			-- temporary "break apart" behavior.
			------------------------------------------------

			if speed >=
				ENTITY_ENTRY_SPEED
			and distance <=
				PARTICLE_RADIUS + 4 then

				particle.CETS_DisturbedUntil =
					CurTime()
					+
					DISTURB_TIME

			end


			------------------------------------------------
			-- A faster pass produces a stronger splash.
			------------------------------------------------

			if speed >=
				ENTITY_BREAK_SPEED
			and distance <=
				PARTICLE_RADIUS + 2 then

				local burst =
					direction
					*
					math.min(
						speed * 0.20,
						110
					)


				phys:AddVelocity(
					burst
				)

			end

		end

	end

end


------------------------------------------------------------
-- Ground damping
------------------------------------------------------------

function ENT:ApplyGroundDamping()

	if not self.Particles then
		return
	end


	for i = 1,
		#self.Particles do

		local particle =
			self.Particles[i]


		if not IsValid(
			particle
		) then

			continue

		end


		local position =
			particle:GetPos()


		local trace =
			util.TraceLine({

				start =
					position,

				endpos =
					position
					+
					Vector(
						0,
						0,
						-GROUND_TRACE_DISTANCE
					),

				filter = {
					self,
					particle
				},

				mask =
					MASK_SOLID,

				collisiongroup =
					BALL_COLLISION_GROUP

			})


		if not trace.Hit
		or trace.StartSolid
		or trace.HitNormal.z <
			GROUND_NORMAL_Z then

			continue

		end


		local velocity =
			particle:GetVelocity()


		if velocity.z < 0 then

			velocity.z =
				velocity.z
				*
				GROUND_VERTICAL_DAMPING

		end


		if math.abs(
			velocity.z
		)
		<
		3 then

			velocity.z =
				0

		end


		particle:SetVelocity(
			velocity
		)

	end

end


------------------------------------------------------------
-- Generic damage disturbance
------------------------------------------------------------

function ENT:ApplyDamageImpact(
	hitPosition,
	damageForce,
	damage
)

	if not self.Particles
	or #self.Particles == 0 then

		return

	end


	local candidates =
		self:GetNearbyParticles(
			hitPosition,
			BULLET_RADIUS
		)


	local forceDirection =
		GetSafeDirection(
			damageForce
		)


	local forceAmount =
		damageForce:Length()


	if forceAmount <=
		0 then

		forceAmount =
			math.max(
				damage or 10,
				10
			)

	else

		forceAmount =
			math.min(
				forceAmount * 0.002,
				80
			)

	end


	local now =
		CurTime()


	for i = 1,
		#candidates do

		local particle =
			candidates[i]


		local delta =
			particle:GetPos()
			-
			hitPosition


		local distanceSqr =
			delta:LengthSqr()


		if distanceSqr
			>
			BULLET_RADIUS_SQR then

			continue

		end


		local distance =
			math.sqrt(
				math.max(
					distanceSqr,
					0.0001
				)
			)


		local radial =
			GetSafeDirection(
				delta
			)


		local falloff =
			1
			-
			(
				distance
				/
				BULLET_RADIUS
			)


		falloff =
			math.Clamp(
				falloff,
				0,
				1
			)


		local impulse =
			(
				radial * 0.75
				+
				forceDirection * 0.25
			)
			*
			falloff
			*
			forceAmount


		impulse =
			ClampVectorLength(
				impulse,
				100
			)


		local phys =
			particle:GetPhysicsObject()


		if IsValid(phys) then

			phys:AddVelocity(
				impulse
			)


			phys:Wake()

		end


		particle.CETS_DisturbedUntil =
			now
			+
			BULLET_DISTURB_TIME

	end

end


------------------------------------------------------------
-- Explosion response
------------------------------------------------------------

function ENT:ApplyExplosionForce(
	origin,
	damage
)

	if not self.Particles
	or #self.Particles == 0 then

		return

	end


	local radius =
		EXPLOSION_RADIUS


	local forceScale =
		math.Clamp(
			(
				damage or 100
			)
			/
			100,
			0.5,
			3
		)


	local candidates =
		ents.FindInSphere(
			origin,
			radius
		)


	local now =
		CurTime()


	for i = 1,
		#candidates do

		local particle =
			candidates[i]


		if not IsValid(particle)
		or not particle.CETS_LiquidBlobParticle
		or particle.CETS_LiquidParent
			~=
			self then

			continue

		end


		local delta =
			particle:GetPos()
			-
			origin


		local distanceSqr =
			delta:LengthSqr()


		if distanceSqr
			>
			radius * radius then

			continue

		end


		local distance =
			math.sqrt(
				math.max(
					distanceSqr,
					0.0001
				)
			)


		local direction =
			GetSafeDirection(
				delta
			)


		local falloff =
			1
			-
			(
				distance
				/
				radius
			)


		falloff =
			math.Clamp(
				falloff,
				0,
				1
			)


		falloff =
			falloff
			*
			falloff


		local velocity =
			direction
			*
			falloff
			*
			forceScale
			*
			EXPLOSION_VELOCITY_SCALE
			*
			math.max(
				damage or 100,
				50
			)


		velocity =
			ClampVectorLength(
				velocity,
				EXPLOSION_MAX_VELOCITY
			)


		local phys =
			particle:GetPhysicsObject()


		if IsValid(phys) then

			phys:AddVelocity(
				velocity
			)


			phys:Wake()

		end


		particle.CETS_DisturbedUntil =
			now
			+
			EXPLOSION_DISTURB_TIME

	end

end


------------------------------------------------------------
-- Damage / explosion detection
------------------------------------------------------------

hook.Add(
	"EntityTakeDamage",
	"CETS_Liquid_DamageInteraction",
	function(
		target,
		dmginfo
	)

		----------------------------------------------------
		-- Direct damage to an actual liquid particle.
		----------------------------------------------------

		if IsValid(target)
		and target.CETS_LiquidBlobParticle
		and target.CETS_LiquidParent then

			local damageType =
				dmginfo:GetDamageType()


			if bit.band(
				damageType,
				DMG_BLAST
			) == 0 then

				target.CETS_LiquidParent:ApplyDamageImpact(
					target:GetPos(),
					dmginfo:GetDamageForce(),
					dmginfo:GetDamage()
				)

			end

		end


		----------------------------------------------------
		-- Explosion detection.
		----------------------------------------------------

		local damageType =
			dmginfo:GetDamageType()


		if bit.band(
			damageType,
			DMG_BLAST
		) == 0 then

			if IsValid(target)
			and target.CETS_LiquidBlobParticle then

				return true

			end


			return

		end


		local position =
			dmginfo:GetDamagePosition()


		if position ==
			vector_origin then

			local inflictor =
				dmginfo:GetInflictor()


			if IsValid(
				inflictor
			) then

				position =
					inflictor:GetPos()

			else

				position =
					target:GetPos()

			end

		end


		local damage =
			dmginfo:GetDamage()


		local now =
			CurTime()


		for _, liquid in ipairs(
			ents.FindByClass(
				"ent_cets_blob"
			)
		) do

			if not IsValid(
				liquid
			) then

				continue

			end


			------------------------------------------------
			-- Prevent one explosion from being applied
			-- repeatedly as it damages several entities.
			------------------------------------------------

			if liquid.LastExplosionPosition
			and
			now
			-
			(
				liquid.LastExplosionTime
				or
				0
			)
			<
			0.08
			and
			liquid.LastExplosionPosition:DistToSqr(
				position
			)
			<
			64 * 64 then

				continue

			end


			liquid.LastExplosionTime =
				now


			liquid.LastExplosionPosition =
				Vector(
					position.x,
					position.y,
					position.z
				)


			liquid:ApplyExplosionForce(
				position,
				damage
			)

		end


		----------------------------------------------------
		-- Explosion damage itself should not damage the
		-- liquid physics entity.
		----------------------------------------------------

		if IsValid(target)
		and target.CETS_LiquidBlobParticle then

			return true

		end

	end
)


------------------------------------------------------------
-- Bullet interaction
--
-- Bullets disturb liquid but do not damage the particle
-- and do not create the normal bullet impact response.
------------------------------------------------------------

hook.Add(
	"EntityFireBullets",
	"CETS_Liquid_BulletInteraction",
	function(
		shooter,
		data
	)

		if not data then
			return
		end


		local oldCallback =
			data.Callback


		data.Callback =
			function(
				attacker,
				trace,
				dmginfo
			)

				local hit =
					trace.Entity


				if IsValid(hit)
				and hit.CETS_LiquidBlobParticle
				and hit.CETS_LiquidParent then

					hit.CETS_LiquidParent:ApplyBulletImpact(
						trace.HitPos,
						trace.HitNormal,
						dmginfo:GetDamageForce()
					)


					return {

						effects =
							false,

						damage =
							false

					}

				end


				if oldCallback then

					return oldCallback(
						attacker,
						trace,
						dmginfo
					)

				end

			end


		return true

	end
)


------------------------------------------------------------
-- Bullet response
------------------------------------------------------------

function ENT:ApplyBulletImpact(
	hitPosition,
	hitNormal,
	damageForce
)

	if not self.Particles
	or #self.Particles == 0 then

		return

	end


	local candidates =
		self:GetNearbyParticles(
			hitPosition,
			BULLET_RADIUS
		)


	local direction =
		-hitNormal


	if direction:LengthSqr()
		<=
		0.0001 then

		direction =
			Vector(
				0,
				0,
				1
			)

	else

		direction:Normalize()

	end


	local now =
		CurTime()


	for i = 1,
		#candidates do

		local particle =
			candidates[i]


		local delta =
			particle:GetPos()
			-
			hitPosition


		local distanceSqr =
			delta:LengthSqr()


		if distanceSqr
			>
			BULLET_RADIUS_SQR then

			continue

		end


		local distance =
			math.sqrt(
				math.max(
					distanceSqr,
					0.0001
				)
			)


		local radial =
			GetSafeDirection(
				delta
			)


		local falloff =
			1
			-
			(
				distance
				/
				BULLET_RADIUS
			)


		falloff =
			math.Clamp(
				falloff,
				0,
				1
			)


		local impact =
			(
				radial * 0.70
				+
				direction * 0.30
			)
			*
			falloff
			*
			BULLET_VELOCITY


		if damageForce
		and damageForce:LengthSqr()
			>
			0 then

			local bulletForce =
				damageForce:Length()


			impact =
				impact
				+
				direction
				*
				math.min(
					bulletForce * 0.002,
					35
				)

		end


		impact =
			ClampVectorLength(
				impact,
				BULLET_MAX_VELOCITY
			)


		local phys =
			particle:GetPhysicsObject()


		if IsValid(phys) then

			phys:AddVelocity(
				impact
			)


			phys:Wake()

		end


		particle.CETS_DisturbedUntil =
			now
			+
			BULLET_DISTURB_TIME

	end

end


------------------------------------------------------------
-- Spawn
------------------------------------------------------------

function ENT:SpawnFunction(
	ply,
	tr,
	className
)

	if not tr.Hit then
		return
	end


	local ent =
		ents.Create(
			className
		)


	if not IsValid(ent) then
		return
	end


	local spawnHeight =
		PARTICLE_SPACING
		*
		3.4


	ent:SetPos(
		tr.HitPos
		+
		tr.HitNormal
		*
		spawnHeight
	)


	ent:SetAngles(
		Angle(
			0,
			0,
			0
		)
	)


	ent:Spawn()
	ent:Activate()


	return ent

end


------------------------------------------------------------
-- Always transmit controller
------------------------------------------------------------

function ENT:UpdateTransmitState()

	return TRANSMIT_ALWAYS

end


------------------------------------------------------------
-- Initialize
------------------------------------------------------------

function ENT:Initialize()

	self:SetModel(
		"models/hunter/plates/plate1x1.mdl"
	)


	self:SetNoDraw(true)

	self:DrawShadow(false)


	self:SetSolid(
		SOLID_NONE
	)


	self:SetMoveType(
		MOVETYPE_NONE
	)


	self.Particles =
		{}


	self.SpawnQueue =
		nil


	self.SpatialHash =
		{}


	self.NextLiquidUpdate =
		0


	self.NextGroundUpdate =
		0


	self.NextEntityUpdate =
		0


	self.LastExplosionTime =
		0


	self.LastExplosionPosition =
		nil


	self:BuildSpawnQueue()

end


------------------------------------------------------------
-- Think
------------------------------------------------------------

function ENT:Think()

	local now =
		CurTime()


	--------------------------------------------------------
	-- Construct the initial liquid.
	--------------------------------------------------------

	self:ProcessSpawnQueue()


	self:RemoveInvalidParticles()


	--------------------------------------------------------
	-- Local liquid simulation.
	--------------------------------------------------------

	if now >=
		self.NextLiquidUpdate then

		self.NextLiquidUpdate =
			now
			+
			LIQUID_UPDATE_INTERVAL


		self:SimulateLiquid(
			LIQUID_UPDATE_INTERVAL
		)

	end


	--------------------------------------------------------
	-- Entity interaction.
	--------------------------------------------------------

	if now >=
		self.NextEntityUpdate then

		self.NextEntityUpdate =
			now
			+
			ENTITY_UPDATE_INTERVAL


		self:ApplyEntityDisturbance()

	end


	--------------------------------------------------------
	-- Ground settling.
	--------------------------------------------------------

	if now >=
		self.NextGroundUpdate then

		self.NextGroundUpdate =
			now
			+
			GROUND_UPDATE_INTERVAL


		self:ApplyGroundDamping()

	end


	self:NextThink(
		now
	)


	return true

end


------------------------------------------------------------
-- Cleanup
------------------------------------------------------------

function ENT:Cleanup()

	if self.Particles then

		for i = #self.Particles,
			1,
			-1 do

			local particle =
				self.Particles[i]


			if IsValid(
				particle
			) then

				particle.CETS_LiquidParent =
					nil


				particle:Remove()

			end

		end

	end


	self.Particles =
		nil


	self.SpawnQueue =
		nil


	self.SpatialHash =
		nil

end


------------------------------------------------------------
-- Remove
------------------------------------------------------------

function ENT:OnRemove()

	self:Cleanup()

end