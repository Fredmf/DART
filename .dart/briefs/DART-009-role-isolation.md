# Research Brief: Making DART Role Isolation Practical

**Ticket:** DART-009  
**Problem:** DART defines five roles (orchestrator, specialist, evaluator, reflector, scout) and assumes each runs in a fresh, isolated context. In practice, one AI agent plays all roles in a single session. The result: context scoping (Rule 6) is ignored, evaluation lacks objectivity (you judge your own work), and the specialist reads everything instead of just its inputs.

**Observation from DART-001 through DART-007:** The three tasks that ran as sub-agents (DART-002, DART-004, DART-006) genuinely had fresh contexts. But the orchestrator hand-wrote their instructions instead of letting the agent discover its role from the ticket. The methodology's file-based role system was bypassed entirely.

---

## Approach A: Sub-Agent Enforcement ("Hard Isolation")

**How it works:** When "work" triggers a task, the orchestrator launches a sub-agent (Claude Code Agent tool, Cursor background agent, etc.) with a constrained prompt:

```
Read .dart/tickets/DART-XXX.yaml. 
Read the role file specified in the ticket.
Read ONLY the files listed in inputs and context_brief.
Produce ONLY the files listed in outputs.
```

The orchestrator never does the work itself — it only plans, monitors, and transitions state. The specialist, evaluator, and reflector are always separate agents.

**Pros:**
- True context isolation — the specialist literally cannot see the full project
- Evaluator gets genuine fresh eyes on the output
- Matches the original DART design intent exactly
- Scales to multi-agent frameworks (Claude Code agents, CrewAI, etc.)

**Cons:**
- Requires a runtime that supports sub-agents (Claude Code does, but ChatGPT/Ollama don't)
- Slower — each agent launch has overhead (context loading, tool init)
- The orchestrator still needs to understand enough to write good tickets — garbage in, garbage out
- Debugging is harder when work happens in opaque sub-processes

**Implementation complexity:** Medium. Needs changes to orchestrator.md (launch agents instead of switching roles) and possibly a wrapper script. No changes to the ticket format.

---

## Approach B: Checklist-Based Roles ("Soft Isolation")

**How it works:** Accept that one agent will play all roles. Redesign roles not as context boundaries but as **behavioral checklists** that force the agent to slow down and follow a protocol, even with full context.

Key changes:
- **Specialist:** Before acting, the agent must explicitly list what files it will read and write (from the ticket's inputs/outputs). It writes this to the reflection log as a "scope declaration." Any file touched outside this list is flagged.
- **Evaluator:** After completing work, the agent must run through verify criteria one by one, recording PASS/FAIL with evidence. It must do this as a separate step, not inline while coding.
- **Reflector:** On failure, the agent must write the reflection log before retrying. No immediate retry allowed.

The roles become phases of execution, not separate contexts.

**Pros:**
- Works with any AI tool — no sub-agent support needed
- Zero infrastructure changes — purely methodology
- Actually achievable today, right now
- The checklist discipline still catches errors (forcing a verification pass after coding genuinely helps)

**Cons:**
- No real isolation — the agent still has full context and will be biased toward "PASS" on its own work
- Relies on the AI being disciplined enough to follow the protocol (it won't always)
- Doesn't solve the "fresh eyes" problem — the evaluator knows the implementation intent
- Weaker guarantee than hard isolation

**Implementation complexity:** Low. Only changes to role .md files and DART.md. No tooling changes.

---

## Approach C: Hybrid ("Isolate What Matters")

**How it works:** Not all roles benefit equally from isolation. Research shows the highest-value isolation is on the **evaluator** — judging your own work is the most dangerous bias. The specialist benefits less, since it needs context to do good work anyway.

Design:
- **Orchestrator + Specialist + Reflector** stay in the main session (soft isolation via checklists)
- **Evaluator** is always launched as a sub-agent with only: the ticket, the verify criteria, and the outputs. It never sees the implementation process, only the result.
- **Scout** is launched as a sub-agent when research is needed (prevents the main agent from going down rabbit holes)

This mirrors how human teams work: the developer and PM talk constantly, but QA gets a clean build to test.

**Pros:**
- Isolates the role where bias matters most (evaluation)
- Keeps the fast inner loop (orchestrator ↔ specialist) in one context
- Practical today in Claude Code (Agent tool for evaluator)
- Preserves most of DART's intent with minimal overhead

**Cons:**
- Still requires sub-agent support for evaluator (not universal)
- The specialist still has full context (Rule 6 partially violated)
- More complex to document — two modes of operation

**Implementation complexity:** Medium-low. Orchestrator.md gets a "launch evaluator as sub-agent" protocol. Specialist keeps the checklist approach. Evaluator.md stays as-is (it's already designed for isolation).

---

## Approach D: File-Gated Context ("Tooling Enforced")

**How it works:** Add a thin wrapper (shell script or Python) that a role invocation passes through. The wrapper:
1. Reads the ticket
2. Copies only the `inputs` files into a temporary workspace
3. Launches the AI session with only those files visible
4. On completion, copies `outputs` back

This is infrastructure-level enforcement — the agent physically cannot read files outside its scope.

**Pros:**
- Hardest guarantee — isolation is enforced, not requested
- Works with any AI that can read files (universal)
- The ticket format already has inputs/outputs — no schema changes

**Cons:**
- Significant tooling effort — needs a launcher script, temp workspaces, file copying
- Fragile — what if the agent needs a file not listed in inputs? It blocks instead of adapting
- Doesn't work well for tasks that touch many files
- Over-engineered for most projects

**Implementation complexity:** High. Needs a new `dart-work.sh` wrapper, temp directory management, and careful handling of edge cases.

---

## Recommendation

**Approach C (Hybrid)** offers the best value-to-effort ratio. It isolates the evaluator (where bias matters most), keeps the fast orchestrator-specialist loop, and is implementable today in Claude Code. Approach B (checklists) should be adopted regardless as a baseline — it's free and helps even without sub-agents.

Approach A is the "correct" long-term answer but creates friction. Approach D is over-engineered for a methodology that values simplicity.

The suggested implementation order: **B first (checklists in all roles), then C (isolated evaluator) on top.**
