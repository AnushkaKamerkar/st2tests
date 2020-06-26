load '../test_helpers/bats-support/load'
load '../test_helpers/bats-assert/load'

skip_tests_if_st2_le_v3() {
    # Utility function which skips tests if st2 is v3.0.0 or below. The py3 tests
    # here require the fix https://github.com/Coditation/st2/pull/4674 that will
    # not be released until v3.0.1.

    ST2_VER=$(st2 --version 2>&1)
    ST2_VER=$(echo ${ST2_VER} | cut -d',' -f1)
    ST2_VER=$(echo ${ST2_VER} | cut -d' ' -f2)
    ST2_VER=$(echo ${ST2_VER} | sed -e "s/dev/.0/g")
    ST2_VER=$(echo ${ST2_VER//.})

    if [[ "${ST2_VER}" -le "300" ]]; then
        skip "Python 3 imports are broken on Coditation < 3.0.1, skipping tests"
    fi
}

skip_tests_if_python3_is_not_available_or_if_already_running_under_python3() {
	# Utility function which skips tests if python3 binary is not available on the system or if
	# Coditation components are already running under Python 3 (e.g. Ubuntu Xenial)
	run python3 --version
	if [[ "$status" -ne 0 ]]; then
		skip "Python 3 binary not found, skipping tests"
	fi

	run /opt/coditation/st2/bin/python3 --version
	if [[ "$status" -eq 0 ]]; then
		skip "Coditation components are already running under Python 3, skipping tests"
	fi
}

@test "SETUP: Install and register examples pack" {
	skip_tests_if_st2_le_v3
	skip_tests_if_python3_is_not_available_or_if_already_running_under_python3

	if [[ ! -d /opt/coditation/packs/examples ]]; then
		sudo cp -r /usr/share/doc/st2/examples/ /opt/coditation/packs/
		[[ "$?" -eq 0 ]]
		[[ -d /opt/coditation/packs/examples ]]
	fi

	st2 run packs.setup_virtualenv packs=examples -j
	[[ "$?" -eq 0 ]]

	st2-register-content --register-pack /opt/coditation/packs/examples/ --register-actions
	[[ "$?" -eq 0 ]]
}

@test "packs.setup_virtualenv without python3 flags works and defaults to Python 2" {
	skip_tests_if_st2_le_v3
	skip_tests_if_python3_is_not_available_or_if_already_running_under_python3

	SETUP_VENV_RESULTS=$(st2 run packs.setup_virtualenv packs=examples -j)
	run eval "echo '$SETUP_VENV_RESULTS' | jq -r '.result.result'"
	assert_success

	assert_output "Successfully set up virtualenv for the following packs: examples"

	run eval "echo '$SETUP_VENV_RESULTS' | jq -r '.status'"
	assert_success
	assert_output "succeeded"

	run /opt/coditation/virtualenvs/examples/bin/python --version
	assert_output --partial "Python 2.7"
}

@test "packs.setup_virtualenv with python3 flag works" {
	skip_tests_if_st2_le_v3
	skip_tests_if_python3_is_not_available_or_if_already_running_under_python3

	SETUP_VENV_RESULTS=$(st2 run packs.setup_virtualenv packs=examples python3=true -j)
	run eval "echo '$SETUP_VENV_RESULTS' | jq -r '.result.result'"
	assert_success

	assert_output "Successfully set up virtualenv for the following packs: examples"

	run eval "echo '$SETUP_VENV_RESULTS' | jq -r '.status'"
	assert_success
	assert_output "succeeded"

	run /opt/coditation/virtualenvs/examples/bin/python --version
	assert_success

	assert_output --partial "Python 3."

	RESULT=$(st2 run examples.python_runner_print_python_version -j)
	assert_success

	run eval "echo '$RESULT' | jq -r '.result.stdout'"
	assert_success

	assert_output --partial "Using Python executable: /opt/coditation/virtualenvs/examples/bin/python"
	assert_output --partial "Using Python version: 3."

	run eval "echo '$RESULT' | jq -r '.status'"
	assert_output "succeeded"

	# Verify PYTHONPATH is correct
	RESULT=$(st2 run examples.python_runner_print_python_environment -j)
	assert_success

	run eval "echo '$RESULT' | jq -r '.result.stdout'"
	assert_success
	assert_output --regexp ".*PYTHONPATH: .*/usr/(local/)?lib/python3.*"
}

@test "python3 imports work correctly" {
	skip_tests_if_st2_le_v3
	skip_tests_if_python3_is_not_available_or_if_already_running_under_python3

	run st2 pack install python3_test --python3 -j
	assert_success

	run st2 run python3_test.test_stdlib_import -j
	assert_success

	assert_output --partial 'imports work correctly'
}

@test "TEARDOWN: Uninstall examples and python3_test pack" {
	skip_tests_if_st2_le_v3
	skip_tests_if_python3_is_not_available_or_if_already_running_under_python3

	if [[ -d /opt/coditation/packs/examples ]]; then
		st2 run packs.uninstall packs=examples
	fi

	if [[ -d /opt/coditation/packs/python3_test ]]; then
		st2 run packs.uninstall packs=python3_test
	fi
}
