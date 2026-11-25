extends Node
## Entry point. Hands control to the Flow autoload.
func _ready() -> void:
	Flow.call_deferred("start")
