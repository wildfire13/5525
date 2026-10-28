[CmdletBinding()]
param([switch]$Check,[switch]$SmokeTest)
$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
function Probe([string]$Program,[string[]]$Arguments) {
    $output = & $Program @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Probe failed: $Program" }
    return (($output | ForEach-Object { "$_" }) -join "`n").Trim()
}
function Command-Path([string]$Name) {
    $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
    return ''
}
function Existing-Path([string]$Path) {
    if ($Path -and (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return ''
}
try {
    foreach ($relative in @('godot/project.godot','native/bridge.cjs','native/godot_files.py','native/master-data.cjs','native/master_data.py','native/data/master.sqlite','native/assets/music/manifest.json','godot/assets/quest_music.json')) {
        if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $relative) -PathType Leaf)) {
            throw "Missing project file: $relative. Keep the godot and native folders together."
        }
    }
    $nodeCandidates = @()
    if ($env:NATIVE5525_NODE) { $nodeCandidates = @($env:NATIVE5525_NODE) }
    else { $nodeCandidates = @((Command-Path 'node'),(Join-Path $env:ProgramFiles 'nodejs/node.exe')) }
    $nodePath = ''; $nodeVersion = ''
    foreach ($candidate in $nodeCandidates) {
        $resolved = Existing-Path $candidate
        if (-not $resolved) { continue }
        try {
            $version = Probe $resolved @('-p','process.versions.node')
            if ([int]($version.Split('.')[0]) -ge 22) { $nodePath=$resolved; $nodeVersion=$version; break }
        } catch { }
    }
    if (-not $nodePath) { throw 'Node.js 22+ was not found. Set NATIVE5525_NODE to its full executable path.' }

    $pythonCandidates = @()
    if ($env:NATIVE5525_PYTHON) { $pythonCandidates = @($env:NATIVE5525_PYTHON) }
    else {
        $pythonCandidates += (Command-Path 'python')
        $pyPath = Command-Path 'py'
        if ($pyPath) { try { $pythonCandidates += (Probe $pyPath @('-3','-c','import sys; print(sys.executable)')) } catch { } }
        $pythonCandidates += (Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe')
    }
    $pythonPath=''; $pythonInfo=$null
    foreach ($candidate in $pythonCandidates) {
        $resolved = Existing-Path $candidate
        if (-not $resolved) { continue }
        try {
            # File-based probe: Windows PowerShell strips embedded native argument quotes.
            $info = (Probe $resolved @('-X','utf8','-B',(Join-Path $projectRoot 'native/master_data.py'),'probe')) | ConvertFrom-Json
            $pythonPath=$resolved; $pythonInfo=$info; break
        } catch { }
    }
    if (-not $pythonPath) { throw 'Python 3.10+ with Pillow and SQLite JSON/foreign-key support was not found. Set NATIVE5525_PYTHON to its full executable path.' }

    # Validate the shipped master read-only before opening the game or a save.
    try {
        $null = Probe $pythonPath @('-X','utf8','-B',(Join-Path $projectRoot 'native/master_data.py'),'read','--db',(Join-Path $projectRoot 'native/data/master.sqlite'))
    } catch {
        throw 'Master data could not be read. Restore native/data/master.sqlite from the matching game distribution. Existing saves were not changed.'
    }

    $godotCandidates = @()
    if ($env:GODOT_BIN) { $godotCandidates = @($env:GODOT_BIN) }
    else {
        $godotCandidates += (Command-Path 'godot')
        $godotCandidates += (Command-Path 'godot4')
        $runtimeFolders = @((Join-Path $projectRoot 'runtime/godot'))
        $existingDemoRoot = Join-Path (Split-Path $projectRoot -Parent) '5525'
        if (Test-Path -LiteralPath $existingDemoRoot -PathType Container) {
            $runtimeFolders += @(Get-ChildItem -LiteralPath $existingDemoRoot -Directory -Filter 'Godot*' | Select-Object -ExpandProperty FullName)
        }
        foreach ($folder in $runtimeFolders) {
            if (Test-Path -LiteralPath $folder -PathType Container) {
                $godotCandidates += @(Get-ChildItem -LiteralPath $folder -File -Filter '*_console.exe' | Sort-Object Name -Descending | Select-Object -ExpandProperty FullName)
            }
        }
    }
    $godotPath=''; $godotVersion=''
    foreach ($candidate in $godotCandidates) {
        $resolved = Existing-Path $candidate
        if (-not $resolved) { continue }
        try {
            $version = Probe $resolved @('--version')
            if ($version -match '^4\.6\.') { $godotPath=$resolved; $godotVersion=$version; break }
        } catch { }
    }
    if (-not $godotPath) { throw 'Godot 4.6.x was not found. Set GODOT_BIN to its full executable path. Nothing was downloaded.' }
    $report = [ordered]@{
        project=$projectRoot
        godot=@{path=$godotPath;version=$godotVersion}
        node=@{path=$nodePath;version=$nodeVersion}
        python=@{path=$pythonPath;version=$pythonInfo.python;pillow=$pythonInfo.pillow;sqlite=$pythonInfo.sqlite}
        fallback=(Join-Path $projectRoot 'Start-5525-Python.cmd')
        installedNothing=$true
    }
    if ($Check) { $report | ConvertTo-Json -Depth 4; exit 0 }
    $env:NATIVE5525_NODE=$nodePath
    $env:NATIVE5525_PYTHON=$pythonPath
    $env:PYTHONUTF8='1'
    $env:PYTHONDONTWRITEBYTECODE='1'
    # Source checkouts contain import recipes, not the generated .godot cache.
    # Run the incremental importer on every launch, including after a Git pull.
    $importLog = [System.IO.Path]::GetTempFileName()
    $importArgs=@('--headless','--path',(Join-Path $projectRoot 'godot'),'--editor','--import')
    $savedErrorPreference = $ErrorActionPreference
    try {
        # Windows PowerShell represents native stderr as error records. Capture
        # them without aborting before Godot finishes and supplies its exit code.
        $ErrorActionPreference = 'Continue'
        & $godotPath @importArgs > $importLog 2>&1
        $importExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $savedErrorPreference
    }
    $importOutput = Get-Content -LiteralPath $importLog -Raw
    if ($importExit -ne 0 -or $importOutput -match '(?m)(^|\s)(SCRIPT ERROR:|ERROR:)') {
        [Console]::Error.WriteLine('[5525] Asset import failed. Log: '+$importLog)
        [Console]::Error.WriteLine($importOutput)
        if ($importExit -ne 0) { exit $importExit }
        exit 1
    }
    Remove-Item -LiteralPath $importLog
    $godotArgs=@('--path',(Join-Path $projectRoot 'godot'))
    if ($SmokeTest) { $godotArgs+=@('--headless','--audio-driver','Dummy','--script','res://tests/launcher_smoke.gd') }
    & $godotPath @godotArgs
    exit $LASTEXITCODE
} catch {
    [Console]::Error.WriteLine('[5525] '+$_.Exception.Message)
    [Console]::Error.WriteLine('Python fallback: Start-5525-Python.cmd. Existing saves were not changed.')
    exit 1
}
