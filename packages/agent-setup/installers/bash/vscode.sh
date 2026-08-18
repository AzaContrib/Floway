# VSCode Agent Setup fragment.

# VSCode's "Chat: Open Language Models (JSON)" dialog accepts the settings by
# paste, so the installer prints the converted JSON and the steps to follow
# rather than writing a file the editor would not read.
vscode_print_settings() {
  _vs_out=$(harness_run_converter vscode) || {
    out_error 'failed to convert the Floway model list to VSCode settings.'
    return 1
  }
  if ! printf '%s' "$_vs_out" | grep -q '"models"'; then
    out_error 'the VSCode converter produced no model settings.'
    return 1
  fi
  out_info 'Paste the JSON below into VSCode:'
  out_info '1. Ctrl-Shift-P (Cmd-Shift-P): "Chat: Open Language Models (JSON)"'
  out_info '2. Ctrl-Shift-P (Cmd-Shift-P): "Developer: Reload Window"'
  out_info '3. Ctrl-Shift-P (Cmd-Shift-P): "Chat: Manage Language Models"'
  out_info '4. Right click a model, and choose "Update API Key"'
  printf '%s\n' "$_vs_out"
}

# Fetch the model list, convert it, and print the VSCode settings.
configure_agent() {
  out_agent_notice 'Configuring' 'VSCode'
  if ! harness_ensure_python; then
    return 1
  fi
  if ! harness_fetch_converter vscode; then
    return 1
  fi
  if ! harness_fetch_models; then
    return 1
  fi
  if ! vscode_print_settings; then
    return 1
  fi
  out_agent_notice 'Completed Agent Setup' 'VSCode'
}


main 'VSCode' "$@"
