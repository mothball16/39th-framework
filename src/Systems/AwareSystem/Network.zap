opt server_output = "./Ping_Server/Network.luau"
opt client_output = "./Ping_Client/Network.luau"
opt types_output = "./Ping_Framework/Core/NetworkTypes.luau"
opt remote_scope = "PING"

event RequestPing = {
	from: Client,
	type: Reliable,
	call: SingleAsync,
	data: (Position: Vector3),
}

event ReportPing = {
	from: Server,
	type: Reliable,
	call: ManyAsync,
	data: (Position: Vector3),
}