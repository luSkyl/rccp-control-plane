# Agent Skills Selective Absorption V2 Plan

## V0 Baseline Freeze / V0 基线冻结

- Main goal: selectively absorb high-value Agent Skills mechanisms into the existing repo-native skill system.
- Acceptance metrics: every adopted pattern has a source repository, a local target skill, and a non-regression boundary.
- Non-regression constraints: do not create a parallel control plane, duplicate top-level skills, or mirror external repositories wholesale.
- Timebox: one selective absorption cycle, prioritizing durable mechanisms over broad catalog growth.
- Out of scope: building a public skill marketplace, importing full external directory trees, or replacing existing RCCP governance flows.
- Existing capability evidence paths:
  - `findings.md` records the local absorption findings and GitHub benchmark snapshot.
  - `progress.md` records external source cloning, absorbed deltas, and degraded validation notes.
  - `docs/治理/最新态/task-recap-agent-skills-selective-absorption-latest.md` records closeout status for the task.
- Confirmed gaps: the local skill system already covers delivery, governance, verification, TDD, frontend, backend, and security review, but needed stronger source-first, doubt-first, browser-evidence, migration/deprecation, and lightweight ADR discipline.

## V1 Self-built Plan / V1 自研方案

1. Problem definition: the target is not a new skills platform; it is a small, auditable improvement to the existing RCCP skill workflow.
2. Root-cause hypotheses:
   - External benchmark claims can become loose suggestions unless tied to source-first evidence.
   - High-impact plans need adversarial review before becoming durable guidance.
   - Skill evolution can bloat unless migration and deprecation rules are explicit.
3. Self-built plan:
   - Keep the existing local skills as the main routing surface.
   - Add compact reference cards and guardrails under existing skills.
   - Reject duplicated top-level skills when an existing skill can host the mechanism.
4. Execution steps:
   - Select benchmark repositories.
   - Score each repository against task-specific criteria.
   - Extract only reusable mechanisms.
   - Map each mechanism to an existing local skill.
   - Close with local evidence and final recap paths.
5. Risk and rollback:
   - Risk: benchmark absorption expands into a new control plane.
   - Rollback: keep only reference cards and guardrails; remove any duplicated entrypoint.

## V2 Fusion Plan / 融合方案 V2

### 0. Metadata / 元信息

- Task: `agent-skills-selective-absorption`
- Status: V3-A selective absorption plan
- Date: 2026-05-12
- Benchmark basis: GitHub API metadata, repository README review, and local RCCP evidence files.

### 1. Goals and Scope / 目标与范围

- Goal: absorb the highest-value external Agent Skills practices without replacing repo-native governance.
- In scope: source-first evidence, doubt-first review, browser evidence, migration/deprecation compatibility, lightweight ADR capture.
- Out of scope: full repository import, new skill marketplace, public catalog rewrite, or duplicated delivery skills.

### 2. GitHub Benchmark Matrix / GitHub 标杆评分矩阵

Scoring formula: target fit 30, engineering depth 25, maintenance activity 15, reuse safety 15, installation friendliness 15.

| Repository | Role | Stars | Score | Adoption Decision |
|---|---:|---:|---:|---|
| [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | Production-grade engineering skills | 40,157 | 96 | Primary absorption source for workflow, gates, and validation discipline. |
| [anthropics/skills](https://github.com/anthropics/skills) | Official standard and implementation reference | 132,861 | 92 | Standard reference for skill shape, packaging, and dynamic loading model. |
| [sickn33/antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills) | Large installable skill library | 37,277 | 89 | Reference for catalog, bundle, and distribution patterns only. |
| [github/awesome-copilot](https://github.com/github/awesome-copilot) | Community resource aggregation | 32,735 | 88 | Reference for taxonomy, discoverability, and machine-readable listings. |
| [vercel-labs/skills](https://github.com/vercel-labs/skills) | Open agent skills CLI | 18,152 | 86 | Reference for install and distribution experience. |
| [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) | Official Vercel skill collection | 26,453 | 84 | Reference for standard-format skill repository organization. |
| [huggingface/skills](https://github.com/huggingface/skills) | Domain-specific AI/ML skills | 10,471 | 82 | Reference for domain-specific interoperability and Hub workflows. |
| [ComposioHQ/awesome-codex-skills](https://github.com/ComposioHQ/awesome-codex-skills) | Codex-focused curated list | 8,635 | 76 | Secondary Codex ecosystem reference; not a primary template. |

### 3. Fusion Conclusion and Tradeoffs / 融合结论

- Primary source: `addyosmani/agent-skills`.
- Standards anchor: `anthropics/skills`.
- Distribution anchor: `vercel-labs/skills`.
- Breadth references: `github/awesome-copilot` and `sickn33/antigravity-awesome-skills`.
- Domain reference: `huggingface/skills`.
- Secondary Codex reference: `ComposioHQ/awesome-codex-skills`.
- Tradeoff: prefer fewer high-confidence mechanisms over a broad skill encyclopedia.

### 4. Phased WBS / 分阶段执行步骤

1. Extract source-first evidence rules.
2. Extract doubt-first and adversarial review rules.
3. Extract browser-evidence rules for UI or runtime observations.
4. Extract migration/deprecation compatibility rules.
5. Extract lightweight ADR capture rules.
6. Map each mechanism to an existing local skill.
7. Backfill findings, progress, and closeout evidence.

### 5. Milestones and Timebox / 里程碑与时间盒

- Milestone 1: benchmark repositories selected and scored.
- Milestone 2: reusable mechanisms classified.
- Milestone 3: local reference cards and guardrails linked from existing skills.
- Milestone 4: evidence and final recap recorded.

### 6. RACI / 责任分工

| Activity | Responsible | Accountable | Consulted | Informed |
|---|---|---|---|---|
| Benchmark selection | Codex | User | GitHub source repos | Repo maintainers |
| Mechanism extraction | Codex | User | Existing local skills | Future agents |
| Local mapping | Codex | User | RCCP governance evidence | Future agents |
| Closeout evidence | Codex | User | RCCP final recap checks | Future agents |

### 7. Prerequisites / 前置依赖

- Existing local skill system remains authoritative.
- External repositories are treated as evidence sources, not install targets.
- Retired actions are not recreated unless explicitly approved.

### 8. Executable Acceptance Gates / 验收门禁

- No new parallel control plane.
- No duplicate top-level skill when an existing skill can host the mechanism.
- Every adopted rule cites a source repository and local target skill.
- Final evidence is recorded in findings, progress, and closeout outputs.

### 9. Risk and Rollback / 风险与回滚

- Risk: external benchmark absorption turns into uncontrolled catalog growth.
- Risk: copied external wording conflicts with local workflows.
- Rollback: remove the new reference card or guardrail and keep the existing local skill unchanged.
- Rollback: downgrade a benchmark from adoption source to read-only reference.

### 10. Evidence Output Paths / 证据输出路径

- `findings.md`
- `progress.md`
- `docs/治理/最新态/task-recap-agent-skills-selective-absorption-latest.md`

### 11. Open Items and Next Steps / 未决项与下一步

- Decide whether to turn this matrix into a reusable external-benchmark template.
- Decide whether future absorption rounds should require the same scoring formula.
- Keep this document updated when benchmark repositories materially change.

## V2.5 Perf Matrix and Evidence Design / V2.5 压测矩阵与证据设计

The performance target here is decision quality and evidence quality, not runtime latency.

| Dimension | Metric | Threshold | Evidence |
|---|---|---|---|
| Benchmark fit | Score for primary absorption source | At least 90 | GitHub metadata and README review |
| Standards confidence | Score for standards anchor | At least 85 | Official repository and standard-format docs |
| Reuse safety | Local mapping exists | Required | Local skill path or reference card |
| Non-regression | No duplicate entrypoint | Required | Local file diff and closeout evidence |
| Evidence traceability | Findings and progress updated | Required | `findings.md`, `progress.md` |

### Observation Metrics / 观测指标

- Number of adopted mechanisms.
- Number of rejected or downgraded repositories.
- Number of local skills touched.
- Number of evidence paths updated.

### Stop-loss Rules / 止损规则

- Stop if the plan starts creating a new platform instead of extending existing skills.
- Stop if a benchmark has no clear source repository or license signal.
- Stop if an adopted mechanism cannot map to a local skill.
- Stop if a change weakens existing closeout evidence.

### Failure Budget / 失败预算

- Zero tolerance for new parallel entrypoints.
- Zero tolerance for untraceable external claims.
- One degraded validation path is acceptable only when recorded with an alternate evidence method.

## V3 Final Convergence Plan / V3 最终收敛方案

- Current status: V3-A plan convergence.
- Confirmed hypotheses:
  - `addyosmani/agent-skills` is the strongest direct absorption source.
  - `anthropics/skills` is the strongest standards reference.
  - `vercel-labs/skills` is the strongest distribution reference.
- Rejected hypotheses:
  - A high-star repository should not automatically become the primary template.
  - A broad skill catalog should not be imported as a new RCCP control plane.
  - Codex-specific curation is useful but insufficient as the main design source.
- New findings:
  - The missing piece in the previous V2 answer was the benchmark and scoring layer, not the internal implementation direction.
  - The strongest local shape is selective reference-card absorption.
- Final adopted plan:
  - Adopt five mechanisms: source-first evidence, doubt-first review, browser evidence, migration/deprecation compatibility, and lightweight ADR capture.
  - Keep external repositories as benchmark evidence.
  - Keep the local RCCP skill system as the only execution surface.
- Explicit non-goals:
  - Do not build a marketplace.
  - Do not import full external skill trees.
  - Do not add duplicate frontend, backend, TDD, security, or governance skills.
- Perf confirmation backfill:
  - Benchmark score threshold met by the primary and anchor repositories.
  - Evidence is recorded locally for future review.
- Production backfill:
  - This document becomes the canonical V2/V3 selection record for the `agent-skills-selective-absorption` round.
