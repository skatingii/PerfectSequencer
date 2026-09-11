--!strict

return function(T: any, Cleanup: any)
	T:Test("calls a function task", function()
		const Bin = Cleanup.new()
		local Called = false

		Bin:Add(function()
			Called = true
		end)

		Bin:Clean()

		T:Equal(Called, true, "function task called")
	end)

	T:Test("returns whatever it was given", function()
		const Bin = Cleanup.new()
		const Item = function() end

		T:Equal(Bin:Add(Item), Item, "returned task")
	end)

	T:Test("prefers Disconnect on a table", function()
		const Bin = Cleanup.new()
		local Disconnected = false
		local Destroyed = false

		Bin:Add({
			Disconnect = function()
				Disconnected = true
			end,
			Destroy = function()
				Destroyed = true
			end,
		})

		Bin:Clean()

		T:Equal(Disconnected, true, "Disconnect called")
		T:Equal(Destroyed, false, "Destroy not called")
	end)

	T:Test("falls back to Destroy on a table", function()
		const Bin = Cleanup.new()
		local Destroyed = false

		Bin:Add({
			Destroy = function()
				Destroyed = true
			end,
		})

		Bin:Clean()

		T:Equal(Destroyed, true, "Destroy called")
	end)

	T:Test("warns about a table it cannot clean", function()
		const Bin = Cleanup.new()

		T:TakeWarnings()
		Bin:Add({ Nothing = true })
		Bin:Clean()

		T:Equal(#T:TakeWarnings(), 1, "warning count")
	end)

	T:Test("warns about a task type it does not understand", function()
		const Bin = Cleanup.new()

		T:TakeWarnings()
		Bin:Add(42)
		Bin:Clean()

		T:Equal(#T:TakeWarnings(), 1, "warning count")
	end)

	T:Test("runs every task in one clean", function()
		const Bin = Cleanup.new()
		local Count = 0

		for _ = 1, 5 do
			Bin:Add(function()
				Count += 1
			end)
		end

		Bin:Clean()

		T:Equal(Count, 5, "tasks run")
	end)

	T:Test("cleaning twice does not run a task again", function()
		const Bin = Cleanup.new()
		local Count = 0

		Bin:Add(function()
			Count += 1
		end)

		Bin:Clean()
		Bin:Clean()

		T:Equal(Count, 1, "tasks run")
	end)

	T:Test("a task added during a clean is not run by that clean", function()
		const Bin = Cleanup.new()
		local Late = 0

		Bin:Add(function()
			Bin:Add(function()
				Late += 1
			end)
		end)

		Bin:Clean()

		T:Equal(Late, 0, "late task deferred")

		Bin:Clean()

		T:Equal(Late, 1, "late task run on the next clean")
	end)

	T:Test("Destroy behaves like Clean", function()
		const Bin = Cleanup.new()
		local Called = false

		Bin:Add(function()
			Called = true
		end)

		Bin:Destroy()

		T:Equal(Called, true, "task called")
	end)

	T:Test("cancels a thread task", function()
		const Bin = Cleanup.new()
		local Reached = false

		const Waiting = coroutine.create(function()
			coroutine.yield()
			Reached = true
		end)

		coroutine.resume(Waiting)
		Bin:Add(Waiting)
		Bin:Clean()

		T:Equal(coroutine.status(Waiting), "dead", "thread closed")
		T:Equal(Reached, false, "cancelled thread did not run")
	end)
end
