extends GameTest
## Pack 9 bug pass (fix-licid; findings h3-5, h4-5) — a licid's "becomes an
## Aura enchantment with enchant creature" EFFECT outlives a later rewrite
## of the object's copiable values.
##
## The licid ability's effect is a type- and ability-changing effect from
## a resolved ability (CR 611.2c; layers 4 and 6, CR 613.1d/f). A copy
## effect or "has the full text of" (layer 1, CR 613.1a, 707.2) applied
## to the same object later changes only the values UNDER it: the object
## takes the new name, colour and abilities, and is still an Aura
## enchantment attached to its creature, its controller may still pay the
## ORIGINAL end cost (CR 116.2c), and ending the effect leaves it the copy
## it is now. Until this pass the effect was encoded only as a swap of the
## instance's `data`, which the next copy (Unstable Shapeshifter, Vesuvan
## Doppelganger — [method MtgGame.become_copy]) or graveyard-top change
## (Volrath's Shapeshifter — ContinuousEffects._graveyard_top_copies)
## threw away: a creature again, still attached, with no end action.
##
## "You control enchanted creature" (Dominating Licid) is a printed static
## ability of the licid card (its own paragraph), not part of the effect:
## it goes with the copiable values that carry it.


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


# ----------------------------------------------------------------- helpers --

func _cast(pid: int, card_name: String, mana: Array) -> CardInstance:
	var card := give_hand(pid, card_name)
	for m in mana: add_mana(pid, int(m))
	g.priority_player = pid
	assert_ok(g.cast_spell(pid, card, []))
	resolve_stack()
	return card


func _end_rows(pid: int, inst: CardInstance) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in g.special_actions(pid):
		if String(row["kind"]) == "licid_end" and int(row["id"]) == inst.id:
			out.append(row)
	return out


func _licid_index(inst: CardInstance) -> int:
	for i in inst.cur_activated_abilities.size():
		if inst.cur_activated_abilities[i] == inst.data.licid_ability:
			return i
	return -1


## A red 2/2 licid ({R}: become an Aura; pay {R} to end), Enraging Licid's shape.
static func _synthetic_licid() -> CardData:
	return CardData.new("Synthetic Licid", "{1}{R}", Mtg.CardType.CREATURE).pt(2, 2) \
		.with_subtypes(["licid"]).as_licid("{R}", "{R}")


## The Unstable Shapeshifter (a copy of Gliding Licid) as an Aura on [param host].
func _unstable_licid_on(host: CardInstance) -> CardInstance:
	var shifter := put_battlefield(0, "Unstable Shapeshifter")
	_cast(0, "Gliding Licid", [Mtg.ManaColor.U, Mtg.ManaColor.C, Mtg.ManaColor.C])
	assert_eq(shifter.data.card_name, "Gliding Licid", "precondition: it copied the licid")
	add_mana(0, Mtg.ManaColor.U)
	g.priority_player = 0
	assert_ok(g.activate_ability(0, shifter, _licid_index(shifter), [TargetRef.card(host)]))
	resolve_stack()
	assert_true(g.is_licid_aura(shifter), "precondition: an Aura")
	assert_eq(shifter.attached_to, host.id, "precondition: attached")
	return shifter


## Volrath's Shapeshifter with Gliding Licid's text, made an Aura on [param host].
func _volrath_licid_on(host: CardInstance) -> CardInstance:
	var shifter := put_battlefield(0, "Volrath's Shapeshifter")
	g.discard_cards(0, [give_hand(0, "Gliding Licid")])
	g.recalculate()
	assert_eq(shifter.data.card_name, "Gliding Licid", "precondition: the graveyard's top text")
	add_mana(0, Mtg.ManaColor.U)
	g.priority_player = 0
	assert_ok(g.activate_ability(0, shifter, _licid_index(shifter), [TargetRef.card(host)]))
	resolve_stack()
	assert_true(g.is_licid_aura(shifter), "precondition: an Aura")
	assert_eq(shifter.attached_to, host.id, "precondition: attached")
	return shifter


# ------------------------------------------------------ Unstable Shapeshifter --

func test_unstable_shapeshifter_stays_an_aura_when_it_copies_the_next_creature() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var shifter := _unstable_licid_on(bear)
	_cast(0, "Savannah Lions", [Mtg.ManaColor.W])
	assert_eq(shifter.data.card_name, "Savannah Lions", "the copy effect applied (layer 1)")
	assert_false(shifter.is_creature(), "the licid effect still makes it an Aura (layer 4)")
	assert_true(shifter.is_aura())
	assert_true(g.is_licid_aura(shifter))
	assert_eq(shifter.attached_to, bear.id, "still attached to the bear")
	assert_eq(shifter.zone, Mtg.Zone.BATTLEFIELD, "no Aura state-based action")
	var rows := _end_rows(0, shifter)
	assert_eq(rows.size(), 1, "its controller may still pay to end the effect")
	assert_eq(str(rows[0]["cost"]), "{U}", "the end cost is Gliding Licid's, from the effect")
	# Ending it leaves the copy it is NOW: a Savannah Lions that still has
	# the shapeshift ability, unattached.
	add_mana(0, Mtg.ManaColor.U)
	g.priority_player = 0
	assert_ok(g.end_licid_effect(0, shifter))
	assert_false(g.is_licid_aura(shifter))
	assert_true(shifter.is_creature())
	assert_eq(shifter.data.card_name, "Savannah Lions")
	assert_eq([shifter.cur_power, shifter.cur_toughness], [2, 1])
	assert_eq(shifter.attached_to, -1)
	assert_false(bear.attachments.has(shifter.id))
	assert_eq(shifter.data.triggered_abilities.size(), 1, "it still has this ability")


func test_an_end_cost_of_the_wrong_colour_does_not_end_it_after_the_copy() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var shifter := _unstable_licid_on(bear)
	_cast(0, "Savannah Lions", [Mtg.ManaColor.W])
	add_mana(0, Mtg.ManaColor.W)
	g.priority_player = 0
	assert_refused(g.end_licid_effect(0, shifter), "not enough mana")
	assert_true(g.is_licid_aura(shifter), "{W} does not pay {U}: still an Aura")


func test_a_licid_aura_copying_a_dominating_licid_gains_its_control_ability() -> void:
	# The Aura on THEIR creature takes Dominating Licid's text, whose
	# "You control enchanted creature" now works for it (a printed static
	# of the copied card); the licid effect itself — and its {U} end cost —
	# is still Gliding Licid's.
	var theirs := put_battlefield(1, "Grizzly Bears")
	var shifter := _unstable_licid_on(theirs)
	assert_eq(theirs.controller_id, 1, "Gliding Licid's Aura steals nothing")
	_cast(0, "Dominating Licid", [Mtg.ManaColor.U, Mtg.ManaColor.U, Mtg.ManaColor.C])
	assert_eq(shifter.data.card_name, "Dominating Licid")
	assert_false(shifter.is_creature())
	assert_eq(shifter.attached_to, theirs.id)
	assert_eq(theirs.controller_id, 0, "You control enchanted creature")
	assert_eq(_licid_index(shifter), -1, "an Aura has no licid ability to activate")


func test_a_dominating_licid_aura_copying_a_plain_creature_loses_its_control_text() -> void:
	# The control layer asks whether an Aura still steals
	# (engine/core/control_layers.gd _live), so its host goes back.
	var theirs := put_battlefield(1, "Grizzly Bears")
	var shifter := put_battlefield(0, "Unstable Shapeshifter")
	_cast(0, "Dominating Licid", [Mtg.ManaColor.U, Mtg.ManaColor.U, Mtg.ManaColor.C])
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C)
	g.priority_player = 0
	assert_ok(g.activate_ability(0, shifter, _licid_index(shifter), [TargetRef.card(theirs)]))
	resolve_stack()
	assert_eq(theirs.controller_id, 0, "precondition: stolen")
	_cast(0, "Savannah Lions", [Mtg.ManaColor.W])
	assert_eq(shifter.data.card_name, "Savannah Lions")
	assert_false(shifter.is_creature(), "still an Aura")
	assert_eq(shifter.attached_to, theirs.id)
	assert_false(shifter.data.aura_steals, "Savannah Lions' text controls nothing")
	assert_eq(theirs.controller_id, 1, "and the creature goes back to its owner")
	assert_eq(str(_end_rows(0, shifter)[0]["cost"]), "{U}")


# ---------------------------------------------------- Volrath's Shapeshifter --

func test_volraths_shapeshifter_stays_an_aura_when_the_graveyard_top_changes() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var shifter := _volrath_licid_on(bear)
	g.discard_cards(0, [give_hand(0, "Savannah Lions")])
	g.recalculate()
	assert_eq(shifter.data.card_name, "Savannah Lions", "the new top's text (layer 1)")
	assert_false(shifter.is_creature(), "still an Aura enchantment (the licid effect)")
	assert_eq(shifter.attached_to, bear.id)
	assert_eq(shifter.zone, Mtg.Zone.BATTLEFIELD)
	var rows := _end_rows(0, shifter)
	assert_eq(rows.size(), 1)
	assert_eq(str(rows[0]["cost"]), "{U}")
	# The derived definition is settled: further recalculations change nothing.
	var settled := shifter.data
	g.recalculate()
	g.recalculate()
	assert_same(shifter.data, settled, "no re-derivation while the top stays the same")
	# A creature card that DIES onto the top (the h4 shape) — same story.
	var giant := put_battlefield(0, "Hill Giant")
	g.destroy(giant)
	assert_eq(shifter.data.card_name, "Hill Giant")
	assert_false(shifter.is_creature())
	assert_eq(shifter.attached_to, bear.id)


func test_volraths_shapeshifter_aura_with_a_noncreature_top_is_its_own_text_as_an_aura() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var shifter := _volrath_licid_on(bear)
	g.discard_cards(0, [give_hand(0, "Forest")])
	g.recalculate()
	assert_eq(shifter.data.card_name, "Volrath's Shapeshifter", "its own text again")
	assert_false(shifter.is_creature(), "and still an Aura")
	assert_eq(shifter.attached_to, bear.id)
	var settled := shifter.data
	g.recalculate()
	assert_same(shifter.data, settled, "settled, not re-derived every recalculation")
	# End the effect: the Shapeshifter creature with its own text.
	add_mana(0, Mtg.ManaColor.U)
	g.priority_player = 0
	assert_ok(g.end_licid_effect(0, shifter))
	assert_true(shifter.is_creature())
	assert_eq(shifter.data.card_name, "Volrath's Shapeshifter")
	assert_eq(shifter.attached_to, -1)
	# And it follows its graveyard again as a creature.
	g.discard_cards(0, [give_hand(0, "Savannah Lions")])
	g.recalculate()
	assert_eq(shifter.data.card_name, "Savannah Lions")
	assert_true(shifter.is_creature())


func test_ending_volraths_licid_aura_leaves_the_current_top_creature() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var shifter := _volrath_licid_on(bear)
	g.discard_cards(0, [give_hand(0, "Savannah Lions")])
	g.recalculate()
	add_mana(0, Mtg.ManaColor.U)
	g.priority_player = 0
	assert_ok(g.end_licid_effect(0, shifter))
	assert_true(shifter.is_creature())
	assert_eq(shifter.data.card_name, "Savannah Lions")
	assert_eq([shifter.cur_power, shifter.cur_toughness], [2, 1])
	assert_eq(shifter.attached_to, -1)
	g.recalculate()
	assert_eq(shifter.data.card_name, "Savannah Lions", "still following its graveyard")


# ------------------------------------------- the engine door (become_copy) --

func test_become_copy_on_a_licid_aura_keeps_the_effect_count_and_end_cost() -> void:
	# Vesuvan Doppelganger's upkeep copy goes through this door too.
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var licid := put_synthetic(0, _synthetic_licid())
	add_mana(0, Mtg.ManaColor.R, 2)
	g.priority_player = 0
	assert_ok(g.activate_ability(0, licid, 0, [TargetRef.card(giant)]))
	g.untap_permanent(licid)
	assert_ok(g.activate_ability(0, licid, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(int(licid.memory.get("licid_effects", 0)), 2, "precondition: two effects")
	g.become_copy(licid, CardRegistry.get_card("Savannah Lions"))
	assert_false(licid.is_creature())
	assert_eq(licid.attached_to, giant.id)
	assert_eq(int(licid.memory.get("licid_effects", 0)), 2, "both effects still apply")
	add_mana(0, Mtg.ManaColor.R)
	g.priority_player = 0
	assert_ok(g.end_licid_effect(0, licid))
	assert_true(g.is_licid_aura(licid), "one effect left")
	add_mana(0, Mtg.ManaColor.R)
	g.priority_player = 0
	assert_ok(g.end_licid_effect(0, licid))
	assert_true(licid.is_creature())
	assert_eq(licid.data.card_name, "Savannah Lions")


func test_a_search_rewinds_the_rederived_aura() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var licid := put_synthetic(0, _synthetic_licid())
	add_mana(0, Mtg.ManaColor.R)
	g.priority_player = 0
	assert_ok(g.activate_ability(0, licid, 0, [TargetRef.card(bear)]))
	resolve_stack()
	var before := licid.data
	var mark := g.make_mark()
	g.become_copy(licid, CardRegistry.get_card("Savannah Lions"))
	assert_eq(licid.data.card_name, "Savannah Lions")
	g.unmake_to(mark)
	g.end_search()
	assert_same(licid.data, before)
	assert_eq(str(_end_rows(0, licid)[0]["cost"]), "{R}")


func test_a_plain_licid_creature_copies_as_before() -> void:
	# Not an Aura: become_copy is the plain swap, nothing derived.
	var licid := put_synthetic(0, _synthetic_licid())
	var lions := CardRegistry.get_card("Savannah Lions")
	g.become_copy(licid, lions)
	assert_same(licid.data, lions)
	assert_true(licid.is_creature())
	assert_false(g.is_licid_aura(licid))


# ------------------------------------------------------- Vesuvan Doppelganger --

## Says yes to every "may" and picks cards by NAME, in order.
class Picker extends DecisionAgent:
	var picks: Array[String] = []

	func answer_yes_no(_g: MtgGame, _p: int, _prompt: String, _hint: bool) -> bool:
		return true

	func answer_card(_g: MtgGame, _p: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		var want: String = picks.pop_front() if not picks.is_empty() else ""
		for c in candidates:
			if c.data.card_name == want:
				return c
		return null if candidates.is_empty() else candidates[0]


func test_vesuvan_doppelganger_stays_an_aura_when_it_shifts_at_upkeep() -> void:
	var seat := Picker.new()
	g.set_agent(0, seat)
	put_battlefield(0, "Gliding Licid")
	seat.picks = ["Gliding Licid"]
	var dopp := put_battlefield(0, "Vesuvan Doppelganger")
	assert_eq(dopp.data.card_name, "Gliding Licid", "precondition: entered as the licid")
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.U)
	g.priority_player = 0
	assert_ok(g.activate_ability(0, dopp, _licid_index(dopp), [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(g.is_licid_aura(dopp), "precondition: an Aura on the bear")
	# Its next upkeep: "you may have this creature become a copy of target
	# creature ... and it has this ability" — it takes the Giant's text.
	seat.picks = ["Hill Giant"]
	advance_to_next_turn()
	while g.active_player != 0:
		advance_to_next_turn()
	resolve_stack()
	assert_eq(dopp.data.card_name, "Hill Giant", "the upkeep copy applied")
	assert_false(dopp.is_creature(), "still an Aura enchantment (the licid effect)")
	assert_eq(dopp.attached_to, bear.id)
	assert_eq(dopp.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(str(_end_rows(0, dopp)[0]["cost"]), "{U}")
