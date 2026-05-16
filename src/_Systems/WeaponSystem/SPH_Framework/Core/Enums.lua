return {
    Stance = {
        STANDING = "STANDING",
        CROUCHING = "CROUCHING",
        CRAWLING = "CRAWLING",
    },
    Lean = {
        LEFT = "LEFT",
        RIGHT = "RIGHT",
        NONE = "NONE",
    },
    Intents = {
        STANCE_UP = "STANCE_UP",
        STANCE_DOWN = "STANCE_DOWN",
        LEAN_LEFT = "LEAN_LEFT",
        LEAN_RIGHT = "LEAN_RIGHT",
        LEAN_NONE = "LEAN_NONE",
        SPRINT = "SPRINT",
        HOLD_AIM = "HOLD_AIM",
        FREELOOK = "FREELOOK",
        SCROLL = "SCROLL",
        JUMP = "JUMP",
        TRIGGER = "TRIGGER",
        RELOAD = "RELOAD",
        CHAMBER = "CHAMBER",
        SWITCH_SIGHTS = "SWITCH_SIGHTS",
        SWITCH_FIRE_MODE = "SWITCH_FIRE_MODE",
        TOGGLE_LASER = "TOGGLE_LASER",
        TOGGLE_FLASHLIGHT = "TOGGLE_FLASHLIGHT",
        DROP_GUN = "DROP_GUN",
    },

    HoldStance = {
        High = 0,
        Ready = 1,
        Low = 2,
        Patrol = 3,
    },

    FireModes = {
        Safe = 0,
        Semi = 1,
        Auto = 2,
        Burst = 3,
        UBGL = 4,
        Manual = 5
    },

    OperationType = {
        -- Tactical/Closed Bolt behavior (AR-15, Glock)
        ClosedBoltRetained = 1,
        -- Open-bolt or specific manual cycling (MP40, some Shotguns)
        OpenBoltOnEmpty = 2,
        -- Forced cycling every time (Bolt-action, Pump-action)
        ManualCycleAlways = 3,
        -- Static breech/Cell based (RPG, Railgun)
        NonReciprocating = 4
    },

    MagType = {
        MagFed = 1,
        ClipFed = 2,
        Manual = 3,
    },

}
