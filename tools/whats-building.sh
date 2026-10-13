#!/usr/bin/env bash
# Shows what a rebuild would really COMPILE, hiding plain source downloads
# (crates, npm packages, tarballs), which are cheap but make the count huge.
#
#   bash tools/whats-building.sh [host]      # default host: thinkpad
host="${1:-thinkpad}"

out=$(nixos-rebuild dry-build --flake ".#$host" 2>&1)
echo "$out" | grep -E 'will be (built|fetched)'

pending=$(echo "$out" | sed -n '/will be built/,/will be fetched/p' \
  | grep -E '^ */nix/store/.*\.drv$' | tr -d ' ')

# Fixed-output derivations (downloads) have an outputHash; real builds do not.
builds=$(echo "$pending" | while read -r d; do
  nix-store -q --binding outputHash "$d" >/dev/null 2>&1 || echo "${d#/nix/store/*-}"
done | sed 's/\.drv$//' | sort)

echo
echo "Real builds (not downloads): $(echo "$builds" | grep -c .)"
echo "$builds" | grep -vE '^(unpack|download)-' | head -45
echo
echo "Crate unpack/download steps: $(echo "$builds" | grep -cE '^(unpack|download)-')"
