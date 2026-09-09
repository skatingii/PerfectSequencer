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

# Every dependency is copied into _Index and given a link file beside the
# package that requires it, which is how wally makes deps resolve as siblings.
for LINK in Packages/*.lua Packages/*.luau; do
	[ -f "$LINK" ] || continue

	ALIAS_NAME="$(basename "${LINK%.*}")"
	DEP="$(sed -n 's/.*_Index\["\([^"]*\)"\].*/\1/p' "$LINK" | head -1)"
	INNER="$(sed -n 's/.*_Index\[[^]]*\]\[\{0,1\}\.\{0,1\}"\{0,1\}\([A-Za-z0-9_-]*\)"\{0,1\}\]\{0,1\}).*/\1/p' "$LINK" | head -1)"

	if [ -z "$DEP" ] || [ ! -d "Packages/_Index/${DEP}" ]; then
		echo "error: could not resolve dependency from ${LINK}" >&2
		exit 1
	fi

	cp -r "Packages/_Index/${DEP}" "${OUT}/_Index/${DEP}"

	printf '\n\nreturn (require(script.Parent.Parent["%s"].%s))\n' "$DEP" "$INNER" \
		> "${OUT}/_Index/${PKG}/${ALIAS_NAME}.luau"
done

cat > "${OUT}/${ALIAS}.luau" <<EOF
local REQUIRED_MODULE = require(script.Parent._Index["${PKG}"]["${NAME}"])
export type SequencerEvent = REQUIRED_MODULE.SequencerEvent
export type TrackSequencer = REQUIRED_MODULE.TrackSequencer
return REQUIRED_MODULE
EOF

echo "built ${OUT}"
