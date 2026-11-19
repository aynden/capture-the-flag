extends Node
class_name AudioManager

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_idx: int = 0
const POOL_SIZE := 18

func _ready() -> void:
	var files := {
		"shoot": "res://assets/audio/shoot.wav",
		"splat": "res://assets/audio/splat.wav",
		"hit": "res://assets/audio/hit_marker.wav",
		"eliminated": "res://assets/audio/eliminated.wav",
		"dash": "res://assets/audio/dash.wav",
		"reload": "res://assets/audio/reload.wav",
		"flag_pickup": "res://assets/audio/flag_pickup.wav",
		"flag_return": "res://assets/audio/flag_return.wav",
		"flag_capture": "res://assets/audio/flag_capture.wav",
	}
	for key in files:
		var path: String = files[key]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)

	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)


func play_sfx(sound_name: String, volume_db: float = -6.0, pitch_jitter: float = 0.08) -> void:
	if not _streams.has(sound_name):
		return
	var player: AudioStreamPlayer = _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % POOL_SIZE
	player.stream = _streams[sound_name]
	player.volume_db = volume_db
	player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	player.play()
