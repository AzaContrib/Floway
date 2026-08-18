# VSCode Agent Setup fragment.

# VSCode's "Chat: Open Language Models (JSON)" dialog accepts the settings by
# paste, so the installer prints the converted JSON and the steps to follow
# rather than writing a file the editor would not read.
function Write-SetupVscodeSettings {
  $converter = Get-SetupHarnessConverter -Name 'vscode'
  $models = Get-SetupHarnessModels
  $converted = Invoke-SetupHarnessConverter -Name 'vscode' -Converter $converter -Models $models
  if ($converted -notmatch '"models"') {
    Stop-Setup 'the VSCode converter produced no model settings.'
  }
  Write-SetupInfo 'Paste the JSON below into VSCode:'
  Write-SetupInfo '1. Ctrl-Shift-P (Cmd-Shift-P): "Chat: Open Language Models (JSON)"'
  Write-SetupInfo '2. Ctrl-Shift-P (Cmd-Shift-P): "Developer: Reload Window"'
  Write-SetupInfo '3. Ctrl-Shift-P (Cmd-Shift-P): "Chat: Manage Language Models"'
  Write-SetupInfo '4. Right click a model, and choose "Update API Key"'
  Write-Host $converted
}

# Fetch the model list, convert it, and print the VSCode settings.
function Set-SetupAgent {
  Write-SetupAgentNotice 'Configuring' 'VSCode'
  try {
    Write-SetupVscodeSettings
    Write-SetupAgentNotice 'Completed Agent Setup' 'VSCode'
  } finally {
    Remove-SetupHarnessTmpDir
  }
}


$global:LASTEXITCODE = Main 'VSCode'
