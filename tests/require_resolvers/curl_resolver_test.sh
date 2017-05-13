#!/usr/bin/env bash

test_resolve_Resolves_existing_available_module_using_scheme() {
  helper_validResolve "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME}" "${VALID_MODULE_CONTENT}"
}

test_resolve_Resolves_existing_available_module_without_scheme() {
  helper_validResolve "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME_WITHOUT_SCHEME}" "${VALID_MODULE_CONTENT}"
}

test_resolve_Resolves_existing_available_module_using_prefix() {
  prefix="${VALID_MODULE_NAME%%/*}"
  rest="${VALID_MODULE_NAME#*/}"

  helper_validResolve "${DEFAULT_SCHEME}" "${rest}" "${VALID_MODULE_CONTENT}" --prefix="${prefix}"
}

test_resolve_Resolves_existing_available_module_passing_curl_options() {
  assertNotEquals 'TestRunner_GITHUB_TOKEN must be different from the invalid token' "${VALID_GITHUB_TOKEN}" "${INVALID_GITHUB_TOKEN}"
  [ "${VALID_GITHUB_TOKEN}" = "${INVALID_GITHUB_TOKEN}" ] && startSkipping

  helper_validResolve "${DEFAULT_SCHEME}" "${VALID_PROTECTED_MODULE}" "${VALID_MODULE_CONTENT}" \
    -H "Authorization: token ${VALID_GITHUB_TOKEN}" \
    -H 'Accept: application/vnd.github.v3.raw'

  [ "${VALID_GITHUB_TOKEN}" = "${INVALID_GITHUB_TOKEN}" ] && endSkipping
}

test_resolve_Fails_resolving_non_existing_available_module() {
  helper_invalidResolve "${DEFAULT_SCHEME}" "${INVALID_MODULE_NAME}"
}

test_canResolve_Returns_true_if_all_required_information_is_present() {
  CurlResolver_canResolve "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME}" # other options
  exit_code=$?
  assertTrue "CurlResolver_canResolve exit code is 0" "[ ${exit_code} -eq 0 ]"
}

test_canResolve_Returns_true_if_module_starts_with_specified_prefix() {
  CurlResolver_canResolve "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME}" --resolve-only="${VALID_MODULE_NAME:0:7}"
  exit_code=$?
  assertTrue "CurlResolver_canResolve exit code is 0" "[ ${exit_code} -eq 0 ]"
}

test_canResolve_Returns_true_if_scheme_matches_provided_scheme() {
  CurlResolver_canResolve "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME}" --match-scheme="${DEFAULT_SCHEME}"
  exit_code=$?
  assertTrue "CurlResolver_canResolve exit code is 0" "[ ${exit_code} -eq 0 ]"
}

test_canResolve_Returns_false_if_scheme_does_not_match_provided_scheme() {
  CurlResolver_canResolve "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME}" --match-scheme="different${DEFAULT_SCHEME}"
  exit_code=$?
  assertTrue "CurlResolver_canResolve exit code greater than 0" "[ ${exit_code} -gt 0 ]"
}

test_canResolve_Returns_false_if_module_does_not_start_with_specified_prefix() {
  CurlResolver_canResolve "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME}" --resolve-only="really_random_module_prefix"
  exit_code=$?
  assertTrue "CurlResolver_canResolve exit code greater than 0" "[ ${exit_code} -gt 0 ]"
}

test_canResolve_Returns_false_if_required_information_is_missing() {
  CurlResolver_canResolve "${DEFAULT_SCHEME}" "" # other options
  exit_code=$?
  assertTrue "CurlResolver_canResolve exit code is greater than 0" "[ ${exit_code} -gt 0 ]"
}

test_onRejected_Remove_created_files() {
  invalid_file="${SHUNIT_TMPDIR}/curl_resolver_${RANDOM}.sh"
  touch "${invalid_file}"
  touch "${invalid_file}.headers"

  assertTrue "Invalid output file exists" "[ -f \"${invalid_file}\" ]"
  assertTrue "Invalid headers file exists" "[ -f \"${invalid_file}.headers\" ]"

  CurlResolver_onRejected "${invalid_file}"
  exit_code=$?

  assertFalse "Invalid output file has been removed" "[ -f \"${invalid_file}\" ]"
  assertFalse "Invalid headers file has been removed" "[ -f \"${invalid_file}.headers\" ]"
}

test_onAccepted_Return_true() {
  CurlResolver_onAccepted "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME}" # resolved path + other options
  exit_code=$?

  assertTrue "CurlResolver_onAccepted exit code is 0" "[ ${exit_code} -eq 0 ]"
}


################################################################################

helper_validResolve() {
  module_scheme="$1"; shift
  module_name="$1"; shift
  expected_content="$1"; shift
  # $@ module args

  output_file="${SHUNIT_TMPDIR}/curl_resolver_${RANDOM}.sh"
  result="$(CurlResolver_resolve "${module_scheme}" "${module_name}" "${output_file}" "$@")"
  exit_code=$?

  assertTrue "CurlResolver_resolve exit code is 0" ${exit_code}
  assertTrue "Output file is not empty" "[ -s \"${output_file}\" ]"
  assertEquals "Output is expected output file" "${expected_content}" "$(cat "${output_file}")"
  assertEquals "Result equals output file" "${output_file}" "${result}"

  [ -f "${output_file}" ] && rm "${output_file}"
}

helper_invalidResolve() {
  module_scheme="$1"; shift
  module_name="$1"; shift
  expected_content=""
  # $@ module args

  output_file="${SHUNIT_TMPDIR}/git_hub_resolver_${RANDOM}.sh"

  result="$(CurlResolver_resolve "${module_scheme}" "${module_name}" "${output_file}" "$@")"
  exit_code=$?

  assertTrue "CurlResolver_resolve exit code greater than 0" "[ ${exit_code} -gt 0 ]"
  assertTrue "Output file does not exist" "[ ! -e \"${output_file}\" ]"
  assertEquals "Result is empty" "${expected_content}" "${result}"

  [ -f "${output_file}" ] && rm "${output_file}"
}

oneTimeSetUp() {
  DEFAULT_SCHEME='noscheme:'
  VALID_MODULE_NAME='https://raw.githubusercontent.com/kward/shunit2/master/source/2.1/bin/which'
  VALID_MODULE_NAME_WITHOUT_SCHEME='raw.githubusercontent.com/kward/shunit2/master/source/2.1/bin/which'

  VALID_PROTECTED_MODULE="api.github.com/repos/kward/shunit2/contents/source/2.1/bin/which?ref=master"

  VALID_MODULE_CONTENT="$(curl -s -L https://raw.githubusercontent.com/kward/shunit2/master/source/2.1/bin/which)"
  INVALID_MODULE_NAME='raw.githubusercontent.com/jtrefke/random/master/something/invalid'
  INVALID_MODULE_NAME=""

  INVALID_GITHUB_TOKEN='TOKEN'
  VALID_GITHUB_TOKEN="${TestRunner_GITHUB_TOKEN:-${INVALID_GITHUB_TOKEN}}"

  # shellcheck disable=SC1090,SC2154
  . "${TestRunner_PROJECT_ROOT}/shell_modules/require_resolvers/curl_resolver.sh"
}

# shellcheck disable=SC1090
. "$(which shunit2)"
