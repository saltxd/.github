#!/usr/bin/env bash
# Fixture tests for .github/actions/bump-image/bump-image.sh (run: bash tests/test_bump.sh)
set -euo pipefail; d=$(mktemp -d); trap 'rm -rf "$d"' EXIT; B="$(dirname "$0")/../.github/actions/bump-image/bump-image.sh"
cat > "$d/cronjob.yaml" <<'Y'
spec:
  jobTemplate:
    spec:
      template:
        spec:
          initContainers:
            - name: wait-for-deps
              image: busybox:1.36
          containers:
            - name: sentry
              image: ghcr.io/saltxd/alert-closer:9f42a64527c3fa9c37095404ee1d3979ebdc94dd
              env:
                - name: IMAGE
                  value: ghcr.io/saltxd/alert-closer:9f42a64527c3fa9c37095404ee1d3979ebdc94dd
Y
bash "$B" "$d/cronjob.yaml" ghcr.io/saltxd/alert-closer sha-abc1234 >/dev/null
grep -q 'image: busybox:1.36' "$d/cronjob.yaml" || { echo "FAIL: busybox touched"; exit 1; }
[ "$(grep -c 'ghcr.io/saltxd/alert-closer:sha-abc1234' "$d/cronjob.yaml")" = 2 ] || { echo "FAIL: expected 2 rewrites"; exit 1; }
cat > "$d/hr.yaml" <<'Y'
spec:
  values:
    image:
      repository: ghcr.io/saltxd/jobhunt-web
      tag: e2af6bc
Y
bash "$B" "$d/hr.yaml" ghcr.io/saltxd/jobhunt-web sha-abc1234 --helm-values >/dev/null
[ "$(yq -r .spec.values.image.tag "$d/hr.yaml")" = sha-abc1234 ] || { echo "FAIL: helm tag"; exit 1; }
if bash "$B" "$d/hr.yaml" ghcr.io/saltxd/other sha-x --helm-values 2>/dev/null; then echo "FAIL: wrong repo accepted"; exit 1; fi
if bash "$B" "$d/cronjob.yaml" ghcr.io/saltxd/nothing sha-x 2>/dev/null; then echo "FAIL: zero-line change accepted"; exit 1; fi
# 5: HelmRelease with full image strings (chart shape 2): only the matching repo changes, a prefix-sharing repo does not
cat > "$d/hr2.yaml" <<'Y'
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
spec:
  values:
    images:
      api: ghcr.io/saltxd/chainward-api:7d6fc14
      api2: ghcr.io/saltxd/chainward-api-extra:7d6fc14
      web: ghcr.io/saltxd/chainward-web:7d6fc14
    other: { note: "ghcr.io/saltxd/chainward-api is mentioned in prose" }
Y
bash "$B" "$d/hr2.yaml" ghcr.io/saltxd/chainward-api abc1234 --helm-values >/dev/null
[ "$(yq -r '.spec.values.images.api' "$d/hr2.yaml")" = "ghcr.io/saltxd/chainward-api:abc1234" ] || { echo "FAIL 5a: api not bumped"; exit 1; }
[ "$(yq -r '.spec.values.images.api2' "$d/hr2.yaml")" = "ghcr.io/saltxd/chainward-api-extra:7d6fc14" ] || { echo "FAIL 5b: prefix-sharing repo bumped"; exit 1; }
[ "$(yq -r '.spec.values.images.web' "$d/hr2.yaml")" = "ghcr.io/saltxd/chainward-web:7d6fc14" ] || { echo "FAIL 5c: web bumped"; exit 1; }
[ "$(yq -r '.spec.values.other.note' "$d/hr2.yaml")" = "ghcr.io/saltxd/chainward-api is mentioned in prose" ] || { echo "FAIL 5d: prose rewritten"; exit 1; }
# 6: shape 2 with no matching string fails loudly
if bash "$B" "$d/hr2.yaml" ghcr.io/saltxd/nope abc1234 --helm-values 2>/dev/null; then echo "FAIL 6: missing repo did not fail"; exit 1; fi
# 7: HelmRelease with image.tag only (repository from the chart default) stays shape 1
cat > "$d/hr3.yaml" <<'Y'
spec:
  values:
    image:
      tag: sha-0105065
    scraperUrl: http://example:8001
Y
bash "$B" "$d/hr3.yaml" ghcr.io/saltxd/jobhunt-web sha-f70a771 --helm-values >/dev/null
[ "$(yq -r '.spec.values.image.tag' "$d/hr3.yaml")" = "sha-f70a771" ] || { echo "FAIL 7: tag-only HelmRelease not bumped"; exit 1; }
echo "bump-image.sh: 7/7 fixture checks pass"
