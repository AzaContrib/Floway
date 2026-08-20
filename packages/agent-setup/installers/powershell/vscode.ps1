# VSCode Agent Setup fragment.

# VSCode reads bring-your-own-key model groups from `chatLanguageModels.json`
# in its user data profile directory, so the installer writes the converted
# groups there (merging the Floway group into any existing groups) instead of
# asking the user to paste them by hand.
# Ref: https://code.visualstudio.com/docs/agent-customization/language-models
function Write-SetupVscodeSettings {
  $converter = Get-SetupHarnessConverter -Name 'vscode'
  $models = Get-SetupHarnessModels
  $converted = Invoke-SetupHarnessConverter -Name 'vscode' -Converter $converter -Models $models
  if ($converted -notmatch '"models"') {
    Stop-Setup 'the VSCode converter produced no model settings.'
  }

  if (Test-SetupIsWindows) {
    $appData = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $env:USERPROFILE 'AppData\Roaming' }
    $configDir = if ($env:VSCODE_CONFIG_DIR) { $env:VSCODE_CONFIG_DIR } else { Join-Path $appData 'Code\User' }
  } elseif ($IsMacOS) {
    $configDir = if ($env:VSCODE_CONFIG_DIR) { $env:VSCODE_CONFIG_DIR } else { Join-Path $HOME 'Library\Application Support\Code\User' }
  } else {
    $configDir = if ($env:VSCODE_CONFIG_DIR) { $env:VSCODE_CONFIG_DIR } else { Join-Path $HOME '.config\Code\User' }
  }
  $script:VscodeSettingsPath = Join-Path $configDir 'chatLanguageModels.json'
  $script:VscodeSettingsBackup = $null
  $script:VscodeSettingsExisted = $false
  if (-not (Test-Path -LiteralPath $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
  }

  if (Test-Path -LiteralPath $script:VscodeSettingsPath) {
    $script:VscodeSettingsExisted = $true
    $stamp = [long]([DateTimeOffset]::UtcNow - [DateTimeOffset]'1970-01-01T00:00:00Z').TotalMilliseconds
    $script:VscodeSettingsBackup = "$($script:VscodeSettingsPath).floway-backup.$stamp.$PID"
    try {
      Copy-Item -LiteralPath $script:VscodeSettingsPath -Destination $script:VscodeSettingsBackup
      Protect-SetupFile $script:VscodeSettingsBackup
    } catch {
      if (Test-Path -LiteralPath $script:VscodeSettingsBackup) { Remove-Item -LiteralPath $script:VscodeSettingsBackup -Force }
      $script:VscodeSettingsBackup = $null
      throw
    }
  }

  # Windows PowerShell 5.1 unwraps a single-element JSON array, so force array
  # semantics before merging.
  $convertedDoc = @($converted | ConvertFrom-Json)
  if ($convertedDoc.Count -eq 0) { Stop-Setup 'the VSCode converter produced no model settings.' }

  $stage = "$($script:VscodeSettingsPath).floway-stage.$PID"
  try {
    if ($script:VscodeSettingsExisted) {
      $existing = @(Get-Content -Raw -LiteralPath $script:VscodeSettingsPath | ConvertFrom-Json)
      $kept = @($existing | Where-Object { $_.name -ne 'Floway' })
      $merged = @($kept + $convertedDoc)
    } else {
      $merged = @($convertedDoc)
    }
    # ConvertTo-Json unwraps a single-element array into a bare object, but
    # VSCode requires the top-level JSON to be an array. Serialize each group
    # and join them inside brackets so a one-group file stays an array on both
    # Windows PowerShell 5.1 and PowerShell 7.
    $json = '[' + (($merged | ConvertTo-Json -Depth 100) -join ',') + ']'
    [System.IO.File]::Create($stage).Dispose()
    Protect-SetupFile $stage
    [System.IO.File]::WriteAllText($stage, $json, (New-Object System.Text.UTF8Encoding($false)))
    $check = @(Get-Content -Raw -LiteralPath $stage | ConvertFrom-Json)
    $floway = @($check | Where-Object { $_.name -eq 'Floway' -and $_.vendor -eq 'customendpoint' })
    if ($floway.Count -ne 1) { Stop-Setup 'staged VSCode settings failed validation.' }
    $runningOnWindows = Test-SetupIsWindows
    if ($script:VscodeSettingsExisted -and $runningOnWindows) {
      Protect-SetupFile $script:VscodeSettingsPath
      [System.IO.File]::Replace($stage, $script:VscodeSettingsPath, [System.Management.Automation.Language.NullString]::Value)
    } else {
      Move-Item -LiteralPath $stage -Destination $script:VscodeSettingsPath -Force
    }
    Remove-SetupOlderBackups -Path $script:VscodeSettingsPath -Keep $script:VscodeSettingsBackup
  } catch {
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Force }
    Restore-SetupManagedFile -Existed $script:VscodeSettingsExisted -Backup $script:VscodeSettingsBackup -Path $script:VscodeSettingsPath -OriginalLabel 'file' -CreatedLabel 'VSCode language-model settings'
    throw
  }
}

# Fetch the model list, convert it, and write the VSCode settings file.
function Set-SetupAgent {
  Write-SetupAgentNotice 'Configuring' 'VSCode'
  try {
    Write-SetupVscodeSettings
    Write-SetupInfo ('Written to `' + $script:VscodeSettingsPath + '`.')
    Write-SetupAgentNotice 'Completed Agent Setup' 'VSCode'
  } finally {
    Remove-SetupHarnessTmpDir
  }
}


$global:LASTEXITCODE = Main 'VSCode'
