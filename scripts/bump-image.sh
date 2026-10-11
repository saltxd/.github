#!/usr/bin/env bash
# Rewrite an image tag in a homelab-k3s file. Exits 1 if nothing changed.
#   bump-image.sh <file> <image-repo> <new-tag>                raw manifest: every "image: <repo>:<x>" and "value: <repo>:<x>" line
#   bump-image.sh <file> <image-repo> <new-tag> --helm-values  HelmRelease: .spec.values.image.tag (repository must match <image-repo>)
set -euo pipefail
file=$1; repo=$2; tag=$3; mode=${4:-manifest}
[ -f "$file" ] || { echo "bump-image: no such file $file" >&2; exit 1; }
esc=$(printf '%s' "$repo" | sed 's/[.[\*^$/]/\\&/g')
if [ "$mode" = "--helm-values" ]; then
  cur=$(yq -r '.spec.values.image.tag // ""' "$file"); rep=$(yq -r '.spec.values.image.repository // ""' "$file")
  [ -n "$rep" ] && [ "$rep" != "$repo" ] && { echo "bump-image: $file repository is $rep, not $repo" >&2; exit 1; }
  [ "$cur" = "$tag" ] && { echo "bump-image: $file already at $tag"; exit 0; }
  yq -i ".spec.values.image.tag = \"$tag\"" "$file"
  echo "bump-image: $file image.tag $cur -> $tag"
else
  before=$(grep -cE "^[[:space:]]*(- )?(image|value): ${esc}[:@]" "$file" || true)
  [ "$before" -gt 0 ] || { echo "bump-image: no ${repo}: lines in $file" >&2; exit 1; }
  sed -i.bak -E "s#^([[:space:]]*(- )?(image|value): )${esc}[:@][^ ]*#\1${repo}:${tag}#" "$file" && rm -f "$file.bak"
  after=$(grep -cE "^[[:space:]]*(- )?(image|value): ${esc}:${tag}( |\$)" "$file" || true)
  [ "$after" -eq "$before" ] || { echo "bump-image: expected $before lines, rewrote $after" >&2; exit 1; }
  echo "bump-image: $file $before line(s) -> ${repo}:${tag}"
fi
