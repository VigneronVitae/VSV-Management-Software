# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Runs the watchdog check on an interval, in a process that stays
#           alive, because Task Scheduler does not work on this machine."
# Depends on: [scripts/watchdog.ps1]
# Depended on by: [scripts/watchdog-install.ps1, docs/status-ledger.md]
# ---------------------------------------------------------------------------
#
# **Why this exists instead of a scheduled task.** The obvious way to run
# something every five minutes is Task Scheduler, and that was tried first. The
# task registers, `schtasks /run` and `Start-ScheduledTask` both report success,
# and the process never starts: last result 1, no output, no log line. A task
# whose whole action is `cmd.exe /c echo` into a file fails identically, so it is
# not this script and not the quoting. Task history logging is disabled and
# turning it on needs administrator rights, as does reading the user rights
# assignment, so the cause is not visible from here.
#
# What does work on this machine is the HKCU Run key, which is how Docker Desktop
# itself starts. So the interval lives in a loop in a process, rather than in the
# scheduler.
#
# The tradeoff is honest: a loop in a process dies if the process dies, and
# nothing restarts it until the next login. A scheduled task would survive that.
# Given the choice between a mechanism that survives its own death and one that
# runs at all, this is the one that runs at all.

[CmdletBinding()]
param(
  [int] $EveryMinutes = 5,
  [string] $LogPath = "C:\Users\Randy\AppData\Local\vsv-watchdog\watchdog.log"
)

$ErrorActionPreference = "Continue"

$here  = Split-Path -Parent $MyInvocation.MyCommand.Path
$check = Join-Path $here "watchdog.ps1"

if (-not (Test-Path $check)) {
  throw "watchdog.ps1 is not beside this file"
}

# Said once at the top so the log shows when the loop itself last started, which
# is the thing to look at when the log goes quiet.
Add-Content -Path $LogPath -Encoding utf8 -Value (
  "{0}  loop     started, checking every {1} minute(s), pid {2}" -f `
    (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $EveryMinutes, $PID)

while ($true) {
  try {
    & $check -LogPath $LogPath | Out-Null
  } catch {
    # A crash in the check must not end the loop. The cellar being unreachable is
    # exactly when this is worth having, and that is also when the check is most
    # likely to throw something unexpected.
    Add-Content -Path $LogPath -Encoding utf8 -Value (
      "{0}  ERROR    the check threw: {1}" -f `
        (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $_)
  }
  Start-Sleep -Seconds ($EveryMinutes * 60)
}
