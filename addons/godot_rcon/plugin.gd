@tool
extends EditorPlugin

const AUTOLOAD_NAME = "RCONServer"
const AUTOLOAD_PATH = "res://addons/godot_rcon/rcon_server.gd"

func _enter_tree():
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	print("Godot RCON Server addon enabled")

func _exit_tree():
	remove_autoload_singleton(AUTOLOAD_NAME)
	print("Godot RCON Server addon disabled")