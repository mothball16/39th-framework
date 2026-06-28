opt server_output = "./Server/Network.luau"
opt client_output = "./Player/Network.luau"
opt types_output = "./Framework/Core/NetworkTypes.luau"
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