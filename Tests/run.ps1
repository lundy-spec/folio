# Runs the busted spec suite locally on Windows.
# If `lua`/`luarocks` aren't on PATH yet (fresh install, shell not restarted),
# falls back to the default winget install location.

$ErrorActionPreference = "Stop"

function Resolve-Tool($name, $fallbackGlob) {
	$cmd = Get-Command $name -ErrorAction SilentlyContinue
	if ($cmd) { return $cmd.Source }
	$found = Get-ChildItem $fallbackGlob -ErrorAction SilentlyContinue | Select-Object -First 1
	if (-not $found) { throw "Could not find $name - install it first (see README)." }
	return $found.FullName
}

$lua = Resolve-Tool "lua" "$env:LOCALAPPDATA\Programs\Lua\bin\lua.exe"
$luarocks = Resolve-Tool "luarocks" "$env:LOCALAPPDATA\Programs\Lua\bin\luarocks.exe"

$lrPath = (& $luarocks path --lr-path).Trim()
$lrCPath = (& $luarocks path --lr-cpath).Trim()
$lrBin = (& $luarocks path --lr-bin).Trim()

$env:LUA_PATH = "$lrPath;;"
$env:LUA_CPATH = "$lrCPath;;"

& $lua "$lrBin\busted" Tests/spec @args
exit $LASTEXITCODE
