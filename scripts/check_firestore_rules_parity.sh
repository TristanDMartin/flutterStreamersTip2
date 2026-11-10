#!/bin/sh
# Fail when this repo's firestore.rules differs from the website copy.
# The website checkout must be homepage-merge-staging before anyone copies
# rules across. This script never writes either file and never deploys.
set -eu

flutter_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
flutter_rules="$flutter_root/firestore.rules"
website_root="${STREAMERSTIP_WEB_ROOT:-$flutter_root/../streamerstipReact}"
website_rules="$website_root/firestore.rules"

if [ ! -f "$website_rules" ]; then
  echo "Firestore rules parity: sibling checkout not present, not checked."
  echo "Expected: $website_rules"
  exit 0
fi

branch=$(git -C "$website_root" branch --show-current)
if [ "$branch" != "homepage-merge-staging" ]; then
  echo "Firestore rules parity: website checkout is '$branch'."
  echo "Required branch before copying rules: homepage-merge-staging."
fi

if cmp -s "$flutter_rules" "$website_rules"; then
  echo "Firestore rules parity: byte-identical."
  exit 0
fi

echo "Firestore rules parity: files differ."
echo "Flutter: $flutter_rules"
echo "Website: $website_rules"
diff -u "$website_rules" "$flutter_rules" | head -n 80 || true
exit 1
