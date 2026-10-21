extends GameTest
## CARDS THAT DID NOT DO WHAT THEIR TEXT SAYS (bug hunt 2026-10-21, cardsA —
## a text-versus-script audit of the 2ed, arn, atq, leg, drk, 4ed, past and
## phpr scripts). Each test below failed on the code it was written against.
##
##  - Drain Power aimed at its own caster ("that player loses all unspent
##    mana and you add the mana lost this way") added the caster's pool to
##    itself and then emptied it: every land tapped, nothing kept.
##  - Berserk ("cast this spell only before the combat damage step") was
##    castable in the first-strike damage step, which IS a combat damage
##    step (CR 510.4): a trampling double-power finisher after the first
##    strikers had already traded.
##  - Plague Rats counted a face-down permanent — which has no name (CR
##    708.2) — as one "named Plague Rats".
##  - Enchantment Alteration could "move" an Aura onto a creature with
##    protection from its colour (or onto a permanent that can't be
##    enchanted), where the state-based check then put it in the graveyard:
##    a one-mana Aura removal. An Aura can't be attached to what it couldn't
##    enchant (CR 701.3b, 702.16c); with no legal permanent it stays.
##  - Glyph of Doom read the Wall's block history at end of combat, after a
##    Wall that died in that combat had lost it: the creatures it blocked
##    survived. The history the Wall had as the Glyph resolved now counts.
##  - Equinox countered any spell whose spec COULD name one of your lands
##    (a Desert Twister aimed at your creature), and missed a Volcanic
##    Eruption aimed at your Mountain. "If it would destroy a land you
##    control" now reads the spell's actual targets.
##  - The Fallen bit the player who had since taken control of it: it deals
##    damage to each OPPONENT it has damaged, and its controller is none.
##  - Tetravus made 1/1 artifact creature tokens with no creature type;
##    they are Tetravites.
##  - Kudzu hopped onto a land that "can't be enchanted by other Auras"
##    (Consecrate Land) — the same CR 701.3b as Enchantment Alteration.
##  - Illusionary Mask's "you MAY choose a creature card" could not be
##    declined: a seat that answered nothing had the dearest creature masked
##    for it.


# ----------------------------------------------------------- Drain Power --

func test_drain_power_on_yourself_keeps_every_mana() -> void:
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	var drain := give_hand(0, "Drain Power")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, drain, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.U), 2,
		"you lose the mana and you add the mana lost")


func test_drain_power_on_the_opponent_still_moves_it_across() -> void:
	put_battlefield(1, "Forest")
	put_battlefield(1, "Forest")
	var drain := give_hand(0, "Drain Power")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, drain, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.G), 2)
	assert_eq(g.players[1].mana_pool.total(), 0)


# --------------------------------------------------------------- Berserk --

func _first_strike_attack() -> void:
	var knight := put_battlefield(0, "Black Knight")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [knight.id, bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))


func test_berserk_is_refused_in_the_first_strike_damage_step() -> void:
	_first_strike_attack()
	advance_to_step(Mtg.Step.FIRST_STRIKE_DAMAGE)
	var berserk := give_hand(0, "Berserk")
	add_mana(0, Mtg.ManaColor.G)
	assert_string_contains(g.cast_timing_refusal(0, berserk),
		"before the combat damage step")


func test_berserk_is_still_open_after_blockers_with_a_first_striker() -> void:
	_first_strike_attack()
	var berserk := give_hand(0, "Berserk")
	add_mana(0, Mtg.ManaColor.G)
	assert_eq(g.current_step(), Mtg.Step.DECLARE_BLOCKERS)
	assert_eq(g.cast_timing_refusal(0, berserk), "")


# ----------------------------------------------------------- Plague Rats --

func test_plague_rats_do_not_count_a_face_down_card() -> void:
	var rats := put_battlefield(0, "Plague Rats")
	var masked := put_battlefield(0, "Plague Rats")
	masked.face_down = true
	g.recalculate()
	assert_eq(rats.cur_power, 1, "a face-down 2/2 has no name")
	assert_eq(rats.cur_toughness, 1)
	masked.face_down = false
	g.recalculate()
	assert_eq(rats.cur_power, 2, "turned face up, it is a Plague Rats again")


# ------------------------------------------------- Enchantment Alteration --

func _holy_strength_on_a_bear() -> Array:
	var bear := put_battlefield(0, "Grizzly Bears")
	var strength := give_hand(0, "Holy Strength")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, strength, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_next_turn()
	return [bear, strength]


func test_enchantment_alteration_cannot_move_an_aura_onto_protection() -> void:
	var pair := _holy_strength_on_a_bear()
	put_battlefield(1, "Black Knight")   # protection from white
	var alter := give_hand(1, "Enchantment Alteration")
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, alter, [TargetRef.card(pair[1])]))
	resolve_stack()
	assert_eq(pair[1].zone, Mtg.Zone.BATTLEFIELD, "no legal permanent: it stays")
	assert_eq(pair[1].attached_to, pair[0].id)


func test_enchantment_alteration_still_moves_onto_a_legal_creature() -> void:
	var pair := _holy_strength_on_a_bear()
	var ogre := put_battlefield(1, "Hill Giant")
	var alter := give_hand(1, "Enchantment Alteration")
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, alter, [TargetRef.card(pair[1])]))
	resolve_stack()
	assert_eq(pair[1].attached_to, ogre.id)


# ---------------------------------------------------------- Glyph of Doom --

func test_glyph_of_doom_kills_what_a_dead_wall_blocked() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Wood")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: giant.id}))
	var glyph := give_hand(1, "Glyph of Doom")
	add_mana(1, Mtg.ManaColor.B)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, glyph, [TargetRef.card(wall)]))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "the 0/3 died to the 3/3")
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD,
		"it was blocked by that creature this turn")


func test_glyph_of_doom_on_a_surviving_wall_still_works() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Wood")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: bear.id}))
	var glyph := give_hand(1, "Glyph of Doom")
	add_mana(1, Mtg.ManaColor.B)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, glyph, [TargetRef.card(wall)]))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------------------- Equinox --

func _equinox_on(land_name: String) -> CardInstance:
	var land := put_battlefield(0, land_name)
	var aura := give_hand(0, "Equinox")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(land)]))
	resolve_stack()
	advance_to_next_turn()
	return land


func _answer_with_equinox(land: CardInstance, spell: CardInstance) -> void:
	assert_ok(g.pass_priority(1))
	assert_ok(g.activate_ability(0, land, land.cur_activated_abilities.size() - 1,
		[TargetRef.card(spell)]))
	resolve_stack()


func test_equinox_lets_a_twister_aimed_at_a_creature_through() -> void:
	var land := _equinox_on("Forest")
	var bear := put_battlefield(0, "Grizzly Bears")
	var twister := give_hand(1, "Desert Twister")
	add_mana(1, Mtg.ManaColor.G, 2)
	add_mana(1, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(1, twister, [TargetRef.card(bear)]))
	_answer_with_equinox(land, twister)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "a Twister on a creature destroys no land")


func test_equinox_counters_a_twister_aimed_at_the_land() -> void:
	var land := _equinox_on("Forest")
	var twister := give_hand(1, "Desert Twister")
	add_mana(1, Mtg.ManaColor.G, 2)
	add_mana(1, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(1, twister, [TargetRef.card(land)]))
	_answer_with_equinox(land, twister)
	assert_eq(twister.zone, Mtg.Zone.GRAVEYARD, "countered")
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD)


func test_equinox_counters_a_volcanic_eruption_on_its_mountain() -> void:
	var land := _equinox_on("Mountain")
	var eruption := give_hand(1, "Volcanic Eruption")
	add_mana(1, Mtg.ManaColor.U, 3)
	add_mana(1, Mtg.ManaColor.C, 1)
	assert_ok(g.cast_spell(1, eruption, [TargetRef.card(land)], 1))
	_answer_with_equinox(land, eruption)
	assert_eq(eruption.zone, Mtg.Zone.GRAVEYARD, "countered")
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD)


func test_equinox_still_counters_a_sweeper() -> void:
	var land := _equinox_on("Plains")
	var geddon := give_hand(1, "Armageddon")
	add_mana(1, Mtg.ManaColor.W)
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(1, geddon, []))
	_answer_with_equinox(land, geddon)
	assert_eq(geddon.zone, Mtg.Zone.GRAVEYARD, "countered")
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------------- The Fallen --

func test_the_fallen_never_bites_its_new_controller() -> void:
	# "…deals 1 damage to each OPPONENT … it has dealt damage to this game":
	# the player it bit, who has since taken it, is no opponent of theirs.
	var fallen := put_battlefield(0, "The Fallen")
	g.deal_damage(fallen, TargetRef.player(1), 2)
	resolve_stack()
	g.change_control(fallen, 1)
	advance_to_next_turn()   # P1's turn: its upkeep trigger has resolved
	assert_eq(g.active_player, 1)
	assert_eq(g.players[1].life, 18, "it does not haunt its own controller")
	assert_eq(g.players[0].life, 20, "and it never bit the other player")


# ---------------------------------------------------------------- Tetravus --

func test_tetravus_makes_tetravite_tokens() -> void:
	# "create that many 1/1 colorless Tetravite artifact creature tokens"
	var tetravus := put_battlefield(0, "Tetravus")
	advance_to_next_turn()
	advance_to_next_turn()   # our upkeep: the heuristic buds all three
	var tetravites: Array = []
	for inst in g.players[0].battlefield:
		if inst.is_token:
			tetravites.append(inst)
	assert_false(tetravites.is_empty(), "the upkeep made Tetravites")
	for t in tetravites:
		assert_true(t.has_subtype("tetravite"), "a Tetravite is a Tetravite")
	assert_not_null(tetravus)


# -------------------------------------------------------- Illusionary Mask --

## Answers every card question with nothing.
class DeclinesCards extends DecisionAgent:
	func answer_card(_game: MtgGame, _pid: int, _candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		return null


func test_illusionary_mask_choice_may_be_declined() -> void:
	var mask := put_battlefield(0, "Illusionary Mask")
	var bear := give_hand(0, "Grizzly Bears")
	g.agents[0] = DeclinesCards.new()
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, mask, 0, [], 2))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.HAND, "\"you MAY choose\": nothing was chosen")


func test_illusionary_mask_still_masks_the_chosen_creature() -> void:
	var mask := put_battlefield(0, "Illusionary Mask")
	var bear := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, mask, 0, [], 2))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(bear.face_down)


# ------------------------------------------------------------------ Kudzu --

## Says yes to every yes/no question.
class SaysYes extends DecisionAgent:
	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool:
		return true


func test_kudzu_cannot_hop_onto_a_consecrated_land() -> void:
	var vined := put_battlefield(0, "Forest")
	var holy := put_battlefield(0, "Forest")
	var kudzu := give_hand(0, "Kudzu")
	var consecrate := give_hand(0, "Consecrate Land")
	advance_to_step(Mtg.Step.MAIN1)
	g.attach_aura_from_anywhere(kudzu, vined, 0)
	g.attach_aura_from_anywhere(consecrate, holy, 0)
	g.agents[0] = SaysYes.new()
	g.tap_permanent(vined)
	resolve_stack()
	assert_eq(vined.zone, Mtg.Zone.GRAVEYARD, "the strangled land is destroyed")
	assert_ne(kudzu.attached_to, holy.id, "a consecrated land can't be enchanted")
	assert_eq(kudzu.zone, Mtg.Zone.GRAVEYARD, "no land to go to: it dies with its host")


func test_kudzu_still_hops_onto_an_ordinary_land() -> void:
	var vined := put_battlefield(0, "Forest")
	var next := put_battlefield(1, "Forest")
	var kudzu := give_hand(0, "Kudzu")
	advance_to_step(Mtg.Step.MAIN1)
	g.attach_aura_from_anywhere(kudzu, vined, 0)
	g.agents[0] = SaysYes.new()
	g.tap_permanent(vined)
	resolve_stack()
	assert_eq(kudzu.attached_to, next.id)
