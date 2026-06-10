# 39th-framework
* The spaghetti bowl holding together 39th ACR/WN games.

### overview
* **FactionSystem**: Native faction management framework. Currently supports classes & variants, with future implementation of buildings and spawners on the horizon.
* **WeaponSystem**: Modification of Spearhead aiming for UX improvements, immersive gunplay, and overall optimization. Features a re-written client-side using reactivity to somewhat salvage the previous monolithic client script.

### prerequisites
* [Aftman](https://github.com/LPGhatguy/aftman) for toolchain management
* [Rojo](https://rojo.space/) for project synchronization
* [Wally](https://wally.run/) for package management

### installation
1. Clone the repo to your machine.
2. Assuming you have the above installed, run the default build task (CTRL + SHIFT + B by default in VS code) to install packages and update the sourcemap.
3. Serve to Roblox Studio with 'rojo serve' or with the Rojo plugin. This will sync the scripts to whatever workplace you are in.
4. Insert the asset package listed under the group and ensure auto-update is on. Unfortunately, Rojo tends to corrupt rbxms with meshes, so this project wasn't able to be fully managed via Rojo.