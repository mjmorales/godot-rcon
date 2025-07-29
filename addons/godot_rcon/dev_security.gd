class_name DevSecurity
extends RefCounted

# Dangerous operations that should be blocked
const DANGEROUS_OPERATIONS = [
	"OS.execute", "OS.shell_open", "OS.kill",
	"FileAccess.open", "DirAccess.open",
	"ProjectSettings.save", "ProjectSettings.save_custom",
	".set_script", ".source_code",
	"Expression.new()", "GDScript.new()"
]

# Network operations that could be dangerous
const DANGEROUS_NETWORK = [
	"HTTPRequest", "HTTPClient", 
	"TCPServer", "UDPServer", "WebSocketServer"
]

const MAX_OUTPUT_LENGTH = 2000
const MAX_COLLECTION_ITEMS = 100

static func is_expression_safe(expression: String) -> bool:
	# Allow REPL commands
	if expression.begins_with("eval ") or expression.begins_with("exec "):
		return true
	
	# Check for dangerous operations
	for danger in DANGEROUS_OPERATIONS:
		if danger in expression:
			return false
	
	# Check for dangerous network operations (optional)
	for danger in DANGEROUS_NETWORK:
		if danger in expression:
			return false
	
	return true

static func is_code_safe(code: String) -> bool:
	# Check each line for dangerous operations
	var lines = code.split("\n")
	
	for line in lines:
		# Check for dangerous operations
		for danger in DANGEROUS_OPERATIONS:
			if danger in line:
				return false
		
		# Check for dangerous network operations
		for danger in DANGEROUS_NETWORK:
			if danger in line:
				return false
	
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