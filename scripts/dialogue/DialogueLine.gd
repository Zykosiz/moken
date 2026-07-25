class_name DialogueLine
extends Resource

## See docs/UI_FOUNDATION.md. One line of linear dialogue: who's speaking,
## their portrait (nullable — PortraitFrame renders an empty glass frame
## when unset, no placeholder art required), and the line text.

@export var speaker_name: String = ""
@export var portrait: Texture2D
@export_multiline var text: String = ""
