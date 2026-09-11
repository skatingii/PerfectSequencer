--!strict

return function(T: any, Signal: any)
	T:Test("calls a connected handler with its arguments", function()
		const Fired = Signal.new()
		local Got = nil

		Fired:Connect(function(Value)
			Got = Value
		end)

		Fired:Fire(42)

		T:Equal(Got, 42, "handler argument")
	end)

	T:Test("calls every connected handler", function()
		const Fired = Signal.new()
		local Count = 0

		Fired:Connect(function()
			Count += 1
		end)
		Fired:Connect(function()
			Count += 1
		end)
		Fired:Connect(function()
			Count += 1
		end)

		Fired:Fire()

		T:Equal(Count, 3, "handler count")
	end)

	T:Test("stops calling a disconnected handler", function()
		const Fired = Signal.new()
		local Count = 0

		const Link = Fired:Connect(function()
			Count += 1
		end)

		Fired:Fire()
		Link:Disconnect()
		Fired:Fire()

		T:Equal(Count, 1, "handler count")
		T:Equal(Link.Connected, false, "connected flag")
	end)

	T:Test("disconnecting twice is harmless", function()
		const Fired = Signal.new()

		const Link = Fired:Connect(function() end)

		Link:Disconnect()
		Link:Disconnect()

		T:Equal(Link.Connected, false, "connected flag")
	end)

	T:Test("keeps firing the rest when a handler disconnects itself mid-fire", function()
		const Fired = Signal.new()
		local Count = 0
		local Link = nil

		Fired:Connect(function()
			Count += 1
		end)

		Link = Fired:Connect(function()
			Link:Disconnect()
			Count += 1
		end)

		Fired:Connect(function()
			Count += 1
		end)

		Fired:Fire()

		T:Equal(Count, 3, "handlers run on the first fire")

		Fired:Fire()

		T:Equal(Count, 5, "handlers run after the self disconnect")
	end)

	T:Test("disconnects the middle of the list correctly", function()
		const Fired = Signal.new()
		const Seen = {}

		Fired:Connect(function()
			table.insert(Seen, "third")
		end)
		const Middle = Fired:Connect(function()
			table.insert(Seen, "second")
		end)
		Fired:Connect(function()
			table.insert(Seen, "first")
		end)

		Middle:Disconnect()
		Fired:Fire()

		T:Equal(table.concat(Seen, ","), "first,third", "remaining handlers")
	end)

	T:Test("Once fires a single time", function()
		const Fired = Signal.new()
		local Count = 0

		Fired:Once(function()
			Count += 1
		end)

		Fired:Fire()
		Fired:Fire()
		Fired:Fire()

		T:Equal(Count, 1, "handler count")
	end)

	T:Test("DisconnectAll clears every handler", function()
		const Fired = Signal.new()
		local Count = 0

		Fired:Connect(function()
			Count += 1
		end)
		Fired:Connect(function()
			Count += 1
		end)

		Fired:DisconnectAll()
		Fired:Fire()

		T:Equal(Count, 0, "handler count")
	end)

	T:Test("Destroy behaves like DisconnectAll", function()
		const Fired = Signal.new()
		local Count = 0

		Fired:Connect(function()
			Count += 1
		end)

		Fired:Destroy()
		Fired:Fire()

		T:Equal(Count, 0, "handler count")
	end)

	T:Test("reuses the runner thread across handlers", function()
		const Fired = Signal.new()
		const Threads = {}

		Fired:Connect(function()
			Threads[coroutine.running()] = true
		end)
		Fired:Connect(function()
			Threads[coroutine.running()] = true
		end)

		Fired:Fire()

		local Distinct = 0

		for _ in Threads do
			Distinct += 1
		end

		T:Equal(Distinct, 1, "distinct runner threads")
	end)
end
