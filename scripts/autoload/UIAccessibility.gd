extends Node

## See docs/UI_FOUNDATION.md. Global accessibility toggles for the glass UI
## system: reduced motion, high readability. Every GlassPanel subscribes to
## settings_changed once and adjusts its own shader uniforms locally — this
## singleton holds state only, it does not touch panels directly.

signal settings_changed

var reduced_motion: bool = false:
	set(value):
		if reduced_motion == value:
			return
		reduced_motion = value
		settings_changed.emit()

var high_readability: bool = false:
	set(value):
		if high_readability == value:
			return
		high_readability = value
		settings_changed.emit()


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled


func set_high_readability(enabled: bool) -> void:
	high_readability = enabled
