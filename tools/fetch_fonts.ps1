# Recupere les polices de l'UI depuis Google Fonts, en sous-ensembles.
#
# Rejouable et deterministe, comme paint_tuxedo.py ou build_outline.py : les
# polices sont un GESTE DE STYLE, pas un binaire tombe du ciel. Si une police
# doit changer, on change ce script — on ne glisse pas un .ttf a la main.
#
#   powershell -ExecutionPolicy Bypass -File tools/fetch_fonts.ps1
#
# Pourquoi des sous-ensembles et pas les .ttf complets : les deux familles
# portent tout le japonais, soit 14 Mo et 3,7 Mo. Le sous-ensemble `latin` de
# Google fait 32 Ko et 9 Ko, couvre U+0000-00FF — donc TOUS les accents
# francais — et `latin-ext` ajoute l'oe lie pour 2 Ko. Le kana, lui, est
# DECORATIF et se reduit aux quelques mots ci-dessous : on le demande par
# `text=`, ce qui rend un fichier de quelques centaines d'octets.
#
# ⚠️ Ajouter un kana a l'UI sans l'ajouter a $Kana donne un carre vide (tofu)
# a l'ecran, silencieusement. Les deux listes doivent bouger ensemble.

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $Root "assets\fonts"
New-Item -ItemType Directory -Force $OutDir | Out-Null

# Une UA moderne : sans elle, l'API rend le .ttf complet au lieu des woff2
# decoupes par script. C'est TOUTE la difference entre 14 Mo et 32 Ko.
$UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# Les kana decoratifs reellement dessines par l'UI. Voir ui_style.gd (KANA).
$Kana = "タイムレベルライフゲームオーバーつづくネコ"

# ⚠️ Shippori Mincho B1 a ete ESSAYEE puis ECARTEE le 2026-08-16, apres analyse
# image d'Orbitals (4 min de gameplay en 720p60) : il n'y a AUCUNE mincho dans
# ce jeu. Son HUD est une grotesque techno carree, son logo une gothique lourde
# angulaire. La mincho etait un reflexe "carton d'anime" jamais verifie.
$Families = @(
    @{ Slug = "delagothicone";     Query = "Dela+Gothic+One";              Name = "DelaGothicOne" },
    @{ Slug = "zenkakugothicnew";  Query = "Zen+Kaku+Gothic+New:wght@500"; Name = "ZenKakuGothicNew-Medium" },
    @{ Slug = "zenkakugothicnew";  Query = "Zen+Kaku+Gothic+New:wght@700"; Name = "ZenKakuGothicNew-Bold" }
)

function Get-SubsetUrl($css, $subset) {
    $m = [regex]::Match($css, "/\*\s*$([regex]::Escape($subset))\s*\*/\s*@font-face\s*\{[^}]*?src:\s*url\((https://[^)]+)\)")
    if (-not $m.Success) { return $null }
    return $m.Groups[1].Value
}

foreach ($f in $Families) {
    $css = (Invoke-WebRequest -Uri "https://fonts.googleapis.com/css2?family=$($f.Query)&display=swap" `
        -UseBasicParsing -UserAgent $UA -TimeoutSec 60).Content

    foreach ($subset in @("latin", "latin-ext")) {
        $url = Get-SubsetUrl $css $subset
        if (-not $url) { Write-Warning "$($f.Name) : sous-ensemble '$subset' introuvable"; continue }
        $out = Join-Path $OutDir "$($f.Name).$subset.woff2"
        Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -TimeoutSec 60
        Write-Output ("{0,-26} {1,-10} {2,5} Ko" -f $f.Name, $subset, [math]::Round((Get-Item $out).Length / 1KB, 1))
    }

    # Le kana, demande caractere par caractere. `text=` rend UN seul @font-face.
    $enc = [System.Uri]::EscapeDataString($Kana)
    $cssKana = (Invoke-WebRequest -Uri "https://fonts.googleapis.com/css2?family=$($f.Query)&text=$enc" `
        -UseBasicParsing -UserAgent $UA -TimeoutSec 60).Content
    $urlKana = [regex]::Match($cssKana, 'src:\s*url\((https://[^)]+)\)').Groups[1].Value
    $outKana = Join-Path $OutDir "$($f.Name).kana.woff2"
    Invoke-WebRequest -Uri $urlKana -OutFile $outKana -UseBasicParsing -TimeoutSec 60
    Write-Output ("{0,-26} {1,-10} {2,5} Ko" -f $f.Name, "kana", [math]::Round((Get-Item $outKana).Length / 1KB, 1))
}

# La licence OFL EXIGE d'accompagner les fichiers redistribues. Ce n'est pas
# une politesse : sans elle, le depot n'a pas le droit de porter les polices.
foreach ($slug in @("delagothicone", "zenkakugothicnew")) {
    $out = Join-Path $OutDir "OFL-$slug.txt"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/google/fonts/main/ofl/$slug/OFL.txt" `
        -OutFile $out -UseBasicParsing -TimeoutSec 60
    Write-Output ("{0,-26} {1,-10} {2,5} Ko" -f "OFL-$slug.txt", "licence", [math]::Round((Get-Item $out).Length / 1KB, 1))
}

Write-Output ""
Write-Output "Polices ecrites dans assets/fonts/. Reimporter :"
Write-Output '  "C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64.exe" --headless --import --path .'
