---
title: addyosmani/agent-skills 选择性吸收提案
status: accepted
owner: governance-owner
updated_at: 2026-05-12
source_path: docs/治理/策略/agent-skills-selective-absorption-proposal.md
confidence: high
---

# addyosmani/agent-skills 选择性吸收提案

## 1. 背景

本提案评估并落地对 GitHub 仓库 `addyosmani/agent-skills` 的选择性吸收。目标不是把外部技能整包安装到本地，而是在不破坏现有 RCCP 控制面、技能触发规则和证据链的前提下，提取可复用的方法增量。

本地已经具备前端交付、后端交付、安全审查、TDD、代码简化、规划、治理收口和多 Agent 验证等能力。外部仓库的主要价值不在于提供另一套顶层技能入口，而在于若干稳定的方法片段可以补强本地技能体系。

## 2. 决策结论

结论：选择性吸收，拒绝整包导入。

- 不新增 `addyosmani/agent-skills` 的顶层技能目录。
- 不新增第二套技能入口或并行控制面。
- 不引入发布、部署、CI/CD 自动化默认行为。
- 只把高价值增量落为现有技能下的参考卡和短 guardrail。
- 每个吸收点必须有目标技能、触发条件、证据路径和回滚方式。

## 3. 吸收范围

| 优先级 | 外部增量 | 本地落点 | 吸收方式 | 状态 |
| --- | --- | --- | --- | --- |
| P0 | source-first evidence | `existing-capability-delta-answer` | 新增参考卡并挂接工作流 | 已落地 |
| P0 | doubt gate | `planning-with-files` | 新增参考卡并挂接重大决策步骤 | 已落地 |
| P0 | browser evidence | `frontend-delivery` | 新增浏览器运行时证据卡 | 已落地 |
| P1 | deprecation / migration | `backend-delivery`、`backend-db-migration-guard` | 新增兼容窗口与回滚矩阵 | 已落地 |
| P1 | lightweight ADR | `docs-triplet-sync` | 新增轻量 ADR 结构 | 已落地 |

## 4. 明确拒绝项

以下外部能力不作为本轮吸收目标：

- `test-driven-development`：本地已有 `tdd-workflow`。
- `security-and-hardening`：本地已有 `security-review`。
- `code-simplification`：本地已有 `code-simplifier`。
- `frontend-ui-engineering`：本地已有 `frontend-delivery` 和 `frontend-design`。
- `using-agent-skills`：本地已有技能触发入口和 `using-superpowers` 规则。
- `ci-cd-and-automation`、`shipping-and-launch`：涉及发布与自动化边界，必须另行授权。

## 5. 落地结果

已新增并挂接以下本地参考卡：

- `C:/Users/lifeiyu/.codex/skills/existing-capability-delta-answer/references/source-first-evidence.md`
- `C:/Users/lifeiyu/.codex/skills/planning-with-files/references/doubt-gate.md`
- `C:/Users/lifeiyu/.codex/skills/frontend-delivery/references/browser-evidence.md`
- `C:/Users/lifeiyu/.codex/skills/backend-delivery/references/deprecation-migration.md`
- `C:/Users/lifeiyu/.codex/skills/docs-triplet-sync/references/lightweight-adr.md`

已挂接的现有技能包括：

- `existing-capability-delta-answer`
- `planning-with-files`
- `frontend-delivery`
- `backend-delivery`
- `backend-db-migration-guard`
- `docs-triplet-sync`

## 6. 验证结果

本轮验证结果如下：

- `external-capability-license-check`：通过。
- `action-reference-surface-check`：通过。
- `command-template-lint`：通过。
- `closeout-atomic`：已执行收口链路，控制事务、快照、快速收口、recap、task-close、sidecar 均完成。

已知降级项：

- `skills-sync` 是已退役 RCCP 动作，本轮没有恢复该旧入口，而是记录为降级同步路径。
- `rg` 在当前环境中被拒绝执行，本轮使用 PowerShell `Select-String` 完成等价文本检查。

## 7. 回滚方案

如需回滚本轮吸收，按以下顺序执行：

1. 删除 5 个新增参考卡。
2. 从对应 `SKILL.md` 中移除新增的引用行。
3. 保留 `task_plan.md`、`findings.md`、`progress.md` 中的历史记录作为审计证据。
4. 重新运行 `external-capability-license-check`、`action-reference-surface-check` 和 `command-template-lint`。

## 8. 后续规则

未来继续吸收外部方法时，必须遵循以下规则：

- 一个外部增量只对应一个本地参考卡或一个小型 guardrail。
- 优先更新现有技能，不优先创建新技能。
- 不得新增第二套控制面、第二套发布流程或第二套技能入口。
- 涉及发布、部署、CI/CD、生产验证的能力必须单独授权。
- 未通过许可证、引用面和命令模板检查前，不得宣称吸收完成。

