#!/usr/bin/env bash

readonly GitHubResolver_ENDPOINT_API="https://api.github.com"
readonly GitHubResolver_ENDPOINT_PUBLIC="https://raw.githubusercontent.com"

GitHubResolver_resolve() {
  local -r scheme="$1"; shift
  local -r module="$1"; shift

  declare -A output
  output[file]="$1"; shift
  output[headers]="$(GitHubResolver__headerFilePath "${output[file]}")"

  local -r options_arr=$(GitHubResolver__parseOptions "${scheme}" "${module}" "$@")
  eval "declare -A options=${options_arr}"
  if [ ${#options[@]} -eq 0 ]; then
    return 1
  fi

  local github_fn=""
  [ -z "${options[token]}" ] && \
    github_fn="GitHubResolver__getGitHubContentPublic" || \
    github_fn="GitHubResolver__getGitHubContentApi"
  ${github_fn} "${options[owner]}" "${options[repo]}" "${options[path]}" "${options[ref]}" "${output[file]}" "${output[headers]}" "${options[token]}"

  local exit_code=$?
  local -r http_status_code=$(head -1 "${output[headers]}" | cut -d ' ' -f2)
  if [ ${exit_code} -ne 0 ] || [ ${http_status_code} -gt 399 ]; then
    exit_code=1
    [ -f "${output[file]}" ] && rm "${output[file]}"
    output[file]=""
  fi
  [ -f "${output[headers]}" ] && rm "${output[headers]}"

  echo "${output[file]}"
  return ${exit_code}
}

GitHubResolver_canResolve() {
  local -r scheme="$1"; shift
  local -r module="$1"; shift
  command -v curl >/dev/null 2>&1 || return 1

  local -r options_arr="$(GitHubResolver__parseOptions "${scheme}" "${module}" "$@")"
  eval "declare -A options=${options_arr}"
  if [ ${#options[@]} -eq 0 ]; then
    return 1
  elif [ -n "${options[scheme]:-}" ] && [ "${options[scheme]}" != "${scheme}" ]; then
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

GitHubResolver_onRejected() {
  local -r output_file="$1"
  local -r header_file="$(GitHubResolver__headerFilePath "${output_file}")"

  [ -f "${output_file}" ] && rm "${output_file}"
  [ -f "${header_file}" ] && rm "${header_file}"
}

GitHubResolver_onAccepted() {
  # shellcheck disable=SC2034
  local -r module_scheme="$1"
  # shellcheck disable=SC2034
  local -r module_name="$2"
  # shellcheck disable=SC2034
  local -r output_file="$3"
}

GitHubResolver__parseOptions() {
  local scheme="$1"; shift
  local module="$1"; shift
  # options = $@

  # TODO: figure out more intelligent arguments/resolution of arguments
  declare -A options=()
  for option in "$@"; do
    case ${option} in
      -r=*|--resolve-only=*)
        options[resolve]="${option#*=}"; shift
      ;;
      -s=*|--match-scheme=*)
        options[scheme]="${option#*=}"; shift
      ;;
      -p=*|--prefix=*)
        options[prefix]="${option#*=}"; shift
      ;;
      -o=*|--owner=*)
        options[owner]="${option#*=}"; shift
      ;;
      -e=*|--repo=*)
        options[repo]="${option#*=}"; shift
      ;;
      -b=*|--branch=*|--version=*|--tag=*|ref=*)
        options[ref]="${option#*=}"; shift
      ;;
      -t=*|--token=*|--personal-access-token=*|--oauth-token=*)
        options[token]="${option#*=}"; shift
        options[token]="${options[token]#\"}"; options[token]="${options[token]%\"}"
        options[token]="${options[token]#\'}"; options[token]="${options[token]%\'}"
      ;;
      *)
      ;;
    esac
  done

  local prefixed_module="${options[prefix]:-}${module}"
  local module_info=(
    ${options[owner]:-}
    ${options[repo]:-}
    ${options[ref]:-}
    ${prefixed_module//\// }
  )
  # "Missing at least path in GitHub ${module}."
  if [ ${#module_info[@]} -lt 4 ] || \
    { [ -n "${options[prefix]:-}" ] && [ "${options[prefix]: -1}" != "/" ]; }; then
    echo '('')'
    return 1
  fi

  options[owner]=${module_info[0]}
  options[repo]=${module_info[1]}
  options[ref]=${module_info[2]}
  options[path]=${prefixed_module#*${options[ref]}/}
  options[token]=${options[token]:-${GitHubResolver_AUTH_TOKEN:-}}

  local -r result_values=$(declare -p options)
  echo "${result_values#*=}"
}

GitHubResolver__getGitHubContentPublic() {
  local -r output_file="$5"
  local -r header_output_file="$6"
  local -r github_url="${GitHubResolver_ENDPOINT_PUBLIC}/$1/$2/$4/$3"
  curl -D "${header_output_file}" \
       -o "${output_file}" \
       -L "${github_url}" \
       -s >/dev/null 2>&1
}

GitHubResolver__getGitHubContentApi() {
  local -r output_file="$5"
  local -r header_output_file="$6"
  local -r oauth_token="$7"
  local -r github_url="${GitHubResolver_ENDPOINT_API}/repos/$1/$2/contents/$3?ref=$4"
  # GET /repos/:owner/:repo/contents/:path
  # See https://developer.github.com/v3/repos/contents/#get-contents
  curl -H "Authorization: token ${oauth_token}" \
       -H 'Accept: application/vnd.github.v3.raw' \
       -D "${header_output_file}" \
       -o "${output_file}" \
       -L "${github_url}" \
       -s >/dev/null 2>&1
}

GitHubResolver__headerFilePath() {
  local output_file="$1"
  echo "${output_file}.headers"
}
