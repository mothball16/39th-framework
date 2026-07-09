# Project Rules

- Do not install Wally packages manually. Never run `wally install` directly for this project.
- When packages need to be installed or refreshed, use the default build task, `Update Wally & Sourcemap`, because it runs the full required workflow: Wally install, Rojo sourcemap generation, and Wally package type generation.
- Use the Stylua version pinned in `rokit.toml` and `stylua.toml` when formatting. If the `stylua` Rokit shim fails in this shell, call the pinned binary from Rokit tool storage directly with `--config-path stylua.toml` instead of retrying the shim.
- Do not manually edit generated `Network.luau` files.
- Avoid using the Roblox Studio MCP `execute_luau` command; it often stalls. Prefer non-executing Studio MCP inspection/search tools or filesystem checks.
- Treat this codebase as greenfield unless told otherwise: prefer the new intended shape over compatibility fallbacks for old Roblox Studio objects or tags.
