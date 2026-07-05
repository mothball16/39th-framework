opt server_output = "./Server/Net/Network.luau"
opt client_output = "./Client/Net/Network.luau"
opt types_output = "./Shared/Core/NetworkTypes.luau"
opt remote_scope = "PING"

type RequestPingPayload = struct {
	position: Vector3,
}

event RequestPing = {
	from: Client,
	type: Reliable,
	call: SingleAsync,
	data: (payload: RequestPingPayload),
}

event RequestRemovePing = {
	from: Client,
	type: Reliable,
	call: SingleAsync,
	data: (),
}

type ReportPingPayload = struct {
	owner: Instance.Player,
	position: Vector3,
	name: string.utf8,
}

event ReportPing = {
	from: Server,
	type: Reliable,
	call: ManyAsync,
	data: (payload: ReportPingPayload),
}

type ReportRemovePingPayload = struct {
	owner: Instance.Player,
}

event ReportRemovePing = {
	from: Server,
	type: Reliable,
	call: ManyAsync,
	data: (payload: ReportRemovePingPayload),
}
