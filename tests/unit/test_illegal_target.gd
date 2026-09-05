extends GameTest
## WHY A TARGET IS ILLEGAL — `docs/duel-todo.md` §6.10.
##
## `@PROMPT_ILLEGALTARGET` (`Program/UIStrings.txt:1145`) is
## `Illegal target.` / `Illegal target (%s).`, and `:1150`
## `@PROMPT_ILLEGALTARGETWHY` is the 29 words that go in the brackets.
## These tests pin the table, the ONE-reason rule the Manalink source
## proves (see [constant TargetSpec.WHY] — the item said they
## concatenate, and they do not), and the reason each of our own checks
## reports.
##
## The load-bearing test is the last one:
## [method TargetSpec.is_legal] is [method TargetSpec.refusal_reason]
## asked for a yes or no, so the two can never disagree. If somebody
## re-splits them, that test is what fails.


func test_the_29_reasons_are_the_1997_table_verbatim() -> void:
	var words: Array = []
	for key in TargetSpec.WHY:
		words.append(TargetSpec.WHY[key])
	assert_eq(words, [
		"player", "can't target this", "where", "controller", "owner",
		"type", "abilities", "color", "name", "subtype",
		"power", "toughness", "walls", "spell", "basic land",
		"artifact creature", "target player", "tapped", "attacking", "attacked",
		"blocked", "blocking", "attacking/blocking", "enchanted", "casted",
		"cast resolved", "damaged", "can untap", "will untap",
	], "@PROMPT_ILLEGALTARGETWHY, UIStrings.txt:1150, in the table's order")


func test_no_reason_carries_the_separator_comma() -> void:
	# The original STORES each reason with a leading comma because the
	# comma is a separator, and strips it before printing
	# (`targets.c:686`: `strcpy(return_error_str, &error_str[1])`).
	for key in TargetSpec.WHY:
		assert_false(String(TargetSpec.WHY[key]).begins_with(","),
			TargetSpec.WHY[key])


# --------------------------------------------------- one reason, not many --

func test_only_one_reason_comes_back_however_many_things_are_wrong() -> void:
	# A Black Knight (protection from white) in the GRAVEYARD offered to
	# a white spell that wants a creature on the battlefield: the wrong
	# zone AND protected AND (for Swords) the wrong colour. The original
	# emits the FIRST failing check and stops — every one of Manalink's
	# sixty failure sites ends in `goto epilog`.
	var knight := give_hand(1, "Black Knight")
	knight.zone = Mtg.Zone.GRAVEYARD
	g.players[1].hand.erase(knight)
	g.players[1].graveyard.append(knight)
	var swords := give_hand(0, "Swords to Plowshares")
	var spec: TargetSpec = swords.data.spell_effects[0].target_spec
	var why := spec.refusal_reason(g, TargetRef.card(knight), swords)
	assert_eq(why, "where", "the first failing check, and only it")
	assert_false(why.contains(","), "never a concatenation")


# ------------------------------------------------- the reasons we can name --

func test_the_wrong_zone_is_where() -> void:
	var bear := give_hand(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	var spec: TargetSpec = bolt.data.spell_effects[0].target_spec
	assert_eq(spec.refusal_reason(g, TargetRef.card(bear), bolt), "where")


func test_the_wrong_kind_of_permanent_is_type() -> void:
	var forest := put_battlefield(1, "Forest")
	var terror := give_hand(0, "Terror")
	var spec: TargetSpec = terror.data.spell_effects[0].target_spec
	assert_eq(spec.refusal_reason(g, TargetRef.card(forest), terror), "type")


func test_protection_is_abilities() -> void:
	# The original files every keyword refusal under `,abilities` — its own
	# shroud check does exactly that (`targets.c:219`).
	var knight := put_battlefield(1, "Black Knight")   # pro white
	var swords := give_hand(0, "Swords to Plowshares")
	var spec: TargetSpec = swords.data.spell_effects[0].target_spec
	assert_eq(spec.refusal_reason(g, TargetRef.card(knight), swords),
		"abilities")


func test_a_card_offered_where_a_player_is_wanted_is_target_player() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var drain := TargetSpec.player()
	assert_eq(drain.refusal_reason(g, TargetRef.card(bear), null),
		"target player")


func test_a_player_offered_where_a_creature_is_wanted_is_player() -> void:
	var terror := give_hand(0, "Terror")
	var spec: TargetSpec = terror.data.spell_effects[0].target_spec
	assert_eq(spec.refusal_reason(g, TargetRef.player(1), terror), "player")


func test_a_dead_player_is_player() -> void:
	g.players[1].has_lost = true
	assert_eq(TargetSpec.player().refusal_reason(g, TargetRef.player(1), null),
		"player")


func test_someone_elses_graveyard_is_owner() -> void:
	# "Your graveyard" means the ABILITY's controller (CR 109.5), and the
	# 1997 word for the wrong one is `,owner` — entry 5, checked before
	# `,type` in both the table and `targets.c`.
	var bear := give_hand(1, "Grizzly Bears")
	g.players[1].hand.erase(bear)
	bear.zone = Mtg.Zone.GRAVEYARD
	g.players[1].graveyard.append(bear)
	var raise := give_hand(0, "Raise Dead")
	var spec: TargetSpec = raise.data.spell_effects[0].target_spec
	assert_eq(spec.refusal_reason(g, TargetRef.card(bear), raise), "owner")


func test_a_filter_reports_type_unless_the_spec_says_otherwise() -> void:
	# Our filters are one opaque Callable each where the original had a
	# dozen typed fields, so the word is DECLARED. `type` is the default
	# because it is the original's most common answer by far.
	var plain := TargetSpec.creature("target creature",
		func(_i: CardInstance) -> bool: return false)
	assert_eq(plain.filter_reason, "type")
	var named := TargetSpec.creature("target tapped creature",
		func(_i: CardInstance) -> bool: return false) \
		.because(TargetSpec.WHY["tapped"])
	assert_eq(named.filter_reason, "tapped")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_eq(named.refusal_reason(g, TargetRef.card(bear), null), "tapped")


func test_a_legal_target_has_no_reason_at_all() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	var spec: TargetSpec = bolt.data.spell_effects[0].target_spec
	assert_eq(spec.refusal_reason(g, TargetRef.card(bear), bolt), "")
	assert_true(spec.is_legal(g, TargetRef.card(bear), bolt))


# ---------------------------------------------- the refusal reaches the API --

func test_the_engine_refuses_a_cast_in_the_originals_words() -> void:
	var forest := put_battlefield(1, "Forest")
	var terror := give_hand(0, "Terror")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, terror, [TargetRef.card(forest)]),
		"Illegal target (type).")


# ------------------------------------------------------- they cannot drift --

func test_is_legal_and_refusal_reason_are_the_same_question() -> void:
	# One set of checks, asked two ways. This is the test that fails if
	# anybody ever re-splits them into two implementations.
	var bear := put_battlefield(0, "Grizzly Bears")
	var knight := put_battlefield(1, "Black Knight")
	var wall := put_battlefield(1, "Wall of Wood")
	var forest := put_battlefield(1, "Forest")
	var dead := give_hand(1, "Grizzly Bears")
	dead.zone = Mtg.Zone.GRAVEYARD
	g.players[1].hand.erase(dead)
	g.players[1].graveyard.append(dead)
	var sources: Array[CardInstance] = [
		give_hand(0, "Swords to Plowshares"), give_hand(0, "Terror"),
		give_hand(0, "Lightning Bolt"), give_hand(0, "Raise Dead"),
		give_hand(0, "Counterspell"),
	]
	var specs: Array[TargetSpec] = []
	for src in sources:
		for e in src.data.spell_effects:
			if e.target_spec != null:
				specs.append(e.target_spec)
	var refs: Array[TargetRef] = [
		TargetRef.card(bear), TargetRef.card(knight), TargetRef.card(wall),
		TargetRef.card(forest), TargetRef.card(dead),
		TargetRef.player(0), TargetRef.player(1), null,
	]
	var checked := 0
	for spec in specs:
		for src in sources:
			for ref in refs:
				assert_eq(spec.is_legal(g, ref, src),
					spec.refusal_reason(g, ref, src) == "",
					"%s / %s" % [spec.description, src.data.card_name])
				checked += 1
	assert_gt(checked, 100, "the sweep really ran")


# ------------------------------------------------------------ CONCEDE (§6.3) --
#
# `@MENU_TERRITORY` entry 24, and an engine action rather than a screen one
# because three cards in the pool offer it as a CHOICE — `@DEMONIC_ATTORNEY`
# (`promptsX1.txt:121`), `@BRONZE_TABLET` (`prompts.txt:151`) and
# `@TEMPEST_EFREET` (`prompts.txt:877`) all print `Concede game.`

func test_conceding_loses_the_game_at_once() -> void:
	# CR 104.3a — "A player can concede the game at any time. A player who
	# concedes leaves the game immediately."
	assert_ok(g.concede(0))
	assert_true(g.game_over)
	assert_true(g.players[0].has_lost)
	assert_eq(g.winner, 1)


func test_conceding_needs_no_priority_and_no_stack() -> void:
	# "At any time" is the whole rule: it does not use the stack and it is
	# not something an opponent can respond to.
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.R)
	g.priority_player = 1
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_eq(g.stack.size(), 1, "something is waiting to resolve")
	# "and it is conceded through anyway" — with a spell still on the chain.
	assert_ok(g.concede(0))
	assert_eq(g.winner, 1)


func test_a_second_concession_is_refused_rather_than_asserted() -> void:
	assert_ok(g.concede(1))
	assert_refused(g.concede(0), "already over")
	assert_eq(g.winner, 0, "the first concession still decides it")
