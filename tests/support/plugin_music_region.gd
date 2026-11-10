extends RefCounted
## THE BEACON FIXTURE WITH A WORLD TRACK, for the music hook's tests
## (adventure plugins, 2026-11-10; [method WorldDuels.region_music]): the
## development fixture's island and record (its own static functions, named
## here: a script's static functions are found on that script alone), and a
## tune of its own — the loader fixture's OGG, decoded from its bytes as a
## plugin's would be.

const BEACON := preload("res://tools/expansion_testing/beacon_region.gd")
const TUNE := "res://tests/fixtures/adventure_plugins/tiny_isle/music/tiny_isle_tide.ogg"
static var _tune: AudioStream


static func music_descriptor() -> Dictionary:
	var out: Dictionary = BEACON.descriptor()
	out["provider"] = "res://tests/support/plugin_music_region.gd"
	return out


static func generate(seed_value: int, color: int, difficulty: int) -> ShandalarWorld:
	return BEACON.generate(seed_value, color, difficulty)


static func task_rows(data: Dictionary, progress: Dictionary) -> Array[Dictionary]:
	return BEACON.task_rows(data, progress)


static func music() -> AudioStream:
	if _tune == null:
		_tune = AudioStreamOggVorbis.load_from_buffer(FileAccess.get_file_as_bytes(TUNE))
	return _tune
