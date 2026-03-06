# Dream Server Support Matrix

Last updated: 2026-03-05

## What Works Today

**Linux and Windows are fully supported.** macOS support is coming soon — the macOS installer currently provides system diagnostics and preflight checks only.

| Platform | Status | What you get today |
|----------|--------|-------------------|
| **Linux + AMD Strix Halo (ROCm)** | **Fully supported** | Complete install and runtime. Primary development platform. |
| **Linux + NVIDIA (CUDA)** | **Supported** | Complete install and runtime. Broader distro test matrix still expanding. |
| **Windows (Docker Desktop + WSL2)** | **Supported** | Complete install and runtime via `.\install.ps1`. GPU auto-detection (NVIDIA/AMD). |
| **macOS (Apple Silicon)** | **Coming soon** (target: mid-March 2026) | Preflight diagnostics and system readiness checks only. No runtime. |

## Support Tiers

- `Tier A` — fully supported and actively tested in this repo
- `Tier B` — partially supported (works in some paths, gaps remain)
- `Tier C` — experimental or planned (installer diagnostics only, no runtime)

## Platform Matrix (detailed)

| Platform | GPU Path | Tier | Status |
|---|---|---|---|
| Linux (Ubuntu/Debian family) | NVIDIA (llama-server/CUDA) | Tier B | Installer path exists in `install-core.sh`; broader distro test matrix still pending |
| Linux (Strix Halo / AMD unified memory) | AMD (llama-server/ROCm) | Tier A | Primary path via `docker-compose.base.yml` + `docker-compose.amd.yml` |
| Windows (Docker Desktop + WSL2) | NVIDIA/AMD via Docker Desktop | Tier B | Standalone installer (`.\install.ps1`) with GPU auto-detection, Docker orchestration, health checks, and desktop shortcuts |
| macOS (Apple Silicon) | Metal/MLX-style local backend | Tier C | `installers/macos.sh` runs preflight + doctor with actionable reports; full runtime under development |

## Current Truth

- **Linux and Windows are fully supported.**
- Linux + NVIDIA is supported but needs broader validation and CI matrix coverage.
- Windows installs via `.\install.ps1` with Docker Desktop + WSL2 backend.
- macOS installer runs preflight diagnostics only — it **will not produce a running AI stack**.
- macOS full runtime support is targeted for mid-March 2026.
- Version baselines for triage are in `docs/KNOWN-GOOD-VERSIONS.md`.

## Roadmap

| Target | Milestone |
|--------|-----------|
| **Now** | Linux AMD + NVIDIA + Windows fully supported |
| **Mid-March 2026** | macOS Apple Silicon full runtime support |
| **Ongoing** | CI smoke matrix expansion for all platforms |

## Next Milestones

1. Ship macOS Apple Silicon full runtime (installer + compose + runtime parity).
2. Add CI smoke matrix for Linux NVIDIA/AMD and WSL logic checks.
3. Promote macOS from Tier C to Tier B after validated real-hardware runs.
