include("shared.lua")


------------------------------------------------------------
-- Configuration
------------------------------------------------------------

local MESH_SEGMENTS =
	12

local MESH_RINGS =
	6

local VISUAL_RADIUS =
	7.4


------------------------------------------------------------
-- Material
------------------------------------------------------------

local LiquidMaterial =
	CreateMaterial(
		"CETS_Liquid_Blob_Material",
		"VertexLitGeneric",
		{
			["$basetexture"] =
				"models/debug/debugwhite",

			["$model"] =
				"1",

			["$vertexcolor"] =
				"1",

			["$vertexalpha"] =
				"1",

			["$halflambert"] =
				"1",

			["$nocull"] =
				"1"
		}
	)


------------------------------------------------------------
-- Mesh
------------------------------------------------------------

local BlobMesh


local function BuildBlobMesh()

	if BlobMesh then
		return
	end


	local vertices =
		{}


	local function GetVertex(
		ring,
		segment
	)

		local theta =
			math.pi
			*
			(
				ring
				/
				MESH_RINGS
			)


		local phi =
			math.pi
			*
			2
			*
			(
				segment
				/
				MESH_SEGMENTS
			)


		local sinTheta =
			math.sin(theta)

		local cosTheta =
			math.cos(theta)

		local sinPhi =
			math.sin(phi)

		local cosPhi =
			math.cos(phi)


		local x =
			cosPhi
			*
			sinTheta

		local y =
			sinPhi
			*
			sinTheta

		local z =
			cosTheta


		local position =
			Vector(
				x,
				y,
				z
			)


		local normal =
			Vector(
				x,
				y,
				z
			)


		if normal:LengthSqr()
			>
			0.0001 then

			normal:Normalize()

		end


		return
			position,
			normal

	end


	for ring = 0,
		MESH_RINGS - 1 do

		for segment = 0,
			MESH_SEGMENTS - 1 do

			local nextSegment =
				(
					segment
					+
					1
				)
				%
				MESH_SEGMENTS


			local p1,
				n1 =
				GetVertex(
					ring,
					segment
				)

			local p2,
				n2 =
				GetVertex(
					ring,
					nextSegment
				)

			local p3,
				n3 =
				GetVertex(
					ring + 1,
					nextSegment
				)

			local p4,
				n4 =
				GetVertex(
					ring + 1,
					segment
				)


			local u1 =
				segment
				/
				MESH_SEGMENTS

			local u2 =
				nextSegment
				/
				MESH_SEGMENTS

			local v1 =
				ring
				/
				MESH_RINGS

			local v2 =
				(
					ring + 1
				)
				/
				MESH_RINGS


			vertices[
				#vertices + 1
			] = {

				pos =
					p1,

				normal =
					n1,

				u =
					u1,

				v =
					v1

			}


			vertices[
				#vertices + 1
			] = {

				pos =
					p2,

				normal =
					n2,

				u =
					u2,

				v =
					v1

			}


			vertices[
				#vertices + 1
			] = {

				pos =
					p3,

				normal =
					n3,

				u =
					u2,

				v =
					v2

			}


			vertices[
				#vertices + 1
			] = {

				pos =
					p1,

				normal =
					n1,

				u =
					u1,

				v =
					v1

			}


			vertices[
				#vertices + 1
			] = {

				pos =
					p3,

				normal =
					n3,

				u =
					u2,

				v =
					v2

			}


			vertices[
				#vertices + 1
			] = {

				pos =
					p4,

				normal =
					n4,

				u =
					u1,

				v =
					v2

			}

		end

	end


	BlobMesh =
		Mesh()


	if BlobMesh then

		BlobMesh:BuildFromTriangles(
			vertices
		)

	end

end


BuildBlobMesh()


------------------------------------------------------------
-- Initialize
------------------------------------------------------------

function ENT:Initialize()

	--------------------------------------------------------
	-- Do NOT call SetNoDraw here.
	--------------------------------------------------------

	self:DrawShadow(false)


	self:SetRenderBounds(
		Vector(
			-16,
			-16,
			-16
		),
		Vector(
			16,
			16,
			16
		)
	)

end


------------------------------------------------------------
-- Draw
------------------------------------------------------------

function ENT:Draw()

	if not BlobMesh then

		BuildBlobMesh()

	end


	if not BlobMesh then
		return
	end


	if not IsValid(
		self
	) then

		return

	end


	local position =
		self:GetPos()


	--------------------------------------------------------
	-- Slight velocity-based squashing.
	--------------------------------------------------------

	local velocity =
		self:GetVelocity()


	local speed =
		velocity:Length()


	local speedFraction =
		math.Clamp(
			speed / 350,
			0,
			1
		)


	local radiusXY =
		VISUAL_RADIUS
		*
		(
			1.0
			+
			speedFraction
			*
			0.12
		)


	local radiusZ =
		VISUAL_RADIUS
		*
		(
			1.0
			-
			speedFraction
			*
			0.08
		)


	local matrix =
		Matrix()


	matrix:SetTranslation(
		position
	)


	matrix:Scale(
		Vector(
			radiusXY,
			radiusXY,
			radiusZ
		)
	)


	--------------------------------------------------------
	-- Render custom liquid mesh.
	--
	-- We deliberately do NOT call DrawModel().
	--------------------------------------------------------

	render.SetMaterial(
		LiquidMaterial
	)

	render.SetColorModulation(
		0.03,
		0.34,
		1.0
	)

	render.SetBlend(
		0.96
	)


	cam.PushModelMatrix(
		matrix,
		true
	)


	BlobMesh:Draw()


	cam.PopModelMatrix()


	render.SetBlend(
		1
	)

	render.SetColorModulation(
		1,
		1,
		1
	)

end