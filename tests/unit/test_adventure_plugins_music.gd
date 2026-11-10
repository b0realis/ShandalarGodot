extends GutTest
## A LAND'S OWN WORLD TRACK (adventure plugins, 2026-11-10; the spec's §4,
## music): while the hero walks a land whose plugin names a track it plays
## in place of the title's tune, as low under the world, and gives way to a
## duel's or the deck builder's music as the title's does; on the mainland,
## or a land with none, the title's tune again ([method WorldDuels.region_music]).
## The land is the development fixture with a tune (tests/support/plugin_music_region.gd).

const BEACON := preload("res://tools/expansion_testing/beacon_region.gd")
const MUSIC := preload("res://tests/support/plugin_music_region.gd")
const HOLDER := "extends Node\nvar soundscape: Node\n"
const SOUNDSCAPE := "extends Node\nvar player\n"


func after_each() -> void:
	AdventureExpansions.clear_development()


func _node(source: String) -> Node:
	var script := GDScript.new()
	script.source_code = source
	script.reload()
	return script.new()


func _world(player: AdventurePlayer) -> Node:
	var holder := _node(HOLDER)
	var sound := _node(SOUNDSCAPE)
	sound.set(&"player", player)
	holder.set(&"soundscape", sound)
	holder.add_child(sound)
	add_child_autofree(holder)
	return holder


func _hero() -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	setup.adventures = [BEACON.ID] as Array[String]
	var record := setup.resolve({})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(player)
	return player


func test_a_lands_track_plays_there_and_the_titles_tune_at_home() -> void:
	assert_true(AdventureExpansions.register_development(BEACON.ID, MUSIC.music_descriptor()))
	var player := _hero()
	var world := _world(player)
	var sound: Node = world.get(&"soundscape")
	assert_null(AdventureExpansions.music(player), "the mainland's music is the title's")
	assert_false(WorldDuels.region_music(world))
	assert_null(sound.get_node_or_null(^"RegionTune"), "no voice of a land's on the mainland")
	assert_true(AdventureExpansions.voyage(player, BEACON.ID))
	assert_same(AdventureExpansions.music(player), MUSIC.music())
	assert_true(WorldDuels.region_music(world))
	var voice := sound.get_node_or_null(^"RegionTune") as AudioStreamPlayer
	assert_not_null(voice, "the land's voice, the soundscape's child")
	if voice == null: return
	assert_same(voice.stream, MUSIC.music())
	assert_eq(voice.bus, GameAudio.MUSIC_BUS)
	assert_eq(voice.volume_db, WorldSoundscape.BED_DB, "as low under the world as the title's tune")
	var pane := Node.new()
	world.add_child(pane)
	assert_true(WorldDuels.region_music(pane), "a pane over the world finds the world's soundscape")
	assert_same(sound.get_node_or_null(^"RegionTune"), voice, "one voice, not a second")
	WorldDuels.world_music_off(pane)
	assert_false(voice.playing, "a pane's own tune stops it")
	WorldDuels.region_music_off(world)
	assert_true(AdventureExpansions.voyage(player, AdventureRegions.MAINLAND))
	assert_false(WorldDuels.region_music(world))
	assert_null(sound.get_node_or_null(^"RegionTune"), "home again: the land's voice let go")


func test_a_land_without_a_track_keeps_the_titles_tune() -> void:
	assert_true(AdventureExpansions.register_development(BEACON.ID, BEACON.descriptor()))
	var player := _hero()
	assert_true(AdventureExpansions.voyage(player, BEACON.ID))
	var world := _world(player)
	assert_null(AdventureExpansions.music(player))
	assert_false(WorldDuels.region_music(world))
	assert_null((world.get(&"soundscape") as Node).get_node_or_null(^"RegionTune"))
	assert_false(WorldDuels.region_music(null))
	var loose := Node.new()
	WorldDuels.region_music_off(loose)
	assert_false(WorldDuels.region_music(loose), "outside the tree: nothing to play")
	loose.free()
