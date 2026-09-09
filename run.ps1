<#
.SYNOPSIS
    Inicia o app FitEvo no Android ou iOS com um único comando.
.DESCRIPTION
    - Android: inicia o emulador automaticamente se necessário, espera boot e roda flutter run.
    - iOS: abre o simulador e roda flutter run (só funciona no macOS).
.PARAMETER platform
    'android' ou 'ios'. Default: detecta automaticamente (preferência Android).
.EXAMPLE
    .\run.ps1
    .\run.ps1 android
    .\run.ps1 ios
#>
param(
    [ValidateSet('android', 'ios')]
    [string]$platform = ''
)

$ErrorActionPreference = 'Stop'

function Get-FlutterDeviceId {
    $devices = flutter devices 2>$null
    $lines = $devices -split "`n" | Where-Object { $_ -match '•' -and $_ -notmatch '^Found' }
    $first = ($lines | Select-Object -First 1) -split '•' | Select-Object -First 1
    return $first.Trim()
}

function Wait-EmulatorBoot {
    Write-Host "Aguardando emulador bootar..." -ForegroundColor Yellow
    adb wait-for-device
    # Poll ate sys.boot_completed == 1
    $timeout = 120
    $elapsed = 0
    while ($elapsed -lt $timeout) {
        $val = adb shell getprop sys.boot_completed 2>$null
        if ($val -match '1') {
            Write-Host "Emulador pronto!" -ForegroundColor Green
            return
        }
        Start-Sleep -Seconds 2
        $elapsed += 2
        Write-Host "." -NoNewline
    }
    Write-Host ""
    Write-Host "Timeout aguardando emulador. Continuando mesmo assim..." -ForegroundColor Yellow
}

function Start-Android {
    $devices = adb devices 2>$null
    if ($devices -match 'emulator-\d+\s+device') {
        Write-Host "Emulador Android ja esta rodando." -ForegroundColor Green
    } else {
        Write-Host "Iniciando emulador Android..." -ForegroundColor Cyan
        $emulators = flutter emulators 2>$null
        if ($emulators -match 'Pixel_7_API_36') {
            Start-Process -FilePath "flutter" -ArgumentList "emulators --launch Pixel_7_API_36" -NoNewWindow
        } else {
            # Fallback: qualquer emulador disponivel
            Start-Process -FilePath "flutter" -ArgumentList "emulators --launch" -NoNewWindow
        }
        Wait-EmulatorBoot
    }
    $deviceId = Get-FlutterDeviceId
    Write-Host "Rodando flutter run -d $deviceId..." -ForegroundColor Cyan
    flutter run -d $deviceId
}

function Start-IOS {
    if (-not $IsMacOS) {
        Write-Host "iOS so funciona no macOS. Use 'flutter run -d ios' no Mac." -ForegroundColor Red
        Write-Host "Alternativa: use Android com '.\run.ps1 android'" -ForegroundColor Yellow
        exit 1
    }
    # Abre o simulador se nao estiver aberto
    $running = xcrun simctl list devices booted 2>$null
    if ($running -notmatch 'Booted') {
        Write-Host "Abrindo simulador iOS..." -ForegroundColor Cyan
        open -a Simulator
        Start-Sleep -Seconds 5
    }
    $deviceId = Get-FlutterDeviceId
    Write-Host "Rodando flutter run -d $deviceId..." -ForegroundColor Cyan
    flutter run -d $deviceId
}

# --- Main ---
Write-Host ""
Write-Host "=== FitEvo Runner ===" -ForegroundColor Magenta
Write-Host ""

if ($platform -eq 'ios') {
    Start-IOS
} elseif ($platform -eq 'android') {
    Start-Android
} else {
    # Auto-detect: Windows/Linux -> Android, macOS -> pergunta ou usa Android
    if ($IsMacOS) {
        # No macOS, tenta iOS se tiver simulador, senao Android
        $hasSimulator = xcrun simctl list devices available 2>$null
        if ($hasSimulator -match 'iPhone') {
            Start-IOS
        } else {
            Start-Android
        }
    } else {
        Start-Android
    }
}
