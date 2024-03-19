# HitboxClass
An incredibly easy yet powerful OOP-based hitbox module for Roblox. Completely type-checked to allow easy implementation and use.

HitboxClass comes with a variety of features such as easy client-sided hitboxes and velocity prediction.

This module uses [Signal](https://sleitnick.github.io/RbxUtil/api/Signal/) by [Sleitnick](https://github.com/Sleitnick).

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
	SizeOrPart = 5,
	DebounceTime = 1,
	Debug = true,
} :: HitboxTypes.HitboxParams
 --[[
	A magnitude hitbox that can hit anybody, with 1 second between possible hits for each character!
	It'll also show itself in red!
 ]]  
```

Then make a new hitbox with your parameters. The HitboxClass.new function will return the hitbox and whether or not it successfully connected to the client. This will always be true if this is a server hitbox.

```lua
local newHitbox, connected = HitboxClass.new(hitboxParams)
```

Finally, connect to the HitSomeone signal and start the hitbox!

```lua
newHitbox.HitSomeone:Connect(function(hitChars)
	print(hitChars)
end)

newHitbox:Start()
```

### To make a client-sided hitbox:

```lua
local hitboxParams = {
	SizeOrPart = 5,
	DebounceTime = 1,
	UseClient = player : Player, -- add a player into the UseClient parameter!
	Debug = true,
} :: HitboxTypes.HitboxParams
```

Just add a player into the UseClient parameter, after that just handle it like you would a server-sided hitbox.

***Keep in mind that calling HitboxClass.new() for a client-sided hitbox will YIELD for a max of 1.5 seconds in order to try and secure a connection to the client.***

# Class Methods

## ClearClientHitboxes : (Client : Player) -> ()

This method will destroy all client-sided hitboxes. Recommended to be used when there's no reason for a player to have a currently active hitbox, like if they died. This also destroys the hitboxes in the cache.

## ClearHitboxesWithID : (ID : string | number) -> ()

This method will destroy all hitboxes with the specified ID. This also destroys the hitboxes on the client if they are client-sided.

## GetHitboxCache : () -> {Hitbox}

This method will return the server's hitbox cache. This is where all of the game's hitbox objects are stored.

# Class Settings

## Alive Folder

This is the folder you store all your NPCs and players in. HitboxClass cannot run without this being set.

## Projectile Folder

This is usually the folder you store all your VFX or extra stuff in that you normally blacklist for your raycasts. This is where the hitbox will be placed while in Part mode.

## Velocity Prediction Constant

Reflects how much the welded part's velocity will affect the position of the hitbox. The higher the number, the less the velocity will affect it. Default is 6.

# Hitbox Methods

## new(HitboxParams) -> (Hitbox, boolean) (YIELDS FOR CLIENT-SIDED HITBOXES)

This method will return a hitbox and a boolean for whether or not the hitbox made a connection to the client. The boolean will always be true if the hitbox is server-sided. ***This will yield for a maximum of 1.5 seconds if the hitbox is going to be client-sided!***

## Start : (self : Hitbox) -> ()

This method will start the hitbox. The HitSomeone signal **will not** fire unless the hitbox is started with this method.

## Stop : (self : Hitbox) -> ()

This method will stop the hitbox by disconnecting all connections and removing the part being used if Part mode is being used. 

## SetPosition : (self : Hitbox, Position : CFrame) -> ()

This method will place the hitbox in the desired location. When a hitbox has been "welded", this method is nigh-useless until Unweld is used, so keep that in mind.

## ClearTaggedChars : (self : Hitbox) -> ()

This method clears the TaggedCharacters table within the Hitbox, allowing all things hit by the hitbox before to be hit by it again. Use this in order to use the same hitbox multiple times if need be.

## WeldTo : (self : Hitbox , PartToWeldTo : BasePart, OffsetCFrame : CFrame?) -> ()

This method "welds" the hitbox in place at the desired Part with an offset defined by OffsetCFrame (default is the same CFrame as the part). Unless velocity predition is turned off, this will turn it on as well.

## Unweld : (self : Hitbox) -> ()

This method "unwelds" the hitbox, stopping it where it last was before the method was used.

## ChangeWeldOffset : (self : Hitbox, OffsetCFrame : CFrame) -> ()

This method changes the offset for the welded hitbox.

## SetVelocityPrediction : (self : Hitbox, state : boolean) -> ()

This method turns velocity prediction on or off. Velocity prediction is only active while a hitbox is "welded".

## SetDebug : (self : Hitbox, state : boolean) -> ()

This method turns debug mode on or off.

## Destroy : (self : Hitbox) -> ()

This method destroys the hitbox by first stopping the hitbox, clearing out all its tables, disconnecting all connections to its HitSomeone signal, destroying the part used if there is one, then finally clearing itself.

# Signals

## HitSomeone : () -> ({Model})

When fired by the hitbox, it will return a table of the models hit within the hitbox. This is the default signal, it's used whenever the LookingFor parameter is left empty or set to "Humanoid".

## HitObject : () -> ({BasePart})

When fired by the hitbox, it will return a table of baseparts hit within the hitbox. This signal only fires when the hitbox is made with the LookingFor parameter set to "Object".

# Hitbox Parameters

## SizeOrPart : Vector3 | number | BasePart (REQUIRED)

Depending on whether you give this a number, Vector3, or BasePart, the module will handle itself in different ways depending on what SpatialOption you give it. Read the tables below the SpatialOption parameter to get a full overview of it.

## InitialPosition : CFrame?

Starts the hitbox off at this CFrame. By default, hitboxes will be placed at the center of the world at CFrame.new(0,0,0).

## SpatialOption : ("InBox" | "InRadius" | "InPart")?

The spatial query method to be used for the hitbox's calculations. InPart is the most expensive, while InBox and InRadius aren't as expensive. Magnitude is the least expensive out of these.

Depending on what is passed in the SizeOrPart parameter, the following can happen:

### Number

| Option     | Description |
| ----------- | ----------- |
| InRadius   | The method will use the PartBoundsInRadius with a sphere, the radius being the same length as the number provided.         |
| InBox      | The method will use PartBoundsInBox with a cube, all 3 axis being the same length as the number provided.       |
| InPart   | The method will create a sphere to use for PartsInPart, the radius being the same length as the number provided.        |

***If no SpatialOption parameter is passed, the hitbox will default to using Magnitude!***

### Vector3

| Option     | Description |
| ----------- | ----------- |
| InRadius   | Can't be used.         |
| InBox      | The method will use PartBoundsInBox with a cube, the size being determined by the Vector3 provided.     |
| InPart   | The method will create a cube to use for PartsInPart, the size being determined by the Vector3 provided.        |

***If no SpatialOption parameter is passed, the hitbox will default to using PartBoundsInBox!***

### BasePart

| Option     | Description |
| ----------- | ----------- |
| InRadius   | Can't be used.         |
| InBox      | Can't be used.       |
| InPart   | The method will use the part provided for the PartsInPart spatial query.       |

***Passing in a BasePart will cause the hitbox to always use PartsInPart!***

## Blacklist : {Model}?

A blacklist that'll be used to exclude certain things from being hit by the hitbox. For instance, preventing a fire magic user from being hit by their own fireball.

## DebounceTime : number?

Time between hits on the same hitbox. Use this to allow things to be hit multiple times using the same hitbox.

## DotProductRequirement : DotProductRequirement?

Used for Magnitude mode, allowing a Dot Product to be calculated and checked. Only things within the Dot Product will be hit.

## Debug : boolean?

Shows the hitbox used in bright red. Defaults to false.

## UseClient : Player?

Activates client-side mode. The hitbox will automatically be made on the client provided, and its results will be sent back to the server and fired through the HitSomeone signal.

## ID : (string | number)?

A custom ID for the hitbox if wanted.

## VelocityPrediction : boolean?

Turns velocity prediction on or off from the beginning. Defaults to on for server-sided hitboxes.

## LookingFor : ("Humanoid" | "Object")?

Sets the LookingFor field to the option provided.

Setting this to Humanoid makes the hitbox look only for models with humanoids within the Alive folder. It'll fire the models found through the HitSomeone signal.

Setting this to Object makes the hitbox look for all objects instead, firing BaseParts through the HitObject signal instead of going through the HitSomeone signal.

This is set to Humanoid by default.

# Dot Product Requirement

## DotProduct : number (REQUIRED)

Determines the threshold at which a person will be counted. For instance, 0 means they can't be at most 90 degrees from the vector used for the dot product.

### Example
```lua
local DotProductReq = {
	DotProduct = 0,
	PartForVector = character.HumanoidRootPart
} :: HitboxTypes.DotProductRequirement

local hitboxParams = {
	SizeOrPart = 5,
	DotProductRequirement = DotProductReq,
} :: HitboxTypes.HitboxParams
```

The above code will use the HumanoidRootPart's LookVector as the first Vector3. When someone is within the magnitude hitbox, it'll find the dot product of the HumanoidRootPart's LookVector and the vector drawn from the HumanoidRootPart to the person within the hitbox.

## PartForVector : BasePart (REQUIRED)

The part the vector will be based off of.

## VectorType : ("LookVector" | "UpVector" | "RightVector")?

Which vector will be used from the part provided. Defaults to LookVector.

## Negative : boolean?

If the vector will be flipped. For instance, a RightVector being turned to the left. Defaults to false.

# Interval Timer

The timer class is a new class added in v1.1 that can be used to run callbacks on certain intervals.

This class is used inside Hitbox objects, but they can also be used outside of HitboxClass!

## new(TimeOut : number, Callback : () -> ()) -> IntervalTimer

This method will return an IntervalTimer object that elapses at the interval provided in the TimeOut argument.

It's recommended to keep the TimeOut argument set to only 0.1 or higher! Anything lower can cause issues.

## On(self : IntervalTimer) -> ()

This method will turn on a timer that can been turned off using the Off method.

## Off(self : IntervalTimer) -> ()

This method will turn off a timer that can be turned on using the On method.

# Signals

## Elapsed : () -> ()

Fires whenever the timer goes through an interval set by the TimeOut argument.