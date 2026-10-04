extends Node
class_name EAEventBankMounter
@export var _audio_bank_resource : EAEventBank
# @export var audioBankResources: Array[EAEventBank]

func _enter_tree():
	# The autoload singleton name can prevent Godot from inferring this class_name type.
	var player: EventAudioAPI = EventAudioAPI.get_instance()
	if player != null:
		player.register_event_bank(_audio_bank_resource)
			
func _exit_tree():
	var player: EventAudioAPI = EventAudioAPI.get_instance()
	if player != null:
		player.unregister_event_bank(_audio_bank_resource)
	
