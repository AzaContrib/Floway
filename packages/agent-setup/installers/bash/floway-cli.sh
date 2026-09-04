# floway-cli Agent Setup fragment.

# floway-cli configures every harness Floway supports in one pass, so this
# fragment only has to fetch its binary and hand it the credentials the
# rendered prefix carries. The non-interactive install reads
# SETUP_ENDPOINT/SETUP_API_KEY, writes the same files the per-agent fragments
# write, and records its own state for `floway update`/`floway uninstall`.
# Ref: https://github.com/AzaContrib/floway-cli
FLOWAY_CLI_REPO='AzaContrib/floway-cli'

# Reuse the harness download discipline: refuse HTML (captive portals) and
# empty bodies before anything executes.
_floway_download_installer() {
  _fdi_url="$1"
  _fdi_file=$(mktemp "$SETUP_TMPDIR/floway-install.XXXXXX") || return 1
  if ! curl -fsSL --connect-timeout 10 --max-time 120 -o "$_fdi_file" "$_fdi_url"; then
    out_error "could not download the floway-cli installer from $_fdi_url"
    rm -f "$_fdi_file"
    return 1
  fi
  if awk '
      NR <= 20 {
        line = tolower($0)
        if (line ~ /^[[:space:]]*(<!doctype[[:space:]]+html|<html([[:space:]>])|<head([[:space:]>])|<body([[:space:]>]))/) found = 1
      }
      END { exit found ? 0 : 1 }
    ' "$_fdi_file"; then
    out_error 'the floway-cli installer download was HTML, not an executable script (a login or region-block page?).'
    rm -f "$_fdi_file"
    return 1
  fi
  if ! awk 'NF { found = 1 } END { exit found ? 0 : 1 }' "$_fdi_file"; then
    out_error 'the floway-cli installer download was empty.'
    rm -f "$_fdi_file"
    return 1
  fi
  printf '%s' "$_fdi_file"
}

# Install the floway binary through the project's install.sh (which resolves
# the platform artifact, verifies its sha256, and lands it in ~/.local/bin).
floway_cli_ensure_installed() {
  if command -v floway >/dev/null 2>&1; then
    out_info 'floway is already installed.'
    return 0
  fi
  _fci_timeout=${AGENT_SETUP_TEST_TIMEOUT_SECONDS:-600}
  _fdi_url="https://raw.githubusercontent.com/$FLOWAY_CLI_REPO/main/install.sh"
  _fdi_file=$(_floway_download_installer "$_fdi_url") || return 1
  if ! _run_with_timeout "$_fci_timeout" env -u SETUP_API_KEY sh "$_fdi_file" </dev/null; then
    rm -f "$_fdi_file"
    out_error 'the floway-cli installer failed.'
    return 1
  fi
  rm -f "$_fdi_file"
  hash -r 2>/dev/null || true
  if ! command -v floway >/dev/null 2>&1; then
    [ -x "$HOME/.local/bin/floway" ] && PATH="$HOME/.local/bin:$PATH" && export PATH
  fi
  command -v floway >/dev/null 2>&1
}

# Run the binary's own installer over the prefix credentials. main.sh strips the
# export attribute from SETUP_* so child processes never inherit the key, so the
# values are passed as flags instead; the CLI treats argv identically to env and
# records its state so `floway update` and `floway uninstall` manage the result.
floway_cli_write_settings() {
  _fcw_dir="$(command -v floway || printf '%s' "$HOME/.local/bin/floway")"
  _fcw_timeout=${AGENT_SETUP_TEST_TIMEOUT_SECONDS:-600}
  if ! _run_with_timeout "$_fcw_timeout" "$_fcw_dir" install \
      --endpoint "$SETUP_ENDPOINT" \
      --api-key "$SETUP_API_KEY" \
      --agents all \
      --non-interactive </dev/null; then
    out_error 'floway install failed; see its output above.'
    return 1
  fi
}

floway_cli_write_version() {
  _fv_timeout=${AGENT_SETUP_TEST_TIMEOUT_SECONDS:-30}
  _fv_version_file="$SETUP_TMPDIR/floway-version.out"
  if ! _run_with_timeout "$_fv_timeout" floway --version > "$_fv_version_file" 2>&1; then
    out_warn 'could not read the floway version; the binary may be new.'
    return 0
  fi
  out_info "floway version: $(cat "$_fv_version_file")"
}

floway_cli_rollback_settings() {
  # The binary's own install is transactional per agent; a failed run leaves
  # nothing half-written for us to restore here.
  return 0
}

configure_agent() {
  out_agent_notice 'Installing' 'floway-cli'
  if ! floway_cli_ensure_installed; then
    out_error 'floway-cli is unavailable and could not be installed.'
    return 1
  fi
  floway_cli_write_version

  out_agent_notice 'Configuring' 'floway-cli'
  if ! floway_cli_write_settings; then
    floway_cli_rollback_settings
    return 1
  fi
  out_info 'Configured via `floway install`; manage it with `floway update` and `floway uninstall`.'
  out_agent_notice 'Completed Agent Setup' 'floway-cli'
}


main 'floway-cli' "$@"
