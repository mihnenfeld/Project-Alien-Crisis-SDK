param(
    [ValidateSet('help','check','setup','build','test','logs','update','all','server','play')]
    [string]$Action = 'help'
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Sdk = 'C:\Dev\source-sdk-2013'
$Src = Join-Path $Sdk 'src'
$LogDir = Join-Path $Root 'logs'
New-Item -ItemType Directory -Force $LogDir | Out-Null
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
        $path = Join-Path $Src $project
        if (!(Test-Path $path)) { throw "Projekt fehlt: $path" }
        $log = Join-Path $LogDir ($project + '.log')
        Write-Host "Baue $project (Release x64)"
        & $msbuild $path '/p:Configuration=Release' '/p:Platform=x64' '/m:4' '/v:minimal' "/flp:logfile=$log;verbosity=normal"
        if ($LASTEXITCODE -ne 0) { Write-Host "Fehlerauszug:"; Select-String -Path $log -Pattern 'error C[0-9]+|error MSB[0-9]+|fatal error|error LNK[0-9]+' | Select-Object -First 20; throw "Build fehlgeschlagen: $project (Log: $log)" }
    }
    Write-Host 'Client- und Server-Build erfolgreich.' -ForegroundColor Green
}
switch ($Action) {
    'help' { Write-Host 'Alien Crisis SDK: .\ac.ps1 check|setup|build|test|logs|update|all'; Write-Host 'server/play folgen nach erfolgreichem Build und Mod-Installation.' }
    'check' { $null = Check-Prerequisites }
    'setup' { $null = Check-Prerequisites; Write-Host 'Grundvoraussetzungen vorhanden. Build mit: .\ac.ps1 build' }
    'build' { Build-Game }
    'test' { $null = Check-Prerequisites; Write-Host 'Vorbedingungen OK; Ingame-Tests noch nicht automatisiert.' }
    'logs' { Get-ChildItem $LogDir -File | Select-Object Name,Length,LastWriteTime }
    'update' {
        Push-Location $Root
        try {
            if ((git status --porcelain).Length -gt 0) { throw 'Lokale Aenderungen vorhanden: Update abgebrochen.' }
            git pull --ff-only
            if ($LASTEXITCODE -ne 0) { throw 'Git update fehlgeschlagen' }
        } finally { Pop-Location }
    }
    'all' { $null = Check-Prerequisites; Build-Game; Write-Host 'Build OK. Spielstart wird im naechsten Meilenstein eingerichtet.' }
    'server' { throw 'Dedicated-Server-Start noch nicht konfiguriert. Erst Basis-Build validieren.' }
    'play' { throw 'Alien-Crisis-Mod noch nicht installiert. Erst Basis-Build validieren.' }
}
