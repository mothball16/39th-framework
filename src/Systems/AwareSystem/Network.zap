opt server_output = "./Aware_Server/Network.luau"
opt client_output = "./Aware_Player/Network.luau"
opt types_output = "./Aware_Framework/Core/NetworkTypes.luau"
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

type ReportPingPayload = struct {
	position: Vector3, 
	name: string.utf8,
}

event ReportPing = {
	from: Server,
	type: Reliable,
	call: ManyAsync,
	data: (payload: ReportPingPayload),
}
