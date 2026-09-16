local Types = {}

-- temp signal to make the types
local signal = require(script.Parent.Parent.Signal)
local timer = require(script.Parent.Timer)
local newSignal = signal.new()

export type SignalType<T...> = typeof(newSignal)

export type SignalConnection = typeof(newSignal:Connect())

export type DotProductRequirement = {
	DotProduct: number,
	PartForVector: BasePart,
	VectorType: ("LookVector" | "UpVector" | "RightVector")?,
	Negative: boolean?,
}

export type HitboxParams = {
	SizeOrPart: Vector3 | number | BasePart,
	SpatialOption: ("InBox" | "InRadius" | "InPart")?,
	InitialPosition: CFrame?,
	Blacklist: { Model }?,
	DebounceTime: number?,
	DotProductRequirement: DotProductRequirement?,
	UseClient: Player?,
	ID: (string | number)?,
	VelocityPrediction: boolean?,
	Debug: boolean?,
	Debris: number?,
	LookingFor: ("Humanoid" | "Object")?,

	-- Private fields
	_Tick: number?,
}

export type Hitbox = {

	-- Fields

	Size: Vector3 | number,
	Mode: "Magnitude" | "Part",
	SpatialOption: "InBox" | "InRadius" | "InPart" | "Magnitude",
	LookingFor: "Humanoid" | "Object",
	DebounceTime: number,
	Part: BasePart?,
	Position: CFrame,
	DotProductRequirement: DotProductRequirement?,
	TaggedChars: { [Model]: boolean },
	TaggedObjects: { [BasePart]: boolean },
	ID: (string | number)?,
	TickVal: number,
	Blacklist: {}?,
	SendingChars: { Model },
	SendingObjects: { BasePart },
	DelayThreads: { thread },
	HitSomeone: signal.Signal<{ Model }>,
	HitObject: signal.Signal<{ BasePart }>,
	RunServiceConnection: RBXScriptConnection?,
	ClientConnection: RBXScriptConnection?,
	PartWeld: BasePart?,
	PartWeldOffset: CFrame?,
	Client: Player?,
	VelocityPrediction: boolean?,
	DebugMode: boolean,
	Lifetime: number,

	-- Methods

	new: (HitboxParams) -> (Hitbox, boolean),
	ClearClientHitboxes: (Client: Player) -> (),
	ClearHitboxesWithID: (ID: string | number) -> (),
	GetHitboxCache: () -> { Hitbox },
	SetAliveFolder: (Folder: Instance) -> (),
	SetProjectileFolder: (Folder: Instance) -> (),
	SetVelocityPredictionConstant: (Constant: number) -> (),
	ClearTaggedChars: (self: Hitbox) -> (),
	Start: (self: Hitbox) -> (),
	Stop: (self: Hitbox) -> (),
	Check: (self: Hitbox) -> ({ Model } | { BasePart })?,
	SetPosition: (self: Hitbox, Position: CFrame) -> (),
	Destroy: (self: Hitbox) -> (),
	WeldTo: (self: Hitbox, PartToWeldTo: BasePart, OffsetCFrame: CFrame?) -> (),
	Unweld: (self: Hitbox) -> (),
	ChangeWeldOffset: (self: Hitbox, OffsetCFrame: CFrame) -> (),
	SetVelocityPrediction: (self: Hitbox, state: boolean) -> (),
	SetDebug: (self: Hitbox, state: boolean) -> (),

	-- Private Methods (Don't touch unless you know what you're doing!)

	_SiftThroughSendingCharsAndFire: (self: Hitbox) -> { Model },
	_SiftThroughSendingObjectsAndFire: (self: Hitbox) -> { BasePart },
	_GeneratePart: (self: Hitbox) -> (),
	_ConnectClient: (self: Hitbox) -> (),
	_Step: (self: Hitbox) -> { Model } | { BasePart },
	_Query: (self: Hitbox) -> (),
	_PassesDotProduct: (self: Hitbox, TargetPosition: Vector3) -> boolean,

	-- Private Fields (Don't touch unless you know what you're doing!)
	Timer: timer.IntervalTimer?,
}

return Types
