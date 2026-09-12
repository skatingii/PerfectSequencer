--!strict

const Fs = require("@lute/fs")

const function Read(Path: string): string
	const Handle = Fs.open(Path)
	const Source = Fs.read(Handle)
	Fs.close(Handle)

	return Source
end

const function Find(Path: string, Pattern: string): string
	const Found = string.match(Read(Path), Pattern)

	if not Found then
		error(`no version found in {Path}`, 0)
	end

	return Found
end

return function(T: any)
	const Wally = Find("wally.toml", 'version%s*=%s*"([%d%.]+)"')
	const Npm = Find("package.json", '"version"%s*:%s*"([%d%.]+)"')
	const Header = Find("src/init.luau", "Version%s+([%d%.]+)")

	T:Test("wally.toml and package.json agree", function()
		T:Equal(Npm, Wally, "package.json version")
	end)

	T:Test("the init.luau header agrees", function()
		T:Equal(Header, Wally, "header version")
	end)

	T:Test("the version is a plain semver triple", function()
		T:True(string.match(Wally, "^%d+%.%d+%.%d+$") ~= nil, `"{Wally}" is not major.minor.patch`)
	end)
end
