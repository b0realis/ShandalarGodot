extends GameTest
## Fidelity lifts of 2026-09-02, permanents batch: Earthbind (an Aura enters
## attached, so its own arrival trigger sees its host — CR 303.4a / 603.4),
## Artifact Ward (abilities, not spells, from artifact sources), Field of
## Dreams (the top card of each library is revealed) and Firestorm Phoenix
## (returned to hand revealed, unplayable until the owner's next turn).


# ---------------------------------------------------------------- Earthbind --

func test_earthbind_on_a_grounded_creature_never_triggers() -> void:
	# CR 603.4: "When this Aura enters, IF enchanted creature has flying" —
	# with a grounded host the ability does not trigger at all: after the
	# Aura resolves the stack is EMPTY, not holding a do-nothing trigger.
	var bear := put_battlefield(1, "Grizzly Bears")
	var earthbind := give_hand(0, "Earthbind")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, earthbind, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_eq(earthbind.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(earthbind.attached_to, bear.id, "entered attached (CR 303.4a)")
	assert_true(g.stack.is_empty(), "no trigger went on the stack")
	assert_eq(bear.damage, 0)


func test_earthbind_on_a_flyer_triggers_and_grounds_it() -> void:
	var angel := put_battlefield(1, "Serra Angel")   # 4/4 flying
	var earthbind := give_hand(0, "Earthbind")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, earthbind, [TargetRef.card(angel)]))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_eq(g.stack.size(), 1, "the arrival trigger is on the stack")
	resolve_stack()
	assert_eq(angel.damage, 2)
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING), "grounded")


func test_earthbind_spares_a_host_that_lost_flying_in_response() -> void:
	# The intervening-if is checked again on resolution (CR 603.4).
	var angel := put_battlefield(1, "Serra Angel")
	var earthbind := give_hand(0, "Earthbind")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, earthbind, [TargetRef.card(angel)]))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_eq(g.stack.size(), 1)
	g.continuous.add_until_eot_loss(angel.id, [Mtg.Keyword.FLYING])
	g.recalculate()
	resolve_stack()
	assert_eq(angel.damage, 0, "no flying on resolution: nothing happens")
	assert_false(earthbind.memory.has("armed"))


func test_aura_is_attached_before_its_arrival_event() -> void:
	# CR 303.4a: the Aura enters attached — a watcher of the ENTERS_BATTLEFIELD
	# event already sees `attached_to` set.
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Holy Strength")
	var seen := []
	g.event_occurred.connect(func(ev: GameEvent) -> void:
		if ev.type == Mtg.EventType.ENTERS_BATTLEFIELD \
				and ev.data.get("instance") == aura:
			seen.append(aura.attached_to))
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(seen, [bear.id])
	assert_eq(bear.cur_power, 3, "and the static already applied")


# ------------------------------------------------------------ Artifact Ward --

func test_artifact_ward_refuses_an_artifact_ability() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var ward := put_battlefield(0, "Artifact Ward")
	g.attach_aura_from_anywhere(ward, bear, 0)
	var rod := put_battlefield(1, "Rod of Ruin")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(1, rod, 0, [TargetRef.card(bear)]), "Illegal target")


func test_artifact_ward_lets_an_artifact_spell_target_the_creature() -> void:
	# "can't be the target of ABILITIES from artifact sources" — an artifact
	# SPELL is not an ability. No artifact spell in the 1997 pool targets a
	# creature, so a synthetic one stands in.
	var bear := put_battlefield(0, "Grizzly Bears")
	var ward := put_battlefield(0, "Artifact Ward")
	g.attach_aura_from_anywhere(ward, bear, 0)
	var probe := CardData.new("Ward Probe", "{1}",
		Mtg.CardType.ARTIFACT | Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(1).any_target())
	var spell := CardInstance.new(probe, g._next_instance_id, 1)
	g._next_instance_id += 1
	g._instances[spell.id] = spell
	spell.zone = Mtg.Zone.HAND
	g.players[1].hand.append(spell)
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.C, 1)
	assert_ok(g.cast_spell(1, spell, [TargetRef.card(bear)]))
	resolve_stack()
	# The damage is from an artifact source — the ward's second clause
	# prevents it (that clause is source-kind blind, as printed).
	assert_eq(bear.damage, 0, "damage from an artifact source is prevented")
	assert_eq(spell.zone, Mtg.Zone.GRAVEYARD, "the spell resolved")


# ---------------------------------------------------------- Field of Dreams --

func test_field_of_dreams_reveals_both_library_tops() -> void:
	assert_null(g.revealed_top_card(0), "hidden without the Field")
	var field := put_battlefield(0, "Field of Dreams")
	assert_true(g.players[0].top_card_revealed)
	assert_true(g.players[1].top_card_revealed, "BOTH players")
	assert_eq(g.revealed_top_card(0), g.players[0].library[-1])
	assert_eq(g.revealed_top_card(1), g.players[1].library[-1])
	g.destroy(field, false)
	assert_null(g.revealed_top_card(0), "hidden again once it leaves")
	assert_null(g.revealed_top_card(1))


func test_field_of_dreams_announces_each_new_top() -> void:
	put_battlefield(0, "Field of Dreams")
	var mind_twist := give_hand(0, "Lightning Bolt")   # any card, on top
	g.players[0].hand.erase(mind_twist)
	mind_twist.zone = Mtg.Zone.LIBRARY
	g.players[0].library.append(mind_twist)
	g._emit_state()
	var seen := _reveal_lines()
	assert_true(seen.has("The top card of P0's library is revealed: Lightning Bolt"),
		str(seen))
	# Drawing it turns a new card up — announced once, not on every publish.
	var before := seen.size()
	g.draw_cards(0, 1)
	g._emit_state()
	g._emit_state()
	seen = _reveal_lines()
	assert_eq(seen.size(), before + 1, "one line for the Forest now on top")
	assert_true(seen[-1].ends_with("Forest"))


func _reveal_lines() -> Array[String]:
	var out: Array[String] = []
	for l in g.log_lines:
		if String(l).begins_with("The top card of"):
			out.append(String(l))
	return out


func test_field_of_dreams_reveals_nothing_of_an_empty_library() -> void:
	put_battlefield(0, "Field of Dreams")
	g.players[1].library.clear()
	assert_null(g.revealed_top_card(1))


# --------------------------------------------------------- Firestorm Phoenix --

func test_firestorm_phoenix_is_revealed_and_locked_when_it_returns() -> void:
	var phoenix := put_battlefield(0, "Firestorm Phoenix")
	advance_to_step(Mtg.Step.MAIN1)
	g.destroy(phoenix, false)
	assert_eq(phoenix.zone, Mtg.Zone.HAND)
	assert_true(phoenix.revealed_in_hand, "played with it revealed")
	assert_eq(phoenix.hand_lock_turn, g.turn_number)
	add_mana(0, Mtg.ManaColor.R, 6)
	assert_refused(g.cast_spell(0, phoenix, []), "can't be played until your next turn")


func test_firestorm_phoenix_dying_on_its_own_turn_sits_out_the_opponents_turn() -> void:
	var phoenix := put_battlefield(0, "Firestorm Phoenix")
	advance_to_step(Mtg.Step.MAIN1)
	g.destroy(phoenix, false)
	advance_to_next_turn()   # turn 2, the opponent's
	assert_eq(g.active_player, 1)
	assert_true(phoenix.revealed_in_hand, "still locked through their turn")
	assert_ne(phoenix.hand_lock_turn, -1)
	advance_to_next_turn()   # turn 3, the owner's next turn
	assert_eq(g.active_player, 0)
	assert_eq(phoenix.hand_lock_turn, -1, "free as the owner's next turn begins")
	assert_false(phoenix.revealed_in_hand)
	assert_true(g.log_lines.has("Firestorm Phoenix may be played again"))
	add_mana(0, Mtg.ManaColor.R, 6)
	assert_ok(g.cast_spell(0, phoenix, []))


func test_firestorm_phoenix_dying_on_the_opponents_turn_is_free_next_turn() -> void:
	var phoenix := put_battlefield(0, "Firestorm Phoenix")
	advance_to_next_turn()   # turn 2, the opponent's
	g.destroy(phoenix, false)
	assert_eq(phoenix.zone, Mtg.Zone.HAND)
	assert_true(phoenix.revealed_in_hand)
	advance_to_next_turn()   # turn 3, the owner's
	assert_eq(g.active_player, 0)
	assert_eq(phoenix.hand_lock_turn, -1)
	add_mana(0, Mtg.ManaColor.R, 6)
	assert_ok(g.cast_spell(0, phoenix, []))


func test_firestorm_phoenix_lock_belongs_to_its_stay_in_the_hand() -> void:
	# CR 400.7: discarded and brought back, it is a new object — no lock.
	var phoenix := put_battlefield(0, "Firestorm Phoenix")
	advance_to_step(Mtg.Step.MAIN1)
	g.destroy(phoenix, false)
	g.discard_cards(0, [phoenix])
	assert_eq(phoenix.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(phoenix.hand_lock_turn, -1)
	assert_false(phoenix.revealed_in_hand)


func test_the_lock_is_only_for_the_phoenix_rider() -> void:
	# A plain "return to hand" (Unsummon) carries no lock.
	var bear := put_battlefield(0, "Grizzly Bears")
	g.return_to_hand(bear)
	assert_eq(bear.hand_lock_turn, -1)
	assert_false(bear.revealed_in_hand)
	assert_eq(g.hand_lock_reason(bear), "")
