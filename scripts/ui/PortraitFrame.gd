class_name PortraitFrame
extends GlassPanel

## Portrait-specific variant of GlassPanel: fixed aspect, finer crack detail,
## reserves a slot for future character-portrait art. No parallel shader or
## script implementation — reuses GlassPanel's material pipeline entirely.
## See docs/UI_FOUNDATION.md.

@export var portrait_texture: Texture2D:
	set(value):
		portrait_texture = value
		if _portrait_rect != null:
			_portrait_rect.texture = value

@onready var _portrait_rect: TextureRect = $ContentMargin/PortraitArt


func _ready() -> void:
	detail_size_px = 10.0
	super._ready()
	if _portrait_rect != null:
		_portrait_rect.texture = portrait_texture
