extends Node
## Selects context-aware music through Conductor and keeps cosmetic accents on beat.
class_name MusicDirector

@export var music_stream: AudioStream
@export_range(40.0, 240.0, 1.0) var music_bpm: float = 120.0
@export_range(0.0, 2.0, 0.001) var first_beat_offset: float = 0.0

const TRACKS: Dictionary = {
    &"menu": ["res://assets/audio/music/cosmos_cinematic_120bpm_c_minor.wav", 120.0],
    &"sector_start": ["res://assets/audio/music/cosmos_cinematic_120bpm_c_minor.wav", 120.0],
    &"sector_generic": ["res://assets/audio/music/cosmos_pyscho_125bpm_d_minor.wav", 125.0],
    &"sector_patrol": ["res://assets/audio/music/cosmos_dishonor_140bpm_e_minor.wav", 140.0],
    &"sector_station": ["res://assets/audio/music/cosmos_cinematic_120bpm_c_minor.wav", 120.0],
    &"sector_nebula": ["res://assets/audio/music/cosmos_pyscho_125bpm_d_minor.wav", 125.0],
    &"sector_warp": ["res://assets/audio/music/cosmos_dishonor_140bpm_e_minor.wav", 140.0],
    &"sector_outpost": ["res://assets/audio/music/cosmos_dishonor_140bpm_e_minor.wav", 140.0],
    &"sector_planet": ["res://assets/audio/music/cosmos_pyscho_125bpm_d_minor.wav", 125.0],
    &"sector_moon": ["res://assets/audio/music/cosmos_cinematic_120bpm_c_minor.wav", 120.0],
    &"sector_star": ["res://assets/audio/music/cosmos_dishonor_140bpm_e_minor.wav", 140.0],
    &"pause": ["res://assets/audio/music/cosmos_pyscho_125bpm_d_minor.wav", 125.0],
    &"run_finished": ["res://assets/audio/music/cosmos_dishonor_140bpm_e_minor.wav", 140.0],
}
const SYSTEM_TRACKS: Dictionary = {
    &"sol": ["res://assets/audio/music/cosmos_cinematic_120bpm_c_minor.wav", 120.0],
    &"ember": ["res://assets/audio/music/cosmos_dishonor_140bpm_e_minor.wav", 140.0],
    &"glacial": ["res://assets/audio/music/cosmos_pyscho_125bpm_d_minor.wav", 125.0],
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
    var track_data: Array = SYSTEM_TRACKS.get(system_id, [])
    if track_data.is_empty():
        _play_stream(&"system_fallback", music_stream, music_bpm)
        return
    _play_stream(
        StringName("system_%s" % system_id),
        load(str(track_data[0])) as AudioStream,
        float(track_data[1]),
    )


func _play_track(track_key: StringName) -> void:
	if _current_track_key == track_key:
		return
    var track_data: Array = TRACKS.get(track_key, [])
    if track_data.is_empty():
        Log.error("Unknown music context", track_key)
        return
	var selected_stream: AudioStream = load(str(track_data[0])) as AudioStream
	if selected_stream == null:
		Log.warn("Using the authored fallback stream for a missing music asset", track_key, track_data[0])
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
	Conductor.set_song(selected_stream, selected_bpm, 4, first_beat_offset)
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
