extends PanelContainer
## Saved station drop target that forwards dragged module data to the shop controller.
class_name ModuleSellDropZone

signal module_dropped(payload: Variant)


func _can_drop_data(_at_position: Vector2, payload: Variant) -> bool:
	return payload is Dictionary and payload.get("module") is ModuleDefinition


func _drop_data(_at_position: Vector2, payload: Variant) -> void:
	if payload is Dictionary:
		module_dropped.emit(payload)
