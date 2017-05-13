#!/usr/bin/env bash

test_require_Returns_false_if_no_module_is_provided() {
  ShellModule_require
  local exit_status=$?

  assertTrue "ShellModule_require exits with exit code greater than 0" "[ ${exit_status} -gt 0 ]"
}

test_require_Returns_false_if_no_module_was_found() {
  ShellModule_require 'my/completely/random/module'
  local exit_status=$?

  assertTrue "ShellModule_require exits with exit code greater than 0" "[ ${exit_status} -gt 0 ]"
}

test_require_Returns_false_if_file_found_is_no_module() {
  assertTrue "Invalid module file exists" "[ -f \"${INVALID_MODULE}\" ]"

  ShellModule_require "${INVALID_MODULE}"
  local exit_status=$?

  assertTrue "ShellModule_require exits with exit code greater than 0" "[ ${exit_status} -gt 0 ]"
}


test_require_Loads_modules_with_absolute_paths_directly_from_file_system() {
  assertTrue "Module file exists" "[ -f \"${VALID_MODULE}\" ]"
  assertTrue "Module starts with absolute path" "[ \"${VALID_MODULE:0:1}\" = \"/\" ]"
  assertTrue "Module ends with .sh" "[ \"${VALID_MODULE: -3}\" = \".sh\" ]"
  assertTrue "Module not loaded" "[ \"x${ValidModule_ONE_IF_LOADED:-notsetx}\" = \"xnotsetx\" ]"

  ShellModule_require "${VALID_MODULE}"
  local exit_status=$?

  assertTrue "ShellModule_require exits with exit code 0" "[ ${exit_status} -eq 0 ]"
  assertTrue "Module variable is present" "[ ${NUM_LOAD_COUNT} -eq 1 ]"
}

test_require_Loads_modules_with_absolute_paths_without_provided_sh_suffix() {
  assertTrue "Module file exists" "[ -f \"${VALID_MODULE}\" ]"
  assertTrue "Module not loaded" "[ \"x${ValidModule_ONE_IF_LOADED:-notsetx}\" = \"xnotsetx\" ]"

  ShellModule_require "${VALID_MODULE%*.sh}"
  local exit_status=$?

  assertTrue "ShellModule_require exits with exit code 0" "[ ${exit_status} -eq 0 ]"
  assertTrue "Module variable is present" "[ ${ValidModule_ONE_IF_LOADED} -eq 1 ]"
}

test_require_Does_not_load_modules_twice_by_default() {
  assertTrue "Module file exists" "[ -f \"${VALID_MODULE}\" ]"
  assertTrue "Module not loaded" "[ \"x${ValidModule_ONE_IF_LOADED:-notsetx}\" = \"xnotsetx\" ]"

  ShellModule_require "${VALID_MODULE}"
  local exit_status=$?
  assertTrue "ShellModule_require exits with exit code 0" "[ ${exit_status} -eq 0 ]"
  assertTrue "Module variable is present" "[ ${ValidModule_ONE_IF_LOADED} -eq 1 ]"
  assertTrue "Load count is 1" "[ ${NUM_LOAD_COUNT} -eq 1 ]"

  ShellModule_require "${VALID_MODULE}"
  local exit_status=$?
  assertTrue "ShellModule_require exits with exit code 0" "[ ${exit_status} -eq 0 ]"
  # TODO: the load count seems to be unreliable!
  assertTrue "Load count is 1" "[ ${NUM_LOAD_COUNT} -eq 1 ]"
}


test_require_Loads_modules_multiple_times_when_argument_reload_provided() {
  startSkipping "Does not increment correctly"

  assertTrue "Module file exists" "[ -f \"${VALID_MODULE}\" ]"
  assertTrue "Module not loaded" "[ \"x${ValidModule_ONE_IF_LOADED:-notsetx}\" = \"xnotsetx\" ]"

  ShellModule_require "${VALID_MODULE}"
  local exit_status=$?

  assertTrue "ShellModule_require exits with exit code 0" "[ ${exit_status} -eq 0 ]"
  assertTrue "Module variable is present" "[ ${ValidModule_ONE_IF_LOADED} -eq 1 ]"
  ShellModule_require "${VALID_MODULE}" "reload"

  local exit_status=$?
  assertTrue "ShellModule_require exits with exit code 0" "[ ${exit_status} -eq 0 ]"
  assertTrue "Module var has been incremented" "[ ${NUM_LOAD_COUNT} -eq 2 ]"

  endSkipping
}

test_require_Loads_modules_in_shell_module_path() {
  assertTrue "Module file exists" "[ -f \"${VALID_MODULE}\" ]"
  assertTrue "Module not loaded" "[ \"x${ValidModule_ONE_IF_LOADED:-notsetx}\" = \"xnotsetx\" ]"

  export ShellModule_PATH="${SHUNIT_TMPDIR}"
  ShellModule_require "${VALID_RELATIVE_MODULE}"
  local exit_status=$?
  assertTrue "ShellModule_require exits with exit code 0" "[ ${exit_status} -eq 0 ]"
  assertTrue "Module variable is present" "[ ${ValidModule_ONE_IF_LOADED} -eq 1 ]"
  assertTrue "Module var has been incremented" "[ ${NUM_LOAD_COUNT} -eq 1 ]"
}

test_require_Does_not_load_modules_not_in_shell_module_path() {
  assertTrue "Module file exists" "[ -f \"${VALID_MODULE}\" ]"
  assertTrue "Module not loaded" "[ \"x${ValidModule_ONE_IF_LOADED:-notsetx}\" = \"xnotsetx\" ]"

  export ShellModule_PATH=""
  ShellModule_require "${VALID_RELATIVE_MODULE}"
  local exit_status=$?

  assertTrue "ShellModule_require exits with exit code greater than 0" "[ ${exit_status} -gt 0 ]"
  assertTrue "Module not loaded" "[ \"x${ValidModule_ONE_IF_LOADED:-notsetx}\" = \"xnotsetx\" ]"
}

test_require_Loads_modules_using_external_resolvers() {
  export ShellModule_RESOLVERS=("require_resolvers/git_hub_resolver --token='${TestRunner_GITHUB_TOKEN}'")
  ShellModule_require "${TestRunner_DATA_VALID_GITHUB_MODULE}"
  local exit_status=$?

  assertTrue "ShellModule_require exits with exit code 0" "[ ${exit_status} -eq 0 ]"
}

test_require_Does_not_load_non_existing_modules_using_external_resolvers() {
  export ShellModule_RESOLVERS=("require_resolvers/git_hub_resolver --token='${TestRunner_GITHUB_TOKEN}'")

  ShellModule_require "${TestRunner_DATA_INVALID_GITHUB_MODULE}"
  local exit_status=$?

  assertTrue "ShellModule_require exits with exit code greater than 0" "[ ${exit_status} -gt 0 ]"
}

# test_require_Uses_default_external_github_resolver() {
#   export ShellModule_RESOLVERS=()
#
#   ShellModule_require "${TestRunner_DATA_VALID_GITHUB_MODULE_WITH_SCHEME}"
#   local exit_status=$?
#
#   assertTrue "ShellModule_require exits with exit code 0" "[ ${exit_status} -eq 0 ]"
# }

# test_require_External_resolvers_only_find_files_with_sh_extension() {
# }


# ShellModule_isFunctionPresent
# ShellModule_isModulePresent

################################################################################

oneTimeSetUp() {
  INVALID_MODULE="${SHUNIT_TMPDIR}/invalid_module.sh"
  touch "${INVALID_MODULE}"

  VALID_MODULE="${SHUNIT_TMPDIR}/valid_module.sh"
  VALID_RELATIVE_MODULE="$(basename "${VALID_MODULE%*.sh}")"
  cat<<END_OF_VALID_MODULE>"${VALID_MODULE}"
#!/usr/bin/env bash

if [ -z "${NUM_LOAD_COUNT:-}" ]; then
  export NUM_LOAD_COUNT=0
fi

function ValidModule_sayHello() {
  echo "hello"
}

ValidModule_ONE_IF_LOADED=1
export NUM_LOAD_COUNT=$(( ${NUM_LOAD_COUNT} + 1 ))

END_OF_VALID_MODULE

  . "${TestRunner_PROJECT_ROOT}/shell_module.sh"
}

setUp() {
  export NUM_LOAD_COUNT=0



}

tearDown() {
  EXTERNAL_MODULE_DIR=${TestRunner_DATA_VALID_GITHUB_MODULE%%/*}
  EXTERNAL_MODULE_DIR=${EXTERNAL_MODULE_DIR:1}
  CREATED_MODULE_DIR="shell_modules/${EXTERNAL_MODULE_DIR}"

  if [ -d "${CREATED_MODULE_DIR}" ]; then
    rm -r "${CREATED_MODULE_DIR}"
  fi

  for fn in $( compgen -A function | grep -E '^(ValidModule)_' ); do unset -f $fn; done
  for var in $( compgen -A variable | grep -E '^(ValidModule)_' ); do unset $var; done

}

. "$(which shunit2)"
