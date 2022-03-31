#!/usr/bin/env bash

set -e
set -o pipefail

# shellcheck disable=SC2005
SCRIPTSDIR="$(cd "$(dirname "${0}")" || exit; echo "$(pwd)")"
cd "${SCRIPTSDIR}/.." || exit 1

run_test_script() {
    echo "----------------------------"
    echo " Running test script"
    echo "----------------------------"
    echo ""
    /usr/local/bin/pwsh -NonInteractive -NoProfile -NoLogo -ExecutionPolicy ByPass -File test/Tests.ps1
    echo ""
    echo "Finished running test script."
    echo ""
}

run_test_command() {
    echo "----------------------------"
    echo " Running test command"
    echo "----------------------------"
    echo ""
    /usr/local/bin/pwsh -NonInteractive -NoProfile -NoLogo -ExecutionPolicy ByPass -Command '. ./Backup-File.ps1; Backup-File -Path ".github" -Destination "tmp2/test" -DailyBackupsToKeep 2 -WhatIf -Verbose'
    echo ""
    echo "Finished running test command."
    echo ""
}

run_test_script
run_test_command
