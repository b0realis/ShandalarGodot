extends GameTest
## Second-pass hunt over the 1997 card pool (2ed/4ed/arn/atq/leg/drk).
## Each test pins one printed clause the implementation was not honouring.


## A seat that answers by script — OPTION questions by label, YES/NO by a
## queue — and records every prompt it was actually asked.
class Seat extends DecisionAgent:
	var yes: Array = []          # YES/NO answers, in order; empty = the hint
	var yes_no_prompts: Array = []
	var labels: Array = []       # OPTION answers, in order (by label)
	var options_offered: Array = []

	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String,
			hint: bool) -> bool:
		yes_no_prompts.append(prompt)
		if yes.is_empty():
			return hint
		return bool(yes.pop_front())

	func answer_option(_game: MtgGame, _pid: int, _prompt: String,
			options: Array[String], hint: int) -> int:
		options_offered.append(options.duplicate())
		if labels.is_empty():
			return hint
		var wanted := String(labels.pop_front())
		var at := options.find(wanted)
		return at if at >= 0 else hint


func _seat(pid: int) -> Seat:
	var seat := Seat.new()
	g.set_agent(pid, seat)
	return seat


func _was_asked(seat: Seat, text: String) -> bool:
	for prompt in seat.yes_no_prompts:
		if String(prompt).contains(text):
			return true
	return false


func _log_has(text: String) -> bool:
	for line in g.log_lines:
		if String(line).contains(text):
			return true
	return false


## A card into [param pid]'s graveyard.
func _put_graveyard(pid: int, card_name: String) -> CardInstance:
	var card := _make_instance(pid, card_name)
	card.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(card)
	return card


## A card into the TOP of [param pid]'s library.
func _put_library(pid: int, card_name: String) -> CardInstance:
	var card := _make_instance(pid, card_name)
	card.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.append(card)
	return card


# ------------------------------------------------------- Shelkin Brownie --
#
# "{T}: Target creature loses all 'bands with other' abilities until end of
# turn." — NOT banding itself. Tolaria is the card that takes both, and the
# two texts differ on purpose (CR 702.22b runs one way only).

func test_shelkin_brownie_leaves_plain_banding_alone() -> void:
	var brownie := put_battlefield(0, "Shelkin Brownie")
	var hero := put_battlefield(1, "Benalish Hero")
	assert_true(hero.has_keyword(Mtg.Keyword.BANDING), "printed banding")
	assert_ok(g.activate_ability(0, brownie, 0, [TargetRef.card(hero)]))
	resolve_stack()
	assert_true(hero.has_keyword(Mtg.Keyword.BANDING),
		"the Brownie takes 'bands with other' abilities, never banding")


func test_shelkin_brownie_still_strips_bands_with_other() -> void:
	put_battlefield(0, "Adventurers' Guildhouse")
	var brownie := put_battlefield(0, "Shelkin Brownie")
	var jasmine := put_battlefield(0, "Jasmine Boreal")
	assert_eq(jasmine.cur_bands_with.size(), 1, "granted by the Guildhouse")
	assert_ok(g.activate_ability(0, brownie, 0, [TargetRef.card(jasmine)]))
	resolve_stack()
	assert_eq(jasmine.cur_bands_with.size(), 0, "lost until end of turn")


# -------------------------------------------------------------- Preacher --
#
# "{T}: FOR AS LONG AS THIS CREATURE REMAINS TAPPED, gain control of target
# creature…" — the duration names the tap and nothing else, so losing the
# Preacher itself does not hand the prize back (Rubinia Soulsinger and
# Willow Satyr, which do say "for as long as you control", still do).

func test_preacher_keeps_its_prize_when_the_preacher_changes_hands() -> void:
	var preacher := put_battlefield(0, "Preacher")
	var bears := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, preacher, 0, []))   # the victim names it
	resolve_stack()
	assert_eq(bears.controller_id, 0, "the Preacher borrows it")
	g.change_control(preacher, 1)
	assert_true(preacher.tapped, "still tapped — the printed duration holds")
	assert_eq(bears.controller_id, 0,
		"the leash names the tap, not who controls the Preacher")


func test_preacher_gives_the_prize_back_when_it_untaps() -> void:
	var preacher := put_battlefield(0, "Preacher")
	var bears := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, preacher, 0, []))
	resolve_stack()
	assert_eq(bears.controller_id, 0)
	g.untap_permanent(preacher)
	assert_eq(bears.controller_id, 1, "'remains tapped' ended")


# ------------------------------------------------------- Scarwood Bandits --
#
# "…gain control of target artifact FOR AS LONG AS THIS CREATURE REMAINS ON
# THE BATTLEFIELD" — again no "you control" clause.

func test_scarwood_bandits_keep_the_artifact_when_they_change_hands() -> void:
	_seat(1).yes = [false]        # the opponent declines to pay {2}
	var bandits := put_battlefield(0, "Scarwood Bandits")
	var icy := put_battlefield(1, "Icy Manipulator")
	add_mana(0, Mtg.ManaColor.G, 3)
	assert_ok(g.activate_ability(0, bandits, 0, [TargetRef.card(icy)]))
	resolve_stack()
	assert_eq(icy.controller_id, 0, "the Bandits take it")
	g.change_control(bandits, 1)
	assert_eq(icy.controller_id, 0,
		"the leash names the battlefield, not who controls the Bandits")


# --------------------------------------------------- Season of the Witch --
#
# "…sacrifice this enchantment unless you pay 2 life." Life may be paid
# down to exactly 0 (CR 119.4), so a controller at 2 life still has the
# choice; only one at 1 has none.

func test_season_of_the_witch_still_asks_at_exactly_two_life() -> void:
	var seat := _seat(0)
	seat.yes = [true]
	put_battlefield(0, "Season of the Witch")
	g.adjust_life(0, 2 - g.players[0].life)
	assert_eq(g.players[0].life, 2)
	advance_to_next_turn()        # P1's turn
	advance_to_next_turn()        # back to P0: the rent comes due
	assert_true(_was_asked(seat, "Season of the Witch"),
		"a controller at 2 life is still offered the bargain")


# ----------------------------------------------------------- Wand of Ith --
#
# "…discards it unless they pay life equal to its mana value." Same rule:
# a player whose life total EQUALS the toll may still pay it.

func test_wand_of_ith_lets_a_player_pay_their_whole_life_total() -> void:
	var seat := _seat(1)
	seat.yes = [true]
	var wand := put_battlefield(0, "Wand of Ith")
	give_hand(1, "Grizzly Bears")   # mana value 2
	g.adjust_life(1, 2 - g.players[1].life)
	assert_eq(g.players[1].life, 2)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, wand, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_true(_was_asked(seat, "Pay 2 life"),
		"paying life equal to your total is a legal payment")
	assert_eq(g.players[1].hand.size(), 1, "and it keeps the card")


# ---------------------------------------------------------- Jeweled Bird --
#
# "{T}: Ante this artifact. If you do, put all other cards YOU OWN from the
# ante into your graveyard, then draw a card." — "you" is the activating
# player, which is not the Bird's owner once it has been stolen.

func test_jeweled_bird_dumps_the_activating_players_ante() -> void:
	# Played FOR ANTE: in a duel that is not, an ante card does nothing and
	# nothing reaches the ante (the owner's ruling of 2026-10-21,
	# tests/unit/test_ruling_2026_10_21_ante_off.gd).
	g.ante_enabled = true
	var bird := put_battlefield(1, "Jeweled Bird")
	g.change_control(bird, 0)
	assert_eq(bird.controller_id, 0, "stolen")
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	g.move_to_ante(mine)
	g.move_to_ante(theirs)
	assert_ok(g.activate_ability(0, bird, 0))
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "the activator's own stake goes")
	assert_eq(theirs.zone, Mtg.Zone.ANTE, "the other player's stake stays")


# ------------------------------------------------------------- Power Surge --
#
# "…X is the number of untapped lands they controlled AT THE BEGINNING OF
# THIS TURN" — before the untap step, which is the whole "tap out or burn"
# identity of the card.

func test_power_surge_counts_the_lands_left_standing_before_the_untap() -> void:
	put_battlefield(0, "Power Surge")
	var a := put_battlefield(0, "Forest")
	var b := put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	g.tap_permanent(a)
	g.tap_permanent(b)
	advance_to_next_turn()        # P1's turn
	advance_to_next_turn()        # P0's: the Surge comes due as it begins
	assert_eq(g.players[0].life, 19,
		"one land stood untapped as the turn began, not three")


# ---------------------------------------------------------------- Visions --
#
# "LOOK AT the top five cards of target player's library" — the caster
# looks; the duel log both seats read must not say what was there (rule 8,
# docs/fair-play.md; Natural Selection is the same mechanic done right).

func test_visions_keeps_the_library_out_of_the_shared_log() -> void:
	_seat(0).yes = [false]        # don't shuffle
	_put_library(1, "Shivan Dragon")
	var visions := give_hand(0, "Visions")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, visions, [TargetRef.player(1)]))
	resolve_stack()
	assert_false(_log_has("Shivan Dragon"),
		"the opponent reads this log — the five cards are the caster's alone")


func test_visions_shuffles_through_the_journaled_path() -> void:
	_seat(0).yes = [true]
	_put_library(1, "Shivan Dragon")
	var visions := give_hand(0, "Visions")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, visions, [TargetRef.player(1)]))
	resolve_stack()
	assert_true(_log_has("shuffles their library"),
		"MtgGame.shuffle_library, which journals the pile for a rewind")


# ----------------------------------------------- Vesuvan Doppelganger --
#
# "…you may have this creature become a copy of TARGET creature" — which
# creature is the controller's own choice, and a smaller shape is a real
# line (evasion, an ability, dodging a sweeper).

class Shaper extends DecisionAgent:
	var want := ""                # card name to become
	var offered: Array = []       # names offered, per CARD question

	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String,
			_hint: bool) -> bool:
		return true

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		var names: Array = []
		for inst in candidates:
			names.append(inst.data.card_name)
		offered.append(names)
		for inst in candidates:
			if inst.data.card_name == want:
				return inst
		return null if candidates.is_empty() else candidates[0]


func test_vesuvan_doppelganger_lets_its_controller_pick_the_shape() -> void:
	var shaper := Shaper.new()
	g.set_agent(0, shaper)
	put_battlefield(1, "Grizzly Bears")
	var doppel := give_hand(0, "Vesuvan Doppelganger")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, doppel, []))
	resolve_stack()
	assert_eq(doppel.data.card_name, "Grizzly Bears")
	put_battlefield(1, "Serra Angel")            # the biggest body on the table
	put_battlefield(1, "Birds of Paradise")      # smaller, but it flies and taps for mana
	shaper.want = "Birds of Paradise"
	advance_to_next_turn()                       # their turn
	advance_to_next_turn()                       # ours: the upkeep trigger
	resolve_stack()
	assert_eq(doppel.data.card_name, "Birds of Paradise",
		"the seat names the shape, not the engine")


# ----------------------------------------------------------- Reincarnation --
#
# CR 609.3: an effect's instructions are carried out by the object's
# controller unless it says otherwise, and Reincarnation only names WHOSE
# graveyard and WHOSE control — so the CASTER picks the body, exactly as
# Glyph of Reincarnation (same set, same clause) already does.

func test_reincarnation_lets_its_caster_choose_the_body() -> void:
	var picker := Shaper.new()
	picker.want = "Mons's Goblin Raiders"     # their worst, which is the point
	g.set_agent(0, picker)
	_put_graveyard(1, "Shivan Dragon")
	_put_graveyard(1, "Mons's Goblin Raiders")
	var bear := put_battlefield(1, "Grizzly Bears")
	var spell := give_hand(0, "Reincarnation")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear)]))
	resolve_stack()
	g.destroy(bear)
	var raised := PackedStringArray()
	for inst in g.players[1].battlefield:
		raised.append(inst.data.card_name)
	assert_true("Mons's Goblin Raiders" in raised,
		"the spell's controller names the body (CR 609.3), not its owner")
	assert_false("Shivan Dragon" in raised, "which is not their best one")


# ---------------------------------------------------------- Eye for an Eye --
#
# "The next time A SOURCE OF YOUR CHOICE would deal damage to you…" — every
# source, ranked by what is actually about to hit you, the way the Circles
# of Protection and Nova Pentacle already rank theirs.

func test_eye_for_an_eye_watches_what_is_about_to_burn_you() -> void:
	put_battlefield(1, "Forest")            # older, and never going to hurt
	put_battlefield(1, "Mountain")
	var eye := give_hand(0, "Eye for an Eye")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_next_turn()                  # their turn, their main phase
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(0, eye, []))
	resolve_stack()
	assert_eq(g.players[0].life, 17, "the Bolt still lands on you")
	assert_eq(g.players[1].life, 17, "and the same blow goes back at them")


# ------------------------------------------------------------ False Orders --
#
# "You may have it block AN ATTACKING CREATURE OF YOUR CHOICE" — the
# attacking creatures are the active player's, so the defending player
# casting this on their own blocker has the same list to choose from.

func test_false_orders_re_points_a_blocker_for_the_defending_player() -> void:
	var seat := _seat(1)
	var big := put_battlefield(0, "Hill Giant")
	var small := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	var orders := give_hand(1, "False Orders")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [big.id, small.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: small.id}))
	assert_ok(g.pass_priority(0))
	seat.labels = ["Hill Giant"]
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, orders, [TargetRef.card(wall)]))
	resolve_stack()
	assert_true(g.combat.blockers_of(big.id).has(wall.id),
		"the defender may point their own blocker at another attacker")


# ----------------------------------------------------------- Ydwen Efreet --
#
# "Whenever this creature BLOCKS, flip a coin" — one flip per combat,
# however many attackers it blocks (CR 509.1h). Blaze of Glory and
# Two-Headed Giant of Foriys both make two-at-once reachable.

func test_ydwen_efreet_flips_once_however_many_it_blocks() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bears := put_battlefield(0, "Grizzly Bears")
	var efreet := put_battlefield(1, "Ydwen Efreet")
	var blaze := give_hand(0, "Blaze of Glory")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id, bears.id]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, blaze, [TargetRef.card(efreet)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {efreet.id: [giant.id, bears.id]}))
	assert_eq(g.stack.size(), 1, "one block, one flip")


# ---------------------------------------------------------------- Imprison --
#
# "If you do, tap the creature, remove it from combat, AND CREATURES IT WAS
# BLOCKING THAT HAD BECOME BLOCKED BY ONLY THAT CREATURE THIS COMBAT BECOME
# UNBLOCKED" — the printed exception to CR 509.1h, so paying the toll on a
# blocker lets your attacker through instead of fogging it.

func test_imprison_unblocks_the_attacker_it_pulls_the_blocker_from() -> void:
	put_battlefield(0, "Forest")
	put_battlefield(0, "Swamp")
	var giant := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	var aura := give_hand(0, "Imprison")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(wall)]))
	resolve_stack()
	run_combat([giant.id], {wall.id: giant.id})
	assert_true(wall.tapped, "the toll was paid")
	assert_eq(g.players[1].life, 17,
		"the Giant is unblocked, not left swinging at nobody")


func test_imprison_charges_one_toll_however_many_it_blocks() -> void:
	var seat := _seat(0)
	put_battlefield(0, "Forest")
	put_battlefield(0, "Swamp")
	var giant := put_battlefield(0, "Hill Giant")
	var bears := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	var aura := give_hand(0, "Imprison")
	var blaze := give_hand(0, "Blaze of Glory")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(wall)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id, bears.id]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, blaze, [TargetRef.card(wall)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: [giant.id, bears.id]}))
	resolve_stack()
	var tolls := 0
	for prompt in seat.yes_no_prompts:
		if String(prompt).contains("Pay {1} to hold"):
			tolls += 1
	assert_eq(tolls, 1, "one block, one toll")
