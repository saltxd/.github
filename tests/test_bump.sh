#!/usr/bin/env bash
# Fixture tests for scripts/bump-image.sh (run: bash tests/test_bump.sh)
set -euo pipefail; d=$(mktemp -d); trap 'rm -rf "$d"' EXIT; B="$(dirname "$0")/../scripts/bump-image.sh"
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
echo "bump-image.sh: 4/4 fixture checks pass"
