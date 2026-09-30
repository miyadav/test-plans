# Test Plan: OLMv0 to OLMv1 Migration — Console UI and E2E Testing (Tech Preview)

> **IEEE 829-conformant test plan**
> **Jira Feature:** [OCPSTRAT-2692 — \[Tech Preview\] OLMv0 to OLMv1 Migration: Console UI and E2E Testing](https://redhat.atlassian.net/browse/OCPSTRAT-2692)
> **Depends on:** [OCPSTRAT-2693 — Migration Library](https://redhat.atlassian.net/browse/OCPSTRAT-2693)
> **UX epic:** [HPUX-2193 — OCP Console: OLMv0→OLMv1 operator migration UX](https://issues.redhat.com/browse/HPUX-2193) (stories: HPUX-2194 requirements, HPUX-2195 migration flow design)
> **GA follow-up:** [OCPSTRAT-3281](https://redhat.atlassian.net/browse/OCPSTRAT-3281)

---

## 1. Test Plan Identifier

`TP-OCPSTRAT-2692-OLMv0-OLMv1-MIGRATION-TP-v1.1`

| Field | Value |
|-------|-------|
| Version | 1.1 |
| Date | 2026-09-23 |
| Target OpenShift release | 5.1 (Tech Preview) |
| Feature type | Tech Preview |
| Owning components | `console`, `Operator Framework` (OLMv1) |
| Feature status (Jira) | In Progress |
| Plan status | Active — tracking In Progress feature |

---

## 2. Introduction

This test plan describes the strategy, scope, resources, and schedule for validating the
**OLMv0 → OLMv1 migration** capability delivered as a Tech Preview in OpenShift 5.1, covering both
the **Console UI workflow** and the **end-to-end (E2E) test automation** delivered as part of this feature.

The feature enables an existing user of OLMv0 (classic OLM) to migrate eligible operators to
OLMv1 (Operator Controller / ClusterExtension model) through a Console UI workflow, with
**single-operator** and **bulk** migration paths, per-operator **automatic rollback on failure**,
and admin-initiated **rollback of successfully migrated** operators. The Console workflow is built
on the migration **library and CLI** delivered by OCPSTRAT-2693; the CLI in this feature is
**internal-only** (layered product teams and Red Hat engineers), not a customer deliverable.

The purpose of this document is to establish what will and will not be tested, the pass/fail
criteria, how test data (the operator fixture set) is sourced, and the environmental and staffing
needs so that the feature meets the OpenShift Definition of Ready quality bar for 5.1.

### 2.1 References

- OCPSTRAT-2692 — feature (this plan's subject)
- OCPSTRAT-2693 — migration library/CLI (four operator states, phased `Migrate()`, `Rollback()`)
- HPUX-2193 — UX epic (console migration UX); HPUX-2194 (requirements); HPUX-2195 (migration flow design)
- OCPSTRAT-2601 — operators with dependencies (out of scope here)
- OCPSTRAT-3281 — GA migration (out of scope here)
- IEEE 829 Standard for Software and System Test Documentation

---

## 3. Test Items

The following items (and their interfaces) are the subject of testing:

| ID | Item | Description |
|----|------|-------------|
| TI-1 | Console migration UI | "Migrate" workflow under **Installed Operators**: top-level bulk `Migrate` action + per-operator selection for incremental migration |
| TI-2 | Migration **library** methods | `ScanAll()`, `Check()`, `Gather()` (library-only — no CLI equivalent), `Migrate()`, `Rollback()`, `Cleanup()` — as consumed by the console and the CLI |
| TI-3 | Internal **CLI** (`migrate-operators-v0-to-v1`) | Subcommands `check`, `convert`, `rollback`, `cleanup`. Bulk = `convert --all` (non-interactive, script/CI-friendly); `--continue-on-error` for bulk failure handling; single-op dry-run = `convert <op> -n <ns> --dry-run`. No `migrate` or `gather` verb and no `-y` flag |
| TI-4 | Operator-state classification | Eligible / Ineligible / Already-migrated / Conflict — detection and reporting. The `migrated-from-subscription` annotation distinguishes a *migrated* CE from a *born-in-v1* CE; `rollback`/`cleanup` and conflict detection depend on it |
| TI-5 | Migrated `ClusterExtension` annotations | `olm.operatorframework.io/migrated-from-subscription: <ns>/<name>` marks the CE as migrated; the CE annotations also **store the Subscription/OperatorGroup specs** used as the rollback source-of-truth and for scan classification (already-migrated vs conflict) |
| TI-6 | Backup / rollback model | `--backup` writes **optional, non-authoritative** on-disk copies (not the recovery source). Rollback restores the **Subscription/OperatorGroup from the CE annotations** (TI-5); OLMv0 then reconciles the CSV. The CSV is **not** restored directly from on-disk backup |
| TI-7 | E2E test suite | Console e2e + library/CI automation delivered as part of this feature |

---

## 4. Features to Be Tested

Traceability is to the success criteria and expected results of OCPSTRAT-2692.

| ID | Feature under test | Source acceptance criterion |
|----|--------------------|-----------------------------|
| F-1 | Single eligible operator migration via console UI | "validate the process before committing to bulk migration" |
| F-2 | Bulk migration of all eligible operators via console UI | "initiate bulk migration of all eligible OLMv0 operators" |
| F-3 | Operand availability — **namespace-aware**: same-namespace retains workloads (no interruption); cross-namespace has bounded, expected controller downtime | "running workloads … are not interrupted" (same-ns); bounded controller gap (cross-ns) |
| F-4 | Failure handling is correct on **both sides of the activation boundary** — automatic recovery before target activation; preserved artifacts + explicit recovery after | OCPSTRAT-2693 recovery model; "automatically rolls it back…" applies **pre-activation** |
| F-5 | Failure recorded in logs + surfaced in UI with reason; flagged for retry | failure surfacing + standalone retry |
| F-6 | Admin-initiated rollback of a successfully migrated operator | Expected Results: "rollback (failure recovery and **post-success**)". *Note: the explicit "double confirmation" success criterion was removed in the 2026-09-23 update — confirmation UX now pending HPUX-2195; see §7.* |
| F-7 | Correct classification of all four states with no silent failures | eligible / ineligible (with reason) / already-migrated / conflict |
| F-8 | Ineligible / already-migrated operators do not block eligible ones | "do not block migration of eligible operators" |
| F-9 | Disconnected-cluster migration with pre-configured matching ClusterCatalog | disconnected success criterion (incl. `oc-mirror` customized catalogs — open question) |
| F-10 | Bulk migration non-interactive via `convert --all` (with `--continue-on-error` for failure handling) | "automatable via a library/CI flag" (implemented as `convert --all`) |
| F-11 | Conflict state (dual OLMv0/OLMv1 management) detected + surfaced before start | conflict detection pre-migration |
| F-12 | Migration status/progress surfaced in UI | "Migration status and progress should be surfaced in the UI" (UX per HPUX-2195) |
| F-13 | Full eligibility model at scan phase — **hard blocks** (skip w/ reason) and **soft-ack paths** (proceed only with the matching acknowledgement); enumerated in Appendix D | eligibility definition (per current implementation; see Appendix D) |
| F-14 | Idempotency / re-scan after migration reports "already migrated" | already-migrated state |
| F-15 | Acknowledged watch-scope change — non-AllNamespaces operator migrates **only** with `--acknowledge-watch-scope-change`; without it, classified ineligible | soft-ack path (Appendix D) |
| F-16 | Install-namespace migration — `--install-namespace` honored; PSA/SCC labels transferred; target-resource collisions rejected; source Deployment scaled down + Pods terminated; target ClusterObjectSet ready **before** source cleanup; source-namespace deleted **only** with `--acknowledge-namespace-delete` | migration mechanics (per implementation) |
| F-17 | *(Experimental)* `--system-managed-install-namespace` mode — capability-checks optional CE namespace support, derives the bundle-metadata namespace, prepares it before ClusterObjectSet application, omits `CE.spec.namespace` | experimental; TP scope TBC |
| F-18 | CatalogSource → ClusterCatalog migration — image-type sources migrated; unsupported types rejected; Serving readiness awaited; same-name/image deduplicated; source deleted **only** opt-in; priority overflow requires acknowledgement (validation in Appendix E) | migration mechanics (per implementation) |

---

## 5. Features Not to Be Tested

| ID | Excluded item | Rationale |
|----|---------------|-----------|
| NF-1 | *Unacknowledged* non-AllNamespaces (`OwnNamespace` / `SingleNamespace`) install modes | Ineligible by default. The **acknowledged** watch-scope-change path (`--acknowledge-watch-scope-change`) **is** in scope — see F-15 |
| NF-2 | ODF and operators with unresolved dependencies | Out of scope — tracked by OCPSTRAT-2601 (used only as ineligible fixtures) |
| NF-3 | Customer-facing CLI hardening / UX / docs | CLI is internal-only for this feature |
| NF-4 | Managed services (ROSA, ARO, OSD) | Stretch goal only — not a committed deliverable |
| NF-5 | GA-level migration guarantees / scale beyond TP | Covered by OCPSTRAT-3281 |
| NF-6 | Migration remediation guidance for ineligible operators | Explicitly deferred to a future iteration |
| NF-7 | `oc-mirror` **mirroring tool correctness** itself | Upstream dependency (open question, §15). Note: **CatalogSource → ClusterCatalog migration by the library is in scope** (F-18) |

---

## 6. Approach

### 6.1 Test levels & types

- **Functional testing** (primary): all `F-*` items above, driven through the Console UI and via
  the internal CLI/library where the console consumes it.
- **Integration testing:** console ↔ migration library ↔ OLMv0 (Subscription/CSV) ↔ OLMv1
  (ClusterExtension / ClusterExtensionRevision) ↔ ClusterCatalog.
- **Negative / fault-injection testing:** induce failure at each `Migrate()` phase
  (profile → catalog resolution → collect owned resources → [optional `--backup`] →
  create **ClusterObjectSet** → wait `Succeeded=True` + `Available=True` → create
  **ClusterExtension** → cleanup) and verify the correct recovery behavior on each side of the
  **activation boundary** (F-4a/F-4b) with no cross-operator impact (F-5). Migration does **not**
  directly create a `ClusterExtensionRevision`; catalog reconciliation manages those later.
- **Data-integrity / continuity testing:** monitor operand workloads throughout migration to
  confirm no interruption; measure and record the controller management-gap duration (F-3).
- **State-machine testing:** exercise all four operator states, including the deliberately
  constructed **conflict** state (F-7, F-11).
- **Environment matrix testing:** connected vs. disconnected clusters, including `oc-mirror`
  customized catalogs (F-9).
- **Automation / E2E testing:** library/CI-flag bulk migration and console e2e delivered as a
  tracked feature output (F-10, TI-7).

### 6.2 Test design techniques

- Requirements-based case derivation traced to each `F-*` (see §4).
- Equivalence partitioning across operator states (eligible / ineligible / already-migrated / conflict).
- Boundary/negative cases: unresolved dependency, unhealthy CSV, missing catalog, non-AllNamespaces mode.
- Dry-run / read-only verification: `check` and single-operator `convert <op> -n <ns> --dry-run`
  (and console equivalents) must make **zero** cluster modifications — verified by resource-diff
  before/after. Note: `Gather()` is library-only, and there is **no** bulk dry-run
  (`--all --dry-run` is not a supported safe preview).

### 6.3 Automation strategy

- **E2E automation is a tracked deliverable of this feature.**
- Bulk-migration path automated using `convert --all` (`--continue-on-error`) (F-10) and run in CI on TP builds.
- UI happy-paths (single + bulk) automated via console e2e harness; complex fault-injection and
  disconnected scenarios may remain **manual** for TP where automation cost is prohibitive.
- Backup/restore assertions automated by comparing captured Subscription/CSV YAML pre-migration
  to the restored resources post-rollback.

### 6.4 Test Data Strategy (operator fixture set)

The central data problem is obtaining a set of OLMv0 operators that deterministically exercise
each of the four states. The strategy has two rules and three sources.

**Rule 1 — Separate discovery.** The migration library (`ScanAll()` / `check`)
is itself the classifier under test, so it must **not** be used to both select and judge fixtures
(circular). Fixtures are selected and labelled using signals **independent** of the library —
PackageManifest install modes, bundle dependencies, CSV phase, and CatalogSource/ClusterCatalog
presence — and the library's classification is then **asserted equal** to the known label.

**Rule 2 — Construct the impossible states.** "Already migrated" and "conflict" do not occur
naturally in a healthy cluster and are built by scripting the target resources directly (see
Appendix C), independent of running a real migration.

**Sources:**

1. **Real catalog operators** — a shortlist of operators from the redhat / certified / community
   catalogs chosen to satisfy each state's independent signal (confirm current availability at
   test time; see Appendix C queries).
2. **Synthetic minimal operators** — 1–2 trivial operator bundles built and hosted in a test
   catalog, for deterministic behaviour and cheap **bulk/scale** counts (F-2, F-10).
3. **Requested artifacts from the feature team** — see §12 data asks (canonical eligibility
   predicate, existing fixture generators/test bundles, telemetry-informed operator shortlist,
   `oc-mirror` ImageSetConfiguration).

Per-state sourcing recipes and the discovery queries are in **Appendix C**.

---

## 7. Item Pass/Fail Criteria

A test item **passes** when all of the following hold for its associated `F-*` criteria:

| Criterion | Pass condition |
|-----------|----------------|
| Single migration (F-1) | Eligible operator ends managed by OLMv1 via a `ClusterExtension` carrying the `migrated-from-subscription` annotation; original Subscription + CSV removed |
| Bulk migration (F-2) | All eligible operators migrated in one run; ineligible/already-migrated skipped, not failed |
| Operand continuity (F-3) | **Same-namespace:** no operand workload restart/outage. **Cross-namespace:** source controller scaled down before target activation → bounded, recorded controller downtime within the (TBD) agreed bound; operand workloads themselves remain running |
| Failure **before** activation (F-4a) | Injected failure **automatically** restores the operator to its prior OLMv0 state, no manual intervention, no leftover target artifacts; other operators unaffected |
| Failure **at/after** activation (F-4b) | **No** auto-rollback; recovery artifacts (CE/COS/Secret) are **preserved**, the operator is halted and flagged for **explicit** `rollback`/`cleanup`; operator is **never** managed by OLMv0 and OLMv1 simultaneously; other operators continue (`--continue-on-error`). *Activation signal (likely ClusterObjectSet `Available=True`) TBC with library owners* |
| Failure surfacing (F-5) | Specific failure reason present in logs **and** in UI; operator flagged for standalone retry |
| Admin rollback (F-6) | Rollback restores the **Subscription/OperatorGroup from the CE annotations** and deletes the ClusterExtension; OLMv0 then reconciles the CSV; operands not interrupted. **Double-confirmation UX pending HPUX-2195** — verify against final UX before treating confirmation flow as a hard pass condition |
| Classification (F-7) | All four states correctly identified and reported; **no silent failures** |
| Non-blocking (F-8) | Presence of ineligible/already-migrated operators does not prevent eligible migrations |
| Disconnected (F-9) | Eligible operator with a pre-configured matching ClusterCatalog migrates successfully offline; behaviour on `oc-mirror` customized catalogs verified once the open question is resolved |
| Automation (F-10) | `convert --all` drives bulk migration non-interactively and reports per-operator results; `--continue-on-error` continues past a failed operator |
| Conflict detection (F-11) | Dual OLMv0/OLMv1 management detected and surfaced **before** any migration begins; auto-migration blocked |
| Status surfacing (F-12) | UI shows progress/status transitions for in-flight and completed migrations, per HPUX-2195 flow |
| Eligibility model (F-13) | Each hard block in Appendix D is classified ineligible and skipped with a specific reason; each soft-ack path proceeds **only** with its acknowledgement; catalog availability evaluated at scan (not deferred) |
| Idempotency (F-14) | Re-scan of a migrated operator reports "already migrated" and skips |
| Install-namespace (F-16) | `--install-namespace` honored; PSA/SCC labels present on target; colliding target resources cause rejection (no partial migration); source Deployment replicas → 0 and Pods terminated; target ClusterObjectSet `Available=True` **before** any source cleanup; source namespace deleted **only** when `--acknowledge-namespace-delete` is set |
| Catalog migration (F-18) | Image-type CatalogSources become Serving-ready ClusterCatalogs; unsupported types rejected with reason; duplicate name/image deduplicated (no double catalog); source CatalogSource removed only when opt-in flag set; priority overflow blocks until acknowledged |
| Dry-run safety | `check` and single-op `convert <op> -n <ns> --dry-run` cause zero cluster mutations; no bulk dry-run is offered |
| Fixture | Library classification matches the independently-derived state label for every fixture (§6.4, Appendix C) |

**Overall feature pass:** 100% of P1 (F-1, F-2, F-4, F-6, F-7, F-11) cases pass; ≥95% of all
functional cases pass with no open Critical/Blocker defects against TP acceptance criteria.

---

## 8. Suspension Criteria and Resumption Requirements

**Suspend testing when:**

- Migration corrupts or fails to restore operand availability (data-loss / continuity break) — Blocker.
- Recovery leaves an operator in a broken state not recoverable via `cleanup`/`rollback` (note: after the activation boundary, *preserved artifacts awaiting explicit recovery* is expected, not a failure).
- The migration library or console build is not deployable on the target TP payload.
- A conflict state is silently migrated (violates F-7 "no silent failures").
- The operator fixture set cannot be built for a state, blocking that state's cases (see §15).

**Resume testing when:**

- The blocking defect is fixed and verified in a new build, and a smoke test of F-1 (single
  migration) + F-6 (rollback) passes on a clean cluster.

---

## 9. Test Deliverables

- This test plan (living document, versioned in git).
- Test cases / Polarion (or equivalent) suite traced to `F-*` IDs in §4.
- **E2E automation suite** (console e2e + library/CI-flag bulk migration) — a tracked feature output (TI-7).
- **Operator fixture set + generator** covering all four states (real + synthetic), with the
  independent state-label metadata per fixture (§6.4, Appendix C).
- **Disconnected fixture artifacts**: `oc-mirror` ImageSetConfiguration + ClusterCatalog manifests,
  including a customized-catalog variant.
- Test execution report (per build) with pass/fail against §7.
- Defect reports (OCPBUGS) linked back to OCPSTRAT-2692.
- Controller management-gap measurement record (feeds the "duration TBD" engineering spike).

---

## 10. Testing Tasks

| # | Task | Depends on |
|---|------|-----------|
| T-1 | Finalize eligibility/state definitions with OCPSTRAT-2693 owners; obtain data asks (§12) | 2693 refinement |
| T-2 | Build the operator fixture set for all four states (real + synthetic; incl. conflict) per Appendix C | T-1 |
| T-2a | Build disconnected fixtures: `oc-mirror` ImageSetConfiguration + (customized) ClusterCatalog | T-1 |
| T-3 | Author functional test cases traced to F-1…F-14; map UI cases to HPUX-2195 flow | T-1 |
| T-4 | Stand up connected + disconnected TP clusters (env, §11) | — |
| T-5 | Implement E2E/CI automation for bulk migration via `convert --all` (`--continue-on-error`) + console happy-paths | T-2, T-4 |
| T-6 | Execute single + bulk happy-path (F-1, F-2, F-3, F-12) | T-3, T-4 |
| T-7 | Execute fault-injection + auto-rollback (F-4, F-5) | T-3, T-4 |
| T-8 | Execute admin rollback + confirmation UX (F-6) | T-6, HPUX-2195 |
| T-9 | Execute state/classification + non-blocking + idempotency (F-7, F-8, F-11, F-14); assert fixture | T-2, T-3 |
| T-10 | Execute disconnected migration incl. customized catalog (F-9) | T-2a, T-4 |
| T-11 | Measure & record controller management gap (F-3) | T-6 |
| T-12 | Triage defects, retest, produce execution report | T-6…T-11 |

---

## 11. Environmental Needs

- **Clusters:** at least one **connected** and one **disconnected/restricted-network** OpenShift
  5.1 cluster with the Tech Preview feature gate enabled (`TechPreviewNoUpgrade` or the specific
  migration feature gate, TBD).
- **Both OLMv0 and OLMv1 present:** classic OLM (Subscription/CSV) plus Operator Controller /
  ClusterExtension APIs installed.
- **ClusterCatalog(s):** matching catalogs pre-configured for all test operators; for disconnected,
  a mirrored catalog (via `oc-mirror`, assumed working per NF-7), including a customized variant.
- **Operator fixture set:** operators covering AllNamespaces (eligible), non-AllNamespaces
  (ineligible), unresolved-dependency (ineligible), unhealthy-CSV (ineligible), missing-catalog
  (ineligible), already-migrated, and a deliberately constructed conflict — plus synthetic minimal
  operators for bulk counts (see §6.4 / Appendix C).
- **Mirror registry** for the disconnected scenario.
- **Access:** cluster-admin credentials; console access; internal CLI binary / library build.
- **Tooling:** console e2e harness, CI runner for `convert --all`, workload-continuity monitor,
  resource-diff tooling for dry-run verification, `oc-mirror`.

---

## 12. Responsibilities

| Role | Responsibility |
|------|----------------|
| QE (Operator Framework / OLMv1) | Library/CLI, state classification, rollback, disconnected, fixture set, CI automation |
| QE (Console) | UI workflow, status surfacing, confirmation flow, failure surfacing; console e2e |
| Development (OLMv1 + Console) | Fix defects, provide feature-gate + build, define controller-gap bound, supply eligibility predicate + any existing fixture generators |
| UX (HPUX-2193) | Deliver migration flow design (HPUX-2195) and requirements (HPUX-2194); validate F-6/F-12 UI |
| Feature owner / PM | Confirm scope (incl. status of the dropped double-confirmation criterion), sign off on TP acceptance |
| Product / Data | Provide telemetry on real customer OLMv0 operator usage to prioritize the eligible fixture set |
| Release / TRT | Integrate CI jobs into payload signal |

**Data asks (tracked under T-1):**
1. Canonical, versioned **eligibility predicate**; and any existing **fixture generator / test
   operator bundles** from the OCPSTRAT-2693 unit/e2e suites (reuse over reinvent).
2. Reference list of **known-eligible operators** in TP-supported catalogs.
3. Which **ClusterCatalogs** (redhat / certified / community / custom) are in TP scope.
4. **Telemetry/Insights** on customer OLMv0 usage — install-mode distribution + dependency prevalence.
5. **`oc-mirror` ImageSetConfiguration** reference, including customized-catalog handling.

---

## 13. Staffing and Training Needs

- QE familiarity with **both** OLMv0 (Subscription/CSV) and OLMv1 (ClusterExtension /
  ClusterExtensionRevision / ClusterCatalog) resource models.
- Ability to **build/host operator bundles** (synthetic fixtures) and set up disconnected
  mirrored/customized catalogs (`oc-mirror`).
- Ramp-up on the migration library API (`ScanAll`, `Check`, `Gather`, `Migrate`, `Rollback`,
  `Cleanup`) and the CLI `migrate-operators-v0-to-v1` (`check`/`convert`/`rollback`/`cleanup`),
  coordinated with OCPSTRAT-2693 owners.

---

## 14. Schedule

Aligned to the 5.1 planning/refinement cycle. Milestones (to be dated during refinement):

| Milestone | Target |
|-----------|--------|
| Test plan approved | 5.1 refinement |
| Data asks resolved (T-1) | Before fixture build |
| Fixture set + cases ready (T-2, T-2a, T-3) | Before feature code-complete |
| E2E/CI automation live (T-5) | Feature code-complete |
| Functional execution complete (T-6…T-11) | Before TP feature-freeze |
| Execution report + sign-off (T-12) | TP freeze |

---

## 15. Risks and Contingencies

| Risk | Impact | Mitigation / Contingency |
|------|--------|--------------------------|
| Controller management-gap duration undefined ("TBD" spike) | Can't set pass bound for F-3 | Record measured gap; agree provisional TP bound with dev; gate GA (OCPSTRAT-3281) on it |
| `oc-mirror` + **customized catalog** behaviour unresolved (open question 2026-09-18) | Blocks/undermines disconnected F-9 | Pre-configure catalog manually; treat customized-catalog case as conditional; track the dependency to resolution |
| Sourcing realistic eligible operators is hard / catalog contents drift | Weak or unstable eligible + bulk coverage | Combine real operators with **synthetic minimal** operators; re-validate the shortlist against the live catalog at test time (Appendix C) |
| Fixture circularity | False confidence if SUT judges its own fixtures | Label fixtures from **independent** metadata; assert library classification == label (§6.4) |
| Double-confirmation criterion dropped from Jira | Ambiguous F-6 pass condition | Confirm intended UX with PM/UX via HPUX-2195 before finalizing F-6 |
| Conflict state hard to construct reliably | Weak F-11 coverage | Script deterministic creation of Subscription + annotated ClusterExtension for same package (Appendix C) |
| OCPSTRAT-2693 library API still changing | Test churn | Version-pin against agreed API; keep cases traced to states not signatures |
| TP scope creep (managed services, deps) | Effort dilution | Enforce §5 exclusions; defer to OCPSTRAT-2601 / 3281 |
| Rollback fidelity (backup/restore) gaps | Data/continuity risk | Byte-diff restored Subscription/CSV against captured backup |

---

## 16. Approvals

| Name / Role | Approval | Date |
|-------------|----------|------|
| Feature owner (PM) | | |
| QE lead (Operator Framework) | | |
| QE lead (Console) | | |
| Dev lead (OLMv1) | | |
| UX lead (HPUX-2193) | | |

---

### Appendix A — Operator-state reference (from OCPSTRAT-2693)

| State | Condition | Expected action |
|-------|-----------|-----------------|
| **Eligible** | OLMv0 Subscription present; no ClusterExtension; AllNamespaces, no unresolved deps, healthy CSV, package in an available ClusterCatalog (checked at scan) | Proceed with migration |
| **Ineligible** | Subscription present but fails ≥1 check | Report specific reason; skip |
| **Already migrated** | No Subscription; annotated ClusterExtension exists for same package | Report done; skip |
| **Conflict** | Both Subscription **and** annotated ClusterExtension exist for same package | Warn prominently; block auto-migration; require `cleanup`/`rollback` |

### Appendix B — `Migrate()` phases and the activation boundary

`Profile → Catalog resolution (by package name) → Collect owned resources →
[optional --backup to disk (non-authoritative)] → Create ClusterObjectSet (COS) →
wait Succeeded=True + Available=True  ‹— ACTIVATION BOUNDARY —›  Create ClusterExtension
(annotated migrated-from-subscription + stored Subscription/OperatorGroup specs) →
Cleanup (delete Subscription and CSV)`

- **Before the boundary** (up to COS activation): failures **auto-recover** to OLMv0 (F-4a).
- **At/after the boundary:** artifacts (CE/COS/Secret) are **preserved**; recovery is **explicit**
  via `rollback`/`cleanup` (F-4b), to avoid concurrent OLMv0 + OLMv1 management.
- Migration does **not** directly create a `ClusterExtensionRevision`; catalog reconciliation
  manages catalog-derived revisions later.

### Appendix C — Test data: per-state fixture recipes & discovery queries

**Discovery rule:** label every fixture from the *independent signal* column below, then
assert the migration library's classification equals that label. Never let the library both select
and judge a fixture.

| State (label) | How to build the fixture | Independent signal (the input) |
|---------------|--------------------------|----------------------------------------|
| Eligible | Install a dependency-free, AllNamespaces-capable operator from an enabled catalog; or a synthetic minimal operator | PackageManifest advertises `AllNamespaces`; bundle declares no required package/GVK; CSV `phase=Succeeded`; package resolvable in an enabled ClusterCatalog |
| Ineligible — mode | Install an OwnNamespace/SingleNamespace-only operator (or dual-mode with a namespaced OperatorGroup) | CSV `spec.installModes` lacks supported `AllNamespaces` |
| Ineligible — deps | Install a dependency-bearing operator without its dependency (ODF family per OCPSTRAT-2601 as fixture only) | bundle `dependencies` / `olm.package.required` non-empty & unsatisfied |
| Ineligible — unhealthy CSV | Break a healthy operator: patch deployment to a bad image ref or delete required RBAC | CSV `phase ≠ Succeeded` |
| Ineligible — no catalog | Install from a CatalogSource, then delete/disable that ClusterCatalog/CatalogSource | package absent from any enabled ClusterCatalog |
| Already migrated | With no Subscription for the package, create a `ClusterExtension` annotated `olm.operatorframework.io/migrated-from-subscription: <ns>/<name>` | annotation present + Subscription absent |
| Conflict | Simultaneously have an OLMv0 Subscription (+CSV) **and** an annotated ClusterExtension for the same package | both present for same package |
| Bulk/scale | Install N operators at once — mix real + synthetic minimal operators | N Subscriptions present |

**Discover AllNamespaces-capable candidates:**

```bash
oc get packagemanifest -A -o json | jq -r '.items[]
  | select([.status.channels[].currentCSVDesc.installModes[]
      | select(.type=="AllNamespaces" and .supported==true)] | length > 0)
  | "\(.status.catalogSource)/\(.metadata.name)"'
```

**Enumerate current OLMv0 / OLMv1 state on a cluster (starting inventory):**

```bash
oc get subscriptions.operators.coreos.com -A          # OLMv0 subscriptions
oc get csv -A                                          # CSV health/phase
oc get clusterextensions.olm.operatorframework.io     # OLMv1 extensions
oc get clustercatalogs.olm.operatorframework.io       # available catalogs
oc get catalogsource -n openshift-marketplace         # OLMv0 catalog sources
```

**Cross-check (assertion):** run `check` (read-only, no mutations) or `ScanAll()` and
confirm the reported state for each fixture equals its independently-derived label above.

### Appendix D — Eligibility model (hard blocks & soft-ack paths)

Evaluated at the scan phase. (Reflects current implementation; the OCPSTRAT-2693 description is
being updated to match.)

**Hard blocks — always ineligible; skip with a specific reason:**

| Condition | Reason surfaced |
|-----------|-----------------|
| Declared package or GVK dependency | Dependencies not migratable (ref OCPSTRAT-2601) |
| APIService-owning operator | Not supported |
| Missing ClusterCatalog content for the package | "package not found in any ClusterCatalog" |
| OLMv0-generated dependency Subscription (`olm.generated-by`) | Managed as a dependency, not standalone |

**Soft-ack paths — ineligible by default; proceed only with the acknowledgement:**

| Condition | Acknowledgement |
|-----------|-----------------|
| Watch-scope change (non-AllNamespaces OperatorGroup) | `--acknowledge-watch-scope-change` |
| Active `OperatorCondition` | (flag TBC) |
| OLMv0-only RBAC present | (flag TBC) |
| Scoped ServiceAccount | (flag TBC) |
| Non-steady state (operator mid-reconcile) | (retry when steady) |

### Appendix E — CatalogSource → ClusterCatalog migration: fixtures & validation

| Check (F-18) | Fixture to set up | How to validate |
|--------------|-------------------|-----------------|
| Image-type migrated | A `grpc` CatalogSource with `spec.image` | Run migration; assert a ClusterCatalog is created for it |
| Unsupported type rejected | A non-image CatalogSource (e.g. grpc `address:`-based, or `configmap` type) | Run migration; assert rejected with a specific reason; **no** ClusterCatalog created |
| Serving readiness | Any image-type source | After migration, assert the ClusterCatalog reaches its Serving/ready condition before it's treated as migrated |
| Same-name/image dedup | Two CatalogSources sharing a name or image | Run migration; assert **exactly one** ClusterCatalog results (no duplicate) |
| Delete-source opt-in | One image-type source; run twice | Without opt-in → source CatalogSource remains; with opt-in flag → source removed |
| Priority-overflow ack | A CatalogSource with priority beyond the allowed bound | Run migration; assert blocked until acknowledged; with acknowledgement → proceeds |

Enumerate results with `oc get clustercatalogs.olm.operatorframework.io`. Exact `sourceType`
names, the Serving condition name, the delete opt-in flag, and the priority-overflow flag/bound
are **TBC with library owners**.

