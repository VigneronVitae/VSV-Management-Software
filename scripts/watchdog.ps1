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
  [switch] $SimulateDown,

  # Where the repository is, because the web servers are started from it.
  [string] $RepoRoot = "D:\Vitae Springs Management\Management_Software",

  # The three web servers, which are the thing a phone actually talks to first.
  #
  # **This is the gap that let the cellar sit dark all of the morning of
  # 2026-09-18.** The machine lost power the evening before, came back at 08:24,
  # and Docker started itself, so the database was answering the whole time and
  # this watchdog would have reported "ok" on every run. What was down was these
  # three, which nothing restarts at logon and nothing was watching. A watchdog
  # that checks the database and not the thing serving the app is a watchdog that
  # reports health during an outage, which is worse than none.
  #
  # The ports are not a choice made here. They are what `tailscale serve status`
  # already proxies to: / -> 5177, /shop -> 5175, /cellar -> 5176. Changing one
  # means changing the serve config too, and a mismatch shows up as this script
  # starting a server nobody can reach.
  [object[]] $Apps = @(
    @{ name = "cellar";   dir = "apps\web";      port = 5176 },
    @{ name = "shop";     dir = "apps\shop";     port = 5175 },
    @{ name = "launcher"; dir = "apps\launcher"; port = 5177 }
  )
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

# Listening is the whole question. A port with nothing on it is the outage, and
# anything more (fetching a page, checking the markup) is a check that can fail
# for reasons that are not an outage, at five minute intervals, forever.
function Test-Served([int] $Port) {
  $listening = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
  return [bool] $listening
}

foreach ($app in $Apps) {
  if ($SimulateDown) { continue }
  if (Test-Served $app.port) { continue }

  $wd = Join-Path $RepoRoot $app.dir
  $built = Join-Path $wd "dist\index.html"

  # Said rather than started. `vite preview` with no build serves a 404 to a
  # phone in a barn, and a watchdog that leaves one running has turned a plain
  # outage into a puzzling one.
  if (-not (Test-Path $built)) {
    Write-Log ("FAIL     {0} is down and has no build at {1}. Run: bun run build" -f $app.name, $built)
    continue
  }

  Write-Log ("start    {0} was not listening, starting it on {1}" -f $app.name, $app.port)
  # Hidden, detached, and from the app's own directory, because vite reads its
  # config from there. --strictPort so a port already taken by something else
  # fails loudly here instead of quietly serving the cellar on a port the proxy
  # does not forward.
  Start-Process -FilePath "bun" `
    -ArgumentList @("x", "vite", "preview", "--port", $app.port, "--strictPort") `
    -WorkingDirectory $wd -WindowStyle Hidden

  Start-Sleep -Seconds 4
  if (Test-Served $app.port) {
    Write-Log ("ok       {0} answers on {1} again" -f $app.name, $app.port)
  } else {
    Write-Log ("FAIL     {0} did not come up on {1}" -f $app.name, $app.port)
  }
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
