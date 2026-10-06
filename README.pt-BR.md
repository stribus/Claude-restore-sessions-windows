# Claude-restore-sessions-windows

[English](README.md) | **Português**

Salva as sessões do [Claude Code](https://docs.claude.com/en/docs/claude-code) que estão abertas e, depois de um reboot, reabre todas no Windows Terminal com 2 cliques, cada uma em sua pasta e retomando a conversa (`claude --resume <id>`).

## Como funciona

- O hook **SessionStart** grava um arquivo por sessão em `~/.claude/session-registry` (`session_id`, pasta, transcript).
- O hook **SessionEnd** apaga esse arquivo quando você sai normalmente (`/exit`, Ctrl+C, `/clear`, logout).
- Num reboot forçado o processo morre e o arquivo fica para trás. Assim, o registro guarda exatamente as sessões que estavam abertas.
- O atalho **Restaurar Claude Code** lê o registro e abre uma aba do Windows Terminal para cada sessão.

| Arquivo | Função |
| --- | --- |
| `install.ps1` | Copia os scripts, configura os hooks e cria os atalhos |
| `session-track.ps1` | Chamado pelos hooks; mantém o registro de sessões abertas |
| `restore-sessions.ps1` | Reabre as sessões registradas |
| `claude-restore.ico` | Ícone dos atalhos |

## Requisitos

- Windows 10/11 com o Claude Code instalado (`claude` no PATH)
- [Windows Terminal](https://aka.ms/terminal) (`wt.exe`) é recomendado. Sem ele, cada sessão abre numa janela de PowerShell separada.
- PowerShell 7 (`pwsh`) é recomendado para rodar o instalador. Ele também funciona no Windows PowerShell 5.1, mas aí o `settings.json` fica com uma formatação mais feia.

## Instalação

1. Clone o repositório:

   ```powershell
   git clone https://github.com/stribus/Claude-restore-sessions-windows.git
   cd Claude-restore-sessions-windows
   ```

2. Rode o instalador:

   ```powershell
   pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
   ```

   Para restaurar automaticamente ao fazer login no Windows, adicione `-AutoStart`:

   ```powershell
   pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -AutoStart
   ```

O instalador:

- copia `session-track.ps1`, `restore-sessions.ps1` e `claude-restore.ico` para `~/.claude/scripts`;
- adiciona os hooks `SessionStart` e `SessionEnd` em `~/.claude/settings.json`, depois de fazer um backup (`settings.json.bak-<timestamp>`), preservando os hooks e configurações que você já tem;
- cria na Área de Trabalho os atalhos **Restaurar Claude Code** e **Restaurar Claude Code (escolher)**;
- com `-AutoStart`, também cria um atalho na pasta Inicializar do Windows.

Pode rodar de novo sem problema: os hooks não são duplicados.

> Sessões que já estavam abertas durante a instalação não foram registradas. Reabra-as, ou rode `/clear`, para o hook pegá-las.

## Testando

1. Abra 2 sessões do `claude` em projetos diferentes e mande ao menos uma mensagem em cada.
2. Confira se aparecem 2 arquivos `.json` em `~/.claude/session-registry`. Dentro do Claude, `/hooks` deve listar `SessionStart` e `SessionEnd`.
3. Feche a janela do terminal no **X**, para simular o reboot.
4. Dê dois cliques em **Restaurar Claude Code**. Devem abrir 2 abas no Windows Terminal, cada uma retomando a sua conversa.

## Uso

- **Restaurar Claude Code**: reabre todas as sessões registradas.
- **Restaurar Claude Code (escolher)**: abre uma lista para você marcar quais sessões reabrir.

Também dá para rodar direto:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\scripts\restore-sessions.ps1" [-Escolher] [-MaxAgeDays 5]
```

## Pontos de atenção

- **Saia com `/exit`** das sessões que não quer de volta. Fechar a aba no X conta como "estava aberta", e ela volta na próxima restauração.
- **Sessões antigas são ignoradas.** Sessões sem atividade há mais de 5 dias ficam de fora (ajuste com `-MaxAgeDays`), assim como sessões abertas e nunca usadas, em que o `--resume` falharia.
- **Não rode o atalho com as sessões ainda abertas**, senão elas duplicam. Ele foi feito para usar logo depois do reboot.
- **GPO de segurança:** se a política da empresa bloquear `-ExecutionPolicy Bypass`, os hooks falham sem mostrar erro e nada é registrado. Para verificar, rode `Get-ExecutionPolicy -List`: `MachinePolicy` e `UserPolicy` devem estar como `Undefined`.
- Várias sessões na mesma pasta funcionam normalmente, porque o controle é feito pelo `session_id` de cada uma, não pela pasta.
- A cada restauração o registro anterior é arquivado em `~/.claude/session-registry/_restaurado-<data>`. Só os 5 mais recentes são mantidos.

## Desinstalação

1. Remova as entradas `SessionStart`/`SessionEnd` que chamam `session-track.ps1` em `~/.claude/settings.json`, ou restaure o backup `settings.json.bak-<timestamp>`.
2. Apague `~/.claude/scripts/session-track.ps1`, `~/.claude/scripts/restore-sessions.ps1`, `~/.claude/scripts/claude-restore.ico` e a pasta `~/.claude/session-registry`.
3. Apague os atalhos da Área de Trabalho e, se usou `-AutoStart`, também o da pasta Inicializar (`shell:startup`).
