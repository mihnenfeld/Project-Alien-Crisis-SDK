# Project Alien Crisis – Source SDK 2013

Separate Source 1 adaptation of Alien Crisis. The original Godot repository remains unchanged.

## Target
- Story-driven survival RPG with a physical base and raid missions.
- Cooperative campaign: host protagonist + second player controlling a companion.
- Host-local dedicated server; solo companion controlled by AI.
- Tutorial choice between Medic and Mechanic; unchosen companion may return later.
- First prototype retains the Nyra/artifact consequence branch.

## Local setup
1. Install Valve Source SDK Base 2013 Multiplayer through Steam.
2. Clone ValveSoftware/source-sdk-2013 to `C:\Dev\source-sdk-2013`.
3. Generate `src\everything.sln` via `createallprojects.bat`.
4. From this repository, run `.\ac.ps1 check` then `.\ac.ps1 build`.

`.\ac.ps1 all` currently validates and builds client/server; it does **not** launch a game yet. Build logs go to `logs/`. Valve source remains in a separate local checkout (not vendored here).

## Workflow
Changes will be developed in branches; stable revisions merged after review. First milestone: compile unmodified HL2MP modules. Subsequent milestones: standalone mod packaging, dedicated server test, companion control and campaign state.

## License
Source SDK 2013 has license restrictions; no commercial release is assumed without separate authorization.
