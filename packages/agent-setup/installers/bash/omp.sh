# oh-my-pi Agent Setup fragment.

# The oh-my-pi converter emits YAML, which requires the PyYAML module. Check
# for it before any file is touched so a missing module fails cleanly.
omp_ensure_yaml() {
  if ! python3 -c 'import yaml' >/dev/null 2>&1; then
    out_error 'the oh-my-pi converter requires the PyYAML module; install it with `python3 -m pip install pyyaml`.'
    return 1
  fi
}

# Write the converted oh-my-pi settings transactionally: back up the existing
# file (if one exists), stage the new content in the same directory, validate
# it, and rename it into place with owner-only access.
omp_write_settings() {
  _ow_dir="${OMP_CONFIG_DIR:-$HOME/.omp}/agent"
  OMP_MODELS_PATH="$_ow_dir/models.yml"
  OMP_MODELS_BACKUP=""
  OMP_MODELS_EXISTED=0

  if ! mkdir -p "$_ow_dir"; then
    out_error "could not create $_ow_dir"
    return 1
  fi

  if [ -e "$OMP_MODELS_PATH" ]; then
    OMP_MODELS_EXISTED=1
    OMP_MODELS_BACKUP="$OMP_MODELS_PATH.floway-backup.$(date +%Y%m%d%H%M%S).$$"
    if ! cp "$OMP_MODELS_PATH" "$OMP_MODELS_BACKUP"; then
      out_error "could not back up $OMP_MODELS_PATH"
      return 1
    fi
  fi

  _ow_stage="$OMP_MODELS_PATH.floway-stage.$$"
  if ! harness_run_converter omp > "$_ow_stage"; then
    out_error 'failed to convert the Floway model list to oh-my-pi settings.'
    rm -f "$_ow_stage"
    omp_rollback_settings
    return 1
  fi
  if ! grep -q '^providers:' "$_ow_stage"; then
    out_error 'the oh-my-pi converter produced no provider settings.'
    rm -f "$_ow_stage"
    omp_rollback_settings
    return 1
  fi

  if ! chmod 600 "$_ow_stage"; then
    rm -f "$_ow_stage"
    omp_rollback_settings
    return 1
  fi

  if ! mv "$_ow_stage" "$OMP_MODELS_PATH"; then
    out_error "could not replace $OMP_MODELS_PATH"
    rm -f "$_ow_stage"
    omp_rollback_settings
    return 1
  fi
  if ! _prune_managed_backups "$OMP_MODELS_PATH" "$OMP_MODELS_BACKUP"; then
    omp_rollback_settings
    return 1
  fi
}

omp_rollback_settings() {
  _restore_managed_file \
    "${OMP_MODELS_EXISTED:-0}" "${OMP_MODELS_BACKUP:-}" "$OMP_MODELS_PATH" \
    "file" "oh-my-pi settings"
}

# Fetch the model list, convert it, and install the oh-my-pi settings file.
configure_agent() {
  out_agent_notice 'Configuring' 'oh-my-pi'
  if ! harness_ensure_python; then
    return 1
  fi
  if ! omp_ensure_yaml; then
    return 1
  fi
  if ! harness_fetch_converter omp; then
    return 1
  fi
  if ! harness_fetch_models; then
    return 1
  fi
  if ! omp_write_settings; then
    return 1
  fi
  out_info "Written to \`$OMP_MODELS_PATH\`."
  out_agent_notice 'Completed Agent Setup' 'oh-my-pi'
}


main 'oh-my-pi' "$@"
