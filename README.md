# HitboxClass
An incredibly easy yet powerful OOP-based hitbox module for Roblox. Completely type-checked to allow easy implementation and use.

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

# Hitbox Methods

### new(HitboxParams) -> (Hitbox, boolean)

This method will return a hitbox and a boolean for whether or not the hitbox made a connection to the client. The boolean will always be true if the hitbox is server-side.

### Start : (self : Hitbox) -> ()

This method will start the hitbox. The HitSomeone signal **will not** fire unless the hitbox is started with this method.

### Stop : (self : Hitbox) -> ()

This method will stop the hitbox by disconnecting all connections and removing the part being used if Part mode is being used.

### SetPosition : (self : Hitbox, Position : CFrame) -> ()

This method will place the hitbox in the desired location. When a hitbox has been "welded", this method is nigh-useless until Unweld is used, so keep that in mind.

### ClearTaggedChars : (self : Hitbox) -> ()

This method clears the TaggedCharacters table within the Hitbox, allowing all things hit by the hitbox before to be hit by it again. Use this in order to use the same hitbox multiple times if need be.

### WeldTo : (self : Hitbox , PartToWeldTo : BasePart, OffsetCFrame : CFrame?) -> ()

This method "welds" the hitbox in place at the desired Part with an offset defined by OffsetCFrame (default is the same CFrame as the part). Unless velocity predition is turned off, this will turn it on as well.

### Unweld : (self : Hitbox) -> ()

This method "unwelds" the hitbox, stopping it where it last was before the method was used.

### ChangeWeldOffset : (self : Hitbox, OffsetCFrame : CFrame) -> ()

This method changes the offset for the welded hitbox.

### SetVelocityPrediction : (self : Hitbox, state : boolean) -> ()

This method turns velocity prediction on or off. Velocity prediction is only active while a hitbox is "welded".

### Destroy : (self : Hitbox) -> ()

This method destroys the hitbox by first stopping the hitbox, clearing out all its tables, destroying the part used if there is one, then finally clearing itself.

# Hitbox Parameters

### Mode : "Magnitude" | "Part" (REQUIRED)
Determines whether or not the hitbox will be in Magnitude mode or Part mode. 

### SizeOrPart : Vector3 | number | BasePart (REQUIRED)
Give this a number if Magnitude is used; this will determine the radius of the circle. If using Part mode, give this a Vector3 to have the module make a box for you or hand it a part to use as the hitbox. 

### InitialPosition : CFrame?
Starts the hitbox off at this CFrame.

### Blacklist : {Model}?
A blacklist that'll be used to exclude certain things from being hit by the hitbox. For instance, preventing a fire magic user from being hit by their own fireball.

### DebounceTime : number?
Time between hits on the same hitbox. Use this to allow things to be hit multiple times using the same hitbox.

### DotProductRequirement : DotProductRequirement?
Used for Magnitude mode, allowing a Dot Product to be calculated and checked. Only things within the Dot Product will be hit.

### ShowHitbox : boolean?
Shows the hitbox used in bright red. Defaults to false.

### UseClient : Player?
Activates client-side mode. The hitbox will automatically be made on the client provided, and its results will be sent back to the server and fired through the HitSomeone signal.

### TickVal : number?
A custom ID for the hitbox if wanted. Defaults to the current server time using workspace:GetServerTimeNow().

### VelocityPrediction : boolean?
Turns velocity prediction on or off from the beginning. Defaults to on.

# Dot Product Requirement

### DotProduct : number (REQUIRED)
Determines the threshold at which a person will be counted. For instance, 0 means they have to be at least 180 degrees from the vector used for the dot product.

### PartForVector : BasePart (REQUIRED)
The part the vector will be based off of.

### VectorType : ("LookVector" | "UpVector" | "RightVector")?
Which vector will be used from the part provided. Defaults to LookVector.

### Negative : boolean?
If the vector will be flipped. For instance, a RightVector being turned to the left. Defaults to false.