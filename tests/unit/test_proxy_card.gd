extends GutTest
## THE PROXY, AND THE BOUNDARY IT MUST NOT CROSS.
##
## A proxy ([ProxyCard]) is a paper stand-in for a card this game does not
## implement — a name a deck holds that the [CardRegistry] does not know.
## It exists so an imported deck can be READ, BUILT, SAVED and LOOKED AT
## whatever cards it names.
##
## **A proxy has no rules behind it.** One that reached [MtgGame] would be
## a card that cannot resolve: `MtgGame._build_library` push_error()s on a
## name it cannot look up and then SKIPS it, so the seat is dealt a
## library quietly short of cards and the duel is silent nonsense rather
## than a crash. That is the failure this file exists to make impossible,
## and every test below the first heading would fail if a proxy could
## reach a duel by the door it names.
##
## The doors, all of them, and the test that holds each:
##   the CardRegistry itself   test_a_proxy_never_enters_the_registry
##   DeckList's strict mode    test_a_strict_load_refuses_a_proxy_in_*
##   the battle-setup screen   tests/ui/test_setup_screen.gd (the note and
##                             the `Go!` gate — they need the real screen)
##   the Deck Lab              test_the_deck_lab_refuses_a_proxy_deck


## A name no card in this pool will ever answer to. Deliberately not a
## real Magic card: a name that GRADUATES would turn this file green for
## the wrong reason (and the pool grows every week).
const NOT_A_CARD := "Zzz Notional Behemoth"
const ALSO_NOT := "Zzz Notional Sprite"


func before_each() -> void:
	CardRegistry.ensure_loaded()


# ================================================== what a proxy IS ======

func test_a_card_in_the_pool_is_not_a_proxy() -> void:
	assert_false(ProxyCard.is_proxy("Lightning Bolt"))
	assert_false(ProxyCard.is_proxy("Mountain"))


func test_a_name_the_registry_does_not_know_is_a_proxy() -> void:
	assert_true(ProxyCard.is_proxy(NOT_A_CARD))


func test_nothing_is_not_a_proxy() -> void:
	# An empty deck line would be a parse bug, not a stand-in.
	assert_false(ProxyCard.is_proxy(""))
	assert_false(ProxyCard.is_proxy("   "))


func test_the_proxy_carries_its_name_and_the_word_proxy() -> void:
	var data := ProxyCard.data_for(NOT_A_CARD)
	assert_eq(data.card_name, NOT_A_CARD, "verbatim, as the deck file wrote it")
	assert_eq(data.oracle_text, "proxy", "the owner's own word, lower case")
	assert_eq(data.oracle_text, ProxyCard.RULES_TEXT)


func test_a_proxy_claims_no_colour_no_type_and_no_cost() -> void:
	# Which is the whole reason it is drawn on plain paper: there is no
	# coloured frame it has any right to.
	var data := ProxyCard.data_for(NOT_A_CARD)
	assert_eq(data.color_mask(), 0)
	assert_eq(data.types, 0)
	assert_eq(data.cost.text, "")
	assert_false(data.is_creature())
	assert_false(data.is_land())


func test_the_same_name_is_the_same_object() -> void:
	# CardArea compares cell data by identity to decide whether to rebind,
	# so two calls handing back two objects would rebuild every cell on
	# every scroll.
	assert_same(ProxyCard.data_for(NOT_A_CARD), ProxyCard.data_for(NOT_A_CARD))
	assert_true(ProxyCard.is_proxy_data(ProxyCard.data_for(NOT_A_CARD)))
	assert_false(ProxyCard.is_proxy_data(CardRegistry.get_card("Mountain")))


# ============================== THE BOUNDARY: THE REGISTRY ===============

func test_a_proxy_never_enters_the_registry() -> void:
	# THE MOST IMPORTANT TEST IN THIS FILE. The registry is the set of
	# things that can be played, and `test_registry_loaded_the_pool` pins
	# its size — a proxy in it would be a bug that pinned itself.
	var before := CardRegistry.size()
	var data := ProxyCard.data_for(NOT_A_CARD)
	assert_not_null(data, "the card data exists...")
	assert_false(CardRegistry.has_card(NOT_A_CARD),
		"...and the registry has still never heard of it")
	assert_eq(CardRegistry.size(), before, "the pool did not grow")
	# ...and asking again, which is what a screen full of proxies does.
	for _i in 5:
		ProxyCard.data_for(NOT_A_CARD)
		ProxyCard.data_for(ALSO_NOT)
	assert_eq(CardRegistry.size(), before)
	assert_true(ProxyCard.is_proxy(NOT_A_CARD),
		"and it is still a proxy afterwards")


# ============================ THE BOUNDARY: THE STRICT LOADER ============
# `DeckList.load_file(path, true)` is the floor under every other gate:
# an unknown name is an ERROR there and never reaches `cards`. Every
# format, because a `.dck` out of a 1997 install is exactly the file most
# likely to name a card we have not built.

func test_a_strict_load_refuses_a_proxy_in_a_deck_list() -> void:
	var deck := DeckList.new()
	deck.parse("name: Proxied\n4 Lightning Bolt\n2 %s\n" % NOT_A_CARD,
		"x", true)
	assert_eq(deck.errors.size(), 1, "the unknown name is an error")
	assert_true(String(deck.errors[0]).contains(NOT_A_CARD), "and it is named")
	assert_eq(deck.cards.size(), 4, "and it never reached the deck")
	assert_eq(deck.proxies, [] as Array[String],
		"a strict load reports no proxies — it refuses them instead")


func test_a_strict_load_refuses_a_proxy_in_a_1997_dck() -> void:
	var deck := DeckList.new()
	deck.parse_dck("Old Deck\n\n.0\t4\tMountain\n.0\t2\t%s\n" % NOT_A_CARD,
		"x", true)
	assert_eq(deck.errors.size(), 1)
	assert_true(String(deck.errors[0]).contains(NOT_A_CARD))
	assert_eq(deck.cards.size(), 4)


func test_a_strict_load_refuses_a_proxy_in_a_sideboard() -> void:
	var deck := DeckList.new()
	deck.parse("4 Mountain\nSB: 3 %s\n" % NOT_A_CARD, "x", true)
	assert_eq(deck.errors.size(), 1)
	assert_eq(deck.sideboard.size(), 0, "it never reached the sideboard either")


# ============================== THE LENIENT PATH, which import needs =====

func test_a_lenient_load_keeps_the_name_and_reports_it() -> void:
	var deck := DeckList.new()
	deck.parse("name: Proxied\n4 Lightning Bolt\n2 %s\n" % NOT_A_CARD,
		"x", false)
	assert_eq(deck.errors, [] as Array[String], "no error: it is a proxy")
	assert_eq(deck.cards.size(), 6, "every copy is in the deck")
	assert_eq(deck.cards.count(NOT_A_CARD), 2, "both of them, by name")
	assert_eq(deck.proxies, [NOT_A_CARD] as Array[String], "and reported once")


func test_a_lenient_load_reports_each_proxy_once_however_many_copies() -> void:
	var deck := DeckList.new()
	deck.parse("4 %s\n4 %s\n4 %s\n" % [NOT_A_CARD, ALSO_NOT, NOT_A_CARD],
		"x", false)
	assert_eq(deck.cards.size(), 12)
	assert_eq(deck.proxies.size(), 2,
		"twelve cards, two things to replace")


func test_a_lenient_dck_and_sideboard_report_proxies_too() -> void:
	var deck := DeckList.new()
	deck.parse_dck("Old\n\n.0\t2\t%s\n.vNone\n.0\t1\t%s\n"
		% [NOT_A_CARD, ALSO_NOT], "x", false)
	assert_eq(deck.errors, [] as Array[String])
	assert_eq(deck.cards.count(NOT_A_CARD), 2)
	assert_eq(deck.sideboard.count(ALSO_NOT), 1)
	assert_eq(deck.proxies.size(), 2, "both piles are reported")


func test_a_clean_deck_reports_no_proxies_either_way() -> void:
	for path in DeckStore.deck_paths_in(DeckStore.SHIPPED_DIR):
		assert_eq(DeckList.load_file(path, false).proxies,
			[] as Array[String], "%s is all real cards" % path.get_file())


# ================================= THE REFUSAL ITSELF ====================

func test_the_refusal_names_every_proxy() -> void:
	# A refusal that said only "this deck has proxies" would leave the
	# player hunting a 200-card list for the ones to replace.
	var refusal := ProxyCard.refusal_for(
		["Mountain", NOT_A_CARD, "Mountain", ALSO_NOT])
	assert_ne(refusal, "")
	assert_true(refusal.contains(NOT_A_CARD), "the first is named")
	assert_true(refusal.contains(ALSO_NOT), "and so is the second")
	assert_true(refusal.contains("cannot be played"), "and it says why")


func test_the_refusal_reads_the_sideboard_too() -> void:
	var refusal := ProxyCard.refusal_for(["Mountain"], [NOT_A_CARD])
	assert_true(refusal.contains(NOT_A_CARD),
		"a proxy cannot hide in the SB: lines")


func test_a_real_deck_is_refused_nothing() -> void:
	assert_eq(ProxyCard.refusal_for(["Mountain", "Lightning Bolt"]), "")
	assert_eq(ProxyCard.refusal([]), "")


func test_the_named_proxies_are_sorted_and_distinct() -> void:
	var names := ProxyCard.names_in([ALSO_NOT, NOT_A_CARD, ALSO_NOT])
	assert_eq(names, [NOT_A_CARD, ALSO_NOT] as Array[String],
		"sorted, and each named once")


# ================== THE BOUNDARY: EVERY DUEL DOOR THIS FILE CAN REACH ====

func test_the_deck_lab_refuses_a_proxy_deck_naming_the_cards() -> void:
	# The Lab is the door where getting this wrong is worst: a strict load
	# would DROP the unresolvable names and it would play a thousand games
	# with a deck short of cards, then report the win rate as if it meant
	# something.
	var path := "user://decks/proxy_lab_probe.deck"
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(DeckStore.USER_DIR))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("name: Lab Probe\n36 Mountain\n4 %s\n" % NOT_A_CARD)
	file.close()
	# autofree: simulate.gd extends SceneTree, whose constructor builds a
	# root Window — an orphan node for the rest of the run without this.
	var lab: Object = autofree(load("res://DeckLab/simulate.gd").new())
	assert_null(lab._load_deck(path), "the Lab will not load it")
	# ...and it accepts the same deck once the proxy is gone.
	var clean := "user://decks/proxy_lab_clean.deck"
	var ok := FileAccess.open(clean, FileAccess.WRITE)
	ok.store_string("name: Lab Clean\n40 Mountain\n")
	ok.close()
	assert_not_null(lab._load_deck(clean), "a real deck still loads")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(clean))


# ======================= THE COPY RULES DO APPLY TO PROXIES ==============
# A proxy stands in for a card, so a deck built with stand-ins should
# still be a legal-LOOKING deck: the player finds out about a fifth copy
# while they are still building, not on the day the card graduates.

func test_the_four_of_rule_counts_proxies() -> void:
	var five: Array[String] = []
	for _i in 5:
		five.append(NOT_A_CARD)
	var refusal := DeckFormat.legal(five, DeckFormat.WILD)
	assert_ne(refusal, "", "five copies is five copies")
	assert_true(refusal.contains(NOT_A_CARD))
	assert_eq(DeckFormat.legal(five.slice(0, 4), DeckFormat.WILD), "",
		"and four is fine")


func test_a_proxy_is_never_exempt_as_a_basic_land() -> void:
	assert_false(DeckFormat.is_basic(NOT_A_CARD))
	assert_false(DeckModel.exempt_from_duplicates(NOT_A_CARD))
	assert_true(DeckFormat.is_basic("Mountain"), "...unlike a real basic")


func test_a_proxy_of_a_banned_card_is_banned() -> void:
	# The lists are kept BY NAME precisely so a card outside the pool is
	# already on them when it arrives — and a proxy IS a card outside the
	# pool, so this needed no new code at all.
	var name: String = DeckFormat.BANNED[0]
	if CardRegistry.has_card(name):
		return          # it graduated; the list is doing its other job
	assert_true(ProxyCard.is_proxy(name), "%s is not implemented" % name)
	var refusal := DeckFormat.legal([name], DeckFormat.WILD)
	assert_true(refusal.contains("banned"),
		"a proxy Contract from Below is still banned")


func test_highlander_counts_proxies_too() -> void:
	assert_ne(DeckFormat.legal([NOT_A_CARD, NOT_A_CARD],
		DeckFormat.HIGHLANDER), "")


# ============================== THE CARD, DRAWN =========================
# [ProxyFace] is the widget. It is not a [MiniCard] — there is no
# [CardInstance] behind it — but it IS the one card size, which is the
# rule that is about what a surface looks like rather than about which
# class drew it.

func test_the_proxy_is_the_one_card_size_in_both_forms() -> void:
	var small := ProxyFace.new(NOT_A_CARD)
	autofree(small)
	assert_eq(small.size, MiniCard.SIZE, "small: MiniCard.SIZE")
	assert_eq(small.custom_minimum_size, MiniCard.SIZE)
	assert_eq(small.scale, Vector2.ONE, "and never rescaled")
	var big := ProxyFace.new(NOT_A_CARD, true)
	autofree(big)
	assert_eq(big.size, CardPreview.SIZE, "large: CardPreview.SIZE")
	assert_eq(big.custom_minimum_size, CardPreview.SIZE)
	assert_eq(big.scale, Vector2.ONE)


func test_the_proxy_writes_its_name_and_the_word_proxy() -> void:
	for large in [false, true]:
		var face := ProxyFace.new(NOT_A_CARD, large)
		autofree(face)
		var names := 0
		var words := 0
		for node in _walk(face):
			if node is Label:
				if (node as Label).text == NOT_A_CARD:
					names += 1
				elif (node as Label).text == ProxyCard.RULES_TEXT:
					words += 1
		assert_eq(names, 1, "the name, once (large=%s)" % large)
		assert_eq(words, 1, "and `proxy` where the rules text goes")


func test_the_proxy_is_paper_and_not_a_coloured_frame() -> void:
	# The point of the whole face: a proxy has no colour to claim, so it
	# must not be wearing one of the five card frames.
	var face := ProxyFace.new(NOT_A_CARD)
	autofree(face)
	var box := face.get_theme_stylebox("normal") as StyleBoxFlat
	assert_not_null(box, "a flat paper ground, not a frame texture")
	assert_eq(box.bg_color, ProxyFace.PAPER)
	# ...and nothing on the face is a StyleBoxTexture, which is what a
	# skinned 1997 frame would be. (Asked of the WIDGET rather than of
	# `MiniCard.frame_skin_key`, which would answer `card_frame_artifact`
	# for a colourless card — the very frame this face exists to avoid.)
	for node in _walk(face):
		if node is Panel:
			var panel_box := (node as Panel).get_theme_stylebox("panel")
			assert_false(panel_box is StyleBoxTexture,
				"no frame art on a piece of paper")


func test_renaming_a_proxy_face_reletters_it() -> void:
	# CardArea rebinds a page widget rather than rebuilding it.
	var face := ProxyFace.new(NOT_A_CARD)
	autofree(face)
	face.set_proxy_name(ALSO_NOT)
	assert_eq(face.proxy_name, ALSO_NOT)
	var found := false
	for node in _walk(face):
		if node is Label and (node as Label).text == ALSO_NOT:
			found = true
	assert_true(found, "the new name is on the card")


func _walk(node: Node) -> Array:
	var out := [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out
