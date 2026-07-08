--!strict
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local Types = {}

export type GetTeamValue = (player1: Player) -> string?
export type ShortenName = (playerKey: string) -> string

export type GameSettings = {
	-- whether to replicate the ping to the player themselves - this is only for debugging
	ReplicateToSelf: boolean,
	-- injectable function to get the team value of a player - used so non-team based systems can still use this
	GetTeamValue: GetTeamValue,
	-- imageId for ping
	PingImageId: string,
	-- max distance for pinging
	PingMaxDistance: number,
	-- interval at which to update the team state
	TeamUpdateInterval: number,
	-- shorten display names for tags
	ShortenName: ShortenName,
}

-- properties for the visual display of a ping tag
export type PingTagProps = {
	imageId: string,
	name: () -> string,
}

-- properties for the visual display of a name tag
export type NameTagProps = {
	nameTag: () -> string,
	health: () -> number,
	maxHealth: () -> number,
	textSize: () -> number,
}

-- information stored within the state for a ping
export type PingInfo = {
	imageId: string,
	name: string,
	position: Vector3,
	owner: Player,
}

export type OwnedValues = {
	Team: string?,
	NameTag: string,
	Pings: { [string]: PingInfo },
}

export type OwnedValuesByKey = { [string]: OwnedValues }

export type State = {
	valuesByPlayer: Charm.Atom<OwnedValuesByKey>,
	valuesByTeam: Charm.Getter<{ [string]: OwnedValuesByKey }>,
}

export type DisplayType = "enemies" | "all" | "none"

export type UserSettings = {
	PingKey: Charm.Atom<Enum.KeyCode>,
	ClearPingKey: Charm.Atom<Enum.KeyCode>,

	PingSize: Charm.Atom<UDim2>,
	UseDeadzone: Charm.Atom<boolean>,
	PingClearDeadzone: Charm.Atom<number>,

	HidePingDistance: Charm.Atom<number>,
	HidePingTransModifier: Charm.Atom<number>,

	NameTagSize: Charm.Atom<number>,
	NameTagTransparency: Charm.Atom<number>,
	ShowOwnNameTag: Charm.Atom<boolean>,

	DefaultNameDisplayType: Charm.Atom<DisplayType>,
	DefaultHealthDisplayType: Charm.Atom<DisplayType>,
}

return Types
