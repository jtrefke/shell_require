#!/usr/bin/env bash

LocalResolver__sanitizedModulePath() {
  local module_path="$1"
  echo "${module_path}" | sed -E 's/[^a-zA-Z0-9\/_\.]/_/gi;s/(_|\/){2,}/\1/g;'
}

LocalResolver__getModuleFile() {
  local possible_paths=("$1")
  local -r sanitized_path="$(LocalResolver__sanitizedModulePath "$1")"
  if [ "${sanitized_path}" != "$1" ]; then
    possible_paths+=("${sanitized_path}")
  fi

  local module_path=""
  for path in "${possible_paths[@]}"; do
    path="${path%.sh}"
    if [ -s "${path}.sh" ]; then
      module_path="${path}.sh"; break
    elif [ -s "${path}" ]; then
      module_path="${path}"; break
    fi
  done

  echo "${module_path}"
}

LocalResolver__searchModulePath() {
  local -r path_list="$1"
  local -r module="$2"

  local found_module
  for path in ${path_list//:/ }; do
    [ -d "${path}" ] || continue
    found_module=$(LocalResolver__getModuleFile "${path}/${module}")
    [ -n "${found_module}" ] && break
  done
  echo "${found_module}"
  [ -s "${found_module}" ]
  return $?
}

LocalResolver_resolve() {
  local -r module_scheme="$1"; shift
  local -r module_name="$1"; shift
  # local -r output_file="$1"; shift

  if [ -f "${module_name}" ]; then
    echo "${module_name}"
    return 0
  fi

  local -r options_arr="$(LocalResolver__parseOptions "${module_scheme}" "${module_name}" "$@")"
  eval "declare -A options=${options_arr}"
  local module_search_paths="${options[search]:-${PWD}}"
  LocalResolver__searchModulePath "${module_search_paths}" "${module_name}"
  return $?
}

LocalResolver_canResolve() {
  local module_scheme="$1"; shift
  local module_name="$1"; shift

  local -r options_arr="$(LocalResolver__parseOptions "${module_scheme}" "${module_name}" "$@")"
  eval "declare -A options=${options_arr}"
  [ -z "${options[scheme]:-}" ] || \
    { [ -n "${options[scheme]:-}" ] && [ "${options[scheme]}" = "${module_scheme}" ]; }
}

LocalResolver_onRejected() {
  # local output_file="$1"
  return 0
}

LocalResolver_onAccepted() {
  # local module_scheme="$1"; shift
  # local module_name="$1"; shift
  # local output_file="$1"; shift
  return 0
}

LocalResolver__parseOptions() {
  local scheme="$1"; shift
  local module="$1"; shift
  # options = $@

  declare -A options=()
  for option in "$@"; do
    case ${option} in
      -p=*|--prefix=*)
      options[prefix]="${option#*=}"; shift
      ;;
      -s=*|--match-scheme=*)
      options[scheme]="${option#*=}"; shift
      ;;
      -r=*|--resolve-only=*|--resolve-prefix=*)
      options[prefix]="${option#*=}"; shift
      ;;
      -s=*|--search-path=*)
      options[search]="${option#*=}"; shift
      ;;
      -*)
      ;;
    esac
  done

  local -r result_values=$(declare -p options)
  echo "${result_values#*=}"
}
