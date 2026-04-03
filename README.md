# DART — Decompose, Act, Reflect, Transition

An AI-native task management methodology. Not Scrum. Not Kanban. Built for how AI agents actually work.

DART replaces human project management with a system designed around stateless execution, DAG-based task decomposition, self-evaluation loops, and role-specialized agents — all backed by plain files on your filesystem.

## Why DART?

Human methodologies assume linear time, single-threaded attention, and social accountability. AI agents are different:

- **Stateless** — no memory between sessions
- **Parallelizable** — can fork into multiple instances
- **Context-bound** — degraded by window overflow, not fatigue
- **Verifiable** — needs objective pass/fail, not subjective "done"

DART works *with* these properties instead of fighting them.

## Quick Start

### Install

```bash
# Download and run the setup script — no chmod needed
curl -LO https://github.com/Fredmf/DART/releases/download/0.0.2/dart-init.sh
bash dart-init.sh "My Project"
```

Or clone the repo and run it directly:

```bash
git clone https://github.com/Fredmf/DART.git
bash DART/dart-init.sh "My Project"
```

This creates the full `.dart/` directory inside your current working directory and auto-launches the **DARTDash** web dashboard (default: `http://localhost:8050`):

```
.dart/
├── DART.md              ← Methodology guide (give this to your AI)
├── dag.yaml             ← Task dependency graph
├── roles/
│   ├── orchestrator.md  ← Plans and delegates
│   ├── specialist.md    ← Executes tasks
│   ├── evaluator.md     ← Pass/fail judgment
│   ├── reflector.md     ← Learns from failure
│   └── scout.md         ← Researches before implementation
├── tickets/
│   └── _template.yaml   ← Ticket format reference
├── reflections/
│   └── lessons.md       ← Cross-task accumulated lessons
├── briefs/              ← Scout research output
├── workspaces/          ← Isolated per-task working dirs
└── dashboard.py         ← DARTDash web dashboard
```

### Resume an Existing Project

If `.dart/` already exists, use `--continue` (or `-c`) to relaunch the dashboard and pick up where you left off:

```bash
bash dart-init.sh --continue
```

### Start Your First Session

Open any AI assistant (Claude, ChatGPT, local models — anything that can read files). The dashboard is already running at `http://localhost:8050` — use it to track progress. Then say:

```
Read .dart/DART.md. You are the orchestrator.
My goal is: Build a REST API with authentication and rate limiting.
Decompose this into tasks.
```

The AI will create ticket files in `.dart/tickets/`, build a dependency graph in `dag.yaml`, and tell you what's ready to execute.

### Run Tasks

The orchestrator delegates all work to sub-agents in isolated contexts. You don't switch roles — just tell it to work:

```
Work on DART-003.
```

Or let it auto-select the next ready task:

```
Work.
```

The orchestrator will launch a specialist, evaluator, or scout sub-agent with only the files that task needs. When the work is done, it automatically launches an evaluator sub-agent to verify the output. If it fails, a reflector sub-agent analyzes the failure before retrying.

### Check Progress

```
You are the orchestrator. What's the project status?
```

## How It Works

### The Core Loop

```
DECOMPOSE → ACT → REFLECT → TRANSITION
    ↑                            |
    └────────────────────────────┘
```

1. **Decompose** — The orchestrator breaks goals into a task DAG (directed acyclic graph). Independent branches run in parallel. Dependencies run sequentially.
2. **Act** — A role-specialized agent picks up a task and executes it in an isolated workspace.
3. **Reflect** — The output is evaluated against objective verification criteria. Pass or fail — no ambiguity.
4. **Transition** — Based on results, tasks move through states. Failures trigger reflection and retry with accumulated lessons. The DAG updates dynamically.

### Task States

```
seed → decomposed → ready → claimed → acting → reflecting → passed → archived
                                                    ↓
                                                  failed → ready (retry with lessons)
                                                    ↓
                                                  seed (re-decompose if stuck)
```

Additional states: `stale` (project context changed), `blocked` (waiting on external input).

### Roles

| Role | What It Does |
|---|---|
| **Orchestrator** | Decomposes goals, assigns tasks, monitors the DAG, unblocks stalls |
| **Specialist** | Executes a single task with scoped context (parameterized by domain) |
| **Evaluator** | Tests outputs against verification criteria — binary pass/fail |
| **Reflector** | Analyzes failures, writes lessons, recommends retry strategy |
| **Scout** | Researches context before implementation, produces briefs |

Each role is defined by a system prompt in `.dart/roles/`. The AI reads the role file and follows its instructions.

### Ticket Format

Tickets are YAML files with explicit dependencies, verification criteria, inputs/outputs, and a reflection history:

```yaml
id: DART-003
type: implementation
state: ready
goal: "Implement rate limiting middleware"

depends_on: [DART-001]
blocks: [DART-005]
role: specialist:backend

verify:
  - "Tests in tests/rate_limit_test.py pass"
  - "Returns 429 after 100 requests/minute"

inputs: ["src/api/auth.py"]
outputs: ["src/middleware/rate_limit.py"]

attempts: 0
lessons: []
```

### The 10 Rules

1. No task without verification criteria
2. No acting without reflection
3. Lessons persist across sessions
4. DAG over backlog — dependencies are explicit
5. Stale detection — re-evaluate if project state changed
6. Context scoping — agents read only what the task needs
7. Retry with lessons, never brute force
8. Humans decide at decision nodes
9. Coarse decomposition first, fine-grain on failure
10. Stateless agents, stateful filesystem

## Your Role as a Human

You do three things:

- **Seed goals** — describe what you want built
- **Review outputs** — approve work that passed verification
- **Make decisions** — answer architectural questions when the AI can't decide

You don't assign tasks, estimate story points, or move cards between columns.

## Tips

- **New sessions:** Always start with "Read .dart/DART.md" so the AI knows the methodology.
- **Long projects:** Begin each session with "Read all files in .dart/ and tell me the current status."
- **Combine roles:** "Evaluate DART-003, and if it passes, start DART-004 as a specialist."
- **Claude Projects / Cursor rules:** Drop `DART.md` into your project-level context so it loads automatically.
- **Git-friendly:** The entire `.dart/` directory is plain text. Commit it alongside your code.

## Compatibility

DART works with any AI that can read and write files:

- Claude (Projects, Code, API)
- ChatGPT (with file access)
- Local models (LM Studio, Ollama, etc.)
- Cursor, Windsurf, Cline, Aider
- Any agent framework (LangChain, CrewAI, AutoGen)

No vendor lock-in. It's just folders, YAML, and markdown.

## Background

DART was designed by synthesizing patterns from AI agent research:

- **DAG-based decomposition** from workflow orchestration (Airflow, Argo) and agentic AI research
- **Reflection loops** from the Reflexion and ReAct frameworks
- **Stateless-but-iterative execution** from the Ralph Loop pattern
- **Role specialization** from multi-agent orchestration (CrewAI, AutoGen, OpenAI Agents SDK)
- **Filesystem-as-memory** from tools like Vibe Kanban

It is not an existing standard — it was designed from scratch to be AI-native.

## License

MIT

## Contributing

This is v0.0.2. The methodology will evolve as people use it and discover what works. Open issues for suggestions, sharp edges, or things that don't survive contact with real projects.
