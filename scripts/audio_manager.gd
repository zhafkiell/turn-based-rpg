extends Node
## Autoload "Audio" — SFX & musik sederhana yang dibuat secara prosedural
## (tidak perlu file audio eksternal).

var _players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _tween_ref: Tween


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = -14.0
	add_child(_music_player)


# ---------- Utilitas pembuatan gelombang ----------

func _tone(freq: float, duration: float, volume_db := -10.0, type := "sine", fade := true) -> AudioStreamWAV:
	var rate := 22050
	var samples := int(rate * duration)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	var arr := PackedFloat32Array()
	arr.resize(samples)
	for i in samples:
		var t := float(i) / rate
		var env := 1.0
		if fade:
			env = clampf(1.0 - float(i) / samples, 0.0, 1.0)
		var s := sin(TAU * freq * t)
		match type:
			"square":
				s = 1.0 if sin(TAU * freq * t) >= 0.0 else -1.0
			"saw":
				s = 2.0 * fmod(freq * t, 1.0) - 1.0
			"noise":
				s = randf() * 2.0 - 1.0
		arr[i] = clampf(s * env * pow(10.0, volume_db / 20.0), -1.0, 1.0)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	for i in samples:
		bytes.encode_s16(i * 2, int(arr[i] * 32767.0))
	stream.data = bytes
	return stream


func play_tone(freq: float, duration: float, volume_db := -10.0, type := "sine") -> void:
	var stream := _tone(freq, duration, volume_db, type)
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	# Semua sibuk — pakai player terakhir
	_players[-1].stream = stream
	_players[-1].play()


func play_sequence(notes: Array, note_dur := 0.09, volume_db := -10.0, type := "square") -> void:
	for n in notes:
		play_tone(n, note_dur, volume_db, type)
		await get_tree().create_timer(note_dur * 0.9).timeout


# ---------- SFX khusus ----------

func sfx_cursor() -> void:
	play_tone(660.0, 0.05, -16.0, "square")


func sfx_select() -> void:
	play_tone(880.0, 0.07, -12.0, "square")


func sfx_attack() -> void:
	play_tone(220.0, 0.08, -8.0, "saw")
	play_tone(140.0, 0.12, -6.0, "noise")


func sfx_hit() -> void:
	play_tone(180.0, 0.1, -6.0, "noise")


func sfx_magic() -> void:
	play_tone(520.0, 0.1, -10.0, "sine")
	play_tone(780.0, 0.15, -10.0, "sine")


func sfx_heal() -> void:
	play_sequence([523.0, 659.0, 784.0], 0.08, -10.0, "sine")


func sfx_victory() -> void:
	play_sequence([523.0, 659.0, 784.0, 1046.0], 0.12, -8.0, "square")


func sfx_defeat() -> void:
	play_sequence([392.0, 330.0, 262.0, 196.0], 0.18, -8.0, "square")


func sfx_boss() -> void:
	play_sequence([98.0, 110.0, 98.0, 82.0], 0.2, -6.0, "saw")


# ---------- Musik latar loop sederhana ----------

func play_menu_music() -> void:
	_start_loop([
		[262.0, 0.25], [330.0, 0.25], [392.0, 0.25], [330.0, 0.25],
		[294.0, 0.25], [349.0, 0.25], [440.0, 0.25], [349.0, 0.25],
	], 0.22)


func play_battle_music() -> void:
	_start_loop([
		[220.0, 0.15], [220.0, 0.15], [262.0, 0.15], [220.0, 0.15],
		[196.0, 0.15], [196.0, 0.15], [233.0, 0.15], [196.0, 0.15],
	], 0.13)


func stop_music() -> void:
	if _tween_ref:
		_tween_ref.kill()
		_tween_ref = null
	_music_player.stop()


func _start_loop(notes: Array, step_dur: float) -> void:
	stop_music()
	var rate := 22050
	var total_samples := 0
	for n in notes:
		total_samples += int(rate * n[1])
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	var arr := PackedFloat32Array()
	arr.resize(total_samples)
	var idx := 0
	for n in notes:
		var freq: float = n[0]
		var samples := int(rate * n[1])
		for i in samples:
			var t := float(i) / rate
			var env := clampf(1.0 - float(i) / samples * 0.4, 0.0, 1.0)
			var s := 1.0 if sin(TAU * freq * t) >= 0.0 else -1.0
			arr[idx + i] = s * env * 0.12
		idx += samples
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	for i in total_samples:
		bytes.encode_s16(i * 2, int(clampf(arr[i], -1.0, 1.0) * 32767.0))
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total_samples
	_music_player.stream = stream
	_music_player.play()
