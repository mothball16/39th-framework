# 39th-framework

Those who troll

The spaghetti bowl holding together 39th acr games


### current goals or somethig
Spearhead tweaks
Spearhead has a couple issues QOL and optimization wise currently keeping it from being a well-rounded system. The following patches should improve general enjoyment when using spearhead

* save sensitivity
* preset FOV for guns
* replication buffer to unfuck networking
* fix weird glitches with gun too close feature

NOTE: this is mostly for me + @AwesomeSauce but if in the future someone else hops on for scripts let me know and i can add u to the repo https://github.com/mothball16/39th-framework 

* considering moving to reactive state using Charm so we can decouple controllers 

* Reference for replication in larger scale sgames https://devforum.roblox.com/t/how-do-some-games-replicate-body-part-rotation-so-smoothly/1240146/13

* Update inputcontroller @AwesomeSauce



### standards


* Controllers are reactive. Avoid calling controllers directly if possible, aside from intent methods
* Input controller wires input actions to controller intent methods


### example pipeline
1. Player presses Shift --> InputController picks up Shift input
2. InputController invokes callback to MovementController.OnSprintIntent
3. MovementController.OnSprintIntent validates the action and switches State.sprinting atom to true
4. All controllers now react to this change: AnimationController (sprint anim), MovementController (speed, stance adj.), CameraController (FOV change).