class_name GDScriptEvaluator
extends RefCounted

static func evaluate_expression(expression_str: String, base_instance: Object = null) -> Dictionary:
	var result = {
		"success": false,
		"value": null,
		"error": "",
		"type": ""
	}
	
	# First, apply security checks
	if not DevSecurity.is_expression_safe(expression_str):
		result.error = "Expression contains unsafe operations"
		return result
	
	# Create expression
	var expression = Expression.new()
	var error = expression.parse(expression_str)
	
	if error != OK:
		result.error = "Parse error: " + expression.get_error_text()
		return result
	
	# Execute expression
	var inputs = []
	if base_instance:
		inputs.append(base_instance)
	
	var value = expression.execute(inputs, base_instance)
	
	if expression.has_execute_failed():
		result.error = "Execution error: " + expression.get_error_text()
		return result
	
	result.success = true
	result.value = value
	result.type = _get_type_string(value)
	
	return result

static func evaluate_multiline_code(code: String) -> Dictionary:
	var result = {
		"success": false,
		"output": "",
		"error": ""
	}
	
	# Security check
	if not DevSecurity.is_code_safe(code):
		result.error = "Code contains unsafe operations"
		return result
	
	# For multiline code, we need a different approach
	# This is a simplified implementation - in production, you'd want
	# to create a temporary script and execute it in a sandboxed context
	result.error = "Multiline code execution not yet implemented"
	return result

static func _get_type_string(value) -> String:
	if value == null:
		return "null"
	
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "bool"
		TYPE_INT:
			return "int"
		TYPE_FLOAT:
			return "float"
		TYPE_STRING:
			return "String"
		TYPE_VECTOR2:
			return "Vector2"
		TYPE_VECTOR2I:
			return "Vector2i"
		TYPE_RECT2:
			return "Rect2"
		TYPE_RECT2I:
			return "Rect2i"
		TYPE_VECTOR3:
			return "Vector3"
		TYPE_VECTOR3I:
			return "Vector3i"
		TYPE_TRANSFORM2D:
			return "Transform2D"
		TYPE_VECTOR4:
			return "Vector4"
		TYPE_VECTOR4I:
			return "Vector4i"
		TYPE_PLANE:
			return "Plane"
		TYPE_QUATERNION:
			return "Quaternion"
		TYPE_AABB:
			return "AABB"
		TYPE_BASIS:
			return "Basis"
		TYPE_TRANSFORM3D:
			return "Transform3D"
		TYPE_PROJECTION:
			return "Projection"
		TYPE_COLOR:
			return "Color"
		TYPE_STRING_NAME:
			return "StringName"
		TYPE_NODE_PATH:
			return "NodePath"
		TYPE_RID:
			return "RID"
		TYPE_OBJECT:
			if value.has_method("get_class"):
				return value.get_class()
			return "Object"
		TYPE_CALLABLE:
			return "Callable"
		TYPE_SIGNAL:
			return "Signal"
		TYPE_DICTIONARY:
			return "Dictionary"
		TYPE_ARRAY:
			return "Array"
		TYPE_PACKED_BYTE_ARRAY:
			return "PackedByteArray"
		TYPE_PACKED_INT32_ARRAY:
			return "PackedInt32Array"
		TYPE_PACKED_INT64_ARRAY:
			return "PackedInt64Array"
		TYPE_PACKED_FLOAT32_ARRAY:
			return "PackedFloat32Array"
		TYPE_PACKED_FLOAT64_ARRAY:
			return "PackedFloat64Array"
		TYPE_PACKED_STRING_ARRAY:
			return "PackedStringArray"
		TYPE_PACKED_VECTOR2_ARRAY:
			return "PackedVector2Array"
		TYPE_PACKED_VECTOR3_ARRAY:
			return "PackedVector3Array"
		TYPE_PACKED_COLOR_ARRAY:
			return "PackedColorArray"
		_:
			return "Unknown"