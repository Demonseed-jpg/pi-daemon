# Roadmap Phases

Full interactive roadmap: [GitHub Project](https://github.com/users/Demonseed-jpg/projects/3)

## Phase 0: Foundation
> Docs, wiki, CI/CD

- Wiki + docs folder with auto-sync GitHub Action
- CI pipeline: lint, unit tests, integration, coverage, security audit, build

## Phase 1: Skeleton (Mar 9 – Apr 6)
> Daemon, webchat, API, pi bridge

| Issue | Title |
|-------|-------|
| P1.1 | Cargo workspace + crate scaffold |
| P1.1b | CI/CD — extensive testing system via GitHub Actions |
| P1.2 | Core types crate — agents, messages, events, errors |
| P1.3 | Kernel — agent registry + event bus |
| P1.4 | Kernel — config system + GitHub PAT auth |
| P1.5 | API server — Axum HTTP routes + shared state |
| P1.6 | WebSocket streaming chat handler |
| P1.7 | Webchat UI — embedded SPA |
| P1.8 | OpenAI-compatible `/v1/chat/completions` endpoint |
| P1.9 | CLI — daemon lifecycle (start/stop/status/chat) |
| P1.10 | Pi bridge extension (TypeScript) |

**Ships:** A working daemon you can chat with from browser, terminal, and pi.

## Phase 2: Memory (Apr 7 – Apr 27)
> SQLite substrate, sessions, usage tracking

| Issue | Title |
|-------|-------|
| P2.1 | Memory substrate — SQLite WAL store |
| P2.2 | Session store + usage tracking |
| P2.3 | Memory API routes + dashboard panels |

**Ships:** Persistent sessions, token/cost tracking, usage dashboard.

## Phase 3: Scheduler + Supervisor (Apr 28 – May 18)
> Autonomous execution, health monitoring

| Issue | Title |
|-------|-------|
| P3.1 | Cron scheduler engine |
| P3.2 | Supervisor — health monitoring + auto-restart |
| P3.3 | Trigger engine + event-driven agent activation |

**Ships:** Agents that run on schedules without prompting. Dead agent detection. Event-driven automation.

## Phase 4: Hands (May 19 – Jun 15)
> Autonomous capability packages

| Issue | Title |
|-------|-------|
| P4.1 | Hands system — manifests, registry, lifecycle |
| P4.2 | Approval gates + security sandbox |
| P4.3 | Built-in Hands — Researcher, Monitor, Summarizer |

**Ships:** Three autonomous agents that work for you overnight. Approval queue in the dashboard.

## Phase 5: Wire + Channels (Jun 16 – Jul 13)
> Multi-machine networking, messaging platforms

| Issue | Title |
|-------|-------|
| P5.1 | Wire protocol — agent-to-agent P2P networking |
| P5.2 | Channel adapters — Telegram, Slack, Discord |

**Ships:** Agents talk across machines. Chat with your agents from Telegram.
