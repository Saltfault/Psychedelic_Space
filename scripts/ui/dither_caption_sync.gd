extends Node
## Moves control captions onto a scene-authored Label so the control artwork can be dithered independently.

@onready var control: Control = get_parent() as Control
@onready var caption: Label = control.get_node("DitherCaption") as Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sync_caption()


func _process(_delta: float) -> void:
	_sync_caption()


func _sync_caption() -> void:
	if control is OptionButton:
		var option_button: OptionButton = control as OptionButton
		caption.text = option_button.get_item_text(option_button.selected) if option_button.selected >= 0 else ""
		return

	if control is Button:
		var button: Button = control as Button
		if not button.text.is_empty():
			caption.text = button.text
			button.text = ""
