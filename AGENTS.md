# AGENTS.md — Batik

Repository-wide instructions for human contributors and AI coding agents.

## Read before coding
- [Product vision and engineering guardrails](docs/ECOSYSTEM_VISION_AND_ENGINEERING_GUARDRAILS.md).
- README, architecture docs, relevant ADRs, dependency manifests, tests and current CI results.

## Required behavior
- Protect Batik's independent product identity and public contracts.
- Keep Farabi-specific workflows in Farabi integrations, never in Batik's core.
- Maintain explicit extension points, schema validation, compatibility and migration guidance.
- Enforce authorization and tenant boundaries at trusted server-side boundaries where applicable; validate all untrusted agent input.
- Favor complete, tested product capabilities over isolated adapters or stubs.
- Inspect branch existence and failing CI before editing.
- Do not claim tests passed without observing results.
- Prefer comprehensive batches and **do not open PRs without user approval**.
- Report commit SHA, validation evidence, known limitations and next user-visible milestone.

## Before calling work complete
Check functionality, negative/security tests, documentation, compatibility, and CI. Distinguish partial scaffolding from verified integrations.

See the linked guardrails for mission, boundaries and ecosystem interoperability.
