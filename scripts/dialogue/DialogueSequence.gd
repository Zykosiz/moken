class_name DialogueSequence
extends Resource

## See docs/UI_FOUNDATION.md. An ordered, linear list of DialogueLine —
## no branching. Authored as a .tres resource and assigned to whatever
## triggers it (e.g. NpcBase.dialogue_sequence).

@export var lines: Array[DialogueLine] = []
