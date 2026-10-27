extends GutTest
## A NEW ADVENTURE'S CHOICES, headless ([AdventureSetup], 2026-10-22): the
## 1997 starting resources the sources give, the fourteen heroes and their
## walkers, the name rules, the seeded record a world will be made from,
## and the choices remembered between visits.


func before_each() -> void:
	AdventureSetup.forget()


func after_each() -> void:
	AdventureSetup.forget()


func test_starting_resources_follow_the_sources() -> void:
	# Gold (5 − difficulty) × 50, 50 food, one amulet of the colour and
	# 3 − difficulty more, the starting deck's size (1997's, its extra
	# creature copy counted: 36, 40, 46, 46) and colours.
	var expected := [[250, 4, 36, 1], [200, 3, 40, 2], [150, 2, 46, 3], [100, 1, 46, 5]]
	for level in 4:
		var start := AdventureSetup.starting_resources(level)
		assert_eq([start["gold"], start["amulets"], start["deck_cards"], start["deck_colors"]],
			expected[level], AdventureSetup.DIFFICULTIES[level])
		assert_eq(start["food"], 50)
	assert_eq(AdventureSetup.starting_resources(9)["gold"], 100, "clamped to Wizard")


func test_each_colour_starts_with_the_first_world_magic_of_its_pair() -> void:
	# `Scards[colour × 2]` in the `@WORLDMAGIC_NAMES` order, colour numbers
	# Black 1, Blue 2, Green 3, Red 4, White 5.
	var names := ["Sleight of Hand", "Haggler's Coin", "Conjurer's Will",
		"Amulet of Swampwalk", "Leap of Fate", "Tome of Enlightenment",
		"Quickening", "Fruit of Sustenance", "Staff of Thunder",
		"Dwarven Pick", "Sword of Resistance", "Ring of the Guardian"]
	for row in AdventureSetup.COLORS:
		assert_eq(row["world_magic"], names[int(row["number"]) * 2], String(row["name"]))
	assert_eq(AdventureSetup.COLORS.size(), 5)


func test_the_fourteen_heroes_are_the_imported_faces_in_frame_order() -> void:
	var ids := ["melody_whisp", "sir_van_popple", "muriallisa", "goya",
		"lady_dragetta", "ali_of_willoshire", "snow_blight", "baba_bue",
		"dina_bin-barq", "inniscor", "gauldron", "agnosia", "wu_wei", "keleena"]
	# 1.3's gender_map, frames 0-13 (1 is the woman who walks the map).
	var female := [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1]
	assert_eq(AdventureSetup.HEROES.size(), 14)
	for i in 14:
		assert_eq(AdventureSetup.HEROES[i]["id"], ids[i])
		assert_eq(AdventureSetup.HEROES[i]["walker"], "female" if female[i] == 1 else "male", ids[i])
	assert_eq(AdventureSetup.suggested_name("dina_bin-barq"), "Dina bin-Barq", "the 1997 spelling")
	assert_eq(AdventureSetup.suggested_name("grey_wizard"), "Grey Wizard", "any other face: its title")


func test_a_name_is_cleaned_and_capped() -> void:
	assert_eq(AdventureSetup.clean_name("  Sir   Van\tPopple  "), "Sir Van Popple")
	assert_eq(AdventureSetup.clean_name("Ann" + String.chr(0x202e) + "a" + String.chr(7)), "Anna")
	assert_eq(AdventureSetup.clean_name("x".repeat(40)).length(), AdventureSetup.NAME_MAX)
	assert_eq(AdventureSetup.clean_name("Junún d'Arc-Ye"), "Junún d'Arc-Ye", "letters 1.3 refused are kept")
	var setup := AdventureSetup.new()
	setup.player_name = "   "
	assert_ne(setup.name_refusal(), "", "a hero needs a name")
	setup.player_name = "Wu Wei"
	assert_eq(setup.name_refusal(), "")


func test_the_walker_follows_the_hero_until_chosen() -> void:
	var setup := AdventureSetup.new()
	setup.portrait = "keleena"
	assert_eq(setup.walker_shown(), "female")
	setup.portrait = "goya"
	assert_eq(setup.walker_shown(), "male")
	setup.portrait = "a_face_of_my_own"
	assert_eq(setup.walker_shown(), "other", "a face that is no hero's")
	setup.walker = "female"
	setup.portrait = "goya"
	assert_eq(setup.walker_shown(), "female", "the player's pick stays")


func test_the_seed_decides_other_and_random_and_replays() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Ann"
	setup.walker = "other"
	setup.playmat_type = AdventureSetup.RANDOM_TYPE
	setup.seed_text = "12345"
	var first := setup.resolve({})
	var again := setup.resolve({})
	assert_eq(first["seed"], 12345)
	assert_eq(first["hero"], again["hero"], "the same seed, the same walker")
	assert_eq(first["playmat"], again["playmat"], "and the same playmat style")
	assert_true(String(first["hero"]["walker"]) in ["male", "female"])
	assert_eq(first["hero"]["walker_choice"], "other")
	var styles := []
	var walkers := {}
	for n in range(1, 60):
		setup.seed_text = str(n)
		var record := setup.resolve({})
		styles.append(record["playmat"]["type"])
		walkers[record["hero"]["walker"]] = true
	for entry in DuelOptions.TERRITORY_TYPES:
		assert_true(String(entry["label"]) in styles, "every style is drawn: %s" % entry["label"])
	assert_eq(walkers.size(), 2, "both walkers are drawn")


func test_an_empty_seed_is_rolled_and_anything_typed_is_a_seed() -> void:
	assert_eq(AdventureSetup.parse_seed(""), 0)
	assert_eq(AdventureSetup.parse_seed("   "), 0, "spaces alone are empty")
	assert_eq(AdventureSetup.parse_seed(" 42 "), 42, "a number is the seed itself")
	assert_eq(AdventureSetup.parse_seed("000509"), 509, "a time before 1 a.m.")
	assert_eq(AdventureSetup.parse_seed("4294967295"), 4294967295, "every 32-bit seed can be typed")
	# FNV-1a of the lower-case bytes: the reference values of the hash.
	assert_eq(AdventureSetup.text_seed("a"), 0xE40C292C)
	assert_eq(AdventureSetup.text_seed("foobar"), 0xBF9CF968)
	assert_eq(AdventureSetup.parse_seed("Marko"), AdventureSetup.parse_seed("marko"), "capitals make no difference")
	assert_ne(AdventureSetup.parse_seed("Marko"), AdventureSetup.parse_seed("Shandalar"), "another word, another world")
	for typed in ["-5", "12a", "0", "4294967296", "12345678901", "Šandalar"]:
		var value := AdventureSetup.parse_seed(typed)
		assert_true(value >= 1 and value <= AdventureSetup.SEED_MAX, "%s is a seed too" % typed)
		assert_eq(value, AdventureSetup.text_seed(typed), typed)
	assert_eq(AdventureSetup.clean_seed("  a\tb  "), "ab", "no control characters, the ends trimmed")
	assert_eq(AdventureSetup.clean_seed("x".repeat(40)).length(), AdventureSetup.SEED_LENGTH)
	var setup := AdventureSetup.new()
	setup.player_name = "Ann"
	assert_eq(setup.resolve({}, 777)["seed"], 777, "the rolled seed is used")
	var from_clock := int(setup.resolve({})["seed"])
	assert_gt(from_clock, 0, "or one is taken from the clock")
	assert_true(_is_a_time(from_clock), "the time of day, %d" % from_clock)


func test_the_clock_seed_reads_as_the_time_of_day() -> void:
	var text := AdventureSetup.time_seed_text()
	assert_eq(text.length(), 6, "hours, minutes, seconds: two digits each")
	assert_true(_is_a_time(AdventureSetup.parse_seed(text)), text)
	var now := Time.get_time_dict_from_system()
	var seconds := int(now["hour"]) * 3600 + int(now["minute"]) * 60 + int(now["second"])
	var shown := int(text.substr(0, 2)) * 3600 + int(text.substr(2, 2)) * 60 + int(text.substr(4, 2))
	assert_lte(posmod(seconds - shown, 86400), 5, "the time it is now")


func _is_a_time(value: int) -> bool:
	var hours := value / 10000
	var minutes := (value / 100) % 100
	return value > 0 and hours <= 24 and minutes < 60 and value % 100 < 60


func test_the_record_carries_the_choices_and_the_start() -> void:
	var setup := AdventureSetup.new()
	setup.portrait = "wu_wei"
	setup.player_name = "  Wu   Wei "
	setup.color = "green"
	setup.playmat_color = ""
	setup.playmat_type = "Pattern"
	setup.difficulty = 3
	setup.packs = ["pack-3", "pack-9"]
	setup.seed_text = "99"
	var record := setup.resolve({"pack-3": "1.0.0", "pack-8": "1.0.0"})
	assert_eq(record["version"], AdventureSetup.RECORD_VERSION)
	assert_eq(record["game_version"], ProjectSettings.get_setting("application/config/version"))
	assert_eq(record["hero"]["name"], "Wu Wei")
	assert_eq(record["hero"]["walker"], "male")
	assert_eq(record["color"], "green")
	assert_eq(record["playmat"], {"color": "green", "type": "Pattern"}, "your colour")
	assert_eq(record["packs"], [{"id": "pack-3", "version": "1.0.0"}], "a pack not installed is left out")
	assert_eq(record["start"]["gold"], 100)
	assert_eq(record["start"]["world_magic"], "Quickening")
	assert_eq(record["start"]["amulet_color"], "green")
	setup.playmat_color = "blue"
	assert_eq(setup.resolve({})["playmat"]["color"], "blue", "a colour of its own")


func test_the_choices_are_remembered_and_checked_on_the_way_back() -> void:
	var setup := AdventureSetup.new()
	setup.portrait = "agnosia"
	setup.player_name = "Agnosia the Bold"
	setup.walker = "other"
	setup.color = "black"
	setup.playmat_color = "red"
	setup.playmat_type = "Mana symbols"
	setup.packs = ["pack-2", "pack-5"]
	setup.difficulty = 2
	setup.seed_text = "5"
	setup.remember()
	var back := AdventureSetup.restore(["pack-5", "pack-7"] as Array[String])
	assert_eq(back.portrait, "agnosia")
	assert_eq(back.player_name, "Agnosia the Bold")
	assert_eq(back.walker, "other")
	assert_eq(back.color, "black")
	assert_eq(back.playmat_color, "red")
	assert_eq(back.playmat_type, "Mana symbols")
	assert_eq(back.packs, ["pack-5"] as Array[String], "a pack no longer installed is dropped")
	assert_eq(back.difficulty, 2)
	assert_eq(back.seed_text, "", "a seed is one world's, never remembered")
	# Values that are not choices fall back.
	Settings.set_value("adventure_color", "purple", false)
	Settings.set_value("adventure_walker", "dragon", false)
	Settings.set_value("adventure_playmat_type", "Tartan", false)
	Settings.set_value("adventure_difficulty", 11)
	back = AdventureSetup.restore([] as Array[String])
	assert_eq([back.color, back.walker, back.playmat_type, back.difficulty],
		["white", "", AdventureSetup.RANDOM_TYPE, 3])


func test_each_level_says_how_hard_it_is() -> void:
	assert_eq(AdventureSetup.DIFFICULTY_WORDS, ["Training game", "Easy game", "Normal game", "Hard game"] as Array[String])
	assert_eq(AdventureSetup.difficulty_phrase(0), "a training game")
	assert_eq(AdventureSetup.difficulty_phrase(1), "an easy game")
	assert_eq(AdventureSetup.difficulty_phrase(3), "a hard game")


## PACK 1 IS NEVER AN ADVENTURE'S (the owner, 2026-10-22): the base cards
## are always there; the packs are the expansions, Pack 2 on.
func test_pack_one_is_never_taken() -> void:
	var installed: Array[String] = ["pack-1", "pack-2", "pack-9"]
	assert_eq(AdventureSetup.offered_packs(installed), ["pack-2", "pack-9"] as Array[String])
	var setup := AdventureSetup.new()
	setup.player_name = "Ann"
	setup.packs = ["pack-1", "pack-2"]
	var record := setup.resolve({"pack-1": "1.0.0", "pack-2": "1.0.0"})
	assert_eq(record["packs"], [{"id": "pack-2", "version": "1.0.0"}])
	setup.remember()
	assert_eq(AdventureSetup.restore(installed).packs, ["pack-2"] as Array[String],
		"a remembered Pack 1 does not come back")


## THE RECORD NAMES ITS WORLD: the seed, and the site placement's first
## slot that follows it (the original's clock), the colour and the
## difficulty are all the 1997 generator needs.
func test_the_record_makes_its_world() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Ann"
	setup.color = "red"
	setup.difficulty = 1
	setup.seed_text = "12345"
	var record := setup.resolve({})
	assert_eq(record["slot_start"], 12345 % 128)
	assert_eq(AdventureSetup.color_number("red"), 4)
	var world := AdventureSetup.make_world(record)
	assert_eq(world.fingerprint(), WorldGenerator.generate(12345, 12345 % 128, 4, 1).fingerprint())
	assert_eq([world.color, world.difficulty, world.seed], [4, 1, 12345])


## The owner, 2026-10-22: Randomize draws a name from "100 magical names and
## 100 magical surname combinations".
func test_a_hundred_names_and_a_hundred_surnames() -> void:
	for list in [AdventureSetup.FIRST_NAMES, AdventureSetup.SURNAMES]:
		assert_eq(list.size(), 100)
		var unique := {}
		for word in list:
			unique[word] = true
			assert_eq(AdventureSetup.clean_name(word), word, "a clean name: %s" % word)
			assert_false(" " in word, word)
		assert_eq(unique.size(), 100, "no name twice")
	var longest := 0
	for first in AdventureSetup.FIRST_NAMES:
		longest = maxi(longest, first.length())
	var longest_surname := 0
	for surname in AdventureSetup.SURNAMES:
		longest_surname = maxi(longest_surname, surname.length())
	assert_lte(longest + 1 + longest_surname, AdventureSetup.NAME_MAX, "every pair fits a hero's name")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var setup := AdventureSetup.new()
	for draw in 50:
		setup.player_name = AdventureSetup.random_name(rng)
		assert_eq(setup.name_refusal(), "", "%s is a name" % setup.player_name)
