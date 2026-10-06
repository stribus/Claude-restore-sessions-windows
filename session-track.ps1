# session-track.ps1
# Chamado pelos hooks SessionStart/SessionEnd do Claude Code.
# Mantém em ~/.claude/session-registry um arquivo por sessão aberta.
# IMPORTANTE: não escrever nada no stdout (o stdout do SessionStart vai para o contexto do Claude).
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('start', 'end')]
    [string]$Mode
)

$ErrorActionPreference = 'SilentlyContinue'
try {
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    $raw = [Console]::In.ReadToEnd()
    if (-not $raw) { exit 0 }

    $data = $raw | ConvertFrom-Json
    $id = $data.session_id
    if (-not $id) { exit 0 }

    $dir = Join-Path $env:USERPROFILE '.claude\session-registry'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $file = Join-Path $dir "$id.json"

    if ($Mode -eq 'start') {
        $entry = [ordered]@{
            session_id      = $id
            cwd             = $data.cwd
            transcript_path = $data.transcript_path
            source          = $data.source
            started_at      = (Get-Date).ToString('o')
        }
        $json = $entry | ConvertTo-Json
        [IO.File]::WriteAllText($file, $json, (New-Object System.Text.UTF8Encoding $false))
    }
    else {
        # reason 'other' = encerramento não interativo (pode ser o próprio reboot) -> mantém no registro.
        # /exit, Ctrl+C, /clear, logout -> remove.
        if ($data.reason -ne 'other') {
            Remove-Item -LiteralPath $file -Force
        }
    }
}
catch { }
exit 0
