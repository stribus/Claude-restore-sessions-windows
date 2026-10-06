# restore-sessions.ps1
# Reabre no Windows Terminal as sessões do Claude Code que estavam abertas.
#   (sem parâmetros)  -> reabre todas
#   -Escolher         -> mostra uma lista para você marcar quais reabrir
#   -MaxAgeDays N     -> ignora sessões sem atividade há mais de N dias (padrão 5)
param(
    [switch]$Escolher,
    [int]$MaxAgeDays = 5
)

$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:USERPROFILE '.claude\session-registry'

function Show-Popup($msg) {
    (New-Object -ComObject WScript.Shell).Popup($msg, 0, 'Restaurar Claude Code', 64) | Out-Null
}

$files = @(Get-ChildItem -LiteralPath $dir -Filter '*.json' -File -ErrorAction SilentlyContinue)
if ($files.Count -eq 0) { Show-Popup 'Nenhuma sessão registrada para restaurar.'; exit 0 }

$limite = (Get-Date).AddDays(-$MaxAgeDays)
$sessoes = foreach ($f in $files) {
    try { $e = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
    if (-not $e.cwd -or -not (Test-Path -LiteralPath $e.cwd)) { continue }
    # Sem transcript = sessão aberta mas nunca usada; --resume falharia.
    if (-not $e.transcript_path -or -not (Test-Path -LiteralPath $e.transcript_path)) { continue }
    $ultima = (Get-Item -LiteralPath $e.transcript_path).LastWriteTime
    if ($ultima -lt $limite) { continue }
    [pscustomobject]@{
        Projeto         = Split-Path $e.cwd -Leaf
        UltimaAtividade = $ultima
        Pasta           = $e.cwd
        SessionId       = $e.session_id
    }
}
$sessoes = @($sessoes | Sort-Object UltimaAtividade)

if ($sessoes.Count -eq 0) {
    Show-Popup 'Nenhuma sessão recente encontrada para restaurar.'
    exit 0
}

if ($Escolher) {
    $sel = @($sessoes | Out-GridView -Title 'Marque as sessões para reabrir (Ctrl+A = todas) e clique OK' -PassThru)
    if ($sel.Count -eq 0) { exit 0 }
}
else { $sel = $sessoes }

# Arquiva o registro atual: as sessões retomadas vão se registrar de novo pelo hook,
# então isso evita duplicatas e "sessões fantasma" na próxima restauração.
$arquivo = Join-Path $dir ("_restaurado-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $arquivo | Out-Null
$files | Move-Item -Destination $arquivo -Force
Get-ChildItem -LiteralPath $dir -Directory -Filter '_restaurado-*' |
    Sort-Object Name -Descending | Select-Object -Skip 5 |
    Remove-Item -Recurse -Force

$wt = Get-Command wt.exe -ErrorAction SilentlyContinue
$shell = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { 'pwsh.exe' } else { 'powershell.exe' }

foreach ($s in $sel) {
    $pasta = $s.Pasta
    if ($pasta.Length -gt 3) { $pasta = $pasta.TrimEnd('\') }   # barra final quebra as aspas no wt
    $cmd = "claude --resume $($s.SessionId)"

    if ($wt) {
        Start-Process wt.exe -ArgumentList @(
            '-w', 'claude-restore', 'new-tab',
            '-d', "`"$pasta`"",
            '--title', "`"$($s.Projeto)`"", '--suppressApplicationTitle',
            $shell, '-NoExit', '-Command', $cmd
        )
        Start-Sleep -Milliseconds 800
    }
    else {
        Start-Process $shell -WorkingDirectory $s.Pasta -ArgumentList '-NoExit', '-Command', $cmd
    }
}
