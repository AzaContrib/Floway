# Zed Agent Setup fragment.

# Merge the converted Zed settings into the existing global_settings.json. The
# converter emits `{language_models: {openai_compatible: {Floway: {...}}}}`;
# that subtree is merged into the existing document so unrelated settings
# survive, then the whole document is written back transactionally.
function Write-SetupZedSettings {
  $configDir = if ($env:ZED_CONFIG_DIR) { $env:ZED_CONFIG_DIR } else { Join-Path $HOME '.config\zed' }
  $script:ZedSettingsPath = Join-Path $configDir 'global_settings.json'
  $script:ZedSettingsBackup = $null
  $script:ZedSettingsExisted = $false
  if (-not (Test-Path -LiteralPath $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
  }

  if (Test-Path -LiteralPath $script:ZedSettingsPath) {
    $script:ZedSettingsExisted = $true
    $raw = Get-Content -Raw -LiteralPath $script:ZedSettingsPath
    try { $document = $raw | ConvertFrom-Json } catch { Stop-Setup "$($script:ZedSettingsPath) is not valid JSON; leaving it untouched." }
    if ($document -isnot [System.Management.Automation.PSCustomObject]) { Stop-Setup "existing Zed settings root is not a JSON object." }
    $stamp = [long]([DateTimeOffset]::UtcNow - [DateTimeOffset]'1970-01-01T00:00:00Z').TotalMilliseconds
    $script:ZedSettingsBackup = "$($script:ZedSettingsPath).floway-backup.$stamp.$PID"
    try {
      Copy-Item -LiteralPath $script:ZedSettingsPath -Destination $script:ZedSettingsBackup
      Protect-SetupFile $script:ZedSettingsBackup
    } catch {
      if (Test-Path -LiteralPath $script:ZedSettingsBackup) { Remove-Item -LiteralPath $script:ZedSettingsBackup -Force }
      $script:ZedSettingsBackup = $null
      throw
    }
  } else {
    $document = [PSCustomObject]@{}
  }

  $converter = Get-SetupHarnessConverter -Name 'zed'
  $models = Get-SetupHarnessModels
  $converted = Invoke-SetupHarnessConverter -Name 'zed' -Converter $converter -Models $models
  $convertedDoc = $converted | ConvertFrom-Json
  if ($null -eq $convertedDoc.language_models -or $null -eq $convertedDoc.language_models.openai_compatible) {
    Stop-Setup 'the Zed converter produced no language-model settings.'
  }

  if ($document.PSObject.Properties.Name -notcontains 'language_models') {
    $document | Add-Member -NotePropertyName language_models -NotePropertyValue ([PSCustomObject]@{})
  }
  if ($document.language_models.PSObject.Properties.Name -notcontains 'openai_compatible') {
    $document.language_models | Add-Member -NotePropertyName openai_compatible -NotePropertyValue ([PSCustomObject]@{})
  }
  Set-SetupProp $document.language_models.openai_compatible 'Floway' $convertedDoc.language_models.openai_compatible.Floway

  $stage = "$($script:ZedSettingsPath).floway-stage.$PID"
  try {
    [System.IO.File]::Create($stage).Dispose()
    Protect-SetupFile $stage
    $json = $document | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($stage, $json, (New-Object System.Text.UTF8Encoding($false)))
    $check = Get-Content -Raw -LiteralPath $stage | ConvertFrom-Json
    if ($null -eq $check.language_models.openai_compatible.Floway) { Stop-Setup 'staged Zed settings failed validation.' }
    $runningOnWindows = Test-SetupIsWindows
    if ($script:ZedSettingsExisted -and $runningOnWindows) {
      Protect-SetupFile $script:ZedSettingsPath
      [System.IO.File]::Replace($stage, $script:ZedSettingsPath, [System.Management.Automation.Language.NullString]::Value)
    } else {
      Move-Item -LiteralPath $stage -Destination $script:ZedSettingsPath -Force
    }
    Remove-SetupOlderBackups -Path $script:ZedSettingsPath -Keep $script:ZedSettingsBackup
  } catch {
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Force }
    Restore-SetupManagedFile -Existed $script:ZedSettingsExisted -Backup $script:ZedSettingsBackup -Path $script:ZedSettingsPath -OriginalLabel 'file' -CreatedLabel 'Zed settings'
    throw
  }
}

# Fetch the model list, convert it, and merge the Zed settings file.
function Set-SetupAgent {
  Write-SetupAgentNotice 'Configuring' 'Zed'
  try {
    Write-SetupZedSettings
    Write-SetupInfo ('Written to `' + $script:ZedSettingsPath + '`.')
    Write-SetupAgentNotice 'Completed Agent Setup' 'Zed'
  } finally {
    Remove-SetupHarnessTmpDir
  }
}


$global:LASTEXITCODE = Main 'Zed'
