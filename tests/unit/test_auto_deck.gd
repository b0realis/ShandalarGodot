extends GutTest
## AUTODECK'S HEAD ([AutoDeck], 2026-09-18): the pools it reads,
## the deck it builds from a pool and a handful of wishes — legal, in the
## colours asked for, the lands the speed asks for settled by the curve
## (2026-09-26: Karsten's fit, and the basics split by what the spells
## want), the caps the rules set — and the report it writes into the
## notes; the variety knob, and a deck held but for a few cards
## (2026-09-26). Nothing here opens the window; that is
## `tests/ui/test_auto_deck_window.gd`.


func before_all() -> void:
	CardRegistry.ensure_loaded()


## The whole library, four of everything — the widest pool there is.
func _library() -> Dictionary:
	return AutoDeck.pool_from_names(CardRegistry.all_names())


func _builder(pool: Dictionary, seed := 7) -> AutoDeck:
	var auto := AutoDeck.new()
	auto.pool = pool
	auto.seed = seed
	return auto


func _lands(deck: DeckModel) -> int:
	var n := 0
	for name in deck.names():
		if DeckModel._card(name).is_land():
			n += int(deck.counts[name])
	return n


## The band the land count may settle in: the speed's count within
## [constant AutoDeck.LAND_PLAY] either way (2026-09-26).
func _assert_lands_settled(deck: DeckModel, auto: AutoDeck) -> void:
	var table := int(AutoDeck.LANDS[auto.size_key()][auto.speed])
	assert_between(_lands(deck), table - AutoDeck.LAND_PLAY, table + AutoDeck.LAND_PLAY,
		"%d lands within %d of the %s speed's %d" % [_lands(deck), AutoDeck.LAND_PLAY, auto.speed, table])
	var asked := AutoDeck.lands_for(_average_mana(deck), AutoDeck._cheap_mana_or_draw(deck), auto.size_key())
	var settled := clampi(asked, table - AutoDeck.LAND_PLAY, table + AutoDeck.LAND_PLAY)
	assert_between(_lands(deck), settled - 1, settled + 1,
		"the curve's own count (%d for an average of %.2f) within one: %d lands" % [asked, _average_mana(deck), _lands(deck)])
	if auto.land_total <= 0 and auto.short_by == 0:
		assert_true(deck.notes.contains("the %s speed's %d settled at %d." % [auto.speed, table, _lands(deck)]), deck.notes)


func _creatures(deck: DeckModel) -> int:
	var n := 0
	for name in deck.names():
		if DeckModel._card(name).is_creature():
			n += int(deck.counts[name])
	return n


## The first-turn castables: non-land cards of mana value 0 or 1.
## The spells cast for one mana — a Fireball is not one ([method
## AutoDeck.cast_value]).
func _one_drops(deck: DeckModel) -> int:
	var n := 0
	for name in deck.names():
		var data := DeckModel._card(name)
		if not data.is_land() and AutoDeck.cast_value(data) <= 1:
			n += int(deck.counts[name])
	return n


func _average_mana(deck: DeckModel) -> float:
	var mana := 0
	var spells := 0
	for name in deck.names():
		var data := DeckModel._card(name)
		if data.is_land():
			continue
		mana += data.cost.mana_value() * int(deck.counts[name])
		spells += int(deck.counts[name])
	return float(mana) / maxi(spells, 1)


## Every non-land card is castable in the deck's colours and comes from
## the pool, no card is over the copy limit, and the basics are basics.
func _assert_legal(deck: DeckModel, auto: AutoDeck, size: int) -> void:
	assert_eq(deck.total(), size, "the size asked for")
	assert_eq(deck.side_total(), 0, "no sideboard")
	var limit := DeckModel.duplicates_allowed(size)
	for name in deck.names():
		var data := DeckModel._card(name)
		assert_not_null(data, name)
		if AutoDeck.BASICS.has(name):
			continue
		assert_true(auto.pool.has(name), "%s is in the pool" % name)
		assert_true(int(deck.counts[name]) <= mini(limit, int(auto.pool[name])),
			"%d %s within the pool's %d and the rules' %d" % [
				int(deck.counts[name]), name, int(auto.pool[name]), limit])
		assert_true(AutoDeck.castable(data, auto.chosen_colors),
			"%s is castable in %s" % [name, AutoDeck.color_phrase(auto.chosen_colors)])


# ------------------------------------------------------------ the pools --

func test_a_pool_of_names_leaves_out_basics_and_strangers() -> void:
	var pool := AutoDeck.pool_from_names(["Lightning Bolt", "Plains", "Not A Card", "Serra Angel"], 3)
	assert_eq(pool, {"Lightning Bolt": 3, "Serra Angel": 3})
	assert_eq(AutoDeck.pool_total(pool), 6)
	assert_eq(AutoDeck.pool_from_counts({"Terror": 2, "Island": 9, "Terror ": 0, "Nope": 4}), {"Terror": 2})


func test_a_set_pool_is_the_registry_s_own_membership() -> void:
	var pool := AutoDeck.pool_from_sets(["4ed"])
	assert_gt(pool.size(), 100, "Fourth Edition is a big set (149 names with the card packs off)")
	for name in pool:
		assert_true(CardRegistry.card_in_set(name, "4ed", true, true), "%s is in 4ed" % name)
		assert_false(AutoDeck.BASICS.has(name), "no basic in a pool")
		assert_eq(int(pool[name]), 4, "four of each")
	var two := AutoDeck.pool_from_sets(["4ed", "drk"])
	assert_gt(two.size(), pool.size(), "two sets are more than one")
	assert_eq(AutoDeck.pool_from_sets([]), {}, "no set, no pool")


func test_a_text_pool_reads_deck_lines_sideboard_and_all() -> void:
	var report: Array = []
	var pool := AutoDeck.pool_from_text(
		"# my pool\n4 Lightning Bolt\n2x Serra Angel\nSB: 1 Terror\n1 Lightning Bolt\n3 Nothing Of The Sort\n", report)
	assert_eq(pool, {"Lightning Bolt": 5, "Serra Angel": 2, "Terror": 1},
		"main and sideboard lines count together; the stranger is left out")
	assert_eq(report.size(), 1)
	assert_eq(String(report[0]), "1 name the game does not have: Nothing Of The Sort")
	report.clear()
	assert_eq(AutoDeck.pool_from_text("Lightning Bolt\nSerra Angel", report), {},
		"a line without a count is not a card line: the pool is empty")
	assert_false(report.is_empty(), "and the reason is reported")
	assert_true(String(report[0]).begins_with("line 1:"), String(report[0]))


func test_the_pool_becomes_a_sealed_pool_with_free_basics() -> void:
	var auto := _builder({"Lightning Bolt": 4, "Serra Angel": 2})
	auto.size = 40
	var pool := auto.to_sealed_pool()
	assert_eq(pool.copies_of("Lightning Bolt"), 4)
	assert_eq(pool.copies_of("Serra Angel"), 2)
	for land in AutoDeck.BASICS:
		assert_eq(pool.copies_of(land), 40, "%s, as many as the deck is big" % land)
	assert_eq(pool.packs.size(), 1)
	assert_eq(String(pool.packs[0]["title"]), "AutoDeck")
	assert_eq(pool.total(), 6 + 5 * 40)
	assert_eq(auto.to_sealed_pool(60).copies_of("Plains"), 60, "or more, when asked")


# ------------------------------------------------------------ the build --

func test_sixty_from_the_library_is_legal_and_in_the_colours_worth_most() -> void:
	var auto := _builder(_library())
	var deck := auto.build()
	_assert_legal(deck, auto, 60)
	_assert_lands_settled(deck, auto)
	# The builder's own choice is the colour set worth most ON ITS OWN
	# MANA (2026-09-26): each set's best castable cards less the strain
	# their pips put on the lands the set would be laid, one per cent off
	# per extra colour — blue-green in the library once the red cards
	# with a drawback (a coin flip, a Horde's discard, an X spell priced
	# at its cast value) were read as such, and every other set rates
	# under it by that measure.
	assert_eq(auto.chosen_colors, Mtg.ManaColor.U | Mtg.ManaColor.G,
		"the library's own choice: %s" % deck.deck_name)
	var candidates := auto._candidates(4)
	var chosen := auto._mask_worth(candidates, auto.chosen_colors, 60 - _lands(deck), 0) \
		* (1.0 - 0.01 * (AutoDeck._count_colors(auto.chosen_colors) - 1))
	for mask in [Mtg.ManaColor.R, Mtg.ManaColor.R | Mtg.ManaColor.G, Mtg.ManaColor.U | Mtg.ManaColor.R,
			Mtg.ManaColor.G, Mtg.ManaColor.W | Mtg.ManaColor.U, Mtg.ManaColor.U | Mtg.ManaColor.B | Mtg.ManaColor.G]:
		var other := auto._mask_worth(candidates, mask, 60 - _lands(deck), 0)
		assert_gte(chosen, other * (1.0 - 0.01 * (AutoDeck._count_colors(mask) - 1)),
			"%s is worth %.1f on its mana, the choice %.1f" % [AutoDeck.color_phrase(mask), other, chosen])
	assert_eq(auto.short_by, 0, "the library never runs short")
	assert_eq(deck.deck_name, auto.deck_name())
	assert_true(deck.deck_name.ends_with(" Midrange"), deck.deck_name)
	assert_true(deck.notes.begins_with("Built by AutoDeck: 60 cards, "), deck.notes)
	assert_true(deck.notes.contains("Card pool: the library (%d cards on offer)." % AutoDeck.pool_total(auto.pool)))
	assert_true(deck.notes.contains("%d lands: " % _lands(deck)), deck.notes)
	assert_true(deck.notes.contains("%d spells: " % (60 - _lands(deck))), deck.notes)
	assert_true(deck.notes.contains("The curve asks for "), deck.notes)
	assert_true(deck.notes.contains("Seed 7: the same pool and wishes build this deck again."), deck.notes)
	assert_false(deck.notes.contains("ran out"), "no ran-short line")
	assert_false(deck.notes.contains("Built around"), "nothing was kept")
	assert_false(deck.notes.contains("without the tournament rules"))
	assert_false(deck.notes.contains("Variety"), "no variety line at variety 0")
	assert_true(deck.notes.contains("The Power Nine left out: the switch is off."),
		"the library holds them; the notes say why none is in (2026-09-18): " + deck.notes)
	assert_eq(auto.report.size(), 7)


func test_forty_from_a_set_is_legal_with_three_of_a_card() -> void:
	var auto := _builder(AutoDeck.pool_from_sets(["4ed"]))
	auto.size = 40
	var deck := auto.build()
	_assert_legal(deck, auto, 40)
	_assert_lands_settled(deck, auto)
	for name in deck.names():
		if not AutoDeck.BASICS.has(name):
			assert_true(int(deck.counts[name]) <= 3, "%s: three copies at most in 40 (manual ch.10)" % name)
	assert_true(deck.notes.begins_with("Built by AutoDeck: 40 cards, "), deck.notes)


func test_the_colours_asked_for_are_the_deck_s() -> void:
	var auto := _builder(_library())
	auto.colors = Mtg.ManaColor.U | Mtg.ManaColor.B
	var deck := auto.build()
	assert_eq(auto.chosen_colors, Mtg.ManaColor.U | Mtg.ManaColor.B, "both, and no third")
	_assert_legal(deck, auto, 60)
	assert_true(deck.deck_name.begins_with("Blue-Black "), deck.deck_name)
	for land in ["Plains", "Mountain", "Forest"]:
		assert_eq(deck.count_of(land), 0, "no %s in a blue-black deck" % land)
	assert_true(deck.count_of("Island") >= 2 and deck.count_of("Swamp") >= 2,
		"each colour with pips gets at least two basics")
	# One colour asked for and one allowed: mono.
	auto.colors = Mtg.ManaColor.G
	auto.max_colors = 1
	deck = auto.build()
	assert_eq(auto.chosen_colors, Mtg.ManaColor.G)
	assert_true(deck.deck_name.begins_with("Mono-Green "), deck.deck_name)
	_assert_legal(deck, auto, 60)
	assert_eq(deck.count_of("Forest"), _lands(deck) - _nonbasics(deck), "the basics are all Forests")


func _nonbasics(deck: DeckModel) -> int:
	var n := 0
	for name in deck.names():
		if DeckModel._card(name).is_land() and not AutoDeck.BASICS.has(name):
			n += int(deck.counts[name])
	return n


func test_asking_for_three_colours_widens_the_cap() -> void:
	var auto := _builder(_library())
	auto.colors = Mtg.ManaColor.W | Mtg.ManaColor.R | Mtg.ManaColor.G
	auto.max_colors = 1
	var deck := auto.build()
	assert_eq(auto.chosen_colors, Mtg.ManaColor.W | Mtg.ManaColor.R | Mtg.ManaColor.G,
		"the colours asked for always win over the cap")
	_assert_legal(deck, auto, 60)
	assert_true(deck.deck_name.begins_with("White-Red-Green "), deck.deck_name)


func test_the_speed_sets_the_lands_and_the_curve() -> void:
	var fast := _builder(_library())
	fast.speed = AutoDeck.SPEED_FAST
	var fast_deck := fast.build()
	var slow := _builder(_library())
	slow.speed = AutoDeck.SPEED_SLOW
	var slow_deck := slow.build()
	_assert_legal(fast_deck, fast, 60)
	_assert_legal(slow_deck, slow, 60)
	_assert_lands_settled(fast_deck, fast)
	_assert_lands_settled(slow_deck, slow)
	assert_lt(_lands(fast_deck), _lands(slow_deck), "fast: %d lands, slow: %d" % [_lands(fast_deck), _lands(slow_deck)])
	assert_lt(_average_mana(fast_deck), _average_mana(slow_deck),
		"the fast deck's spells are cheaper: %.2f against %.2f" % [
			_average_mana(fast_deck), _average_mana(slow_deck)])
	assert_lt(_average_mana(fast_deck), 2.5, "a fast deck lives at one and two")
	assert_gt(_average_mana(slow_deck), 3.2, "a slow deck reaches for the big spells")
	# The speed is the cost of the creatures and the spells (2026-09-18):
	# a fast deck is full of first-turn castables, a slow deck nearly
	# without — the curve is held firmly, not nudged.
	var medium := _builder(_library())
	var medium_deck := medium.build()
	assert_gte(_one_drops(fast_deck), 10, "fast: three in ten of 38 spells cost one, got %d" % _one_drops(fast_deck))
	assert_lte(_one_drops(slow_deck), 3, "slow: hardly any one-drops, got %d" % _one_drops(slow_deck))
	assert_gt(_one_drops(fast_deck), _one_drops(medium_deck), "fast has more one-drops than medium")
	assert_gt(_one_drops(medium_deck), _one_drops(slow_deck), "medium has more than slow")
	assert_between(_average_mana(medium_deck), 2.6, 3.2, "medium sits between")
	fast.size = 40
	var fast_forty := fast.build()
	_assert_lands_settled(fast_forty, fast)
	assert_gte(_one_drops(fast_forty), 7, "and the curve scales with the size: %d one-drops" % _one_drops(fast_forty))
	slow.size = 40
	var slow_forty := slow.build()
	_assert_lands_settled(slow_forty, slow)
	assert_lt(_lands(fast_forty), _lands(slow_forty), "fast: %d lands in 40, slow: %d" % [_lands(fast_forty), _lands(slow_forty)])
	assert_lte(_one_drops(slow_forty), 2, "slow: %d one-drops in 40" % _one_drops(slow_forty))


## The land count settles on the curve (2026-09-26): Karsten's fit over
## 95,000 tournament decks — 19.59 + 1.90 x the average mana value, less
## 0.28 a cheap mana or draw spell — within [constant AutoDeck.LAND_PLAY]
## of the speed's count, and two thirds of it in forty.
func test_the_curve_settles_the_land_count() -> void:
	assert_eq(AutoDeck.lands_for(2.0, 0, 60), 23, "two mana a spell: 23 lands (Karsten)")
	assert_eq(AutoDeck.lands_for(2.5, 0, 60), 24)
	assert_eq(AutoDeck.lands_for(3.0, 0, 60), 25)
	assert_eq(AutoDeck.lands_for(3.5, 0, 60), 26)
	assert_eq(AutoDeck.lands_for(4.0, 0, 60), 27)
	assert_eq(AutoDeck.lands_for(2.0, 4, 60), 22, "four cheap mana or draw spells take one off")
	assert_eq(AutoDeck.lands_for(1.8, 0, 40), 15, "two thirds in forty")
	assert_eq(AutoDeck.lands_for(2.0, 0, 40), 16)
	assert_eq(AutoDeck.lands_for(3.0, 0, 40), 17)
	assert_eq(AutoDeck.lands_for(3.5, 0, 40), 17)
	# The count is laid exactly when the deck names it ([member
	# AutoDeck.land_total]) — a varied deck keeps its own.
	var own := _builder(_library())
	own.land_total = 21
	var deck := own.build()
	_assert_legal(deck, own, 60)
	assert_eq(_lands(deck), 21, "the deck's own count, whatever the curve")
	assert_true(deck.notes.contains("The land count is the deck's own: 21."), deck.notes)
	assert_false(deck.notes.contains("The curve asks for"), deck.notes)
	# The curve is read off the deck: a slow deck of the library asks for
	# more than the speed's count and gets it, a fast deck of one-drops
	# hardly more than its own.
	var slow := _builder(_library())
	slow.speed = AutoDeck.SPEED_SLOW
	deck = slow.build()
	assert_gt(AutoDeck.lands_for(_average_mana(deck), 0, 60), 25, "a slow curve asks for more than 25")
	_assert_lands_settled(deck, slow)
	assert_eq(AutoDeck._cheap_mana_or_draw(deck), _cheap(deck), "the cheap count is what the deck holds")


## Cheap mana and draw as the test counts them: non-lands of two mana
## or less that make mana or read as draw or acceleration.
func _cheap(deck: DeckModel) -> int:
	var n := 0
	for name in deck.names():
		var data := DeckModel._card(name)
		if data.is_land() or data.cost.mana_value() > 2:
			continue
		var roles := AiDeckStudy.classify(data)
		if AutoDeck.produces(data) != 0 or roles.has("draw") or roles.has("acceleration"):
			n += int(deck.counts[name])
	return n


## Karsten's source counts (2026-09-26): what a card's pips want of the
## lands, and what that does to the fill and the basics. A two-colour
## deck's double pip is marked down by every source it is short; the
## basics are split by what the spells want, not by the raw pips.
func test_the_sources_the_pips_want() -> void:
	assert_eq(AutoDeck.sources_for(1, 1, 60), 14, "a one-drop of one pip: 14 of 60")
	assert_eq(AutoDeck.sources_for(1, 2, 60), 13)
	assert_eq(AutoDeck.sources_for(1, 3, 60), 12)
	assert_eq(AutoDeck.sources_for(1, 4, 60), 11)
	assert_eq(AutoDeck.sources_for(1, 6, 60), 9, "five and up")
	assert_eq(AutoDeck.sources_for(2, 2, 60), 20, "a double pip of two mana wants nearly every land")
	assert_eq(AutoDeck.sources_for(2, 3, 60), 18)
	assert_eq(AutoDeck.sources_for(3, 3, 60), 23)
	assert_eq(AutoDeck.sources_for(4, 4, 60), 21, "a fourth pip one more")
	assert_eq(AutoDeck.sources_for(1, 1, 40), 10, "forty")
	assert_eq(AutoDeck.sources_for(2, 2, 40), 14)
	assert_eq(AutoDeck.sources_for(0, 3, 60), 0, "no pips, no want")
	# Mono-red expects every land red: no strain on anything red.
	var mono := _builder(_library())
	mono.colors = Mtg.ManaColor.R
	mono.max_colors = 1
	mono.build()
	assert_almost_eq(mono._source_strain(_card("Ball Lightning")), 0.0, 0.001, "RRR in mono-red is free")
	# Blue-black splits the lands: a double pip is strained, a single
	# pip of three mana hardly at all.
	var two := _builder(_library())
	two.colors = Mtg.ManaColor.U | Mtg.ManaColor.B
	two.build()
	var double := two._source_strain(_card("Hypnotic Specter"))
	var single := two._source_strain(_card("Erg Raiders"))
	assert_gt(double, single, "1BB is strained more than 1B: %.2f against %.2f" % [double, single])
	assert_gt(double, 0.2, "and the strain is felt: %.2f" % double)
	assert_lt(single, 0.4, "a single pip is nearly free: %.2f" % single)
	# The basics by what the spells want: two Black Knights (BB, two
	# mana: 20 sources) against four Lightning Bolts (R, one mana: 14)
	# are even in pips, and the Swamps still outnumber the Mountains.
	var keep := DeckModel.new()
	for i in 2:
		keep.add("Black Knight")
	for i in 4:
		keep.add("Lightning Bolt")
	var split := _builder({})
	split.keep = keep
	var deck := split.build()
	assert_eq(deck.total(), 60)
	assert_gt(deck.count_of("Swamp"), deck.count_of("Mountain"),
		"the double pip wants the more sources: %d Swamp, %d Mountain" % [deck.count_of("Swamp"), deck.count_of("Mountain")])
	assert_gte(deck.count_of("Mountain"), 2, "and every colour with a pip gets two at least")


## A deck held but for a few cards (2026-09-26, the CLI's `--vary`):
## the kept deck's lands go in as they are ([member
## AutoDeck.keep_lands]), the land count is the deck's own ([member
## AutoDeck.land_total]) and any size will do.
func test_a_deck_held_but_for_a_few_cards_keeps_its_lands() -> void:
	var held := DeckModel.new()
	for i in 20:
		held.add("Mountain")
	for i in 4:
		held.add("Taiga")
	for i in 4:
		held.add("Lightning Bolt")
	for i in 4:
		held.add("Llanowar Elves")
	for i in 3:
		held.add("Shivan Dragon")
	var auto := _builder(_library())
	auto.keep = held
	auto.keep_lands = true
	auto.size = 61
	auto.land_total = 24
	auto.colors = Mtg.ManaColor.R | Mtg.ManaColor.G
	var deck := auto.build()
	assert_eq(deck.total(), 61, "the size is the deck's own")
	assert_eq(deck.count_of("Mountain"), 20, "the kept lands as they were")
	assert_eq(deck.count_of("Taiga"), 4)
	assert_eq(_lands(deck), 24, "and no more: the land count is the deck's own")
	assert_eq(deck.count_of("Lightning Bolt"), 4)
	assert_eq(deck.count_of("Shivan Dragon"), 3)
	assert_eq(auto.chosen_colors, Mtg.ManaColor.R | Mtg.ManaColor.G)
	assert_true(deck.notes.contains("Built around the 35 cards already on the surface, 24 lands among them."), deck.notes)
	assert_true(deck.notes.contains("The land count is the deck's own: 24."), deck.notes)
	# A land varied out is made up in basics by the whole deck's pips.
	held.remove_all("Taiga")
	auto.keep = held
	deck = auto.build()
	assert_eq(deck.total(), 61)
	assert_eq(_lands(deck), 24, "four lands laid fresh for the four Taigas out")
	assert_eq(deck.count_of("Taiga"), 0, "the library holds Taiga, but classic lands are basics")
	assert_gte(deck.count_of("Forest"), 2, "green pips (the Elves) get Forests: %s" % str(deck.counts))
	# Without the lands kept, a bad size still falls back to sixty.
	auto.keep_lands = false
	auto.land_total = 0
	deck = auto.build()
	assert_eq(deck.total(), 60)


## The mana a spell is cast for (2026-09-26): an X spell is no one-drop
## — a Fireball is cast for three and buckets with the three-drops
## ([method AutoDeck.cast_value], [constant AutoDeck.X_AS]).
func test_an_x_spell_is_cast_for_more_than_its_printed_value() -> void:
	assert_eq(AutoDeck.cast_value(_card("Lightning Bolt")), 1)
	assert_eq(AutoDeck._bucket(_card("Lightning Bolt")), 0, "the one-drop bucket")
	assert_eq(AutoDeck.cast_value(_card("Fireball")), 1 + AutoDeck.X_AS, "X R: cast for three")
	assert_eq(AutoDeck._bucket(_card("Fireball")), 2, "the three-drop bucket")
	assert_eq(AutoDeck.cast_value(_card("Braingeyser")), 2 + AutoDeck.X_AS, "X U U")
	assert_eq(AutoDeck._bucket(_card("Braingeyser")), 3)
	assert_eq(AutoDeck.cast_value(_card("Craw Wurm")), 6, "no X: the printed value")
	assert_eq(AutoDeck._bucket(_card("Craw Wurm")), 4, "five or more")


## The mana a colour set would be laid (2026-09-26, [method
## AutoDeck._mana_expected]): the lands split among the set's colours
## as the laying splits them, from the best cards castable under the
## set — every land to a mono deck's colour, the deeper colour's share
## the larger, a colour asked for never under an even share — and the
## strain a card's pips cost it reads that expectation.
func test_the_mana_a_colour_set_would_be_laid() -> void:
	var auto := _builder(AutoDeck.pool_from_sets(["4ed"]))
	auto.build()
	var candidates := auto._candidates(4)
	var mono := auto._mana_expected(candidates, Mtg.ManaColor.R, 36, 24, 0)
	assert_almost_eq(float(mono[Mtg.ManaColor.R]), 24.0, 0.001, "a mono deck's colour gets every land")
	assert_eq(mono.size(), 1)
	var pair := auto._mana_expected(candidates, Mtg.ManaColor.R | Mtg.ManaColor.G, 36, 24, 0)
	assert_almost_eq(float(pair[Mtg.ManaColor.R]) + float(pair[Mtg.ManaColor.G]), 24.0, 0.001,
		"the pair shares the 24: %s" % pair)
	assert_gt(float(pair[Mtg.ManaColor.R]), float(pair[Mtg.ManaColor.G]), "Fourth Edition's red is the deeper: %s" % pair)
	assert_lt(float(pair[Mtg.ManaColor.G]), 12.0, "green under an even share on its cards")
	var asked := auto._mana_expected(candidates, Mtg.ManaColor.R | Mtg.ManaColor.G, 36, 24, Mtg.ManaColor.G)
	assert_almost_eq(float(asked[Mtg.ManaColor.G]), 12.0, 0.001, "green asked for: the even share at least")
	assert_almost_eq(float(asked[Mtg.ManaColor.R]), float(pair[Mtg.ManaColor.R]), 0.001, "red's share as it was")
	# The strain: Craw Wurm's double pip wants fifteen Forests and on
	# green's share of the pair is short most of them; a Bolt on red's
	# share wants nothing; and green asked for eases the Wurm.
	var wurm := _card("Craw Wurm")
	assert_almost_eq(auto._source_strain(wurm, pair),
		AutoDeck.SOURCE_STRAIN * (AutoDeck.sources_for(2, 6, 60) - float(pair[Mtg.ManaColor.G])), 0.001)
	assert_eq(auto._source_strain(_card("Lightning Bolt"), pair), 0.0, "a red one-drop on twenty Mountains")
	assert_lt(auto._source_strain(wurm, asked), auto._source_strain(wurm, pair))
	assert_eq(auto._source_strain(wurm, mono), AutoDeck.SOURCE_STRAIN * AutoDeck.sources_for(2, 6, 60),
		"nothing expected of a colour the set is not")
	# A colour with no card among the best gets no land — and, asked
	# for, the even share still.
	var five := auto._mana_expected(candidates, 31, 36, 24, 0)
	assert_eq(five.size(), 5)
	var floored := auto._mana_expected(candidates, 31, 36, 24, 31)
	for color in Mtg.WUBRG:
		assert_gte(float(floored[color]), 24.0 / 5, "%s asked for: 4.8 at least" % AutoDeck.color_phrase(color))
		assert_gte(float(floored[color]), float(five[color]))


## The splash the lands cannot carry (2026-09-26, [method
## AutoDeck._drop_splashes]): The Dark's red is worth a second colour
## to the choice, but the fill takes a card or two of it — under
## [constant AutoDeck.SPLASH_CARDS] — and the deck is better mono-green
## than green with a Mountain or three. Asked for, red stays: the
## quota's cards of it at least, on the lands its pips are laid for,
## and the notes own how light that is.
func test_a_splash_the_lands_cannot_carry_leaves_the_deck() -> void:
	for size in [60, 40]:
		var auto := _builder(AutoDeck.pool_from_sets(["drk"]))
		auto.size = size
		var deck := auto.build()
		assert_eq(auto._first_choice, Mtg.ManaColor.R | Mtg.ManaColor.G, "%d: red-green chosen at first" % size)
		assert_eq(auto._splashed, Mtg.ManaColor.R, "%d: red was the splash" % size)
		assert_eq(auto.chosen_colors, Mtg.ManaColor.G, "%d: green stays" % size)
		assert_eq(auto.cast_colors, Mtg.ManaColor.G)
		assert_true(deck.deck_name.begins_with("Mono-Green "), deck.deck_name)
		assert_eq(int(auto._cards_of_colors(deck).get(Mtg.ManaColor.R, 0)), 0, "no red card left")
		assert_eq(deck.count_of("Mountain"), 0)
		_assert_legal(deck, auto, size)
		_assert_lands_settled(deck, auto)
		assert_true(deck.notes.contains("Red-Green chosen, but the lands could not carry the red the fill took a card or two of; the spells are green."),
			deck.notes)
		assert_false(deck.notes.contains("light on the lands"), deck.notes)
	for size in [60, 40]:
		var asked := _builder(AutoDeck.pool_from_sets(["drk"]))
		asked.size = size
		asked.colors = Mtg.ManaColor.R | Mtg.ManaColor.G
		var deck := asked.build()
		assert_eq(asked.chosen_colors, Mtg.ManaColor.R | Mtg.ManaColor.G)
		assert_eq(asked._splashed, 0, "a colour asked for is never dropped")
		var red := int(asked._cards_of_colors(deck).get(Mtg.ManaColor.R, 0))
		assert_gte(red, int(AutoDeck.SPLASH_CARDS[size]), "%d: %d red cards, the quota at least" % [size, red])
		assert_true(deck.deck_name.begins_with("Red-Green "), deck.deck_name)
		_assert_legal(deck, asked, size)
		assert_eq(asked._thin_colors(deck), Mtg.ManaColor.R, "%d: The Dark's red is light" % size)
		assert_lt(asked._sources_in(deck, Mtg.ManaColor.R), AutoDeck.sources_for(1, 5, size))
		assert_true(deck.notes.contains("Red asked for, and light on the lands: %s." % asked._thin_words(deck, Mtg.ManaColor.R)),
			deck.notes)
		assert_false(deck.notes.contains("could not carry"), deck.notes)


## The builder's own second colour, kept for the cards it has but laid
## for by its pips (2026-09-26): Arabian Nights' green is six cards on
## six Forests behind the blue, and the notes say what that is.
func test_a_light_second_colour_is_owned_in_the_notes() -> void:
	var auto := _builder(AutoDeck.pool_from_sets(["arn"]), 1)
	var deck := auto.build()
	assert_eq(auto.chosen_colors, Mtg.ManaColor.U | Mtg.ManaColor.G, deck.deck_name)
	assert_eq(auto._splashed, 0, "green's cards are a colour, not a splash")
	var green := int(auto._cards_of_colors(deck).get(Mtg.ManaColor.G, 0))
	assert_gte(green, int(AutoDeck.SPLASH_CARDS[60]))
	assert_eq(auto._thin_colors(deck), Mtg.ManaColor.G, "green's Forests are under what one late pip wants")
	assert_lt(auto._sources_in(deck, Mtg.ManaColor.G), AutoDeck.sources_for(1, 5, 60))
	assert_eq(auto._thin_words(deck, Mtg.ManaColor.G),
		"%d cards of it on %d sources" % [green, auto._sources_in(deck, Mtg.ManaColor.G)])
	assert_true(deck.notes.contains("Green chosen for its cards, and light on the lands: %s." % auto._thin_words(deck, Mtg.ManaColor.G)),
		deck.notes)
	assert_false(deck.notes.contains("Blue chosen"), "blue is laid for: " + deck.notes)
	# One card on one source reads in the singular.
	var one := DeckModel.new()
	one.add("Llanowar Elves")
	one.add("Forest")
	assert_eq(auto._thin_words(one, Mtg.ManaColor.G), "1 card of it on 1 source")


## The colours asked for are in the deck (2026-09-26): five colours
## from the library, whose red runs deepest, still hold [constant
## AutoDeck.SPLASH_CARDS] cards of each — the quota is a nudge on the
## fill, not on the lands — and the light ones are owned in the notes.
func test_every_colour_asked_for_has_its_quota_of_cards() -> void:
	var auto := _builder(_library())
	auto.colors = 31
	var deck := auto.build()
	var cards := auto._cards_of_colors(deck)
	for color in Mtg.WUBRG:
		assert_gte(int(cards.get(color, 0)), int(AutoDeck.SPLASH_CARDS[60]),
			"%s: %d cards" % [AutoDeck.color_phrase(color), int(cards.get(color, 0))])
	assert_gt(int(cards[Mtg.ManaColor.R]), int(cards[Mtg.ManaColor.W]), "red the deepest: %s" % cards)
	var thin := auto._thin_colors(deck)
	assert_ne(thin, 0, "five colours on 24 lands: some are light")
	for color in Mtg.WUBRG:
		var line := "%s asked for, and light on the lands: " % AutoDeck.color_phrase(color).replace("Mono-", "")
		assert_eq(deck.notes.contains(line), (thin & color) != 0, line)
	# Four in forty: three cards of each, and none of the fifth.
	var forty := _builder(_library())
	forty.size = 40
	forty.colors = Mtg.ManaColor.W | Mtg.ManaColor.U | Mtg.ManaColor.B | Mtg.ManaColor.G
	deck = forty.build()
	cards = forty._cards_of_colors(deck)
	for color in [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B, Mtg.ManaColor.G]:
		assert_gte(int(cards.get(color, 0)), int(AutoDeck.SPLASH_CARDS[40]), "%s: %s" % [AutoDeck.color_phrase(color), cards])
	assert_eq(int(cards.get(Mtg.ManaColor.R, 0)), 0, "no red card in a deck not red")
	_assert_legal(deck, forty, 40)


## Variety (2026-09-26): at 0 the seed is a hair, at 100 a taste for
## every name — different seeds build genuinely different decks, the
## same seed the same deck.
func test_variety_lets_the_seed_into_the_cards() -> void:
	var stiff: Array = []
	var loose: Array = []
	var wild: Array = []
	for seed in [11, 22, 33, 44]:
		var auto := _builder(_library(), seed)
		auto.colors = Mtg.ManaColor.W | Mtg.ManaColor.G
		stiff.append(AutoDeck.builders_cards(auto.build()))
		auto.variety = 50
		var deck := auto.build()
		_assert_legal(deck, auto, 60)
		assert_true(deck.notes.contains("Variety 50: the seed's taste moved each card's worth by up to 0.75."), deck.notes)
		loose.append(AutoDeck.builders_cards(deck))
		auto.variety = 100
		deck = auto.build()
		_assert_legal(deck, auto, 60)
		wild.append(AutoDeck.builders_cards(deck))
	var stiff_gap := _least_difference(stiff)
	var loose_gap := _least_difference(loose)
	var wild_gap := _least_difference(wild)
	assert_lt(stiff_gap, 0.15, "at variety 0 four seeds are one deck but for a hair: %.2f apart at least" % stiff_gap)
	assert_gt(loose_gap, stiff_gap, "at 50 they part: %.2f" % loose_gap)
	assert_gt(loose_gap, 0.2, "by a fifth at least: %.2f" % loose_gap)
	assert_gt(wild_gap, loose_gap, "at 100 further: %.2f" % wild_gap)
	var again := _builder(_library(), 33)
	again.colors = Mtg.ManaColor.W | Mtg.ManaColor.G
	again.variety = 100
	assert_eq(AutoDeck.builders_cards(again.build()), wild[2], "the same seed and variety, the same deck")
	assert_eq(AutoDeck.VARIETY_LEVELS, [0, 25, 50, 100] as Array[int])
	# Above 0 the builder's own colour choice follows the seed too.
	var choices := {}
	for seed in [11, 22, 33, 44, 55, 66]:
		var free := _builder(_library(), seed)
		free.variety = 100
		free.build()
		choices[free.chosen_colors] = true
	assert_gt(choices.size(), 1, "six seeds at variety 100 choose more than one colour pair")


## The least difference between any two of the decks ([method
## AutoDeck.difference]).
func _least_difference(decks: Array) -> float:
	var least := 1.0
	for i in decks.size():
		for j in range(i + 1, decks.size()):
			least = minf(least, AutoDeck.difference(decks[i], decks[j]))
	return least


func test_the_difference_between_two_decks() -> void:
	var a := {"Lightning Bolt": 4, "Serra Angel": 2, "Counterspell": 4}
	var b := {"Lightning Bolt": 4, "Serra Angel": 1, "Wrath of God": 2}
	assert_almost_eq(AutoDeck.difference(a, a), 0.0, 0.001, "a deck and itself")
	assert_almost_eq(AutoDeck.difference(a, b), 0.5, 0.001, "five of ten shared")
	assert_almost_eq(AutoDeck.difference(a, {}), 1.0, 0.001, "nothing shared")
	assert_almost_eq(AutoDeck.difference({}, {}), 0.0, 0.001, "two empty decks are one")
	var deck := DeckModel.new()
	for i in 4:
		deck.add("Lightning Bolt")
	deck.add("Mountain")
	deck.add("Taiga")
	var kept := DeckModel.new()
	kept.add("Lightning Bolt")
	assert_eq(AutoDeck.builders_cards(deck), {"Lightning Bolt": 4, "Taiga": 1}, "no basics")
	assert_eq(AutoDeck.builders_cards(deck, kept), {"Lightning Bolt": 3, "Taiga": 1}, "less the kept")


func test_the_lean_sets_the_creature_share() -> void:
	var shares := {}
	for lean in AutoDeck.LEANS:
		var auto := _builder(_library())
		auto.lean = lean
		var deck := auto.build()
		_assert_legal(deck, auto, 60)
		shares[lean] = float(_creatures(deck)) / (60 - _lands(deck))
	assert_gt(float(shares[AutoDeck.LEAN_CREATURES]), float(shares[AutoDeck.LEAN_BALANCED]),
		"more creatures: %s" % str(shares))
	assert_gt(float(shares[AutoDeck.LEAN_BALANCED]), float(shares[AutoDeck.LEAN_SPELLS]),
		"more spells: %s" % str(shares))
	assert_almost_eq(float(shares[AutoDeck.LEAN_CREATURES]), 0.70, 0.12, "about seven in ten")
	assert_almost_eq(float(shares[AutoDeck.LEAN_SPELLS]), 0.38, 0.12, "under four in ten")


## The tiers of a deck's non-basic cards, `tier -> copies`.
func _tiers(deck: DeckModel) -> Dictionary:
	var out := {}
	for name in deck.names():
		if AutoDeck.BASICS.has(name):
			continue
		var tier := DeckStats.rarity_tier(DeckModel._card(name))
		out[tier] = int(out.get(tier, 0)) + int(deck.counts[name])
	return out


## The rarity wish is a floor and a ceiling (2026-09-18): commons only,
## no rares, uncommons and up, rares and legends only.
func test_the_rarity_wish_holds() -> void:
	var commons := _builder(_library())
	commons.rarity = AutoDeck.RARITY_PAUPER
	var deck := commons.build()
	_assert_legal(deck, commons, 60)
	var tiers := _tiers(deck)
	for tier in tiers:
		assert_true(tier == "common" or tier == "", "a pauper deck: %s" % str(tiers))
	assert_true(deck.notes.contains("Rarity: commons only."), deck.notes)
	var uncommons := _builder(_library())
	uncommons.rarity = AutoDeck.RARITY_NO_RARES
	deck = uncommons.build()
	tiers = _tiers(deck)
	assert_false(tiers.has("rare") or tiers.has("legendary"), "no rares, no legends: %s" % str(tiers))
	assert_true(tiers.has("uncommon"), "the uncommons are allowed in: %s" % str(tiers))
	assert_true(deck.notes.contains("Rarity: no rares, no legends."), deck.notes)
	var uncommon_up := _builder(_library())
	uncommon_up.rarity = AutoDeck.RARITY_UNCOMMON_UP
	deck = uncommon_up.build()
	_assert_legal(deck, uncommon_up, 60)
	tiers = _tiers(deck)
	assert_false(tiers.has("common") or tiers.has(""), "uncommon up: no commons in %s" % str(tiers))
	assert_true(tiers.has("uncommon") and tiers.has("rare"), "uncommons and rares both: %s" % str(tiers))
	assert_eq(uncommon_up.short_by, 0, "the library has uncommons enough")
	assert_true(deck.notes.contains("Rarity: uncommons, rares and legends."), deck.notes)
	var rares := _builder(_library())
	rares.rarity = AutoDeck.RARITY_RARES
	deck = rares.build()
	_assert_legal(deck, rares, 60)
	tiers = _tiers(deck)
	for tier in tiers:
		assert_true(tier == "rare" or tier == "legendary", "only rares: %s" % str(tiers))
	assert_true(tiers.has("rare"), "and there are rares: %s" % str(tiers))
	assert_eq(rares.short_by, 0, "the library has rares enough for sixty")
	assert_true(deck.notes.contains("Rarity: rares and legends only."), deck.notes)
	# The old ceiling words still read, and a stranger falls back to any.
	var odd := _builder({"Lightning Bolt": 4})
	odd.rarity = "mythic"
	odd.build()
	assert_eq(odd.rarity, AutoDeck.RARITY_ANY)
	assert_eq(AutoDeck.RARITY_PAUPER, "common", "the saved words of the first release")
	assert_eq(AutoDeck.RARITY_NO_RARES, "uncommon")


func test_the_tournament_rules_bar_the_banned_and_cap_the_restricted() -> void:
	var pool := {"Contract from Below": 4, "Black Lotus": 4, "Lightning Bolt": 4, "Hypnotic Specter": 4}
	var auto := _builder(pool)
	auto.colors = Mtg.ManaColor.B | Mtg.ManaColor.R
	auto.power_nine = true   # the Lotus is one of the nine (2026-09-18)
	var deck := auto.build()
	_assert_legal(deck, auto, 60)
	assert_eq(deck.count_of("Contract from Below"), 0, "banned")
	assert_eq(deck.count_of("Black Lotus"), 1, "restricted: one")
	assert_eq(deck.count_of("Lightning Bolt"), 4)
	assert_eq(deck.count_of("Hypnotic Specter"), 4)
	assert_eq(auto.short_by, 36 - 9, "the rest of the spells are missing")
	assert_eq(_lands(deck), 24 + 27, "and basics fill the deck")
	assert_true(deck.notes.contains("The pool ran out after 9 spells; 27 extra basic lands fill the deck."), deck.notes)
	auto.tournament = false
	deck = auto.build()
	assert_eq(deck.count_of("Contract from Below"), 4, "allowed without the rules")
	assert_eq(deck.count_of("Black Lotus"), 4)
	assert_true(deck.notes.contains("Built without the tournament rules: banned and restricted cards were allowed."), deck.notes)


func test_a_legend_comes_twice_at_most() -> void:
	var auto := _builder({"Tetsuo Umezawa": 4, "Lightning Bolt": 4})
	auto.colors = Mtg.ManaColor.U | Mtg.ManaColor.B | Mtg.ManaColor.R
	var deck := auto.build()
	_assert_legal(deck, auto, 60)
	assert_eq(deck.count_of("Tetsuo Umezawa"), AutoDeck.LEGEND_CAP, "one in play at a time")
	assert_eq(deck.count_of("Lightning Bolt"), 4)
	assert_true(deck.count_of("Island") >= 2 and deck.count_of("Swamp") >= 2 and deck.count_of("Mountain") >= 2,
		"the three colours each get their two basics: %s" % str(deck.counts))


func test_the_kept_cards_go_in_first_and_set_the_colours() -> void:
	var keep := DeckModel.new()
	for i in 4:
		keep.add("Lightning Bolt")
	keep.add("Serra Angel")
	keep.add("Serra Angel")
	keep.add("Plains")
	var auto := _builder(_library())
	auto.keep = keep
	var deck := auto.build()
	_assert_legal(deck, auto, 60)
	assert_eq(auto.chosen_colors, Mtg.ManaColor.W | Mtg.ManaColor.R, "the kept cards' colours")
	assert_eq(deck.count_of("Lightning Bolt"), 4)
	assert_eq(deck.count_of("Serra Angel"), 2)
	assert_true(deck.notes.contains("Built around the 6 cards already on the surface."), deck.notes)
	_assert_lands_settled(deck, auto)
	assert_eq(deck.count_of("Plains") + deck.count_of("Mountain"), _lands(deck), "the kept Plains is not counted; the lands are laid fresh")


func test_a_seed_is_a_deck() -> void:
	var one := _builder(_library(), 1234).build()
	var again := _builder(_library(), 1234).build()
	assert_eq(again.counts, one.counts, "same seed, same deck")
	assert_eq(again.notes, one.notes)
	var other := _builder(_library(), 4321)
	other.build()
	assert_eq(other.roll, 4321, "the roll is the seed given")
	var fresh := _builder(_library(), 0)
	fresh.build()
	assert_true(fresh.roll >= 1 and fresh.roll <= 999_999, "a fresh roll when none is given: %d" % fresh.roll)
	assert_true(fresh.report[fresh.report.size() - 1].begins_with("Seed %d:" % fresh.roll))


func test_an_empty_pool_builds_lands_and_says_so() -> void:
	var auto := _builder({})
	auto.colors = Mtg.ManaColor.R
	var deck := auto.build()
	assert_eq(deck.total(), 60)
	assert_eq(deck.count_of("Mountain"), 60, "the colour asked for, evenly")
	assert_eq(auto.short_by, 36)
	assert_true(deck.notes.contains("The pool ran out after 0 spells; 36 extra basic lands fill the deck."), deck.notes)
	auto.colors = 0
	deck = auto.build()
	assert_eq(deck.total(), 60, "and with no colour asked for, still a deck")


func test_a_bad_size_falls_back_to_sixty() -> void:
	var auto := _builder(_library())
	auto.size = 53
	auto.max_colors = 9
	auto.land_kind = "snow"
	var deck := auto.build()
	assert_eq(auto.size, 60)
	assert_eq(auto.max_colors, 5, "five colours at most")
	assert_eq(auto.land_kind, AutoDeck.LANDS_CLASSIC, "a land kind the builder does not know is classic")
	assert_eq(deck.total(), 60)


func test_five_colours_when_asked_for() -> void:
	var auto := _builder(_library())
	auto.colors = Mtg.ManaColor.W | Mtg.ManaColor.U | Mtg.ManaColor.B | Mtg.ManaColor.R | Mtg.ManaColor.G
	var deck := auto.build()
	assert_eq(auto.chosen_colors, auto.colors, "all five")
	_assert_legal(deck, auto, 60)
	assert_true(deck.deck_name.begins_with("White-Blue-Black-Red-Green "), deck.deck_name)
	for land in AutoDeck.BASICS:
		assert_gte(deck.count_of(land), 2, "%s: every colour with pips gets at least two" % land)
	_assert_lands_settled(deck, auto)
	# At most five with nothing ticked: the builder may still settle on
	# fewer — the per-colour discount is what keeps a deep pool from
	# always ending five colours — but never on more.
	var free := _builder(_library())
	free.max_colors = 5
	deck = free.build()
	assert_lte(AutoDeck._count_colors(free.chosen_colors), 5)
	_assert_legal(deck, free, 60)
	# Four colours asked for and a cap of one: the cap widens.
	var four := _builder(_library())
	four.colors = Mtg.ManaColor.W | Mtg.ManaColor.U | Mtg.ManaColor.B | Mtg.ManaColor.R
	four.max_colors = 1
	four.build()
	assert_eq(four.chosen_colors, four.colors)


## A gold deck (2026-09-18): multicoloured cards get [constant
## AutoDeck.GOLD_BONUS] on their worth, so the colour choice and the
## fill reach for them; and it is two colours at least.
func _gold_cards(deck: DeckModel) -> int:
	var n := 0
	for name in deck.names():
		if AutoDeck.is_gold(DeckModel._card(name)):
			n += int(deck.counts[name])
	return n


func test_a_gold_deck_prefers_multicoloured_cards() -> void:
	assert_true(AutoDeck.is_gold(_card("Tetsuo Umezawa")), "three colours")
	assert_true(AutoDeck.is_gold(_card("Marsh Goblins")), "two")
	assert_false(AutoDeck.is_gold(_card("Lightning Bolt")), "one")
	assert_false(AutoDeck.is_gold(_card("Black Lotus")), "none")
	var plain := _builder(_library())
	plain.colors = Mtg.ManaColor.U | Mtg.ManaColor.B
	var plain_deck := plain.build()
	var gold := _builder(_library())
	gold.colors = Mtg.ManaColor.U | Mtg.ManaColor.B
	gold.gold = true
	var gold_deck := gold.build()
	_assert_legal(gold_deck, gold, 60)
	assert_gt(_gold_cards(gold_deck), _gold_cards(plain_deck),
		"the gold deck holds more gold cards: %d against %d" % [_gold_cards(gold_deck), _gold_cards(plain_deck)])
	assert_gte(_gold_cards(gold_deck), 6,
		"the blue-black legends of Legends, all five-drops and up, two of each: %d" % _gold_cards(gold_deck))
	# Colours of its own choosing, the gold deck goes where the gold
	# cards are — red-green in the library, Scarwood Goblins and the
	# legends of the mountain.
	var free := _builder(_library())
	free.gold = true
	var free_deck := free.build()
	_assert_legal(free_deck, free, 60)
	assert_gte(_gold_cards(free_deck), 10, "%s: %d gold" % [free_deck.deck_name, _gold_cards(free_deck)])
	assert_true(gold_deck.notes.contains("A gold deck: multicoloured cards preferred; %d of the %d spells are gold." % [
		_gold_cards(gold_deck), 60 - _lands(gold_deck)]), gold_deck.notes)
	assert_false(plain_deck.notes.contains("A gold deck"), plain_deck.notes)
	var goblins := _card("Marsh Goblins")
	assert_almost_eq(gold.worth(goblins), plain.worth(goblins) + AutoDeck.GOLD_BONUS, 0.001, "the bonus")
	assert_eq(gold.worth(_card("Lightning Bolt")), plain.worth(_card("Lightning Bolt")), "and none for a plain card")
	assert_eq(gold.score(goblins), plain.score(goblins), "the score is the card's own")
	# Mono-coloured and gold cannot both be: two colours at least.
	var mono := _builder(_library())
	mono.max_colors = 1
	mono.gold = true
	mono.build()
	assert_eq(mono.max_colors, 2)
	assert_gte(AutoDeck._count_colors(mono.chosen_colors), 2, "a gold deck is never mono")
	# Even from a pool with no gold card in it — Fourth Edition has none
	# — and the notes say so.
	var none := _builder(AutoDeck.pool_from_sets(["4ed"]))
	none.gold = true
	none.rarity = AutoDeck.RARITY_RARES
	var none_deck := none.build()
	assert_eq(AutoDeck._count_colors(none.chosen_colors), 2, "two colours, not mono-red: %s" % none_deck.deck_name)
	assert_eq(none._splashed, 0, "a gold deck's second colour is never dropped as a splash (2026-09-26)")
	assert_eq(_gold_cards(none_deck), 0)
	# And a pool that ran out keeps every card it had (2026-09-26): the
	# three white cards of a seven-card list are no splash to drop.
	var seven := _builder(AutoDeck.pool_from_counts({"Lightning Bolt": 4, "Serra Angel": 2, "Disenchant": 1}))
	var seven_deck := seven.build()
	assert_eq(seven.chosen_colors, Mtg.ManaColor.W | Mtg.ManaColor.R, seven_deck.deck_name)
	assert_eq(seven._splashed, 0, "nothing to pick again: the white stays")
	assert_eq(seven_deck.count_of("Serra Angel"), 2)
	assert_eq(seven_deck.count_of("Disenchant"), 1)
	assert_eq(seven_deck.total(), 60)
	assert_gte(seven_deck.count_of("Plains"), 2, "and Plains for them")
	assert_true(none_deck.notes.contains("A gold deck: multicoloured cards preferred, but the pool had none the deck could cast."),
		none_deck.notes)


## The Power Nine (2026-09-18, the owner's playtest): a switch of their
## own, off by default. Off, the builder avoids all nine even from a
## pool that holds them; on, it puts the Lotus and the five Moxen in
## every deck and the blue three in a blue deck, one copy each under the
## tournament rules, and the notes say which.
func _power_cards(deck: DeckModel) -> Dictionary:
	var out := {}
	for name in AutoDeck.POWER_NINE:
		if deck.count_of(name) > 0:
			out[name] = deck.count_of(name)
	return out


func test_the_power_nine_are_avoided_unless_asked_for() -> void:
	var unlimited := AutoDeck.pool_from_sets(["2ed"])
	for name in AutoDeck.POWER_NINE:
		assert_true(unlimited.has(name), "Unlimited holds %s" % name)
	var plain := _builder(unlimited)
	plain.colors = Mtg.ManaColor.U | Mtg.ManaColor.R
	assert_false(plain.power_nine, "off by default")
	var plain_deck := plain.build()
	_assert_legal(plain_deck, plain, 60)
	assert_eq(_power_cards(plain_deck), {}, "not one of the nine")
	assert_true(plain_deck.notes.contains("The Power Nine left out: the switch is off."), plain_deck.notes)
	# On, in a blue deck: all nine, one copy each.
	var blue := _builder(unlimited)
	blue.colors = Mtg.ManaColor.U | Mtg.ManaColor.R
	blue.power_nine = true
	var blue_deck := blue.build()
	_assert_legal(blue_deck, blue, 60)
	var all_nine := {}
	for name in AutoDeck.POWER_NINE:
		all_nine[name] = 1
	assert_eq(_power_cards(blue_deck), all_nine, "all nine, once each under the tournament rules")
	assert_true(blue_deck.notes.contains("The Power Nine in play: Black Lotus, Mox Pearl, Mox Sapphire, Mox Jet, "
		+ "Mox Ruby, Mox Emerald, Ancestral Recall, Time Walk, Timetwister."), blue_deck.notes)
	assert_false(blue_deck.notes.contains("left out"), blue_deck.notes)
	# On, in a deck without blue: the Lotus and the Moxen — every Mox,
	# an off-colour one still pays the colourless part of a cost.
	var green := _builder(unlimited)
	green.colors = Mtg.ManaColor.R | Mtg.ManaColor.G
	green.power_nine = true
	var green_deck := green.build()
	_assert_legal(green_deck, green, 60)
	assert_eq(_power_cards(green_deck), {"Black Lotus": 1, "Mox Pearl": 1, "Mox Sapphire": 1,
		"Mox Jet": 1, "Mox Ruby": 1, "Mox Emerald": 1}, "the mana six; the blue three need blue")
	assert_true(green_deck.notes.contains("The Power Nine in play: Black Lotus, Mox Pearl, Mox Sapphire, Mox Jet, Mox Ruby, Mox Emerald."),
		green_deck.notes)
	# The bonus on their worth, and only theirs.
	var lotus := _card("Black Lotus")
	assert_almost_eq(blue.worth(lotus), plain.worth(lotus) + AutoDeck.POWER_BONUS, 0.001, "the bonus")
	assert_eq(blue.worth(_card("Lightning Bolt")), plain.worth(_card("Lightning Bolt")), "and none for a plain card")
	assert_eq(blue.score(lotus), plain.score(lotus), "the score is the card's own")
	# The pool must hold them: Fourth Edition has none.
	var fourth := _builder(AutoDeck.pool_from_sets(["4ed"]))
	fourth.colors = Mtg.ManaColor.U | Mtg.ManaColor.R
	fourth.power_nine = true
	var fourth_deck := fourth.build()
	_assert_legal(fourth_deck, fourth, 60)
	assert_eq(_power_cards(fourth_deck), {})
	assert_true(fourth_deck.notes.contains("The Power Nine asked for, but the pool, the rarity wish and the colours allowed none."),
		fourth_deck.notes)
	# And the rarity wish still holds: a pauper deck has no rares.
	var pauper := _builder(unlimited)
	pauper.colors = Mtg.ManaColor.U | Mtg.ManaColor.R
	pauper.power_nine = true
	pauper.rarity = AutoDeck.RARITY_PAUPER
	var pauper_deck := pauper.build()
	_assert_legal(pauper_deck, pauper, 60)
	assert_eq(_power_cards(pauper_deck), {}, "rares, all nine")
	assert_true(pauper_deck.notes.contains("The Power Nine asked for, but the pool, the rarity wish and the colours allowed none."),
		pauper_deck.notes)


## Classic lands (2026-09-18) are the five basics alone, whatever the
## pool holds; non-classic lands take the pool's duals and the lands
## with abilities first.
func test_classic_lands_are_the_basics_alone() -> void:
	var pool := AutoDeck.pool_from_sets(["4ed"])
	pool["Taiga"] = 4
	var auto := _builder(pool)
	auto.colors = Mtg.ManaColor.R | Mtg.ManaColor.G
	var deck := auto.build()
	_assert_legal(deck, auto, 60)
	assert_eq(auto.land_kind, AutoDeck.LANDS_CLASSIC, "the default")
	assert_eq(_nonbasics(deck), 0, "no Taiga, no Mishra's Factory: %s" % str(deck.counts))
	assert_eq(deck.count_of("Mountain") + deck.count_of("Forest"), _lands(deck))
	_assert_lands_settled(deck, auto)
	assert_false(deck.notes.contains("Non-classic"), deck.notes)


func test_non_classic_lands_take_the_duals_and_the_lands_with_abilities_first() -> void:
	var pool := AutoDeck.pool_from_sets(["4ed"])
	pool["Taiga"] = 4
	pool["Tundra"] = 4
	var auto := _builder(pool)
	auto.colors = Mtg.ManaColor.R | Mtg.ManaColor.G
	auto.land_kind = AutoDeck.LANDS_NONCLASSIC
	var deck := auto.build()
	_assert_legal(deck, auto, 60)
	assert_eq(deck.count_of("Taiga"), 4, "the red-green dual, all four")
	assert_eq(deck.count_of("Tundra"), 0, "a white-blue dual makes nothing the deck casts")
	assert_true(_nonbasics(deck) <= int(floor(AutoDeck.NONBASIC_SHARE * _lands(deck))),
		"%d non-basic lands within the share" % _nonbasics(deck))
	_assert_lands_settled(deck, auto)
	assert_true(deck.notes.contains("Non-classic lands: %d of the %d lands are not basics." % [_nonbasics(deck), _lands(deck)]), deck.notes)
	# The whole library, blue-black: the dual first, then the Factory
	# and the Library within the colourless room, the Maze within the
	# room for lands that make no mana, the restricted ones once.
	var wide := _builder(_library())
	wide.colors = Mtg.ManaColor.U | Mtg.ManaColor.B
	wide.land_kind = AutoDeck.LANDS_NONCLASSIC
	deck = wide.build()
	_assert_legal(deck, wide, 60)
	assert_eq(deck.count_of("Underground Sea"), 4, "the blue-black dual, all four")
	assert_gte(deck.count_of("Mishra's Factory"), 1, "the Factory is in: %s" % str(deck.counts))
	assert_eq(deck.count_of("Library of Alexandria"), 1, "restricted: once")
	assert_eq(deck.count_of("Tundra") + deck.count_of("Taiga") + deck.count_of("Karakas"), 0,
		"nothing that makes only colours the deck is not")
	for name in ["Sorrow's Path", "The Tabernacle at Pendrell Vale", "Seafarer's Quay", "Urza's Tower"]:
		assert_eq(deck.count_of(name), 0, "%s is not worth a slot" % name)
	var colorless := 0
	var no_mana := 0
	for name in deck.names():
		var data := DeckModel._card(name)
		if not data.is_land() or AutoDeck.BASICS.has(name):
			continue
		if (AutoDeck.produces(data) & wide.chosen_colors) == 0:
			colorless += int(deck.counts[name])
		if AutoDeck.produces(data) == 0:
			no_mana += int(deck.counts[name])
	assert_lte(colorless, int(AutoDeck.COLORLESS_ROOM[60]), "%d lands making no colour of the deck" % colorless)
	assert_lte(no_mana, int(AutoDeck.NO_MANA_ROOM[60]), "%d lands making no mana" % no_mana)
	assert_lte(_nonbasics(deck), 12, "half the lands at most: %d" % _nonbasics(deck))
	assert_true(deck.count_of("Island") >= 2 and deck.count_of("Swamp") >= 2, "the basics still carry the colours")
	# In forty, the rooms are smaller.
	wide.size = 40
	deck = wide.build()
	_assert_legal(deck, wide, 40)
	colorless = 0
	for name in deck.names():
		var data := DeckModel._card(name)
		if data.is_land() and not AutoDeck.BASICS.has(name) and (AutoDeck.produces(data) & wide.chosen_colors) == 0:
			colorless += int(deck.counts[name])
	assert_lte(colorless, int(AutoDeck.COLORLESS_ROOM[40]))
	assert_lte(_nonbasics(deck), 8, "half of 16: %d" % _nonbasics(deck))


func test_a_land_s_worth_to_the_deck() -> void:
	var auto := _builder({})
	auto.chosen_colors = Mtg.ManaColor.U | Mtg.ManaColor.B
	var sea := auto.land_worth(_card("Underground Sea"))
	assert_almost_eq(sea, 2.5, 0.001, "a dual of the deck's colours: two and a half")
	assert_eq(auto.land_worth(_card("Taiga")), 0.0, "a dual of two other colours is worth nothing to it")
	assert_eq(auto.land_worth(_card("Karakas")), 0.0, "an ability on a colour the deck is not, neither")
	assert_eq(auto.land_worth(_card("Tundra")), AutoDeck.LAND_FLOOR, "an Island with a white side is an Island, no more")
	var city := auto.land_worth(_card("City of Brass"))
	assert_lt(city, sea, "City of Brass in two colours is a dual that hurts: %.2f" % city)
	assert_gt(city, 1.5, "but well worth a slot")
	var factory := auto.land_worth(_card("Mishra's Factory"))
	assert_lt(factory, sea, "the Factory comes after the dual")
	assert_gt(factory, auto.land_worth(_card("Strip Mine")), "and before the Strip Mine")
	assert_gt(auto.land_worth(_card("Strip Mine")), auto.land_worth(_card("Desert")))
	assert_gt(auto.land_worth(_card("Urborg")), 1.0, "a Swamp with abilities is more than a Swamp")
	assert_lt(auto.land_worth(_card("Urborg")), sea)
	var maze := auto.land_worth(_card("Maze of Ith"))
	assert_gte(maze, AutoDeck.LAND_FLOOR, "the Maze makes no mana and is worth a slot: %.2f" % maze)
	assert_lt(maze, factory)
	assert_lt(auto.land_worth(_card("Sorrow's Path")), AutoDeck.LAND_FLOOR, "the Path hurts its owner")
	assert_lt(auto.land_worth(_card("The Tabernacle at Pendrell Vale")), AutoDeck.LAND_FLOOR)
	assert_lt(auto.land_worth(_card("Seafarer's Quay")), AutoDeck.LAND_FLOOR, "a band-land does nothing here")
	assert_lt(auto.land_worth(_card("Urza's Tower")), AutoDeck.LAND_FLOOR, "one Urza's land alone is a colourless land")
	auto.chosen_colors = Mtg.ManaColor.W | Mtg.ManaColor.U | Mtg.ManaColor.B
	assert_gt(auto.land_worth(_card("City of Brass")), auto.land_worth(_card("Underground Sea")),
		"in three colours the City is the best land there is")
	auto.chosen_colors = Mtg.ManaColor.U
	assert_lt(auto.land_worth(_card("City of Brass")), AutoDeck.LAND_FLOOR, "and in one it is an Island that hurts")
	auto.chosen_colors = Mtg.ManaColor.U | Mtg.ManaColor.B
	assert_lt(auto.land_worth(_card("Bazaar of Baghdad")), auto.land_worth(_card("Maze of Ith")))


# ------------------------------------------------------------ the score --

func _card(name: String) -> CardData:
	return CardRegistry.get_card(name)


func test_a_body_per_mana_scores_a_creature() -> void:
	var auto := _builder({})
	var lions := auto.score(_card("Savannah Lions"))
	var bears := auto.score(_card("Grizzly Bears"))
	var wall := auto.score(_card("Wall of Wood"))
	var colossus := auto.score(_card("Colossus of Sardia"))
	assert_gt(lions, bears, "a 2/1 for one beats a 2/2 for two")
	assert_gt(bears, wall, "a defender with no power is worth half its body")
	assert_gt(lions, colossus, "a 9/9 for nine that does not untap is a dead card most games")
	assert_gt(auto.score(_card("Serra Angel")), bears, "flying and vigilance are worth paying for")
	assert_gt(auto.score(_card("Llanowar Elves")), bears,
		"a 1/1 for one with a mana ability beats a bare 2/2 for two")


func test_a_role_scores_a_spell_and_a_narrow_answer_is_marked_down() -> void:
	var auto := _builder({})
	var bolt := auto.score(_card("Lightning Bolt"))
	var terror := auto.score(_card("Terror"))
	var cop := auto.score(_card("Circle of Protection: Red"))
	var shatter := auto.score(_card("Shatter"))
	assert_gt(bolt, 2.0, "burn for one: %.2f" % bolt)
	assert_gt(terror, 2.0, "removal for two: %.2f" % terror)
	assert_gt(bolt, cop, "a Circle of Protection is dead against most decks")
	assert_gt(terror, shatter, "artifact removal is narrower than creature removal")
	assert_gt(shatter, cop, "and colour hate is narrower still")
	assert_eq(auto.score(_card("Lightning Bolt")), bolt, "cached")


## The speed prices the mana value ([constant AutoDeck.TEMPO]) and the
## lean the roles ([constant AutoDeck.LEAN_ROLE_SCALE]); the score
## itself knows neither the curve nor the speed.
func test_the_speed_prices_the_cost_and_the_lean_the_roles() -> void:
	var fast := _builder({})
	fast.speed = AutoDeck.SPEED_FAST
	var medium := _builder({})
	var slow := _builder({})
	slow.speed = AutoDeck.SPEED_SLOW
	var bolt := _card("Lightning Bolt")
	var dragon := _card("Shivan Dragon")
	assert_eq(fast.score(bolt), slow.score(bolt), "the score is the card's own")
	assert_gt(fast.worth(bolt), medium.worth(bolt), "a fast deck prizes its one-drops")
	assert_gt(medium.worth(bolt), slow.worth(bolt), "a slow deck does not")
	assert_gt(slow.worth(dragon), medium.worth(dragon), "a slow deck prizes its six-drops")
	assert_gt(medium.worth(dragon), fast.worth(dragon), "a fast deck discounts them")
	assert_eq(medium.worth(dragon), medium.score(dragon), "medium takes the card at its score")
	assert_almost_eq(fast.worth(bolt), fast.score(bolt) * 1.2, 0.001, "a fifth over")
	assert_almost_eq(fast.worth(dragon), fast.score(dragon) * 0.7, 0.001, "seven tenths")
	var creatures := _builder({})
	creatures.lean = AutoDeck.LEAN_CREATURES
	var spells := _builder({})
	spells.lean = AutoDeck.LEAN_SPELLS
	assert_gt(creatures.score(_card("Giant Growth")), spells.score(_card("Giant Growth")),
		"a deck of creatures wants its pump")
	assert_gt(spells.score(_card("Wrath of God")), creatures.score(_card("Wrath of God")),
		"a deck of spells wants the sweeper that a deck of creatures fears")
	assert_gt(spells.score(_card("Counterspell")), creatures.score(_card("Counterspell")),
		"and the counters")
	assert_eq(medium.score(_card("Terror")), creatures.score(_card("Terror")),
		"removal is removal in any deck")


## The 2026-09-26 A/B's two lessons ([method AutoDeck._spell_score],
## [method AutoDeck._drawbacks], [method AutoDeck._sacrifice_cost]): an
## X spell is priced at the mana it is cast for, not the cheapest card in
## the pool; a spell that asks for a Goblin to be sacrificed is as dead
## as colour hate in a deck with no Goblin; a creature that enters asking
## for another, or flips a coin to attack, is worth less than its body.
func test_a_spell_is_priced_at_the_mana_it_is_cast_for_and_what_it_asks() -> void:
	var auto := _builder({})
	var bolt := auto.score(_card("Lightning Bolt"))
	assert_lt(auto.score(_card("Fireball")), bolt, "a Fireball is cast for three, a Bolt for one")
	assert_gt(auto.score(_card("Fireball")), 2.0, "and is still a good card: %.2f" % auto.score(_card("Fireball")))
	var five := CardData.new("Test Five", "{R}", Mtg.CardType.SORCERY)
	five.spell(DamageEffect.new(5).any_target())
	five.oracle("Test Five deals 5 damage to any target.")
	var grenade := CardData.new("Test Grenade", "{R}", Mtg.CardType.SORCERY)
	grenade.spell(DamageEffect.new(5).any_target())
	grenade.oracle("As an additional cost to cast this spell, sacrifice a Goblin.\nTest Grenade deals 5 damage to any target.")
	grenade.with_additional_sacrifice("Goblin", Callable())
	var blade := CardData.new("Test Blade", "{R}", Mtg.CardType.SORCERY)
	blade.spell(DamageEffect.new(5).any_target())
	blade.with_additional_sacrifice("a creature", Callable())
	assert_gt(auto.score(five), bolt, "five damage for one, no strings")
	assert_lt(auto.score(grenade), bolt, "five damage for one and a Goblin the deck may not have")
	assert_lt(auto.score(blade), auto.score(five), "a creature spent is a card spent")
	assert_gt(auto.score(blade), auto.score(grenade), "but a creature is easier found than a Goblin")
	assert_eq(AutoDeck._sacrifice_cost(five), 0.0)
	assert_eq(AutoDeck._sacrifice_cost(grenade), 1.8)
	assert_eq(AutoDeck._sacrifice_cost(blade), 0.8)
	var dead := CardData.new("Test Dead", "{B}", Mtg.CardType.CREATURE).pt(3, 1)
	dead.oracle("When this creature enters, sacrifice a creature.")
	var elemental := CardData.new("Test Elemental", "{1}{G}", Mtg.CardType.CREATURE).pt(3, 4)
	elemental.oracle("When this creature enters the battlefield, sacrifice it unless you sacrifice a Forest.")
	var force := CardData.new("Test Force", "{2}{G}{G}{G}", Mtg.CardType.CREATURE).pt(8, 8)
	force.oracle("When this creature enters, sacrifice it unless you sacrifice three Forests.")
	var horde := CardData.new("Test Horde", "{2}{R}{R}", Mtg.CardType.CREATURE).pt(5, 5)
	horde.oracle("When this creature enters, sacrifice it unless you discard a card at random.")
	var plain := CardData.new("Test Plain", "{B}", Mtg.CardType.CREATURE).pt(3, 1)
	assert_eq(AutoDeck._drawbacks(plain), 0.0)
	assert_eq(AutoDeck._drawbacks(dead), 1.0, "enters asking for a creature")
	assert_eq(AutoDeck._drawbacks(horde), 1.0, "enters asking for a card from the hand")
	assert_eq(AutoDeck._drawbacks(elemental), 2.0, "enters asking for a Forest from the table")
	assert_eq(AutoDeck._drawbacks(force), 6.0, "enters asking for three of them")
	var fair := CardData.new("Test Fair", "{2}{G}{G}{G}", Mtg.CardType.CREATURE).pt(5, 5)
	assert_almost_eq(auto.score(force), auto.score(fair), 0.001,
		"an 8/8 for five that eats three Forests is a 5/5 for five")
	assert_lt(auto.score(dead), auto.score(plain), "a 3/1 for one that eats a creature is not a 3/1 for one")
	assert_eq(AutoDeck._drawbacks(_card("Mijae Djinn")), 0.6, "a coin flip to attack")
	assert_gt(AutoDeck._drawbacks(_card("Ball Lightning")), 0.0, "sacrificed at end of turn")
	assert_eq(AutoDeck._drawbacks(_card("Grizzly Bears")), 0.0)


func test_castable_and_produces_read_the_card() -> void:
	assert_true(AutoDeck.castable(_card("Lightning Bolt"), Mtg.ManaColor.R))
	assert_false(AutoDeck.castable(_card("Lightning Bolt"), Mtg.ManaColor.W))
	assert_true(AutoDeck.castable(_card("Black Lotus"), Mtg.ManaColor.W), "colourless goes anywhere")
	assert_true(AutoDeck.castable(_card("Tetsuo Umezawa"), Mtg.ManaColor.U | Mtg.ManaColor.B | Mtg.ManaColor.R))
	assert_false(AutoDeck.castable(_card("Tetsuo Umezawa"), Mtg.ManaColor.U | Mtg.ManaColor.B))
	assert_eq(AutoDeck.produces(_card("Taiga")), Mtg.ManaColor.R | Mtg.ManaColor.G)
	assert_eq(AutoDeck.produces(_card("Llanowar Elves")), Mtg.ManaColor.G)
	assert_eq(AutoDeck.produces(_card("Lightning Bolt")), 0)


func test_the_words() -> void:
	assert_eq(AutoDeck.color_phrase(0), "Colourless")
	assert_eq(AutoDeck.color_phrase(Mtg.ManaColor.W), "Mono-White")
	assert_eq(AutoDeck.color_phrase(Mtg.ManaColor.B | Mtg.ManaColor.U), "Blue-Black", "WUBRG order")
	assert_eq(AutoDeck.color_phrase(Mtg.ManaColor.G | Mtg.ManaColor.W | Mtg.ManaColor.R), "White-Red-Green")
	var auto := _builder({})
	auto.chosen_colors = Mtg.ManaColor.R | Mtg.ManaColor.G
	auto.lean = AutoDeck.LEAN_CREATURES
	auto.speed = AutoDeck.SPEED_MEDIUM
	assert_eq(auto.deck_name(), "Red-Green Beatdown")
	auto.lean = AutoDeck.LEAN_SPELLS
	auto.speed = AutoDeck.SPEED_SLOW
	auto.chosen_colors = Mtg.ManaColor.U
	assert_eq(auto.deck_name(), "Mono-Blue Control")
	auto.lean = AutoDeck.LEAN_BALANCED
	auto.speed = AutoDeck.SPEED_FAST
	assert_eq(auto.deck_name(), "Mono-Blue Aggro")
	assert_eq(AutoDeck._bucket(_card("Black Lotus")), 0, "mana value 0 sits with the ones")
	assert_eq(AutoDeck._bucket(_card("Lightning Bolt")), 0)
	assert_eq(AutoDeck._bucket(_card("Serra Angel")), 4, "five and up is the last bucket")
	assert_eq(AutoDeck._bucket(_card("Shivan Dragon")), 4)
