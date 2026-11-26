extends GutTest
## Campaign 2026-11-26, bugs3 #2: a decklist from a deck site, a word
## processor or a person spells a card its own way, and Import, Paste and
## Load read each such name as a proxy "this game does not implement".
## The Deck Builder's doors now read a name by its letters
## ([method CardRegistry.names_like]); an exact name always wins, a name
## two cards answer to stays a proxy and is named, and the duel's strict
## loader is as it was.

const LIST := "4 lightning bolt\n1 Aladdin’s Lamp\n1 aladdin's lamp\n1 Circle Of Protection: Red\n" \
	+ "1 Will-O'-The-Wisp\n1 LIGHTNING BOLT\n2 Lightning  Bolt\n1 Dandan\n1 El-Hajjaj\n" \
	+ "3 Ali From Cairo\n20 mountain\n"
const DIR := "user://c1126_deck_names"

var _added: Array[String] = []


func before_each() -> void:
	CardRegistry.ensure_loaded()


func after_each() -> void:
	for card_name in _added:
		CardRegistry._cards.erase(card_name)
	_added.clear()
	if DirAccess.dir_exists_absolute(DIR):
		for file in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR + "/" + file)
		DirAccess.remove_absolute(DIR)


func _register(card_name: String) -> void:
	var data := CardData.new()
	data.card_name = card_name
	CardRegistry.register(data)
	_added.append(card_name)


func _expect_whole(model: DeckModel, what: String) -> void:
	assert_not_null(model, what)
	if model == null:
		return
	assert_eq(model.proxy_names().size(), 0, "%s: no proxies, got %s" % [what, str(model.proxy_names())])
	assert_eq(model.total(), 36, what)
	assert_eq(model.count_of("Lightning Bolt"), 7, what)
	assert_eq(model.count_of("Aladdin's Lamp"), 2, what)
	assert_eq(model.count_of("Circle of Protection: Red"), 1, what)
	assert_eq(model.count_of("Will-o'-the-Wisp"), 1, what)
	assert_eq(model.count_of("Dandân"), 1, what)
	assert_eq(model.count_of("El-Hajjâj"), 1, what)
	assert_eq(model.count_of("Ali from Cairo"), 3, what)
	assert_eq(model.count_of("Mountain"), 20, what)


func test_the_registry_reads_a_name_by_its_letters() -> void:
	for pair in [["lightning bolt", "Lightning Bolt"], ["Aladdin’s Lamp", "Aladdin's Lamp"],
			["Dandan", "Dandân"], ["Ali From Cairo", "Ali from Cairo"], ["Lightning  Bolt", "Lightning Bolt"],
			["mountain", "Mountain"], ["Lightning Bolt", "Lightning Bolt"]]:
		assert_eq(CardRegistry.resolve_name(String(pair[0])), String(pair[1]))
	assert_eq(CardRegistry.resolve_name("Lightning Bold"), "", "another name is no card")
	assert_eq(CardRegistry.resolve_name(""), "")
	assert_eq(CardRegistry.resolve_name("’ - :"), "", "no letters, no card")
	assert_eq(CardRegistry.names_like("no such card at all").size(), 0)


func test_a_pasted_list_keeps_its_cards() -> void:
	var report: Array = []
	_expect_whole(DeckStore.import_text(LIST, "Pasted", report), "paste")
	assert_eq(report, [], "nothing to report")


func test_every_file_door_reads_the_same() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for ext in ["dec", "txt", "deck"]:
		var path := "%s/list.%s" % [DIR, ext]
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(LIST)
		file.close()
		var report: Array = []
		_expect_whole(DeckStore.import_file(path, report), "import ." + ext)
		assert_eq(report, [], ext)
		if ext != "txt":
			report = []
			_expect_whole(DeckStore.load_deck(path, report), "load ." + ext)


func test_the_1997_file_and_a_printing_tail_read_the_same() -> void:
	var report: Array = []
	var dck := DeckStore.import_text("My deck\n.1\t4\tlightning bolt\n.2\t2\tDandan\n", "x", report)
	assert_eq(dck.count_of("Lightning Bolt"), 4)
	assert_eq(dck.count_of("Dandân"), 2)
	assert_eq(dck.proxy_names().size(), 0)
	var arena := DeckStore.import_text("Deck\n4 lightning bolt (M10) 146\n2 Aladdin’s Lamp [4ED]\n", "x", report)
	assert_eq(arena.count_of("Lightning Bolt"), 4)
	assert_eq(arena.count_of("Aladdin's Lamp"), 2)
	assert_eq(report, [])


func test_a_name_that_is_no_card_is_still_a_proxy() -> void:
	var report: Array = []
	var model := DeckStore.import_text("4 Lightning Bolt\n2 Zzz Not A Card\n", "x", report)
	assert_eq(model.proxy_names(), ["Zzz Not A Card"] as Array[String])
	assert_eq(report.size(), 1)
	assert_string_contains(String(report[0]), "Zzz Not A Card")


func test_an_exact_name_wins_and_a_doubtful_one_stays_a_proxy_and_is_named() -> void:
	_register("Zzq Probe-Card")
	_register("Zzqprobe Card")
	assert_eq(CardRegistry.resolve_name("Zzq Probe-Card"), "Zzq Probe-Card", "exact wins")
	assert_eq(CardRegistry.resolve_name("Zzqprobe Card"), "Zzqprobe Card", "exact wins")
	assert_eq(CardRegistry.resolve_name("zzq probe card"), "", "two cards answer: not guessed")
	assert_eq(CardRegistry.names_like("zzq probe card").size(), 2)
	var report: Array = []
	var model := DeckStore.import_text("2 Zzq Probe-Card\n3 Zzqprobe Card\n1 zzq probe card\n", "x", report)
	assert_eq(model.count_of("Zzq Probe-Card"), 2)
	assert_eq(model.count_of("Zzqprobe Card"), 3)
	assert_eq(model.proxy_names(), ["zzq probe card"] as Array[String])
	var said := "\n".join(PackedStringArray(report))
	assert_string_contains(said, "1 card became a proxy: zzq probe card")
	assert_string_contains(said, "\"zzq probe card\" could be Zzq Probe-Card or Zzqprobe Card.")
	# The table follows the pool: with one of the two gone the name is sure.
	CardRegistry._cards.erase("Zzqprobe Card")
	assert_eq(CardRegistry.resolve_name("zzq probe card"), "Zzq Probe-Card")


func test_a_chosen_printing_follows_the_card() -> void:
	var list := DeckList.new()
	list.printings["lightning bolt"] = "any"
	list.parse_foreign("4 lightning bolt\n", "x")
	assert_eq(list.cards.count("Lightning Bolt"), 4)
	assert_eq(list.printings, {"Lightning Bolt": "any"})


func test_the_duel_s_loader_and_every_other_reader_are_as_they_were() -> void:
	var strict := DeckList.new()
	strict.parse("4 lightning bolt\n4 Lightning Bolt\n")
	assert_eq(strict.cards.size(), 4, "strict keeps only the exact name")
	assert_eq(strict.errors.size(), 1)
	var lenient := DeckList.new()
	lenient.parse("4 lightning bolt\n", "x", false)
	assert_eq(lenient.proxies, ["lightning bolt"] as Array[String], "a plain lenient read is unchanged")
	var from_text := DeckList.from_text("4 lightning bolt\n", "x.deck", false)
	assert_eq(from_text.proxies.size(), 1)
	assert_eq(DeckList.from_text("4 lightning bolt\n", "x.deck", false, true).proxies.size(), 0)
