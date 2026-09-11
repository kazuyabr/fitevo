<#
.SYNOPSIS
    Inicia o app VivaSaudavel no Android ou iOS com um único comando.
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

# Resolve o caminho do Flutter (PATH do usuario, ou fallback comum em Windows).
function Resolve-Flutter {
    $cmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($p in @('C:\flutter-git\bin\flutter.bat', "$env:USERPROFILE\flutter\bin\flutter.bat", "$env:LOCALAPPDATA\flutter\bin\flutter.bat")) {
        if (Test-Path $p) { return $p }
    }
    return 'flutter'
}
$script:Flutter = Resolve-Flutter

function Get-AndroidAvdId {
    # Prefere o emulator.exe do Android SDK (listagem autoritativa de AVDs).
    $emu = ''
    if ($env:ANDROID_HOME -and (Test-Path "$env:ANDROID_HOME\emulator\emulator.exe")) {
        $emu = "$env:ANDROID_HOME\emulator\emulator.exe"
    } elseif ($env:ANDROID_SDK_ROOT -and (Test-Path "$env:ANDROID_SDK_ROOT\emulator\emulator.exe")) {
        $emu = "$env:ANDROID_SDK_ROOT\emulator\emulator.exe"
    }
    if ($emu) {
        $avds = & $emu -list-avds 2>$null | Where-Object { $_.Trim() }
        if ($avds) {
            # Prefer VivaSaudavel (AVD principal do projeto).
            $pref = $avds | Where-Object { $_ -match 'VivaSaudavel' } | Select-Object -First 1
            if (-not $pref) { $pref = $avds | Where-Object { $_ -match 'GoogleAPIs' } | Select-Object -First 1 }
            if (-not $pref) { $pref = $avds | Where-Object { $_ -match 'Pixel' } | Select-Object -First 1 }
            if (-not $pref) { $pref = $avds | Select-Object -First 1 }
            return $pref.Trim()
        }
    }
    return ''
}

function Get-FlutterDeviceId {
    param([string]$platform = '')
    # 1) Fonte principal: JSON do flutter devices --machine (robusto,
    #    independente de encoding/caracteres especiais).
    $json = & $script:Flutter devices --machine 2>$null
    if ($json) {
        try {
            $devices = $json | ConvertFrom-Json
            if ($devices) {
                if ($platform -eq 'ios') {
                    $d = $devices |
                        Where-Object { $_.targetPlatform -like 'ios*' } |
                        Select-Object -First 1
                } else {
                    $d = $devices |
                        Where-Object { $_.emulator -or $_.targetPlatform -like 'android*' } |
                        Select-Object -First 1
                }
                if ($d -and $d.id) { return $d.id }
                $d = $devices | Where-Object { $_.isSupported } | Select-Object -First 1
                if ($d -and $d.id) { return $d.id }
            }
        } catch { }
    }
    # 2) Fallback: adb devices (serial do emulador via adb).
    $adb = adb devices 2>$null
    $m = $adb | Select-String -Pattern '^(\S+)\s+device$' | Select-Object -First 1
    if ($m) { return $m.Matches[0].Groups[1].Value }
    return ''
}

function Wait-DeviceId {
    param([string]$wanted = '')
    # Aguarda o Flutter listar o device (pode levar alguns segundos apos o boot).
    $timeout = 60
    $elapsed = 0
    while ($elapsed -lt $timeout) {
        $id = Get-FlutterDeviceId $wanted
        if ($id) { return $id }
        Start-Sleep -Seconds 3
        $elapsed += 3
        Write-Host "." -NoNewline
    }
    Write-Host ""
    return ''
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
        $avd = Get-AndroidAvdId
        if ($avd) {
            Write-Host "AVD: $avd" -ForegroundColor DarkGray
            & $script:Flutter emulators --launch $avd
        } else {
            Write-Host "Nenhum AVD encontrado; tentando lancar qualquer um..." -ForegroundColor Yellow
            & $script:Flutter emulators --launch
        }
        Wait-EmulatorBoot
    }

    # Corrige fuso horário do emulador (padrão GMT → America/Sao_Paulo).
    # AlarmManager service call não requer root; funciona em qualquer AVD.
    Write-Host "Configurando fuso horário do emulador..." -ForegroundColor DarkGray
    try {
        $currentTz = & adb shell getprop persist.sys.timezone 2>$null
        if ($currentTz -ne 'America/Sao_Paulo') {
            & adb shell service call alarm 3 s16 America/Sao_Paulo 2>$null | Out-Null
        }
        Write-Host "Fuso: America/Sao_Paulo" -ForegroundColor DarkGray
    } catch {
        Write-Host "Não foi possível configurar fuso (ok em device real)." -ForegroundColor DarkGray
    }

    # Configura navegação (3 botões) e teclado do host.
    Write-Host "Configurando navegação e teclado..." -ForegroundColor DarkGray
    try {
        & adb shell settings put secure navigation_mode 0 2>$null | Out-Null
        & adb shell cmd overlay enable com.android.internal.systemui.navbar.threebutton 2>$null | Out-Null
        & adb shell settings put secure show_ime_with_hard_keyboard 1 2>$null | Out-Null
        Write-Host "Nav: 3 botões | Teclado: host habilitado" -ForegroundColor DarkGray
    } catch {
        Write-Host "Não foi possível configurar nav/teclado (ok em device real)." -ForegroundColor DarkGray
    }

    $deviceId = Wait-DeviceId 'android'
    if ([string]::IsNullOrWhiteSpace($deviceId)) {
        Write-Host "Nenhum device Android detectado. Verifique se o emulador esta ativo." -ForegroundColor Red
        exit 1
    }
    Write-Host ""
    Write-Host "Rodando flutter run -d $deviceId..." -ForegroundColor Cyan
    # --android-skip-build-dependency-validation: silencia os warnings de
    # versao do toolchain (Gradle/AGP/Kotlin) que nao bloqueiam o build.
    & $script:Flutter run -d $deviceId --android-skip-build-dependency-validation @DefineArgs
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
    $deviceId = Wait-DeviceId 'ios'
    if ([string]::IsNullOrWhiteSpace($deviceId)) {
        Write-Host "Nenhum simulador iOS detectado. Verifique o Xcode e o simulador." -ForegroundColor Red
        exit 1
    }
    Write-Host ""
    Write-Host "Rodando flutter run -d $deviceId..." -ForegroundColor Cyan
    & $script:Flutter run -d $deviceId @DefineArgs
}

# --- Main ---
Write-Host ""
Write-Host "=== VivaSaudavel Runner ===" -ForegroundColor Magenta
Write-Host ""

# Injeta env.json (se existir) via --dart-define-from-file.
# NUNCA commite env.json; use env.json.sample como template.
$DefineArgs = @()
$envFile = Join-Path $PSScriptRoot 'env.json'
if (Test-Path $envFile) {
    $DefineArgs = @("--dart-define-from-file=$envFile")
    Write-Host "env.json encontrado: credenciais serao injetadas." -ForegroundColor DarkGray
} else {
    Write-Host "env.json nao encontrado (opcional). Template: env.json.sample" -ForegroundColor DarkGray
}
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
