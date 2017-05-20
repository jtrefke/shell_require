#!/usr/bin/env bash

readonly Install_PROJECT_URL="https://raw.githubusercontent.com/jtrefke/shell_require"
readonly Install_SOURCE_FILES=(
  'shell_module.sh'
  'README.md'
  'LICENSE'
  'bin/require'
  'shell_modules/require_resolvers/curl_resolver.sh'
  'shell_modules/require_resolvers/git_hub_resolver.sh'
  'shell_modules/require_resolvers/local_resolver.sh'
)
readonly Install_DEPENDENCIES=(
  "curl" "readlink" "cat" "head" "grep" "sed" "dirname" "basename" "mktemp"
)

readonly Install_SCRIPT_DIR="$(unset CDPATH; cd -- "$(dirname -- "${0}")" && echo "${PWD}")"
readonly Install_APP_NAME="shell_require"


Install_main() {
  local -r version_if_download="${1:-master}"

  local -r install_dir="${HOME}/.${Install_APP_NAME}"
  local -r bin_files_permission="700"
  local source_dir="${Install_SCRIPT_DIR}"

  echo "Verifying script dependencies for ${Install_APP_NAME}..."
  Install_verifyScriptDependencies || \
    Install_exit 1 "Not all dependencies present"

  echo "Verifying all files to be installed are present..."
  if ! Install_verifySourceFilesPresent "${source_dir}"; then
    source_dir=$(mktemp -d) || \
    { echo "Failed creating temporary download directory...">&2 && exit 1 ; }

    echo "Couldn't find script files on computer. Downloading them from GitHub..."
    Install_download "${version_if_download}" "${source_dir}" || \
      Install_exit $? "Failed downloading installation files"

    Install_verifySourceFilesPresent "${source_dir}" || \
      Install_exit 1 "Could still not find all files to be installed"
  fi

  echo "Installing ${Install_APP_NAME} to '${install_dir}'... "
  Install_copyInstallFiles "${source_dir}" "${install_dir}" "${bin_files_permission}" || \
    Install_exit 1 "Error copying files"

  Install_createConfigTemplate "${install_dir}"

  Install_addToPath "${install_dir}" || \
    Install_exit 1 "Error adding files to PATH"

  echo
  echo "Installation complete!"
  echo
  echo "As always: "
  echo "  Be careful when using online scripts - make sure they are trustworthy."
  echo
  Install_exit 0 "You can now use 'require'."
}

Install_verifyScriptDependencies() {
  local required_commands_present=true
  for required_command in "${Install_DEPENDENCIES[@]}"; do
    command -v "${required_command}" >/dev/null 2>&1 || \
      { required_commands_present=false && break; }
  done

  local dependencies_as_list=${Install_DEPENDENCIES[*]}
  dependencies_as_list=${dependencies_as_list// /, }
  if [ "${required_commands_present}" = "false" ]; then
    Install_err "Not all dependencies are installed on your computer."
    Install_err "Please make sure that "
    Install_err "  ${dependencies_as_list}"
    Install_err "are installed and available to the current user."
    return 1
  fi
  return 0
}

Install_verifySourceFilesPresent() {
  local -r work_dir="${1}"
  (
    unset CDPATH; cd "${work_dir}" || exit 3
    for file in "${Install_SOURCE_FILES[@]}"; do
      [ -f "${file}" ] || exit 1
    done
  )
  return $?
}


Install_copyInstallFiles() {
  local -r source_dir="$1"
  local -r install_dir="$2"
  local -r bin_files_permission="$3"

  [ -z "${source_dir}" ] || [ ! -d "${source_dir}" ] && return 1
  [ ! -w "$(dirname -- "${install_dir}")" ] && return 1

  mkdir -p "${install_dir}" || return 1
  cp -R "${source_dir}/"* "${install_dir}" || return 1
  chmod ${bin_files_permission} "${install_dir}/bin/"*
}

Install_download() {
  local -r version="$1"
  local -r download_dir="$2"

  local -r base_url="${Install_PROJECT_URL}/${version}"
  local source_file_string="${Install_SOURCE_FILES[*]}"
  source_file_string="${source_file_string// /,}"

  mkdir -p "${download_dir}" || return 1
  (
    unset CDPATH; cd "${download_dir}" || exit 1
    # Downloading all files manually, therefore neither
    # tar, gzip, or unzip is required
    curl -L "${base_url}/{${source_file_string}}" \
       -o "#1" \
       -f \
       --create-dirs \
       --compressed -#
 )
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
  local -r bin_file_path="${file_path}/bin"
  local -r require_src="${file_path}/shell_module.sh"
  local -r env_files=("${HOME}/.bashrc" "${HOME}/.bash_profile" "${HOME}/.shrc")

  local path_includes_require=false
  for env_file in "${env_files[@]}"; do
    # avoid adding multiple entries
    if [ -r "${env_file}" ] && grep -q "${require_src}" "${env_file}"; then
      path_includes_require=true; break
    fi

    if [ -w "${env_file}" ]; then
cat<<-END_OF_INCLUDE>>"${env_file}"
# Alternative install for ${Install_APP_NAME}
# export PATH="${bin_file_path}:\$PATH"
# Installing ${Install_APP_NAME} as function
source "${require_src}" 2>/dev/null || \\
  {
    echo
    echo "Error including '${Install_APP_NAME}' from '${require_src}'."
    echo
    echo "If you removed it, please manually remove the entries in '${env_file}' to get rid of this message."
    echo "Otherwise try re-installing it or file an issue on GitHub:"
    echo
    echo "  https://github.com/jtrefke/shell_require/issues"
    echo ;
  }
END_OF_INCLUDE
      [ $? -eq 0 ] && path_includes_require=true && break
    fi
  done

  if [ "${path_includes_require}" = "false" ]; then
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
  [ ${exit_code} -eq 0 ] && ${SHELL} || exit ${exit_code}
}

Install_main "$@"
