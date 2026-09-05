AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")


------------------------------------------------------------
-- Physics
------------------------------------------------------------

local PHYSICS_RADIUS = 5.0

local PHYSICS_MATERIAL =
	"rubber"

local COLLISION_GROUP =
	COLLISION_GROUP_INTERACTIVE_DEBRIS

local PARTICLE_MASS =
	0.55

local LINEAR_DAMPING =
	0.35

local ANGULAR_DAMPING =
	1.0

local BOUNCE =
	0.12

local MAX_SPEED =
	800


------------------------------------------------------------
-- Initialize
------------------------------------------------------------

function ENT:Initialize()

	self:SetModel(
		"models/hunter/misc/sphere025x025.mdl"
	)

	--------------------------------------------------------
	-- IMPORTANT:
	--
	-- Do NOT call SetNoDraw here.
	-- The client has its own Draw() implementation.
	--------------------------------------------------------

	self:DrawShadow(false)


	--------------------------------------------------------
	-- Custom collision filtering.
	--------------------------------------------------------

	self.CETS_LiquidBlobParticle =
		true

	self.CETS_LiquidParent =
		self.CETS_LiquidParent


	self:SetCustomCollisionCheck(
		true
	)

	self:SetCollisionGroup(
		COLLISION_GROUP
	)

	self:CollisionRulesChanged()


	--------------------------------------------------------
	-- Physics.
	--------------------------------------------------------

	self:PhysicsInitSphere(
		PHYSICS_RADIUS,
		PHYSICS_MATERIAL
	)

	self:SetSolid(
		SOLID_VPHYSICS
	)

	self:SetMoveType(
		MOVETYPE_VPHYSICS
	)

	self:SetCollisionBounds(
		Vector(
			-PHYSICS_RADIUS,
			-PHYSICS_RADIUS,
			-PHYSICS_RADIUS
		),
		Vector(
			PHYSICS_RADIUS,
			PHYSICS_RADIUS,
			PHYSICS_RADIUS
		)
	)


	local phys =
		self:GetPhysicsObject()


	if IsValid(phys) then

		phys:SetMass(
			PARTICLE_MASS
		)

		phys:SetDamping(
			LINEAR_DAMPING,
			ANGULAR_DAMPING
		)

		phys:EnableGravity(
			true
		)

		phys:EnableDrag(
			true
		)

		phys:Wake()

	end

end


------------------------------------------------------------
-- Collision response
------------------------------------------------------------

function ENT:PhysicsCollide(
	data,
	phys
)

	if not IsValid(phys) then
		return
	end


	local velocity =
		phys:GetVelocity()

	local normal =
		data.HitNormal


	if normal:LengthSqr()
		>
		0.0001 then

		normal:Normalize()


		local normalVelocity =
			velocity:Dot(
				normal
			)


		if normalVelocity < 0 then

			------------------------------------------------
			-- Remove the incoming component.
			------------------------------------------------

			velocity =
				velocity
				-
				normal
				*
				normalVelocity


			------------------------------------------------
			-- Add only a very small bounce.
			------------------------------------------------

			velocity =
				velocity
				+
				normal
				*
				(
					-normalVelocity
					*
					BOUNCE
				)

		end

	end


	local speed =
		velocity:Length()


	if speed >
		MAX_SPEED then

		velocity =
			velocity
			*
			(
				MAX_SPEED
				/
				speed
			)

	end


	phys:SetVelocity(
		velocity
	)

end


------------------------------------------------------------
-- Cleanup
------------------------------------------------------------

function ENT:OnRemove()

	self.CETS_LiquidBlob =
		nil

	self.CETS_LiquidBlobParticle =
		nil

	self.CETS_LiquidParent =
		nil

end