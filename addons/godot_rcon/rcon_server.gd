extends Node

signal command_received(command: String, client_id: int)
signal client_connected(client_id: int)
signal client_disconnected(client_id: int)

# Enable built-in command handling
var enable_repl: bool = true
var enforce_dev_security: bool = true

# Preload required classes
const RCONProtocol = preload("res://addons/godot_rcon/rcon_protocol.gd")
const REPLCommandHandler = preload("res://addons/godot_rcon/repl_command_handler.gd")
const DevSecurity = preload("res://addons/godot_rcon/dev_security.gd")

var tcp_server: TCPServer
var port: int = 27015
var password: String = ""
var clients: Dictionary = {}
var running: bool = false
var next_client_id: int = 1

# Client state tracking
class ClientInfo:
	var stream: StreamPeerTCP
	var authenticated: bool = false
	var buffer: PackedByteArray = PackedByteArray()
	var id: int
	var last_request_id: int = 0

func start() -> Error:
	tcp_server = TCPServer.new()
	var err = tcp_server.listen(port)
	if err == OK:
		running = true
		set_process(true)
	return err

func stop():
	running = false
	set_process(false)
	
	if tcp_server:
		tcp_server.stop()
		
	for client_id in clients:
		var client_info = clients[client_id]
		if client_info.stream:
			client_info.stream.disconnect_from_host()
	clients.clear()

func _process(_delta):
	if not running or not tcp_server:
		return
	
	# Check for new connections
	if tcp_server.is_connection_available():
		var stream = tcp_server.take_connection()
		if stream:
			_handle_new_client(stream)
	
	# Process existing clients
	var clients_to_remove = []
	for client_id in clients:
		var client_info = clients[client_id]
		
		# Check connection status
		var status = client_info.stream.get_status()
		if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
			clients_to_remove.append(client_id)
			continue
		
		# Read available data
		if status == StreamPeerTCP.STATUS_CONNECTED:
			var available = client_info.stream.get_available_bytes()
			if available > 0:
				var data = client_info.stream.get_data(available)
				if data[0] == OK:
					client_info.buffer.append_array(data[1])
					_process_client_buffer(client_id)
	
	# Remove disconnected clients
	for client_id in clients_to_remove:
		_remove_client(client_id)

func _handle_new_client(stream: StreamPeerTCP):
	var client_id = next_client_id
	next_client_id += 1
	
	var client_info = ClientInfo.new()
	client_info.stream = stream
	client_info.id = client_id
	
	clients[client_id] = client_info
	client_connected.emit(client_id)
	print("[RCONServer] Client %d connected" % client_id)

func _remove_client(client_id: int):
	if client_id in clients:
		clients[client_id].stream.disconnect_from_host()
		clients.erase(client_id)
		client_disconnected.emit(client_id)
		print("[RCONServer] Client %d disconnected" % client_id)

func _process_client_buffer(client_id: int):
	var client_info = clients[client_id]
	
	# Try to parse packets from buffer
	while client_info.buffer.size() >= 14: # Minimum packet size
		var packet = RCONProtocol.parse_packet(client_info.buffer)
		if packet.is_empty():
			break
		
		# Remove processed bytes from buffer
		var packet_total_size = packet["size"] + 4 # Size field itself is 4 bytes
		if client_info.buffer.size() >= packet_total_size:
			client_info.buffer = client_info.buffer.slice(packet_total_size)
			_handle_packet(client_id, packet)
		else:
			break # Not enough data yet

func _handle_packet(client_id: int, packet: Dictionary):
	var client_info = clients[client_id]
	
	match packet["type"]:
		RCONProtocol.PacketType.AUTH:
			_handle_auth(client_id, packet)
		RCONProtocol.PacketType.EXEC_COMMAND:
			if client_info.authenticated:
				client_info.last_request_id = packet["request_id"]
				var command = packet["body"]
				
				# Use built-in REPL if enabled
				if enable_repl:
					# Security check if enabled
					if enforce_dev_security:
						if not DevSecurity.is_expression_safe(command) and not DevSecurity.is_code_safe(command):
							send_response(client_id, "Error: Command blocked by security policy")
							return
					
					# Execute command through REPL handler
					var response = REPLCommandHandler.handle_command(command)
					send_response(client_id, response)
				else:
					# Emit signal for custom handling
					command_received.emit(command, client_id)
			else:
				_send_error_response(client_id, packet["request_id"], "Not authenticated")
		_:
			print("[RCONServer] Unknown packet type: %d" % packet["type"])

func _handle_auth(client_id: int, packet: Dictionary):
	var client_info = clients[client_id]
	
	if packet["body"] == password or password == "":
		client_info.authenticated = true
		# Send successful auth response
		var response = RCONProtocol.create_packet(
			packet["request_id"],
			RCONProtocol.PacketType.AUTH_RESPONSE,
			""
		)
		_send_packet(client_id, response)
		print("[RCONServer] Client %d authenticated" % client_id)
	else:
		# Send failed auth response
		var response = RCONProtocol.create_packet(
			-1, # -1 indicates auth failure
			RCONProtocol.PacketType.AUTH_RESPONSE,
			""
		)
		_send_packet(client_id, response)
		print("[RCONServer] Client %d authentication failed" % client_id)

func send_response(client_id: int, response_text: String):
	if client_id not in clients:
		return
	
	var client_info = clients[client_id]
	if not client_info.authenticated:
		return
	
	# Use the last request ID from this client
	var packet = RCONProtocol.create_packet(
		client_info.last_request_id,
		RCONProtocol.PacketType.RESPONSE_VALUE,
		response_text
	)
	_send_packet(client_id, packet)

func _send_error_response(client_id: int, request_id: int, error_text: String):
	var packet = RCONProtocol.create_packet(
		request_id,
		RCONProtocol.PacketType.RESPONSE_VALUE,
		"Error: " + error_text
	)
	_send_packet(client_id, packet)

func _send_packet(client_id: int, packet_data: PackedByteArray):
	if client_id not in clients:
		return
	
	var client_info = clients[client_id]
	if client_info.stream.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		client_info.stream.put_data(packet_data)