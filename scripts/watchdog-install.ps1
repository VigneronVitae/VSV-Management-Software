# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Installs the watchdog so it starts at login and runs from now on,
#           and is the one place the interval is written down."
# Depends on: [scripts/watchdog-loop.ps1, scripts/watchdog.ps1]
# Depended on by: [docs/status-ledger.md]
# ---------------------------------------------------------------------------
#
# Run this to install the watchdog, and run it again to change how often it
# checks. It replaces what is there rather than adding to it, so running it twice
# is the same as running it once.
#
#   powershell -ExecutionPolicy Bypass -File scripts\watchdog-install.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\watchdog-install.ps1 -CheckEveryMinutes 15
#
# **This does not use Task Scheduler, and that was not the first choice.** A
# scheduled task was written, registered, and did nothing: it reports success and
# the process never starts, last result 1, and a task whose entire action is
# `cmd.exe /c echo` into a file fails the same way. Diagnosing that needs
# administrator rights this account does not have. The HKCU Run key does work
# here, demonstrably, because it is how Docker Desktop starts. See
# scripts/watchdog-loop.ps1.
#
# To see what it has been doing:
#
#   Get-Content "C:\Users\Randy\AppData\Local\vsv-watchdog\watchdog.log" -Tail 40
#
# To take it away:
#
#   Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "VSV cellar watchdog"

[CmdletBinding()]
param(
  # **The interval, and the only number here worth thinking about.**
  #
  # The check costs about half a second when everything is fine, so this is not a
  # question about load. It is how long the app stays offline before it heals
  # itself. The night this was written the gap was eight hours, because nothing
  # was watching at all.
  #
  # Five means somebody filling in a weighing on a phone waits once and it works
  # the second time. Fifteen means they give up and send a message. Either is a
  # defensible answer and this is the line to change.
  [int] $CheckEveryMinutes = 5,

  [string] $HomeDir = "C:\Users\Randy\AppData\Local\vsv-watchdog",
  [string] $RunName = "VSV cellar watchdog"
)

$ErrorActionPreference = "Stop"

if ($CheckEveryMinutes -lt 1 -or $CheckEveryMinutes -gt 1440) {
  throw "A check every $CheckEveryMinutes minutes is not an interval."
}

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$loop = Join-Path $here "watchdog-loop.ps1"
if (-not (Test-Path $loop)) { throw "watchdog-loop.ps1 is not beside this file" }

New-Item -ItemType Directory -Force -Path $HomeDir | Out-Null

# **There used to be a VBScript shim here and it is gone.** It existed because
# every other way of starting PowerShell at login flashes a console window, and
# WScript's Run with a window style of 0 does not.
#
# On 2026-09-18 the machine came back from an unclean shutdown and the winemaker
# was shown "Can not find script file
# C:\Users\Randy\AppData\Local\vsv-watchdog\run-loop.vbs" at logon. The file was
# there, was readable, and cscript ran a test script on that machine minutes
# later without complaint, so the cause was never established. What was
# established is the shape of the failure, and the shape is what matters: wscript
# sat on a modal dialog, the loop it should have spawned never started, and the
# watchdog did not run at all that day. The dialog is the only reason anybody
# knew, and it was noticed by a person rather than by anything here.
#
# A link in the chain that can fail this way, for a reason nobody can reproduce,
# to save one console flash per login, is not worth having. VBScript is also on
# its way out of Windows, so this was going to break eventually regardless. A
# flash at login is the price, and given the failure it replaces, a thing you can
# see is an improvement on a thing you cannot.

# Stop whatever is already looping, so that changing the interval changes it
# rather than adding a second loop on the old one.
Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
  Where-Object { $_.CommandLine -and $_.CommandLine -like "*watchdog-loop.ps1*" } |
  ForEach-Object {
    "stopping existing loop, pid {0}" -f $_.ProcessId
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
  }

# At login, from now on. PowerShell directly, and by full path rather than by
# bare name: the Run key resolves a bare name against PATH, and PATH at logon is
# not reliably PATH in a shell.
$ps = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$launch = '"{0}" -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "{1}" -EveryMinutes {2}' -f `
  $ps, $loop, $CheckEveryMinutes

Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
  -Name $RunName -Value $launch

# And right now, so installing it means it is running rather than meaning it will
# run after the next login.
#
# One quoted string, not an array. `Start-Process -ArgumentList` joins an array
# with spaces and quotes nothing, so the repository path splits at its first
# space and PowerShell reports `Processing -File 'D:\Vitae' failed because the
# file does not have a '.ps1' extension`. The same shape of mistake as the
# VBScript quoting this replaced, caught here only because the installer checks
# whether the thing it installed is running.
$args = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -EveryMinutes {1}' -f `
  $loop, $CheckEveryMinutes
Start-Process -FilePath $ps -ArgumentList $args -WindowStyle Hidden

Start-Sleep -Seconds 6
$running = Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
  Where-Object { $_.CommandLine -and $_.CommandLine -like "*watchdog-loop.ps1*" }

"installed:  {0}" -f $RunName
"interval:   every {0} minute(s)" -f $CheckEveryMinutes
"at login:   {0}" -f $launch
"running:    {0}" -f $(if ($running) { "yes, pid " + ($running.ProcessId -join ", ") } else { "NO, the loop did not start" })
"log:        {0}\watchdog.log" -f $HomeDir
