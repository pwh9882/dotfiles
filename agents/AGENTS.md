# LLM-WIKI — durable shared memory

A personal LLM wiki (OKF-style Markdown bundle) is the durable memory shared across machines, sessions, and agents. Prefer it over ad-hoc recall for anything infra- or project-related.

- Machine identity: before the first machine-, infra-, or project-related action in a session, run `llm-instance` once. Treat its one-line result as authoritative. Never infer the current machine from the username, home path, working directory, prior conversation, or remembered context. If it fails, stop machine-specific changes and repair `~/.config/llm-wiki/instance-id`. Read only `instances/<instance_id>.md` when machine-specific context is needed.
- macOS canonical path: `~/Documents/Obsidian Vault/LLM-WIKI` (convenience symlink `~/llm-wiki`). Other machines resolve it via the `llm-wiki-git` wrapper or their `instances/` document.
- Entry points: `index.md` (map), `AGENTS.md` (editing rules — read before writing), `state/current.md` (what is true now).
- Consult it before machine, infra, or project work: machine paths and roles are in `instances/`, procedures in `runbooks/`, project state and logs in `projects/<name>/`, past decisions in `decisions/`.
- Update it when durable knowledge changes (infra change, project milestone, decision). Commit with `llm-wiki-git` / `llm-wiki-commit`; message prefix = current instance id (see `instances/`).
- The parent Obsidian vault has two sibling layers: `sources/` (raw source files: papers, PDFs — reference material, not knowledge) and `human-inbox/` (human-owned working area — write there only where the user asks). The wiki links to both by pointer only.
