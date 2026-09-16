--!strict

local RunService = game:GetService("RunService")
local Signal = require(script.Parent.Parent.Signal)

export type IntervalTimer = {

	-- fields
	TimeOut: number,
	TimeElapsed: number,
	Callback: (number) -> (),
	HeartbeatConnection: RBXScriptConnection,
	Elapsed: Signal.Signal<>,

	-- methods
	new: (timeOut: number, callback: () -> ()) -> IntervalTimer,
	On: (self: IntervalTimer) -> (),
	Off: (self: IntervalTimer) -> (),
	Destroy: (self: IntervalTimer) -> (),

	-- private methods
	_Interval: (self: IntervalTimer, deltaTime: number) -> (),
}

local Timer = {}

-- this timer is only reliable on 0.1 timeout threshold or above
function Timer.new(TimeOut: number, Callback: () -> ())
	local self = (setmetatable({}, { __index = Timer }) :: unknown) :: IntervalTimer

	-- set up fields
	self.TimeOut = TimeOut
	self.Callback = Callback
	self.TimeElapsed = 0
	self.Elapsed = Signal.new()

	self.Elapsed:Connect(Callback)

	-- set up connection to heartbeat
	self.HeartbeatConnection = RunService.Heartbeat:Connect(function(DT)
		self:_Interval(DT)
	end)

	return self
end

function Timer._Interval(self: IntervalTimer, deltaTime: number)
	-- add the elapsed time to the timer
	self.TimeElapsed += deltaTime

	-- if there's something crazy going on and this hasn't been called in over 10 times the timeout threshold
	-- we want to reset the time elapsed field to prevent the timer from running the callback over 10 times in a row
	if self.TimeElapsed >= self.TimeOut * 10 then
		-- get the amount of timeouts skipped and then multiply by the timeout threshold
		-- subtract this from time elapsed
		self.TimeElapsed -= math.floor(self.TimeElapsed / self.TimeOut) * self.TimeOut

		return
	end

	-- if the elapsed time meets the threshold for the timeout
	-- then get rid of the elapsed time and run the callback
	if self.TimeElapsed >= self.TimeOut then
		self.TimeElapsed -= self.TimeOut
		self.Elapsed:Fire()
	end
end

function Timer.On(self: IntervalTimer)
	-- if connection exists and is connected, don't do anything
	if self.HeartbeatConnection and self.HeartbeatConnection.Connected then
		return
	end

	-- make a new connection to heartbeat
	self.HeartbeatConnection = RunService.Heartbeat:Connect(function(DT)
		self:_Interval(DT)
	end)
end

function Timer.Off(self: IntervalTimer)
	-- if there's not connection, don't do anything
	if not self.HeartbeatConnection then
		return
	end

	-- disconnect the connection
	self.HeartbeatConnection:Disconnect()
end

function Timer.Destroy(self: IntervalTimer)
	-- disconnect the connection
	self:Off()

	-- destroy the signal
	self.Elapsed:Destroy()

	-- clear self
	table.clear(self)
end

return Timer
