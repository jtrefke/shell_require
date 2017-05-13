#!/usr/bin/env bash

set -e
set -u
shopt -s globstar

TestRunner_SCRIPT_NAME="$(readlink -e "${BASH_SOURCE[0]}")"
TestRunner_SCRIPT_DIR="$(dirname "${TestRunner_SCRIPT_NAME}")"
TestRunner_PROJECT_ROOT="$(cd "${TestRunner_SCRIPT_DIR}/.."; pwd)"
TestRunner_CONFIG_FILE="${TestRunner_SCRIPT_NAME%*.sh}rc"

export TestRunner_SCRIPT_NAME
export TestRunner_SCRIPT_DIR
export TestRunner_PROJECT_ROOT
export TestRunner_CONFIG_FILE

TestRunner__ensureConfigured() {
  if [ ! -s "${TestRunner_CONFIG_FILE}" ]; then
cat<<TEST_RUNNER_CONFIG>"${TestRunner_CONFIG_FILE}"
#!/usr/bin/env sh

#
# replace this with valid data
#
readonly TestRunner_GITHUB_TOKEN=4a68631afb82ba1a9f9c49892e0e3c82eaa7ef66
readonly TestRunner_DATA_VALID_GITHUB_MODULE="@valid-gh-owner/valid-repo/master/misc/lib/url.lib.sh"
readonly TestRunner_DATA_VALID_GITHUB_MODULE_WITH_SCHEME="@gh:valid-gh-owner/valid-repo/master/misc/lib/url.lib.sh"

# no changes required
readonly TestRunner_DATA_INVALID_GITHUB_MODULE="@gh-owner/random/master/misc/sth.sh"
readonly TestRunner_DATA_INVALID_GITHUB_MODULE_WITH_SCHEME="@gh:gh-owner/random/master/misc/sth.sh"

export TestRunner_GITHUB_TOKEN
export TestRunner_DATA_VALID_GITHUB_MODULE
export TestRunner_DATA_INVALID_GITHUB_MODULE
export TestRunner_DATA_VALID_GITHUB_MODULE_WITH_SCHEME
export TestRunner_DATA_INVALID_GITHUB_MODULE_WITH_SCHEME

TEST_RUNNER_CONFIG
    echo
    echo "Please update the test data in ${TestRunner_CONFIG_FILE} before executing the tests"
    echo
    return 1
  fi
}

TestRunner__ensureShUnitInstalled() {
  if ! which shunit2 >/dev/null 2>&1 ; then
    echo
    echo "Please ensure, that the xUnit test framework 'shUnit2' is installed and in your PATH."
    echo
    echo "You can find it in many operating systems' package managers or online,"
    echo "see: https://github.com/kward/shunit2"
    echo
    return 1
  fi
}

TestRunner__runTest() {
  local test_suite_file="$1"
  local current_test_suite_count="${2}"
  local total_test_suites="${3}"

  local current_count="" && \
   [ -n "${total_test_suites}" ] &&  \
   current_count=" (${current_test_suite_count}/${total_test_suites})"

  echo "--------------------------------------------------------------------------------"
  echo
  echo "  TEST SUITE${current_count}: ${test_suite_file}"
  echo
  echo "--------------------------------------------------------------------------------"

  TIMEFORMAT=%R
  time /bin/bash "${test_suite_file}"

  echo -e "\n"
}

TestRunner__runTests() {
  local total_test_suites=0
  for test_suite in **/*_test.sh; do
    total_test_suites=$((${total_test_suites}+1))
  done

  local current_test_suite_count=1
  for test_suite in **/*_test.sh; do
    TestRunner__runTest "${test_suite}" ${current_test_suite_count} ${total_test_suites}
    current_test_suite_count=$((${current_test_suite_count}+1))
  done
}

TestRunner_main() {

  TestRunner__ensureConfigured || exit 1
  TestRunner__ensureShUnitInstalled || exit 1

  TIMEFORMAT=%R
  if [ -f "${1:-}" ]; then
    TestRunner__runTest "$1" 1 1
  else
    time TestRunner__runTests
  fi
}
# shellcheck disable=SC1090
[ -f "${TestRunner_CONFIG_FILE}" ] && source "${TestRunner_CONFIG_FILE}"
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  TestRunner_main "$@"
fi
