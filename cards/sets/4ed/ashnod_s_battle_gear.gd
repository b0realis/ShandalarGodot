extends CardScript
## Ashnod's Battle Gear — {2} — Artifact — (4ed, uncommon)
## Oracle: You may choose not to untap this artifact during your untap step.
##         {2}, {T}: Target creature you control gets +2/-2 for as long as
##         this artifact remains tapped.
##
## Implementation: the ability remembers the creature in the Gear's
## card-local memory; a static applies +2/-2 while the Gear stays tapped,
## and with_may_skip_untap keeps it there. Aimed at a Wall it turns a
## blocker into an attacker; aimed at a 2/2 it is removal.
##
## "For as long as this artifact remains tapped" is a DURATION: the moment
## the Gear untaps the effect ends for good and does not come back when
## the Gear is tapped again later (CR 611.2b — a continuous effect whose
## duration has expired never restarts; Manalink's dnuimt_legacy kills the
## legacy the first time it sees its source untapped). So the static that
## first finds the Gear untapped forgets the creature; only a fresh
## activation can hold one again. The forget is journaled so an AI probe
## can undo across it.
##
## "You may choose not to untap" is the controller's call, asked in their
## untap step (MtgGame._untap_step, `@ISLAND_FISH_JASCONIUS`'s two-line
## form: "Untap <name>." / "Don't untap."); the heuristic keeps it tapped
## while it is sustaining something and untaps it otherwise.


func build() -> CardData:
	var spec := TargetSpec.creature("target creature you control")
	spec.with_source_filter(_yours)
	return CardData.new("Ashnod's Battle Gear", "{2}", Mtg.CardType.ARTIFACT) \
		.with_may_skip_untap() \
		.static_ability(StaticAbility.new(
			_apply, "The equipped creature gets +2/-2 while the Gear stays tapped.")) \
		.activated(ActivatedAbility.new(
			"{2}", true, [EquipEffect.new(spec)],
			"{2}, {T}: Target creature you control gets +2/-2 for as long as Ashnod's "
			+ "Battle Gear remains tapped.")) \
		.oracle("You may choose not to untap this artifact during your untap step.\n"
			+ "{2}, {T}: Target creature you control gets +2/-2 for as long as this "
			+ "artifact remains tapped.")


static func _yours(_game: MtgGame, source: CardInstance, inst: CardInstance) -> bool:
	return inst.controller_id == source.controller_id


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if not source.memory.has("holding"):
		return
	if not source.tapped or source.untap_sequence \
			!= int(source.memory.get("holding_untaps", source.untap_sequence)):
		# The duration ran out — untapped, or phased out since (CR 702.26f):
		# the effect is over, not paused (CR 611.2b).
		if game.undo_log != null:
			game.undo_log.record(source, &"memory", source.memory)
		source.memory.erase("holding")
		return
	var held := game.find_instance(int(source.memory["holding"]))
	if held == null or held.zone != Mtg.Zone.BATTLEFIELD \
			or held.layer_timestamp != int(source.memory.get("holding_stamp",
				held.layer_timestamp)):
		# Gone — and a card that comes back is a NEW object (CR 400.7), not
		# the one this effect was given; the id alone survived the trip.
		if game.undo_log != null:
			game.undo_log.record(source, &"memory", source.memory)
		source.memory.erase("holding")
		source.memory.erase("holding_stamp")
		return
	if held.phased_out:
		return   # the duration tracks the Gear; nothing to write meanwhile
	held.cur_power += 2
	held.cur_toughness -= 2


class EquipEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var held := game.find_instance(target.instance_id)
		if held == null or held.zone != Mtg.Zone.BATTLEFIELD:
			return
		source.memory["holding"] = held.id
		source.memory["holding_stamp"] = held.layer_timestamp
		# "Remains tapped" from the activation on: an untap — or the Gear
		# phasing out (CR 702.26f), which moves the same marker — ends it.
		source.memory["holding_untaps"] = int(game.cost_paid("_source_untap_sequence",
			source.untap_sequence))
		game.recalculate()
		game.check_state_based_actions()

	func describe() -> String:
		return "target creature you control gets +2/-2 while this stays tapped"
