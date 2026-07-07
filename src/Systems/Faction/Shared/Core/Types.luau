local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Types = {}

export type PlayerKey = string

export type VariantItemProvider<TBuild = any> = {
	-- identifier for item type within configurations
	ID: string,
	AssignType: string?,
	-- constructs config-friendly item args for this provider
	Build: (args: TBuild) -> { type: string } & TBuild,
	-- runs when the variant containing the item is assigned to a player
	Assign: (player: Player, args: { type: string } & TBuild) -> (),
	-- runs when the variant containing the item is unassigned from a player
	Unassign: (player: Player, args: { type: string } & TBuild) -> (),
}

export type Settings = {
	ShowManualButton: boolean,
	ApplyVariantMode: string,
	AfterTeamChangeBehavior: string,
	ItemTypePaths: {
		[string]: Folder,
	},

	DebugMode: boolean,
}

export type Access = {
	Assets: Folder,
	Config: Settings,
}

export type VariantDescriptor = {
	Id: string,
	Name: string?,
	Description: string?,
	AccessCheck: AccessCheck?,
}

export type AccessCheck = (userId: number) -> boolean

export type FactionConfig = {
	ID: string,
	Name: string,
	Classes: {
		[string]: ClassConfig,
	},
	DefaultClassKey: string?,
}

export type ClassConfig = {
	Variants: { VariantDescriptor },
	Limit: number,
	Default: boolean,
}

export type PlayerAssignment = {
	FactionId: string,
	ClassKey: string?,
	VariantId: string?,
}

export type Variant = {
	ID: string,
	Items: { any },
}

export type InteractionController = {
	isOpen: Vide.source<boolean>,
	Initialize: (isOpen: Vide.source<boolean>) -> (),
	Destroy: () -> (),
}

return Types
