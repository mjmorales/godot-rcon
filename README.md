# Godot RCON Server

A Source RCON (Remote Console) protocol server implementation for Godot Engine, allowing remote administration and debugging of Godot applications.

## Features

- **Full RCON Protocol Support**: Implements the Source RCON protocol for secure remote access
- **Authentication**: Password-protected access with per-client authentication
- **REPL Commands**: Built-in GDScript evaluation and execution capabilities
- **Scene Inspection**: Browse and inspect nodes in the scene tree remotely
- **Performance Monitoring**: Access real-time performance metrics
- **Multi-client Support**: Handle multiple simultaneous RCON connections
- **Godot Integration**: Works as a Godot addon with autoload singleton

## Installation

### Method 1: Quick Install (Recommended)

Run this command from your Godot project root directory:

```bash
curl -sSL https://raw.githubusercontent.com/mjmorales/godot-rcon/refs/heads/main/install.sh | bash
```

Or with wget:

```bash
wget -qO- https://raw.githubusercontent.com/mjmorales/godot-rcon/refs/heads/main/install.sh | bash
```

### Method 2: Manual Installation

1. Download or clone this repository
2. Copy the `addons/godot_rcon` folder to your project's `addons/` directory
3. Enable the plugin in Project Settings > Plugins > "Godot RCON Server"

## Configuration

The RCON server can be configured through code:

```gdscript
# Access the autoloaded RCONServer singleton
var rcon_server = get_node("/root/RCONServer")

# Configure server settings
rcon_server.port = 27015  # Default RCON port
rcon_server.password = "your_secure_password"  # Set empty string for no auth

# Built-in REPL and security (enabled by default)
rcon_server.enable_repl = true  # Use built-in command handler
rcon_server.enforce_dev_security = true  # Block unsafe commands

# Start the server
rcon_server.start()

# Stop the server
rcon_server.stop()
```

## Usage

### Starting the Server

```gdscript
func _ready():
    var rcon = get_node("/root/RCONServer")
    rcon.password = "mysecretpassword"
    rcon.port = 27015
    
    # Connect to signals
    rcon.client_connected.connect(_on_client_connected)
    rcon.client_disconnected.connect(_on_client_disconnected)
    rcon.command_received.connect(_on_command_received)
    
    # Start server
    if rcon.start() == OK:
        print("RCON server started on port ", rcon.port)

func _on_command_received(command: String, client_id: int):
    var rcon = get_node("/root/RCONServer")
    
    # Process command using the built-in REPL handler
    var response = REPLCommandHandler.handle_command(command)
    
    # Send response back to client
    rcon.send_response(client_id, response)
```

### Connecting with RCON Client

You can connect using any Source RCON compatible client:

```bash
# Using mcrcon (https://github.com/Tiiffi/mcrcon)
mcrcon -H localhost -P 27015 -p mysecretpassword

# Using rcon-cli (https://github.com/gorcon/rcon-cli)
rcon-cli -a localhost:27015 -p mysecretpassword
```

## Available Commands

The addon includes a REPL command handler with the following built-in commands:

### Expression Evaluation
```
# Direct evaluation (no command prefix needed)
Vector2(10, 20).length()
get_tree().get_nodes_in_group("enemies").size()

# Explicit eval command
eval OS.get_name()
```

### Multi-line Code Execution
```
exec var player = get_node("/root/Main/Player")
player.health = 100
print("Player healed!")
```

### Node Inspection
```
# Inspect a specific node
inspect /root/Main/Player

# List all nodes (optional pattern matching)
nodes
nodes Player
nodes Button
```

### Performance Monitoring
```
# Show available metrics
performance

# Show specific metric
performance fps
performance memory
performance draw_calls
```

### Scene Information
```
# Show current scene
scene
```

### Help
```
# Show available commands
help
```

## Security Considerations

- **Always use a strong password** in production environments
- **Consider IP whitelisting** at the firewall level
- **Disable in release builds** unless specifically needed for production monitoring
- The RCON server has full access to the Godot scripting API - treat it as admin access

### Built-in Security Features

The addon includes lightweight security features that are enabled by default:

- **Dangerous Operation Blocking**: Prevents only truly dangerous operations:
  - OS command execution (`OS.execute`, `OS.shell_open`, `OS.kill`)
  - Direct file system access (`FileAccess.open`, `DirAccess.open`)
  - Script injection (`set_script`, `source_code`, `Expression.new()`)
  - Project settings modification (`ProjectSettings.save`)
  - Network server creation (HTTP/TCP/UDP/WebSocket servers)
- **Output Sanitization**: Limits output size and safely formats complex data structures
- **Permissive by Default**: All other Godot API calls are allowed, including:
  - Node manipulation (`queue_free`, `add_child`, etc.)
  - Resource loading (`load`, `preload`)
  - Property access and modification
  - Signal connections
  - And much more!

To disable security checks entirely:
```gdscript
rcon_server.enforce_dev_security = false
```

To enable command logging for debugging:
```gdscript
rcon_server.log_commands = true
```

## API Reference

### RCONServer

The main server class, autoloaded as `/root/RCONServer`.

#### Properties
- `port: int` - Server port (default: 27015)
- `password: String` - Authentication password (empty = no auth)
- `running: bool` - Server running state (read-only)

#### Methods
- `start() -> Error` - Start the RCON server
- `stop()` - Stop the server and disconnect all clients
- `send_response(client_id: int, response_text: String)` - Send response to specific client

#### Signals
- `command_received(command: String, client_id: int)` - Emitted when a command is received
- `client_connected(client_id: int)` - Emitted when a client connects
- `client_disconnected(client_id: int)` - Emitted when a client disconnects

## Examples

### Custom Command Handler

```gdscript
extends Node

func _ready():
    var rcon = get_node("/root/RCONServer")
    rcon.command_received.connect(_handle_rcon_command)

func _handle_rcon_command(command: String, client_id: int):
    var rcon = get_node("/root/RCONServer")
    var response = ""
    
    # Custom commands
    if command.begins_with("teleport "):
        var coords = command.split(" ")
        if coords.size() >= 3:
            var x = coords[1].to_float()
            var y = coords[2].to_float()
            get_node("/root/Main/Player").position = Vector2(x, y)
            response = "Player teleported to (%f, %f)" % [x, y]
        else:
            response = "Usage: teleport <x> <y>"
    else:
        # Fallback to built-in REPL handler
        response = REPLCommandHandler.handle_command(command)
    
    rcon.send_response(client_id, response)
```

### Monitoring Script

```gdscript
extends Node

var rcon: RCONServer

func _ready():
    rcon = get_node("/root/RCONServer")
    rcon.command_received.connect(_on_command)
    
    # Auto-start server in debug builds
    if OS.is_debug_build():
        rcon.password = OS.get_environment("RCON_PASSWORD")
        if rcon.password.is_empty():
            rcon.password = "debug123"
        rcon.start()

func _on_command(command: String, client_id: int):
    # Log all commands for auditing
    print("[RCON] Client %d: %s" % [client_id, command])
    
    # Process command
    var response = REPLCommandHandler.handle_command(command)
    rcon.send_response(client_id, response)
```

## Troubleshooting

### Server won't start
- Check if the port is already in use
- Ensure you have network permissions
- Try a different port number

### Client can't connect
- Verify the server is running (`rcon_server.running`)
- Check firewall settings
- Ensure correct password is used
- Try connecting to `localhost` first

### Commands not working
- Check the Godot console for error messages
- Ensure nodes exist at the paths you're trying to access
- Verify your GDScript syntax is correct

## License

This addon is provided as-is for use in Godot Engine projects. See LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## Credits

Created for the Godot Engine community. RCON protocol implementation based on the Source RCON specification.