extends Node
## Selects context-aware music through Conductor and keeps cosmetic accents on beat.
class_name MusicDirector

@export var music_stream: AudioStream
@export var track_streams: Array[AudioStream] = []
@export_range(40.0, 240.0, 1.0) var music_bpm: float = 120.0
@export_range(0.0, 2.0, 0.001) var first_beat_offset: float = 0.0

const TRACKS: Dictionary = {
	&"menu": [0, 120.0],
	&"sector_start": [0, 120.0],
	&"sector_generic": [1, 125.0],
	&"sector_patrol": [2, 140.0],
	&"sector_station": [0, 120.0],
	&"sector_nebula": [1, 125.0],
	&"sector_warp": [2, 140.0],
	&"sector_outpost": [2, 140.0],
	&"sector_planet": [1, 125.0],
	&"sector_moon": [0, 120.0],
	&"sector_star": [2, 140.0],
	&"pause": [1, 125.0],
	&"run_finished": [2, 140.0],
}
const SYSTEM_TRACKS: Dictionary = {
	&"frontier": [0, 120.0],
	&"ember": [2, 140.0],
	&"glacial": [1, 125.0],
}

var _current_track_key: StringName = &""
var _gameplay_track_key: StringName = &""


func _ready() -> void:
	Conductor.bus = "Music"
	add_to_group("music_director")
	if not Conductor.beat.is_connected(_on_beat):
		Conductor.beat.connect(_on_beat)


## Play the title-screen track.
func play_main_menu() -> void:
	_play_track(&"menu")


## Play the track matching the active sector role, or its outpost objective.
func play_sector_track(sector_id: String, has_outpost_objective: bool = false) -> void:
	var track_key: StringName = StringName("sector_%s" % sector_id)
	if has_outpost_objective:
		track_key = &"sector_outpost"
	if not TRACKS.has(track_key):
		track_key = &"sector_generic"
	_gameplay_track_key = track_key
	_play_track(track_key)


## Play the dedicated pause-menu track without losing the active gameplay context.
func play_pause_track() -> void:
	_play_track(&"pause")


## Restore the active sector track when play resumes.
func resume_gameplay_track() -> void:
	if _gameplay_track_key != &"":
		_play_track(_gameplay_track_key)


## Replace gameplay music with the run's terminal-screen track.
func play_run_finished() -> void:
	_play_track(&"run_finished")


## Keep the authored solar-system themes available for callers without a sector role.
func play_system_track(system_id: StringName) -> void:
	if not SYSTEM_TRACKS.has(system_id):
		_play_stream(&"system_fallback", music_stream, music_bpm)
		return
	_play_track_data(StringName("system_%s" % system_id), SYSTEM_TRACKS[system_id])


func _play_track(track_key: StringName) -> void:
	if _current_track_key == track_key:
		return
	if not TRACKS.has(track_key):
		Log.error("Unknown music context", track_key)
		return
	_play_track_data(track_key, TRACKS[track_key])


func _play_track_data(track_key: StringName, track_data: Array) -> void:
	var stream_index: int = int(track_data[0])
	var selected_stream: AudioStream = (
		track_streams[stream_index]
		if stream_index >= 0 and stream_index < track_streams.size()
		else null
	)
	if selected_stream == null:
		Log.warn("Using the scene-authored fallback stream for a missing music asset", track_key, stream_index)
		selected_stream = music_stream
	_play_stream(track_key, selected_stream, float(track_data[1]))


func _play_stream(track_key: StringName, selected_stream: AudioStream, selected_bpm: float) -> void:
	if selected_stream == null:
		Log.error("Missing music stream", track_key)
		return
	if selected_bpm <= 0.0:
		Log.error("Music BPM must be positive", track_key, selected_bpm)
		return
	# Imported loop files may not include loop metadata in their source WAV.
	if selected_stream is AudioStreamWAV:
		(selected_stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	var music_bus_index: int = AudioServer.get_bus_index("Music")
	if music_bus_index < 0:
		Log.error("Music bus is missing; routing the selected track to Master", track_key)
		Conductor.bus = "Master"
	else:
		Conductor.bus = "Music"
	Conductor.stop()
	# Conductor.set_song only refreshes BPM/offset when its stream changes. Clear it
	# first so revisiting the same scene-authored track always restarts consistently.
	Conductor.stream = null
	Conductor.set_song(selected_stream, selected_bpm, 4, first_beat_offset)
	Conductor.stream_paused = false
	Conductor.play()
	if not Conductor.playing:
		Log.error("Conductor did not start the selected track", track_key)
		return
	_current_track_key = track_key
	Log.info("Music track started", track_key, selected_stream.resource_path)


func _exit_tree() -> void:
	if Conductor.beat.is_connected(_on_beat):
		Conductor.beat.disconnect(_on_beat)


func _on_beat(beat_position: int) -> void:
	# Music may pulse visuals; combat input and timing remain immediate.
	if beat_position % 4 == 0:
		get_tree().call_group("beat_visuals", "pulse_on_downbeat")
