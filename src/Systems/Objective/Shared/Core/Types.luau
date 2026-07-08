--!strict
--#selene: allow(incorrect_standard_library_use)
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local Maid = require("@game/ReplicatedStorage/Packages/maid")

local Types = {}

export type ObjectiveStatus = "Idle" | "Active" | "Ended"
export type ObjectiveEndReason = "completed" | "cancelled" | "destroyed" | string

export type TeamId = string
export type ScoreMap = { [TeamId]: number }

export type ObjectiveSnapshot = {
	ID: string,
	Kind: string,
	Status: ObjectiveStatus,
	OwnerTeam: TeamId?,
	ContestingTeam: TeamId?,
	Scores: ScoreMap,
	Progress: number,
	PhaseIndex: number?,
	WinnerTeam: TeamId?,
	StartedAt: number?,
	EndedAt: number?,
	Reason: ObjectiveEndReason?,
	Details: { [string]: any }?,
}

export type State = {
	objectiveById: Charm.Atom<{ [string]: ObjectiveSnapshot }>,
}

export type Settings = {
	DebugMode: boolean?,
	GetTeamId: ((Player) -> TeamId?)?,
}

export type Access = {
	Assets: Folder,
	Config: Settings,
}

export type ObjectiveContext = {
	ObjectiveId: string,
	Definition: ObjectiveDefinition,
	State: State,
	Maid: Maid.Maid,
	Access: Access?,

	GetSnapshot: () -> ObjectiveSnapshot?,
	SetSnapshot: (ObjectiveSnapshot) -> (),
	UpdateSnapshot: ((ObjectiveSnapshot) -> ObjectiveSnapshot) -> (),
	AddScore: (TeamId, number) -> number,
	SetProgress: (number) -> (),
	Complete: ({ winnerTeam: TeamId?, reason: ObjectiveEndReason?, details: { [string]: any }? }?) -> (),
	End: (ObjectiveEndReason?) -> (),
	GetTeamId: (Player) -> TeamId?,
	OnHeartbeat: ((number) -> ()) -> RBXScriptConnection?,
}

export type ObjectiveDefinition = {
	ID: string,
	Kind: string,
	AutoStart: boolean?,
	OnStart: ((ObjectiveContext) -> (() -> ())?)?,
	OnEnd: ((ObjectiveContext, ObjectiveEndReason?) -> ())?,
}

return Types
