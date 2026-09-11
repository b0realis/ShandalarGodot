extends GameTest
## A LAYER-6 GRANT PRINTED AS A STATIC CARRIES ITS OWN TIMESTAMP
## (CR 613.7) — 2026-09-11.
##
## The 2026-09-10 pass put layer 6's FLOATING half in timestamp order, so
## Radjan Spirit then Jump leaves a Serra Angel flying. What it could not
## reach, and wrote up where it lives, is the half printed as a STATIC:
## Flight, Fear, Lance, Concordant Crossroads and the landwalk lords all
## granted their ability in ContinuousEffects.recalculate's statics pass,
## which ran AHEAD of every floating entry — so a floating LOSS beat a
## static GRANT whatever the two timestamps said.
##
## The pool is full of the pair. Radjan Spirit grounds a Serra Angel; an
## Aura cast on it AFTERWARDS is the later effect and CR 613.7 says the
## later effect wins, so the Angel flies again. Urborg strips first strike
## and a Lance puts it back. Hammerheim strips all landwalk and a Fishliver
## Oil puts islandwalk back. Tolaria strips banding and a Fortified Area
## gives it back to every Wall. None of those worked.
##
## StaticAbility.changing_abilities() is the flag — the shape
## changing_types() (layer 4) and setting_base_pt() (layer 7b) already
## have. A flagged static is applied inside _layer_six at its SOURCE's
## battlefield timestamp (CardInstance.layer_timestamp, stamped from the
## same clock the floating entries use) among the grants and the losses,
## instead of in the statics pass — and the whole layer-6 pass moved ahead
## of the layer-7 statics with it, which is the order CR 613.1 prints.


## P1's own turn, so P1 can cast an Aura at sorcery speed while P0 answers
## with an activated ability. Returns with P0 holding priority in P1's
## first main phase.
func _their_turn_our_priority() -> void:
	advance_to_next_turn()          # P1's turn, main phase one
	assert_eq(g.active_player, 1)
	assert_ok(g.pass_priority(1))


# ------------------------------------------------------ the reproduction --

## THE REPRODUCTION. Ground the Angel, then enchant it: the Aura is the
## later effect and the Angel flies again.
func test_an_aura_cast_after_a_loss_grants_flying_again() -> void:
	var angel := put_battlefield(1, "Serra Angel")
	var spirit := put_battlefield(0, "Radjan Spirit")
	var flight := give_hand(1, "Flight")
	_their_turn_our_priority()
	assert_ok(g.activate_ability(0, spirit, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING), "grounded first")
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, flight, [TargetRef.card(angel)]))
	resolve_stack()
	assert_true(angel.has_keyword(Mtg.Keyword.FLYING),
		"the Aura's timestamp is the later one (CR 613.7)")


## And the other way round, which never moved: enchant it, then ground it.
func test_a_loss_after_an_aura_still_grounds_it() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var spirit := put_battlefield(0, "Radjan Spirit")
	var flight := give_hand(1, "Flight")
	advance_to_next_turn()          # P1's turn, main phase one
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, flight, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING), "flying first")
	assert_ok(g.pass_priority(1))
	assert_ok(g.activate_ability(0, spirit, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_false(bear.has_keyword(Mtg.Keyword.FLYING),
		"the loss is the later effect this time")


## First strike, the same shape: Urborg strips it, a Lance gives it back.
func test_a_lance_after_urborg_gives_first_strike_back() -> void:
	var knight := put_battlefield(1, "White Knight")
	var urborg := put_battlefield(0, "Urborg")
	var lance := give_hand(1, "Lance")
	_their_turn_our_priority()
	assert_ok(g.activate_ability(0, urborg, 0, [TargetRef.card(knight)]))
	resolve_stack()
	assert_false(knight.has_keyword(Mtg.Keyword.FIRST_STRIKE), "stripped")
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(1, lance, [TargetRef.card(knight)]))
	resolve_stack()
	assert_true(knight.has_keyword(Mtg.Keyword.FIRST_STRIKE),
		"the Lance is the later effect (CR 613.7)")


## LANDWALK is layer 6 too: Hammerheim strips it all, a Fishliver Oil cast
## afterwards puts islandwalk back.
func test_fishliver_oil_after_hammerheim_walks_again() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var hammerheim := put_battlefield(0, "Hammerheim")
	var oil := give_hand(1, "Fishliver Oil")
	_their_turn_our_priority()
	assert_ok(g.activate_ability(0, hammerheim, 0, [TargetRef.card(bear)]))
	resolve_stack()
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(1, oil, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.cur_landwalk.has("island"),
		"the Oil is the later effect (CR 613.7)")


## A static granting to a CLASS, not to one host: Tolaria strips banding
## from a Wall in the upkeep, and a Fortified Area that enters in the main
## phase afterwards gives it back.
func test_fortified_area_entering_later_gives_banding_back() -> void:
	var wall := put_battlefield(1, "Wall of Stone")
	var tolaria := put_battlefield(0, "Tolaria")
	var area := give_hand(1, "Fortified Area")
	advance_to_step(Mtg.Step.END)     # P0's turn out
	advance_to_step(Mtg.Step.UPKEEP)  # P1's upkeep, where Tolaria may fire
	assert_eq(g.active_player, 1)
	assert_ok(g.pass_priority(1))
	assert_ok(g.activate_ability(0, tolaria, 0, [TargetRef.card(wall)]))
	resolve_stack()
	assert_false(wall.has_keyword(Mtg.Keyword.BANDING), "stripped in the upkeep")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(1, area, []))
	resolve_stack()
	assert_true(wall.has_keyword(Mtg.Keyword.BANDING),
		"the enchantment entered later (CR 613.7)")
	assert_eq(wall.cur_power, 1,
		"and its layer-7c half is still a +1/+0 on a 0/8")


# ----------------------------------------------- the layer, not the clock --

## Layer 6 still precedes layer 7 (CR 613.1), and a continuous effect that
## MODIFIES THE RULES reads the abilities every layer settled. Moat is the
## pool's reader — "creatures without flying can't attack" — so a bear
## enchanted with Flight under a Moat must be able to attack whichever of
## the two entered first.
func test_moat_reads_the_flying_an_aura_granted() -> void:
	put_battlefield(0, "Moat")
	var bear := put_battlefield(1, "Grizzly Bears")
	var flight := give_hand(1, "Flight")
	advance_to_next_turn()          # P1's turn, main phase one
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, flight, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	assert_false(bear.cur_cant_attack,
		"the Moat read the granted flying (CR 613.1: layer 6 first)")


## THE NULL for every keyword nothing in the pool removes: Concordant
## Crossroads still hands out haste, and an ordinary Aura still grants,
## whatever pass they run in.
func test_a_static_grant_with_no_rival_still_grants() -> void:
	put_battlefield(0, "Concordant Crossroads")
	var bear := put_battlefield(0, "Grizzly Bears", true)
	g.recalculate()
	assert_true(bear.has_keyword(Mtg.Keyword.HASTE), "Crossroads still grants")
	var fear := give_hand(0, "Fear")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, fear, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FEAR), "and the Fear still grants")


## A permanent's layer timestamp is taken when it ENTERS the battlefield
## (CR 613.7b), from the same clock the floating effects use — which is
## the whole reason a static and a floating effect can be compared at all.
func test_a_permanent_is_stamped_as_it_enters() -> void:
	var first := put_battlefield(0, "Grizzly Bears")
	var second := put_battlefield(0, "Hill Giant")
	assert_gt(first.layer_timestamp, 0, "stamped on entry")
	assert_gt(second.layer_timestamp, first.layer_timestamp,
		"and the clock only runs forwards")


# ======================= THE SURVEY, PINNED =======================

## Every card file that writes a layer-6 ability onto a permanent declares
## the static that does it (StaticAbility.changing_abilities). A card that
## grants or strips one and does not say so would be applied out of order
## for ever with nothing noticing, which is exactly how this row was
## opened — the Adventurers' Guildhouse's "bands with other" was found by
## a test rather than by the survey on the day this was built.
##
## THE THREE SHAPES a pool LOSS can strip, and so the three a static has to
## be timestamped for: a keyword, a landwalk, and a "bands with other"
## (CR 702.22b makes that one fall to "loses banding"). Protection,
## rampage, a granted activated ability and a damage immunity are layer 6
## too and are deliberately NOT here, because nothing in the pool removes
## any of them — see ContinuousEffects._layer_six.
##
## Read from the SOURCE rather than from CardRegistry because a file may
## build a token's CardData as well as its own (Master of the Hunt builds
## the Wolves that carry the banding).
func test_every_static_layer_six_effect_declares_itself() -> void:
	var undeclared: Array[String] = []
	for set_dir in DirAccess.get_directories_at("res://cards/sets"):
		var dir_path := "res://cards/sets/%s" % set_dir
		for file in DirAccess.get_files_at(dir_path):
			if not file.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string("%s/%s" % [dir_path, file])
			if not _writes_layer_six(text):
				continue
			if not text.contains("changing_abilities()"):
				undeclared.append(file)
	undeclared.sort()
	assert_eq(undeclared, [], "a layer-6 static effect with no flag")


## And the flag really reaches the CardData the engine reads, not just the
## file: the four shapes, one card each.
func test_the_flag_reaches_the_card_data() -> void:
	for card_name in ["Flight", "Fishliver Oil", "Gravity Sphere",
			"Adventurers' Guildhouse"]:
		var flagged := false
		for ability in CardRegistry.get_card(card_name).static_abilities:
			if ability.changes_abilities:
				flagged = true
		assert_true(flagged, "%s declares its layer-6 static" % card_name)


## And the SPLIT halves stayed in their own layers: the flagged one carries
## the ability, the unflagged one the P/T.
func test_a_split_card_keeps_one_static_per_layer() -> void:
	var statics := CardRegistry.get_card("Lord of Atlantis").static_abilities
	assert_eq(statics.size(), 2, "two effects in two layers (CR 613.1)")
	assert_false(statics[0].changes_abilities, "the +1/+1 is layer 7c")
	assert_true(statics[1].changes_abilities, "the islandwalk is layer 6")


## Does [param text] write a layer-6 ability onto an object?
func _writes_layer_six(text: String) -> bool:
	return text.contains("cur_keywords.append") \
		or text.contains("cur_landwalk.append") \
		or text.contains("cur_keywords.erase") \
		or text.contains("cur_landwalk.erase") \
		or text.contains("grant_bands_with")
