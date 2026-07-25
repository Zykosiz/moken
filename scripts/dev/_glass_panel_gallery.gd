extends Control
## TEMPORARY verification scene for the GlassPanel component pass. Not a
## shipped screen — delete once GlassPanel/PortraitFrame are confirmed
## working, or once a real screen supersedes it.

@onready var _grid: GridContainer = $VBoxContainer/GridContainer
@onready var _toggle_selected_button: Button = $VBoxContainer/Controls/ToggleSelectedButton
@onready var _horror_slider: HSlider = $VBoxContainer/Controls/HorrorSlider
@onready var _reduced_motion_button: CheckButton = $VBoxContainer/Controls/ReducedMotionButton
@onready var _high_readability_button: CheckButton = $VBoxContainer/Controls/HighReadabilityButton

var _selected_state := false


func _ready() -> void:
	_toggle_selected_button.pressed.connect(_on_toggle_selected_pressed)
	_horror_slider.value_changed.connect(_on_horror_slider_changed)
	_reduced_motion_button.toggled.connect(UIAccessibility.set_reduced_motion)
	_high_readability_button.toggled.connect(UIAccessibility.set_high_readability)
	print("GlassPanel gallery ready: %d panels" % _grid.get_child_count())


func _on_toggle_selected_pressed() -> void:
	_selected_state = not _selected_state
	var first_panel: GlassPanel = _grid.get_child(0)
	first_panel.set_selected(_selected_state)


func _on_horror_slider_changed(value: float) -> void:
	for child in _grid.get_children():
		if child is GlassPanel:
			(child as GlassPanel).set_horror_amount(value)
