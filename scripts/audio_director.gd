extends Node
## Lightweight original synthesized interaction sounds, no downloads.
##
## There is deliberately no looping ambience bed: the old filtered-white-noise
## "wind" read as a constant hiss on headphones. The world is quiet between
## cues now; any future ambience has to be a real, band-limited loop with a slow
## gust envelope, not raw noise.
var muted: bool = false
var master_volume: float = 1.0
var cues: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var next_voice: int = 0
var random := RandomNumberGenerator.new()

func _ready() -> void:
	random.seed = 803
	for id in ["melee", "cast", "block", "move", "support", "reward", "death"]:
		cues[id] = _build_cue(id)
	for i in range(16):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -14
		add_child(voice)
		voices.append(voice)

func _build_cue(id: String) -> AudioStreamWAV:
	var duration: float = 0.24
	var frequency: float = 220.0
	match id:
		"melee": frequency = 110.0
		"cast": frequency = 440.0
		"block": frequency = 160.0
		"move": frequency = 310.0
		"support": frequency = 660.0; duration = 0.55
		"reward": frequency = 880.0; duration = 0.35
		"death": frequency = 65.0; duration = 1.0
	var rate := 22050
	var count := int(duration * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	for index in range(count):
		var time: float = float(index) / rate
		var progress: float = time / duration
		var envelope: float = sin(progress * PI) * (1 - progress)
		var pitch: float = frequency * (1 - progress * 0.25)
		var sample: float = sin(time * TAU * pitch) * 0.20 + sin(time * TAU * pitch * 1.5) * 0.06
		if id == "melee" or id == "move":
			sample += random.randf_range(-1, 1) * 0.17 * (1 - progress)
		data.encode_s16(index * 2, int(sample * envelope * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream

func cue(id: String) -> void:
	if muted or not cues.has(id):
		return
	var sound: AudioStreamPlayer = voices[next_voice]
	for voice in voices:
		if not voice.playing:
			sound = voice
			break
	next_voice = (next_voice + 1) % voices.size()
	sound.stop()
	sound.stream = cues[id]
	sound.play()

func toggle_mute() -> void:
	muted = not muted
	_apply_volume()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_volume()

func _apply_volume() -> void:
	var silent: bool = muted or master_volume <= 0.0
	var gain_db: float = linear_to_db(maxf(master_volume, 0.0001))
	for voice: AudioStreamPlayer in voices:
		voice.volume_db = -80.0 if silent else -14.0 + gain_db

