# Helm Core

A Helm library chart that provides a shared hub of reusable template helpers for rendering Kubernetes workloads. It is not deployed directly — it is consumed as a dependency by any number of application or library charts.

`helm-templates` is one example consumer, but the library is intentionally generic: any chart that needs deployments, services, configmaps, probes, volumes, or region-aware config merging can depend on `helm-core` and call its helpers directly.

---

## Consuming this library

Add `helm-core` as a dependency in your `Chart.yaml`:

```yaml
dependencies:
  - name: core
    version: 0.1.0
    repository: "file://../helm-core"
```

Then run `helm dependency update` to fetch it.

In your templates, build the context dict once at the top of each template file and pass it to every helper:

```yaml
{{- $config := include "core.general.config" . | fromYaml }}
{{- $context := merge (dict "$" $) $config }}
```

`$config` is the merged, region-resolved values object. `$context` adds the live Helm root context (`$`) so helpers that need `$.Chart`, `$.Release`, or cluster lookups can access them.

---

## Configuration system

### `core.general.config`

The core of the library. Merges values from three sources in priority order (highest wins):

1. Region-specific overrides (`regions.<region>.*`)
2. Root chart values (`.Values.*`)
3. Global values (`.Values.global.*`)

The `global` object is then stripped from the result. Keys in `regions` are also stripped. The final object contains a flat, merged configuration ready for use.

**Requires** `global.region` to be set in values.

**Example values:**

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
  us-west-1:
    configMap:
      data:
        ENDPOINT: "api.us-west-1.example.com"
```

**Values may contain Go template expressions** (resolved via `tpl`):

```yaml
configMap:
  data:
    PORT: "{{ .Values.port }}"
```

### `core.general.name`

Returns `$.Chart.Name`. Used as the default name for all Kubernetes resources and the main container.

```yaml
name: {{ include "core.general.name" $context }}
```

---

## Labels

### `core.common.labels`

Emits the standard Kubernetes label set:

```yaml
app.kubernetes.io/name: "<chart-name>"
helm.sh/chart: "<chart-name>-<chart-version>"
app.kubernetes.io/managed-by: "Helm"
```

### `core.deployment.labels`

Extends `core.common.labels` with an optional `commit` label sourced from `global.commit`. If `global.commit` is absent the label is omitted, so local development flows are not blocked.

---

## Deployment helpers

### `core.deployment.name`
Returns the deployment name (delegates to `core.general.name`).

### `core.common.replicas`

Returns the configured replica count, or `0` if `activeRegion` is set and does not match the current `region`. Used to make a deployment dormant in non-active regions without removing it.

```yaml
# Values
activeRegion: us-east-1
region: us-west-1   # set by the platform, not the developer
replicas: 3
# Result: 0 replicas (region doesn't match activeRegion)
```

### `core.common.strategy`

Renders the deployment strategy block. Defaults to `RollingUpdate` with percentage-based values (`25%`) so the budget scales automatically with replica count. Set `strategy.type: Recreate` to terminate all pods before starting new ones.

```yaml
strategy: {{ include "core.common.strategy" $context | nindent 4 }}
```

```yaml
# values — all fields optional
strategy:
  type: RollingUpdate   # default, or Recreate
  maxUnavailable: "25%" # default
  maxSurge: "25%"       # default
```

---

## Pod helpers

### `core.pod.volumes`

Renders the `volumes:` list from `volumes.secrets`, `volumes.configMaps`, and `volumes.empty`. Validates that referenced secrets exist in the cluster during real deployments.

```yaml
{{- with (include "core.pod.volumes" $context) }}
volumes: {{ . | indent 6 }}
{{- end }}
```

**Values shape:**

```yaml
volumes:
  secrets:
    my-secret:
      mountPath: /run/secrets    # used by volumeMounts
      defaultMode: 420           # optional, default 420 (0644)
      files:                     # optional: mount individual keys as files
        - my-key
  configMaps:
    my-configmap:
      mountPath: /etc/config
  empty:
    my-scratch-dir:
      mountPath: /tmp/scratch    # optional for emptyDir
```

### `core.pod.imagePullSecrets`

Renders `imagePullSecrets` from `image.pullSecrets` or `global.image.pullSecrets` (local takes priority).

```yaml
{{- with (include "core.pod.imagePullSecrets" $context) }}
imagePullSecrets: {{ . | indent 6 }}
{{- end }}
```

### `core.pod.initContainers`

Renders `initContainers` by delegating each entry to `core.container.render`. See [Container helpers](#container-helpers) for the container spec shape. Init containers share the pod's volumes — declare them in the root `volumes` config.

```yaml
{{- with (include "core.pod.initContainers" $context) }}
initContainers: {{ . | indent 6 }}
{{- end }}
```

### `core.pod.topologySpreadConstraints`

Renders topology spread constraints with an auto-injected `labelSelector`. By default (when the key is absent from values) two constraints are applied — one across hostnames and one across availability zones, both with `whenUnsatisfiable: ScheduleAnyway` so scheduling is never hard-blocked.

Consumer charts should declare the defaults explicitly in their `values.yaml` so users can see and override them. Set `topologySpreadConstraints: []` to disable entirely.

```yaml
# values
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway
```

### `core.pod.annotations`

Emits a `checksum/config` annotation derived from the ConfigMap data. Changing any ConfigMap value triggers a rolling restart of the deployment.

---

## Container helpers

### `core.container.render`

The central container renderer. Produces a single `- name: ...` list item. Used for the main container, init containers, and sidecars.

**Parameters** (all passed via the `$context` dict):

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `name` | string | no | Container name. Defaults to `core.general.name` (use for main container). |
| `image.url` | string | yes | Image repository URL. Falls back to `global.image.url`. |
| `image.tag` | string | no | Image tag. Falls back to `global.image.tag`, then `"latest"`. |
| `image.pullPolicy` | string | no | `Always`, `IfNotPresent`, or `Never`. Default: `IfNotPresent`. |
| `port` | integer | no | Container port number. |
| `portName` | string | no | Named port. Default: `"http"`. |
| `command` | array | no | Entrypoint override. |
| `args` | array | no | Args override. |
| `envFrom` | object | no | Bulk environment from ConfigMaps/Secrets. See below. |
| `env` | object | no | Individual env vars from ConfigMap/Secret keys. See below. |
| `resources` | object | no | CPU/memory requests and limits. |
| `volumes` | object | no | Used to generate `volumeMounts`. |
| `probes` | object | no | `readiness`, `liveness`, `startup` probes. |

**Usage:**

```yaml
containers: {{ include "core.container.render" $context | nindent 6 }}
```

### `core.container.sidecars`

Iterates `.sidecars` and calls `core.container.render` for each. Each sidecar entry is a container spec object with `name` required.

```yaml
{{- with (include "core.container.sidecars" $context) }}
{{- . | indent 6 }}
{{- end }}
```

### `core.container.resources`

Computes requests and limits from the `resources` config:

```yaml
resources:
  cpu: 250m      # request
  memory: 512Mi  # request and limit
  limitMultiplier: 4  # optional, default 4 — CPU limit = request × multiplier
```

Result:
```yaml
requests:
  cpu: '250m'
  memory: '512Mi'
limits:
  cpu: '1000m'
  memory: '512Mi'
```

### `core.container.envFrom` / `core.container.envFrom.base`

Renders `envFrom` entries. `core.container.envFrom` additionally appends the chart's own generated ConfigMap when `configMap.data` is set. `core.container.envFrom.base` renders only explicitly listed sources.

```yaml
envFrom:
  configMaps:
    shared-config: {}
  secrets:
    my-secret: {}
```

### `core.container.env`

Renders individual environment variables sourced from named keys in ConfigMaps or Secrets. Validates that the referenced key exists in the cluster during real deployments.

```yaml
env:
  secrets:
    my-secret:
      - key: DB_PASSWORD
        variable: DATABASE_PASSWORD
  configMaps:
    my-config:
      - key: LOG_LEVEL
        variable: LOG_LEVEL
```

### `core.container.volumeMounts`

Renders `volumeMounts` from the `volumes` config. `emptyDir` entries are skipped unless they have a `mountPath`. For `files`-based mounts, each file becomes a separate entry with `subPath`.

### Probe helpers

Three helpers — `core.container.readinessProbe`, `core.container.livenessProbe`, `core.container.startupProbe` — all delegate to `core.container.probes`.

**httpGet probe:**

```yaml
probes:
  readiness:
    httpGet:
      path: /health
      scheme: HTTP     # optional, default HTTP
    failureThreshold: 3
    initialDelaySeconds: 40
    periodSeconds: 30
    successThreshold: 1
    timeoutSeconds: 20
```

**exec probe:**

```yaml
probes:
  liveness:
    exec:
      command: ["sh", "-c", "pg_isready"]
```

---

## Resource name helpers

Each resource type has a `core.<type>.name` helper that returns `core.general.name`. They exist as extension points — override them in your chart to customise naming:

```
core.configmap.name
core.deployment.name
core.service.name
core.cronjob.name
core.hpa.name
```

---

## Cluster lookup helpers

### `core.isRealDeployment`

Returns `"true"` only during a real `helm install`/`upgrade` (not `helm template` or `--dry-run`). Uses `$.Release.IsRender` on Helm 3.13+, falls back to checking the release name placeholder on older versions.

Set `global.ignoreLookup: "true"` to disable cluster lookups entirely (required for test/CI rendering without a cluster).

### `core.cluster.getResource`

Fetches a resource from the cluster via `lookup`. Fails the release if the resource does not exist during a real deployment.

### `core.configmap.get` / `core.secret.get`

Convenience wrappers around `core.cluster.getResource` for ConfigMaps and Secrets.

### `core.cluster.checkIfKeyExists`

Fails the release if a specific key is absent from a fetched resource. Used by `core.container.env` to validate env var mappings.

---

## Test charts

Two test application charts live under `test-charts/`. They wrap the library so its helpers can be rendered and validated without a deployed application chart.

| Chart | Purpose |
|-------|---------|
| `test-charts/single` | Single-chart deployment: configmap, service, deployment |
| `test-charts/umbrella` | Multi-chart umbrella: `common` (configmap only), `master`, `worker` sub-charts |

Render manually:

```bash
cd test-charts/single
helm dependency update
helm template core-test-single . -f common.values.yaml -f prod.values.yaml
```

Run unit tests (requires the [helm-unittest](https://github.com/helm-unittest/helm-unittest) plugin):

```bash
cd test-charts/single
helm dependency build
helm unittest -f 'unit-tests/*_test.yaml' .
```
