--!strict

const Fs = require("@lute/fs")
const Luau = require("@lute/luau")

const Warnings: { string } = {}

const function Warn(...: any)
	const Parts = {}

	for Index = 1, select("#", ...) do
		table.insert(Parts, tostring(select(Index, ...)))
	end

	table.insert(Warnings, table.concat(Parts, " "))
end

const Task = {
	spawn = function(Target: any, ...: any)
		if typeof(Target) == "thread" then
			coroutine.resume(Target, ...)
		else
			coroutine.resume(coroutine.create(Target), ...)
		end
	end,

	cancel = function(Target: thread)
		coroutine.close(Target)
	end,
}

const function LoadModule(Name: string): any
	const Handle = Fs.open(`src/{Name}.luau`)
	const Source = Fs.read(Handle)
	Fs.close(Handle)

	const Compiled = Luau.compile(Source)

	const Environment = {
		task = Task,
		warn = Warn,

		typeof = typeof,
		type = type,
		tostring = tostring,
		tonumber = tonumber,
		select = select,
		next = next,
		pairs = pairs,
		ipairs = ipairs,
		error = error,
		assert = assert,
		pcall = pcall,
		xpcall = xpcall,
		setmetatable = setmetatable,
		getmetatable = getmetatable,
		rawget = rawget,
		rawset = rawset,
		table = table,
		string = string,
		math = math,
		os = os,
		coroutine = coroutine,
		buffer = buffer,
	}

	return Luau.load(Compiled, Name, Environment)()
end

local Passed = 0
local Failed = 0
local Suite = ""

const Context = {}
Context.__index = Context

function Context.Test(self: any, Name: string, Body: () -> ())
	const Succeeded, Problem = pcall(Body)

	if Succeeded then
		Passed += 1
		print(`  ok    {Suite} > {Name}`)
	else
		Failed += 1
		print(`  FAIL  {Suite} > {Name}`)
		print(`        {Problem}`)
	end
end

function Context.Equal(self: any, Actual: any, Expected: any, Label: string)
	if Actual ~= Expected then
		error(`{Label}: expected {tostring(Expected)}, got {tostring(Actual)}`, 2)
	end
end

function Context.True(self: any, Value: any, Label: string)
	if not Value then
		error(`{Label}: expected a truthy value, got {tostring(Value)}`, 2)
	end
end

function Context.TakeWarnings(self: any): { string }
	const Taken = table.clone(Warnings)
	table.clear(Warnings)

	return Taken
end

const Suites: { { Name: string, Module: string, Run: (any, any) -> () } } = {
	{ Name = "Queue", Module = "Queue", Run = require("./Queue") },
	{ Name = "Signal", Module = "Signal", Run = require("./Signal") },
	{ Name = "Cleanup", Module = "Cleanup", Run = require("./Cleanup") },
}

for _, Entry in Suites do
	Suite = Entry.Name
	print(Entry.Name)

	Entry.Run(setmetatable({}, Context), LoadModule(Entry.Module))
end

print(`\n{Passed} passed, {Failed} failed`)

if Failed > 0 then
	error("test suite failed", 0)
end
