# 39th-framework
* The spaghetti bowl holding together 39th ACR games
* Currently, the only system being actively worked on is Spearhead (SPH). DTS re-works are planned but not priority at the moment

### prerequisites
* [Aftman](https://github.com/LPGhatguy/aftman) for toolchain management
* [Rojo](https://rojo.space/) for project synchronization
* [Wally](https://wally.run/) for package management

### installation
1. Clone the repo to your machine
2. Assuming you have the above installed, run the default build task (CTRL + SHIFT + B by default in VS code) to install packages and update the sourcemap.
3. Serve to Roblox Studio with 'rojo serve' or with the Rojo plugin. You will most likely need to re-upload/re-bind animations due to how Roblox's permissions are.
4. (Optional) To make your life easier, look at Utility/CommandLineStuff and execute the SpearheadAnimBulkUploader script in the command line. Instructions are located there.

### testing (Studio)
With Rojo synced, play in Studio (server run). `ServerScriptService/SPH_TestRunner.server.lua` discovers `*.spec` modules under `ReplicatedStorage/Tests` and runs them with TestEZ (text reporter in output). This only runs when `RunService:IsStudio()` is true.

### standards
* Controllers are reactive. Avoid calling controllers directly if possible, aside from intent methods.
* Input controller wires input actions to controller intent methods.
* Any method wired to an input should be named On(action_name)Intent. (todo: maybe this isn't the best naming for lookup purposes)
* Any method reacting to a change should be named Sync(atom_name).
* If the order of reactions matter then something has gone wrong.

### example pipeline
1. Player presses Shift --> InputController picks up Shift input
2. InputController invokes callback to MovementController.OnSprintIntent
3. MovementController.OnSprintIntent validates the action and switches State.sprinting atom to true
4. All controllers now react to this change: AnimationController (sprint anim), MovementController (speed, stance adj.), CameraController (FOV change).