extends GameTest
## 2026-09 audit pins for 2ed cards (plus The Rack, Black Vise's 4ed
## mirror). Every test here failed before the fix it names, and each one
## quotes the oracle text or the Comprehensive Rules clause it protects.


## A seat that refuses every optional choice — the "you MAY put this card
## onto the battlefield" half of Nether Shadow.
class RefusingAgent extends DecisionAgent:
	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool:
		return false


## Cycle turns until [param pid]'s upkeep has put a trigger on the stack —
## the only window in which a triggered ability can be answered by killing
## its source.
func _advance_to_upkeep_trigger_of(pid: int) -> void:
	var guard := 0
	while (g.current_step() != Mtg.Step.UPKEEP or g.active_player != pid
			or g.stack.is_empty()) and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "never reached that upkeep with a trigger waiting")


# ----------------------------------------------- Black Vise / The Rack (1) --

func test_black_vise_keeps_squeezing_the_player_it_chose() -> void:
	# "As this artifact enters, CHOOSE AN OPPONENT. At the beginning of the
	# CHOSEN PLAYER's upkeep ..." — the choice is locked in as the artifact
	# enters, so stealing the Vise does not turn it around on its caster.
	var vise := put_battlefield(0, "Black Vise")
	resolve_stack()                       # the "choose an opponent" trigger
	for _i in 7:
		give_hand(0, "Forest")            # a hand worth 3 damage, if it were aimed here
	var steal := give_hand(1, "Steal Artifact")
	advance_to_next_turn()                # turn 2 — player 1 (hand of 1, no damage)
	add_mana(1, Mtg.ManaColor.U, 2)
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(1, steal, [TargetRef.card(vise)]))
	resolve_stack()
	assert_eq(vise.controller_id, 1, "player 1 now controls the Vise")
	for _i in 7:
		give_hand(1, "Forest")
	advance_to_next_turn()                # turn 3 — player 0's upkeep
	assert_eq(g.players[0].life, 20,
		"the Vise never turns on its caster — the chosen player was player 1")
	advance_to_next_turn()                # turn 4 — the chosen player's upkeep
	assert_eq(g.players[1].life, 17, "7 cards in hand minus 4")


func test_the_rack_keeps_stretching_the_player_it_chose() -> void:
	# Same locked-in choice, from the other end of the arithmetic. Aladdin
	# and Steal Artifact do this for real; change_control is the same code
	# path with none of the setup.
	var rack := put_battlefield(0, "The Rack")
	resolve_stack()                       # the "choose an opponent" trigger
	g.change_control(rack, 1)
	advance_to_next_turn()                # turn 2 — the chosen player's upkeep
	assert_eq(g.players[1].life, 17, "3 minus an empty hand, still aimed at player 1")
	assert_eq(g.players[0].life, 20)


# ------------------------------------- Blaze of Glory / False Orders (2) --

func test_blaze_of_glory_reaches_the_defenders_own_creature() -> void:
	# "Target creature DEFENDING PLAYER controls" — not "a creature you
	# don't control". The defending player is a legal caster and their own
	# creature is the only legal target.
	var attacker := put_battlefield(0, "Hill Giant")
	var mine := put_battlefield(1, "Grizzly Bears")
	var wrong := give_hand(1, "Blaze of Glory")
	var blaze := give_hand(1, "Blaze of Glory")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.W)
	# The attacking player's own creature is never a legal target.
	assert_refused(g.cast_spell(1, wrong, [TargetRef.card(attacker)]),
		"Illegal target (controller).")
	assert_ok(g.cast_spell(1, blaze, [TargetRef.card(mine)]))
	resolve_stack()
	assert_true(mine.must_block_this_turn)


func test_false_orders_reaches_a_creature_that_is_not_blocking() -> void:
	# The printed text says "target creature defending player controls" —
	# it never says "blocking creature", so a defender that stayed home is
	# a legal target and can be dragged into the fight.
	var big := put_battlefield(0, "Hill Giant")                # 3/3
	var small := put_battlefield(0, "Mons's Goblin Raiders")    # 1/1
	var idler := put_battlefield(1, "Grizzly Bears")           # 2/2, blocks nothing
	var orders := give_hand(0, "False Orders")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [big.id, small.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, orders, [TargetRef.card(idler)]))
	resolve_stack()
	assert_eq(g.combat.blockers_of(small.id).size(), 1,
		"'you may have it block an attacking creature of your choice'")


# ------------------------------------------------- Illusionary Mask (3) --

func test_illusionary_mask_activates_only_as_a_sorcery() -> void:
	# "Activate only as a sorcery" = your main phase, your turn, empty
	# stack (CR 601.3c-style timing) — not "the first main phase", which
	# both banned your own second main and allowed the opponent's first.
	var mask := put_battlefield(0, "Illusionary Mask")
	give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, mask, 0, [], 2))
	resolve_stack()
	give_hand(0, "Hill Giant")
	advance_to_next_turn()                # the OPPONENT's precombat main
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_refused(g.activate_ability(0, mask, 0, [], 4), "sorcery")
	advance_to_next_turn()                # our main phase again
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_refused(g.activate_ability(0, mask, 0, [], 4), "sorcery")


# ----------------------------- Force of Nature / Lord of the Pit (4) --

func test_force_of_nature_taxes_even_after_it_leaves() -> void:
	# A triggered ability is independent of its source (CR 603.6/608.2h):
	# bouncing the Force in response to its own upkeep trigger does not
	# refund the {G}{G}{G}{G}.
	var force := put_battlefield(0, "Force of Nature")
	var bounce := give_hand(1, "Unsummon")
	_advance_to_upkeep_trigger_of(0)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, bounce, [TargetRef.card(force)]))
	resolve_stack()
	assert_eq(force.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].life, 12, "8 damage from a Force that is no longer there")


func test_lord_of_the_pit_still_demands_tribute_after_it_leaves() -> void:
	var lord := put_battlefield(0, "Lord of the Pit")
	var bear := put_battlefield(0, "Grizzly Bears")
	var bounce := give_hand(1, "Unsummon")
	_advance_to_upkeep_trigger_of(0)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, bounce, [TargetRef.card(lord)]))
	resolve_stack()
	assert_eq(lord.zone, Mtg.Zone.HAND)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the tribute is still owed (CR 603.6)")
	assert_eq(g.players[0].life, 20)


# --------------------------------------------------------- Earthbind (5) --

func test_earthbind_does_nothing_to_a_grounded_creature() -> void:
	# "When this Aura enters, IF enchanted creature has flying, ..." — an
	# intervening-if (CR 603.4): with a grounded host the ability never
	# triggers (pinned in test_fidelity_2026_09_02_permanents.gd, lifted
	# 2026-09-02). The outcome this pins is the printed one: a grounded
	# host is untouched.
	var bear := put_battlefield(1, "Grizzly Bears")
	var earthbind := give_hand(0, "Earthbind")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, earthbind, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(earthbind.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.damage, 0, "no flying, no 2 damage")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_earthbind_still_shoots_down_a_flier() -> void:
	var angel := put_battlefield(1, "Serra Angel")   # 4/4 flying
	var earthbind := give_hand(0, "Earthbind")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, earthbind, [TargetRef.card(angel)]))
	resolve_stack()
	assert_eq(angel.damage, 2)
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING), "and it loses flying")


# -------------------------------------------------------- Pestilence (6) --

func test_pestilence_sacrifices_itself_rather_than_dying() -> void:
	# "sacrifice this enchantment" — a sacrifice is not destruction, so it
	# goes through indestructible (CR 701.17).
	var pest := put_battlefield(0, "Pestilence")
	advance_to_step(Mtg.Step.END)
	assert_eq(g.stack.size(), 1, "the end-step trigger is waiting")
	# Nothing in the 1997 pool makes an enchantment indestructible, so the
	# only way to tell a sacrifice from a destruction is to set the flag by
	# hand between the last recalculation and the trigger's resolution.
	pest.cur_indestructible = true
	resolve_stack()
	assert_eq(pest.zone, Mtg.Zone.GRAVEYARD, "sacrificed, not destroyed")


# ------------------------------------ Jayemdae Tome / Prodigal Sorcerer --

func test_jayemdae_tome_is_a_book() -> void:
	# Scryfall type line: "Artifact — Book", like Jalum Tome and the Book
	# of Rass.
	assert_true(CardRegistry.get_card("Jayemdae Tome").subtypes.has("book"))


func test_prodigal_sorcerer_is_a_human_wizard_sorcerer() -> void:
	# Scryfall type line: "Creature — Human Wizard Sorcerer".
	var subtypes := CardRegistry.get_card("Prodigal Sorcerer").subtypes
	assert_true(subtypes.has("human"))
	assert_true(subtypes.has("wizard"))
	assert_true(subtypes.has("sorcerer"))


# -------------------------------------------------- Animate Artifact (9) --

func test_animate_artifact_reads_the_live_type() -> void:
	# "As long as enchanted artifact ISN'T A CREATURE" is a live-type test:
	# once the Jade Statue animates itself into a 3/6, Animate Artifact
	# switches off instead of stamping 4/4 over the top.
	var statue := put_battlefield(0, "Jade Statue")     # {4}, mana value 4
	var aura := give_hand(0, "Animate Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(statue)]))
	resolve_stack()
	assert_eq(statue.cur_power, 4, "a plain artifact animates at its mana value")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, statue, 0, []))
	resolve_stack()
	assert_eq(statue.cur_power, 3, "the Statue's own animation stands ...")
	assert_eq(statue.cur_toughness, 6, "... because the clause reads the LIVE type")


# ------------------------------------------------------ Nether Shadow (10) --

func _bury(pid: int, card_name: String) -> CardInstance:
	var inst := give_hand(pid, card_name)
	g.discard_cards(pid, [inst])
	return inst


func test_nether_shadow_return_is_optional() -> void:
	# "you MAY put this card onto the battlefield" — a seat that declines
	# leaves it buried.
	g.set_agent(0, RefusingAgent.new())
	var shadow := _bury(0, "Nether Shadow")
	for _i in 3:
		_bury(0, "Grizzly Bears")
	_advance_to_upkeep_trigger_of(0)
	resolve_stack()
	assert_eq(shadow.zone, Mtg.Zone.GRAVEYARD, "the controller said no")


func test_nether_shadow_rechecks_the_pile_on_resolution() -> void:
	# "if this card is in your graveyard with three or more creature cards
	# above it" is an intervening-if: it must still be true on resolution
	# (CR 603.4).
	var shadow := _bury(0, "Nether Shadow")
	var corpses: Array[CardInstance] = []
	for _i in 3:
		corpses.append(_bury(0, "Grizzly Bears"))
	_advance_to_upkeep_trigger_of(0)
	g.exile_from_graveyard(corpses[0])    # only two creature cards left above it
	resolve_stack()
	assert_eq(shadow.zone, Mtg.Zone.GRAVEYARD, "the condition stopped being true")


# ------------------------------- Magical Hack / Sleight of Mind (11) --

func test_magical_hack_can_rewrite_a_spell_on_the_stack() -> void:
	# "Change the text of target SPELL OR PERMANENT" — the Laces' spec. The
	# replacement type is read off the TARGET's controller's opponent, so
	# hacking their Wraith points its walk at our own lands.
	put_battlefield(0, "Island")
	put_battlefield(1, "Forest")
	var wraith := give_hand(1, "Bog Wraith")     # swampwalk
	var hack := give_hand(0, "Magical Hack")
	advance_to_next_turn()                       # player 1's main phase
	add_mana(1, Mtg.ManaColor.B)
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(1, wraith, []))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, hack, [TargetRef.card(wraith)]))
	resolve_stack()
	assert_eq(wraith.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(wraith.cur_landwalk.has("island"), "swampwalk became islandwalk")
	assert_false(wraith.cur_landwalk.has("swamp"))


func test_sleight_of_mind_can_rewrite_a_spell_on_the_stack() -> void:
	# Same widening for the colour-word half of the pair.
	var knight := give_hand(1, "Black Knight")   # protection from white
	var sleight := give_hand(0, "Sleight of Mind")
	advance_to_next_turn()                       # player 1's main phase
	add_mana(1, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(1, knight, []))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, sleight, [TargetRef.card(knight)]))
	resolve_stack()
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(knight.cur_protection, Mtg.ManaColor.U,
		"protection from white became protection from blue")
