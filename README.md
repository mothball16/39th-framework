# 39th-framework
* The spaghetti bowl holding together 39th ACR games
* Currently, the only system being actively worked on is Spearhead (SPH). DTS re-works are planned but not priority at the moment

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