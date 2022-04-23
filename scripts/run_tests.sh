#!/usr/bin/env bash

set -e
set -o pipefail

# shellcheck disable=SC2005
SCRIPTSDIR="$(cd "$(dirname "${0}")" || exit; echo "$(pwd)")"
cd "${SCRIPTSDIR}/.." || exit 1

run_ps_script_analyzer() {
    echo "----------------------------------"
    echo " Running PSScriptAnalyzer "
    echo "----------------------------------"
    echo ""
    pwsh -NonInteractive -NoProfile -NoLogo -ExecutionPolicy ByPass -Command 'Invoke-ScriptAnalyzer -Settings PSScriptAnalyzerSettings.psd1 -Path . -Recurse'
    echo ""
    echo "Finished running PSScriptAnalyzer."
    echo ""
}

run_test_script() {
    echo "----------------------------------"
    echo " Running integration test script"
    echo "----------------------------------"
    echo ""
    pwsh -NonInteractive -NoProfile -NoLogo -ExecutionPolicy ByPass -File test/Tests.ps1
    echo ""
    echo "Finished running test script."
    echo ""
}

run_test_command() {
    echo "----------------------------------"
    echo " Running integration test command"
    echo "----------------------------------"
    echo ""
    pwsh -NonInteractive -NoProfile -NoLogo -ExecutionPolicy ByPass -Command 'Import-Module ./DailyBackup; New-DailyBackup -Path ".github" -Destination "tmp2/test" -DailyBackupsToKeep 2 -WhatIf -Verbose'
    echo ""
    echo "Finished running test command."
    echo ""
}

run_ps_script_analyzer
run_test_script
run_test_command
