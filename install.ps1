# install.ps1
# Instala o salvamento/restauração de sessões do Claude Code.
#   .\install.ps1               -> instala hooks + atalhos na Área de Trabalho
#   .\install.ps1 -AutoStart    -> também restaura sozinho ao fazer login no Windows
param([switch]$AutoStart)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding $false

$claudeDir  = Join-Path $env:USERPROFILE '.claude'
$scriptsDir = Join-Path $claudeDir 'scripts'
New-Item -ItemType Directory -Force -Path $scriptsDir | Out-Null

foreach ($f in 'session-track.ps1', 'restore-sessions.ps1', 'claude-restore.ico') {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $f) -Destination $scriptsDir -Force
}
Write-Host "Scripts copiados para $scriptsDir"

# ---- Hooks no ~/.claude/settings.json (com backup) ----
$trackPath    = (Join-Path $scriptsDir 'session-track.ps1') -replace '\\', '/'
$settingsPath = Join-Path $claudeDir 'settings.json'

if (Test-Path -LiteralPath $settingsPath) {
    $bak = "$settingsPath.bak-$(Get-Date -Format yyyyMMddHHmmss)"
    Copy-Item -LiteralPath $settingsPath -Destination $bak
    Write-Host "Backup do settings.json: $bak"
    $settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
}
if (-not $settings) { $settings = New-Object psobject }

if (-not $settings.PSObject.Properties['hooks']) {
    $settings | Add-Member -NotePropertyName hooks -NotePropertyValue (New-Object psobject)
}

foreach ($evt in 'SessionStart', 'SessionEnd') {
    $mode = if ($evt -eq 'SessionStart') { 'start' } else { 'end' }
    $command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$trackPath`" $mode"

    $list = @()
    if ($settings.hooks.PSObject.Properties[$evt]) { $list = @($settings.hooks.$evt) }

    $jaExiste = $list | Where-Object { $_.hooks | Where-Object { $_.command -like '*session-track.ps1*' } }
    if (-not $jaExiste) {
        $list += [pscustomobject]@{
            hooks = @([pscustomobject]@{ type = 'command'; command = $command; timeout = 10 })
        }
        Write-Host "Hook $evt adicionado."
    }
    else { Write-Host "Hook $evt já existia." }

    $settings.hooks | Add-Member -NotePropertyName $evt -NotePropertyValue $list -Force
}

[IO.File]::WriteAllText($settingsPath, ($settings | ConvertTo-Json -Depth 32), $utf8)

# ---- Atalhos ----
$restorePath = Join-Path $scriptsDir 'restore-sessions.ps1'
$ws = New-Object -ComObject WScript.Shell

function New-Atalho($caminho, $extra) {
    $lnk = $ws.CreateShortcut($caminho)
    $lnk.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$restorePath`" $extra"
    $lnk.WorkingDirectory = $env:USERPROFILE
    $lnk.IconLocation = "$(Join-Path $scriptsDir 'claude-restore.ico'),0"
    $lnk.Save()
    Write-Host "Atalho criado: $caminho"
}

$desktop = [Environment]::GetFolderPath('Desktop')
New-Atalho (Join-Path $desktop 'Restaurar Claude Code.lnk') ''
New-Atalho (Join-Path $desktop 'Restaurar Claude Code (escolher).lnk') '-Escolher'

if ($AutoStart) {
    $startup = [Environment]::GetFolderPath('Startup')
    New-Atalho (Join-Path $startup 'Restaurar Claude Code.lnk') ''
}

Write-Host "`nPronto. Sessões do Claude Code abertas a partir de agora serão registradas."
