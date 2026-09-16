--!strict

local require = require
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HitboxClassRemote = ReplicatedStorage:WaitForChild("HitboxClassRemote") :: RemoteEvent
local HitboxClass = require(script["HitboxClass Module"].Value)

local currentHitboxes = {}

HitboxClassRemote.OnClientEvent:Connect(function(mode, packet)
	if mode == "Clr" then
		for i, Hitbox in pairs(currentHitboxes) do
			Hitbox:Destroy()
			currentHitboxes[i] = nil
		end
		return
	end

	if mode ~= "New" and not currentHitboxes[packet._Tick] then
		warn(
			"No hitbox found on the client for tick value sent. Don't change the tick value manually, change the ID instead. (HitboxClass)"
		)
		return
	end

	if mode == "New" then
		local newHitbox = HitboxClass.new(packet)
		currentHitboxes[packet._Tick] = newHitbox
		HitboxClassRemote:FireServer(packet._Tick)
	end

	if mode == "Start" then
		currentHitboxes[packet._Tick]:Start()
	end

	if mode == "Stop" then
		currentHitboxes[packet._Tick]:Stop()
	end

	if mode == "Check" then
		currentHitboxes[packet._Tick]:Check()
	end

	if mode == "ClrTag" then
		currentHitboxes[packet._Tick]:ClearTaggedChars()
	end

	if mode == "Weld" then
		currentHitboxes[packet._Tick]:WeldTo(packet.WeldTo, packet.Offset)
	end

	if mode == "WeldOfs" then
		currentHitboxes[packet._Tick]:ChangeWeldOffset(packet.Offset)
	end

	if mode == "Unweld" then
		currentHitboxes[packet._Tick]:Unweld()
	end

	if mode == "PosCh" then
		currentHitboxes[packet._Tick]:SetPosition(packet.Position)
	end

	if mode == "SzCh" then
		currentHitboxes[packet._Tick]:SetSize(packet.Size)
	end

	if mode == "Dbg" then
		currentHitboxes[packet._Tick]:SetDebug(packet.Debug)
	end

	if mode == "Des" then
		currentHitboxes[packet._Tick]:Destroy()
		currentHitboxes[packet._Tick] = nil
	end
end)
