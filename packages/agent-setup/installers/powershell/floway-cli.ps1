# floway-cli Agent Setup fragment.

# floway-cli configures every harness Floway supports in one pass, so this
# fragment only has to fetch its binary and hand it the credentials the
# rendered prefix carries. The non-interactive install reads
# SETUP_ENDPOINT/SETUP_API_KEY, writes the same files the per-agent fragments
# write, and records its own state for `floway update`/`floway uninstall`.
# Ref: https://github.com/hykilpikonna/floway-cli
$FlowayCliRepo = 'hykilpikonna/floway-cli'

function Install-SetupFlowayCli {
  if ($env:AGENT_SETUP_TEST_INSTALL_FLOWAY_CLI_SCRIPT) {
    Write-SetupInfo 'floway CLI not found; running the test installer'
    $timeoutSeconds = Get-SetupTimeoutSeconds 600
    $installer = Invoke-SetupProcess -Exe $env:AGENT_SETUP_TEST_INSTALL_FLOWAY_CLI_SCRIPT -Arguments @() -TimeoutSeconds $timeoutSeconds
    if ($installer.ExitCode -ne 0) { Stop-Setup 'the test floway-cli installer hook failed.' }
    return
  }
  Write-SetupInfo 'floway CLI not found; installing from the floway-cli installer script'
  Invoke-SetupRemoteInstaller -Uri "https://raw.githubusercontent.com/$FlowayCliRepo/main/install.sh" -BypassExecutionPolicy
}

function Get-SetupFlowayCliExe {
  $exe = Get-SetupCliExe -Name floway -Label 'floway-cli' -Candidates @(
    (Join-Path $HOME '.local/bin/floway.exe'),
    (Join-Path $HOME '.local/bin/floway')
  )
  if (-not $exe) {
    Install-SetupFlowayCli
    $exe = Get-SetupCliExe -Name floway -Label 'floway-cli' -Candidates @(
      (Join-Path $HOME '.local/bin/floway.exe'),
      (Join-Path $HOME '.local/bin/floway')
    )
    if (-not $exe) { Stop-Setup 'floway CLI is unavailable and could not be installed.' }
  } else {
    Write-SetupInfo 'floway is already installed.'
  }
  return $exe
}

# The binary's own installer consumes SETUP_ENDPOINT/SETUP_API_KEY, configures
# every harness, and records its state so `floway update` and `floway
# uninstall` manage the result from then on.
function Set-SetupAgent {
  $exe = Get-SetupFlowayCliExe
  $timeoutSeconds = Get-SetupTimeoutSeconds 600
  $result = Invoke-SetupProcess -Exe $exe -Arguments @('install', '--agents', 'all', '--non-interactive') -TimeoutSeconds $timeoutSeconds
  if ($result.ExitCode -ne 0) { Stop-Setup 'floway install failed; see its output above.' }
  Write-SetupInfo "Configured via ``floway install``; manage it with ``floway update`` and ``floway uninstall``."
  Write-SetupAgentNotice 'Completed Agent Setup' 'floway-cli'
}

$global:LASTEXITCODE = Main 'floway-cli'
