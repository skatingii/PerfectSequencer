--!strict

export type Task = any

type Fields = {
	Tasks: { Task },
}

const Cleanup = {}
Cleanup.__index = Cleanup

export type Cleanup = typeof(setmetatable({} :: Fields, Cleanup))

function Cleanup.new(): Cleanup
	const self: Fields = {
		Tasks = {},
	}

	return setmetatable(self, Cleanup)
end

function Cleanup.Add(self: Cleanup, Item: Task): Task
	table.insert(self.Tasks, Item)

	return Item
end

function Cleanup.Clean(self: Cleanup)
	const Pending = self.Tasks
	self.Tasks = {}

	for _, Item in Pending do
		const Kind = typeof(Item)

		if Kind == "RBXScriptConnection" then
			Item:Disconnect()
		elseif Kind == "Instance" then
			Item:Destroy()
		elseif Kind == "function" then
			Item()
		elseif Kind == "thread" then
			const Succeeded = pcall(task.cancel, Item)

			if not Succeeded then
				warn("[perfect sequencer] could not cancel a pending thread, it may already be running")
			end
		elseif Kind == "table" then
			if Item.Disconnect then
				Item:Disconnect()
			elseif Item.Destroy then
				Item:Destroy()
			else
				warn("[perfect sequencer] a table was given to Cleanup with no Disconnect or Destroy method")
			end
		else
			warn(`[perfect sequencer] Cleanup does not know how to clean a {Kind}`)
		end
	end

	table.clear(Pending)
end

Cleanup.Destroy = Cleanup.Clean

return Cleanup
