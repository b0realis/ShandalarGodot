extends CardScript
## Oubliette — {1}{B}{B} — Enchantment — (arn, common)
## Oracle: When this enchantment enters, target creature phases out until
##         this enchantment leaves the battlefield. Tap that creature as it
##         phases in this way. (Auras and Equipment phase out with it.
##         While permanents are phased out, they're treated as though they
##         don't exist.)
##
## Implementation: real PHASING (CR 702.25) — the creature and everything
## attached to it are lifted out of the battlefield arrays, so no query,
## static, trigger or state-based action can see them, and nothing
## triggers on the way out or the way in. The Oubliette remembers its
## prisoner in its own memory.
##
## "UNTIL this enchantment leaves the battlefield" is a DURATION, not a
## trigger: the creature phases back in at the instant the Oubliette
## leaves, with nothing on the stack and no window to respond in. That is
## the immediate leave hook (CardData.as_it_leaves), which hands the
## callback the memory SNAPSHOT taken before the battlefield-state wipe —
## so the creature comes back however the Oubliette goes, destroyed,
## exiled, bounced or anted.
##
## "Target creature" is a real TARGET of the ETB trigger
## (TriggeredAbility.targeting): the Oubliette's controller names it as
## the trigger goes on the stack (CR 603.3d) — a human seat is asked the
## moment a player would receive priority, with the original's own prompt
## (`@OUBLIETTE`, `Program/promptsX1.txt:296`: "Select a creature.") — a
## creature with shroud is not on the list, with no creature at all the
## trigger is removed instead, and the trigger fizzles if the creature has
## left by resolution (CR 608.2b). ANY creature is legal, your own
## included (the printed text does not say "an opponent controls"); the
## list is ranked the opponent's first, biggest first, which is the
## heuristic seat's pick and the human seat's default highlight.


func build() -> CardData:
	return CardData.new("Oubliette", "{1}{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _imprison,
			"When this enchantment enters, target creature phases out until this enchantment leaves the battlefield.",
			_is_self) \
			.targeting(TargetSpec.creature(), _enemy_biggest_first,
				"Select a creature.")) \
		.as_it_leaves(_release) \
		.oracle("When this enchantment enters, target creature phases out until this enchantment leaves the battlefield. Tap that creature as it phases in this way. (Auras and Equipment phase out with it. While permanents are phased out, they're treated as though they don't exist.)")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


## The opponent's creatures before your own, the biggest first.
static func _enemy_biggest_first(game: MtgGame, source: CardInstance,
		a: TargetRef, b: TargetRef) -> bool:
	var ia := game.find_instance(a.instance_id)
	var ib := game.find_instance(b.instance_id)
	var a_enemy := ia.controller_id != source.controller_id
	var b_enemy := ib.controller_id != source.controller_id
	if a_enemy != b_enemy:
		return a_enemy
	var va := ia.cur_power + ia.cur_toughness
	var vb := ib.cur_power + ib.cur_toughness
	if va != vb:
		return va > vb
	return ia.id < ib.id


static func _imprison(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var refs: Array = game.current_targets()
	if refs.is_empty():
		return
	var prisoner := game.find_instance(refs[0].instance_id)
	if prisoner == null or prisoner.zone != Mtg.Zone.BATTLEFIELD:
		return
	source.memory["prisoner"] = prisoner.id
	game.phase_out(prisoner)


static func _release(game: MtgGame, _source: CardInstance, _controller: int,
		parting: Dictionary) -> void:
	var prisoner := game.find_instance(int(parting.get("prisoner", -1)))
	if prisoner != null and prisoner.phased_out:
		game.phase_in(prisoner, true)
