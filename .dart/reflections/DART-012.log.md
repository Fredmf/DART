# Reflection: DART-012

**Task:** Update DART.md activation section and role quick reference for sub-agent model.

## Changes made

1. **Activation section** rewritten. Removed "The human tells you which role to assume" and all "Be the X" triggers. Replaced with orchestrator-as-delegator language: "Work on DART-XXX" and "Work" now explicitly describe launching a sub-agent with the ticket's role.

2. **Role Quick Reference** table gained a "Runs as" column. Orchestrator is "main agent"; scout, specialist, evaluator, and reflector are all "sub-agent". Added explanatory text about isolated contexts.

3. **Removed role-switching language.** No more "assume a role" or "be the orchestrator" phrasing. The orchestrator is the default; other roles are launched, not assumed.

## Verification

- [x] Activation section describes sub-agent delegation for "Work" and "Work on DART-XXX"
- [x] Role Quick Reference table reflects sub-agent status for specialist/evaluator/reflector/scout
- [x] No language instructs users to "switch roles" or "be the specialist"

## Concerns

- The "Evaluate DART-042" trigger previously said "evaluator mode" which implied role-switching. Now it says "launches an evaluator sub-agent" which is consistent.
- The "Process seeds" trigger stays with the orchestrator (not delegated) since decomposition is orchestrator work. This is intentional.
