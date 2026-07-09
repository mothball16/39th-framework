# Project Rules

- Do not install Wally packages manually. Never run `wally install` directly for this project.
- When packages need to be installed or refreshed, use the default build task, `Update Wally & Sourcemap`, because it runs the full required workflow: Wally install, Rojo sourcemap generation, and Wally package type generation.
