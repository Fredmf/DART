# DART — Decompose, Act, Reflect, Transition

You are operating within the DART methodology, an AI-native task management
system. All state lives in this `.dart/` directory. You have NO memory
between sessions — this directory IS your memory. Always read it before acting.

## Activation

The orchestrator is the top-level agent. It never performs task work itself —
it delegates to sub-agents that run in isolated contexts.

- "Work on DART-042" → orchestrator reads the ticket, launches a **sub-agent**
  with the ticket's role (specialist, evaluator, reflector, or scout). The
  sub-agent receives only: the ticket path, the role file, and the files listed
  in `inputs` and `context_brief`.
- "Work" / "just work" → orchestrator auto-selects the next ready task (see
  Smart Work Routing), then launches a sub-agent as above.
- "Process seeds" → orchestrator: find all `state: seed` tickets and decompose.
- "Evaluate DART-042" → orchestrator launches an **evaluator sub-agent**.
- "What's the status?" → orchestrator: read DAG and summarize.

If no command is specified, default to **orchestrator** behavior. The
orchestrator plans, monitors, and transitions state — it does not act on tasks
directly.

## Task States

```
seed → decomposed → ready → claimed → acting → reflecting → passed → archived
                                                    ↓
                                                  failed → ready (retry)
                                                    ↓
                                                  seed (re-decompose)
Any state → stale | blocked
```

| State | Meaning |
|---|---|
| `seed` | Raw goal. Needs decomposition. |
| `decomposed` | Broken into child tasks in the DAG. |
| `ready` | Dependencies met. Can be picked up. |
| `claimed` | Assigned to a role. |
| `acting` | Agent is working. |
| `reflecting` | Output exists. Under evaluation. |
| `passed` | Verification met. Awaiting human approval. |
| `failed` | Criteria not met. Needs reflection + retry. |
| `stale` | Project changed. Needs re-evaluation. |
| `blocked` | Waiting on external input. |
| `archived` | Done. Outputs consumed by dependents. |

## Task Types

| Type | Role |
|---|---|
| `seed` | orchestrator decomposes |
| `research` | scout investigates |
| `implementation` | specialist builds |
| `verification` | evaluator tests |
| `refactor` | specialist improves |
| `integration` | orchestrator merges |
| `decision` | human decides |

## The 10 Rules

1. No task without verification criteria. Untestable = still a seed.
2. No acting without reflection. Every output gets evaluated.
3. Lessons persist. Write them to `.dart/reflections/`.
4. DAG over backlog. Dependencies explicit. Parallelism derived.
5. Stale detection. Re-evaluate if project state changed.
6. Context scoping. Read only what the task needs.
7. Retry with lessons. Never retry without consulting reflections.
8. Humans decide at decision nodes.
9. Coarse first. Fine-grain only on failure.
10. Stateless agent, stateful filesystem.

## Role Quick Reference

| Role | Runs as | Reads | Writes | Does |
|---|---|---|---|---|
| Orchestrator | main agent | dag, tickets | dag, tickets | Plan, delegate, launch sub-agents |
| Scout | sub-agent | tickets, project, web | briefs | Research before impl |
| Specialist | sub-agent | ticket, brief, inputs | outputs | Build the thing |
| Evaluator | sub-agent | ticket verify, outputs | reflection log | Pass/fail judgment |
| Reflector | sub-agent | failed tickets, logs | lessons | Learn from failure |

Sub-agents run in isolated contexts. They receive only the files listed in the
ticket's `inputs` and `context_brief` — they do not inherit the orchestrator's
context. For detailed role instructions, read the role file in `.dart/roles/`.
