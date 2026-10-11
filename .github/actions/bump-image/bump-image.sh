#!/usr/bin/env bash
# Rewrite an image tag in a homelab-k3s file. Exits 1 if nothing changed.
#   bump-image.sh <file> <image-repo> <new-tag>                raw manifest: every "image: <repo>:<x>" and "value: <repo>:<x>" line
#   bump-image.sh <file> <image-repo> <new-tag> --helm-values  HelmRelease: .spec.values.image.tag (repository must match <image-repo>)
set -euo pipefail
file=$1; repo=$2; tag=$3; mode=${4:-manifest}
[ -f "$file" ] || { echo "bump-image: no such file $file" >&2; exit 1; }
esc=$(printf '%s' "$repo" | sed 's/[.[\*^$/]/\\&/g')
if [ "$mode" = "--helm-values" ]; then
  rep=$(yq -r '.spec.values.image.repository // ""' "$file")
  if [ -n "$rep" ]; then
    # chart shape 1: image: { repository, tag }
    [ "$rep" != "$repo" ] && { echo "bump-image: $file repository is $rep, not $repo" >&2; exit 1; }
    cur=$(yq -r '.spec.values.image.tag // ""' "$file")
    [ "$cur" = "$tag" ] && { echo "bump-image: $file already at $tag"; exit 0; }
    yq -i ".spec.values.image.tag = \"$tag\"" "$file"
    echo "bump-image: $file image.tag $cur -> $tag"
  else
    # chart shape 2: full image strings anywhere under .spec.values (e.g. images: { api: ghcr.io/x/api:abc })
    rx=$(printf '%s' "$repo" | sed 's/[.]/\\\\./g')
    sel=".spec.values | .. | select(tag == \"!!str\" and test(\"^${rx}[:@]\"))"
    n=$(yq "[${sel}] | length" "$file")
    [ "$n" -gt 0 ] || { echo "bump-image: no ${repo} image string under .spec.values in $file" >&2; exit 1; }
    yq -i "(${sel}) = \"${repo}:${tag}\"" "$file"
    echo "bump-image: $file $n value(s) -> ${repo}:${tag}"
  fi
else
  before=$(grep -cE "^[[:space:]]*(- )?(image|value): ${esc}[:@]" "$file" || true)
  [ "$before" -gt 0 ] || { echo "bump-image: no ${repo}: lines in $file" >&2; exit 1; }
  sed -i.bak -E "s#^([[:space:]]*(- )?(image|value): )${esc}[:@][^ ]*#\1${repo}:${tag}#" "$file" && rm -f "$file.bak"
  after=$(grep -cE "^[[:space:]]*(- )?(image|value): ${esc}:${tag}( |\$)" "$file" || true)
  [ "$after" -eq "$before" ] || { echo "bump-image: expected $before lines, rewrote $after" >&2; exit 1; }
  echo "bump-image: $file $before line(s) -> ${repo}:${tag}"
fi
