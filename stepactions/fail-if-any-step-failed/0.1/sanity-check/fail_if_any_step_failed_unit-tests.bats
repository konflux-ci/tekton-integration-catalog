#!/usr/bin/env bats

setup() {
  export BATS_TEST_TMPDIR=$(mktemp -d)
  export SCRIPT_FILE="$BATS_TEST_TMPDIR/script.sh"
  
  cat << 'EOF' > "$SCRIPT_FILE"
#!/bin/bash
set -e

# Loop through "exitCode" files containing exit codes of all executed steps within the Task
find -L "/tekton/steps/" -path "*/step-*/exitCode" | while read -r file; do
    exitCode=$(<"$file")

    # If some of the steps exited with non-zero code, exit the script with that code
    if [ "$exitCode" != "0" ]; then
        stepname=${file##*step-}
        stepname=${stepname%%/*}
        echo -e "[ERROR]: Step '$stepname' failed with exit code '$exitCode', which was previously ignored - exiting now"
        exit $exitCode
    fi
done

echo -e "[INFO]: Did not find any failed steps"
EOF
  chmod +x "$SCRIPT_FILE"
  
  # Replace the hardcoded path with our temp directory for testing
  sed -i'' -e "s|/tekton/steps/|$BATS_TEST_TMPDIR/|g" "$SCRIPT_FILE"
}

teardown() {
  rm -rf "$BATS_TEST_TMPDIR"
}

# ── Suite: Happy Path ──

@test "No steps found" {
  run "$SCRIPT_FILE"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "[INFO]: Did not find any failed steps" ]
}

@test "All steps exited with 0" {
  mkdir -p "$BATS_TEST_TMPDIR/step-one"
  echo "0" > "$BATS_TEST_TMPDIR/step-one/exitCode"
  mkdir -p "$BATS_TEST_TMPDIR/step-two"
  echo "0" > "$BATS_TEST_TMPDIR/step-two/exitCode"

  run "$SCRIPT_FILE"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "[INFO]: Did not find any failed steps" ]
}

# ── Suite: Failure Path ──

@test "One step failed with non-zero exit code" {
  mkdir -p "$BATS_TEST_TMPDIR/step-build"
  echo "1" > "$BATS_TEST_TMPDIR/step-build/exitCode"

  run "$SCRIPT_FILE"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "[ERROR]: Step 'build' failed with exit code '1', which was previously ignored - exiting now" ]
}

@test "Multiple steps, one fails" {
  mkdir -p "$BATS_TEST_TMPDIR/step-test"
  echo "0" > "$BATS_TEST_TMPDIR/step-test/exitCode"
  mkdir -p "$BATS_TEST_TMPDIR/step-lint"
  echo "42" > "$BATS_TEST_TMPDIR/step-lint/exitCode"

  run "$SCRIPT_FILE"
  [ "$status" -eq 42 ]
  [[ "$output" == *"[ERROR]: Step 'lint' failed with exit code '42', which was previously ignored - exiting now"* ]]
}

@test "Step name with hyphens" {
  mkdir -p "$BATS_TEST_TMPDIR/step-my-app-build"
  echo "7" > "$BATS_TEST_TMPDIR/step-my-app-build/exitCode"

  run "$SCRIPT_FILE"
  [ "$status" -eq 7 ]
  [ "${lines[0]}" = "[ERROR]: Step 'my-app-build' failed with exit code '7', which was previously ignored - exiting now" ]
}