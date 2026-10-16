param(
    [ValidateSet('help','check','setup','build','test','logs','update','all','server','play','map')]
    [string]$Action = 'help'
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Sdk = 'C:\Dev\source-sdk-2013'
$Src = Join-Path $Sdk 'src'
$LogDir = Join-Path $Root 'logs'
New-Item -ItemType Directory -Force $LogDir | Out-Null
$SteamBase = Join-Path ${env:ProgramFiles(x86)} 'Steam\steamapps\common\Source SDK Base 2013 Multiplayer'
$ModPath = Join-Path $Sdk 'game\mod_hl2mp'
function Check-Runtime {
    $client = Join-Path $SteamBase 'hl2_win64.exe'
    $server = Join-Path $SteamBase 'srcds_win64.exe'
    $gameInfo = Join-Path $ModPath 'gameinfo.txt'
    foreach ($path in @($client,$server,$gameInfo)) {
        if (!(Test-Path $path)) { throw "Runtime-Datei fehlt: $path" }
    }
    foreach ($dll in @('client.dll','server.dll')) {
        $path = Join-Path $ModPath "bin\x64\$dll"
        if (!(Test-Path $path)) { throw "Modul fehlt: $path. Zuerst .\ac.ps1 build ausfuehren." }
    }
    Write-Host "Steam Runtime: $SteamBase"
    Write-Host "SDK Mod: $ModPath"
}
function Check-Prerequisites {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (!(Test-Path $vswhere)) { throw 'vswhere.exe fehlt' }
    $vs = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
    if (!$vs) { throw 'Visual Studio mit C++-Tools nicht gefunden' }
    $msbuild = Join-Path $vs 'MSBuild\Current\Bin\MSBuild.exe'
    if (!(Test-Path $msbuild)) { throw 'MSBuild fehlt' }
    if (!(Test-Path (Join-Path $Src 'everything.sln'))) { throw 'SDK-Solution fehlt; createallprojects.bat im SDK src ausfuehren' }
    $vc = Get-ChildItem (Join-Path $vs 'VC\Tools\MSVC') -Directory -ErrorAction SilentlyContinue
    if (!$vc) { throw 'MSVC fehlt' }
    Write-Host "VS: $vs"
    Write-Host "MSVC: $(($vc.Name) -join ', ')"
    Write-Host "SDK: $Sdk"
    return $msbuild
}
function Build-Game {
    $msbuild = Check-Prerequisites
    $projects = @('client_win64_hl2mp.vcxproj','server_win64_hl2mp.vcxproj')
    foreach ($project in $projects) {
        $matches = @(Get-ChildItem -Path $Src -Filter $project -File -Recurse -ErrorAction Stop)
        if ($matches.Count -ne 1) {
            throw "Erwartet genau ein Projekt '$project', gefunden: $($matches.Count). createallprojects.bat pruefen."
        }
        $path = $matches[0].FullName
        Write-Host "Projekt gefunden: $path"
        $log = Join-Path $LogDir ($project + '.log')
        Write-Host "Baue $project (Release x64)"
        & $msbuild $path '/p:Configuration=Release' '/p:Platform=x64' '/m:4' '/v:minimal' "/flp:logfile=$log;verbosity=normal"
        if ($LASTEXITCODE -ne 0) { Write-Host "Fehlerauszug:"; Select-String -Path $log -Pattern 'error C[0-9]+|error MSB[0-9]+|fatal error|error LNK[0-9]+' | Select-Object -First 20; throw "Build fehlgeschlagen: $project (Log: $log)" }
    }
    Write-Host 'Client- und Server-Build erfolgreich.' -ForegroundColor Green
}
function Update-Local {
    Push-Location $Root
    try {
        $dirty = @(git status --porcelain)
        if ($LASTEXITCODE -ne 0) { throw 'Git Status fehlgeschlagen' }
        if ($dirty.Count -gt 0) { throw 'Lokale Aenderungen vorhanden: Update abgebrochen.' }
        git pull --ff-only
        if ($LASTEXITCODE -ne 0) { throw 'Git update fehlgeschlagen' }
    } finally { Pop-Location }
}
function Build-TestMap {
    $generator = Join-Path $Root 'tools\generate-map.ps1'
    $vmf = Join-Path $Root 'maps\ac_test_01.vmf'
    & $generator -OutputPath $vmf
    if (!(Test-Path $vmf)) { throw "Map-Generator fehlgeschlagen" }
    $searchPaths = @((Join-Path $SteamBase 'bin'),(Join-Path $SteamBase 'sdktools'),(Join-Path $Sdk 'game'),(Join-Path $Sdk 'src'))
    $toolPaths = @{}
    foreach ($name in @('vbsp.exe','vvis.exe','vrad.exe')) {
        $found = @()
        foreach ($dir in $searchPaths) {
            if (Test-Path $dir) { $found += @(Get-ChildItem -Path $dir -Filter $name -Recurse -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName) }
        }
        if ($found.Count -eq 0) { throw "Map-Compiler fehlt: $name. VMF ist erzeugt: $vmf" }
        $toolPaths[$name] = $found[0]
        Write-Host "$name : $($found[0])"
    }
    $mapBase = [System.IO.Path]::ChangeExtension($vmf,$null)
    foreach ($name in @('vbsp.exe','vvis.exe','vrad.exe')) {
        Write-Host "Map-Compile: $name"
        & $toolPaths[$name] '-game' $ModPath $mapBase
        if ($LASTEXITCODE -ne 0) { throw "$name fehlgeschlagen: Exit $LASTEXITCODE" }
    }
    $bsp = "$mapBase.bsp"
    if (!(Test-Path $bsp)) { throw "BSP wurde nicht erzeugt: $bsp" }
    $target = Join-Path $ModPath 'maps\ac_test_01.bsp'
    New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
    Copy-Item -Path $bsp -Destination $target -Force
    Write-Host "Map bereit: $target" -ForegroundColor Green
}
switch ($Action) {
    'help' { Write-Host 'Alien Crisis SDK: .\ac.ps1 check|setup|build|map|test|logs|update|all|server|play'; Write-Host 'server/play starten nur den Valve SDK-Basistest (noch keine AC-Map).' }
    'check' { $null = Check-Prerequisites }
    'setup' { $null = Check-Prerequisites; Write-Host 'Grundvoraussetzungen vorhanden. Build mit: .\ac.ps1 build' }
    'build' { Build-Game }
    'map' { Check-Runtime; Build-TestMap }
    'test' { $null = Check-Prerequisites; Check-Runtime; Write-Host 'Build- und Runtime-Dateien vorhanden. Spielstart noch nicht bestaetigt.' }
    'logs' { Get-ChildItem $LogDir -File | Select-Object Name,Length,LastWriteTime }
    'update' { Update-Local }
    'all' { Update-Local; Build-Game; Check-Runtime; Build-TestMap; Write-Host 'Update, Build und Map-Pruefung erfolgreich.' }
    'server' {
        Check-Runtime
        $maps = @(Get-ChildItem (Join-Path $ModPath 'maps') -Filter '*.bsp' -File -ErrorAction SilentlyContinue)
        if ($maps.Count -eq 0) { throw 'Noch keine BSP-Testmap im Mod-Verzeichnis. Serverstart folgt nach Erstellung einer eigenen Testmap.' }
        $testMap = Join-Path $ModPath 'maps\ac_test_01.bsp'
        if (!(Test-Path $testMap)) { throw 'ac_test_01.bsp fehlt. Zuerst .\ac.ps1 map ausfuehren.' }
        $mapName = 'ac_test_01'
        Write-Host "Starte LAN-Dedicated-Server mit Map $mapName. Kein Port-Forwarding eingerichtet."
        & (Join-Path $SteamBase 'srcds_win64.exe') -game $ModPath -console -port 27015 +map $mapName +sv_lan 1 +maxplayers 2
    }
    'play' {
        Check-Runtime
        Write-Host 'Starte Source-SDK-Mod-Client. Dies ist noch nicht Alien Crisis, sondern der SDK-Basistest.'
        Start-Process -FilePath (Join-Path $SteamBase 'hl2_win64.exe') -WorkingDirectory $SteamBase -ArgumentList @('-game',("`"$ModPath`""),'-console')
    }
}
