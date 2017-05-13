#!/usr/bin/env bash

CurlResolver__headerFileFromOutputFile() {
  local output_file="${1:-}"
  echo "${output_file}.headers"
}


CurlResolver_resolve() {
  local -r module_scheme="$1"; shift
  local -r module="$1"; shift
  local -r output_file="$1"; shift

  declare -A named_options
  local curl_pass_through=()
  for option in "$@"; do
    case ${option} in
      -u=*|--user=*)
      named_options[user]="${option#*=}"; shift
      ;;
      -p=*|--prefix=*)
      named_options[prefix]="${option#*=}"; shift
      ;;
      -r=*|--resolve-only=*)
      ;;
      -s=*|--match-scheme=*)
      ;;
      *)
      curl_pass_through+=("${option}"); shift
      ;;
    esac
  done

  declare -A output
  output[file]="${output_file}"
  output[headers]="$(CurlResolver__headerFileFromOutputFile "${output[file]}")"

  local module_url="${named_options[prefix]:-}${module}"
  # local scheme=$(echo "${module_url}" | sed -n -r 's/^(https?|ftp):\/\/.*/\1/p')
  if [ -z "${scheme}" ]; then
    scheme="http"
  fi

  local curl_arguments=(-o "${output[file]}")
  if [ "${scheme}" = "http" ] || [ "${scheme}" = "https" ]; then
    curl_arguments+=(-L "${module_url}")
  elif [ "${scheme}" = "ftp" ]; then
    curl_arguments+=("${module_url}")
  fi

  if [ "${scheme}" = "ftp" ] && [ -z "${named_options[user]:-}" ]; then
    curl_arguments+=(--user "anonymous:anonymous")
  fi

  curl_arguments=("${curl_arguments[@]}" "${curl_pass_through[@]}")
  curl_arguments+=(-D "${output[headers]}")
  curl "${curl_arguments[@]}" -s >/dev/null 2>&1

  local exit_code=$?
  local http_status_code
  http_status_code=$(head -1 "${output[headers]}" | cut -d ' ' -f2)

  if [ ${exit_code} -ne 0 ] || [ ${http_status_code} -gt 399 ]; then
    exit_code=1
    output[file]=""
  fi

  echo "${output[file]}"
  return ${exit_code}
}

CurlResolver_canResolve() {
  local module_scheme="$1"; shift
  local module="$1"; shift

  command -v curl >/dev/null 2>&1 || return 1
  declare -A options
  for option in "$@"; do
    case ${option} in
      -r=*|--resolve-only=*)
      options[resolve]="${option#*=}"; shift
      ;;
      -s=*|--match-scheme=*)
      options[scheme]="${option#*=}"; shift
      ;;
      *)
      ;;
    esac
  done

  if [ -z "${module:-}" ]; then
    return 1
  elif [ -n "${options[scheme]:-}" ] && [ "${options[scheme]}" != "${module_scheme}" ]; then
    return 1
  elif [ -n "${options[resolve]:-}" ]; then
    local resolve_list=(${options[resolve]})
    for prefix in "${resolve_list[@]}"; do
      [ "${module:0:${#prefix}}" = "${prefix}" ] && return 0
    done
    return 1
  fi

  return 0
}

CurlResolver_onRejected() {
  local output_file="$1"

  local header_file
  header_file="$(CurlResolver__headerFileFromOutputFile "${output_file}")"
  [ -f "${output_file}" ] && rm "${output_file}"
  [ -f "${header_file}" ] && rm "${header_file}"
}

CurlResolver_onAccepted() {
  # shellcheck disable=SC2034
  local -r module_scheme="$1"
  # shellcheck disable=SC2034
  local -r module_name="$2"
  # shellcheck disable=SC2034
  local -r output_file="$3"
}
