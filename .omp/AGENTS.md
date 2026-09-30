# OMP Project Context

WH3 MOD workspace. At task start read `.codex/project_context.md`; it routes all task-specific material. Read `warhammer-mod-development_generic/SKILL.md` and only the matching reference for MOD creation, packing, RPFM, or game diagnostics. Read `.codex/runtime_state.md` only for current playset, machine paths, Workshop, specific MOD state, AI/TTS, or pagefile work; query live state before acting. History is `.codex/project_context_history.md` and is never startup material.

## Boundaries

- Maintain MOD sources in `mod_files/`; generated packs in `mod_output/`; release assets in `workshop_release/`; all temporary scripts, backups, renders, downloads, and diagnostics in `scratch/`.
- `gamedata/`, `bilingual/`, `references/`, the RPFM directory, and user-owned `assets/image/` are read-only unless the user explicitly requests otherwise. `manual_edit/` is append/reference only.
- Never create temporary files at repository root. Reusable scripts belong in `tools/`; their outputs belong in `tools/_*/` or `scratch/`.

## Hard requirements

- Launch WH3 and manage MOD enable/order only through `E:\Code\wyccc-warhammer-mod-manager`. Read the current playset from `state.db`; never trust historical names, counts, positions, or `config.json` presets. Back up `state.db` before mutation.
- Keep `C:\pagefile.sys` system-managed; never resize it automatically.
- Default pack/deploy command: `C:\Users\22448\AppData\Local\Programs\Python\Python313\python.exe tools/build_pack.py <mod> --deploy`. Every MOD needs `notes/pack_notes.txt`, `notes/alias.txt`, and `preview.png`; patches also need `notes/dependencies.txt`.
- Diagnose game issues with `tools/wh3diag.py` first. File-path shadowing and DB same-key conflicts have opposite ordering rules; read the load-order reference before reordering.
- Reusable findings update the smallest SKILL/reference plus `CHANGELOG.md`; specific MOD state goes to its notes or runtime state, and dated events go to history.
