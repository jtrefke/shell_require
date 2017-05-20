#!/usr/bin/env bash

# Shell Module module - base for require
#
# Use 'install.sh' to install it
#
# Implemented by Joern Trefke < joern [at] trefke [dot] com >
# See: https://github.com/jtrefke/shell_require
#

ShellModule__getThisScriptFile() {
  local current_file_path=$0
  if [ -n "${BASH:-}" ]; then current_file_path=${BASH_SOURCE[0]}
  else current_file_path=$0
  fi
  echo ${current_file_path}
}

ShellModule__realDir() {
  local original_path="${1}"
  local file path
  [ ! -e "${original_path}" ] && return 1
  (
    unset CDPATH
    cd -- "$(dirname -- "${original_path}")" >/dev/null 2>&1 || return $?
    file="$(basename -- "${original_path}")"; original_path="${PWD}/${file}"
    while [ -h "${file}" ] && [ "${original_path}" != "${path}" ]; do
      path="$(readlink -- "${file}")"; file="$(basename -- "${path}")"
      cd -- "$(dirname -- "${path}")" >/dev/null 2>&1  || return $?
      path="${PWD}/${file}"
    done
    pwd -P
  )
}

if [ -z "${ShellModule__INSTALL_DIR:-}" ]; then
  readonly ShellModule__INSTALL_DIR="$(ShellModule__realDir "$(ShellModule__getThisScriptFile)")"
  export ShellModule__INSTALL_DIR
fi

if [ -f "${ShellModule__INSTALL_DIR}/shellmodulerc" ]; then
  # shellcheck source=/dev/null
  source "${ShellModule__INSTALL_DIR}/shellmodulerc"
fi

if [ -f "${HOME}/.shellmodulerc" ]; then
    # shellcheck source=/dev/null
    source "${HOME}/.shellmodulerc"
fi
[ "${ShellModule___IS_LOADED:-false}" != "false" ] && { [ "${BASH_SOURCE[0]}" = "$0" ] && exit 0 || return 0; }

ShellModule___IS_LOADED=true
export ShellModule___IS_LOADED
declare -Arg ShellModule_EX=(
  [OK]=0            # successful termination
  [USAGE]=64        # command line usage error: no input provided
  [DATAERR]=65      # data format error: resolved module not a valid shell file
  [UNAVAILABLE]=69  # service unavailable: module not available/found
  [CONFIG]=78       # configuration error: resolver does not implement interface
)

# External config variables
ShellModule_STORE_EXTERNAL_MODULES=${ShellModule_STORE_EXTERNAL_MODULES:-true}
ShellModule_RESOLVERS=(${ShellModule_RESOLVERS[@]:-})
ShellModule_PATH=${ShellModule_PATH:-}

# Internal
readonly ShellModule_DEFAULT_SCHEME="noscheme:"
readonly ShellModule__MODULES_DIRECTORY_NAME="shell_modules"
readonly ShellModule__DEFAULT_RESOLVERS=(
  "${ShellModule__INSTALL_DIR}/${ShellModule__MODULES_DIRECTORY_NAME}/require_resolvers/git_hub_resolver --match-scheme=gh:"
  "${ShellModule__INSTALL_DIR}/${ShellModule__MODULES_DIRECTORY_NAME}/require_resolvers/curl_resolver --match-scheme=https:"
  "${ShellModule__INSTALL_DIR}/${ShellModule__MODULES_DIRECTORY_NAME}/require_resolvers/curl_resolver --match-scheme=http:"
  "${ShellModule__INSTALL_DIR}/${ShellModule__MODULES_DIRECTORY_NAME}/require_resolvers/curl_resolver --match-scheme=ftp:"
)
ShellModule__USED_RESOLVERS=()


require() {
  ShellModule_require "$@"
}

ShellModule_isFunctionPresent() {
  declare -F $1>/dev/null 2>&1
}

ShellModule_isModulePresent() {
  local -r shellmodule_name=$(ShellModule__extractModuleInfo "${1}")

  compgen -A function | grep -qi "^${shellmodule_name}_" || \
  compgen -A variable | grep -q "^${shellmodule_name}__"
}

ShellModule_require() {
  local -r provided_module_name="${1:-}"
  local -r reload="${2:-noreload}"
  local -r module_name=${provided_module_name#@}

  if [ -z "${module_name}" ]; then
    ShellModule__log ${ShellModule_EX[USAGE]} "No module to import provided!"
    return $?
  elif ShellModule__isNoReloadingRequired "${reload}" "${module_name}" ;then
    ShellModule__log ${ShellModule_EX[OK]} "Module ${provided_module_name} has already been loaded... skipping"
    return $?
  fi

  local -r resolved_module_path=$(ShellModule__resolveModuleFile "${provided_module_name}" "${module_name}")
  local -r resolve_exit_code=$?
  if [ ${resolve_exit_code} -eq 3 ]; then
    ShellModule__log ${ShellModule_EX[CONFIG]} "Import resolver does not implement resolver interface (functions: resolve, canResolve, onAccepted, onRejected)!"
    return $?
  elif [ -z "${resolved_module_path}" ]; then
    ShellModule__log ${ShellModule_EX[UNAVAILABLE]} "Unable to find module ${provided_module_name}."
    return $?
  elif ! ShellModule__isShellModule "${resolved_module_path}"; then
    ShellModule__log ${ShellModule_EX[DATAERR]} "Module ${provided_module_name} is not a valid shell module (${resolved_module_path})"
    return $?
  fi

  local -r this_module="$(ShellModule__extractModuleInfo "$(ShellModule__fileSystemToModuleNotation "${module_name}")" "module")"
  # shellcheck source=/dev/null
  source "${resolved_module_path}" && \
    declare -g "${this_module}___IS_LOADED=true"
}

ShellModule__resolveModuleFile() {
  local provided_module_name="$1"
  local module_name="$2"

  local resolved_file=""
  local resolver_exit_code=$?

  if [ "${provided_module_name:0:2}" = "./" ]; then
    provided_module_name="$(dirname -- "$(ShellModule__getInvokedScriptFile)")/${provided_module_name:2}"
  fi

  # Builtin: Resolve absolute paths
  # For everything else: use resolvers
  if [ "${provided_module_name:0:1}" = "/" ]; then
    resolved_file="$(ShellModule__resolveAbsolutePath "${provided_module_name}")"
  else
    local original_module_path="${module_name#*:}"
    local module_scheme="${module_name:0:$((${#module_name}-${#original_module_path}))}"
    [ -z "${module_scheme:-}" ] && module_scheme="${ShellModule_DEFAULT_SCHEME}"
    [ "${original_module_path:0:2}" == "//" ] && original_module_path="${original_module_path:2}"

    local -r local_resolver_path="$(ShellModule__getModulesDirectory "${ShellModule__INSTALL_DIR}")/require_resolvers/local_resolver.sh"
    ShellModule_isModulePresent "LocalResolver" || ShellModule_require "${local_resolver_path}"
    resolved_file=$(LocalResolver_resolve "${module_scheme}" "${original_module_path}" --search-path="$(ShellModule__moduleSearchPaths)")
    resolver_exit_code=$?

    ShellModule__USED_RESOLVERS=("${ShellModule__DEFAULT_RESOLVERS[@]}" "${ShellModule_RESOLVERS[@]:-}")
    if [ -z "${resolved_file}" ] && [ "${provided_module_name:0:1}" = "@" ] && [ ${#ShellModule__USED_RESOLVERS[@]} -gt 0 ]; then
      local suffixed_module_path="${original_module_path%.sh}.sh"
      resolved_file=$(ShellModule__resolveUsingExternalResolvers "${module_scheme}" "${suffixed_module_path}" "${module_name}")
      resolver_exit_code=$?
    fi
  fi

  echo "${resolved_file}"
  return ${resolver_exit_code:-0}
}

ShellModule__resolveAbsolutePath() {
  local -r module_name="${1}"
  local -r sanitized_module_name="$(ShellModule__sanitizedModulePath "${module_name}")"
  local potential_module_paths=("${module_name}")
  if [ "${module_name}" != "${sanitized_module_name}" ]; then
    potential_module_paths+=("${sanitized_module_name}")
  fi

  local resolved_file=""
  for path_to_test in "${potential_module_paths[@]}"; do
    path_to_test="${path_to_test%.sh}"
    if [ -s "${path_to_test}.sh" ]; then
      resolved_file="${path_to_test}.sh"; break
    elif [ -s "${path_to_test}" ]; then
      resolved_file="${path_to_test}"; break
    fi
  done

  echo "${resolved_file}"
}

ShellModule__resolveUsingExternalResolvers() {
  local -r module_scheme="$1"
  local -r module_path="$2"
  local -r module_name="$3"

  local resolved_path=""
  local module_path_result=""
  declare -A resolver

  for resolver_path_w_args in "${ShellModule__USED_RESOLVERS[@]}"; do
    [ -n "${resolver_path_w_args}" ] || continue
    local resolver_and_arguments=(${resolver_path_w_args})
    local resolver_path=${resolver_and_arguments[0]}
    local arguments=(${resolver_and_arguments[@]:1})

    local resolver_package_module
    resolver_package_module=$(ShellModule__fileSystemToModuleNotation "${resolver_path}")
    local resolver_module
    resolver_module=$(ShellModule__extractModuleInfo "${resolver_package_module}" "module")
    resolver[MODULE_NAME]="${resolver_module}"
    resolver[canResolve]="${resolver_module}_canResolve"
    resolver[resolve]="${resolver_module}_resolve"
    resolver[rejected]="${resolver_module}_onRejected"
    resolver[accepted]="${resolver_module}_onAccepted"

    if ! ShellModule_isFunctionPresent "${resolver[resolve]}" ; then
      ShellModule_require "${resolver_path}" >/dev/null 2>&1 || return 3
      if ! ShellModule_isFunctionPresent "${resolver[resolve]}" || \
         ! ShellModule_isFunctionPresent "${resolver[canResolve]}" || \
         ! ShellModule_isFunctionPresent "${resolver[rejected]}" || \
         ! ShellModule_isFunctionPresent "${resolver[accepted]}" ; then
        return 3
      fi
    fi
    (${resolver[canResolve]} "${module_scheme}" "${module_path}" "${arguments[@]}")>/dev/null 2>&1 || continue
    resolved_path="$(mktemp)" || return 1
    (${resolver[resolve]} "${module_scheme}" "${module_path}" "${resolved_path}" "${arguments[@]}")>/dev/null 2>&1 || continue
    if ! ShellModule__isShellModule "${resolved_path}" ; then
      [ -e "${resolved_path}" ] && rm "${resolved_path}"
      (${resolver[rejected]} "${resolved_path}")>/dev/null 2>&1
      continue
    fi
    module_path_result="${resolved_path}"
    break
  done
  [ -z "${module_path_result}" ] && return 1

  (${resolver[accepted]} "${module_scheme}" "${module_path}" "${resolved_path}")>/dev/null 2>&1

  if [ "${ShellModule_STORE_EXTERNAL_MODULES:-true}" = "true" ]; then
    local -r script_modules_dir=$(ShellModule__getModulesDirectory "$(ShellModule__getInvokedScriptFile)")
    local local_package_name="${module_path}"
    [ "${module_scheme}" != "${ShellModule_DEFAULT_SCHEME}" ] && local_package_name="${module_scheme}${local_package_name}"
    resolved_path=$(ShellModule__storeExternalModule "${module_path_result}" "${script_modules_dir}" "${local_package_name}")

    if [ $? -eq 0 ]; then
      module_path_result="${resolved_path}"
    fi
  fi
  echo "${module_path_result}"
}

ShellModule__storeExternalModule() {
  local -r current_file_path="$1"
  local -r script_modules_dir="$2"
  local -r sanitized_module=$(ShellModule__sanitizedModulePath "$3")

  local -r script_modules_parent_dir=$(dirname -- "${script_modules_dir}")
  local -r target_file_path="${script_modules_dir}/${sanitized_module}"
  local stored_file_path=""
  if [ -d "${script_modules_parent_dir}" ] && [ ! -f "${target_file_path}" ]; then
    mkdir -p -- "$(dirname -- "${target_file_path}")" && \
    mv -- "${current_file_path}" "${target_file_path}" && \
    stored_file_path="${target_file_path}"
  fi
  if [ -z "${stored_file_path}" ]; then
    return 1
  fi
  echo "${stored_file_path}"
}

ShellModule__isSourced() {
  [ "$(basename -- "${BASH_SOURCE[0]}")" != "$(basename -- "$0")" ]
}

ShellModule__log() {
  local -r exit_code=${1:-1}; shift
  local -r message="$*"

  local -r script_name="$(basename -- "$0")"
  local -r output_stream=$([ ${exit_code} -eq 0 ] && echo 1 || echo 2)

  ! ShellModule__isSourced && echo "${script_name}: ${message}">&${output_stream}
  return ${exit_code}
}

ShellModule__getModulesDirectory() {
  local root_dir="$1"

  [ -f "${root_dir}" ] && root_dir="$(dirname -- "${root_dir}")"
  [ ! -d "${root_dir}" ] && return 1

  local -r absolute_root_dir="$(unset CDPATH; cd -- "${root_dir}" && echo "${PWD}")"
  [ $? -ne 0 ] || [ -z "${absolute_root_dir}" ] && return 1

  echo "${absolute_root_dir}/${ShellModule__MODULES_DIRECTORY_NAME}"
}


ShellModule__getInvokedScriptFile() {
  local current_file_path=$0

  if [ "${BASH:-notset}" != "notset" ] ; then current_file_path=${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]}
  elif [ "${ZSH_NAME:-notset}" != "notset" ]; then current_file_path=$0
  elif [ "${TMOUT:-notset}" != "notset" ]; then
    # shellcheck disable=SC2154
    current_file_path=${.sh.file}
  elif [ ${0##*/} = dash ]; then x=$(lsof -p $$ -Fn0 | tail -1); current_file_path=${x#n}
  else current_file_path=$0
  fi

  echo ${current_file_path}
}

ShellModule__isNoReloadingRequired() {
  local -r reload="$1"
  local -r module_name="$2"
  [ "${reload}" != "reload" ] && \
    ShellModule_isModulePresent \
      "$(ShellModule__fileSystemToModuleNotation "${module_name}")"
}

# Workaround for normalized module name, as
# BSD sed does not have the GNU sed uppercase/lowercase extensions
ShellModule__capitalizeAfter() {
  local input="$1"; shift

  local current_char
  local previous_char=/
  local len=${#input}
  for ((i=0; i<${len}; i=$i+1)); do
    current_char=${input:${i}:1}
    if [ "${previous_char}" = "/" ] || [ "${previous_char}" = "_" ]; then
      current_char=$(echo "${current_char}" | sed "y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/")
      input="${input:0:${i}}${current_char}${input:$((${i}+1))}"
    fi
    previous_char=${current_char}
  done
  echo "${input}"
}

ShellModule__fileSystemToModuleNotation() {
  local file_system_path="$1"
  local module_notation_name
  module_notation_name=$(
    echo ${file_system_path} | \
    sed -E 's/.*\/shell_modules\///;s/(.+)\.sh$/\1/i;s/[^a-zA-Z0-9_\/]/_/g;s/(_|\/){2,}/_/g'
  ) || return 1
  module_notation_name=$(ShellModule__capitalizeAfter "${module_notation_name}")
  echo "${module_notation_name//_/}"
}

ShellModule__sanitizedModulePath() {
  local -r module_path="$1"
  echo "${module_path}" | sed -E 's/[^a-zA-Z0-9\/_\.\-]/_/gi;s/(_|\/){2,}/\1/g;'
}

ShellModule__extractModuleInfo() {
  local -r available_info="$1"
  local -r requested_data="${2:-module}"
  declare -A module_info

  module_info[module_and_function]="${available_info##*/}"
  module_info[module]="${module_info[module_and_function]%_*}"
  module_info[function]="${module_info[module_and_function]/${module_info[module]}/}" #"*_}"
  module_info[function]="${module_info[function]#*_}"
  module_info[package]="${available_info/${module_info[module_and_function]}/}"
  module_info[package]="${module_info[package]%/}"

  echo "${module_info[${requested_data}]}"
}

ShellModule__isShellModule() {
  local file_path="$1"
  [ -s "${file_path}" ] && \
  sed -n '/./{p;q;}' "${file_path}" 2>/dev/null | \
  grep -s -q -E '^\s*#\s*!\s*/((usr/)?bin/)(env\s+.*sh|.*sh)\s*$'
  return $?
}

ShellModule__moduleSearchPaths() {
  local -r local_modules_dir=$(ShellModule__getModulesDirectory "${PWD}")
  local -r script_modules_dir=$(ShellModule__getModulesDirectory "$(ShellModule__getInvokedScriptFile)")
  local -r script_dir=$(dirname -- "${script_modules_dir}")
  local -r user_modules_dir=$(ShellModule__getModulesDirectory "${HOME}")
  local module_search_paths="${PWD}:${local_modules_dir}:${script_dir}:${script_modules_dir}"
  module_search_paths+=":${HOME}:${user_modules_dir}:${ShellModule__GLOBAL_MODULES_DIRECTORY}:${ShellModule_PATH:-}"

  echo "${module_search_paths}"
}

readonly ShellModule__GLOBAL_MODULES_DIRECTORY="$(ShellModule__getModulesDirectory "$(ShellModule__realDir "$(ShellModule__getThisScriptFile)")")"
