# Agent rules for this project

Read docs/ARCHITECTURE.md before the first task in any session; refer back to it instead of
re-explaining architecture in chat.

- Follow the 4-layer structure: presentation → state (Riverpod) → domain → data (repositories/SQL).
  Screens never contain SQL. Only repositories run SQL.
- Feature-first folders under lib/features/<feature>/{data,domain,presentation}.
- Use flutter_riverpod (no code generation / no riverpod_generator).
- Use go_router for navigation.
- All DB times: integer epoch milliseconds UTC. All weights stored in kilograms.
- Add packages with `flutter pub add <name>` (never hand-type a version).
- After any code change: run `flutter analyze` and fix all errors before saying you're done.
- Keep changes scoped to the current phase only. Don't build ahead of what was asked.
- If a manual step is needed from the user (install, permission, decision, asset file), end your
  reply with a "MANUAL TODO" section describing exactly what to do and why.
- Prefer editing existing files over creating new abstractions. Keep it simple — this is a fast MVP,
  not an enterprise app.