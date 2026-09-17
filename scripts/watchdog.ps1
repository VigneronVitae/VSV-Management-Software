# ---------------------------------------------------------------------------
# Type: tool
# Purpose: "Brings the cellar back up when it goes down, without anybody
#           noticing it went down."
# Depends on: [CLAUDE.md]
# Depended on by: [scripts/watchdog-loop.ps1, scripts/watchdog-install.ps1,
#                  docs/status-ledger.md]
# ---------------------------------------------------------------------------
#
# Written after the cellar was offline for eight hours overnight. Two things had
# to line up. The Claude desktop app updated itself at 23:42 and its VM service
# was reinstalled at 23:53:11, which took the shared WSL platform down; Docker
# Desktop logged "enginedependencies: starting graceful shutdown" at that exact
# second and stopped. Then Docker could not come back, because settings-store.json
# had been written with a UTF-8 byte order mark and its parser refuses one, which
# is a thing an agent did while enabling autostart and which lay dormant for
# hours because that file is only read at startup.
#
# **Autostart was never going to help.** It fires at login, and the machine had
# been up for three days. Nothing in the picture was watching.
#
# So this watches. It is deliberately dumb: it asks whether the database answers,
# and if it does not, it starts what is missing and writes down what it did. It
# does not diagnose, because the failure that put it here was one nobody
# predicted and the next one will be too.
#
# It must run as the logged-in user. Docker Desktop is a desktop application and
# there is no version of it that runs without a session, so a watchdog that runs
# "whether the user is logged on or not" would be a watchdog that quietly cannot
# work. That is why the task installs as logon-only, and why this says so rather
# than pretending otherwise.

[CmdletBinding()]
param(
  # The container the winery actually depends on. The sandbox stack is not
  # checked: practice being down is a nuisance and not a harvest problem.
  [string] $Container = "supabase_db_vsv-management-software",

  # How long to wait for the engine after starting Docker Desktop. It took five
  # seconds the morning this was written and the documented cold start is under
  # a minute; three is room for a bad day.
  [int] $EngineWaitSeconds = 180,

  # Where the record goes. Outside the repository, because it is about this
  # machine rather than about the app.
  [string] $LogPath = "$env:LOCALAPPDATA\vsv-watchdog\watchdog.log",

  # Pretends the database is unreachable, to exercise the recovery path on a
  # machine that is working. A check that has never run is a check nobody has
  # reason to believe.
  [switch] $SimulateDown
)

$ErrorActionPreference = "Continue"

New-Item -ItemType Directory -Force -Path (Split-Path $LogPath) | Out-Null

function Write-Log([string] $Message) {
  $line = "{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
  Add-Content -Path $LogPath -Value $line -Encoding utf8
  Write-Output $line
}

# Trimmed here rather than by a second scheduled task. At one line per run every
# five minutes, a year is about a hundred thousand lines, and the interesting
# ones are always the last few.
if ((Test-Path $LogPath) -and ((Get-Item $LogPath).Length -gt 2MB)) {
  $keep = Get-Content $LogPath -Tail 2000
  Set-Content -Path $LogPath -Value $keep -Encoding utf8
}

function Test-Cellar {
  if ($SimulateDown) { return $false }
  # The question the app asks, rather than a question about Docker. The engine
  # can be up with the database stopped, and that reads as offline on a phone
  # exactly the same way.
  & docker exec $Container pg_isready -U postgres 2>&1 | Out-Null
  return $?
}

if (Test-Cellar) {
  Write-Log "ok       the cellar answers"
  exit 0
}

Write-Log "DOWN     the cellar does not answer, bringing it back"

# 1. The engine. Everything else is downstream of it.
& docker ps 2>&1 | Out-Null
$engineUp = $?

if (-not $engineUp) {
  $running = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
  if ($running) {
    # Already on its way. Starting a second copy is how one bad morning becomes
    # twelve Docker Desktops.
    Write-Log "wait     Docker Desktop is already starting, leaving it alone"
    exit 0
  }

  $exe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
  if (-not (Test-Path $exe)) {
    Write-Log "FAIL     Docker Desktop is not installed at $exe"
    exit 1
  }

  Write-Log "start    launching Docker Desktop"
  Start-Process $exe | Out-Null

  $waited = 0
  while ($waited -lt $EngineWaitSeconds) {
    Start-Sleep -Seconds 5
    $waited += 5
    & docker ps 2>&1 | Out-Null
    if ($?) { $engineUp = $true; break }
  }

  if ($engineUp) {
    Write-Log "start    engine up after ${waited}s"
  } else {
    # Said plainly and left for a person. This is where the byte order mark
    # would have landed, and the useful thing then was the reason in Docker's
    # own log rather than another attempt.
    Write-Log "FAIL     no engine after ${EngineWaitSeconds}s. Look at $env:LOCALAPPDATA\Docker\log\host\com.docker.backend.exe.log"
    exit 1
  }
}

# 2. The container. It normally restarts itself with the engine, so reaching
#    here means it did not, and starting it by name is cheap.
$state = (& docker inspect -f '{{.State.Running}}' $Container 2>&1)
if ($state -ne "true") {
  Write-Log "start    starting $Container"
  & docker start $Container 2>&1 | Out-Null
}

# 3. Say whether it worked, because "I tried" is not an outcome.
$waited = 0
while ($waited -lt 120) {
  Start-Sleep -Seconds 5
  $waited += 5
  if ($SimulateDown) { break }
  if (Test-Cellar) {
    Write-Log "ok       the cellar answers again after ${waited}s"
    exit 0
  }
}

if ($SimulateDown) {
  Write-Log "ok       simulated run finished; the engine and container were checked and nothing was left broken"
  exit 0
}

Write-Log "FAIL     the engine is up and the cellar still does not answer"
exit 1
