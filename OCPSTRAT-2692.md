# Test Plan: OLMv0 to OLMv1 Migration — Console UI and E2E Testing (Tech Preview)

> **IEEE 829-conformant test plan**
> **Jira Feature:** [OCPSTRAT-2692 — \[Tech Preview\] OLMv0 to OLMv1 Migration: Console UI and E2E Testing](https://redhat.atlassian.net/browse/OCPSTRAT-2692)
> **Depends on (not under test here):** [OCPSTRAT-2693 — Migration Library/CLI](https://redhat.atlassian.net/browse/OCPSTRAT-2693)
> **UX epic:** [HPUX-2193 — OCP Console: OLMv0→OLMv1 operator migration UX](https://issues.redhat.com/browse/HPUX-2193) (stories: HPUX-2194 requirements, HPUX-2195 migration flow design)
> **GA follow-up:** [OCPSTRAT-3281](https://redhat.atlassian.net/browse/OCPSTRAT-3281)

---

## 1. Test Plan Identifier

`TP-OCPSTRAT-2692-OLMv0-OLMv1-MIGRATION-TP-v1.2`

| Field | Value |
|-------|-------|
| Version | 1.2 |
| Date | 2026-10-05 |
| Target OpenShift release | 5.1 (Tech Preview) |
| Feature type | Tech Preview |
| Owning component | `console` |
| Feature status (Jira) | In Progress |
| Plan status | Active — tracking In Progress feature |

---

## 2. Introduction

This test plan describes the strategy, scope, resources, and schedule for validating the
**OLMv0 → OLMv1 migration** capability as delivered through the **OpenShift Console UI** and the
**end-to-end (E2E) test automation** that drives that UI, as a Tech Preview in OpenShift 5.1.

The feature enables an existing user of OLMv0 (classic OLM) to migrate eligible operators to
OLMv1 (Operator Controller / ClusterExtension model) through a Console UI workflow, with
**single-operator** and **bulk** migration paths, per-operator **automatic rollback on failure**,
and admin-initiated **rollback of successfully migrated** operators.

The Console workflow is built on the migration **library and CLI** delivered by **OCPSTRAT-2693**.
That library and CLI are the tools the Console uses to meet its acceptance criteria; their internal
correctness is **not** the subject of this plan.

### 2.1 Scope statement (what this plan covers — and what it does not)

- **In scope:** the Console UI workflow and the E2E automation that exercises migration **through
  the Console and asserts on console-observable behavior and cluster-level outcomes** (the resulting
  OLMv1 `ClusterExtension`, the removal of the OLMv0 `Subscription`/CSV, operand continuity, and what
  the UI displays to the admin).
- **Out of scope (OCPSTRAT-2693):** the migration **library methods** (`ScanAll/Check/Gather/
  Migrate/Rollback/Cleanup`), the internal **CLI** (`migrate-operators-v0-to-v1`) and its
  subcommands/flags, and the library's **internal mechanics** (the `Migrate()` phase machine and
  activation boundary, the `migrated-from-subscription` annotation data model, the backup/restore
  source-of-truth, the eligibility predicate, and CatalogSource→ClusterCatalog conversion). These
  are a **dependency** of this feature and are validated by OCPSTRAT-2693's own test plan.

The discriminator used throughout this plan: **we assert on what the admin sees in the Console and
on the end-state of the cluster — never on library internals or CLI flags.**

### 2.2 Scope change log (v1.2)

v1.2 scopes this plan down to the feature stated in its title (Console UI + E2E), per review feedback
that "the migration library is an implementation detail of OCPSTRAT-2692; the UI shouldn't be
concerned with testing underlying tools that it uses to meet AC." The following were **removed** from
this plan and belong to the **OCPSTRAT-2693** test plan:

- Direct testing of library methods and the internal CLI subcommands/flags
  (`convert --all`, `--continue-on-error`, `--dry-run`, `--acknowledge-watch-scope-change`,
  `--install-namespace`, `--acknowledge-namespace-delete`, `--system-managed-install-namespace`).
- The `Migrate()` phase-level fault-injection and activation-boundary internals.
- The eligibility predicate enumeration (former Appendix D) and CatalogSource→ClusterCatalog
  conversion validation (former Appendix E).
- The fixture-classifier-circularity argument (that is a library-under-test concern).

Behaviors that are **observable through the Console** (e.g. failure surfacing, the four operator
states as displayed, conflict blocking, status/progress) are retained, reframed as UI/E2E assertions.

### 2.3 References

- OCPSTRAT-2692 — feature (this plan's subject: Console UI + E2E)
- OCPSTRAT-2693 — migration library/CLI (dependency; has its own test plan)
- HPUX-2193 — UX epic (console migration UX); HPUX-2194 (requirements); HPUX-2195 (migration flow design)
- OCPSTRAT-2601 — operators with dependencies (out of scope here)
- OCPSTRAT-3281 — GA migration (out of scope here)
- IEEE 829 Standard for Software and System Test Documentation

---

## 3. Test Items

The following items (and their interfaces) are the subject of testing. All are Console-facing.

| ID | Item | Description |
|----|------|-------------|
| TI-1 | Console migration UI | "Migrate" workflow under **Installed Operators**: top-level bulk `Migrate` action + per-operator selection for incremental migration |
| TI-2 | Console state presentation | How the console **displays** each operator state (eligible / ineligible-with-reason / already-migrated / conflict) to the admin |
| TI-3 | Console status, failure & rollback surfacing | In-flight status/progress, failure reason + retry flagging, and the admin-initiated rollback action and its confirmation UX |
| TI-4 | Console E2E suite | Console e2e automation that drives the migration workflow end-to-end and asserts console + cluster outcomes |

> **Not test items (dependencies, owned by OCPSTRAT-2693):** the migration library methods, the
> internal CLI and its flags, the `migrated-from-subscription` annotation data model, the backup/
> restore model, the `Migrate()` phase machine, and the eligibility predicate. This plan relies on
> them and verifies only their **console-observable effects**.

---

## 4. Features to Be Tested

Traceability is to the Console UI / E2E acceptance criteria of OCPSTRAT-2692. Each feature is
asserted via the **Console and/or end-state cluster resources**, not via library/CLI internals.

| ID | Feature under test | Console/E2E acceptance expectation |
|----|--------------------|-------------------------------------|
| F-1 | Single eligible operator migration via console UI | Admin migrates one operator from the UI; validates the flow before committing to bulk |
| F-2 | Bulk migration of all eligible operators via console UI | Admin initiates bulk migration from the top-level UI action |
| F-3 | Operand availability — **namespace-aware**: same-namespace retains workloads (no interruption); cross-namespace has bounded, expected controller downtime | Observed end-to-end: running workloads are not interrupted (same-ns); bounded controller gap (cross-ns) |
| F-4 | Console correctly **reflects** the two failure-recovery outcomes: automatic recovery (operator returns to working state, no admin action) vs. preserved-and-halted (operator flagged for explicit recovery) | The UI shows the correct outcome for each case; the underlying recovery mechanism is a 2693 dependency |
| F-5 | Failure reason surfaced in the UI and flagged for standalone retry | Specific failure reason visible in the console; operator flagged for retry |
| F-6 | Admin-initiated rollback of a successfully migrated operator via the console | Rollback is triggerable from the UI; operand workloads not interrupted. *Confirmation UX pending HPUX-2195; see §7.* |
| F-7 | All four operator states correctly **distinguished and labeled in the console** | Eligible / ineligible (with specific reason) / already-migrated / conflict are each shown correctly; no silent mislabeling in the UI |
| F-8 | Ineligible / already-migrated operators do not block eligible ones in the UI | A bulk run with mixed states migrates the eligible ones and skips the rest, surfaced in the UI |
| F-9 | Disconnected-cluster migration via the console with a pre-configured matching ClusterCatalog | Eligible operator migrates successfully offline through the UI |
| F-10 | Conflict state (dual OLMv0/OLMv1 management) surfaced in the UI **before** start, auto-migration blocked | Console warns prominently and blocks auto-migration for a conflicted operator |
| F-11 | Migration status/progress surfaced in the UI | Console shows progress/status transitions for in-flight and completed migrations (UX per HPUX-2195) |
| F-12 | Idempotency — re-visiting a migrated operator shows "already migrated" in the UI and offers no re-migration | After migration, the console reports the operator as already migrated |

---

## 5. Features Not to Be Tested

| ID | Excluded item | Rationale |
|----|---------------|-----------|
| NF-1 | **Migration library methods and internal CLI correctness** (`ScanAll/Check/Gather/Migrate/Rollback/Cleanup`, `migrate-operators-v0-to-v1` subcommands and all flags) | Dependency delivered by **OCPSTRAT-2693**; covered by its own test plan. This plan verifies only console-observable effects |
| NF-2 | Library **internal mechanics**: `Migrate()` phase machine / activation boundary, `migrated-from-subscription` annotation data model, backup/restore source-of-truth, eligibility predicate, CatalogSource→ClusterCatalog conversion, install-namespace mechanics | Implementation details of the tools the UI consumes (OCPSTRAT-2693) |
| NF-3 | Non-AllNamespaces install modes and acknowledged soft-ack paths as **library behavior** | Eligibility/acknowledgement logic is a 2693 concern; the console only needs to **display** the resulting state/reason (covered by F-7) |
| NF-4 | ODF and operators with unresolved dependencies | Out of scope — tracked by OCPSTRAT-2601 (used only as ineligible fixtures so the UI can show the ineligible state) |
| NF-5 | Customer-facing CLI hardening / UX / docs | CLI is internal-only and out of scope for this UI plan |
| NF-6 | Managed services (ROSA, ARO, OSD) | Stretch goal only — not a committed deliverable |
| NF-7 | GA-level migration guarantees / scale beyond TP | Covered by OCPSTRAT-3281 |
| NF-8 | Migration remediation guidance for ineligible operators | Explicitly deferred to a future iteration |
| NF-9 | `oc-mirror` mirroring tool correctness | Upstream dependency; assumed working for the disconnected F-9 setup |

---

## 6. Approach

### 6.1 Test levels & types

- **Functional UI testing** (primary): all `F-*` items above, driven through the Console UI.
- **E2E / integration testing:** migration exercised end-to-end through the console, asserting on
  the resulting cluster state (OLMv1 `ClusterExtension` present, OLMv0 `Subscription`/CSV removed,
  operands healthy) — the library/OLMv0/OLMv1 interactions are treated as a black box.
- **Negative / fault-injection testing:** induce a migration failure (e.g. via an ineligible or
  broken fixture, or an injected catalog/resource fault) and verify **the console reflects the
  correct outcome** — automatic recovery vs. preserved-and-halted-with-retry (F-4, F-5) — and that
  other operators in a bulk run are unaffected (F-8). We assert on UI state and end-state cluster
  resources, not on library phases.
- **Data-integrity / continuity testing:** monitor operand workloads throughout a console-driven
  migration to confirm no interruption; measure and record the controller management-gap duration (F-3).
- **State presentation testing:** exercise all four operator states, including a deliberately
  constructed **conflict** state, and assert the **console displays** each correctly (F-7, F-10).
- **Environment matrix testing:** connected vs. disconnected clusters (F-9).

### 6.2 Test design techniques

- Requirements-based case derivation traced to each `F-*` (see §4) and to the HPUX-2195 flow.
- Equivalence partitioning across operator states (eligible / ineligible / already-migrated / conflict)
  as **displayed** by the console.
- Boundary/negative cases: unresolved dependency, unhealthy CSV, missing catalog, non-AllNamespaces
  mode — used to confirm the UI shows the correct ineligible reason and does not block eligible operators.

### 6.3 Automation strategy

- **Console E2E automation is a tracked deliverable of this feature** (TI-4).
- UI happy-paths (single + bulk) automated via the console e2e harness and run in CI on TP builds.
- Complex fault-injection and disconnected scenarios may remain **manual** for TP where automation
  cost is prohibitive.
- Rollback assertions automated by comparing the operator's pre-migration and post-rollback
  observable state (operand running; operator again managed by OLMv0) — not by inspecting the
  library's internal backup artifacts.

### 6.4 Test Data Strategy (operator fixture set)

The console must correctly **display** each operator state, so we need a set of OLMv0 operators that
deterministically land in each state. Fixtures are labelled from signals **independent** of the
console/library (PackageManifest install modes, bundle dependencies, CSV phase, CatalogSource/
ClusterCatalog presence), and the **console's displayed state** is then asserted equal to that label.

"Already migrated" and "conflict" do not occur naturally and are built by scripting the target
resources directly (see Appendix B), so the console can be checked against a known state.

**Sources:**

1. **Real catalog operators** — a shortlist from the redhat / certified / community catalogs chosen
   to satisfy each state's independent signal (confirm availability at test time; see Appendix B).
2. **Synthetic minimal operators** — 1–2 trivial operator bundles in a test catalog, for
   deterministic behaviour and cheap **bulk/scale** counts (F-2).
3. **Requested artifacts from the feature team** — see §12 data asks.

Per-state sourcing recipes and the discovery queries are in **Appendix B**.

---

## 7. Item Pass/Fail Criteria

A test item **passes** when all of the following hold for its associated `F-*` criteria, asserted via
the Console and/or end-state cluster resources:

| Criterion | Pass condition |
|-----------|----------------|
| Single migration (F-1) | After the UI flow, the operator is managed by OLMv1 via a `ClusterExtension`; the original Subscription + CSV are gone |
| Bulk migration (F-2) | All eligible operators migrated in one UI-initiated run; ineligible/already-migrated shown as skipped, not failed |
| Operand continuity (F-3) | **Same-namespace:** no operand workload restart/outage. **Cross-namespace:** bounded, recorded controller downtime within the (TBD) agreed bound; operand workloads remain running |
| Failure reflected in UI (F-4) | For a pre-activation failure the UI shows the operator automatically recovered (no admin action, still working via OLMv0); for a post-activation failure the UI shows it halted and flagged for explicit recovery — never shown as silently succeeded; other operators unaffected |
| Failure surfacing (F-5) | Specific failure reason visible in the UI; operator flagged for standalone retry |
| Admin rollback (F-6) | Rollback is triggerable from the console; afterward the operator is again managed by OLMv0 and operands are not interrupted. **Double-confirmation UX pending HPUX-2195** — verify against final UX before treating confirmation flow as a hard pass condition |
| State display (F-7) | All four states correctly labeled in the UI, each ineligible operator shown with a specific reason; **no silent mislabeling** |
| Non-blocking (F-8) | Presence of ineligible/already-migrated operators does not prevent eligible migrations in a bulk UI run |
| Disconnected (F-9) | Eligible operator with a pre-configured matching ClusterCatalog migrates successfully offline through the console |
| Conflict surfacing (F-10) | Dual OLMv0/OLMv1 management detected and surfaced in the UI **before** any migration begins; auto-migration blocked |
| Status surfacing (F-11) | UI shows progress/status transitions for in-flight and completed migrations, per HPUX-2195 flow |
| Idempotency (F-12) | Re-visiting a migrated operator in the console shows "already migrated" and offers no re-migration |
| Fixture | The console's displayed state matches the independently-derived state label for every fixture (§6.4, Appendix B) |

**Overall feature pass:** 100% of P1 (F-1, F-2, F-4, F-6, F-7, F-10) cases pass; ≥95% of all
functional UI cases pass with no open Critical/Blocker defects against TP acceptance criteria.

---

## 8. Suspension Criteria and Resumption Requirements

**Suspend testing when:**

- A console-driven migration corrupts or fails to restore operand availability (data-loss /
  continuity break) — Blocker.
- The console build is not deployable on the target TP payload, or the OCPSTRAT-2693 library/CLI
  dependency is not available/deployable (blocks all cases).
- A conflict state is **not surfaced** by the UI and auto-migration proceeds (violates F-7/F-10
  "no silent" behavior).
- The operator fixture set cannot be built for a state, blocking that state's UI cases (see §15).

**Resume testing when:**

- The blocking defect is fixed and verified in a new build, and a smoke test of F-1 (single
  migration) + F-6 (rollback) passes through the console on a clean cluster.

---

## 9. Test Deliverables

- This test plan (living document, versioned in git).
- Test cases / Polarion (or equivalent) suite traced to `F-*` IDs in §4.
- **Console E2E automation suite** — a tracked feature output (TI-4).
- **Operator fixture set + generator** covering all four states (real + synthetic), with the
  independent state-label metadata per fixture (§6.4, Appendix B).
- **Disconnected fixture artifacts**: mirrored ClusterCatalog manifests for the disconnected case.
- Test execution report (per build) with pass/fail against §7.
- Defect reports (OCPBUGS) linked back to OCPSTRAT-2692 (console defects) or OCPSTRAT-2693 (if a
  failure is traced to the underlying library/CLI).
- Controller management-gap measurement record (feeds the "duration TBD" engineering spike).

---

## 10. Testing Tasks

| # | Task | Depends on |
|---|------|-----------|
| T-1 | Confirm console-observable acceptance criteria with the feature/UX owners; obtain data asks (§12) | HPUX-2195, 2693 refinement |
| T-2 | Build the operator fixture set for all four states (real + synthetic; incl. conflict) per Appendix B | T-1 |
| T-2a | Build disconnected fixtures: mirrored ClusterCatalog for the disconnected case | T-1 |
| T-3 | Author functional UI test cases traced to F-1…F-12; map UI cases to the HPUX-2195 flow | T-1 |
| T-4 | Stand up connected + disconnected TP clusters (env, §11) | — |
| T-5 | Implement console E2E automation for single + bulk happy-paths | T-2, T-4 |
| T-6 | Execute single + bulk happy-path through the UI (F-1, F-2, F-3, F-11) | T-3, T-4 |
| T-7 | Execute fault-injection + verify UI recovery reflection (F-4, F-5) | T-3, T-4 |
| T-8 | Execute admin rollback + confirmation UX (F-6) | T-6, HPUX-2195 |
| T-9 | Execute state-display + non-blocking + idempotency + conflict (F-7, F-8, F-10, F-12); assert fixture display | T-2, T-3 |
| T-10 | Execute disconnected migration via the console (F-9) | T-2a, T-4 |
| T-11 | Measure & record controller management gap (F-3) | T-6 |
| T-12 | Triage defects, retest, produce execution report | T-6…T-11 |

---

## 11. Environmental Needs

- **Clusters:** at least one **connected** and one **disconnected/restricted-network** OpenShift
  5.1 cluster with the Tech Preview feature gate enabled (`TechPreviewNoUpgrade` or the specific
  migration feature gate, TBD).
- **Both OLMv0 and OLMv1 present:** classic OLM (Subscription/CSV) plus Operator Controller /
  ClusterExtension APIs installed.
- **OCPSTRAT-2693 library/CLI build** installed as the dependency the console consumes.
- **ClusterCatalog(s):** matching catalogs pre-configured for all test operators; for disconnected,
  a mirrored catalog (via `oc-mirror`, assumed working per NF-9).
- **Operator fixture set:** operators covering AllNamespaces (eligible), non-AllNamespaces
  (ineligible), unresolved-dependency (ineligible), unhealthy-CSV (ineligible), missing-catalog
  (ineligible), already-migrated, and a deliberately constructed conflict — plus synthetic minimal
  operators for bulk counts (see §6.4 / Appendix B).
- **Mirror registry** for the disconnected scenario.
- **Access:** cluster-admin credentials; console access.
- **Tooling:** console e2e harness, workload-continuity monitor, `oc-mirror`.

---

## 12. Responsibilities

| Role | Responsibility |
|------|----------------|
| QE (Console) | UI workflow, state display, status/failure surfacing, confirmation flow, rollback UX; console e2e; fixture set for UI states |
| QE (Operator Framework / OLMv1) | **Dependency owner** — library/CLI correctness under OCPSTRAT-2693's own plan; supply the library/CLI build and eligibility behavior this plan depends on |
| Development (Console) | Fix console defects; provide feature-gate + console build |
| Development (OLMv1, OCPSTRAT-2693) | Provide the library/CLI build; define controller-gap bound; confirm the state semantics the UI must display |
| UX (HPUX-2193) | Deliver migration flow design (HPUX-2195) and requirements (HPUX-2194); validate F-6/F-11 UI |
| Feature owner / PM | Confirm scope (incl. status of the dropped double-confirmation criterion), sign off on TP acceptance |
| Product / Data | Provide telemetry on real customer OLMv0 operator usage to prioritize the eligible fixture set |
| Release / TRT | Integrate console e2e CI jobs into payload signal |

**Data asks (tracked under T-1):**
1. The **state semantics** the console must display (eligible / ineligible-with-reason /
   already-migrated / conflict), and any existing **fixture generator / test operator bundles**
   from the OCPSTRAT-2693 suites (reuse over reinvent).
2. Reference list of **known-eligible operators** in TP-supported catalogs.
3. Which **ClusterCatalogs** (redhat / certified / community / custom) are in TP scope.
4. **Telemetry/Insights** on customer OLMv0 usage — install-mode distribution + dependency prevalence.

---

## 13. Staffing and Training Needs

- QE familiarity with **both** OLMv0 (Subscription/CSV) and OLMv1 (ClusterExtension /
  ClusterCatalog) resource models, enough to assert end-state cluster outcomes.
- Ability to **build/host operator bundles** (synthetic fixtures) and set up disconnected
  mirrored catalogs (`oc-mirror`).
- Familiarity with the console e2e harness and the HPUX-2195 migration flow.

---

## 14. Schedule

Aligned to the 5.1 planning/refinement cycle. Milestones (to be dated during refinement):

| Milestone | Target |
|-----------|--------|
| Test plan approved | 5.1 refinement |
| Data asks resolved (T-1) | Before fixture build |
| Fixture set + cases ready (T-2, T-2a, T-3) | Before feature code-complete |
| Console E2E automation live (T-5) | Feature code-complete |
| Functional execution complete (T-6…T-11) | Before TP feature-freeze |
| Execution report + sign-off (T-12) | TP freeze |

---

## 15. Risks and Contingencies

| Risk | Impact | Mitigation / Contingency |
|------|--------|--------------------------|
| Controller management-gap duration undefined ("TBD" spike) | Can't set pass bound for F-3 | Record measured gap; agree provisional TP bound with dev; gate GA (OCPSTRAT-3281) on it |
| Disconnected catalog setup unresolved | Blocks/undermines disconnected F-9 | Pre-configure catalog manually; treat disconnected case as conditional; track the dependency to resolution |
| Sourcing realistic eligible operators is hard / catalog contents drift | Weak or unstable eligible + bulk coverage | Combine real operators with **synthetic minimal** operators; re-validate the shortlist against the live catalog at test time (Appendix B) |
| Double-confirmation criterion dropped from Jira | Ambiguous F-6 pass condition | Confirm intended UX with PM/UX via HPUX-2195 before finalizing F-6 |
| Conflict state hard to construct reliably | Weak F-10 coverage | Script deterministic creation of Subscription + annotated ClusterExtension for same package (Appendix B) |
| OCPSTRAT-2693 library/CLI dependency still changing | UI behavior churn | Track against agreed state semantics; keep cases traced to **displayed states**, not library signatures |
| A console failure is actually a library defect | Mis-attributed defects | File library defects under OCPSTRAT-2693; keep this plan's cases scoped to console-observable behavior |
| TP scope creep (managed services, deps, library internals) | Effort dilution | Enforce §5 exclusions; defer library/CLI testing to OCPSTRAT-2693 and deps/GA to OCPSTRAT-2601 / 3281 |

---

## 16. Approvals

| Name / Role | Approval | Date |
|-------------|----------|------|
| Feature owner (PM) | | |
| QE lead (Console) | | |
| Dev lead (Console) | | |
| UX lead (HPUX-2193) | | |

---

### Appendix A — Operator-state reference (dependency context from OCPSTRAT-2693)

Provided so the console's **displayed** state can be checked against a known definition. The states
themselves are owned by OCPSTRAT-2693; this plan verifies only that the **UI shows the correct one**.

| State | Condition | What the console should display |
|-------|-----------|---------------------------------|
| **Eligible** | OLMv0 Subscription present; no ClusterExtension; migratable per 2693 | Operator shown as eligible; migration offered |
| **Ineligible** | Subscription present but fails ≥1 eligibility check | Operator shown ineligible **with a specific reason**; migration not offered |
| **Already migrated** | No Subscription; annotated ClusterExtension exists for same package | Operator shown as already migrated; no re-migration offered |
| **Conflict** | Both Subscription **and** annotated ClusterExtension exist for same package | Prominent warning; auto-migration blocked |

> The detailed eligibility predicate (hard blocks / soft-ack paths) and the activation-boundary
> recovery mechanics are **OCPSTRAT-2693** concerns and are covered by its test plan. This plan cares
> only that their outcomes are correctly **surfaced in the UI** (F-4, F-5, F-7, F-10).

### Appendix B — Test data: per-state fixture recipes & discovery queries

**Discovery rule:** label every fixture from the *independent signal* column below, then assert the
**console's displayed state** equals that label.

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

**Cross-check (assertion):** open each fixture in the console and confirm the **displayed** state
equals its independently-derived label above.
