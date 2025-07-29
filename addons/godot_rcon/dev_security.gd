class_name DevSecurity
extends RefCounted

# Whitelisted Godot API calls for safety
const SAFE_CLASSES = [
	"Node", "Node2D", "Node3D", "Control",
	"Resource", "PackedScene", "Texture2D",
	"Vector2", "Vector3", "Color", "Transform2D",
	"Rect2", "AABB", "Basis", "Transform3D",
	"Quaternion", "Plane", "String", "StringName",
	"Array", "Dictionary", "PackedByteArray",
	"PackedInt32Array", "PackedFloat32Array",
	"PackedStringArray", "PackedVector2Array",
	"PackedVector3Array", "PackedColorArray"
]

const UNSAFE_METHODS = [
	"set_script", "save", "store_var",
	"execute", "kill", "shell_open",
	"request", "http_request", "open_compressed",
	"store_buffer", "store_string", "store_line"
]

const UNSAFE_KEYWORDS = [
	"FileAccess", "DirAccess", 
	"OS.execute", "OS.shell_open", "OS.kill",
	"Engine.set_editor_hint", "ProjectSettings.save",
	"HTTPRequest", "HTTPClient", "StreamPeer",
	"TCPServer", "UDPServer", "PacketPeer", "WebSocket"
]

const MAX_OUTPUT_LENGTH = 2000
const MAX_COLLECTION_ITEMS = 100

static func is_expression_safe(expression: String) -> bool:
	# Check for unsafe methods
	for unsafe in UNSAFE_METHODS:
		if unsafe in expression:
			return false
	
	# Check for unsafe keywords
	for unsafe in UNSAFE_KEYWORDS:
		if unsafe in expression:
			return false
	
	# Check for file system access patterns
	if ".open(" in expression or "FileAccess.open" in expression:
		return false
	
	# Check for potential code injection (but allow eval/exec commands)
	if expression.begins_with("eval ") or expression.begins_with("exec "):
		return true  # These are REPL commands, not injection attempts
	
	# Check for GDScript compilation attempts
	if "GDScript.new()" in expression or "source_code" in expression:
		return false
	
	return true

static func is_code_safe(code: String) -> bool:
	# For multiline code, apply stricter checks
	var lines = code.split("\n")
	
	for line in lines:
		if not is_expression_safe(line):
			return false
		
		# Additional checks for multiline code
		if "class" in line or "extends" in line:
			return false # No class definitions
		
		if "signal" in line or "@export" in line:
			return false # No signal or export declarations
	
	return true

static func sanitize_output(value) -> String:
	var output = ""
	
	if value == null:
		return "null"
	
	# Handle different types
	match typeof(value):
		TYPE_ARRAY:
			output = _sanitize_array(value)
		TYPE_DICTIONARY:
			output = _sanitize_dictionary(value)
		TYPE_OBJECT:
			output = _sanitize_object(value)
		_:
			output = str(value)
	
	# Limit output size
	if output.length() > MAX_OUTPUT_LENGTH:
		output = output.substr(0, MAX_OUTPUT_LENGTH) + "... (truncated)"
	
	return output

static func _sanitize_array(arr: Array) -> String:
	if arr.size() == 0:
		return "[]"
	
	if arr.size() > MAX_COLLECTION_ITEMS:
		return "[Array with %d items]" % arr.size()
	
	var items = []
	for i in mini(arr.size(), 10):
		items.append(sanitize_output(arr[i]))
	
	if arr.size() > 10:
		items.append("... (%d more items)" % (arr.size() - 10))
	
	return "[%s]" % ", ".join(items)

static func _sanitize_dictionary(dict: Dictionary) -> String:
	if dict.size() == 0:
		return "{}"
	
	if dict.size() > MAX_COLLECTION_ITEMS:
		return "{Dictionary with %d items}" % dict.size()
	
	var items = []
	var count = 0
	for key in dict:
		if count >= 10:
			items.append("... (%d more items)" % (dict.size() - 10))
			break
		items.append("%s: %s" % [sanitize_output(key), sanitize_output(dict[key])])
		count += 1
	
	return "{%s}" % ", ".join(items)

static func _sanitize_object(obj: Object) -> String:
	if not obj:
		return "null"
	
	var _class_name = obj.get_class() if obj.has_method("get_class") else "Object"
	
	# For nodes, include path
	if obj is Node:
		var node = obj as Node
		return "%s at %s" % [_class_name, node.get_path()]
	
	# For resources, include resource path if available
	if obj is Resource:
		var res = obj as Resource
		if res.resource_path != "":
			return "%s (%s)" % [_class_name, res.resource_path]
	
	return _class_name