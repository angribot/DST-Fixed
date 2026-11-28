## Related repositories

Find local checkouts in the `workspace.library` entries of `.luarc.json` (machine-local, gitignored; `jq '."workspace.library"' .luarc.json`); ask if one is missing.

- DST-scripts: the game's scripts ("游戏源码", "原版", "上游"), with the contents of `scripts/` at its root. Each commit is one game build, so its history shows upstream updates.
- NightStories: 暗夜故事集, a companion mod. Cross-check it whenever a change touches a mechanic it also modifies.

Target the latest game build. Add compatibility code for older builds or third-party mods only when asked.

## Terminology

Name game and mod content by its in-game string in the language you are writing, in replies as well as files: English from the game's `STRINGS` (`strings.lua`), other languages from the game's matching `languages/*.po`. A module's name is its option `label` in `modinfo.lua`.

## Modules

Each module is one option that loads one file:

- The file is `main/modules/<name>.lua`, mapped from the option name in `modmain.lua`'s `config_table`.
- The option sits under the matching category in `modinfo.lua`'s `configuration_options`.
- `README.md` lists the module under the same category in Modules; keep that entry in step with the module's behavior.
- Mark a new module in `modinfo.lua`'s `new_modules`; an X or Y bump clears the previous series' marks.

Vanilla bug fixes and performance fixes that leave gameplay unchanged go in `main/asscleaner/`, listed in `modmain.lua`'s `asscleaner` table, and always load. Give each a short section under `README.md`'s Patch Notes. Head each fix with comments citing the vanilla functions it fixes or speeds up, and remove the fix, its entry, and its section once vanilla makes it unnecessary.

## Implementation

- Reach for vanilla interfaces and existing files first; add a helper, wrapper, component, or file only when none of them can hold the code.
- Guard only against states you can point to in the game source.

## Comments

- Write comments in the format `.lint/check-comments --help` describes. Head a copied upstream function with one that cites it and names the change that made the copy necessary.
- After DST-scripts, GlassicAPI, or NightStories updates, run `.lint/check-upstream`, recheck each reported fact against the new code, and update the version in its comment.

## Lua compatibility

Target DST's Lua 5.1 runtime plus `bit`, not LuaJIT extensions.

- Use Lua 5.1 syntax: no `goto`/labels, `\x`/`\z` escapes, floor division, or native bitwise operators. Use `bit` for bitwise operations.
- Use `unpack` and `loadstring` instead of `table.unpack` and string-based `load`. Pass arguments to `xpcall` through a closure.
- Use `table.concat` for repeated strings with separators and `math.log(x) / math.log(base)` for other logarithm bases. Lua 5.1 silently ignores the extra arguments to `string.rep` and `math.log`.
- Access standard globals missing from the mod environment through `GLOBAL`, including `unpack`, `coroutine`, and `loadstring`.
- Keep coroutine yields outside C-call boundaries, including `pcall`/`xpcall`, metamethods, `table.sort` comparators, and `gsub` callbacks.
- Avoid relying on cross-runtime `math.random` sequences or out-of-range `%d` formatting.

`.lint/check-lua` checks the first rule, `table.unpack`, and stylua formatting (fix with `stylua <file>`). The pre-commit hook runs it, `.lint/check-changelog`, and `.lint/check-comments`; enable the hook once per clone with `git config core.hooksPath .githooks`.

## Testing

Verify changed behavior with a simulation in a temporary directory outside the repository (e.g. `mktemp -d`); the repository keeps no test cases. Simulate on the game's Lua 5.1 runtime (`uv run --with lupa`, `lupa.lua51`) and load mod files the way `mods.lua` does. Simulations still only approximate DST, so list the engine-dependent behavior left to check in-game.

## Release notes

Release notes live in the `changelog` variable of `modinfo.lua`; there is no CHANGELOG file.

- Each language block opens with the current release's entries and no heading, since `description` already prepends "本次更新:" / "Change:".
- After a blank line, `近期更新：` / `Recent Changes:` lists earlier entries of the current series, newest first. A series starts at the latest `x.y.0` release.
- Publish with `.workshop/publish.sh`, after a `--dry-run`.
- Bump the version when `.workshop/publish.sh --published-version` prints the `version` in `modinfo.lua`. The user picks X (major), Y (minor), or Z (patch); propose one if they did not.
- No bump, while the published version is below `version`: add the entries to the current release in a commit of their own, leaving Recent Changes as is.
- Z bump (e.g. `2.25.9` → `2.25.10`): write the new entries at the top and move the previous release's entries to the top of Recent Changes. The first patch of a series creates that section. Recent Changes accumulates every entry since the series began.
- X or Y bump (e.g. `2.23.2` → `2.24.0`, `2.25.10` → `3.0.0`): replace the whole changelog with this release's entries and drop Recent Changes.
- Commit a bump as `chore: bump version to X.Y.Z`, title only, carrying the release's changelog: its entries and the move into Recent Changes. The commits it releases leave the changelog alone.
- Keep Chinese and English in lockstep: same entries, same order, moved and dropped together.
- Write each entry as a player-facing headline: one clause naming what changed, leaving out conditions, mechanics, and causes. Lead with the module it belongs to: `【解除玩家攻速限制】现在也会加快吹箭和嚎弹炮的连射` / `Enable Quick Attack now also speeds up consecutive dart and Howlitzer shots`, `新模块【巨大洞穴蠕虫延迟消失】` / `New module: Delayed Great Depths Worm Despawn`.
- Write both languages in the simple present, describing the game after the update. Chinese entries drop 了 (`修复…`); English entries without a subject start with the base verb (`Fix …`).
