# ParkPark — OpenCode project guide

This file is the persistent project context and current roadmap for OpenCode. Read it before each task. Keep it updated when a milestone or approved decision changes.

## Project

- **Working name:** ParkPark
- **Concept:** restore a closed-down amusement park, reopen rides, welcome guests, and grow the park.
- **Primary play pattern:** clear/repair → open → guests visit → earn tickets → expand.
- **Audience hypothesis:** casual Roblox players, mobile-first, easy to enjoy with friends.
- The current prototype is a technical graybox only. Its primitive geometry and temporary HUD are not the target quality; the user has said the current quality is far below expectations.

## Workflow and source of truth

- VS Code/OpenCode and files in this repository are the source of truth for code and project structure.
- `AGENTS.md` is the canonical project handoff for OpenCode and Claude Code. Claude Code starts from the root `CLAUDE.md`, which imports this file; read it before every task so the user does not need to repeat the project overview or current roadmap.
- Use Luau and Rojo 7.7. `default.project.json` maps `src/server`, `src/client`, and `src/shared` into Roblox services.
- Roblox Studio is the preview, playtest, and publishing environment. Do not make Studio-only code edits; make code changes in files and let Rojo sync them.
- Do not publish, buy assets, or make external changes without the user's explicit request.
- At the end of each task or completed logic milestone, commit and push the changes with a concise, natural one-sentence message; use and merge a pull request when appropriate.
- Work in small, reviewable milestones. Do not generate the whole game from a broad prompt.

## Claude Code handoff

- Start with the root `CLAUDE.md`; its `@AGENTS.md` import provides this complete guide as Claude Code project context.
- Use the current phase, verification notes, and **Next** item below as the continuation point. Do not ask the user to restate settled project decisions.
- Before editing, inspect the working tree and relevant source so existing user changes are preserved. Keep this guide current when a milestone, verification result, or blocker changes.
- Follow the same Roblox/Rojo workflow and visual-verification rules below; Unity tooling or screenshots are not evidence for ParkPark.

## Current setup

- OpenCode's VS Code workspace is `parkpark/`.
- Git is initialized on branch `main` and connected to the public GitHub repository `https://github.com/namjin22/ParkPark`.
- Rojo project and Studio plugin are connected to the local Place2. The server and client bootstrap messages were verified in Studio Output.
- The current Rojo mapping is in `default.project.json`; imported model templates under `assets/models/roblox/` map to `ReplicatedStorage/ParkParkAssets`.
- `opencode.json` enables the local `roblox-studio` MCP for OpenCode through `%LOCALAPPDATA%\Roblox\mcp.bat` with a 60-second request timeout. Claude Code does not read `opencode.json`; on 2026-09-29 the same launcher was registered for Claude Code at local scope (`claude mcp add roblox-studio --scope local -- cmd.exe /c "%LOCALAPPDATA%\Roblox\mcp.bat"`, stored in `~/.claude.json`, not in the repo). Do not also add Studio's Quick connect entry for Claude Code unless this one is removed (`claude mcp remove roblox-studio -s local`), or the tools will be duplicated.
- **Current MCP blocker (2026-09-29):** a direct stdio probe of `StudioMCP.exe` returned server `RobloxStudio 1.0.0` but `tools: []` with `Timed out waiting for tools to become available`; `claude mcp get roblox-studio` reports `Connected · tools fetch failed`. The proxy works, but Studio is not serving tools. In Studio, open Assistant → Settings → MCP Servers → Manage MCP Servers, turn on `Enable Studio as MCP server` and confirm the green indicator, then restart Claude Code so the Roblox tool schemas load.
- On 2026-09-29 Rojo 7.7.0 was serving `default.project.json` on port 34872 with established Studio plugin connections; Play has not yet been rechecked after the latest startup changes.
- Roblox Studio login succeeded through Quick Login while the phone and PC used the same network. Avoid repeating login troubleshooting unless the user reports a new issue.

## Current source and known prototype state

- `src/server/Bootstrap.server.luau` starts `ParkBuilder`, `ParkProgressionService`, `EconomyService`, and `RideService`; `ParkBuilder` can clone imported templates and still falls back to temporary graybox when they are absent. It waits up to five seconds for the optional asset folder to allow Rojo's startup sync to finish. Bootstrap logs whether the entrance and carousel came from authored models or the fallback. Separate custom OBJ source meshes for the entrance, rides, and repair console are in `assets/models/parkpark/` and are not yet imported into the place.
- `src/client/Bootstrap.client.luau` starts `HUDController` and `RepairFeedbackController` for ticket and restoration feedback.
- `src/shared/Config/GameConfig.luau` holds starter ticket settings.
- The final scene is not visually approved yet. Finish its authored entrance/carousel and compare the before/after states before adding gameplay breadth.
- The user initially reported a broad plain area. A later Play run showed server/client bootstraps and graybox structures, but also a `ParkParkAssets` sync warning and default-baseplate grid/z-fighting. The Rojo server was restarted, a bounded startup wait added, and the default baseplate surface hidden while keeping its collision; the fallback spawn is moved to the entrance. Retest these latest changes in Studio.

## Design and asset direction

- A whimsical, nostalgic, storybook-style fairground is the working direction for the vertical slice, following the user's instruction to proceed. `docs/ART_DIRECTION.md` and `docs/ASSET_PLAN.md` remain working guidance, not a final art bible.
- Visual contrast should clearly show the park changing from faded, neglected, and overgrown to colorful, illuminated, and lively.
- Use basic Parts only for grayboxing layout and interaction. Do not present primitive placeholders as final art.
- Plan assets as a coherent set. Use Creator Store, custom models, or generated meshes selectively; do not invent asset IDs or copy recognizable third-party parks/brands.
- Inspect imported models for scripts and keep visual assets separate from gameplay logic. Add any approved local models to the Rojo project deliberately.

## Roblox Studio visual verification

- Start `rojo serve default.project.json` from the project root and connect the Studio Rojo plugin to port 34872. Restart Rojo after project-tree mapping changes; reconnect Studio if the plugin shows disconnected.
- Use the Roblox Studio MCP screenshot and console tools for Roblox visual/runtime checks. Unity editor screenshots are not evidence for this project.
- After each scene/model milestone, check server and client Output, confirm no `ParkParkAssets` sync warning, capture the same entrance-to-carousel view before/after repair, and review both a wide desktop view and a phone-sized portrait view.
- If Roblox Studio tools are unavailable in the session, mark the visual/play check pending and use the latest user-provided Output/screenshot as evidence; do not claim unrun checks passed.
- The active scene is not visually approved until authored models are imported, their pivots/state variants are checked in Play, and the mobile composition is reviewed.

## Architecture and engineering rules

- Separate responsibilities into small modules as the prototype grows, such as `ParkBuilder`, `RideService`, `EconomyService`, and client-side controllers.
- Server owns tickets, repair state, ownership, and progression. Validate player distance/state on the server; never trust client-supplied currency or prices.
- Keep new code type-checked with Luau and consistent with existing names and paths. Avoid adding packages until there is a concrete need.
- Before editing, inspect the relevant existing files and preserve working behavior unless the task explicitly replaces it.
- After each task, state changed files, how to test in Studio, and anything that could not be verified. Do not claim an unrun test passed.

## Roadmap and current phase

1. **Environment — complete:** VS Code/OpenCode, Git, Rojo, and Studio sync.
2. **Visual direction and asset plan — complete:**
   - **Result:** `docs/ART_DIRECTION.md` records the storybook fairground direction, palette, shape/material rules, mobile lighting/camera and entrance-to-carousel composition. `docs/ASSET_PLAN.md` lists MVP assets, per-item creation/refinement recommendations, Creator Store search/review criteria, and the planned module split. Graybox geometry remains temporary and is not a final-art target.
   - **Verification:** Reviewed the README, game design, Rojo mapping, and source; manually checked the design documents and local references. This documentation phase had no code or Studio checks.
3. **Polished vertical slice — in progress (current phase):** one entrance area and one memorable carousel, with clear cleanup/repair interactions, ticket feedback, and a visible before/after state.
   - **Result:** Server logic is split across `ParkBuilder`, `ParkProgressionService`, `RideService`, and `EconomyService`; client feedback is handled by HUD and repair controllers. Seven custom OBJ mesh sources and a preview are in `assets/models/parkpark/`. `ParkBuilder` can clone named `.rbxmx` templates from `ReplicatedStorage/ParkParkAssets`, toggle authored canopy variants, and retain graybox fallback. The current Studio screenshot still showed rough graybox geometry and the old baseplate grid. A 2026-09-29 contract review found that the meshes face local `-Z` while guests arrive from the `+Z` spawn, so the entrance sign would face the carousel and sit behind the arch (the graybox `PARK PARK` SurfaceGui already faced away from the spawn). `ParkBuilder` now turns the authored entrance 180° and puts the sign SurfaceGui on the face toward arriving guests; the graybox ground now spans z -36..44 so the carousel platform no longer overhangs the hidden baseplate. `assets/models/parkpark/README.md` maps each OBJ to its Studio name and parent (the whole rotor mesh is `CenterPost`) and documents the facing rule (`RepairConsole` turned 180° inside `BrokenCarousel`). Rotor, canopy, and platform meshes are XZ-centered at the origin, so the rotation axis holds even if the importer centers parts on their bounding boxes.
   - **Verification:** `verify.ps1` passes StyLua, Selene (0 warnings), Luau analysis, and Rojo build. Python regenerated all seven OBJ sources and confirmed each is under 7,500 triangles. The last supplied Output showed both bootstraps but also `ParkParkAssets` missing; Rojo was restarted, the asset wait is bounded, the baseplate surface is hidden, and the spawn is moved to the entrance. Those latest changes have not been Play-tested. On 2026-09-29 the mesh generator and `verify.ps1` passed again; RobloxStudioBeta and its MCP launcher were present, but this session exposed only UnityMCP, so Roblox Play, screenshot, and Output checks remain pending. Later on 2026-09-29 (Claude Code), `verify.ps1` passed after the sign-facing and ground changes (StyLua, Selene 0 warnings, Luau analysis with the known `didChangeWatchedFiles` warning, Rojo sourcemap/build). Studio MCP served no tools, so Play, Output, screenshots, OBJ import, and the new sign/ground layout are **not** verified in Studio; no `.rbxmx` templates exist yet.
   - **Next:** (1) User: enable `Enable Studio as MCP server` in Studio and restart Claude Code. (2) List Studio instances, use the returned `studio_id`, and in Play confirm server/client bootstrap logs, `Park ready (entrance=graybox, carousel=graybox)`, and no `ParkParkAssets` warning; capture the entrance-to-carousel view before/after repair in wide and phone portrait, checking the sign now reads from the spawn. (3) Import the seven OBJs with `ParkParkFairground.mtl` through the 3D Importer (this uploads the meshes to the user's Roblox inventory; saved `.rbxmx` files need those uploaded mesh IDs to work through Rojo), assemble `RuinedEntrance`/`BrokenCarousel` per the README table, confirm no scripts, and save them to `assets/models/roblox/`. (4) Play again for `authored` sources, canopy swap, rotor weld/rotation, and mobile composition; also decide visually whether `CrackedPath` (z 1..21) should run through the gate from the spawn.
4. **First-session loop — after slice approval:** tutorial the cleanup-to-ride flow, open the gate, bring in guests, let them ride, and show how ride use earns tickets.
5. **MVP park content — after the first loop works:** add teacups, bumper cars, a snack stand, park-rating/area unlocks, and one short event such as a power outage.
6. **Progress and saves:** add server-authoritative persistence for tickets, park state, ride unlocks, and restoration progress; verify reconnect and failure cases before adding more content.
7. **Social and live-game polish:** friend visits, event cadence, mobile accessibility/performance, onboarding clarity, and error/edge-case cleanup.
8. **Cosmetics and monetization — last:** park expression, cosmetics, and optional purchases only after the core loop and retention are enjoyable; prioritize cosmetics over gameplay power.

When a milestone is completed, update this roadmap and the current phase in this file rather than asking the user to copy the entire project context into a new chat.
