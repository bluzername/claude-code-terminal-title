#!/bin/bash
# Rebuild terminal-title.skill (a zip) from the skill/ source directory.
#
# Usage: scripts/build-skill.sh [output-path]
# Default output: <repo>/terminal-title.skill

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${REPO_DIR}/skill"
OUTPUT="${1:-${REPO_DIR}/terminal-title.skill}"

if [ ! -f "${SOURCE_DIR}/terminal-title/SKILL.md" ]; then
    echo "error: ${SOURCE_DIR}/terminal-title/SKILL.md not found" >&2
    exit 1
fi

rm -f "$OUTPUT"
(cd "$SOURCE_DIR" && zip -q -r -X "$OUTPUT" terminal-title)
echo "built $OUTPUT ($(cat "${SOURCE_DIR}/terminal-title/VERSION"))"
