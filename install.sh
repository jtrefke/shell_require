#!/usr/bin/env bash

set -u

readonly Install_ROOT_UID=0
readonly Install_SCRIPT_DIR="$(cd "$(dirname "$(readlink -e "${BASH_SOURCE[0]}")")" && pwd)"
readonly Install_APP_NAME="shell_require"


Install_main() {
  local -r install_dir="${HOME}/.${Install_APP_NAME}"
  local -r install_file_permission="700"

  echo "Installing ${Install_APP_NAME} to '${install_dir}'... "
  Install_verifyDependencies || \
    Install_exit 1 "Not all dependencies present"
  Install_copyInstallFiles "${install_dir}" "${install_file_permission}" || \
    Install_exit 1 "Error copying files"
  Install_createConfigTemplate "${install_dir}"
  Install_addToPath "${install_dir}/bin" || \
    Install_exit 1 "Error adding files to PATH"

  echo "Installation complete!"
  echo
  echo "As always: "
  echo "  Be careful when using online scripts, make sure they are trustworthy."
  echo
  Install_exit 0 "You can now use 'require'."
}

Install_verifyDependencies() {
  local -r required_commands=("curl")
  local required_commands_present=true
  for required_command in "${required_commands[@]}"; do
    command -v "${required_command}" >/dev/null 2>&1 || \
      { required_commands_present=false && break; }
  done

  if [ "${required_commands_present}" = "false" ]; then
    Install_err "Not all dependencies are installed on your computer."
    Install_err "Please make sure that "
    Install_err "  ${required_commands[*]} "
    Install_err "are installed and available for your user."
    return 1
  fi
  return 0
}

Install_copyInstallFiles() {
  local -r install_dir="$1"
  local -r install_file_permission="$2"

  [ -z "${Install_SCRIPT_DIR}" ] && return 1
  [ ! -w "$(dirname "${install_dir}")" ] && return 1

  mkdir -p "${install_dir}" || return 1
  cp -R ${Install_SCRIPT_DIR}/* "${install_dir}" || return 1
  chmod ${install_file_permission} ${install_dir}/bin/*
}

Install_createConfigTemplate() {
  local -r install_dir="$1"

  local -r config_file_path="${install_dir}/shellmodulerc"
  [ -f "${config_file_path}" ] && return 0

cat <<-'END_OF_CONFIG_TEMPLATE'>"${config_file_path}"
#!/usr/bin/env bash

#
# Template for shellmodulerc
# Found in $HOME/.shell_module/ or shell_module installation directory
# Uncomment the assignments below and add your preferred configuration
#

# Add your custom resolver configuration here (default: ())
# ShellModule_RESOLVERS=()

# Store externally resolved modules locally (default: true)
# ShellModule_STORE_EXTERNAL_MODULES=true

# Path where scripts should be search locally (default: "")
# ShellModule_PATH=""

# Token used by GitHub resolver for private repositories (default: "")
# GitHubResolver_AUTH_TOKEN=""
END_OF_CONFIG_TEMPLATE
}

Install_addToPath() {
  local -r file_path="$1"
  local -r env_files=("${HOME}/.bashrc" "${HOME}/.bash_profile")

  local path_changed=false
  for env_file in "${env_files[@]}"; do
    if [ -w "${env_file}" ]; then
      echo -e "\n# Making ${Install_APP_NAME} available to user\nexport PATH=\"${file_path}:\$PATH\"">>"${env_file}" && \
      path_changed=true && \
      break
    fi
  done

  if [ "${path_changed}" = "false" ]; then
    Install_err "WARNING: Couldn't add '${Install_APP_NAME}' to PATH."
    Install_err "Tried ${env_files[*]}, but non of them exists or is writable."
    Install_err "Make sure at least ~/.bash_profile exists or is writable and try again."
    Install_err "Otherwise ensure, that ${file_path} is in your PATH environment variable."
    return 1
  fi

  return 0
}

Install_err() {
  local -r message="$*"
  echo "${message}">&2
}

Install_exit() {
  local -r exit_code="$1"; shift
  local -r message="$*"

  local output_fd=1 && [ ${exit_code} -ne 0 ] && output_fd=2
  echo >&${output_fd}
  echo "${message}">&${output_fd}
  exit ${exit_code}
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  Install_main "$@"
fi
