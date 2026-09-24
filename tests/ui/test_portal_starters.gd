extends GutTest
## Exact historical lists, honest adaptations and their Help/selector paths.

const ORIGINALS := ["res://decks/portal/portal_starter_a_35.deck", "res://decks/portal/portal_starter_b_35.deck"]
const PLAY := ["res://decks/variants/portal_starter_a_40.deck", "res://decks/variants/portal_starter_b_40.deck"]
const ADDED := [
	["Plains", "Mountain", "Armored Pegasus", "Grizzly Bears", "Volcanic Hammer"],
	["Island", "Swamp", "Coral Eel", "Snapping Drake", "Hand of Death"],
]
const SINGLETONS := [
	["Anaconda", "Armored Pegasus", "Devoted Hero", "Fire Imp", "Gorilla Warrior",
	"Grizzly Bears", "Hill Giant", "Hulking Goblin", "Lizard Warrior", "Raging Goblin",
	"Regal Unicorn", "Spotted Griffin", "Venerable Monk", "Defiant Stand", "Blaze",
	"Lava Axe", "Sacred Nectar", "Untamed Wilds", "Volcanic Hammer", "Warrior's Charge"],
	["Coral Eel", "Craven Knight", "Elite Cat Warrior", "Feral Shadow", "Gravedigger",
	"Ingenious Thief", "Muck Rats", "Panther Warriors", "Rowan Treefolk", "Skeletal Crocodile",
	"Snapping Drake", "Storm Crow", "Command of Unsummoning", "Cloak of Feathers",
	"Hand of Death", "Mind Rot", "Monstrous Growth", "Time Ebb", "Touch of Brilliance", "Vampiric Touch"],
]
const LANDS := [{"Plains": 6, "Mountain": 6, "Forest": 3}, {"Island": 6, "Swamp": 6, "Forest": 3}]
var _enabled: Array = []

func before_each() -> void:
	_enabled = Settings.enabled_card_packs().duplicate()
	Settings.set_value("enabled_card_packs", ["pack-6"], false)
	CardPacks._configure_registry()

func after_each() -> void:
	Settings.set_value("enabled_card_packs", _enabled, false)
	CardPacks._configure_registry()
	ShellMusic.stop()

func test_published_lists_are_exact_and_kept_separate() -> void:
	assert_eq(DeckStore.deck_paths_in("res://decks/portal").size(), 2)
	for index in 2:
		var deck := DeckList.load_file(ORIGINALS[index])
		assert_eq(deck.errors, [])
		assert_eq(deck.cards.size(), 35)
		assert_eq(deck.sideboard.size(), 0)
		assert_eq(DeckGroups.of(ORIGINALS[index]), DeckGroups.PORTAL_STARTERS)
		for card_name in SINGLETONS[index]: assert_eq(deck.cards.count(card_name), 1, card_name)
		for card_name in LANDS[index]: assert_eq(deck.cards.count(card_name), LANDS[index][card_name], card_name)

func test_play_versions_only_add_the_documented_five_cards() -> void:
	for index in 2:
		var original := DeckList.load_file(ORIGINALS[index])
		var deck := DeckList.load_file(PLAY[index])
		assert_eq(deck.errors, [])
		assert_eq(deck.cards.size(), 40)
		assert_eq(deck.sideboard.size(), 0)
		assert_string_contains(deck.deck_name, "40-card play version")
		assert_eq(DeckGroups.of(PLAY[index]), DeckGroups.VARIANTS)
		var expected := original.cards.duplicate()
		expected.append_array(ADDED[index])
		expected.sort()
		var actual := deck.cards.duplicate()
		actual.sort()
		assert_eq(actual, expected)
		assert_eq(SgDeckCatalog.validate(deck.cards), "")

func test_all_four_decks_use_portal_cards_and_keep_printing_metadata() -> void:
	var names := PortalPack.names()
	for path in ORIGINALS + PLAY:
		var deck := DeckList.load_file(path)
		assert_eq(deck.required_packs, ["pack-6"])
		assert_eq(deck.printings.size(), 23)
		for card_name in deck.cards:
			assert_true(names.has(card_name), card_name)
			assert_eq(deck.printings.get(card_name), "por")
			assert_false(CardPrintings.resolve(card_name, "por").is_empty(), card_name)
		var report: Array = []
		var model := DeckStore.load_deck(path, report)
		assert_not_null(model)
		if model == null: continue
		var roundtrip := DeckList.new()
		roundtrip.parse(model.to_text())
		assert_eq(roundtrip.printings, deck.printings)
		assert_eq(roundtrip.required_packs, deck.required_packs)

func test_duel_selector_offers_play_versions_and_preserves_originals_in_builder() -> void:
	var screen = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	for path in PLAY: assert_true(screen._playable_paths.has(path), path)
	for path in ORIGINALS:
		assert_true(screen._playable_paths.has(path), "35-card original is playable without padding")
		assert_true(DeckStore.shipped_paths().has(path))
		var deck := DeckList.load_file(path)
		assert_ne(GauntletState.your_deck_problem(path, deck), "", "Gauntlet keeps its minimum")
	for pid in 2:
		var picker: OptionButton = screen._deck_options[pid]
		for index in picker.item_count:
			if str(picker.get_item_metadata(index)) == ORIGINALS[pid]: picker.select(index)
	screen._refresh_format_note()
	assert_string_contains(screen._format_note.text, "35 cards: casual play only")
	for mode in [SetupScreen.BattleMode.VS_AI, SetupScreen.BattleMode.HOTSEAT, SetupScreen.BattleMode.DEMO]:
		screen._mode = mode
		var config: DuelConfig = screen._build_config()
		assert_not_null(config)
		if config != null:
			for cards in config.decks: assert_eq(cards.size(), 35, "no automatic padding")

func test_casual_lan_accepts_originals_but_tournaments_keep_forty() -> void:
	for path in ORIGINALS:
		var deck := DeckList.load_file(path)
		var payload := {"name": deck.deck_name, "cards": Array(deck.cards), "sideboard": []}
		assert_true(SgDeckCatalog.valid_payload(payload))
		assert_false(SgTournament.valid_deck(payload))
		assert_true(SgDeckCatalog.available().any(func(row: Dictionary) -> bool: return row.name == deck.deck_name))
		assert_false(SgDeckCatalog.available(false).any(func(row: Dictionary) -> bool: return row.name == deck.deck_name))
		var referee := SgPracticeMatch.new(57, [payload, payload])
		assert_eq(referee.game.players[0].library.size() + referee.game.players[0].hand.size(), 35)
		assert_false(referee.game.game_over)

func test_disabled_pack_decks_stay_visible_with_the_pack_requirement() -> void:
	Settings.set_value("enabled_card_packs", [], false)
	CardPacks._configure_registry()
	var screen = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	for path in PLAY:
		assert_true(screen._deck_paths.has(path))
		assert_eq(screen._pack_paths.get(path), ["pack-6"])
		assert_false(screen._playable_paths.has(path))
	for path in ORIGINALS + PLAY:
		var deck := DeckList.load_file(path, false)
		assert_eq(deck.errors, [])
		assert_eq(deck.required_packs, ["pack-6"])
		assert_eq(deck.printings.size(), 23)

func test_thirty_five_cards_are_an_engine_supported_size_not_a_new_ruleset() -> void:
	var game := MtgGame.new()
	game.setup(DeckList.load_file(ORIGINALS[0]).cards, DeckList.load_file(ORIGINALS[1]).cards)
	game.deal_opening_hands()
	assert_false(game.game_over)
	for player in game.players:
		assert_eq(player.hand.size(), 7)
		assert_eq(player.library.size(), 28)
	game.draw_cards(0, 28)
	assert_false(game.game_over, "empty library alone does not lose")
	game.draw_cards(0, 1)
	assert_true(game.game_over)
	assert_eq(game.winner, 1)

func test_portal_guides_remain_readable_with_the_pack_disabled() -> void:
	Settings.set_value("enabled_card_packs", [], false)
	CardPacks._configure_registry()
	var screen = load("res://game/help/help_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var pages := HelpPages.pages()
	var found := 0
	for index in pages.size():
		if not String(pages[index].title).begins_with("Portal · "): continue
		found += 1
		screen.go_to(index)
		await get_tree().process_frame
		assert_eq(screen._title_label.text, pages[index].title)
		assert_gte(screen._body.get_child_count(), 10)
	assert_eq(found, 2)

func test_minimum_casual_deck_can_pay_ante_and_deal_a_full_hand() -> void:
	var cards: Array = []
	cards.resize(DeckModel.CASUAL_MIN_CARDS)
	cards.fill("Grizzly Bears")
	var game := MtgGame.new()
	game.setup(cards, cards)
	for pid in 2: game.stake_ante(pid, 1, true)
	game.deal_opening_hands()
	assert_false(game.game_over)
	for player in game.players:
		assert_eq(player.hand.size(), 7)
		assert_eq(player.ante.size(), 1)
	assert_eq(SgDeckCatalog.validate(cards), "")
	cards.pop_back()
	assert_ne(SgDeckCatalog.validate(cards), "")

func test_builder_displays_short_deck_warning_without_refusing_it() -> void:
	var screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var report: Array = []
	screen.deck = DeckStore.load_deck(ORIGINALS[0], report)
	screen._refresh_legality()
	assert_true(screen.deck.is_legal())
	assert_string_contains(screen._legality_label.tooltip_text, "35 cards: casual play only")
	assert_string_contains(screen._legality_label.tooltip_text, "tournaments need 40")
