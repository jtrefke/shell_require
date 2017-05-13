#!/usr/bin/env bash

test_resolve_Resolves_existing_available_module_via_web() {
  helper_validResolve "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME}" "${VALID_MODULE_CONTENT}"
}

test_resolve_Resolves_existing_available_module_via_web_using_owner() {
  owner="${VALID_MODULE_NAME%%/*}"
  rest="${VALID_MODULE_NAME#*/}"

  helper_validResolve "${DEFAULT_SCHEME}" "${rest}" "${VALID_MODULE_CONTENT}" --owner="${owner}"
}

test_resolve_Resolves_existing_available_module_via_web_using_owner_and_repo() {
  owner="${VALID_MODULE_NAME%%/*}"
  rest="${VALID_MODULE_NAME#*/}"
  repo="${rest%%/*}"
  rest="${rest#*/}"

  helper_validResolve "${DEFAULT_SCHEME}" "${rest}" "${VALID_MODULE_CONTENT}" --owner="${owner}" --repo="${repo}"
}

test_resolve_Resolves_existing_available_module_via_web_using_using_owner_repo_and_ref() {
  owner="${VALID_MODULE_NAME%%/*}"
  rest="${VALID_MODULE_NAME#*/}"
  repo="${rest%%/*}"
  rest="${rest#*/}"
  ref="${rest%%/*}"
  rest="${rest#*/}"

  helper_validResolve "${DEFAULT_SCHEME}" "${rest}" "${VALID_MODULE_CONTENT}" --owner="${owner}" --repo="${repo}" --branch="${ref}"
}

test_resolve_Resolves_existing_available_module_via_web_using_prefix() {
  prefix="${VALID_MODULE_NAME%/*}"
  rest="${VALID_MODULE_NAME##*/}"

  helper_validResolve "${DEFAULT_SCHEME}" "${rest}" "${VALID_MODULE_CONTENT}" --prefix="${prefix}/"
}

test_resolve_Fails_resolving_if_prefix_does_not_end_with_slash() {
  prefix="${VALID_MODULE_NAME%/*}"
  rest="${VALID_MODULE_NAME##*/}"

  helper_invalidResolve "${DEFAULT_SCHEME}" "${rest}" "${VALID_MODULE_CONTENT}" --prefix="${prefix}"
}

test_resolve_Fails_resolving_non_existing_available_module_via_web() {
  helper_invalidResolve "${DEFAULT_SCHEME}" "${INVALID_MODULE_NAME}"
}

test_resolve_Resolves_existing_available_module_via_api() {
  assertNotEquals 'TestRunner_GITHUB_TOKEN must be different from the invalid token' "${VALID_GITHUB_TOKEN}" "${INVALID_GITHUB_TOKEN}"

  [ "${VALID_GITHUB_TOKEN}" = "${INVALID_GITHUB_TOKEN}" ] && startSkipping

  helper_validResolve "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME}" "${VALID_MODULE_CONTENT}" --token="${VALID_GITHUB_TOKEN}"

  [ "${VALID_GITHUB_TOKEN}" = "${INVALID_GITHUB_TOKEN}" ] && endSkipping
}

test_resolve_Fails_resolving_when_wrong_token_is_provided_via_api() {
  helper_invalidResolve "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME}" --token="${INVALID_GITHUB_TOKEN}"
}

test_resolve_Fails_resolving_non_existing_available_module_via_api() {
  assertNotEquals 'TestRunner_GITHUB_TOKEN must be different from the invalid token' "${VALID_GITHUB_TOKEN}" "${INVALID_GITHUB_TOKEN}"

  [ "${VALID_GITHUB_TOKEN}" = "${INVALID_GITHUB_TOKEN}" ] && startSkipping

  helper_invalidResolve "${DEFAULT_SCHEME}" "${INVALID_MODULE_NAME}" --token="${VALID_GITHUB_TOKEN}"

  [ "${VALID_GITHUB_TOKEN}" = "${INVALID_GITHUB_TOKEN}" ] && endSkipping
}

test_canResolve_Returns_true_if_all_required_information_is_present() {
  GitHubResolver_canResolve "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME}" # other options
  exit_code=$?
  assertTrue "GitHubResolver_canResolve exit code is 0" "[ ${exit_code} -eq 0 ]"

  GitHubResolver_canResolve "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME}" --owner="owner" --repo="repo" --ref="ref"
  exit_code=$?
  assertTrue "GitHubResolver_canResolve exit code is 0" "[ ${exit_code} -eq 0 ]"

  GitHubResolver_canResolve "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME}" --prefix="owner/repo/ref/"
  exit_code=$?
  assertTrue "GitHubResolver_canResolve exit code is 0" "[ ${exit_code} -eq 0 ]"
}

test_canResolve_Returns_false_if_required_information_is_missing() {
  GitHubResolver_canResolve "${DEFAULT_SCHEME}" "owner/repo/branch" # other options
  exit_code=$?
  assertTrue "GitHubResolver_canResolve exit code is greater than 0" "[ ${exit_code} -gt 0 ]"

  GitHubResolver_canResolve "${DEFAULT_SCHEME}" "" --owner="owner" --repo="repo" --ref="ref"
  exit_code=$?
  assertTrue "GitHubResolver_canResolve exit code is greater than 0" "[ ${exit_code} -gt 0 ]"

  GitHubResolver_canResolve "${DEFAULT_SCHEME}" "ref" --prefix="owner/repo/"
  exit_code=$?
  assertTrue "GitHubResolver_canResolve exit code is greater than 0" "[ ${exit_code} -gt 0 ]"
}

test_canResolve_Returns_true_if_resolve_prefix_matches_module() {
  GitHubResolver_canResolve "${DEFAULT_SCHEME}" "master/module" --prefix="owner/repo/" --resolve-only="master"
  exit_code=$?
  assertTrue "GitHubResolver_canResolve exit code is 0" "[ ${exit_code} -eq 0 ]"
}

test_canResolve_Returns_true_if_any_resolve_prefixes_match_module() {
  GitHubResolver_canResolve "${DEFAULT_SCHEME}" "master/module" --prefix="owner/repo/" --resolve-only="v1.0.0 master"
  exit_code=$?
  assertTrue "GitHubResolver_canResolve exit code is 0" "[ ${exit_code} -eq 0 ]"
}

test_canResolve_Returns_false_if_resolve_prefix_does_not_match_module() {
  GitHubResolver_canResolve "${DEFAULT_SCHEME}" "master/module" --prefix="owner/repo/" --resolve-only="owner/repo/nomaster"
  exit_code=$?
  assertTrue "GitHubResolver_canResolve exit code is greater than 0" "[ ${exit_code} -gt 0 ]"
}

test_canResolve_Returns_true_if_scheme_does_match_module() {
  GitHubResolver_canResolve "${DEFAULT_SCHEME}" "owner/repo/master/module" --match-scheme="${DEFAULT_SCHEME}"
  exit_code=$?
  assertTrue "GitHubResolver_canResolve exit code is 0" "[ ${exit_code} -eq 0 ]"
}

test_canResolve_Returns_false_if_scheme_does_not_match_module() {
  GitHubResolver_canResolve "${DEFAULT_SCHEME}" "owner/repo/master/module" --match-scheme="different${DEFAULT_SCHEME}"
  exit_code=$?
  assertTrue "GitHubResolver_canResolve exit code is greater than 0" "[ ${exit_code} -gt 0 ]"
}

test_onRejected_Remove_created_files() {
  invalid_file="${SHUNIT_TMPDIR}/git_hub_resolver_${RANDOM}.sh"
  touch "${invalid_file}"
  touch "${invalid_file}.headers"

  assertTrue "Invalid output file exists" "[ -f \"${invalid_file}\" ]"
  assertTrue "Invalid headers file exists" "[ -f \"${invalid_file}.headers\" ]"

  GitHubResolver_onRejected "${invalid_file}"
  exit_code=$?

  assertFalse "Invalid output file has been removed" "[ -f \"${invalid_file}\" ]"
  assertFalse "Invalid headers file has been removed" "[ -f \"${invalid_file}.headers\" ]"
}

test_onAccepted_Return_true() {
  GitHubResolver_onAccepted "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME}" # resolved path + other options
  exit_code=$?

  assertTrue "GitHubResolver_onAccepted exit code is 0" "[ ${exit_code} -eq 0 ]"
}


################################################################################

helper_validResolve() {
  module_scheme="$1"; shift
  module_name="$1"; shift
  expected_content="$1"; shift
  # $@ module args

  output_file="${SHUNIT_TMPDIR}/git_hub_resolver_${RANDOM}.sh"

  result="$(GitHubResolver_resolve "${module_scheme}" "${module_name}" "${output_file}" "$@")"
  exit_code=$?

  assertTrue "GitHubResolver_resolve exit code is 0" ${exit_code}
  assertTrue "Output file is not empty" "[ -s \"${output_file}\" ]"
  assertEquals "Output is expected output file" "${expected_content}" "$(cat "${output_file}")"
  assertEquals "Result equals output file" "${result}" "${output_file}"

  [ -f "${output_file}" ] && rm "${output_file}"
}

helper_invalidResolve() {
  module_scheme="$1"; shift
  module_name="$1"; shift
  expected_content=""
  # $@ module args

  output_file="${SHUNIT_TMPDIR}/git_hub_resolver_${RANDOM}.sh"

  result="$(GitHubResolver_resolve "${module_scheme}" "${module_name}" "${output_file}" "$@")"
  exit_code=$?

  assertTrue "GitHubResolver_resolve exit code greater than 0" "[ ${exit_code} -gt 0 ]"
  assertTrue "Output file does not exist" "[ ! -e \"${output_file}\" ]"
  assertEquals "Result is empty" "${expected_content}" "${result}"

  [ -f "${output_file}" ] && rm "${output_file}"
}

oneTimeSetUp() {
  DEFAULT_SCHEME='noscheme:'
  VALID_MODULE_NAME='kward/shunit2/master/source/2.1/bin/which'
  VALID_MODULE_CONTENT="$(curl -s -L https://raw.githubusercontent.com/kward/shunit2/master/source/2.1/bin/which)"
  INVALID_MODULE_NAME='jtrefke/random/master/something/invalid'
  INVALID_MODULE_NAME=""

  INVALID_GITHUB_TOKEN='TOKEN'
  VALID_GITHUB_TOKEN="${TestRunner_GITHUB_TOKEN:-${INVALID_GITHUB_TOKEN}}"

  # shellcheck disable=SC1090,SC2154
  . "${TestRunner_PROJECT_ROOT}/shell_modules/require_resolvers/git_hub_resolver.sh"
}

# shellcheck disable=SC1090
. "$(which shunit2)"
