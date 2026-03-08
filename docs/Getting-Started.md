# Getting Started

## Prerequisites

- Rust 1.75+ (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)
- Git

## Installation

### From Source (recommended during development)

```bash
git clone https://github.com/demonseed-jpg/pi-daemon.git
cd pi-daemon
cargo build --release
# Binary at target/release/pi-daemon
```

### From Release Binary (once releases are available)

```bash
curl -fsSL https://github.com/demonseed-jpg/pi-daemon/releases/latest/download/install.sh | sh
```

## First Run

```bash
# Start the daemon
pi-daemon start --foreground

# In another terminal:
pi-daemon status
# pi-daemon v0.1.0
#   PID:      12345
#   Address:  http://127.0.0.1:4200
#   Uptime:   5s
#   Agents:   0
```

On first run, pi-daemon creates `~/.pi-daemon/config.toml` with defaults.

## Open the Dashboard

Navigate to **http://localhost:4200** in your browser. You'll see the webchat UI with:
- Chat page — talk to agents
- Agents page — see connected agents
- Overview — system status
- Settings — configuration

## Connect Pi

Install the bridge extension to connect pi to the daemon:

```bash
pi install @demonseed-jpg/pi-daemon-bridge
```

Now when you start pi, it automatically registers with the daemon. You'll see it appear in the dashboard.

## Terminal Chat

```bash
pi-daemon chat
# pi-daemon chat (connected to 127.0.0.1:4200)
# Type a message and press Enter. Ctrl+C to quit.
#
# > Hello!
# 🤔 Echo: Hello!
```

## Next Steps

- [[Configuration]] — Set up API keys, GitHub PAT, customize settings
- [[API-Reference]] — Integrate with scripts and tools
- [[Architecture]] — Understand the system design
