--!strict

-----------------------------------------------------------------------
--                         HitboxClass v1.2.0                        --
-----------------------------------------------------------------------
-- License:                                                          --
--   Licensed under the MIT license.                                 --
--                                                                   --
-- Author:                                                           --
--   RedTrio (VulkanAPI) - January 12, 2024 - Created the module.    --
--                                                                   --
-- Uses Signal by sleitnick.                                         --
-----------------------------------------------------------------------

-- Let me know if you come across any bugs or errors!

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")

local moduleSettings = script.Settings

-- Initial error checking

assert(
	moduleSettings:FindFirstChild("AliveFolder"),
	"No Alive Folder setting found in HitboxClass settings! Make an object value and name it 'AliveFolder' and parent it there!"
)

local aliveFolderSetting = moduleSettings["AliveFolder"]
local aliveFolder = aliveFolderSetting.Value

assert(
	moduleSettings:FindFirstChild("ProjectileFolder"),
	"No Projectile Folder setting found in HitboxClass settings! Make an object value and name it 'ProjectileFolder' and parent it there!"
)

local projectileFolderSetting = moduleSettings["ProjectileFolder"]
local projectileFolder = projectileFolderSetting.Value

local velocityConstant = moduleSettings:FindFirstChild("VelocityPredictionConstant")

if not velocityConstant then
	warn("Velocity Constant Setting has been deleted! 6 will be used as a default. (HitboxClass)")
end

-- the folders don't have to be set yet, they can be set later with Hitbox.SetAliveFolder and Hitbox.SetProjectileFolder
if aliveFolder then
	assert(aliveFolder:IsDescendantOf(workspace), "The alive folder must be a descendant of workspace! (HitboxClass)")
end

if projectileFolder then
	assert(
		projectileFolder:IsDescendantOf(workspace),
		"The projectile folder must be a descendant of workspace! (HitboxClass)"
	)
end

-- now we initialize the class
local Types = require(script.Types)

export type Hitbox = Types.Hitbox
export type HitboxParams = Types.HitboxParams
export type DotProductRequirement = Types.DotProductRequirement

local signal = require(script.Parent.Signal)
local Timer = require(script.Timer)

local overlapParamsHumanoid = OverlapParams.new()
overlapParamsHumanoid.FilterDescendantsInstances = { aliveFolder }
overlapParamsHumanoid.FilterType = Enum.RaycastFilterType.Include

local overlapParamsObject = OverlapParams.new()
overlapParamsObject.FilterDescendantsInstances = { projectileFolder }
overlapParamsObject.FilterType = Enum.RaycastFilterType.Exclude

-- keep the folders up to date if the settings are changed (this is also how the client gets the folders set by the server)
aliveFolderSetting:GetPropertyChangedSignal("Value"):Connect(function()
	aliveFolder = aliveFolderSetting.Value
	overlapParamsHumanoid.FilterDescendantsInstances = { aliveFolder }
end)

projectileFolderSetting:GetPropertyChangedSignal("Value"):Connect(function()
	projectileFolder = projectileFolderSetting.Value
	overlapParamsObject.FilterDescendantsInstances = { projectileFolder }
end)

local CFrameZero = CFrame.new(Vector3.zero)

local RunService = game:GetService("RunService")

local HitboxRemote = nil

local function SetupClients()
	local newRemoteEvent = Instance.new("RemoteEvent")
	newRemoteEvent.Name = "HitboxClassRemote"
	newRemoteEvent.Parent = ReplicatedStorage
	HitboxRemote = newRemoteEvent

	local newLocalScript = script.HitboxClassLocal:Clone()

	local newReference = Instance.new("ObjectValue")
	newReference.Value = script
	newReference.Name = "HitboxClass Module"
	newReference.Parent = newLocalScript

	newLocalScript.Parent = StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts")

	task.spawn(function()
		for i, Player: Player in pairs(Players:GetChildren()) do
			local ScreenGUI = Instance.new("ScreenGui")
			ScreenGUI.Name = "HitboxClassContainer"
			ScreenGUI.ResetOnSpawn = false

			local newScriptClone = newLocalScript:Clone()
			newScriptClone.Parent = ScreenGUI
			newScriptClone.Enabled = true

			ScreenGUI.Parent = Player:WaitForChild("PlayerGui")
		end
	end)

	newLocalScript.Enabled = true
end

if RunService:IsServer() then
	SetupClients()
else
	HitboxRemote = ReplicatedStorage:FindFirstChild("HitboxClassRemote")
	if not HitboxRemote then
		warn("HitboxClass must be initialized on the server before using it on the client! Waiting for RemoteEvent!")
		HitboxRemote = ReplicatedStorage:WaitForChild("HitboxClassRemote")
	end
end

local Hitbox = {} :: Types.Hitbox

local HitboxCache = {} :: { Types.Hitbox }

local function DeepCopyTable(tableToCopy: {})
	local copy = {}

	for key, value in pairs(tableToCopy) do
		if type(value) == "table" then
			copy[key] = DeepCopyTable(value)
		else
			copy[key] = value
		end
	end

	return copy
end

function Hitbox.new(HitboxParams: Types.HitboxParams)
	assert(
		aliveFolder ~= nil,
		"Set the alive characters folder in the HitboxClass settings or with Hitbox.SetAliveFolder!"
	)
	assert(
		projectileFolder ~= nil,
		"Set the projectiles folder in the HitboxClass settings or with Hitbox.SetProjectileFolder!"
	)

	local self = (setmetatable({}, { __index = Hitbox }) :: unknown) :: Types.Hitbox

	self.TaggedChars = {}
	self.TaggedObjects = {}
	self.SendingChars = {}
	self.SendingObjects = {}
	self.DelayThreads = {}

	if RunService:IsClient() and HitboxParams._Tick then
		self.TickVal = HitboxParams._Tick
	else
		self.TickVal = workspace:GetServerTimeNow()
	end

	if HitboxParams.ID then
		self.ID = HitboxParams.ID
	end

	self.Blacklist = HitboxParams.Blacklist

	self.HitSomeone = signal.new()
	self.HitObject = signal.new()

	self.DebugMode = HitboxParams.Debug or false

	self.Lifetime = HitboxParams.Debris or 0

	self.LookingFor = HitboxParams.LookingFor or "Humanoid"

	if HitboxParams.UseClient then
		self.Client = HitboxParams.UseClient

		-- copy the params
		local newDictionary = DeepCopyTable(HitboxParams) :: Types.HitboxParams

		-- get rid of the UseClient parameter
		newDictionary.UseClient = nil

		-- set the tickval to be the same as the hitbox's tickval
		newDictionary._Tick = self.TickVal

		-- fire to the client and wait for a response to ensure they got their hitbox set up
		local readyToGo = false

		local tempWaitEvent: RBXScriptConnection

		tempWaitEvent = HitboxRemote.OnServerEvent:Connect(function(player, tickVal)
			if player ~= self.Client then
				return
			end
			if tickVal ~= self.TickVal then
				return
			end

			readyToGo = true
		end)

		assert(self.Client)

		local startWaitTime = workspace:GetServerTimeNow()

		HitboxRemote:FireClient(self.Client, "New", newDictionary)

		repeat
			task.wait()
		until readyToGo or workspace:GetServerTimeNow() - startWaitTime >= 1.5

		tempWaitEvent:Disconnect()

		if not readyToGo then
			return self, false
		end
	else
		self.Position = HitboxParams.InitialPosition or CFrameZero
		self.DebounceTime = HitboxParams.DebounceTime or 0
		self.VelocityPrediction = HitboxParams.VelocityPrediction

		if self.VelocityPrediction == nil then
			self.VelocityPrediction = true
		end

		self.DotProductRequirement = HitboxParams.DotProductRequirement

		self.DebugMode = HitboxParams.Debug or false

		if typeof(HitboxParams.SizeOrPart) == "Vector3" then
			self.SpatialOption = HitboxParams.SpatialOption or "InBox"

			assert(
				self.SpatialOption ~= "InRadius",
				"You can't use InRadius as the SpatialOption if a Vector3 is passed! Only InPart and InBox! (HitboxClass)"
			)

			self.Mode = "Part"
			self.Size = HitboxParams.SizeOrPart

			if self.SpatialOption == "InPart" then
				self:_GeneratePart()
			end
		elseif type(HitboxParams.SizeOrPart) == "number" then
			self.SpatialOption = HitboxParams.SpatialOption or "Magnitude"

			if self.SpatialOption == "InRadius" then
				self.Mode = "Part"
				self.Size = HitboxParams.SizeOrPart
			elseif self.SpatialOption == "InPart" then
				self.Mode = "Part"
				self.Size = Vector3.new(HitboxParams.SizeOrPart, HitboxParams.SizeOrPart, HitboxParams.SizeOrPart)
				self:_GeneratePart()
			elseif self.SpatialOption == "InBox" then
				self.Mode = "Part"
				self.Size = Vector3.new(HitboxParams.SizeOrPart, HitboxParams.SizeOrPart, HitboxParams.SizeOrPart)
			else
				self.Mode = "Magnitude"
				self.Size = HitboxParams.SizeOrPart

				assert(
					self.LookingFor == "Humanoid",
					"Magnitude hitboxes can only look for Humanoids! Use InRadius as the SpatialOption to look for objects! (HitboxClass)"
				)
			end
		else
			self.Mode = "Part"
			self.Size = HitboxParams.SizeOrPart.Size
			self.Part = HitboxParams.SizeOrPart:Clone()

			self.SpatialOption = "InPart"

			assert(self.Part, "No part provided?")

			assert(self.Part and self.Part:IsA("Part"))

			self.Part.Color = Color3.new(1, 0, 0)
			self.Part.Name = "Hitbox" .. self.TickVal
		end

		if self.DebugMode then
			self:SetDebug(true)
		end
	end

	table.insert(HitboxCache, self)

	return self, true
end

function Hitbox:ClearTaggedChars()
	if self.Client then
		HitboxRemote:FireClient(self.Client, "ClrTag", { _Tick = self.TickVal })
	else
		table.clear(self.TaggedChars)
	end
end

function Hitbox:Start()
	-- if the lifetime is greater than 0
	if self.Lifetime > 0 then
		-- check to see if there's a timer, if there is one, then start it
		if not self.Timer then
			-- make a new timer
			self.Timer = Timer.new(0.1, function()
				self.Lifetime -= 0.1
				if self.Lifetime <= 0 then
					self:Destroy()
				end
			end)
		else
			self.Timer:On()
		end
	end

	if self.Client then
		self:_ConnectClient()

		HitboxRemote:FireClient(self.Client, "Start", { _Tick = self.TickVal })
	else
		if (self.SpatialOption == "InPart") or (self.Part and self.DebugMode == true) then
			self.Part.Parent = projectileFolder
		end

		self.RunServiceConnection = RunService.Heartbeat:Connect(function(DT)
			self:_Step()
		end)
	end
end

function Hitbox:Stop()
	if self.Timer then
		self.Timer:Off()
	end

	if self.Client then
		if self.ClientConnection then
			self.ClientConnection:Disconnect()
			self.ClientConnection = nil
		end
		HitboxRemote:FireClient(self.Client, "Stop", { _Tick = self.TickVal })
	else
		if self.Part then
			self.Part:Remove()
		end

		if self.RunServiceConnection then
			self.RunServiceConnection:Disconnect()
			self.RunServiceConnection = nil
		end
	end
end

function Hitbox:Check()
	if self.Client then
		self:_ConnectClient()

		-- the client does the check and sends back what it hit, so the results come through the signals instead
		HitboxRemote:FireClient(self.Client, "Check", { _Tick = self.TickVal })
		return nil
	end

	-- if the hitbox is already running then everything's already set up, so just step it
	if self.RunServiceConnection then
		return self:_Step()
	end

	if (self.SpatialOption == "InPart") or (self.Part and self.DebugMode == true) then
		self.Part.Parent = projectileFolder
	end

	local hits = self:_Step()

	if self.Part then
		if self.DebugMode then
			-- leave the part up for a bit so you can actually see where it checked
			local checkedPart = self.Part

			task.delay(0.1, function()
				if checkedPart.Parent and not self.RunServiceConnection then
					checkedPart.Parent = nil
				end
			end)
		else
			self.Part.Parent = nil
		end
	end

	return hits
end

function Hitbox:SetPosition(newPosition: CFrame)
	if self.Client then
		HitboxRemote:FireClient(self.Client, "PosCh", { _Tick = self.TickVal, Position = newPosition })
	end

	local constant

	if velocityConstant then
		constant = velocityConstant.Value or 6
	else
		constant = 6
	end

	if RunService:IsServer() and self.PartWeld and self.VelocityPrediction then
		local velocityVector = newPosition:VectorToObjectSpace(self.PartWeld.AssemblyLinearVelocity) / constant
		newPosition = newPosition * CFrame.new(velocityVector)
	end

	self.Position = newPosition

	if self.Part then
		self.Part.CFrame = newPosition
	end
end

function Hitbox:WeldTo(PartToWeldTo: BasePart, OffsetCFrame: CFrame?)
	if self.Client then
		HitboxRemote:FireClient(
			self.Client,
			"Weld",
			{ _Tick = self.TickVal, WeldTo = PartToWeldTo, Offset = OffsetCFrame }
		)
	end

	self.PartWeld = PartToWeldTo
	self.PartWeldOffset = OffsetCFrame
end

function Hitbox:Unweld()
	if self.Client then
		HitboxRemote:FireClient(self.Client, "Unweld", { _Tick = self.TickVal })
	end

	self.PartWeld = nil
	self.PartWeldOffset = nil
end

function Hitbox:ChangeWeldOffset(OffsetCFrame: CFrame)
	if self.Client then
		HitboxRemote:FireClient(self.Client, "WeldOfs", { _Tick = self.TickVal, Offset = OffsetCFrame })
	end

	self.PartWeldOffset = OffsetCFrame
end

function Hitbox:SetVelocityPrediction(state: boolean)
	self.VelocityPrediction = state
end

function Hitbox:SetDebug(state: boolean)
	self.DebugMode = state

	if self.Client then
		HitboxRemote:FireClient(self.Client, "Dbg", { _Tick = self.TickVal, Debug = state })
		return
	end

	if self.DebugMode then
		if not self.Part then
			self:_GeneratePart()
			assert(self.Part, "Part wasn't generated after the GeneratePart method?")

			if self.RunServiceConnection then
				self.Part.Parent = projectileFolder
			end
		else
			self.Part.Transparency = 0.45

			if self.SpatialOption ~= "InPart" and self.RunServiceConnection then
				self.Part.Parent = projectileFolder
			end
		end
	else
		if self.Part then
			if self.SpatialOption ~= "InPart" then
				self.Part.Parent = nil
			end

			self.Part.Transparency = 1
		end
	end
end

function Hitbox.ClearHitboxesWithID(ID: number | string)
	if RunService:IsClient() then
		return
	end

	-- go through the cache and destroy any hitboxes with the ID provided
	for i = #HitboxCache, 1, -1 do
		local checkingHitbox = HitboxCache[i]

		if checkingHitbox.ID and checkingHitbox.ID == ID then
			pcall(function()
				checkingHitbox:Destroy()
			end)
		end
	end
end

function Hitbox.ClearClientHitboxes(client: Player)
	if RunService:IsClient() then
		return
	end

	-- go through the cache and destroy any hitboxes associated with the client
	for i = #HitboxCache, 1, -1 do
		local checkingHitbox = HitboxCache[i]

		if checkingHitbox.Client and checkingHitbox.Client == client then
			pcall(function()
				checkingHitbox:Destroy()
			end)
		end
	end

	-- make sure everything is cleared on the client
	HitboxRemote:FireClient(client, "Clr")
end

function Hitbox.GetHitboxCache()
	return HitboxCache
end

function Hitbox.SetAliveFolder(newFolder: Instance)
	assert(newFolder:IsDescendantOf(workspace), "The alive folder must be a descendant of workspace! (HitboxClass)")

	-- update it right away since the changed signal can be deferred
	aliveFolder = newFolder
	overlapParamsHumanoid.FilterDescendantsInstances = { aliveFolder }

	-- update the setting too so it replicates to the clients
	aliveFolderSetting.Value = newFolder
end

function Hitbox.SetProjectileFolder(newFolder: Instance)
	assert(
		newFolder:IsDescendantOf(workspace),
		"The projectile folder must be a descendant of workspace! (HitboxClass)"
	)

	-- update it right away since the changed signal can be deferred
	projectileFolder = newFolder
	overlapParamsObject.FilterDescendantsInstances = { projectileFolder }

	-- update the setting too so it replicates to the clients
	projectileFolderSetting.Value = newFolder
end

function Hitbox.SetVelocityPredictionConstant(constant: number)
	-- remake the setting if it was deleted
	if not velocityConstant then
		velocityConstant = Instance.new("NumberValue")
		velocityConstant.Name = "VelocityPredictionConstant"
		velocityConstant.Parent = moduleSettings
	end

	velocityConstant.Value = constant
end

function Hitbox:_ConnectClient()
	-- already listening to the client, no need to do it again
	if self.ClientConnection then
		return
	end

	self.ClientConnection = HitboxRemote.OnServerEvent:Connect(function(player: Player, tickVal: number, HitTable)
		if HitTable == nil then
			return
		end
		if player ~= self.Client then
			return
		end
		if tickVal ~= self.TickVal then
			return
		end
		if type(HitTable) ~= "table" then
			return
		end

		if self.LookingFor == "Humanoid" then
			-- remove all HitTable that isn't a model, isn't a descendant of the alive folder, or doesn't have a humanoid, or is nil entirely
			for i = #HitTable, 1, -1 do
				if
					not HitTable[i]
					or (typeof(HitTable[i]) ~= "Instance")
					or (not HitTable[i]:IsDescendantOf(aliveFolder))
					or (not HitTable[i]:FindFirstChildOfClass("Humanoid"))
					or (not HitTable[i]:IsA("Model"))
				then
					table.remove(HitTable, i)
					continue
				end

				-- if everything else is valid, double check to make sure the model passed in is not in the hitbox's blacklist
				if self.Blacklist then
					if table.find(self.Blacklist, HitTable[i]) then
						table.remove(HitTable, i)
					end
				end
			end

			-- if after everything is said and done there's nothing left, don't fire the signal
			if #HitTable <= 0 then
				return
			end

			self.HitSomeone:Fire(HitTable)
		elseif self.LookingFor == "Object" then
			for i = #HitTable, 1, -1 do
				if not HitTable[i] or (typeof(HitTable[i]) ~= "Instance") or (not HitTable[i]:IsA("BasePart")) then
					table.remove(HitTable, i)
					continue
				end

				-- if everything else is valid, double check to make sure the model passed in is not in the hitbox's blacklist
				if self.Blacklist then
					for _, blacklisted in pairs(self.Blacklist) do
						if HitTable[i] == blacklisted or HitTable[i]:IsDescendantOf(blacklisted) then
							table.remove(HitTable, i)
							break
						end
					end
				end
			end

			-- if after everything is said and done there's nothing left, don't fire the signal
			if #HitTable <= 0 then
				return
			end

			self.HitObject:Fire(HitTable)
		end
	end)
end

function Hitbox:_Step()
	if self.PartWeld then
		self:SetPosition(self.PartWeld.CFrame * (self.PartWeldOffset or CFrameZero))
	end

	self:_Query()

	if self.LookingFor == "Humanoid" then
		return self:_SiftThroughSendingCharsAndFire()
	else
		return self:_SiftThroughSendingObjectsAndFire()
	end
end

function Hitbox:_Query()
	if self.Mode == "Magnitude" then
		assert(
			typeof(self.Size) == "number",
			"Magnitude hitbox wasn't given a number! Type given: " .. typeof(self.Size)
		)

		-- go through the alive folder
		for i, Character: Instance in pairs(aliveFolder:GetChildren()) do
			-- check to see if it's a model with a primary part that also has a humanoid
			if
				Character:IsA("Model")
				and Character.PrimaryPart ~= nil
				and Character:FindFirstChildOfClass("Humanoid")
			then
				local magnitude = (self.Position.Position - Character.PrimaryPart.Position).Magnitude

				-- if they're greater than the distance of the hitbox, skip them
				if magnitude > self.Size then
					continue
				end

				-- if they're in the blacklist, skip them
				if self.Blacklist then
					if table.find(self.Blacklist, Character) then
						continue
					end
				end

				-- check the dot product if one is given
				if not self:_PassesDotProduct(Character.PrimaryPart.CFrame.Position) then
					continue
				end

				-- if they've already been tagged, skip them
				if self.TaggedChars[Character] then
					continue
				end

				if magnitude <= self.Size then
					table.insert(self.SendingChars, Character)
				end
			end
		end
	else
		local results

		if self.SpatialOption == "InBox" then
			if self.LookingFor == "Humanoid" then
				results = workspace:GetPartBoundsInBox(self.Position, self.Size, overlapParamsHumanoid)
			else
				results = workspace:GetPartBoundsInBox(self.Position, self.Size, overlapParamsObject)
			end
		elseif self.SpatialOption == "InRadius" then
			if self.LookingFor == "Humanoid" then
				results = workspace:GetPartBoundsInRadius(self.Position.Position, self.Size, overlapParamsHumanoid)
			else
				results = workspace:GetPartBoundsInRadius(self.Position.Position, self.Size, overlapParamsObject)
			end
		else
			if self.LookingFor == "Humanoid" then
				results = workspace:GetPartsInPart(self.Part, overlapParamsHumanoid)
			else
				results = workspace:GetPartsInPart(self.Part, overlapParamsObject)
			end
		end

		for i, Part: BasePart in pairs(results) do
			if not Part.Parent then
				continue
			end

			if self.LookingFor == "Humanoid" then
				local Character = Part.Parent

				if not Character:IsA("Model") then
					continue
				end

				if Character.PrimaryPart == nil or not Character:FindFirstChildOfClass("Humanoid") then
					continue
				end

				if self.Blacklist then
					if table.find(self.Blacklist, Character) then
						continue
					end
				end

				if
					not table.find(self.SendingChars, Character)
					and not self.TaggedChars[Character]
					and self:_PassesDotProduct(Character.PrimaryPart.CFrame.Position)
				then
					table.insert(self.SendingChars, Character)
				end
			else
				local BlacklistFound = false

				if self.Blacklist then
					-- go through the blacklist and flip the bool and break if the part is found
					-- in the blacklist
					for i = #self.Blacklist, 1, -1 do
						local checkingPart = self.Blacklist[i]

						if Part == checkingPart or Part:IsDescendantOf(checkingPart) then
							BlacklistFound = true
							break
						end
					end
				end

				if
					not table.find(self.SendingObjects, Part)
					and not self.TaggedObjects[Part]
					and not BlacklistFound
					and self:_PassesDotProduct(Part.Position)
				then
					table.insert(self.SendingObjects, Part)
				end
			end
		end
	end
end

function Hitbox:_PassesDotProduct(TargetPosition: Vector3)
	-- no dot product given, so everything passes
	if not self.DotProductRequirement then
		return true
	end

	local VectorToCompare = (TargetPosition - self.DotProductRequirement.PartForVector.CFrame.Position).Unit

	local VectorOfUser: Vector3

	-- changed to a long if statement block cause strict mode was throwing a hissy fit
	-- "attempting a dynamic property access on type 'CFrame' is unsafe and may cause exceptions at runtime"

	if self.DotProductRequirement.VectorType then
		if self.DotProductRequirement.VectorType == "LookVector" then
			VectorOfUser = self.DotProductRequirement.PartForVector.CFrame.LookVector
		elseif self.DotProductRequirement.VectorType == "UpVector" then
			VectorOfUser = self.DotProductRequirement.PartForVector.CFrame.UpVector
		elseif self.DotProductRequirement.VectorType == "RightVector" then
			VectorOfUser = self.DotProductRequirement.PartForVector.CFrame.RightVector
		end
	else
		VectorOfUser = self.DotProductRequirement.PartForVector.CFrame.LookVector
	end

	if self.DotProductRequirement.Negative then
		VectorOfUser *= -1
	end

	return VectorToCompare:Dot(VectorOfUser) >= self.DotProductRequirement.DotProduct
end

function Hitbox:_SiftThroughSendingObjectsAndFire()
	if #self.SendingObjects <= 0 then
		return {}
	end

	local shallowObjectTable = {}

	for i, Object in pairs(self.SendingObjects) do
		table.insert(shallowObjectTable, Object)

		self.TaggedObjects[Object] = true

		if self.DebounceTime > 0 then
			local newThread = task.delay(self.DebounceTime, function()
				self.TaggedObjects[Object] = nil
			end)

			table.insert(self.DelayThreads, newThread)
		end
	end

	if #shallowObjectTable > 0 then
		if RunService:IsClient() then
			HitboxRemote:FireServer(self.TickVal, shallowObjectTable)
		end

		self.HitObject:Fire(shallowObjectTable)
	end

	if self.SendingObjects then
		table.clear(self.SendingObjects)
	end

	return shallowObjectTable
end

function Hitbox:_SiftThroughSendingCharsAndFire()
	if #self.SendingChars <= 0 then
		return {}
	end

	local shallowObjectTable = {}

	for i, Object: Model in pairs(self.SendingChars) do
		table.insert(shallowObjectTable, Object)

		self.TaggedChars[Object] = true

		if self.DebounceTime > 0 then
			local newThread = task.delay(self.DebounceTime, function()
				self.TaggedChars[Object] = nil
			end)

			table.insert(self.DelayThreads, newThread)
		end
	end

	if #shallowObjectTable > 0 then
		if RunService:IsClient() then
			HitboxRemote:FireServer(self.TickVal, shallowObjectTable)
		end

		self.HitSomeone:Fire(shallowObjectTable)
	end

	if self.SendingChars then
		table.clear(self.SendingChars)
	end

	return shallowObjectTable
end

function Hitbox:_GeneratePart()
	if self.Part then
		return
	end

	if typeof(self.Size) == "Vector3" then
		self.Mode = "Part"
		self.Part = Instance.new("Part")

		assert(self.Part, "Part was nil!")
		assert(typeof(self.Size) == "Vector3", "self.Size wasn't a vector3 when making a part!") -- you shouldn't get here, but just in case

		self.Part.Color = Color3.new(1, 0, 0)

		if self.DebugMode then
			self.Part.Transparency = 0.45
		else
			self.Part.Transparency = 1
		end

		self.Part.Anchored = true
		self.Part.Massless = true
		self.Part.CanCollide = false

		self.Part.Size = self.Size
		self.Part.CFrame = self.Position

		self.Part.Name = "Hitbox" .. self.TickVal
	elseif type(self.Size) == "number" then
		self.Part = Instance.new("Part")

		assert(self.Part and self.Part:IsA("Part"))
		assert(typeof(self.Size) == "number", "self.Size wasn't a number when making a sphere part!") -- you shouldn't get here, but just in case

		self.Part.Shape = Enum.PartType.Ball
		self.Part.Anchored = true
		self.Part.Massless = true
		self.Part.CanCollide = false
		self.Part.Size = Vector3.new(self.Size * 2, self.Size * 2, self.Size * 2)
		self.Part.Transparency = 0.45
		self.Part.Color = Color3.new(1, 0, 0)
		self.Part.CFrame = self.Position
		self.Part.Name = "Hitbox" .. self.TickVal
	end
end

function Hitbox:Destroy()
	-- remove the hitbox from the cache
	table.remove(HitboxCache, table.find(HitboxCache, self))

	-- tell the client to destroy the hitbox on their end
	if self.Client then
		HitboxRemote:FireClient(self.Client, "Des", { _Tick = self.TickVal })
	end

	-- stop the hitbox
	if self.Client then
		if self.ClientConnection then
			self.ClientConnection:Disconnect()
			self.ClientConnection = nil
		end
	else
		if self.Part then
			self.Part.Parent = nil
		end

		if self.RunServiceConnection then
			self.RunServiceConnection:Disconnect()
			self.RunServiceConnection = nil
		end
	end

	-- disconnect all connections to the HitSomeone signal
	pcall(function()
		self.HitSomeone:Destroy()
	end)

	-- disconnect all connections to the HitObject signal
	pcall(function()
		self.HitObject:Destroy()
	end)

	-- if there's a timer, destroy it
	pcall(function()
		if self.Timer then
			self.Timer:Destroy()
		end
	end)

	-- cancel all debounce threads
	if self.DelayThreads then
		for i, thread in pairs(self.DelayThreads) do
			pcall(function()
				task.cancel(thread)
			end)
		end
	end

	-- if there's a part, destroy it
	if self.Part then
		self.Part:Destroy()
	end

	-- clear out all tables
	pcall(function()
		table.clear(self.TaggedChars)
	end)

	pcall(function()
		table.clear(self.SendingChars)
	end)

	pcall(function()
		table.clear(self)
	end)
end

return Hitbox
