class_name GlassButton
extends GlassPanel

## Clickable variant of GlassPanel: label text, hover/selection feedback via
## GlassPanel.set_selected(), and a disabled state. No parallel shader/material
## implementation — reuses GlassPanel's pipeline entirely. See docs/UI_FOUNDATION.md.

signal pressed

@export var text: String = "Button":
	set(value):
		text = value
		if _label != null:
			_label.text = value

@export var disabled: bool = false:
	set(value):
		disabled = value
		_update_disabled_visual()

@onready var _label: Label = $ContentMargin/Label


func _ready() -> void:
	super._ready()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_label.text = text
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	_update_disabled_visual()


func _on_mouse_entered() -> void:
	if not disabled:
		set_selected(true)


func _on_mouse_exited() -> void:
	set_selected(false)


func _on_gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit()


func _update_disabled_visual() -> void:
	modulate.a = 0.5 if disabled else 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE if disabled else Control.MOUSE_FILTER_STOP
