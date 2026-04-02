#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_SPEC="$ROOT_DIR/project.yml"
TEAM_ID="${1:-}"

if [[ -z "$TEAM_ID" ]]; then
  echo "Usage: ./scripts/set_team.sh TEAM_ID" >&2
  exit 1
fi

if [[ ! "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "TEAM_ID should usually be a 10-character Apple team identifier." >&2
  exit 1
fi

perl -0pi -e 's/DEVELOPMENT_TEAM: [A-Z0-9]{10}/DEVELOPMENT_TEAM: '"$TEAM_ID"'/g' "$PROJECT_SPEC"

echo "Updated DEVELOPMENT_TEAM in project.yml to $TEAM_ID"
