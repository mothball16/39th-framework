opt server_output = "./Server/Network.luau"
opt client_output = "./Player/Network.luau"

opt remote_scope = "SHARED_STATE"
opt remote_folder = "SHARED_STATE"

event RequestState = {
	from: Client,
	type: Reliable,
	call: ManyAsync,
	data: (),
}

event SyncState = {
	from: Server,
	type: Reliable,
	call: ManyAsync,
	data: (payload: unknown),
}