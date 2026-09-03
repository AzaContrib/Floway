# floway-cli Agent Setup fragment.

# floway-cli configures every harness Floway supports in one pass, so this
# fragment only has to fetch its binary and hand it the credentials the
# rendered prefix carries. The non-interactive install reads
# SETUP_ENDPOINT/SETUP_API_KEY, writes the same files the per-agent fragments
# write, and records its own state for `floway update`/`floway uninstall`.
# Ref: https://github.com/AzaContrib/floway-cli
$FlowayCliRepo = 'AzaContrib/floway-cli'

function Install-SetupFlowayCli {
  if ($env:AGENT_SETUP_TEST_INSTALL_FLOWAY_CLI_SCRIPT) {
    Write-SetupInfo 'running the test floway-cli installer hook'
    $timeoutSeconds = Get-SetupTimeoutSeconds 600
    $installer = Invoke-SetupProcess -Exe $env:AGENT_SETUP_TEST_INSTALL_FLOWAY_CLI_SCRIPT -Arguments @() -TimeoutSeconds $timeoutSeconds
    if ($installer.ExitCode -ne 0) { Stop-Setup 'the test floway-cli installer hook failed.' }
    return
  }
  Write-SetupInfo 'installing or updating floway CLI from the installer script'
  Invoke-SetupRemoteInstaller -Uri "https://raw.githubusercontent.com/$FlowayCliRepo/main/install.ps1" -BypassExecutionPolicy
}

function Get-SetupFlowayCliExe {
  Install-SetupFlowayCli
  $candidates = @(
    (Join-Path $HOME '.local/bin/floway.exe'),
    (Join-Path $HOME '.local/bin/floway')
  )
  if ($env:USERPROFILE) {
    $candidates += (Join-Path $env:USERPROFILE '.local\bin\floway.exe')
    $candidates += (Join-Path $env:USERPROFILE '.local\bin\floway')
  }
  $exe = Get-SetupCliExe -Name floway -Label 'floway-cli' -Candidates $candidates
  if (-not $exe) { Stop-Setup 'floway CLI is unavailable and could not be installed.' }
  return $exe
}

# The binary's own installer takes the credentials as flags (matching the bash
# fragment), configures every harness, and records its state so `floway update`
# and `floway uninstall` manage the result from then on.
function Set-SetupAgent {
  $exe = Get-SetupFlowayCliExe
  $timeoutSeconds = Get-SetupTimeoutSeconds 600
  $result = Invoke-SetupProcess -Exe $exe -Arguments @(
    'install',
    '--endpoint', $SetupEndpoint,
    '--api-key', $SetupApiKey,
    '--agents', 'all',
    '--non-interactive'
  ) -TimeoutSeconds $timeoutSeconds
  if ($result.ExitCode -ne 0) { Stop-Setup 'floway install failed; see its output above.' }
  Write-SetupInfo "Configured via ``floway install``; manage it with ``floway update`` and ``floway uninstall``."
  Write-SetupAgentNotice 'Completed Agent Setup' 'floway-cli'
}

$global:LASTEXITCODE = Main 'floway-cli'
