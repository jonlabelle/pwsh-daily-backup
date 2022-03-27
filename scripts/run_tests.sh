#!/usr/bin/env bash

set -e
set -o pipefail

# shellcheck disable=SC2005
SCRIPTSDIR="$(cd "$(dirname "${0}")" || exit; echo "$(pwd)")"
cd "${SCRIPTSDIR}/.." || exit 1

/usr/local/bin/pwsh -NonInteractive -NoProfile -NoLogo -ExecutionPolicy ByPass -File test/Test.ps1
