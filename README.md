# 39th-framework
* A group of standalone systems for the 39th ACR and any managed games.

### overview
* **Faction**: Native faction management framework. Currently supports classes & variants, with future implementation of buildings and spawners on the horizon.
* **Aware**: Provides pings, marks, and nametags (WIP) to the client. Decoupled from teams to support faction integration. 
* **Weapon**: Modification of Spearhead aiming for UX improvements, immersive gunplay, and overall optimization. Features a re-written client-side using reactivity to somewhat salvage the previous monolithic client script.

* **StateSync**: A tiny utility to set up the charm-sync singleton for any portable systems reliant on it.

### prerequisites
* [Rokit](https://github.com/rojo-rbx/rokit) for toolchain management

### installation
1. Clone the repo to your machine.
2. Run `rokit install` in the repo root to install toolchain binaries.
3. Run the default build task (CTRL + SHIFT + B by default in VS code) to install packages and update the sourcemap.
4. Serve to Roblox Studio with 'rojo serve' or with the Rojo plugin. This will sync the scripts to whatever workplace you are in.
5. Insert the asset package listed under the group and ensure auto-update is on. (This requires access to the Artificers group.)