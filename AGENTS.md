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
- Use Luau and Rojo 7.7. `default.project.json` maps `src/server`, `src/client`, and `src/shared` into Roblox services.
- Roblox Studio is the preview, playtest, and publishing environment. Do not make Studio-only code edits; make code changes in files and let Rojo sync them.
- Do not publish, buy assets, or make external changes without the user's explicit request.
- At the end of each task or completed logic milestone, commit and push the changes with a concise, natural one-sentence message; use and merge a pull request when appropriate.
- Work in small, reviewable milestones. Do not generate the whole game from a broad prompt.

## Current setup

- OpenCode's VS Code workspace is `parkpark/`.
- Git is initialized on branch `main` and connected to the public GitHub repository `https://github.com/namjin22/ParkPark`.
- Rojo project and Studio plugin are connected to the local Place2. The server and client bootstrap messages were verified in Studio Output.
- The current Rojo mapping is in `default.project.json`.
- Roblox Studio login succeeded through Quick Login while the phone and PC used the same network. Avoid repeating login troubleshooting unless the user reports a new issue.

## Current source and known prototype state

- `src/server/Bootstrap.server.luau` starts `ParkBuilder`, `EconomyService`, and `RideService`; `ParkBuilder` still creates the temporary entrance/carousel graybox.
- `src/client/Bootstrap.client.luau` starts `HUDController`, which builds the ticket display and reacts to ticket changes.
- `src/shared/Config/GameConfig.luau` holds starter ticket settings.
- The final scene is not visually approved yet. Finish its authored entrance/carousel and compare the before/after states before adding gameplay breadth.

## Design and asset direction

- A whimsical, nostalgic, storybook-style fairground is the working direction for the vertical slice, following the user's instruction to proceed. `docs/ART_DIRECTION.md` and `docs/ASSET_PLAN.md` remain working guidance, not a final art bible.
- Visual contrast should clearly show the park changing from faded, neglected, and overgrown to colorful, illuminated, and lively.
- Use basic Parts only for grayboxing layout and interaction. Do not present primitive placeholders as final art.
- Plan assets as a coherent set. Use Creator Store, custom models, or generated meshes selectively; do not invent asset IDs or copy recognizable third-party parks/brands.
- Inspect imported models for scripts and keep visual assets separate from gameplay logic. Add any approved local models to the Rojo project deliberately.

## Architecture and engineering rules

- Separate responsibilities into small modules as the prototype grows, such as `ParkBuilder`, `RideService`, `EconomyService`, and client-side controllers.
- Server owns tickets, repair state, ownership, and progression. Validate player distance/state on the server; never trust client-supplied currency or prices.
- Keep new code type-checked with Luau and consistent with existing names and paths. Avoid adding packages until there is a concrete need.
- Before editing, inspect the relevant existing files and preserve working behavior unless the task explicitly replaces it.
- After each task, state changed files, how to test in Studio, and anything that could not be verified. Do not claim an unrun test passed.

## Roadmap and current phase

1. **Environment — complete:** VS Code/OpenCode, Git, Rojo, and Studio sync.
2. **Visual direction and asset plan — complete:**
   - **Result:** `docs/ART_DIRECTION.md` records the storybook fairground direction, palette, shape/material rules, mobile lighting/camera and entrance-to-carousel composition. `docs/ASSET_PLAN.md` lists MVP assets, per-item creation/refinement recommendations, Creator Store search/review criteria, and the planned `ParkBuilder`/`RideService`/`EconomyService`/`HUDController` split. Graybox geometry remains temporary and is not a final-art target.
   - **Verification:** Reviewed the project README, game design, Rojo mapping, and current source; manually checked the two design documents and their local references for consistency. No code tests or Studio visual checks were run because this phase changed documentation only.
3. **Polished vertical slice — in progress (current phase):** one entrance area and one memorable carousel; repair interaction and ticket feedback, with an intentional before/after look.
   - **Result:** README refreshed; the existing behavior is split across `ParkBuilder`, `RideService`, `EconomyService`, and client controllers. Server-owned carousel repair state replicates to clients; the ticket HUD pulses on rewards and a brief repair toast confirms the shared restoration. The generated scene remains a temporary graybox; the distinctive authored carousel and approved final scene presentation are still pending.
   - **Verification:** `verify.ps1` passed StyLua, Selene (0 warnings), Luau type analysis, and Rojo sourcemap/place build. Roblox Studio runtime and mobile visual checks were not run.
   - **Next:** replace the temporary carousel/entrance with approved authored assets, then verify the before/after composition in Studio on mobile-sized views.
4. **First-session loop:** open the gate, bring in the first guests, and let guests use the ride.
5. **Expand only after the slice is visually and mechanically approved:** more attractions, zones, saving, social visits, events, and later monetization.

When a milestone is completed, update this roadmap and the current phase in this file rather than asking the user to copy the entire project context into a new chat.
