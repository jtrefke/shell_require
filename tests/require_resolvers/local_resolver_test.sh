#!/usr/bin/env bash

test_resolve_Resolves_existing_module_with_suffix() {
  helper_validResolve "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME}" "${VALID_MODULE_FILE}" ".sh"
  helper_validResolve "${DEFAULT_SCHEME}" "${NESTED_VALID_MODULE_NAME}" "${NESTED_VALID_MODULE_FILE}" ".sh"
}

test_resolve_Resolves_existing_module_without_suffix() {
  helper_validResolve "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME}" "${VALID_MODULE_FILE}"
  helper_validResolve "${DEFAULT_SCHEME}" "${NESTED_VALID_MODULE_NAME}" "${NESTED_VALID_MODULE_FILE}"
}

test_resolve_Resolves_files_in_the_search_path_that_are_not_modules() {
  helper_validResolve "${DEFAULT_SCHEME}" "${INVALID_MODULE_NAME}" "${INVALID_MODULE_FILE}"
}

test_resolve_Uses_normalized_names_alternatively() {
  helper_validResolve "${DEFAULT_SCHEME}" "${DEVIATING_NESTED_VALID_MODULE_NAME}" "${NESTED_VALID_MODULE_FILE}"
  helper_validResolve "${DEFAULT_SCHEME}" "${DEVIATING_NESTED_VALID_MODULE_NAME}" "${NESTED_VALID_MODULE_FILE}" ".sh"
}

test_resolve_Does_not_resolve_files_not_in_search_path() {
  result="$(LocalResolver_resolve "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME}" --search-path="${PWD}")"
  exit_code=$?

  assertTrue "LocalResolver_resolve exit code greater than 0" "[ ${exit_code} -gt 0 ]"
  assertEquals "Output resolves to path" "" "${result}"
}

test_resolve_Uses_current_working_dir_if_no_search_path_given() {
  result="$(LocalResolver_resolve "${DEFAULT_SCHEME}" "${MODULE_NAME_IN_CWD}")"
  exit_code=$?

  assertTrue "LocalResolver_resolve exit code is 0" "[ ${exit_code} -eq 0 ]"
  assertEquals "Output resolves to path" "${MODULE_FILE_IN_CWD}" "${result}"
}

test_canResolve_Returns_true() {
  LocalResolver_canResolve "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME}" # other options
  exit_code=$?
  assertTrue "LocalResolver_canResolve exit code is 0" "[ ${exit_code} -eq 0 ]"
}

test_canResolve_Returns_true_if_scheme_does_match_module() {
  LocalResolver_canResolve "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME}" --match-scheme="${DEFAULT_SCHEME}"
  exit_code=$?
  assertTrue "LocalResolver_canResolve exit code is 0" "[ ${exit_code} -eq 0 ]"
}

test_canResolve_Returns_false_if_scheme_does_not_match_module() {
  LocalResolver_canResolve "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME}" --match-scheme="different${DEFAULT_SCHEME}"
  exit_code=$?
  assertTrue "LocalResolver_canResolve exit code is greater than 0" "[ ${exit_code} -gt 0 ]"
}

test_onRejected_Returns_true() {
  assertTrue "Invalid module file exists initially" "[ -f \"${INVALID_MODULE_FILE}\" ]"

  LocalResolver_onRejected "${INVALID_MODULE_FILE}"
  exit_code=$?

  assertTrue "LocalResolver_onRejected exit code is 0" "[ ${exit_code} -eq 0 ]"
  assertTrue "Invalid module file still exists" "[ -f \"${INVALID_MODULE_FILE}\" ]"
}

test_onAccepted_Returns_true() {
  LocalResolver_onAccepted "${DEFAULT_SCHEME}" "${VALID_MODULE_NAME}" # resolved path + other options
  exit_code=$?

  assertTrue "LocalResolver_onAccepted exit code is 0" "[ ${exit_code} -eq 0 ]"
}


################################################################################

helper_validResolve() {
  module_scheme="$1"
  module_name="$2"
  module_file="$3"
  module_suffix="${4:-}"

  result="$(LocalResolver_resolve "${module_scheme}" "${module_name}${module_suffix}" --search-path="${PWD}:${SHUNIT_TMPDIR}")"
  exit_code=$?

  assertTrue "LocalResolver_resolve exit code is 0" ${exit_code}
  assertEquals "Output resolves to path" "${module_file}" "${result}"
}

oneTimeSetUp() {
  DEFAULT_SCHEME='noscheme:'
  VALID_MODULE_NAME='valid_module'
  VALID_MODULE_FILE="${SHUNIT_TMPDIR}/${VALID_MODULE_NAME}.sh"
  INVALID_MODULE_NAME='invalid_module'
  INVALID_MODULE_FILE="${SHUNIT_TMPDIR}/${INVALID_MODULE_NAME}.sh"
  NESTED_VALID_MODULE_NAME="some_dir/${VALID_MODULE_NAME}"
  NESTED_VALID_MODULE_FILE="${SHUNIT_TMPDIR}/${NESTED_VALID_MODULE_NAME}.sh"
  DEVIATING_NESTED_VALID_MODULE_NAME="some-dir/${VALID_MODULE_NAME}"

  cat<<INVALID_MODULE_CONTENT>"${INVALID_MODULE_FILE}"
hello world!
INVALID_MODULE_CONTENT

  cat<<VALID_MODULE_CONTENT>"${VALID_MODULE_FILE}"
# !/usr/bin/env bash

ValidModule_hello() {
  echo "hello world!"
}
VALID_MODULE_CONTENT
  mkdir -p "$(dirname -- "${NESTED_VALID_MODULE_FILE}")"
  cp "${VALID_MODULE_FILE}" "${NESTED_VALID_MODULE_FILE}"

  MODULE_NAME_IN_CWD="random_module_${RANDOM}"
  MODULE_FILE_IN_CWD="${PWD}/${MODULE_NAME_IN_CWD}.sh"
  cat<<MODULE_CONTENT_IN_CWD>"${MODULE_FILE_IN_CWD}"
  # Module in "${PWD}"
MODULE_CONTENT_IN_CWD

  # shellcheck disable=SC1090,SC2154
  . "${TestRunner_PROJECT_ROOT}/shell_modules/require_resolvers/local_resolver.sh"
}

oneTimeTearDown() {
  [ -f "${INVALID_MODULE}" ] && rm "${INVALID_MODULE}"
  [ -f "${VALID_MODULE}" ] && rm "${VALID_MODULE}"
  [ -f "${MODULE_FILE_IN_CWD}" ] && rm "${MODULE_FILE_IN_CWD}"
}

# shellcheck disable=SC1090
. "$(which shunit2)"
