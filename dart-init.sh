#!/usr/bin/env bash
set -euo pipefail

# DART Project Initializer
# Usage: bash dart-init.sh [project-name]   — fresh init
#        bash dart-init.sh --continue       — resume (launch dashboard)
#        bash dart-init.sh --update         — update templates, keep data
# Run this in the root of your project directory.

DART_DIR=".dart"

# ─────────────────────────────────────────────
# Helper: launch dashboard (or detect if already running)
# ─────────────────────────────────────────────
start_dashboard() {
  local port="${1:-8050}"
  # Check if something is already listening on the port
  if lsof -iTCP:"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "   Dashboard: http://localhost:$port  (already running)"
  else
    python3 "$DART_DIR/dashboard.py" "$port" &
    DASH_PID=$!
    echo "   Dashboard: http://localhost:$port  (pid $DASH_PID)"
  fi
}

# ─────────────────────────────────────────────
# --continue mode: launch dashboard for existing project
# ─────────────────────────────────────────────
if [ "${1:-}" = "--continue" ] || [ "${1:-}" = "-c" ]; then
  if [ ! -d "$DART_DIR" ]; then
    echo "⚠  No .dart/ directory found. Run 'dart-init.sh [project-name]' first."
    exit 1
  fi
  if [ ! -f "$DART_DIR/dashboard.py" ]; then
    echo "⚠  .dart/dashboard.py not found. Run 'dart-init.sh --update' to generate it."
    exit 1
  fi
  PORT="${2:-8050}"
  echo "🎯 Resuming DART project"
  start_dashboard "$PORT"
  echo ""
  echo "   Ready to work. Start an AI session and say:"
  echo "   \"Read .dart/DART.md. Work.\""
  exit 0
fi

# ─────────────────────────────────────────────
# --update mode: regenerate templates, preserve data
# ─────────────────────────────────────────────
DART_UPDATE=false
if [ "${1:-}" = "--update" ] || [ "${1:-}" = "-u" ]; then
  if [ ! -d "$DART_DIR" ]; then
    echo "⚠  No .dart/ directory found. Nothing to update."
    exit 1
  fi
  DART_UPDATE=true
  echo "🔄 Updating DART templates (preserving tickets, dag, reflections, briefs)"
  echo ""
fi

# ─────────────────────────────────────────────
# Fresh init
# ─────────────────────────────────────────────
if [ "$DART_UPDATE" = false ]; then
  PROJECT_NAME="${1:-My Project}"

  if [ -d "$DART_DIR" ]; then
    echo "⚠  .dart/ already exists. Aborting to avoid overwriting."
    echo "   To update templates:  dart-init.sh --update"
    echo "   To resume work:       dart-init.sh --continue"
    echo "   For a fresh start:    rm -rf .dart/ && dart-init.sh"
    exit 1
  fi
fi

# ─────────────────────────────────────────────
# Fresh-init-only: directories, dag, lessons
# ─────────────────────────────────────────────
if [ "$DART_UPDATE" = false ]; then
  echo "🎯 Initializing DART for: $PROJECT_NAME"
  echo ""

  mkdir -p "$DART_DIR"/{roles,tickets,reflections,briefs,workspaces}

  cat > "$DART_DIR/dag.yaml" << 'YAML'
project: "PROJECT_NAME_PLACEHOLDER"
last_updated: TIMESTAMP_PLACEHOLDER
next_id: 1
nodes: {}
YAML
  sed -i.bak "s/PROJECT_NAME_PLACEHOLDER/$PROJECT_NAME/" "$DART_DIR/dag.yaml" 2>/dev/null || \
    sed -i "" "s/PROJECT_NAME_PLACEHOLDER/$PROJECT_NAME/" "$DART_DIR/dag.yaml"
  sed -i.bak "s/TIMESTAMP_PLACEHOLDER/$(date -u +%Y-%m-%dT%H:%M:%SZ)/" "$DART_DIR/dag.yaml" 2>/dev/null || \
    sed -i "" "s/TIMESTAMP_PLACEHOLDER/$(date -u +%Y-%m-%dT%H:%M:%SZ)/" "$DART_DIR/dag.yaml"
  rm -f "$DART_DIR/dag.yaml.bak"
fi

# ─────────────────────────────────────────────
# lessons.md (fresh init only — don't overwrite accumulated lessons)
# ─────────────────────────────────────────────
if [ "$DART_UPDATE" = false ]; then
cat > "$DART_DIR/reflections/lessons.md" << 'MD'
# Cross-Task Lessons

Updated by the Reflector role. Read by Orchestrator and Specialists.

(No lessons yet.)
MD
fi

# ─────────────────────────────────────────────
# Ticket template
# ─────────────────────────────────────────────
cat > "$DART_DIR/tickets/_template.yaml" << 'YAML'
id: DART-XXX
type: implementation  # seed | research | implementation | verification | refactor | integration | decision
state: seed           # seed | decomposed | ready | claimed | acting | reflecting | passed | failed | stale | blocked | archived
goal: "Describe what to achieve"

# DAG
depends_on: []
blocks: []
parent: null

# Execution
role: specialist:backend
granularity: coarse    # coarse | fine
priority: normal       # critical | high | normal | low
context_brief: null

# Verification — MANDATORY for non-seed tasks
verify:
  - "Objective, testable pass/fail condition"

# I/O
inputs: []
outputs: []

# Reflection (populated after attempts)
attempts: 0
lessons: []

# Metadata
created: null
created_by: orchestrator
claimed_by: null
YAML

# ─────────────────────────────────────────────
# Role: Orchestrator
# ─────────────────────────────────────────────
cat > "$DART_DIR/roles/orchestrator.md" << 'MD'
# Role: Orchestrator

You are the Orchestrator. You plan, delegate, monitor, and adapt.

**You must NEVER do specialist, evaluator, reflector, or scout work yourself.**
Your job is to decompose, route, delegate, and monitor. When a task needs
execution, evaluation, reflection, or research, you launch a sub-agent with a
scoped prompt. You do not read the task's inputs, you do not produce its
outputs, and you do not run its verification. You construct the delegation
prompt and hand it off.

## When You Are Called

- Human gives a new goal → create a seed ticket
- Seed ticket exists → decompose it into a task DAG
- Tasks are stuck or failed → diagnose, re-decompose, or reassign
- Human asks for status → read DAG and summarize
- Task passed → check if downstream tasks become `ready`

## Decomposition Process

1. Create a `seed` ticket in `.dart/tickets/`
2. Update `dag.yaml` with the new node
3. Break the seed into the MINIMUM number of coarse tasks:
   - Define dependencies (what must finish before what)
   - EVERY task must have testable `verify` criteria
   - Assign a `role` to each task
   - Create `research` tasks for scouts when context is needed
   - Create `decision` tasks when human input is required
4. Write all child tickets to `.dart/tickets/`
5. Update `dag.yaml` with the full graph
6. Set seed to `state: decomposed`
7. Set dependency-free children to `state: ready`

## Status Check Process

1. Read `dag.yaml` and all ticket files
2. Find `ready` but unclaimed tasks → prompt human to run them
3. Find `failed` tasks → check reflection logs, recommend action
4. Find tasks where all deps are `passed` → transition to `ready`
5. Report using this format:

```
## Project Status
**Progress:** X/Y tasks passed (Z%)
**Blocked:** [list blocked tasks and why]
**Ready to run:** [actionable tasks]
**Needs attention:** [failed or decision tasks]
```

## Re-decomposition

If a task failed 2+ times with different approaches (check `lessons`),
it's likely mis-scoped. Break it into smaller sub-tasks.

## Smart Work Routing

When the human says "work" or "just work" without specifying a ticket ID,
auto-select the next task using this deterministic logic:

1. **Resume in-progress work.** Find any ticket in `acting` or `claimed` state.
   If multiple, pick the oldest (lowest ticket number).
2. **Pick highest-priority ready ticket.** Among `state: ready` tickets, select
   by priority: `critical` > `high` > `normal` > `low`.
3. **Break ties by DAG order.** Within the same priority, pick the lowest
   ticket number (e.g., DART-003 before DART-007).

Once selected, announce the ticket ID and **delegate it to a sub-agent**
using the Sub-Agent Delegation process below. Never execute the task yourself.

If no actionable ticket exists (`acting`, `claimed`, or `ready`), report that
there is nothing to work on and show a brief status summary instead.

## Sub-Agent Delegation

When a task is selected for execution (via "work", explicit ticket ID, or
any other trigger), the orchestrator constructs a scoped prompt and launches
a sub-agent. The orchestrator does not do the work itself.

### Prompt Template

Use the following template to construct the sub-agent prompt. Include only
the fields that exist on the ticket; omit any that are absent.

```
You are a DART specialist. Read your ticket, your role file, and your inputs. Produce only the listed output.

**Ticket:** <ticket_path>
**Role file:** <role_file_path>
**Context brief:** <context_brief_path>   ← include only if the ticket has context_brief

Read those files first, then read the inputs listed in the ticket.

Your output is: <outputs from ticket>

**Summary of what to do:**
<one-paragraph plain-language summary of the ticket goal>

**Verification criteria:**
<bullet list copied from the ticket's verify field>
```

### Field Resolution

| Placeholder        | Source                                          |
|--------------------|-------------------------------------------------|
| `ticket_path`      | `.dart/tickets/DART-XXX.yaml`                   |
| `role_file_path`   | `.dart/roles/<ticket.role>.md`                   |
| `context_brief`    | `.dart/briefs/<ticket.context_brief>` if present |
| `outputs`          | `ticket.outputs`                                 |
| `inputs`           | `ticket.inputs` (the sub-agent reads these)      |

### Rules for Delegation

- The prompt must reference **only** the role file, ticket file, inputs, and
  context_brief. Do not paste project-wide context, DAG contents, or other
  tickets into the sub-agent prompt.
- The sub-agent discovers everything it needs from the ticket and its inputs.
  The orchestrator does not summarize or interpret inputs on the sub-agent's
  behalf.
- After launching, the orchestrator waits for the sub-agent to finish, then
  inspects the ticket state. If the state is `reflecting`, proceed to
  evaluation. If `blocked`, diagnose and act.

## Rules

- Prefer FEWER, COARSER tasks. Don't over-decompose upfront.
- "Works correctly" is not a valid verify criterion. Be specific.
- If unsure about a technical choice, create a `decision` task.
- Read `.dart/reflections/lessons.md` before decomposing.
- Always increment `next_id` and update `last_updated` in `dag.yaml`.
- Number tickets sequentially: DART-001, DART-002, etc.
MD

# ─────────────────────────────────────────────
# Role: Specialist
# ─────────────────────────────────────────────
cat > "$DART_DIR/roles/specialist.md" << 'MD'
# Role: Specialist

You execute a single task with focus and discipline. The ticket tells
you your domain (e.g., backend, frontend, docs, devops).

## Process

1. Read your ticket from `.dart/tickets/DART-XXX.yaml`
2. Confirm state is `ready` or `claimed`. If not, STOP and tell the human.
3. Read ONLY the `inputs` listed in the ticket.
4. If `context_brief` exists, read it from `.dart/briefs/`.
5. Check `.dart/reflections/DART-XXX.log.md` for lessons from prior attempts.
6. Set ticket state to `acting`.
7. Do the work:
   - Produce EXACTLY the outputs listed in the ticket
   - Stay within scope. Note scope-creep discoveries but don't act on them.
   - If a dependency is missing or wrong, STOP → `state: blocked` with note.
8. Set state to `reflecting`.
9. Write a summary to `.dart/reflections/DART-XXX.log.md`.

## Rules

- ONLY read files in `inputs` and `context_brief`. No exploring.
- Do NOT modify files outside your `outputs` list.
- If prior lessons exist, you MUST address them. Don't repeat mistakes.
- If something is ambiguous, `state: blocked` and ask. Don't guess.
- Use workspace at `.dart/workspaces/DART-XXX/` if it exists.

## Checklist Before Moving to Reflecting

- [ ] All `outputs` files exist and are complete
- [ ] Addressed all lessons from prior attempts
- [ ] Did not modify files outside output scope
- [ ] Documented concerns in the reflection log
MD

# ─────────────────────────────────────────────
# Role: Evaluator
# ─────────────────────────────────────────────
cat > "$DART_DIR/roles/evaluator.md" << 'MD'
# Role: Evaluator

You determine whether a task's output meets its verification criteria.
You are objective and binary: pass or fail.

## Process

1. Read the ticket at `.dart/tickets/DART-XXX.yaml`
2. Read the `verify` criteria — your ONLY success conditions
3. Read the `outputs` produced by the specialist
4. For EACH criterion:
   - Test command → run it or describe expected result
   - Behavioral check → inspect code/output for compliance
   - Measurable condition → measure it
   - Record: PASS or FAIL with one-line explanation
5. ALL pass → `state: passed`. ANY fail → `state: failed`.
6. Write evaluation to `.dart/reflections/DART-XXX.log.md`

## Evaluation Log Format

```markdown
## Evaluation — Attempt N
**Date:** YYYY-MM-DD
**Verdict:** PASSED / FAILED

### Criteria Results
1. "criterion" → PASS/FAIL — explanation
2. "criterion" → PASS/FAIL — explanation

### Notes
Observations about quality, edge cases, or fragile passes.
```

## Rules

- Be strict. "Close enough" is a FAIL.
- Do NOT evaluate against criteria not in the ticket.
- If criteria are vague or untestable → `state: blocked`, flag to orchestrator.
- If you find an issue not covered by criteria, note it but evaluate
  only against stated criteria. Recommend a new ticket for the issue.
- You judge. You don't fix. Reflector and specialist handle fixes.
MD

# ─────────────────────────────────────────────
# Role: Reflector
# ─────────────────────────────────────────────
cat > "$DART_DIR/roles/reflector.md" << 'MD'
# Role: Reflector

You analyze failures and extract lessons that make the next attempt succeed.
You are the system's learning mechanism.

## Process — Single Failed Task

1. Read the ticket at `.dart/tickets/DART-XXX.yaml`
2. Read ALL prior entries in `.dart/reflections/DART-XXX.log.md`
3. Read evaluator's failure notes and specialist's output
4. Diagnose failure type:
   - **strategy** — wrong approach
   - **execution** — buggy implementation
   - **dependency** — insufficient inputs
   - **decomposition** — task is mis-scoped
5. Write a lesson to the reflection log
6. Update the ticket's `lessons` array
7. Recommend: **retry** | **re-scope** | **re-decompose** | **escalate**

## Process — Cross-Task Synthesis (periodic)

1. Read all logs in `.dart/reflections/`
2. Find patterns: recurring mistakes, systemic blockers
3. Write to `.dart/reflections/lessons.md`

## Lesson Format (per-task)

```markdown
## Reflection — Attempt N
**Failure type:** strategy | execution | dependency | decomposition
**Root cause:** One sentence.
**Lesson:** What the next attempt should do differently.
**Recommendation:** retry | re-scope | re-decompose | escalate
**Detail:** Longer explanation if needed.
```

## Lesson Format (global, in lessons.md)

```markdown
## Lesson: [Short Title]
**Source:** DART-XXX, DART-YYY
**Pattern:** What keeps going wrong
**Guidance:** What to do about it going forward
```

## Rules

- Never blame "AI limitations." Diagnose the PROCESS.
- Be specific. "Try harder" is not a lesson.
- Same failure 3+ times across tasks = systemic issue. Flag to human.
- "Unsure — escalate to human" is a valid recommendation.
- Your job: make the NEXT attempt smarter, not explain the past.
MD

# ─────────────────────────────────────────────
# Role: Scout
# ─────────────────────────────────────────────
cat > "$DART_DIR/roles/scout.md" << 'MD'
# Role: Scout

You gather information BEFORE implementation begins.
You produce context briefs that specialists consume.

## Process

1. Read the ticket at `.dart/tickets/DART-XXX.yaml`
2. Understand what the downstream task needs to know
3. Research:
   - Read relevant project files (code, configs, docs)
   - Search the web for current best practices if needed
   - Check for existing patterns in the codebase
   - Read `.dart/reflections/lessons.md` for relevant past lessons
4. Write a context brief to `.dart/briefs/DART-XXX-brief.md`
5. Set `state: reflecting` (evaluator checks brief quality)

## Brief Format

```markdown
# Brief: DART-XXX — [Topic]

## Summary
2-3 sentence overview.

## Key Facts
- Concrete, actionable facts the specialist needs
- Current code/API/dependency state
- Versions, compatibility, constraints

## Recommended Approach
Suggested approach and why.

## Alternatives Considered
What else could work and tradeoffs.

## Risks & Unknowns
What couldn't be determined. What might go wrong.

## References
- Links, files, or sources consulted
```

## Rules

- Synthesize, don't dump raw research. Be concise.
- If the task is more complex than expected, note it for re-decomposition.
- If a library or solution already exists, say so. Don't create unnecessary work.
- Include code snippets when they clarify the approach.
- Always note what you COULDN'T find. Unknown unknowns are dangerous.
MD

# ─────────────────────────────────────────────
# DART.md — Master methodology file
# ─────────────────────────────────────────────
cat > "$DART_DIR/DART.md" << 'MD'
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
MD


# ─────────────────────────────────────────────
# DARTDash dashboard
# ─────────────────────────────────────────────
cat > "$DART_DIR/dashboard.py" << 'PYTHON'
#!/usr/bin/env python3
"""DARTDash — Single-file DART project dashboard. Zero dependencies."""

import http.server
import json
import os
import re
import glob
import sys

DART_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '.dart')
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8050


# ---------------------------------------------------------------------------
# Minimal YAML parser for .dart/ subset
# Handles: key-value, inline lists [a, b], dash lists, nested dicts, scalars
# ---------------------------------------------------------------------------

def parse_yaml(text):
    lines = text.split('\n')
    return _parse_block(lines, 0, 0)[0]


def _parse_scalar(val):
    val = val.strip()
    if val in ('null', '~', ''):
        return None
    if val == 'true':
        return True
    if val == 'false':
        return False
    if re.match(r'^-?\d+$', val):
        return int(val)
    if re.match(r'^-?\d+\.\d+$', val):
        return float(val)
    # Strip quotes
    if (val.startswith('"') and val.endswith('"')) or \
       (val.startswith("'") and val.endswith("'")):
        return val[1:-1]
    return val


def _parse_inline_list(val):
    inner = val[1:-1].strip()
    if not inner:
        return []
    return [_parse_scalar(item) for item in inner.split(',')]


def _indent_level(line):
    return len(line) - len(line.lstrip())


def _parse_block(lines, start, min_indent):
    result = {}
    i = start
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Skip blanks and comments
        if not stripped or stripped.startswith('#'):
            i += 1
            continue

        indent = _indent_level(line)
        if indent < min_indent:
            break

        # Dash list item at this level — return as list instead
        if stripped.startswith('- '):
            lst, i = _parse_dash_list(lines, i, indent)
            return lst, i

        # Key-value pair
        m = re.match(r'^(\s*)([\w_][\w_\-]*)\s*:\s*(.*)', line)
        if not m:
            i += 1
            continue

        key = m.group(2)
        val = m.group(3).strip()

        # Strip inline comment from value (but not from quoted strings)
        if val and not val.startswith('"') and not val.startswith("'") and not val.startswith('['):
            comment_match = re.match(r'^(.*?)\s+#\s.*$', val)
            if comment_match:
                val = comment_match.group(1).strip()

        if val.startswith('['):
            result[key] = _parse_inline_list(val)
            i += 1
        elif val:
            result[key] = _parse_scalar(val)
            i += 1
        else:
            # Check if next lines are indented children
            if i + 1 < len(lines):
                next_line = lines[i + 1]
                next_stripped = next_line.strip()
                if next_stripped and _indent_level(next_line) > indent:
                    child_indent = _indent_level(next_line)
                    if next_stripped.startswith('- '):
                        child, i = _parse_dash_list(lines, i + 1, child_indent)
                        result[key] = child
                    else:
                        child, i = _parse_block(lines, i + 1, child_indent)
                        result[key] = child
                else:
                    result[key] = None
                    i += 1
            else:
                result[key] = None
                i += 1

    return result, i


def _parse_dash_list(lines, start, min_indent):
    result = []
    i = start
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            i += 1
            continue
        indent = _indent_level(line)
        if indent < min_indent:
            break
        if stripped.startswith('- '):
            item = stripped[2:].strip()
            result.append(_parse_scalar(item))
            i += 1
        else:
            break
    return result, i


# ---------------------------------------------------------------------------
# Data loaders
# ---------------------------------------------------------------------------

def load_tickets():
    tickets = []
    pattern = os.path.join(DART_DIR, 'tickets', 'DART-*.yaml')
    for path in sorted(glob.glob(pattern)):
        with open(path, 'r') as f:
            ticket = parse_yaml(f.read())
            if isinstance(ticket, dict) and 'id' in ticket:
                tickets.append(ticket)
    return tickets


def load_dag():
    path = os.path.join(DART_DIR, 'dag.yaml')
    if not os.path.exists(path):
        return {}
    with open(path, 'r') as f:
        return parse_yaml(f.read())


def load_file_content(subdir, filename):
    """Load a file from .dart/briefs/ or .dart/reflections/ safely."""
    safe_name = os.path.basename(filename)
    path = os.path.join(DART_DIR, subdir, safe_name)
    if os.path.exists(path):
        with open(path, 'r') as f:
            return f.read()
    return None


def list_files(subdir):
    """List files in a .dart/ subdirectory."""
    dirpath = os.path.join(DART_DIR, subdir)
    if not os.path.isdir(dirpath):
        return []
    return [f for f in sorted(os.listdir(dirpath)) if not f.startswith('.')]


# ---------------------------------------------------------------------------
# HTML dashboard (embedded)
# ---------------------------------------------------------------------------

HTML = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>DARTDash</title>
<script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/cytoscape/3.33.1/cytoscape.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/dagre@0.8.5/dist/dagre.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/cytoscape-dagre@2.5.0/cytoscape-dagre.min.js"></script>
<style type="text/tailwindcss">
  @theme {
    --color-seed: #a78bfa;
    --color-decomposed: #818cf8;
    --color-ready: #38bdf8;
    --color-claimed: #fb923c;
    --color-acting: #facc15;
    --color-reflecting: #c084fc;
    --color-passed: #4ade80;
    --color-archived: #6b7280;
    --color-failed: #f87171;
    --color-stale: #94a3b8;
    --color-blocked: #ef4444;
  }
</style>
</head>
<body class="bg-gray-950 text-gray-100 min-h-screen">

<!-- Header -->
<header class="border-b border-gray-800 px-6 py-4 flex items-center justify-between">
  <div class="flex items-center gap-3">
    <h1 class="text-xl font-bold tracking-tight">DARTDash</h1>
    <span id="project-name" class="text-sm text-gray-500"></span>
  </div>
  <div class="flex items-center gap-4">
    <div id="stats" class="flex gap-4 text-sm"></div>
    <div class="flex items-center gap-3">
      <span id="last-refresh" class="text-xs text-gray-600"></span>
      <button onclick="refresh()" class="text-xs bg-gray-800 hover:bg-gray-700 px-3 py-1.5 rounded cursor-pointer">Refresh</button>
    </div>
  </div>
</header>

<!-- Main layout -->
<div class="flex flex-col lg:flex-row h-[calc(100vh-65px)]">

  <!-- Kanban Board -->
  <div id="board" class="flex-1 overflow-auto p-4">
    <!-- Filter Bar -->
    <div id="filter-bar" class="mb-3 flex flex-wrap gap-2 items-center">
      <input id="filter-search" type="text" placeholder="Search goals..." class="bg-gray-900 border border-gray-700 text-xs text-gray-300 px-3 py-1.5 rounded w-48 focus:outline-none focus:border-gray-500" oninput="applyFilters()">
      <select id="filter-state" class="bg-gray-900 border border-gray-700 text-xs text-gray-300 px-2 py-1.5 rounded focus:outline-none cursor-pointer" onchange="applyFilters()">
        <option value="">All states</option>
      </select>
      <select id="filter-type" class="bg-gray-900 border border-gray-700 text-xs text-gray-300 px-2 py-1.5 rounded focus:outline-none cursor-pointer" onchange="applyFilters()">
        <option value="">All types</option>
      </select>
      <select id="filter-role" class="bg-gray-900 border border-gray-700 text-xs text-gray-300 px-2 py-1.5 rounded focus:outline-none cursor-pointer" onchange="applyFilters()">
        <option value="">All roles</option>
      </select>
      <button onclick="clearFilters()" class="text-xs text-gray-500 hover:text-gray-300 cursor-pointer">Clear</button>
    </div>
    <!-- Action Panel -->
    <div id="action-panel" class="mb-4"></div>
    <div id="columns" class="flex gap-3 h-full min-w-max"></div>
  </div>

  <!-- DAG Panel -->
  <div id="dag-panel" class="lg:w-[420px] w-full border-t lg:border-t-0 lg:border-l border-gray-800 flex flex-col transition-all duration-300">
    <div class="px-4 py-3 border-b border-gray-800 text-sm font-semibold text-gray-400 flex items-center justify-between cursor-pointer select-none" onclick="toggleDAG()">
      <span>Dependency Graph</span>
      <svg id="dag-chevron" class="w-4 h-4 text-gray-500 transition-transform duration-300" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>
    </div>
    <div id="cy" class="flex-1 min-h-[300px]"></div>
  </div>

</div>

<!-- Ticket detail modal -->
<div id="modal" class="hidden fixed inset-0 bg-black/60 flex items-center justify-center z-50" onclick="if(event.target===this)this.classList.add('hidden')">
  <div class="bg-gray-900 border border-gray-700 rounded-lg max-w-lg w-full mx-4 max-h-[80vh] overflow-y-auto p-6">
    <div id="modal-content"></div>
  </div>
</div>

<script>
// DAG panel toggle
let dagCollapsed = false;
function toggleDAG() {
  dagCollapsed = !dagCollapsed;
  const panel = document.getElementById('dag-panel');
  const cy = document.getElementById('cy');
  const chevron = document.getElementById('dag-chevron');
  if (dagCollapsed) {
    panel.classList.remove('lg:w-[420px]');
    panel.classList.add('lg:w-auto');
    cy.classList.add('hidden');
    chevron.style.transform = 'rotate(0deg)';
  } else {
    panel.classList.add('lg:w-[420px]');
    panel.classList.remove('lg:w-auto');
    cy.classList.remove('hidden');
    chevron.style.transform = 'rotate(90deg)';
    if (cyInstance) cyInstance.resize();
  }
}
// Initialize chevron to open state
document.addEventListener('DOMContentLoaded', () => {
  document.getElementById('dag-chevron').style.transform = 'rotate(90deg)';
});

// State colors
const STATE_COLORS = {
  seed: {bg:'bg-seed/20', border:'border-seed/40', text:'text-seed', hex:'#a78bfa'},
  decomposed: {bg:'bg-decomposed/20', border:'border-decomposed/40', text:'text-decomposed', hex:'#818cf8'},
  ready: {bg:'bg-ready/20', border:'border-ready/40', text:'text-ready', hex:'#38bdf8'},
  claimed: {bg:'bg-claimed/20', border:'border-claimed/40', text:'text-claimed', hex:'#fb923c'},
  acting: {bg:'bg-acting/20', border:'border-acting/40', text:'text-acting', hex:'#facc15'},
  reflecting: {bg:'bg-reflecting/20', border:'border-reflecting/40', text:'text-reflecting', hex:'#c084fc'},
  passed: {bg:'bg-passed/20', border:'border-passed/40', text:'text-passed', hex:'#4ade80'},
  archived: {bg:'bg-archived/20', border:'border-archived/40', text:'text-archived', hex:'#6b7280'},
  failed: {bg:'bg-failed/20', border:'border-failed/40', text:'text-failed', hex:'#f87171'},
  stale: {bg:'bg-stale/20', border:'border-stale/40', text:'text-stale', hex:'#94a3b8'},
  blocked: {bg:'bg-blocked/20', border:'border-blocked/40', text:'text-blocked', hex:'#ef4444'},
};

// Column ordering
const STATE_ORDER = ['ready','claimed','acting','reflecting','seed','decomposed','failed','blocked','stale','passed','archived'];

let allTickets = [];
let dagData = {};
let fileIndex = { briefs: [], reflections: [] };
let cyInstance = null;
let autoReloadTimer = null;
const POLL_INTERVAL = 5000;

async function fetchData() {
  const [tickets, dag, files] = await Promise.all([
    fetch('/api/tickets').then(r => r.json()),
    fetch('/api/dag').then(r => r.json()),
    fetch('/api/files').then(r => r.json()),
  ]);
  return { tickets, dag, files };
}

function updateTimestamp() {
  const now = new Date();
  const ts = now.toLocaleTimeString();
  document.getElementById('last-refresh').textContent = `Updated ${ts}`;
}

async function refresh() {
  try {
    const { tickets, dag, files } = await fetchData();
    allTickets = tickets;
    dagData = dag;
    fileIndex = files;
    document.getElementById('project-name').textContent = dag.project || '';
    populateFilterOptions(tickets);
    renderStats(tickets);
    renderActionPanel(tickets);
    applyFilters();
    renderDAG(tickets, dag);
    updateTimestamp();
  } catch (e) {
    console.error('Refresh failed:', e);
  }
}

async function init() {
  await refresh();
  autoReloadTimer = setInterval(refresh, POLL_INTERVAL);
}

// --- Filter / Search ---

function populateFilterOptions(tickets) {
  const states = [...new Set(tickets.map(t => t.state))].sort();
  const types = [...new Set(tickets.map(t => t.type))].sort();
  const roles = [...new Set(tickets.map(t => t.claimed_by || t.role).filter(Boolean))].sort();

  updateSelect('filter-state', states);
  updateSelect('filter-type', types);
  updateSelect('filter-role', roles);
}

function updateSelect(id, options) {
  const el = document.getElementById(id);
  const current = el.value;
  const firstOpt = el.options[0].textContent;
  el.innerHTML = `<option value="">${firstOpt}</option>` + options.map(o => `<option value="${o}">${o}</option>`).join('');
  el.value = current;
}

function getFilteredTickets() {
  const search = document.getElementById('filter-search').value.toLowerCase();
  const state = document.getElementById('filter-state').value;
  const type = document.getElementById('filter-type').value;
  const role = document.getElementById('filter-role').value;

  return allTickets.filter(t => {
    if (search && !(t.goal || '').toLowerCase().includes(search) && !(t.id || '').toLowerCase().includes(search)) return false;
    if (state && t.state !== state) return false;
    if (type && t.type !== type) return false;
    if (role && (t.claimed_by || t.role) !== role) return false;
    return true;
  });
}

function applyFilters() {
  renderBoard(getFilteredTickets());
}

function clearFilters() {
  document.getElementById('filter-search').value = '';
  document.getElementById('filter-state').value = '';
  document.getElementById('filter-type').value = '';
  document.getElementById('filter-role').value = '';
  applyFilters();
}

function renderActionPanel(tickets) {
  const ready = tickets.filter(t => t.state === 'ready');
  const failed = tickets.filter(t => t.state === 'failed');
  const blocked = tickets.filter(t => t.state === 'blocked');
  const decisions = tickets.filter(t => t.type === 'decision' && t.state !== 'passed' && t.state !== 'archived');

  const sections = [];

  if (ready.length) {
    sections.push(`
      <div class="flex items-start gap-2">
        <span class="text-ready font-semibold text-xs whitespace-nowrap mt-0.5">READY</span>
        <div class="flex flex-wrap gap-1.5">
          ${ready.map(t => `<span class="text-xs bg-ready/10 border border-ready/30 text-ready px-2 py-1 rounded cursor-pointer hover:brightness-125" onclick="showDetail('${t.id}')">${t.id}: ${(t.goal||'').substring(0,50)}${(t.goal||'').length>50?'...':''}</span>`).join('')}
        </div>
      </div>
    `);
  }
  if (failed.length) {
    sections.push(`
      <div class="flex items-start gap-2">
        <span class="text-failed font-semibold text-xs whitespace-nowrap mt-0.5">FAILED</span>
        <div class="flex flex-wrap gap-1.5">
          ${failed.map(t => `<span class="text-xs bg-failed/10 border border-failed/30 text-failed px-2 py-1 rounded cursor-pointer hover:brightness-125" onclick="showDetail('${t.id}')">${t.id}: needs retry</span>`).join('')}
        </div>
      </div>
    `);
  }
  if (blocked.length) {
    sections.push(`
      <div class="flex items-start gap-2">
        <span class="text-blocked font-semibold text-xs whitespace-nowrap mt-0.5">BLOCKED</span>
        <div class="flex flex-wrap gap-1.5">
          ${blocked.map(t => `<span class="text-xs bg-blocked/10 border border-blocked/30 text-blocked px-2 py-1 rounded cursor-pointer hover:brightness-125" onclick="showDetail('${t.id}')">${t.id}: waiting</span>`).join('')}
        </div>
      </div>
    `);
  }
  if (decisions.length) {
    sections.push(`
      <div class="flex items-start gap-2">
        <span class="text-claimed font-semibold text-xs whitespace-nowrap mt-0.5">DECIDE</span>
        <div class="flex flex-wrap gap-1.5">
          ${decisions.map(t => `<span class="text-xs bg-claimed/10 border border-claimed/30 text-claimed px-2 py-1 rounded cursor-pointer hover:brightness-125" onclick="showDetail('${t.id}')">${t.id}: needs input</span>`).join('')}
        </div>
      </div>
    `);
  }

  const panel = document.getElementById('action-panel');
  if (sections.length === 0) {
    panel.innerHTML = '';
    return;
  }
  panel.innerHTML = `
    <div class="bg-gray-900/50 border border-gray-800 rounded-lg p-3 space-y-2">
      <div class="text-xs font-semibold text-gray-400 mb-1">What's Next</div>
      ${sections.join('')}
    </div>
  `;
}

function renderStats(tickets) {
  const total = tickets.filter(t => t.type !== 'seed').length;
  const passed = tickets.filter(t => t.state === 'passed' || t.state === 'archived').length;
  const ready = tickets.filter(t => t.state === 'ready').length;
  const failed = tickets.filter(t => t.state === 'failed').length;
  const blocked = tickets.filter(t => t.state === 'blocked').length;
  const pct = total ? Math.round(passed / total * 100) : 0;

  document.getElementById('stats').innerHTML = `
    <span class="text-passed font-semibold">${passed}/${total} done (${pct}%)</span>
    ${ready ? `<span class="text-ready">${ready} ready</span>` : ''}
    ${failed ? `<span class="text-failed">${failed} failed</span>` : ''}
    ${blocked ? `<span class="text-blocked">${blocked} blocked</span>` : ''}
  `;
}

function renderBoard(tickets) {
  const grouped = {};
  for (const t of tickets) {
    const s = t.state || 'seed';
    if (!grouped[s]) grouped[s] = [];
    grouped[s].push(t);
  }

  const cols = document.getElementById('columns');
  cols.innerHTML = '';

  for (const state of STATE_ORDER) {
    const items = grouped[state];
    if (!items || items.length === 0) continue;
    const sc = STATE_COLORS[state] || STATE_COLORS.seed;

    const col = document.createElement('div');
    col.className = 'flex flex-col w-64 shrink-0';
    col.innerHTML = `
      <div class="flex items-center gap-2 mb-3 px-1">
        <span class="w-2.5 h-2.5 rounded-full ${sc.bg} ${sc.border} border"></span>
        <span class="text-sm font-semibold ${sc.text} uppercase tracking-wide">${state}</span>
        <span class="text-xs text-gray-600">${items.length}</span>
      </div>
      <div class="flex flex-col gap-2 overflow-y-auto flex-1 pr-1">
        ${items.map(t => ticketCard(t, sc)).join('')}
      </div>
    `;
    cols.appendChild(col);
  }
}

function ticketCard(t, sc) {
  const goal = (t.goal || '').length > 80 ? t.goal.substring(0, 80) + '...' : (t.goal || '');
  const deps = (t.depends_on || []).length;
  const blocks = (t.blocks || []).length;
  const role = t.claimed_by || t.role || '';
  const priority = t.priority || 'normal';
  const priorityBadge = priority === 'critical' ? '<span class="text-[10px] bg-red-500/20 text-red-400 px-1.5 py-0.5 rounded">CRIT</span>'
    : priority === 'high' ? '<span class="text-[10px] bg-orange-500/20 text-orange-400 px-1.5 py-0.5 rounded">HIGH</span>'
    : '';

  return `
    <div class="${sc.bg} ${sc.border} border rounded-lg p-3 cursor-pointer hover:brightness-125 transition-all"
         onclick="showDetail('${t.id}')" id="card-${t.id}">
      <div class="flex items-center justify-between mb-1.5">
        <span class="text-xs font-mono font-bold ${sc.text}">${t.id}</span>
        <div class="flex gap-1 items-center">
          ${priorityBadge}
          <span class="text-[10px] text-gray-500 bg-gray-800 px-1.5 py-0.5 rounded">${t.type || ''}</span>
        </div>
      </div>
      <p class="text-xs text-gray-300 leading-relaxed mb-2">${goal}</p>
      <div class="flex items-center justify-between text-[10px] text-gray-500">
        <span>${role}</span>
        <div class="flex gap-2">
          ${deps ? `<span>${deps} dep${deps>1?'s':''}</span>` : ''}
          ${blocks ? `<span>blocks ${blocks}</span>` : ''}
        </div>
      </div>
    </div>
  `;
}

function escapeHtml(str) {
  return str.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

async function showDetail(id) {
  const t = allTickets.find(x => x.id === id);
  if (!t) return;
  const sc = STATE_COLORS[t.state] || STATE_COLORS.seed;

  const verify = (t.verify || []).map(v => `<li class="text-xs text-gray-400">&bull; ${v}</li>`).join('');
  const deps = (t.depends_on || []).map(d => `<span class="text-xs bg-gray-800 px-2 py-0.5 rounded cursor-pointer hover:bg-gray-700" onclick="showDetail('${d}')">${d}</span>`).join(' ');
  const blocks = (t.blocks || []).map(d => `<span class="text-xs bg-gray-800 px-2 py-0.5 rounded cursor-pointer hover:bg-gray-700" onclick="showDetail('${d}')">${d}</span>`).join(' ');
  const lessons = (t.lessons || []).map(l => `<li class="text-xs text-gray-400">&bull; ${l}</li>`).join('');

  // Find matching briefs and reflections for this ticket
  const ticketNum = id; // e.g. DART-003
  const matchingBriefs = fileIndex.briefs.filter(f => f.includes(ticketNum));
  const matchingReflections = fileIndex.reflections.filter(f => f.includes(ticketNum));

  // Also check context_brief field
  if (t.context_brief) {
    const briefName = t.context_brief.split('/').pop();
    if (!matchingBriefs.includes(briefName) && fileIndex.briefs.includes(briefName)) {
      matchingBriefs.push(briefName);
    }
  }

  let briefHtml = '';
  let reflectionHtml = '';

  // Fetch brief content
  for (const bf of matchingBriefs) {
    try {
      const resp = await fetch('/api/brief/' + encodeURIComponent(bf));
      if (resp.ok) {
        const text = await resp.text();
        briefHtml += `
          <div class="mb-3">
            <div class="text-xs text-gray-500 mb-1 flex items-center gap-2">
              <span class="font-semibold">Brief:</span> <span class="text-gray-600">${bf}</span>
            </div>
            <pre class="text-xs text-gray-400 bg-gray-950 border border-gray-800 rounded p-3 overflow-x-auto whitespace-pre-wrap max-h-48 overflow-y-auto">${escapeHtml(text)}</pre>
          </div>`;
      }
    } catch(e) {}
  }

  // Fetch reflection content
  for (const rf of matchingReflections) {
    try {
      const resp = await fetch('/api/reflection/' + encodeURIComponent(rf));
      if (resp.ok) {
        const text = await resp.text();
        reflectionHtml += `
          <div class="mb-3">
            <div class="text-xs text-gray-500 mb-1 flex items-center gap-2">
              <span class="font-semibold">Reflection:</span> <span class="text-gray-600">${rf}</span>
            </div>
            <pre class="text-xs text-gray-400 bg-gray-950 border border-gray-800 rounded p-3 overflow-x-auto whitespace-pre-wrap max-h-48 overflow-y-auto">${escapeHtml(text)}</pre>
          </div>`;
      }
    } catch(e) {}
  }

  document.getElementById('modal-content').innerHTML = `
    <div class="flex items-center justify-between mb-4">
      <div class="flex items-center gap-3">
        <span class="font-mono font-bold text-lg ${sc.text}">${t.id}</span>
        <span class="${sc.bg} ${sc.border} border text-xs px-2 py-0.5 rounded ${sc.text}">${t.state}</span>
        <span class="text-xs text-gray-500 bg-gray-800 px-2 py-0.5 rounded">${t.type}</span>
      </div>
      <button onclick="document.getElementById('modal').classList.add('hidden')" class="text-gray-500 hover:text-gray-300 cursor-pointer text-lg">&times;</button>
    </div>
    <p class="text-sm text-gray-300 mb-4 leading-relaxed">${t.goal || ''}</p>
    <div class="grid grid-cols-2 gap-3 mb-4 text-xs">
      <div><span class="text-gray-500">Role:</span> <span class="text-gray-300">${t.role || '—'}</span></div>
      <div><span class="text-gray-500">Claimed by:</span> <span class="text-gray-300">${t.claimed_by || '—'}</span></div>
      <div><span class="text-gray-500">Priority:</span> <span class="text-gray-300">${t.priority || 'normal'}</span></div>
      <div><span class="text-gray-500">Attempts:</span> <span class="text-gray-300">${t.attempts || 0}</span></div>
      <div><span class="text-gray-500">Parent:</span> <span class="text-gray-300">${t.parent || '—'}</span></div>
      <div><span class="text-gray-500">Created:</span> <span class="text-gray-300">${t.created || '—'}</span></div>
    </div>
    ${deps ? `<div class="mb-3"><span class="text-xs text-gray-500 block mb-1">Depends on:</span><div class="flex gap-1 flex-wrap">${deps}</div></div>` : ''}
    ${blocks ? `<div class="mb-3"><span class="text-xs text-gray-500 block mb-1">Blocks:</span><div class="flex gap-1 flex-wrap">${blocks}</div></div>` : ''}
    ${verify ? `<div class="mb-3"><span class="text-xs text-gray-500 block mb-1">Verify criteria:</span><ul class="space-y-1">${verify}</ul></div>` : ''}
    ${lessons ? `<div class="mb-3"><span class="text-xs text-gray-500 block mb-1">Lessons:</span><ul class="space-y-1">${lessons}</ul></div>` : ''}
    ${briefHtml}
    ${reflectionHtml}
  `;
  document.getElementById('modal').classList.remove('hidden');
}

function buildElements(tickets) {
  const elements = [];
  for (const t of tickets) {
    const sc = STATE_COLORS[t.state] || STATE_COLORS.seed;
    elements.push({
      data: { id: t.id, label: `${t.id}\n${t.state}`, color: sc.hex, state: t.state }
    });
  }
  for (const t of tickets) {
    for (const dep of (t.depends_on || [])) {
      elements.push({ data: { source: dep, target: t.id, id: `${dep}->${t.id}` } });
    }
  }
  return elements;
}

const cyStyles = [
  {
    selector: 'node',
    style: {
      'label': 'data(label)', 'text-wrap': 'wrap', 'text-valign': 'center',
      'text-halign': 'center', 'font-size': '10px', 'color': '#e5e7eb',
      'background-color': 'data(color)', 'border-width': 2, 'border-color': 'data(color)',
      'width': 90, 'height': 50, 'shape': 'roundrectangle', 'text-max-width': '80px',
    }
  },
  {
    selector: 'edge',
    style: {
      'width': 2, 'line-color': '#4b5563', 'target-arrow-color': '#4b5563',
      'target-arrow-shape': 'triangle', 'curve-style': 'bezier', 'arrow-scale': 0.8,
    }
  },
  {
    selector: 'node:active, node:selected',
    style: { 'border-width': 3, 'border-color': '#ffffff' }
  }
];

function renderDAG(tickets, dag) {
  const elements = buildElements(tickets);

  if (cyInstance) {
    // Update existing graph — update node data and re-layout only if structure changed
    const oldIds = new Set(cyInstance.nodes().map(n => n.id()));
    const newIds = new Set(tickets.map(t => t.id));
    const structureChanged = oldIds.size !== newIds.size || [...newIds].some(id => !oldIds.has(id));

    if (structureChanged) {
      cyInstance.elements().remove();
      cyInstance.add(elements);
      cyInstance.layout({ name: 'dagre', rankDir: 'TB', nodeSep: 30, rankSep: 50, padding: 20 }).run();
    } else {
      // Just update colors/labels
      for (const t of tickets) {
        const sc = STATE_COLORS[t.state] || STATE_COLORS.seed;
        const node = cyInstance.getElementById(t.id);
        if (node.length) {
          node.data('label', `${t.id}\n${t.state}`);
          node.data('color', sc.hex);
        }
      }
    }
    return;
  }

  cyInstance = cytoscape({
    container: document.getElementById('cy'),
    elements,
    style: cyStyles,
    layout: { name: 'dagre', rankDir: 'TB', nodeSep: 30, rankSep: 50, padding: 20 },
    userZoomingEnabled: true,
    userPanningEnabled: true,
    boxSelectionEnabled: false,
  });

  cyInstance.on('tap', 'node', function(evt) {
    showDetail(evt.target.id());
  });
}

init();
</script>
</body>
</html>
"""


# ---------------------------------------------------------------------------
# HTTP Server
# ---------------------------------------------------------------------------

class DARTHandler(http.server.BaseHTTPRequestHandler):

    def do_GET(self):
        if self.path == '/':
            self._respond(200, 'text/html', HTML.encode('utf-8'))
        elif self.path == '/api/tickets':
            self._respond(200, 'application/json',
                          json.dumps(load_tickets(), default=str).encode())
        elif self.path == '/api/dag':
            self._respond(200, 'application/json',
                          json.dumps(load_dag(), default=str).encode())
        elif self.path.startswith('/api/brief/'):
            name = self.path[len('/api/brief/'):]
            content = load_file_content('briefs', name)
            if content:
                self._respond(200, 'text/plain', content.encode())
            else:
                self._respond(404, 'text/plain', b'Not found')
        elif self.path.startswith('/api/reflection/'):
            name = self.path[len('/api/reflection/'):]
            content = load_file_content('reflections', name)
            if content:
                self._respond(200, 'text/plain', content.encode())
            else:
                self._respond(404, 'text/plain', b'Not found')
        elif self.path == '/api/files':
            data = {
                'briefs': list_files('briefs'),
                'reflections': list_files('reflections'),
            }
            self._respond(200, 'application/json', json.dumps(data).encode())
        else:
            self._respond(404, 'text/plain', b'Not Found')

    def _respond(self, code, content_type, body):
        self.send_response(code)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass  # Silence request logs


def main():
    server = http.server.HTTPServer(('localhost', PORT), DARTHandler)
    print(f'DARTDash running at http://localhost:{PORT}')
    print('Press Ctrl+C to stop.')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\nStopped.')
        server.server_close()


if __name__ == '__main__':
    main()

PYTHON
chmod +x "$DART_DIR/dashboard.py"

# ─────────────────────────────────────────────
# Launch dashboard
# ─────────────────────────────────────────────
PORT=8050
start_dashboard "$PORT"

# ─────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────
if [ "$DART_UPDATE" = true ]; then
  echo "✅ DART templates updated in .dart/"
  echo "   Your tickets, dag, reflections, and briefs are untouched."
else
  echo "✅ DART initialized in .dart/"
  echo ""
  echo "   Created:"
  echo "   ├── .dart/DART.md              (methodology — give this to your AI)"
  echo "   ├── .dart/dag.yaml             (empty task graph)"
  echo "   ├── .dart/dashboard.py         (DARTDash web dashboard)"
  echo "   ├── .dart/roles/"
  echo "   │   ├── orchestrator.md"
  echo "   │   ├── specialist.md"
  echo "   │   ├── evaluator.md"
  echo "   │   ├── reflector.md"
  echo "   │   └── scout.md"
  echo "   ├── .dart/tickets/"
  echo "   │   └── _template.yaml         (ticket template)"
  echo "   ├── .dart/reflections/"
  echo "   │   └── lessons.md             (empty lessons log)"
  echo "   ├── .dart/briefs/"
  echo "   └── .dart/workspaces/"
  echo ""
  echo "   Next step:"
  echo "   Start an AI session and say:"
  echo "   \"Read .dart/DART.md. You are the orchestrator."
  echo "    My goal is: [your goal here]\""
fi
echo ""
