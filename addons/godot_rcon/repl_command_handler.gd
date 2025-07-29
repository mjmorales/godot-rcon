class_name REPLCommandHandler
extends RefCounted

const COMMANDS = {
	"eval": "_handle_eval",
	"exec": "_handle_exec",
	"inspect": "_handle_inspect",
	"nodes": "_handle_nodes",
	"scene": "_handle_scene",
	"performance": "_handle_performance",
	"help": "_handle_help"
}

static func handle_command(command: String) -> String:
	var parts = command.split(" ", true, 1)
	if parts.is_empty():
		return "Error: Empty command"
	
	var cmd = parts[0].to_lower()
	var args = parts[1] if parts.size() > 1 else ""
	
	# Create instance to handle commands
	var handler = REPLCommandHandler.new()
	
	# Special case: if no command prefix, treat as eval
	if cmd not in COMMANDS and not command.begins_with("/"):
		return handler._handle_eval(command)
	
	if cmd in COMMANDS:
		var method = COMMANDS[cmd]
		return handler.call(method, args)
	else:
		return "Error: Unknown command '%s'. Type 'help' for available commands." % cmd

func _handle_eval(expression: String) -> String:
	if expression.is_empty():
		return "Error: Empty expression"
	
	var evaluator = load("res://addons/godot_rcon/gdscript_evaluator.gd")
	var result = evaluator.evaluate_expression(expression, null)
	
	if result.success:
		var security = load("res://addons/godot_rcon/dev_security.gd")
		var value_str = security.sanitize_output(result.value)
		return "Result (%s): %s" % [result.type, value_str]
	else:
		return "Error: %s" % result.error

func _handle_exec(code: String) -> String:
	if code.is_empty():
		return "Error: Empty code block"
	
	var evaluator = load("res://addons/godot_rcon/gdscript_evaluator.gd")
	var result = evaluator.evaluate_multiline_code(code)
	
	if result.success:
		return result.output
	else:
		return "Error: %s" % result.error

func _handle_inspect(path: String) -> String:
	if path.is_empty():
		return "Error: No path specified"
	
	# Get scene tree from main viewport
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		return "Error: No scene tree available"
	
	# Handle special paths
	if path == "/root":
		return _inspect_node(tree.root)
	
	var node = tree.root.get_node_or_null(NodePath(path))
	if node == null:
		return "Error: Node not found at path '%s'" % path
	
	return _inspect_node(node)

func _handle_nodes(pattern: String) -> String:
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		return "Error: No scene tree available"
	
	var root = tree.root
	var nodes = []
	
	_collect_nodes(root, nodes, pattern)
	
	if nodes.is_empty():
		return "No nodes found"
	
	var output = "Found %d nodes:\n" % nodes.size()
	for node_path in nodes:
		output += "  %s\n" % node_path
	
	return output

func _handle_scene(_args: String) -> String:
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		return "Error: No scene tree available"
	
	var current_scene = tree.current_scene
	if not current_scene:
		return "No current scene loaded"
	
	return "Current scene: %s (%s)" % [current_scene.name, current_scene.get_class()]

func _handle_performance(metric: String) -> String:
	if metric.is_empty():
		# List available metrics
		return """Available performance metrics:
  fps - Frames per second
  process - Process time (ms)
  physics - Physics process time (ms)
  nodes - Total node count
  orphans - Orphan node count
  objects - Object count
  resources - Resource count
  draw_calls - Draw calls (2D)
  memory - Static memory usage
  memory_max - Peak static memory usage"""
	
	var value = 0.0
	var format = "%.2f"
	
	match metric.to_lower():
		"fps":
			value = Performance.get_monitor(Performance.TIME_FPS)
		"process":
			value = Performance.get_monitor(Performance.TIME_PROCESS)
			format = "%.3f ms"
		"physics":
			value = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
			format = "%.3f ms"
		"nodes":
			value = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
			format = "%d"
		"orphans":
			value = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
			format = "%d"
		"objects":
			value = Performance.get_monitor(Performance.OBJECT_COUNT)
			format = "%d"
		"resources":
			value = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
			format = "%d"
		"draw_calls":
			value = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			format = "%d"
		"memory":
			value = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
			format = "%.2f MB"
		"memory_max":
			value = Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1048576.0
			format = "%.2f MB"
		_:
			return "Error: Unknown metric '%s'" % metric
	
	return format % value

func _handle_help(_args: String) -> String:
	return """Available commands:
  eval <expression>    - Evaluate a GDScript expression (or just type the expression)
  exec <code>         - Execute multi-line GDScript code
  inspect <path>      - Inspect a node or resource at the given path
  nodes [pattern]     - List all nodes (optionally matching pattern)
  scene              - Show current scene information
  performance [metric] - Show performance metrics
  help               - Show this help message
  
Examples:
  Vector2(10, 20).length()
  eval get_node("/root/Main/Player").position
  inspect /root/Main/Player
  nodes Player
  performance fps"""

func _inspect_node(node: Node) -> String:
	if not node:
		return "Error: Invalid node"
	
	var output = "Node: %s (%s)\n" % [node.name, node.get_class()]
	output += "  Path: %s\n" % node.get_path()
	
	# Common properties based on node type
	if node is Node2D:
		var n2d = node as Node2D
		output += "  Position: %s\n" % n2d.position
		output += "  Rotation: %.3f rad (%.1f°)\n" % [n2d.rotation, rad_to_deg(n2d.rotation)]
		output += "  Scale: %s\n" % n2d.scale
		output += "  Global Position: %s\n" % n2d.global_position
	elif node is Node3D:
		var n3d = node as Node3D
		output += "  Position: %s\n" % n3d.position
		output += "  Rotation: %s\n" % n3d.rotation
		output += "  Scale: %s\n" % n3d.scale
	elif node is Control:
		var control = node as Control
		output += "  Position: %s\n" % control.position
		output += "  Size: %s\n" % control.size
		output += "  Anchor: %.2f, %.2f to %.2f, %.2f\n" % [
			control.anchor_left, control.anchor_top,
			control.anchor_right, control.anchor_bottom
		]
	
	# Child count
	var child_count = node.get_child_count()
	if child_count > 0:
		output += "  Children: %d\n" % child_count
		if child_count <= 10:
			for child in node.get_children():
				output += "    - %s (%s)\n" % [child.name, child.get_class()]
		else:
			output += "    (too many to list)\n"
	
	return output

func _collect_nodes(node: Node, nodes: Array, pattern: String):
	if pattern.is_empty() or pattern in node.name or pattern in node.get_class():
		nodes.append(node.get_path())
	
	for child in node.get_children():
		_collect_nodes(child, nodes, pattern)
