extends Node
## 100% Procedural WebGL2-Safe Fantasy Audio Synthesizer (44.1 kHz 16-bit AudioStreamWAV).
## Zero static hiss, zero harsh beeps: velvety soft-earth footsteps (3 organic variations),
## serene seamless 12s twilight harp & warm pad ambient soundtrack, and warm musical SFX.

const SAMPLE_RATE: int = 44100

var master_volume: float = 0.85
var music_volume: float = 0.72
var sfx_volume: float = 0.85
var is_muted: bool = false

var _streams: Dictionary = {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _pool_idx: int = 0
var _step_idx: int = 0
var _ambient_player: AudioStreamPlayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_all_sfx()
	for i in 12:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
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
	set_master_volume(master_volume)
	set_music_volume(music_volume)
	set_sfx_volume(sfx_volume)
	start_ambient()


func _safe_bus(preferred: StringName) -> StringName:
	if AudioServer.get_bus_index(preferred) != -1:
		return preferred
	return &"Master"


func set_master_volume(val: float) -> void:
	master_volume = clampf(val, 0.0, 1.0)
	var idx: int = AudioServer.get_bus_index(&"Master")
	if idx != -1:
		AudioServer.set_bus_mute(idx, is_muted or master_volume <= 0.01)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(master_volume, 0.001)))


func set_music_volume(val: float) -> void:
	music_volume = clampf(val, 0.0, 1.0)
	var idx: int = AudioServer.get_bus_index(&"Ambience")
	if idx != -1:
		AudioServer.set_bus_mute(idx, music_volume <= 0.01)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(music_volume, 0.001)))
	elif _ambient_player:
		_ambient_player.volume_db = -80.0 if music_volume <= 0.01 else (-14.0 + linear_to_db(maxf(music_volume, 0.001)))


func set_sfx_volume(val: float) -> void:
	sfx_volume = clampf(val, 0.0, 1.0)
	var idx: int = AudioServer.get_bus_index(&"SFX")
	if idx != -1:
		AudioServer.set_bus_mute(idx, sfx_volume <= 0.01)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(sfx_volume, 0.001)))


func set_muted(muted: bool) -> void:
	is_muted = muted
	set_master_volume(master_volume)


func start_ambient() -> void:
	if _ambient_player and _ambient_player.stream and not _ambient_player.playing:
		_ambient_player.play()


func play_sfx(sfx_name: String, pitch_min: float = 0.96, pitch_max: float = 1.04, vol_db: float = -5.0) -> void:
	if is_muted or master_volume <= 0.01 or sfx_volume <= 0.01:
		return
	var key: String = sfx_name
	if key == "footstep":
		_step_idx = (_step_idx + 1) % 3
		key = "footstep_%d" % (_step_idx + 1)
	if not _streams.has(key):
		return
	if _sfx_pool.is_empty():
		return
	var p: AudioStreamPlayer = _sfx_pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % _sfx_pool.size()
	p.stream = _streams[key]
	var lo: float = clampf(minf(pitch_min, pitch_max), 0.5, 2.0)
	var hi: float = clampf(maxf(pitch_min, pitch_max), 0.5, 2.0)
	p.pitch_scale = randf_range(lo, hi)
	p.volume_db = clampf(vol_db, -40.0, 2.0)
	p.play()


func _build_all_sfx() -> void:
	# 3 ultra-soft, velvety acoustic moss-step taps (warm woody heel body, ZERO static hiss!)
	_streams["footstep_1"] = _synth_soft_moss_step(0.052, 92.0, 48.0, 17, 0.24)
	_streams["footstep_2"] = _synth_soft_moss_step(0.048, 86.0, 44.0, 41, 0.22)
	_streams["footstep_3"] = _synth_soft_moss_step(0.055, 96.0, 50.0, 79, 0.23)
	_streams["footstep"] = _streams["footstep_1"]

	_streams["land"] = _synth_soft_moss_step(0.088, 78.0, 38.0, 103, 0.36)
	_streams["jump"] = _synth_warm_sweep(0.14, 240.0, 440.0, 0.22)
	_streams["double_jump"] = _synth_warm_sweep(0.18, 360.0, 680.0, 0.24)
	_streams["dash"] = _synth_velvet_whoosh(0.19, 340.0, 160.0, 0.26)

	# Smooth velvet blade swings + crystalline combo finisher
	_streams["sword_1"] = _synth_velvet_whoosh(0.13, 420.0, 190.0, 0.30)
	_streams["sword_2"] = _synth_velvet_whoosh(0.14, 480.0, 220.0, 0.32)
	_streams["sword_3"] = _synth_bell_chord([329.63, 493.88, 659.25], 0.34, 0.32)
	_streams["golden_arc"] = _synth_harp_arpeggio([587.33, 880.0, 1174.66], 0.06, 0.30)

	var hit_wav: AudioStreamWAV = _synth_soft_impact(0.12, 132.0, 0.38)
	_streams["hit_enemy"] = hit_wav
	_streams["hit_impact"] = hit_wav
	_streams["player_hurt"] = _synth_soft_impact(0.20, 108.0, 0.42)

	_streams["heal"] = _synth_harp_arpeggio([523.25, 659.25, 783.99, 1046.5], 0.08, 0.30)
	_streams["shard_pickup"] = _synth_harp_arpeggio([659.25, 880.0, 1318.5], 0.065, 0.28)
	_streams["chest_open"] = _synth_harp_arpeggio([440.0, 554.37, 659.25, 880.0], 0.095, 0.32)
	_streams["compass_pulse"] = _synth_bell_chord([523.25, 659.25, 783.99, 1046.5], 0.95, 0.34)
	_streams["wayshrine_ignite"] = _synth_bell_chord([392.0, 493.88, 587.33, 783.99], 1.10, 0.36)
	_streams["rune_activate"] = _synth_bell_chord([440.0, 659.25, 880.0], 0.72, 0.32)

	var blip_wav: AudioStreamWAV = _synth_soft_pluck(0.045, 540.0, 0.13)
	_streams["dialogue_blip"] = blip_wav
	_streams["dialogue_tick"] = blip_wav
	_streams["ui_click"] = _synth_soft_pluck(0.052, 660.0, 0.18)

	_streams["quest_start"] = _synth_harp_arpeggio([392.0, 493.88, 587.33, 783.99], 0.09, 0.30)
	_streams["quest_complete"] = _synth_harp_arpeggio([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.10, 0.34)
	_streams["boss_roar"] = _synth_boss_rumble(0.75, 0.38)
	_streams["portal_unlock"] = _synth_bell_chord([329.63, 493.88, 659.25, 987.77], 1.15, 0.36)
	_streams["victory_fanfare"] = _synth_harp_arpeggio([523.25, 659.25, 783.99, 1046.5, 1174.66, 1567.98], 0.14, 0.38)

	# Serene, zero-static 12-second looping twilight Celtic harp & warm forest pad soundtrack
	_streams["ambient_forest"] = _synth_twilight_forest_music(12.0, 0.24)


func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var s: int = clampi(int(round(clampf(samples[i], -1.0, 1.0) * 32767.0)), -32768, 32767)
		bytes[i * 2] = s & 0xFF
		bytes[i * 2 + 1] = (s >> 8) & 0xFF
	wav.data = bytes
	return wav


func _synth_soft_moss_step(dur: float, f0: float, f1: float, seed_val: int, amp: float) -> AudioStreamWAV:
	## Silky acoustic soft-earth heel tap: warm low pitch-drop body + tiny heavily-smoothed moss brush.
	var n: int = maxi(int(dur * SAMPLE_RATE), 128)
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_val
	var ph: float = 0.0
	var lp1: float = 0.0
	var lp2: float = 0.0
	var lp3: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		# Raised-cosine bell attack + smooth decay (zero click!)
		var env: float = sin(minf(t * 3.8, 1.0) * PI * 0.5) * pow(1.0 - t, 2.2)
		ph += (TAU * lerpf(f0, f1, t)) / float(SAMPLE_RATE)
		var body: float = sin(ph) * 0.88 + sin(ph * 2.0) * 0.12
		# 3-pole heavily smoothed soft brush (no static/hiss)
		var w: float = rng.randf_range(-1.0, 1.0)
		lp1 = lerpf(lp1, w, 0.06)
		lp2 = lerpf(lp2, lp1, 0.06)
		lp3 = lerpf(lp3, lp2, 0.06)
		buf[i] = (body * 0.86 + lp3 * 0.35) * env * amp
	return _make_wav(buf)


func _synth_warm_sweep(dur: float, f0: float, f1: float, amp: float) -> AudioStreamWAV:
	var n: int = maxi(int(dur * SAMPLE_RATE), 128)
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n)
	var ph: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		var env: float = sin(t * PI) * pow(1.0 - t, 1.15)
		ph += (TAU * lerpf(f0, f1, t)) / float(SAMPLE_RATE)
		var sig: float = sin(ph) * 0.82 + sin(ph * 1.5) * 0.18
		buf[i] = sig * env * amp
	return _make_wav(buf)


func _synth_velvet_whoosh(dur: float, f0: float, f1: float, amp: float) -> AudioStreamWAV:
	var n: int = maxi(int(dur * SAMPLE_RATE), 128)
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(f0) + 29
	var lp1: float = 0.0
	var lp2: float = 0.0
	var lp3: float = 0.0
	var ph: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		var env: float = sin(minf(t * 4.0, 1.0) * PI * 0.5) * pow(1.0 - t, 1.65)
		var cut: float = clampf(lerpf(0.11, 0.035, t), 0.025, 0.14)
		lp1 = lerpf(lp1, rng.randf_range(-1.0, 1.0), cut)
		lp2 = lerpf(lp2, lp1, cut)
		lp3 = lerpf(lp3, lp2, cut)
		ph += (TAU * lerpf(f0, f1, t)) / float(SAMPLE_RATE)
		var tone: float = sin(ph) * 0.34
		buf[i] = (lp3 * 1.4 + tone) * env * amp
	return _make_wav(buf)


func _synth_soft_impact(dur: float, f0: float, amp: float) -> AudioStreamWAV:
	var n: int = maxi(int(dur * SAMPLE_RATE), 128)
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 123
	var lp1: float = 0.0
	var lp2: float = 0.0
	var ph: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		var env: float = sin(minf(t * 14.0, 1.0) * PI * 0.5) * pow(1.0 - t, 2.3)
		ph += (TAU * lerpf(f0, 46.0, t)) / float(SAMPLE_RATE)
		lp1 = lerpf(lp1, rng.randf_range(-1.0, 1.0), 0.08)
		lp2 = lerpf(lp2, lp1, 0.08)
		buf[i] = (sin(ph) * 0.8 + lp2 * 0.45) * env * amp
	return _make_wav(buf)


func _synth_soft_pluck(dur: float, freq: float, amp: float) -> AudioStreamWAV:
	var n: int = maxi(int(dur * SAMPLE_RATE), 128)
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t: float = float(i) / float(n)
		var sec: float = float(i) / float(SAMPLE_RATE)
		var env: float = sin(minf(t * 14.0, 1.0) * PI * 0.5) * pow(1.0 - t, 2.1)
		var sig: float = sin(TAU * freq * sec) * 0.82 + sin(TAU * freq * 2.0 * sec) * 0.18
		buf[i] = sig * env * amp
	return _make_wav(buf)


func _synth_harp_arpeggio(notes: Array, step_dur: float, amp: float) -> AudioStreamWAV:
	var total_dur: float = float(notes.size()) * step_dur + 0.36
	var n: int = maxi(int(total_dur * SAMPLE_RATE), 128)
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n)
	for idx in notes.size():
		var freq: float = float(notes[idx])
		var start_i: int = int(float(idx) * step_dur * float(SAMPLE_RATE))
		var note_len: int = int((step_dur + 0.34) * float(SAMPLE_RATE))
		for j in note_len:
			var out_i: int = start_i + j
			if out_i >= n:
				break
			var lt: float = float(j) / float(note_len)
			var env: float = sin(minf(lt * 18.0, 1.0) * PI * 0.5) * pow(1.0 - lt, 2.15)
			var sec: float = float(j) / float(SAMPLE_RATE)
			var sig: float = sin(TAU * freq * sec) * 0.78 + sin(TAU * freq * 2.0 * sec) * 0.18 + sin(TAU * freq * 3.0 * sec) * 0.04
			buf[out_i] += sig * env * amp * 0.64
	return _make_wav(buf)


func _synth_bell_chord(freqs: Array, dur: float, amp: float) -> AudioStreamWAV:
	var n: int = maxi(int(dur * SAMPLE_RATE), 128)
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t: float = float(i) / float(n)
		var sec: float = float(i) / float(SAMPLE_RATE)
		var env: float = sin(minf(t * 20.0, 1.0) * PI * 0.5) * pow(1.0 - t, 1.95)
		var shimmer: float = 0.92 + 0.08 * sin(TAU * 4.2 * sec)
		var acc: float = 0.0
		for f_var in freqs:
			var f: float = float(f_var)
			acc += sin(TAU * f * sec) * 0.78 + sin(TAU * f * 2.0 * sec) * 0.22
		buf[i] = (acc / float(maxi(freqs.size(), 1))) * env * shimmer * amp
	return _make_wav(buf)


func _synth_boss_rumble(dur: float, amp: float) -> AudioStreamWAV:
	var n: int = maxi(int(dur * SAMPLE_RATE), 128)
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 666
	var lp1: float = 0.0
	var lp2: float = 0.0
	var ph: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		var env: float = sin(minf(t * 5.0, 1.0) * PI * 0.5) * pow(1.0 - t, 1.45)
		ph += (TAU * lerpf(92.0, 44.0, t)) / float(SAMPLE_RATE)
		lp1 = lerpf(lp1, rng.randf_range(-1.0, 1.0), 0.05)
		lp2 = lerpf(lp2, lp1, 0.05)
		buf[i] = clampf((sin(ph) * 0.65 + lp2 * 0.6) * env * amp, -1.0, 1.0)
	return _make_wav(buf)


func _synth_twilight_forest_music(dur: float, amp: float) -> AudioStreamWAV:
	## Serene 12-second seamless looping twilight forest harp + warm ambient pad (ZERO static noise!).
	var n: int = maxi(int(dur * SAMPLE_RATE), 256)
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n)

	# 1. Warm slow-breathing harmonic pad (exact integer cycles across dur for zero-seam loop)
	var f_d3: float = round(146.83 * dur) / dur
	var f_a3: float = round(220.00 * dur) / dur
	var f_fs4: float = round(369.99 * dur) / dur
	var f_e4: float = round(329.63 * dur) / dur
	for i in n:
		var sec: float = float(i) / float(SAMPLE_RATE)
		var breath: float = 0.72 + 0.28 * sin(TAU * (1.0 / dur) * sec)
		var shimmer: float = 0.5 + 0.5 * sin(TAU * (2.0 / dur) * sec - PI * 0.5)
		var pad: float = (
			sin(TAU * f_d3 * sec) * 0.34
			+ sin(TAU * f_a3 * sec) * 0.24
			+ sin(TAU * f_fs4 * sec) * (0.12 * shimmer)
			+ sin(TAU * f_e4 * sec) * (0.10 * (1.0 - shimmer))
		) * breath
		buf[i] = pad * 0.55

	# 2. Gentle pentatonic twilight Celtic harp melody notes (wrap-around tails for seamless loop)
	var harp_events: Array = [
		[0.30, 293.66], [1.05, 369.99], [1.80, 440.00], [2.55, 587.33],
		[3.60, 493.88], [4.35, 440.00], [5.10, 369.99],
		[6.30, 329.63], [7.05, 440.00], [7.80, 493.88], [8.55, 659.25],
		[9.60, 587.33], [10.35, 440.00], [11.10, 369.99],
	]
	var note_dur: float = 1.65
	var note_samples: int = int(note_dur * float(SAMPLE_RATE))
	for ev in harp_events:
		var start_sec: float = float(ev[0])
		var freq: float = float(ev[1])
		var start_i: int = int(start_sec * float(SAMPLE_RATE))
		for j in note_samples:
			var out_i: int = (start_i + j) % n
			var lt: float = float(j) / float(note_samples)
			var env: float = sin(minf(lt * 26.0, 1.0) * PI * 0.5) * pow(1.0 - lt, 2.55)
			var sec: float = float(j) / float(SAMPLE_RATE)
			var harp: float = sin(TAU * freq * sec) * 0.78 + sin(TAU * freq * 2.0 * sec) * 0.18 + sin(TAU * freq * 3.0 * sec) * 0.04
			buf[out_i] += harp * env * 0.42

	for i in n:
		buf[i] = clampf(buf[i] * amp, -1.0, 1.0)
	return _make_wav(buf)
