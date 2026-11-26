extends Node
## 100% Procedural WebGL2-Safe Audio Synthesizer (AudioStreamWAV in pure GDScript).
## Generates crisp fantasy SFX & gentle ambient wind/chime loops routed through default_bus_layout.tres
## so there are zero missing external audio files and zero browser playback failures.

const SAMPLE_RATE: int = 22050

var _streams: Dictionary = {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _pool_idx: int = 0
var _ambient_player: AudioStreamPlayer = null
var _ambient_started: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_all_sfx()
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = _safe_bus(&"SFX")
		add_child(p)
		_sfx_pool.append(p)

	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = _safe_bus(&"Ambience")
	_ambient_player.volume_db = -14.0
	_ambient_player.stream = _streams.get("ambient_forest", null)
	add_child(_ambient_player)
	_ambient_player.finished.connect(func() -> void:
		if _ambient_player and _ambient_player.stream:
			_ambient_player.play()
	)
	start_ambient()


func _safe_bus(preferred: StringName) -> StringName:
	if AudioServer.get_bus_index(preferred) != -1:
		return preferred
	return &"Master"


func start_ambient() -> void:
	if _ambient_player and _ambient_player.stream and not _ambient_player.playing:
		_ambient_player.play()
		_ambient_started = true


func play_sfx(sfx_name: String, pitch_min: float = 0.96, pitch_max: float = 1.04, vol_db: float = -3.0) -> void:
	if not _streams.has(sfx_name):
		return
	if _sfx_pool.is_empty():
		return
	var p: AudioStreamPlayer = _sfx_pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % _sfx_pool.size()
	p.stream = _streams[sfx_name]
	p.pitch_scale = randf_range(pitch_min, pitch_max)
	p.volume_db = vol_db
	p.play()


func _build_all_sfx() -> void:
	_streams["footstep"] = _synth_noise_burst(0.085, 110.0, 0.35)
	_streams["jump"] = _synth_sweep(0.18, 220.0, 520.0, 0.32, "sine")
	_streams["double_jump"] = _synth_sweep(0.22, 360.0, 820.0, 0.34, "triangle")
	_streams["dash"] = _synth_noise_sweep(0.24, 920.0, 240.0, 0.38)
	_streams["sword_1"] = _synth_noise_sweep(0.15, 760.0, 260.0, 0.42)
	_streams["sword_2"] = _synth_noise_sweep(0.16, 860.0, 290.0, 0.44)
	_streams["sword_3"] = _synth_chord_sweep(0.28, [330.0, 495.0, 660.0], 0.45)
	_streams["golden_arc"] = _synth_arpeggio([587.3, 880.0, 1174.7], 0.07, 0.38)
	_streams["hit_enemy"] = _synth_impact(0.14, 150.0, 0.5)
	_streams["player_hurt"] = _synth_sweep(0.26, 210.0, 72.0, 0.52, "saw")
	_streams["shard_pickup"] = _synth_arpeggio([659.25, 880.0, 1318.5], 0.08, 0.38)
	_streams["chest_open"] = _synth_arpeggio([440.0, 554.37, 659.25, 880.0], 0.11, 0.42)
	_streams["compass_pulse"] = _synth_bell_chord([523.25, 659.25, 783.99, 1046.5], 0.85, 0.44)
	_streams["wayshrine_ignite"] = _synth_bell_chord([392.0, 493.88, 587.33, 783.99], 1.05, 0.46)
	_streams["rune_activate"] = _synth_bell_chord([440.0, 659.25, 880.0], 0.65, 0.42)
	_streams["dialogue_blip"] = _synth_sweep(0.045, 520.0, 640.0, 0.16, "triangle")
	_streams["quest_start"] = _synth_arpeggio([392.0, 493.88, 587.33, 783.99], 0.1, 0.38)
	_streams["quest_complete"] = _synth_arpeggio([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.12, 0.44)
	_streams["boss_roar"] = _synth_boss_roar(0.85, 0.52)
	_streams["portal_unlock"] = _synth_bell_chord([329.63, 493.88, 659.25, 987.77], 1.15, 0.45)
	_streams["victory_fanfare"] = _synth_arpeggio([523.25, 659.25, 783.99, 1046.5, 1174.66, 1567.98], 0.16, 0.48)
	_streams["ambient_forest"] = _synth_ambient_pad(4.5, 0.18)


func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var s: int = clampi(int(round(clampf(samples[i], -1.0, 1.0) * 32767.0)), -32768, 32767)
		bytes[i * 2] = s & 0xFF
		bytes[i * 2 + 1] = (s >> 8) & 0xFF
	wav.data = bytes
	return wav


func _synth_sweep(dur: float, f0: float, f1: float, amp: float, wave: String) -> AudioStreamWAV:
	var n: int = maxi(int(dur * SAMPLE_RATE), 64)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		var freq: float = lerpf(f0, f1, t)
		ph += (TAU * freq) / float(SAMPLE_RATE)
		var env: float = sin(minf(t * 8.0, 1.0) * PI * 0.5) * pow(1.0 - t, 1.4)
		var v: float = sin(ph)
		if wave == "triangle":
			v = (2.0 / PI) * asin(sin(ph))
		elif wave == "saw":
			v = 2.0 * (fmod(ph / TAU, 1.0)) - 1.0
		buf[i] = v * env * amp
	return _make_wav(buf)


func _synth_noise_burst(dur: float, base_hz: float, amp: float) -> AudioStreamWAV:
	var n: int = maxi(int(dur * SAMPLE_RATE), 64)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var lp: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		var env: float = pow(1.0 - t, 2.2)
		var thud: float = sin(TAU * base_hz * (1.0 - t * 0.5) * (float(i) / float(SAMPLE_RATE)))
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.25)
		buf[i] = (thud * 0.65 + lp * 0.35) * env * amp
	return _make_wav(buf)


func _synth_noise_sweep(dur: float, f0: float, f1: float, amp: float) -> AudioStreamWAV:
	var n: int = maxi(int(dur * SAMPLE_RATE), 64)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 97
	var ph: float = 0.0
	var lp: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		var freq: float = lerpf(f0, f1, t)
		ph += (TAU * freq) / float(SAMPLE_RATE)
		var env: float = sin(minf(t * 6.0, 1.0) * PI * 0.5) * pow(1.0 - t, 1.5)
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.32)
		buf[i] = (sin(ph) * 0.45 + lp * 0.55) * env * amp
	return _make_wav(buf)


func _synth_impact(dur: float, f0: float, amp: float) -> AudioStreamWAV:
	var n: int = maxi(int(dur * SAMPLE_RATE), 64)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	for i in n:
		var t: float = float(i) / float(n)
		var env: float = pow(1.0 - t, 2.4)
		var tone: float = sin(TAU * lerpf(f0, 48.0, t) * (float(i) / float(SAMPLE_RATE)))
		buf[i] = (tone * 0.72 + rng.randf_range(-1.0, 1.0) * 0.28) * env * amp
	return _make_wav(buf)


func _synth_chord_sweep(dur: float, freqs: Array, amp: float) -> AudioStreamWAV:
	var n: int = maxi(int(dur * SAMPLE_RATE), 64)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t: float = float(i) / float(n)
		var sec: float = float(i) / float(SAMPLE_RATE)
		var env: float = sin(minf(t * 10.0, 1.0) * PI * 0.5) * pow(1.0 - t, 1.6)
		var acc: float = 0.0
		for f_var in freqs:
			acc += sin(TAU * float(f_var) * sec)
		buf[i] = (acc / float(maxi(freqs.size(), 1))) * env * amp
	return _make_wav(buf)


func _synth_arpeggio(notes: Array, step_dur: float, amp: float) -> AudioStreamWAV:
	var total_dur: float = float(notes.size()) * step_dur + 0.28
	var n: int = maxi(int(total_dur * SAMPLE_RATE), 64)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for idx in notes.size():
		var freq: float = float(notes[idx])
		var start_i: int = int(float(idx) * step_dur * float(SAMPLE_RATE))
		var note_len: int = int((step_dur + 0.26) * float(SAMPLE_RATE))
		for j in note_len:
			var out_i: int = start_i + j
			if out_i >= n:
				break
			var lt: float = float(j) / float(note_len)
			var env: float = minf(lt * 22.0, 1.0) * pow(1.0 - lt, 1.8)
			var sec: float = float(j) / float(SAMPLE_RATE)
			var sig: float = sin(TAU * freq * sec) * 0.75 + sin(TAU * freq * 2.0 * sec) * 0.25
			buf[out_i] += sig * env * amp * 0.7
	return _make_wav(buf)


func _synth_bell_chord(freqs: Array, dur: float, amp: float) -> AudioStreamWAV:
	var n: int = maxi(int(dur * SAMPLE_RATE), 64)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t: float = float(i) / float(n)
		var sec: float = float(i) / float(SAMPLE_RATE)
		var env: float = minf(t * 28.0, 1.0) * pow(1.0 - t, 1.85)
		var shimmer: float = 0.85 + 0.15 * sin(TAU * 6.0 * sec)
		var acc: float = 0.0
		for f_var in freqs:
			var f: float = float(f_var)
			acc += sin(TAU * f * sec) * 0.72 + sin(TAU * f * 2.0 * sec) * 0.28
		buf[i] = (acc / float(maxi(freqs.size(), 1))) * env * shimmer * amp
	return _make_wav(buf)


func _synth_boss_roar(dur: float, amp: float) -> AudioStreamWAV:
	var n: int = maxi(int(dur * SAMPLE_RATE), 64)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 666
	var lp: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		var sec: float = float(i) / float(SAMPLE_RATE)
		var env: float = sin(minf(t * 6.0, 1.0) * PI * 0.5) * pow(1.0 - t, 1.35)
		var base: float = sin(TAU * lerpf(115.0, 52.0, t) * sec) + 0.5 * sin(TAU * 78.0 * sec)
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.18)
		buf[i] = clampf((base * 0.55 + lp * 0.45) * env * amp, -1.0, 1.0)
	return _make_wav(buf)


func _synth_ambient_pad(dur: float, amp: float) -> AudioStreamWAV:
	var n: int = maxi(int(dur * SAMPLE_RATE), 64)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var lp: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		var sec: float = float(i) / float(SAMPLE_RATE)
		var loop_env: float = sin(t * PI)
		var pad: float = sin(TAU * 146.83 * sec) * 0.4 + sin(TAU * 220.0 * sec) * 0.3 + sin(TAU * 329.63 * sec) * 0.2
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.03)
		buf[i] = (pad * 0.5 + lp * 0.5) * (0.45 + 0.55 * loop_env) * amp
	return _make_wav(buf)
