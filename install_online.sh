#!/usr/bin/env bash

readonly InstallOnline_SOURCE_FILES=(
  'install.sh'
  'shell_module.sh'
  'README.md'
  'LICENSE'
  'bin/require'
  'shell_modules/require_resolvers/curl_resolver.sh'
  'shell_modules/require_resolvers/git_hub_resolver.sh'
  'shell_modules/require_resolvers/local_resolver.sh'
)
readonly InstallOnline_PROJECT_URL="https://raw.githubusercontent.com/jtrefke/shell_require"

InstallOnline_main() {
  local -r version="${1:-master}"

  local -r work_dir=$(mktemp --directory --suffix='-require-install') || \
    { echo "Failed creating download directory...">&2 && exit 1 ; }
  (
    echo "Downloading installation files from GitHub..."
    cd "${work_dir}" && \
    InstallOnline_download "${version}" && \
    ${SHELL} "${work_dir}/install.sh"
  ) || \
    {
      echo "Online installation failed - this shouldn't happen.">&2
      echo "Please contact the repository owner, so that it can be fixed.">&2
      exit 1
    }

  [ -d "${work_dir}" ] && [ "${#work_dir}" -gt 17 ] && rm -r "${work_dir}"
}

InstallOnline_download() {
  local -r version="$1"
  local -r base_url="${InstallOnline_PROJECT_URL}/${version}"

  source_file_string="${InstallOnline_SOURCE_FILES[*]}"
  source_file_string="${source_file_string// /,}"

  # Downloading all files manually, therefore neither
  # tar, gzip, or unzip is required
  curl -L "${base_url}/{${source_file_string}}" \
       -o "#1" \
       --create-dirs \
       --compressed -#
}

InstallOnline_main "$@"
