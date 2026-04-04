# Helm Core — User Guide

A Helm library chart providing shared template helpers for rendering Kubernetes workloads. Not deployed directly — consumed as a dependency by charts that need deployments, services, configmaps, probes, volumes, and region-aware config merging.

`helm-templates` is the reference consumer, but any chart can depend on `helm-core` and call its helpers directly.

---

## Adding as a dependency

```yaml
# Chart.yaml
dependencies:
  - name: core
    version: 0.3.0
    repository: "oci://ghcr.io/yagelhayun/helm-charts"
```

Then run `helm dependency update`.

---

## Context pattern

Every helper accepts a single `$context` dict. Build it once at the top of each template file:

```yaml
{{- $config := include "core.general.config" . | fromYaml }}
{{- $context := merge (dict "$" $) $config }}
```

- `$config` — merged, region-resolved values (flat; `global` and `regions` stripped)
- `$context` — adds the live Helm root as `$` for `$.Chart`, `$.Release`, and cluster lookups

---

## Configuration system

### `core.general.config`

Merges values from four sources in priority order (highest wins):

1. Region-specific root values (`regions.<region>.*`)
2. Root chart values (`.Values.*`)
3. Region-specific global values (`global.regions.<region>.*`)
4. Global values (`.Values.global.*`)

`global` and `regions` are stripped from the result. Requires `global.region` to be set.

```yaml
global:
  region: us-east-1
  port: 8080

port: 5000          # overrides global.port → result has port: 5000

regions:
  us-east-1:
    configMap:
      data:
        ENDPOINT: "api.us-east-1.example.com"
```

Values may contain Go template expressions (resolved via `tpl`):

```yaml
configMap:
  data:
    PORT: "{{ .Values.port }}"
    MOUNT: '{{ index .Values.global.volumes.secrets "my-secret" "mountPath" }}'
```

---

## General helpers

**`core.general.name`** — returns `$.Chart.Name`. Default name for all resources and the main container.

**`core.general.labels`** — standard label set: `app.kubernetes.io/name`, `helm.sh/chart`, `app.kubernetes.io/managed-by`.

**`core.general.selectorLabels`** — immutable selector labels (`app.kubernetes.io/name` only). Use in `spec.selector.matchLabels` and pod template labels.

---

## Workload helpers

**`core.workload.labels`** — extends `core.general.labels` with an optional `commit` label from `global.commit`.

**`core.workload.replicas`** — returns configured replicas, or `0` if `activeRegion` is set and does not match `global.region`. Keeps the workload resource alive in standby regions for rollback history.

**`core.workload.strategy`** — renders the `strategy` / `updateStrategy` block. Defaults to `RollingUpdate` with `maxUnavailable: 25%` and `maxSurge: 25%`. Presence of `strategy.partition` switches to StatefulSet canary mode.

> The caller is responsible for using `strategy:` vs `updateStrategy:` depending on workload kind.

---

## Pod helpers

### `core.pod.volumes`

Renders the `volumes:` list. Supports four types; validates secrets and configmaps exist in the cluster during real deployments.

```yaml
volumes:
  secrets:
    my-secret:
      mountPath: /run/secrets
      defaultMode: 420        # optional, default 420 (0644)
      files:                  # optional: mount individual keys as files
        - tls.crt
  configMaps:
    my-config:
      mountPath: /etc/config
  empty:
    scratch:
      mountPath: /tmp/scratch
  persistentVolumeClaims:
    my-pvc:
      mountPath: /data
      readOnly: false
```

**`core.pod.imagePullSecrets`** — renders `imagePullSecrets`; falls back to `global.image.pullSecrets`.

**`core.pod.initContainers`** — delegates each entry to `core.container.render`. Init containers share pod volumes.

**`core.pod.topologySpreadConstraints`** — auto-injects `labelSelector`. When absent from values, defaults to hostname + zone spreading with `ScheduleAnyway`. Set to `[]` to disable.

**`core.pod.annotations`** — emits `checksum/config` from ConfigMap data, triggering rolling restarts on config changes.

**`core.pod.serviceaccount`** — returns service account name; resolves `serviceAccount.create` → `core.serviceaccount.name`, else `serviceAccount.name` or `"default"`.

**`core.pod.volumeClaimTemplates`** — renders `volumeClaimTemplates` for StatefulSets (one PVC per pod replica).

---

## Container helpers

### `core.container.render`

The central renderer. Produces a single `- name: ...` container entry. Used for main containers, init containers, and sidecars.

```yaml
containers:
  {{- include "core.container.render" $context | nindent 6 }}
```

Defaults the container name to the chart name when `.name` is not set.

**`core.container.sidecars`** — iterates `sidecars` and calls `core.container.render` for each.

**`core.container.resources`** — CPU limit = `request × limitMultiplier` (default `4`). Memory limit = memory request.

**`core.container.envFrom`** — renders `envFrom` entries plus the chart's own ConfigMap when `configMap.data` is set.

**`core.container.env`** — renders individual env vars from named keys; validates key existence in the cluster during real deployments.

### Probe helpers

`core.container.readinessProbe`, `core.container.livenessProbe`, `core.container.startupProbe` — each probe must use exactly one of `httpGet` or `exec`:

```yaml
probes:
  readiness:
    httpGet:
      path: /health/ready
  liveness:
    httpGet:
      path: /health/live
  startup:
    exec:
      command: ["sh", "-c", "test -f /tmp/ready"]
    failureThreshold: 30
    periodSeconds: 10
```

---

## Resource name helpers

All delegate to `core.general.name` and exist as override extension points:

```
core.configmap.name    core.cronjob.name     core.daemonset.name
core.deployment.name   core.hpa.name         core.pdb.name
core.service.name      core.serviceaccount.name   core.statefulset.name
```

---

## Cluster lookup helpers

**`core.isRealDeployment`** — returns `"true"` only during a real `helm install`/`upgrade`. Set `global.ignoreLookup: "true"` to disable lookups (CI, local rendering).

**`core.cluster.getResource`** — fetches a resource via `lookup`; fails the release if it doesn't exist during live deployments, no-ops otherwise.

**`core.configmap.get` / `core.secret.get` / `core.pvc.get`** — convenience wrappers for the three common resource types.

**`core.cluster.checkIfKeyExists`** — validates a key exists in a fetched resource; used internally by `core.container.env`.

---

## Umbrella charts

Place shared values under `global`. Each sub-chart reads it via `core.general.config` and merges with its own values. See [helm-templates](../helm-templates/README.md) for a no-template approach, or `test-charts/umbrella/` for a full template-authoring example with `master`, `worker`, and `common` sub-charts.
