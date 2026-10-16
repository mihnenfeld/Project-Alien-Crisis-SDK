param([string]$OutputPath = (Join-Path $PSScriptRoot 'maps\ac_test_01.vmf'))
$ErrorActionPreference = 'Stop'
$script:nextId = 2
$script:blocks = [System.Collections.Generic.List[string]]::new()
function Next-Id { $script:nextId++; return $script:nextId }
function Brush([int]$x1,[int]$y1,[int]$z1,[int]$x2,[int]$y2,[int]$z2,[string]$texture = 'BRICK/BRICKWALL001A') {
    $faces = @(
        "($x1 $y1 $z2) ($x2 $y1 $z2) ($x2 $y2 $z2)",
        "($x1 $y2 $z1) ($x2 $y2 $z1) ($x2 $y1 $z1)",
        "($x1 $y1 $z1) ($x1 $y1 $z2) ($x1 $y2 $z2)",
        "($x2 $y2 $z1) ($x2 $y2 $z2) ($x2 $y1 $z2)",
        "($x2 $y1 $z1) ($x2 $y1 $z2) ($x1 $y1 $z2)",
        "($x1 $y2 $z1) ($x1 $y2 $z2) ($x2 $y2 $z2)"
    )
    $solidId = Next-Id
    $sides = foreach ($face in $faces) {
        $id = Next-Id
        @"
side
{
    "id" "$id"
    "plane" "$face"
    "material" "$texture"
    "uaxis" "[1 0 0 0] 0.25"
    "vaxis" "[0 -1 0 0] 0.25"
    "rotation" "0"
    "lightmapscale" "16"
    "smoothing_groups" "0"
}
"@
    }
    $script:blocks.Add("solid { `"id`" `"$solidId`" `n$($sides -join "`n")`n}")
}
function Point([string]$class,[int]$x,[int]$y,[int]$z,[hashtable]$props=@{}) {
    $id=Next-Id
    $values=($props.GetEnumerator() | ForEach-Object { '    "'+$_.Key+'" "'+$_.Value+'"' }) -join "`n"
    $script:blocks.Add("entity {`n`"id`" `"$id`"`n`"classname`" `"$class`"`n`"origin`" `"$x $y $z`"`n$values`n}")
}
# Sealed shell: two chambers and a wide opening in the central divider.
Brush -576 -320 -32 576 320 0 'CONCRETE/CONCRETEFLOOR001A'
Brush -576 -320 256 576 320 288
Brush -608 -352 -32 -576 352 288
Brush 576 -352 -32 608 352 288
Brush -576 -352 -32 576 -320 288
Brush -576 320 -32 576 352 288
# Divider leaves 128-unit passage centred on Y=0, full player headroom.
Brush -24 -320 0 24 -80 256
Brush -24 80 0 24 320 256
Brush -24 -80 208 24 80 256
Point 'info_player_deathmatch' -288 -80 16 @{ angles='0 0 0' }
Point 'info_player_deathmatch' -288 80 16 @{ angles='0 0 0' }
Point 'info_player_start' -384 0 16 @{ angles='0 0 0' }
Point 'light' -300 0 192 @{ _light='255 225 185 500'; _constant_attn='0' }
Point 'light' 300 0 192 @{ _light='175 220 255 500'; _constant_attn='0' }
$world = ($script:blocks | Where-Object { $_ -like 'solid*' }) -join "`n"
$entities = ($script:blocks | Where-Object { $_ -like 'entity*' }) -join "`n"
$vmf=@"
versioninfo { "editorversion" "400" "editorbuild" "0" "mapversion" "1" "formatversion" "100" "prefab" "0" }
visgroups {}
viewsettings { "bSnapToGrid" "1" "bShowGrid" "1" "bShowLogicalGrid" "0" "nGridSpacing" "16" }
world
{
    "id" "1"
    "mapversion" "1"
    "classname" "worldspawn"
    "skyname" "sky_day01_01"
    $world
}
$entities
cameras { "activecamera" "-1" }
cordons { "active" "0" }
"@
New-Item -ItemType Directory -Force (Split-Path $OutputPath -Parent) | Out-Null
[System.IO.File]::WriteAllText($OutputPath, $vmf, [System.Text.UTF8Encoding]::new($false))
Write-Host "VMF erzeugt: $OutputPath"
