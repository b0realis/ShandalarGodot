extends GameTest
## PACK 8, E5 — THE DAMAGE REPLACEMENT SUITE (`engine/damage_replacements.gd`).
##
## Every mechanism the Mirage block's damage cards need, pinned on
## SYNTHETIC cards three lines long, so the engine is proven before any card
## agent writes Shadowbane:
##
## - N_damage_mod — damage MODIFIERS (CR 614.1a): a static "a spell deals 1
##   less" (Benevolent Unicorn), a floating "combat damage creature to
##   creature is doubled this turn" (Blind Fury), a one-shot "the next time
##   that source would deal damage, double it" (Desperate Gambit).
## - N_creature_dmg_repl — "the next time a source of your choice would deal
##   damage to <victims>" over ANY victim kind with ONE shield per damage
##   EVENT (CR 615.8), Reflect Damage's redirect, Zhalfirin Crusader's
##   metered redirect to any target, Lichenthrope's damage-into-counters.
## - N_repl_duration — "until your next upkeep" (Soul Echo, CR 611.2b).
## - N_ogre_lethal — "lethal damage dealt by a single source" (Ogre
##   Enforcer, CR 704.5g as the card changes it).
## - N_divided_prevention — "prevent the next 5 ... divided as you choose"
##   (Remedy, CR 601.2d).
## - N_stack_static — statics that function on the STACK (CR 611.3: Torrent
##   of Lava's granted ability, Kaervek's Torch's targeting surcharge).
## - predict_damage — what a damage event would REALLY do, for the AI.
##
## And the cross-cutting checks the brief asks for: CR 616.1 ordering by the
## affected player / the affected object's controller, CR 614.5 (once per
## event), CR 615.12 (unpreventable damage), CR 400.7 (a new object is not
## shielded), control change, turn expiry, simultaneous events, undo through
## the search journal, and both rules profiles where they differ (the 1997
## damage-prevention window).


# ------------------------------------------------------------ agents --

## Answers the CR 616.1 ordering question with the parked index (negative =
## the hint) and records every question; names the parked card for "a
## source of your choice".
class Chooser extends DecisionAgent:
	var take := -1
	var asked: Array[String] = []
	var name_card: CardInstance = null

	func answer_option(_game: MtgGame, _pid: int, _prompt: String,
			options: Array[String], hint: int) -> int:
		asked.append(", ".join(options))
		return hint if take < 0 else take

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		if name_card != null and candidates.has(name_card):
			return name_card
		return null if candidates.is_empty() else candidates[0]


# ------------------------------------------------- synthetic cards --

func _unicorn_static(game: MtgGame, source: CardInstance) -> void:
	game.add_static_damage_effect(source, {"kind": &"modify", "delta": -1,
		"spell_only": true, "desc": "Test Unicorn: a spell deals 1 less"})


## "If a spell would deal damage to a permanent or player, it deals that
## much damage minus 1 to that permanent or player instead."
func _unicorn() -> CardData:
	return CardData.new("Test Unicorn", "{1}{W}", Mtg.CardType.CREATURE).pt(1, 2) \
		.static_ability(StaticAbility.new(_unicorn_static, "a spell deals 1 less"))


func _lichen_static(game: MtgGame, source: CardInstance) -> void:
	game.add_static_damage_effect(source, {"kind": &"counters", "counter": "-1/-1",
		"victims": [source], "desc": "Test Lichen: damage becomes -1/-1 counters"})


## "If damage would be dealt to this creature, put that many -1/-1 counters
## on it instead."
func _lichen() -> CardData:
	return CardData.new("Test Lichen", "{3}{G}{G}", Mtg.CardType.CREATURE).pt(5, 5) \
		.static_ability(StaticAbility.new(_lichen_static, "damage becomes counters"))


## "This creature can't be destroyed by lethal damage unless lethal damage
## dealt by a single source is marked on it."
func _ogre() -> CardData:
	return CardData.new("Test Ogre", "{3}{R}{R}", Mtg.CardType.CREATURE).pt(4, 4) \
		.with_lethal_needs_single_source()


func _instant(card_name: String, effect: EffectBase) -> CardData:
	return CardData.new(card_name, "{0}", Mtg.CardType.INSTANT).spell(effect)


func _shock(card_name := "Test Shock", amount := 2) -> CardData:
	return _instant(card_name, DamageEffect.new(amount).any_target())


## Blind Fury's shape: a creature's damage to a creature.
func _creature_to_creature(_game: MtgGame, packet: DamagePacket) -> bool:
	return packet.source.is_creature() and not packet.target.is_player


func _always(_game: MtgGame, _packet: DamagePacket) -> bool:
	return true


func _prevent_all(_game: MtgGame, packet: DamagePacket) -> int:
	packet.prevent(packet.remaining())
	return 0


var _heard: Array = []

func _hear_damage(e: GameEvent) -> void:
	if e.type == Mtg.EventType.DAMAGE_DEALT:
		_heard.append(e)


# ------------------------------------------------------------ helpers --

func _bolt_at(pid: int, target: TargetRef) -> void:
	var bolt := give_hand(pid, "Lightning Bolt")
	add_mana(pid, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(pid, bolt, [target]))
	resolve_stack()


func _pestilence_once(pid: int, pest: CardInstance) -> void:
	add_mana(pid, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(pid, pest, 0))
	resolve_stack()


func _chooser(pid: int) -> Chooser:
	var chooser := Chooser.new()
	g.set_agent(pid, chooser)
	return chooser


# ================================================= N_damage_mod ==

## The reproduction: a spell's damage is one less, to a player and to a
## creature alike — and an ABILITY's damage is not a spell's.
func test_a_static_modifier_takes_one_from_every_spell() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_synthetic(1, _unicorn())
	var giant := put_battlefield(1, "Hill Giant")
	_bolt_at(0, TargetRef.player(1))
	assert_eq(g.players[1].life, 18, "Bolt dealt 2, not 3")
	_bolt_at(0, TargetRef.card(giant))
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "2 damage does not kill a 3/3... ")
	assert_eq(giant.damage, 2, "...it marks 2")
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17, "a creature's ability is not a spell")


## Two Unicorns: each replacement applies ONCE (CR 616.1f), so two points.
func test_two_static_modifiers_each_apply_once() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_synthetic(1, _unicorn())
	put_synthetic(1, _unicorn())
	_bolt_at(0, TargetRef.player(1))
	assert_eq(g.players[1].life, 19)


## "If a source would deal 0 damage, it does not deal damage at all"
## (CR 614.7a): nothing lands and nothing hears DAMAGE_DEALT.
func test_a_modifier_to_zero_is_no_damage_event() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_synthetic(1, _unicorn())
	_heard.clear()
	g.event_occurred.connect(_hear_damage)
	var ping := give_synthetic(0, _shock("Test Ping", 1))
	assert_ok(g.cast_spell(0, ping, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 20)
	assert_eq(_heard.size(), 0, "no damage event at all")


## The static lives as long as its source: the Unicorn dies, the Bolt is a
## Bolt again.
func test_the_static_modifier_leaves_with_its_source() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var unicorn := put_synthetic(1, _unicorn())
	g.destroy(unicorn)
	_bolt_at(0, TargetRef.player(1))
	assert_eq(g.players[1].life, 17)
	assert_true(g.static_damage_effects.is_empty())


## Blind Fury: a floating, turn-long modifier — combat damage from a
## creature to a creature doubles; combat damage to a player and a
## creature's ping do not; it ends at cleanup.
func test_a_turn_long_combat_modifier_doubles_creature_combat_damage() -> void:
	var giant := put_battlefield(0, "Hill Giant")     # 3/3
	var wall := put_battlefield(1, "Wall of Stone")   # 0/8
	var bear := put_battlefield(0, "Grizzly Bears")
	g.add_damage_effect({"kind": &"modify", "factor": 2, "combat_only": true,
		"filter": _creature_to_creature, "desc": "Test Fury"})
	run_combat([giant.id, bear.id], {wall.id: giant.id})
	assert_eq(wall.damage, 6, "3 combat damage to a creature becomes 6")
	assert_eq(g.players[1].life, 18, "the unblocked bear's 2 to a player is not doubled")
	advance_to_next_turn()
	assert_true(g.damage_effects.is_empty(), "this turn only")


## Desperate Gambit's win: "the next time that source would deal damage
## this turn, it deals double that damage instead" — the next EVENT, any
## victim, then never again.
func test_a_one_shot_modifier_doubles_the_next_event_only() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	g.modify_next_damage(0, "Test Gambit", sorcerer, 2)
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 18, "1 doubled")
	sorcerer.tapped = false
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17, "the next time only")
	assert_true(g.damage_effects.is_empty(), "spent and pruned")


## CR 616.1: a doubling and a prevention pool on the same creature — its
## CONTROLLER orders them, and the order is the difference between 2 and 4
## damage. The hint (what every heuristic seat takes) is the pool first.
func test_the_controller_orders_a_doubling_against_a_pool() -> void:
	var chooser := _chooser(1)
	var wall := put_battlefield(1, "Wall of Stone")
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	g.add_damage_effect({"kind": &"modify", "factor": 2, "desc": "Test Doubler"})
	wall.prevention = 1
	g.deal_damage(sorcerer, TargetRef.card(wall), 3)
	assert_eq(chooser.asked.size(), 1, "asked once")
	assert_true(chooser.asked[0].contains("Test Doubler"), chooser.asked[0])
	assert_eq(wall.damage, 4, "hint: the pool first (3-1=2), then doubled")
	chooser.take = 0
	chooser.asked.clear()
	wall.damage = 0
	wall.prevention = 1
	# the head of the list is now the pool, so take the doubler (index 1)
	chooser.take = 1
	g.deal_damage(sorcerer, TargetRef.card(wall), 3)
	assert_eq(wall.damage, 5, "doubled first (6), then the pool (5)")


# ========================================= N_creature_dmg_repl ==

## THE REPRODUCTION FOR SHADOWBANE: one shield over the controller AND every
## creature they control, against ONE event from the chosen source — a
## Pestilence activation hits all of them at once, and all of it is
## prevented; the next activation is a new event and lands in full.
func test_one_shield_covers_you_and_your_creatures_for_one_event() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var pest := put_battlefield(0, "Pestilence")
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var their_bear := put_battlefield(0, "Grizzly Bears")
	g.shield_next_damage(1, "Test Shadowbane", pest, [TargetRef.player(1)], 1)
	_pestilence_once(0, pest)
	assert_eq(g.players[1].life, 20, "you: prevented")
	assert_eq(bear.damage, 0, "your creature: prevented")
	assert_eq(giant.damage, 0, "and the other one")
	assert_eq(their_bear.damage, 1, "not their creature")
	assert_eq(g.players[0].life, 19, "nor them")
	_pestilence_once(0, pest)
	assert_eq(g.players[1].life, 19, "the next event is a new one")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.damage, 1)


func _black_rider(game: MtgGame, packet: DamagePacket, amount: int) -> void:
	if (game.damage_source_colors(packet.source) & Mtg.ManaColor.B) != 0:
		game.adjust_life(1, amount)


## The rider: "If damage from a black source is prevented this way, you gain
## that much life" — every point the event lost, from every victim.
func test_the_shield_rider_counts_what_it_prevented() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var pest := put_battlefield(0, "Pestilence")
	put_battlefield(1, "Grizzly Bears")
	g.shield_next_damage(1, "Test Shadowbane", pest, [TargetRef.player(1)], 1, _black_rider)
	_pestilence_once(0, pest)
	assert_eq(g.players[1].life, 22, "1 to you + 1 to your bear, both prevented and gained")


## The declarative effect a card agent writes: SourceShieldEffect, cast in
## response, names the source as it resolves (the one about to deal damage
## is the default).
func test_the_source_shield_effect_names_the_source_on_resolution() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	var bane := give_synthetic(1, _instant("Test Bane",
		SourceShieldEffect.prevent_to_you_and_your_creatures()))
	assert_ok(g.cast_spell(1, bane, []))
	resolve_stack()
	assert_eq(g.players[1].life, 20, "the Bolt on the stack was named and stopped")


## "... to any target": the shield is on its target alone. Damage from the
## same source to another victim neither lands on the shield nor uses it up.
func test_a_target_shield_covers_its_target_only() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.shield_next_damage(0, "Test Circle", sorcerer, [TargetRef.card(bear)])
	g.deal_damage(sorcerer, TargetRef.player(0), 1)
	assert_eq(g.players[0].life, 19, "not the target")
	assert_eq(g.damage_effects.size(), 1, "not used up by someone else's damage")
	g.deal_damage(sorcerer, TargetRef.card(bear), 1)
	assert_eq(bear.damage, 0, "the target is shielded")


## CR 609.7: the shield names ONE source; another source's damage passes.
func test_a_shield_ignores_other_sources() -> void:
	var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
	var other := put_battlefield(1, "Grizzly Bears")
	g.shield_next_damage(0, "Test Circle", sorcerer, [TargetRef.player(0)])
	g.deal_damage(other, TargetRef.player(0), 2)
	assert_eq(g.players[0].life, 18)
	assert_eq(g.damage_effects.size(), 1)


## CR 400.7: the shielded creature leaves and comes back — a new object the
## shield never covered.
func test_a_creature_shield_does_not_follow_a_new_object() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.shield_next_damage(0, "Test Circle", sorcerer, [TargetRef.card(bear)])
	g.return_to_hand(bear)
	g.put_from_hand_into_play(bear, 0)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	g.deal_damage(sorcerer, TargetRef.card(bear), 1)
	assert_eq(bear.damage, 1, "the returned bear is not the shielded one")


## Control change: "creatures you control" is read when the damage would be
## dealt — a creature stolen from you after the shield is not covered.
func test_creatures_you_control_is_read_at_damage_time() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var pest := put_battlefield(0, "Pestilence")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.shield_next_damage(1, "Test Shadowbane", pest, [TargetRef.player(1)], 1)
	g.change_control(bear, 0)
	_pestilence_once(0, pest)
	assert_eq(bear.damage, 1, "it is theirs now")
	assert_eq(g.players[1].life, 20, "you are still shielded")


## Reflect Damage: the next damage EVENT from the source — every victim of
## it — is dealt to the source's controller instead, and the reflected
## damage is not reflected again (CR 614.5).
func test_reflect_turns_a_whole_event_on_the_sources_controller() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var pest := put_battlefield(0, "Pestilence")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.reflect_next_damage(1, "Test Reflect", pest)
	_pestilence_once(0, pest)
	assert_eq(g.players[1].life, 20)
	assert_eq(bear.damage, 0)
	assert_eq(g.players[0].life, 17, "1 for you, 1 for your bear, 1 for its own controller")
	_pestilence_once(0, pest)
	assert_eq(g.players[1].life, 19, "one event only")


## Reflect on a spell: the Bolt aimed at your creature hits its caster.
func test_reflect_on_a_spell_aimed_at_a_creature() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(0))
	var reflect := give_synthetic(1, _instant("Test Reflect", SourceShieldEffect.reflect()))
	assert_ok(g.cast_spell(1, reflect, []))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 17)


## Zhalfirin Crusader: "the next 1 damage that would be dealt to this
## creature this turn is dealt to any target instead" — one point moves,
## the rest lands; to a player or to a creature.
func test_a_metered_redirect_moves_one_point_to_any_target() -> void:
	var knight := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	var giant := put_battlefield(1, "Hill Giant")
	g.redirect_next_damage_points(0, "Test Crusader", knight, 1, TargetRef.card(wall))
	g.redirect_next_damage_points(0, "Test Crusader", knight, 1, TargetRef.player(1))
	var chooser := _chooser(0)
	g.deal_damage(giant, TargetRef.card(knight), 3)
	assert_eq(chooser.asked.size(), 1, "two redirects: the controller orders them")
	assert_eq(knight.damage, 1, "two of three points left")
	assert_eq(wall.damage, 1, "one to the wall")
	assert_eq(g.players[1].life, 19, "one to the player")
	assert_true(g.damage_effects.is_empty(), "both points spent")


## The destination is gone by the time the damage comes: nothing to redirect
## to, so the damage stays where it was (CR 614.6) and the point waits.
func test_a_metered_redirect_with_no_destination_does_not_apply() -> void:
	var knight := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	g.redirect_next_damage_points(0, "Test Crusader", knight, 1, TargetRef.card(bear))
	g.destroy(bear)
	g.deal_damage(giant, TargetRef.card(knight), 2)
	assert_eq(knight.damage, 2)


## Lichenthrope: damage becomes -1/-1 counters — nothing marked, no
## DAMAGE_DEALT, and the counters are what kill it.
func test_damage_becomes_counters() -> void:
	var lichen := put_synthetic(0, _lichen())
	var giant := put_battlefield(1, "Hill Giant")
	_heard.clear()
	g.event_occurred.connect(_hear_damage)
	g.deal_damage(giant, TargetRef.card(lichen), 3)
	assert_eq(lichen.damage, 0, "no damage is marked")
	assert_eq(int(lichen.counters.get("-1/-1", 0)), 3)
	assert_eq(lichen.cur_toughness, 2)
	assert_eq(_heard.size(), 0, "the counters replaced the damage event")
	g.deal_damage(giant, TargetRef.card(lichen), 2)
	assert_eq(lichen.zone, Mtg.Zone.GRAVEYARD, "five counters on a 5/5")


## CR 615.12: damage that can't be prevented is still REPLACED by counters
## (no prevention involved), while a prevention shield on the same creature
## neither applies nor is used up.
func test_unpreventable_damage_meets_the_replacement_but_not_the_shield() -> void:
	var lichen := put_synthetic(0, _lichen())
	var giant := put_battlefield(1, "Hill Giant")
	lichen.damage_unpreventable_this_turn = true
	g.shield_next_damage(0, "Test Circle", giant, [TargetRef.card(lichen)])
	g.deal_damage(giant, TargetRef.card(lichen), 2)
	assert_eq(int(lichen.counters.get("-1/-1", 0)), 2, "counters still")
	assert_eq(g.damage_effects.size(), 1, "the shield was not spent")
	var bear := put_battlefield(0, "Grizzly Bears")
	bear.damage_unpreventable_this_turn = true
	g.shield_next_damage(0, "Test Circle", giant, [TargetRef.card(bear)])
	g.deal_damage(giant, TargetRef.card(bear), 1)
	assert_eq(bear.damage, 1, "can't be prevented")


## Torrent of Lava's granted ability books "prevent the next 1 damage that
## would be dealt to this creature by Torrent of Lava this turn": metered,
## keyed to that source.
func test_a_metered_shield_keyed_to_one_source() -> void:
	var wall := put_battlefield(0, "Wall of Stone")
	var giant := put_battlefield(1, "Hill Giant")
	var other := put_battlefield(1, "Grizzly Bears")
	g.prevent_next_damage_points(0, "Test Torrent", wall, 1, giant)
	g.deal_damage(other, TargetRef.card(wall), 2)
	assert_eq(wall.damage, 2, "another source's damage passes")
	g.deal_damage(giant, TargetRef.card(wall), 3)
	assert_eq(wall.damage, 4, "1 of 3 prevented")
	assert_true(g.damage_effects.is_empty(), "spent")


## The 616.1 walk on a PLAYER: a shield and a prevention pool — the damaged
## player is asked, and the hint is the shield.
func test_the_damaged_player_orders_a_shield_against_a_pool() -> void:
	var chooser := _chooser(0)
	var giant := put_battlefield(1, "Hill Giant")
	g.players[0].damage_prevention = 2
	g.shield_next_damage(0, "Test Circle", giant, [TargetRef.player(0)])
	g.deal_damage(giant, TargetRef.player(0), 3)
	assert_eq(chooser.asked.size(), 1)
	assert_eq(g.players[0].life, 20, "the shield first: all of it")
	assert_eq(g.players[0].damage_prevention, 2, "and the pool untouched")


## "This turn": the cleanup step ends a shield nobody used.
func test_an_unused_shield_ends_at_cleanup() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	g.shield_next_damage(0, "Test Circle", giant, [TargetRef.player(0)])
	advance_to_next_turn()
	assert_true(g.damage_effects.is_empty())


## Undo: a shield spent inside a search node is back after unmake.
func test_a_spent_shield_round_trips_through_the_journal() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	var id := g.shield_next_damage(0, "Test Circle", giant, [TargetRef.player(0)])
	var mark := g.make_mark()
	g.deal_damage(giant, TargetRef.player(0), 3)
	g.deal_damage(giant, TargetRef.player(0), 3)
	assert_eq(g.players[0].life, 17)
	assert_true(g.damage_effect(id).is_empty(), "spent")
	g.unmake_to(mark)
	g.end_search()
	assert_eq(g.players[0].life, 20)
	assert_false(g.damage_effect(id).is_empty(), "the shield is back")
	g.deal_damage(giant, TargetRef.player(0), 3)
	assert_eq(g.players[0].life, 20, "and it still works")


## FIFTH EDITION's damage-prevention window: combat damage waits as packets;
## a shield made inside the window applies as they land, and one Pestilence
## event's packets landing together are one event.
class Duelist extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true


func test_a_shield_made_in_the_1997_window_stops_the_waiting_damage() -> void:
	g.rules.damage_prevention_window = true
	g.set_agent(1, Duelist.new())
	give_hand(1, "Healing Salve")   # something to do in the window
	var wurm := put_battlefield(0, "Craw Wurm")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention)
	g.shield_next_damage(1, "Test Circle", wurm, [TargetRef.player(1)])
	assert_ok(g.end_damage_prevention(g.priority_player))
	if g.awaiting_damage_prevention or g.awaiting_regeneration:
		assert_ok(g.end_damage_prevention(g.priority_player))
	assert_eq(g.players[1].life, 20, "the waiting six were stopped as they landed")


# ======================================== N_repl_duration ==

## Soul Echo: a seat-level replacement marked "until_upkeep_of" survives the
## cleanup step and ends as that player's upkeep begins (CR 611.2b).
func test_a_seat_replacement_lasts_until_the_next_upkeep() -> void:
	g.players[0].damage_replacements.append({"desc": "Test Echo", "all_turn": true,
		"until_upkeep_of": 0, "filter": _always, "apply": _prevent_all})
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_next_turn()   # player 1's turn: cleanup passed, the echo stays
	assert_eq(g.players[0].damage_replacements.size(), 1)
	g.deal_damage(giant, TargetRef.player(0), 3)
	assert_eq(g.players[0].life, 20, "still replacing on the opponent's turn")
	advance_to_next_turn()   # player 0's upkeep has begun
	assert_true(g.players[0].damage_replacements.is_empty(), "ended at the upkeep")


## The registry's own long duration: `"lasts": &"upkeep"`.
func test_a_registry_effect_lasts_until_the_named_upkeep() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	g.add_damage_effect({"kind": &"prevent", "victims": [TargetRef.player(0)],
		"lasts": &"upkeep", "lasts_pid": 0, "desc": "Test Echo"})
	advance_to_next_turn()
	g.deal_damage(giant, TargetRef.player(0), 3)
	assert_eq(g.players[0].life, 20)
	advance_to_next_turn()
	assert_true(g.damage_effects.is_empty())


# ============================================ N_ogre_lethal ==

## Two sources, two points each, on a 4/4: lethal in all, from no one source.
func test_split_lethal_damage_does_not_destroy() -> void:
	var ogre := put_synthetic(0, _ogre())
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	g.deal_damage(a, TargetRef.card(ogre), 2)
	g.deal_damage(b, TargetRef.card(ogre), 2)
	assert_eq(ogre.zone, Mtg.Zone.BATTLEFIELD, "4 marked, 2 + 2")
	g.deal_damage(a, TargetRef.card(ogre), 2)
	assert_eq(ogre.zone, Mtg.Zone.GRAVEYARD, "one source has now marked 4")


## Regeneration removes the marked damage — and with it every source's
## share of it; the toughness-0 rule is untouched.
func test_regeneration_wipes_the_per_source_ledger() -> void:
	var ogre := put_synthetic(0, _ogre())
	var a := put_battlefield(1, "Hill Giant")
	ogre.regeneration_shields = 1
	g.deal_damage(a, TargetRef.card(ogre), 3)
	g.deal_damage(a, TargetRef.card(ogre), 1)
	assert_eq(ogre.zone, Mtg.Zone.BATTLEFIELD, "regenerated")
	assert_true(ogre.marked_damage_by_source.is_empty())
	g.deal_damage(a, TargetRef.card(ogre), 3)
	assert_eq(ogre.zone, Mtg.Zone.BATTLEFIELD, "3 is not lethal from scratch")


func _silence_creatures(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature():
			inst.cur_abilities_silenced = true


## A creature that LOST ALL ABILITIES has lost this one too: ordinary
## lethal damage again.
func test_the_rule_is_the_creatures_own_ability() -> void:
	var ogre := put_synthetic(0, _ogre())
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	g.deal_damage(a, TargetRef.card(ogre), 2)
	put_synthetic(1, CardData.new("Test Silence", "{2}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_silence_creatures,
			"Creatures lose all abilities.").silencing_abilities()))
	assert_false(ogre.cur_lethal_needs_single_source)
	g.deal_damage(b, TargetRef.card(ogre), 2)
	assert_eq(ogre.zone, Mtg.Zone.GRAVEYARD, "4 marked on a 4/4, from anyone")


# ===================================== N_divided_prevention ==

## Remedy: "prevent the next 5 damage ... divided as you choose" — each
## target's pool gets its own share; a division that does not add up is
## refused before anything is paid (CR 601.2d).
func test_divided_prevention_hands_each_target_its_share() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var remedy := give_synthetic(0, _instant("Test Remedy", PreventDamageEffect.new(0).divided(5)))
	assert_refused(g.cast_spell(0, remedy, [TargetRef.card(bear, 3), TargetRef.player(0, 1)]))
	assert_ok(g.cast_spell(0, remedy, [TargetRef.card(bear, 3), TargetRef.player(0, 2)]))
	resolve_stack()
	assert_eq(bear.prevention, 3)
	assert_eq(g.players[0].damage_prevention, 2)


# ========================================== N_stack_static ==

func _grant_shield_static(game: MtgGame, spell: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature():
			inst.cur_activated_abilities.append(ActivatedAbility.new("", true,
				[TorrentShield.new(spell.id)], "{T}: Prevent the next 1 damage from it."))


class TorrentShield extends EffectBase:
	var spell_id := -1

	func _init(p_spell: int) -> void:
		spell_id = p_spell
		is_damage_prevention = true

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var spell := game.find_instance(spell_id)
		game.prevent_next_damage_points(controller, "Test Torrent", source, 1, spell)


## "Test Torrent deals X damage to each creature without flying. As long as
## it is on the stack, each creature has '{T}: Prevent the next 1 damage
## that would be dealt to this creature by Test Torrent this turn.'"
func _torrent() -> CardData:
	return CardData.new("Test Torrent", "{X}", Mtg.CardType.SORCERY) \
		.spell(DamageAllEffect.new(0, "each creature without flying",
			func(inst: CardInstance) -> bool: return not inst.has_keyword(Mtg.Keyword.FLYING)).x_damage()) \
		.stack_static(StaticAbility.new(_grant_shield_static, "each creature has a shield ability"))


## The ability exists exactly while the spell is on the stack; using it
## makes the spell's own damage one less to that creature.
func test_a_stack_static_grants_an_ability_while_the_spell_waits() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var wall := put_battlefield(1, "Wall of Stone")
	var bear := put_battlefield(1, "Grizzly Bears")
	var before := wall.cur_activated_abilities.size()
	var torrent := give_synthetic(0, _torrent())
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, torrent, [], 3))
	assert_eq(wall.cur_activated_abilities.size(), before + 1, "granted on the stack")
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, wall, before))
	resolve_stack()
	assert_eq(wall.damage, 2, "3 from the Torrent, 1 prevented")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wall.cur_activated_abilities.size(), before, "gone with the spell")


## Kaervek's Torch: "As long as this is on the stack, spells that target it
## cost {2} more to cast."
func test_a_spell_targeting_a_surcharged_spell_costs_more() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var torch := give_synthetic(0, CardData.new("Test Torch", "{X}{R}", Mtg.CardType.SORCERY) \
		.spell(DamageEffect.new(0).any_target().x_damage()).with_targeting_surcharge(2))
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, torch, [TargetRef.player(1)], 2))
	assert_ok(g.pass_priority(0))
	var counter := give_hand(1, "Counterspell")
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_refused(g.cast_spell(1, counter, [TargetRef.card(torch)]), "more")
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(torch)]))
	resolve_stack()
	assert_eq(g.players[1].life, 20, "countered")


# ========================================== predict_damage ==

## The AI's question — "what would this REALLY do?" — through every
## replacement on the table, and the table is untouched afterwards.
func test_predict_damage_reads_the_replacements_and_changes_nothing() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_synthetic(1, _unicorn())
	var bolt := give_hand(0, "Lightning Bolt")
	var bear := put_battlefield(1, "Grizzly Bears")
	var to_face := g.predict_damage(bolt, TargetRef.player(1), 3)
	assert_eq(int(to_face["dealt"]), 2, "a Bolt in hand is a spell: 3 - 1")
	var to_bear := g.predict_damage(bolt, TargetRef.card(bear), 3)
	assert_eq(int(to_bear["dealt"]), 2)
	assert_true(bool(to_bear["dies"]), "2 kills a 2/2")
	assert_eq(g.players[1].life, 20, "nothing really happened")
	assert_eq(bear.damage, 0)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_null(g.undo_log, "the search was closed")


func test_predict_damage_sees_counters_and_split_lethal() -> void:
	var lichen := put_synthetic(1, _lichen())
	var ogre := put_synthetic(1, _ogre())
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(0, "Grizzly Bears")
	var into_lichen := g.predict_damage(giant, TargetRef.card(lichen), 5, true)
	assert_eq(int(into_lichen["dealt"]), 0, "no damage is marked")
	assert_eq(int(into_lichen["toughness"]), 0)
	assert_true(bool(into_lichen["dies"]), "five -1/-1 counters")
	g.deal_damage(bear, TargetRef.card(ogre), 2)
	var into_ogre := g.predict_damage(giant, TargetRef.card(ogre), 3)
	assert_false(bool(into_ogre["dies"]), "2 + 3 marked, no one source's 4")
	assert_eq(int(lichen.counters.get("-1/-1", 0)), 0, "untouched")
	assert_eq(ogre.damage, 2, "untouched")


# ================================== SourceShieldEffect, the rest ==

func _sac_armor() -> CardData:
	return CardData.new("Test Armor", "{0}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.activated(ActivatedAbility.new("", false, [SourceShieldEffect.prevent_to_enchanted()],
			"Sacrifice this Aura: The next time a source of your choice would deal damage to enchanted creature this turn, prevent that damage.") \
			.with_sacrifice_cost())


## Kithkin Armor: the Aura is SACRIFICED as the cost, so "enchanted
## creature" is the creature it was attached to (last known information).
func test_a_sacrificed_aura_shields_the_creature_it_enchanted() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
	var armor := give_synthetic(0, _sac_armor())
	assert_ok(g.cast_spell(0, armor, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(armor.attached_to, bear.id)
	assert_ok(g.activate_ability(0, armor, 0))
	resolve_stack()
	assert_eq(armor.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	g.deal_damage(sorcerer, TargetRef.card(bear), 1)
	assert_eq(bear.damage, 0, "the enchanted creature was shielded against the named source")


func _shadowbane_rider(game: MtgGame, packet: DamagePacket, amount: int,
		_effect_source: CardInstance, controller: int) -> void:
	if (game.damage_source_colors(packet.source) & Mtg.ManaColor.B) != 0:
		game.adjust_life(controller, amount)


## The effect's rider signature: (game, packet, amount, effect source,
## controller) — Shadowbane's black-source life gain.
func test_the_source_shield_effect_runs_its_rider() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var pest := put_battlefield(0, "Pestilence")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, pest, 0))
	assert_ok(g.pass_priority(0))
	var bane := give_synthetic(1, _instant("Test Bane",
		SourceShieldEffect.prevent_to_you_and_your_creatures().with_rider(_shadowbane_rider)))
	assert_ok(g.cast_spell(1, bane, []))
	resolve_stack()
	assert_eq(g.players[1].life, 21, "prevented, and the black source paid it back")
	assert_eq(g.players[0].life, 19)


func _yours(_game: MtgGame, inst: CardInstance, controller: int) -> bool:
	return inst.controller_id == controller


## Desperate Gambit's win, declaratively: "choose a source YOU control" and
## double its next damage — an opponent's source is not on offer.
func test_a_doubling_shield_names_only_a_source_you_control() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var mine := put_battlefield(0, "Prodigal Sorcerer")
	put_battlefield(1, "Prodigal Sorcerer")
	var gambit := give_synthetic(0, _instant("Test Gambit",
		SourceShieldEffect.new(SourceShieldEffect.Victims.ANY, SourceShieldEffect.Action.DOUBLE) \
			.from_sources("a source you control", _yours)))
	assert_ok(g.cast_spell(0, gambit, []))
	resolve_stack()
	assert_eq(g.damage_effects.size(), 1)
	assert_eq(int(g.damage_effects[0]["source_id"]), mine.id)
	assert_ok(g.activate_ability(0, mine, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 18, "doubled")


## FAIR INFORMATION: the AI asks as a seat. A face-down creature it does
## not control is predicted as the 2/2 it shows, not through its hidden
## face (which dealing damage would turn up).
func test_predict_damage_does_not_read_a_hidden_face_for_a_viewer() -> void:
	var lichen := put_synthetic(1, _lichen())
	g.turn_face_down(lichen)
	assert_true(lichen.face_down)
	var giant := put_battlefield(0, "Hill Giant")
	var seen := g.predict_damage(giant, TargetRef.card(lichen), 3, false, -1, 0)
	assert_eq(int(seen["dealt"]), 3, "the public 2/2 takes 3")
	assert_true(bool(seen["dies"]))
	assert_true(lichen.face_down, "nothing was turned up")
	var referee := g.predict_damage(giant, TargetRef.card(lichen), 3)
	assert_eq(int(referee["dealt"]), 0, "the referee knows it becomes counters")
	assert_true(lichen.face_down, "and the referee's run is rewound too")
