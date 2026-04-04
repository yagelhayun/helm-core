# Helm Core — Developer Guide

This document is for contributors to `helm-core` itself: adding helpers, writing tests, understanding design decisions.

---

## Architecture

`helm-core` is a Helm library chart (`type: library`). Library charts expose named templates but produce no Kubernetes manifests on their own. They are vendored into consumer charts via `helm dependency update` and their helpers become available in the consumer's template namespace.

The library is intentionally generic. `helm-templates` is the primary consumer, but any chart can depend on `helm-core` directly and call its helpers to render workloads, pods, containers, probes, and volumes.

---

## Directory structure

```
helm-core/
├── Chart.yaml              # type: library, version
├── templates/              # all helpers live here as _*.tpl files
│   ├── _general.tpl        # config merging, naming, labels
│   ├── _cluster.tpl        # cluster lookup gating
│   ├── _workload.tpl       # strategy, replicas, workload labels
│   ├── _pod.tpl            # volumes, imagePullSecrets, initContainers, topology
│   ├── _container.tpl      # render, image, resources, env, probes, volumeMounts
│   ├── _configmap.tpl      # name + cluster get
│   ├── _secret.tpl         # cluster get
│   ├── _pvc.tpl            # cluster get
│   ├── _deployment.tpl     # name alias
│   ├── _service.tpl        # name alias
│   ├── _cronjob.tpl        # name alias
│   ├── _daemonset.tpl      # name alias
│   ├── _statefulset.tpl    # name alias
│   ├── _hpa.tpl            # name alias
│   ├── _pdb.tpl            # name alias
│   └── _serviceaccount.tpl # name resolution
└── test-charts/
    ├── single/             # single-chart consumer for unit tests
    └── umbrella/           # multi-subchart consumer for unit tests
```

Template files are prefixed with `_` so Helm does not try to render them as manifests.

---

## Naming conventions

All helpers follow `core.<resource>.<verb>`:

- `core.general.*` — cross-cutting: config merging, naming, labels
- `core.workload.*` — applies to any workload kind
- `core.pod.*` — pod spec level
- `core.container.*` — container spec level
- `core.cluster.*` — cluster lookup primitives
- `core.<type>.name` — resource-specific name helpers (extension points)
- `core.<type>.get` — cluster fetch for ConfigMap, Secret, PVC

---

## Context pattern

All helpers receive a single `$context` dict rather than `.` directly. This is a deliberate design choice:

- Helpers need both the merged config values *and* the live Helm root (`.`) for `$.Chart`, `$.Release`, and cluster `lookup` calls.
- Passing `.` alone would force helpers to re-run `core.general.config` internally (expensive, not DRY).
- Merging `$config` with `(dict "$" $)` gives helpers a flat namespace to work from while preserving the Helm root at the `$` key.

Consumer template boilerplate:

```yaml
{{- $config := include "core.general.config" . | fromYaml }}
{{- $context := merge (dict "$" $) $config }}
```

---

## Adding a new helper

1. Create or edit the appropriate `_<domain>.tpl` file.
2. Name the helper `core.<resource>.<verb>`.
3. Accept `$context` as the input (the merged context dict).
4. If the helper renders a Kubernetes resource name, add a `core.<type>.name` alias that delegates to `core.general.name` — this gives consumers an override point.
5. Add unit tests in `test-charts/single/unit-tests/` or `test-charts/umbrella/unit-tests/`.
6. Run `task test` to verify.

For helpers that need cluster lookups, gate them with `core.isRealDeployment` and return an empty string when the gate is closed. This keeps `helm template` and CI rendering fast and cluster-independent.

---

## Test infrastructure

Tests use the [helm-unittest](https://github.com/helm-unittest/helm-unittest) plugin. The library chart itself cannot be rendered directly, so tests run against thin consumer charts in `test-charts/`:

| Chart | What it tests |
|-------|---------------|
| `test-charts/single` | Single-service deployment: all core helpers |
| `test-charts/umbrella` | Multi-subchart: global value inheritance, per-subchart overrides |

Each consumer chart has its own `unit-tests/` directory with `*_test.yaml` files.

### test-charts/single unit tests

| File | Suite |
|------|-------|
| `container_test.yaml` | `core.container.render` — image, port, portName |
| `labels_test.yaml` | `core.general.labels`, `core.workload.labels` — commit label |
| `pdb_test.yaml` | PodDisruptionBudget rendering |
| `pod_test.yaml` | imagePullSecrets, initContainers, sidecars, checksum, topology |
| `probes_test.yaml` | httpGet and exec probes, defaults, omission |
| `pvc_test.yaml` | PVC creation, accessMode, storageClass |
| `region_config_test.yaml` | Config merge, region switching, tpl expressions |
| `replicas_test.yaml` | Active region scaling |
| `resources_test.yaml` | limitMultiplier, memory equality |
| `serviceaccount_test.yaml` | ServiceAccount create/name/pod reference |
| `strategy_test.yaml` | RollingUpdate defaults, Recreate, custom values |
| `volumes_test.yaml` | Volume types, volumeMounts, readOnly PVCs |

### test-charts/umbrella unit tests

| File | Suite |
|------|-------|
| `configmap_test.yaml` | tpl expressions, region merging, per-component data |
| `master_test.yaml` | Master subchart: resources, image, inherited globals |
| `worker_test.yaml` | Worker subchart: initContainers, label isolation from master |

---

## Running tests locally

Requires the `helm-unittest` plugin and [Task](https://taskfile.dev/).

```bash
# Package helm-core for use by test-charts (required before first test run)
task setup

# Run all unit tests
task test
```

`task setup` packages `helm-core` as a `.tgz` so `test-charts` can depend on it via `file://`. `task test` runs `helm dependency update` on both test charts, then executes all `*_test.yaml` suites.

To run a single test chart manually:

```bash
helm dependency update test-charts/single
helm unittest test-charts/single -f 'unit-tests/*_test.yaml'
```

---

## Design decisions

### `core.general.config` strips `global` and `regions`

After merging, `global` and `regions` are removed from the result. This keeps the context flat — helpers reference `$context.port` not `$context.global.port`. It also prevents accidental re-application of global values by helpers that aren't aware of the nesting.

### Cluster lookups are gated, not conditional

Rather than sprinkling `if` guards around each lookup, `core.isRealDeployment` centralises the gate. All lookup helpers call it internally. This means consumer templates never need to worry about accidentally hitting a cluster during `helm template` or CI rendering.

### Resource name helpers as extension points

`core.<type>.name` helpers exist even though they all delegate to `core.general.name`. A consumer chart can override `core.deployment.name` in its own templates to add a suffix or prefix without touching the library — Helm's template override mechanism makes the consumer's definition take precedence.

### `additionalProperties: false` is enforced in helm-templates, not here

`helm-core` has no schema — it is a library, not a user-facing chart. Schema validation belongs in `helm-templates` where users interact directly with `values.yaml`. This keeps the library unopinionated about what charts build on top of it.
