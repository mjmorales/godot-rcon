class_name RCONProtocol
extends RefCounted

enum PacketType {
	AUTH = 3,
	AUTH_RESPONSE = 2,
	EXEC_COMMAND = 2,
	RESPONSE_VALUE = 0
}

static func create_packet(request_id: int, type: int, body: String) -> PackedByteArray:
	var body_bytes = body.to_utf8_buffer()
	var packet_size = 10 + body_bytes.size()
	
	var packet = PackedByteArray()
	
	# Add size (4 bytes, little endian)
	packet.append_array(_int32_to_bytes(packet_size))
	
	# Add request ID (4 bytes, little endian)
	packet.append_array(_int32_to_bytes(request_id))
	
	# Add type (4 bytes, little endian)
	packet.append_array(_int32_to_bytes(type))
	
	# Add body
	packet.append_array(body_bytes)
	
	# Add null terminators
	packet.append(0) # Body null terminator
	packet.append(0) # Packet null terminator
	
	return packet

static func parse_packet(data: PackedByteArray) -> Dictionary:
	if data.size() < 14:
		return {}
	
	# Read size (first 4 bytes)
	var size = _bytes_to_int32(data.slice(0, 4))
	
	# Check if we have the complete packet
	if data.size() < size + 4:
		return {} # Not enough data yet
	
	# Read request ID
	var request_id = _bytes_to_int32(data.slice(4, 8))
	
	# Read type
	var type = _bytes_to_int32(data.slice(8, 12))
	
	# Read body (excluding the two null terminators)
	var body_end = size + 2 # size doesn't include the size field itself
	if body_end > data.size() - 2:
		body_end = data.size() - 2
	
	var body_bytes = data.slice(12, body_end)
	var body = body_bytes.get_string_from_utf8()
	
	return {
		"size": size,
		"request_id": request_id,
		"type": type,
		"body": body
	}

static func _int32_to_bytes(value: int) -> PackedByteArray:
	var bytes = PackedByteArray()
	bytes.resize(4)
	bytes.encode_s32(0, value)
	return bytes

static func _bytes_to_int32(bytes: PackedByteArray) -> int:
	if bytes.size() < 4:
		return 0
	return bytes.decode_s32(0)