#!/usr/bin/env bash
# Builds the Packages tree that `wally install` would produce, so PerfectSequencer
# can be dropped into a synced project before it is published to the registry.
set -euo pipefail

cd "$(dirname "$0")/.."

SCOPE="skatingii"
NAME="perfect-sequencer"
VERSION="0.1.0"
ALIAS="PerfectSequencer"

OUT="dist/Packages"
PKG="${SCOPE}_${NAME}@${VERSION}"

rm -rf dist
mkdir -p "${OUT}/_Index/${PKG}"

cp -r src "${OUT}/_Index/${PKG}/${NAME}"

# PerfectSequencer has no dependencies, so _Index holds only the package
# itself and no link files are generated beside it.

cat > "${OUT}/${ALIAS}.luau" <<EOF
local REQUIRED_MODULE = require(script.Parent._Index["${PKG}"]["${NAME}"])
export type SequencerEvent = REQUIRED_MODULE.SequencerEvent
export type TrackSequencer = REQUIRED_MODULE.TrackSequencer
return REQUIRED_MODULE
EOF

echo "built ${OUT}"
