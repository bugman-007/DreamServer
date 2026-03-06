# Platform Truth Table

Use this file as the canonical source for launch claims.

Last updated: 2026-03-05

| Platform path | Claim | Current level | Target | Evidence required before promoting |
|---|---|---|---|---|
| Linux (native) | First-class installer/runtime path | Tier A/B (by GPU path) | — | `install-core.sh` real run on target hardware + smoke/integration + doctor report |
| Linux AMD unified (Strix) | Preferred AMD path | Tier A | — | Real install + runtime benchmarks + doctor/preflight clean |
| Linux NVIDIA | CUDA/llama-server path | Tier B | — | Real install + model load + runtime/throughput checks |
| Windows (Docker Desktop + WSL2) | Standalone installer with full runtime | Tier B | — | `.\install.ps1` real run + GPU detection + Docker compose up + health checks pass |
| macOS Apple Silicon | Preflight diagnostics only (no runtime) | Tier C | Mid-March 2026 | `installers/macos.sh` run + preflight/doctor pass + full runtime parity |

## Release language guardrails

- Safe to claim now:
  - Linux support (AMD Strix Halo + NVIDIA).
  - Windows support (Docker Desktop + WSL2, NVIDIA/AMD GPU auto-detection).
  - macOS **coming soon** with preflight diagnostics available now.
- Not safe to claim now:
  - macOS **support** (implies a working runtime, which does not exist yet).
  - Full macOS runtime parity with Linux.
