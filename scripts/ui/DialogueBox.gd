class_name DialogueBox
extends CanvasLayer

## See docs/UI_FOUNDATION.md. Presentational only — DialogueManager drives
## this via show_line()/complete_reveal(); this script doesn't decide when
## to advance or who's talking beyond what it's told.

const CHARACTERS_PER_SECOND := 45.0

@onready var _root: Control = $Root
@onready var _portrait_frame: PortraitFrame = $Root/PortraitFrame
@onready var _text_pane: GlassPanel = $Root/TextPane
@onready var _dialogue_label: RichTextLabel = $Root/TextPane/ContentMargin/DialogueText
@onready var _name_shard: GlassPanel = $Root/NameShard
@onready var _speaker_label: Label = $Root/NameShard/ContentMargin/SpeakerLabel

var _reveal_time: float = 0.0
var _is_revealing: bool = false


func _ready() -> void:
	layer = 10
	_root.visible = false
	_text_pane.set_background_busyness(0.8)
	set_process(false)


func open() -> void:
	_root.visible = true


func close() -> void:
	_root.visible = false
	set_process(false)


func show_line(line: DialogueLine) -> void:
	_speaker_label.text = line.speaker_name
	_portrait_frame.portrait_texture = line.portrait
	_dialogue_label.text = line.text
	_dialogue_label.visible_characters = 0

	if UIAccessibility.reduced_motion:
		_dialogue_label.visible_characters = -1
		_is_revealing = false
		set_process(false)
	else:
		_reveal_time = 0.0
		_is_revealing = true
		set_process(true)


func is_revealing() -> bool:
	return _is_revealing


func complete_reveal() -> void:
	if not _is_revealing:
		return
	_dialogue_label.visible_characters = -1
	_is_revealing = false
	set_process(false)


func _process(delta: float) -> void:
	if not _is_revealing:
		return
	_reveal_time += delta
	var total := _dialogue_label.get_total_character_count()
	var char_count := int(_reveal_time * CHARACTERS_PER_SECOND)
	_dialogue_label.visible_characters = mini(char_count, total)
	if char_count >= total:
		_is_revealing = false
		set_process(false)
