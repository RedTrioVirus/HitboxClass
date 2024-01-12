# HitboxClass
An incredibly easy yet powerful hitbox module for Roblox.

# How to Set Up
First, drag the HitboxClass module into your desired place in ReplicatedStorage.

Next, select your Alive folder within HitboxClass's settings folder. This is the folder you store all your players/npcs.

Then, select your Projectiles folder whitin HitboxClass's settings folder. This is the folder you store your VFX and stuff so it doesn't interfere with raycasting and such. This is where the hitbox will be placed while it's active.

Finally, require the module somewhere on the server! HitboxClass will automatically setup client-server communication if it hasn't been set up yet.

# How to Use
First, require the module.

Next, setup your Hitbox Parameters:
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HitboxClass = require(ReplicatedStorage.Modules.HitboxClass)
local HitboxTypes = require(ReplicatedStorage.Modules.HitboxClass.Types)

local hitboxParams = {
	Mode = "Magnitude",
	InitialPosition = CFrame.new(0,0,0),
	SizeOrPart = 5,
} :: HitboxTypes.HitboxParams
```

"Test"