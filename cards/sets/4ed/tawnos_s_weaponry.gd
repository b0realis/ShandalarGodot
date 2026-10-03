extends CardScript
## Tawnos's Weaponry — {2} — Artifact — (4ed, uncommon)
## Oracle: You may choose not to untap this artifact during your untap step.
##         {2}, {T}: Target creature gets +1/+1 for as long as this
##         artifact remains tapped.
##
## Implementation: Ashnod's Battle Gear without the drawback and without
## the "you control" clause — the same remembered-target static, applying
## +1/+1 while the Weaponry stays tapped.
##
## "For as long as this artifact remains tapped" is a DURATION: once the
## Weaponry untaps the effect is over and a later tap does not bring it
## back (CR 611.2b; Manalink's dnuimt_legacy kills the legacy the first
## time its source is untapped). The static that first finds the Weaponry
## untapped forgets the creature, journaled for the undo log.
##
## "You may choose not to untap" is the controller's call, asked in their
## untap step (MtgGame._untap_step, `@ISLAND_FISH_JASCONIUS`'s two-line
## form: "Untap <name>." / "Don't untap."); the heuristic keeps it tapped
## while it is sustaining something and untaps it otherwise.


func build() -> CardData:
	return CardData.new("Tawnos's Weaponry", "{2}", Mtg.CardType.ARTIFACT) \
		.with_may_skip_untap() \
		.static_ability(StaticAbility.new(
			_apply, "The equipped creature gets +1/+1 while the Weaponry stays tapped.")) \
		.activated(ActivatedAbility.new(
			"{2}", true, [EquipEffect.new()],
			"{2}, {T}: Target creature gets +1/+1 for as long as Tawnos's Weaponry "
			+ "remains tapped.")) \
		.oracle("You may choose not to untap this artifact during your untap step.\n"
			+ "{2}, {T}: Target creature gets +1/+1 for as long as this artifact "
			+ "remains tapped.")


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
		return   # the duration tracks the Weaponry; nothing to write meanwhile
	held.cur_power += 1
	held.cur_toughness += 1


class EquipEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var held := game.find_instance(target.instance_id)
		if held == null or held.zone != Mtg.Zone.BATTLEFIELD:
			return
		source.memory["holding"] = held.id
		source.memory["holding_stamp"] = held.layer_timestamp
		# "Remains tapped" from the activation on: an untap — or the
		# Weaponry phasing out (CR 702.26f) — ends it.
		source.memory["holding_untaps"] = int(game.cost_paid("_source_untap_sequence",
			source.untap_sequence))
		game.recalculate()

	func describe() -> String:
		return "target creature gets +1/+1 while this stays tapped"
