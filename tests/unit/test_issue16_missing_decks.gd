extends GutTest
## ISSUE #16 (2026-11-12, "Battle instantly ending"): a build of main
## exported without the project's presets (`export_presets.cfg.example`)
## carried none of the creatures' decks — `.deck` files are not Godot
## resources, and only a preset's include filter brings them — so every
## creature dueled with no card and lost at its first draw (the reporter's
## log: "Inniscor (40 cards) vs Druid (0 cards)"). The owner's ruling of
## 2026-11-13: "Add a warning, then close" — the title screen says so once
## a start ([method CreatureDeck.untold_missing]); a whole build says
## nothing.


func after_each() -> void:
	CreatureDeck._missing_told = false


func test_a_whole_build_says_nothing() -> void:
	assert_true(FileAccess.file_exists(CreatureBook.deck_path(CreatureDeck.FALLBACK_ROW)),
		"control: the fallback deck is in the project")
	assert_eq(CreatureDeck.missing_words(), "")
	assert_eq(CreatureDeck.untold_missing(), "")
	assert_false(CreatureDeck._missing_told)


func test_a_build_without_the_decks_is_told_once() -> void:
	var gone := "res://decks/1997/originals/no_such_creature.deck"
	assert_eq(CreatureDeck.missing_words(gone), CreatureDeck.MISSING_WORDS)
	for words in ["creatures' decks", "export_presets.cfg.example", "*.deck", "Godot editor"]:
		assert_string_contains(CreatureDeck.MISSING_WORDS, words)
	assert_eq(CreatureDeck.untold_missing(gone), CreatureDeck.MISSING_WORDS, "said at the first title")
	assert_eq(CreatureDeck.untold_missing(gone), "", "and not again this run")


func test_the_title_screen_asks() -> void:
	var text := FileAccess.get_file_as_string("res://game/main.gd")
	assert_string_contains(text, "_tell_missing_files()")
	assert_string_contains(text, "CreatureDeck.untold_missing()")


func test_every_preset_carries_the_decks() -> void:
	# The tracked presets are the ones CONTRIBUTING says to copy: each one's
	# include filter names the decks and the other data files.
	var presets := ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg.example"), OK)
	var seen := 0
	for section in presets.get_sections():
		if section.ends_with(".options") or not presets.has_section_key(section, "include_filter"):
			continue
		seen += 1
		var filter := String(presets.get_value(section, "include_filter"))
		for part in ["*.deck", "*.txt", "cards/data/*.json", "packaging/card_packs/*/*.json"]:
			assert_string_contains(filter, part, "%s carries %s" % [presets.get_value(section, "name", section), part])
	assert_gt(seen, 0, "control: presets read")
