# Claude-restore-sessions-windows

**English** | [Português](README.pt-BR.md)

A set of PowerShell scripts that remembers which [Claude Code](https://docs.claude.com/en/docs/claude-code) sessions you had open and, after a Windows reboot, reopens all of them in Windows Terminal with a double-click. Each session reopens in its own folder and resumes its conversation (`claude --resume <id>`).

## How it works

- The **SessionStart** hook writes one file per session to `~/.claude/session-registry` (`session_id`, folder, transcript).
- The **SessionEnd** hook deletes that file when you exit normally (`/exit`, Ctrl+C, `/clear`, logout).
- On a forced reboot the process is killed and the file stays behind. So the registry holds exactly the sessions that were open.
- The **Restaurar Claude Code** shortcut reads the registry and opens one Windows Terminal tab per session.

| File | Purpose |
| --- | --- |
| `install.ps1` | Copies the scripts, sets up the hooks and creates the shortcuts |
| `session-track.ps1` | Called by the hooks; keeps the registry of open sessions |
| `restore-sessions.ps1` | Reopens the registered sessions |
| `claude-restore.ico` | Shortcut icon |

## Requirements

- Windows 10/11 with Claude Code installed (`claude` on the PATH)
- [Windows Terminal](https://aka.ms/terminal) (`wt.exe`) is recommended. Without it, each session opens in a separate PowerShell window.
- PowerShell 7 (`pwsh`) is recommended for running the installer. Windows PowerShell 5.1 also works, but leaves `settings.json` with uglier formatting.

## Installation

1. Clone the repository:

   ```powershell
   git clone https://github.com/stribus/Claude-restore-sessions-windows.git
   cd Claude-restore-sessions-windows
   ```

2. Run the installer:

   ```powershell
   pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
   ```

   To restore automatically when you log in to Windows, add `-AutoStart`:

   ```powershell
   pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -AutoStart
   ```

The installer:

- copies `session-track.ps1`, `restore-sessions.ps1` and `claude-restore.ico` to `~/.claude/scripts`;
- adds the `SessionStart` and `SessionEnd` hooks to `~/.claude/settings.json`, after making a backup (`settings.json.bak-<timestamp>`) and keeping any hooks and settings you already have;
- creates two desktop shortcuts: **Restaurar Claude Code** and **Restaurar Claude Code (escolher)**;
- with `-AutoStart`, also creates a shortcut in the Windows Startup folder.

It is safe to run again: the hooks are not duplicated.

> Sessions that were already open during installation are not registered. Reopen them, or run `/clear`, so the hook picks them up.

## Testing

1. Open 2 `claude` sessions in different projects and send at least one message in each.
2. Check that 2 `.json` files appear in `~/.claude/session-registry`. Inside Claude, `/hooks` should list `SessionStart` and `SessionEnd`.
3. Close the terminal window with the **X** to simulate the reboot.
4. Double-click **Restaurar Claude Code**. 2 tabs should open in Windows Terminal, each resuming its conversation.

## Usage

- **Restaurar Claude Code**: reopens all registered sessions.
- **Restaurar Claude Code (escolher)**: shows a list so you can pick which sessions to reopen.

You can also run it directly:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\scripts\restore-sessions.ps1" [-Escolher] [-MaxAgeDays 5]
```

## Caveats

- **Exit with `/exit`** from sessions you don't want back. Closing a tab with the X counts as "was open", and it comes back on the next restore.
- **Old sessions are skipped.** Sessions with no activity for more than 5 days are left out (change it with `-MaxAgeDays`), as are sessions that were opened but never used, where `--resume` would fail.
- **Don't run the shortcut while the sessions are still open**, or they will be duplicated. It is meant to be used right after the reboot.
- **Security policy (GPO):** if your company policy blocks `-ExecutionPolicy Bypass`, the hooks fail silently and nothing is registered. To check, run `Get-ExecutionPolicy -List`: `MachinePolicy` and `UserPolicy` should be `Undefined`.
- Several sessions in the same folder work fine, because tracking is done by each session's `session_id`, not by folder.
- On each restore, the previous registry is archived to `~/.claude/session-registry/_restaurado-<date>`. Only the 5 most recent are kept.

## Uninstall

1. Remove the `SessionStart`/`SessionEnd` entries that call `session-track.ps1` from `~/.claude/settings.json`, or restore the `settings.json.bak-<timestamp>` backup.
2. Delete `~/.claude/scripts/session-track.ps1`, `~/.claude/scripts/restore-sessions.ps1`, `~/.claude/scripts/claude-restore.ico` and the `~/.claude/session-registry` folder.
3. Delete the desktop shortcuts and, if you used `-AutoStart`, the one in the Startup folder (`shell:startup`).
