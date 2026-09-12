---
name: codex-queue
description: Coordinates Claude Code and Codex through explicit Codex queue messages and verifiable replies. Use only when the user explicitly invokes codex-queue.
disable-model-invocation: true
---

# Codex Queue

Manual invocation only: `/codex-queue` in Claude Code; `$codex-queue` in Codex. Scope is Claude Code and Codex, without Hermes integration or background relay services.

## Choose the transport

`codex queue` sends input to an **existing Codex session**, whether the sender is a person, Claude Code, or another Codex session. A Claude session ID is not a valid Codex queue destination. Queue acceptance is not evidence that the recipient read the message or completed the task, and replies do not automatically return to the sender.

Before sending, establish the target machine, Codex profile/home or remote endpoint, exact session UUID (preferred) or exact session name, and requested action. Session names alone do not identify a machine. Do not guess a destination or use `--last` in multi-session coordination.

On the target machine, check `codex queue --help`: it must actually show `--thread` and `--message`. Some older versions show generic help instead. If unsupported, report that fact and use an agreed alternative; do not silently upgrade the CLI.

## Send and inspect

```bash
codex queue --thread 'TARGET_CODEX_UUID' --message 'REQUEST_TEXT'
```

Use `codex agents` or `codex resume --all` for human session selection when available. A human can inspect and continue the target conversation with:

```bash
codex resume 'TARGET_CODEX_UUID'
```

`resume` opens an interactive session; it is not a read-only log query. An agent should use the agreed result file below for unattended inspection. Do not start a second interactive owner merely to poll results. Do not assume queue wakes a stopped session, interrupts an active turn, or starts processing immediately: verify the installed version's behavior or report delivery as pending.

Use argument arrays for arbitrary message text. If using a shell, quote properly; JSON serialization is not shell escaping. For multiline text, Python `subprocess.run(['codex', 'queue', '--thread', thread_id, '--message', message], check=True)` avoids command substitution. Never insert untrusted text into an SSH command string.

## Claude Code → Codex → Claude Code

Agree on an absolute, writable result path accessible to both agents. Prefer a unique request directory in an existing shared scratch location, outside tracked source and outside the human-owned inbox. If machines differ, explicitly arrange SSH/SCP access or another existing shared path; identical path strings do not imply shared storage.

Include this contract in the message, replacing every placeholder:

```text
Request ID: <unique-id>
From: Claude Code, <machine>, <session identifier if known>
Task: <concrete action and scope>
Reply file: <absolute path>/result.md
Reply contract: Write the request ID, status (completed or blocked), outcome,
changed files, validation, and remaining blocker. Publish the final file by
writing a sibling temporary file and renaming it. Also summarize in this
Codex conversation. Do not send a queue message to the Claude session ID.
```

The sender reads the final file and matches its request ID. No file means pending or unknown, not failure or completion. If waiting is requested, use bounded checks and keep the user informed; on timeout report pending with the target and result path. Do not resend automatically after an ambiguous network error: inspect for acceptance/results first to avoid duplicate work. Do not create a permanent polling daemon.

## Codex → Codex reply

Include a verified return Codex UUID and its machine/endpoint in the request. The recipient may send one terminal reply using `codex queue` when this reply was authorized as part of the request. Carry the same request ID and a completed/blocked status. A shared result file is also useful for durable inspection.

Never queue to yourself, invent a return UUID, or acknowledge acknowledgments indefinitely. For cross-machine replies, execute against the return session's actual host/endpoint, not the recipient's local store.

## Codex → Claude Code, or a direct answer instead of queueing

Codex queue cannot address Claude Code. For a new, explicitly requested Claude invocation with a directly returned answer, use `claude -p 'TASK' --output-format json`; read the result and session ID from its output. For an existing stopped Claude conversation, check `claude --help` and use `claude -p --resume 'CLAUDE_SESSION_ID' 'TASK' --output-format json`. Do not resume a conversation concurrently with its active owner.

For a stopped Codex session when execution with captured output is wanted, check `codex exec resume --help`, then use `codex exec resume 'CODEX_UUID' 'TASK' --json -o 'ABSOLUTE_RESULT_FILE'`. This runs a new turn; it does not merely retrieve an earlier answer. Do not submit the same task with both queue and exec resume.

Preserve user-selected models, permissions and task scope. Do not add permission-bypass flags. Sending messages or starting another agent requires the user's authorization for that collaboration; invoking this skill to ask how it works does not authorize sending a test message.

## Report

State the request ID, destination, observed send result, where the answer will appear, and whether completion was verified. Keep sent, pending, completed and blocked distinct.
