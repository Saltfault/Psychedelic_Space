extends Node
## Selects context-aware music through Conductor and keeps cosmetic accents on beat.
class_name MusicDirector

@export var music_stream: AudioStream
@export var track_streams: Array[AudioStream] = []
@export_range(40.0, 240.0, 1.0) var music_bpm: float = 120.0
@export_range(0.0, 2.0, 0.001) var first_beat_offset: float = 0.0

## Every stream index used by TRACKS/SYSTEM_TRACKS below. The array itself is
## authored on the MusicDirector scene (scenes/music_director.tscn):
## 0 menu/intro theme, 1 hot loop, 2 tense loop, 3 Rain, 4 Voices, 5 Emotional
## Guitar, 6 Disconnect, 7 Mistake, 8 Rogue, 9 Omens, 10 RIP, 11 Swords, 12 Forces.
const TRACKS: Dictionary = {
	&"menu": [0, 120.0],
	&"sector_start": [3, 130.0],
	&"sector_generic": [12, 130.0],
	&"sector_patrol": [11, 130.0],
	&"sector_station": [4, 95.0],
	&"sector_nebula": [6, 144.0],
	&"sector_warp": [8, 150.0],
	&"sector_outpost": [9, 155.0],
	&"sector_planet": [5, 150.0],
	&"sector_moon": [7, 150.0],
	&"sector_star": [1, 125.0],
	&"run_finished": [10, 140.0],
}
const SYSTEM_TRACKS: Dictionary = {
	&"frontier": [0, 120.0],
	&"ember": [9, 155.0],
	&"glacial": [11, 130.0],
}

## Absolute fallback library: indexed identically to track_streams. Used when the
## scene-authored array does not survive scene instancing (indexes 0/3 were null
## at runtime in the player's 4.7.2-steam build, so every request fell back to the
## menu theme).
const TRACK_STREAM_PATHS: Array[String] = [
	"res://assets/audio/music/cosmos_cinematic_120bpm_c_minor.wav",
	"res://assets/audio/music/cosmos_pyscho_125bpm_d_minor.wav",
	"res://assets/audio/music/cosmos_dishonor_140bpm_e_minor.wav",
	"res://assets/audio/music/rain_130bpm_a_minor.wav",
	"res://assets/audio/music/voices_95bpm_g_minor.wav",
	"res://assets/audio/music/emotional_guitar_150bpm_e_minor.wav",
	"res://assets/audio/music/disconnect_144bpm_d_minor.wav",
	"res://assets/audio/music/mistake_150bpm_dsharp_minor.wav",
	"res://assets/audio/music/rogue_150bpm_d_minor.wav",
	"res://assets/audio/music/omens_155bpm_a_minor.wav",
	"res://assets/audio/music/rip_140bpm_f_minor.wav",
	"res://assets/audio/music/swords_130bpm_g_minor.wav",
	"res://assets/audio/music/forces_130bpm_b_minor.wav",
]

var _current_track_key: StringName = &""
var _gameplay_track_key: StringName = &""
## Survives across scene changes so a new MusicDirector instance in the next
## scene recognizes that the SAME track is already playing and lets the single
## shared Conductor keep playing it without a restart (menu -> ship select).
static var _playing_track_key: StringName = &""


func _ready() -> void:
	# The 13-entry library is authored on scenes/music_director.tscn; some engine
	# builds drop it during scene instancing, so repair it here when empty.
	if track_streams.size() != TRACK_STREAM_PATHS.size():
		track_streams.clear()
		for stream_path in TRACK_STREAM_PATHS:
			track_streams.append(load(stream_path) as AudioStream)
		Log.info("Music track library loaded from script", track_streams.size())
	Conductor.bus = "Music"
	# The shared music player must run while the tree is paused, or the pause
	# menu would silence the sector theme it is meant to sit atop of.
	Conductor.process_mode = Node.PROCESS_MODE_ALWAYS
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
	Log.info("Sector music requested", track_key, "outpost_objective=", has_outpost_objective)
	_play_track(track_key)


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
	# Continuity check uses the SHARED key (see _playing_track_key): a MusicDirector
	# freshly instanced by the next scene sees the track already playing and does
	# not restart the shared Conductor.
	if _playing_track_key == track_key:
		_current_track_key = track_key
		Log.info("Music request skipped; track already playing", track_key)
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
	# Looping is embedded on the import side instead (edit/loop_mode=1 in each
	# cosmos_*.wav.import) because mutating a QOA-compressed imported stream's
	# loop at runtime produced a playing-but-silent playback on Godot 4.7.
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
	# MODIFIED (Issue 1): schedule the actual start one frame later. Stop/swap/play
	# inside the same frame can be dropped by some audio backends - it looks and
	# behaves exactly like "the music never plays". Deferring play() removes that
	# window, and the retry below recovers one dropped start automatically.
	_deferred_play(track_key, selected_stream)


## Deferred start of the shared Conductor player; waits one frame so the stop(),
## stream swap and play() land in separate audio-server ticks. The stream is
## passed along: the deferred body only needs these two values.
func _deferred_play(track_key: StringName, selected_stream: AudioStream) -> void:
	await get_tree().process_frame
	Conductor.play()
	await get_tree().process_frame
	if not Conductor.playing:
		Log.error("Conductor did not start the selected track; retrying once", track_key)
		Conductor.play()
		if not Conductor.playing:
			Log.error("Conductor start failed twice; audio output may be muted or missing", track_key)
			return
	_current_track_key = track_key
	# Publish the shared key ONLY after playback is confirmed, so a failed start
	# leaves the previous track's continuity intact.
	_playing_track_key = track_key
	Log.info("Music track started", track_key, selected_stream.resource_path)


func _exit_tree() -> void:
	if Conductor.beat.is_connected(_on_beat):
		Conductor.beat.disconnect(_on_beat)


func _on_beat(beat_position: int) -> void:
	# Music may pulse visuals; combat input and timing remain immediate.
	if beat_position % 4 == 0:
		get_tree().call_group("beat_visuals", "pulse_on_downbeat")
