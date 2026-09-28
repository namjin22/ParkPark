$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$localAppData = [Environment]::GetFolderPath("LocalApplicationData")
$userProfile = [Environment]::GetFolderPath("UserProfile")
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = "$machinePath;$userPath;$env:Path"
$winGetRoot = Join-Path $localAppData "Microsoft\WinGet\Packages"

function Resolve-Tool {
	param(
		[string]$Name,
		[string]$FallbackPath
	)

	$command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
	if ($command -ne $null) {
		return $command.Source
	}
	if (Test-Path $FallbackPath -PathType Leaf) {
		return $FallbackPath
	}
	throw "Required tool is not installed or on PATH: $Name"
}

$selenePath = Resolve-Tool "selene" (Join-Path $winGetRoot "Kampfkarren.selene_Microsoft.Winget.Source_8wekyb3d8bbwe\selene.exe")
$styluaPath = Resolve-Tool "stylua" (Join-Path $winGetRoot "JohnnyMorganz.StyLua_Microsoft.Winget.Source_8wekyb3d8bbwe\stylua.exe")
$rojoPath = Resolve-Tool "rojo" (Join-Path $userProfile ".aftman\bin\rojo.exe")
$extensionRoot = Join-Path $userProfile ".vscode\extensions"
$luauLspExtension = Get-ChildItem -Path $extensionRoot -Directory -Filter "johnnymorganz.luau-lsp-*-win32-x64" |
	Sort-Object LastWriteTime -Descending |
	Select-Object -First 1

if ($luauLspExtension -eq $null) {
	throw "Luau LSP VS Code extension is not installed. Install JohnnyMorganz.luau-lsp first."
}

$luauLspPath = Join-Path $luauLspExtension.FullName "bin\server.exe"
$typesDirectory = Join-Path $localAppData "ParkParkTools\luau-types"
$definitionsPath = Join-Path $typesDirectory "globalTypes.None.d.luau"
$definitionUrl = "https://luau-lsp.pages.dev/type-definitions/globalTypes.None.d.luau"

foreach ($tool in @($selenePath, $styluaPath, $rojoPath, $luauLspPath)) {
	if (-not (Test-Path $tool -PathType Leaf)) {
		throw "Required tool not found: $tool"
	}
}

if (-not (Test-Path $definitionsPath -PathType Leaf)) {
	New-Item -ItemType Directory -Path $typesDirectory -Force | Out-Null
	Invoke-WebRequest -Uri $definitionUrl -OutFile $definitionsPath
}

$sourcemapPath = Join-Path $env:TEMP ("ParkPark-" + [guid]::NewGuid().ToString("N") + ".sourcemap.json")
$buildPath = Join-Path $env:TEMP ("ParkPark-" + [guid]::NewGuid().ToString("N") + ".rbxlx")
$failed = $false

function Invoke-Check {
	param(
		[string]$Label,
		[string]$Executable,
		[string[]]$Arguments
	)

	Write-Host "`n== $Label =="
	& $Executable @Arguments
	if ($LASTEXITCODE -ne 0) {
		$script:failed = $true
	}
}

Push-Location $repoRoot
try {
	Invoke-Check "StyLua format check" $styluaPath @("--check", "src")
	Invoke-Check "Selene Luau lint" $selenePath @("src")
	Invoke-Check "Rojo sourcemap" $rojoPath @("sourcemap", "default.project.json", "--include-non-scripts", "--output", $sourcemapPath)

	if (Test-Path $sourcemapPath -PathType Leaf) {
		$definitionArgument = "--definitions:@roblox=$definitionsPath"
		$sourcemapArgument = "--sourcemap=$sourcemapPath"
		Invoke-Check "Luau type analysis" $luauLspPath @("analyze", "--platform=roblox", $definitionArgument, $sourcemapArgument, "src")
	}

	Invoke-Check "Rojo place build" $rojoPath @("build", "default.project.json", "--output", $buildPath)
}
finally {
	Pop-Location
	Remove-Item $sourcemapPath -Force -ErrorAction SilentlyContinue
	Remove-Item $buildPath -Force -ErrorAction SilentlyContinue
}

if ($failed) {
	Write-Error "ParkPark verification failed. Review the checks above."
}

Write-Host "`nParkPark verification passed."
