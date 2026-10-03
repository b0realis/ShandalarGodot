extends CardScript
## Rakalite — {6} — Artifact — (atq, uncommon)
## Oracle: {2}: Prevent the next 1 damage that would be dealt to any target
##         this turn. Return this artifact to its owner's hand at the
##         beginning of the next end step.
##
## Implementation: the prevention is the engine's ordinary amount-based pool
## (PreventDamageEffect), so it stacks with itself — six mana buys three
## points across three activations, all of which come off the same pool.
##
## The bounce is a DELAYED action that outlives its source
## (MtgGame.schedule_end_step_action, new): Rakalite goes home even if it is
## no longer the same object's business to send it, and a Rakalite that has
## already left the battlefield when the end step comes is simply not there
## to return. Only one bounce is scheduled per turn however many times it is
## activated — "the next end step" is one moment, and card-local memory
## records that it is already booked. The action holds the game WEAKLY and
## names the activated object by id AND battlefield timestamp (bug pass
## 2026-10-03: a strong capture leaked every duel that ended with the bounce
## pending, and a Rakalite replayed before the end step was sent home by
## its previous life's booking).
##
## `@RAKALITE`, `Program/promptsX1.txt:333`, is `Select a damaged card.`,
## which is how the original asked for the target.


func build() -> CardData:
	return CardData.new("Rakalite", "{6}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{2}", false, [
				PreventDamageEffect.new(1).any_target(), BounceEffect.new()],
			"{2}: Prevent the next 1 damage that would be dealt to any target this turn. Return this artifact to its owner's hand at the beginning of the next end step.")) \
		.oracle("{2}: Prevent the next 1 damage that would be dealt to any target "
			+ "this turn. Return this artifact to its owner's hand at the beginning "
			+ "of the next end step.")


class BounceEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source == null or source.zone != Mtg.Zone.BATTLEFIELD:
			return
		if bool(source.memory.get("bounce_booked", false)):
			return   # "the NEXT end step" is one moment, however many times
		source.memory["bounce_booked"] = true
		var id := source.id
		var stamp := source.layer_timestamp
		# WEAKLY, as Mana Drain does (bug pass 2026-10-03): the action lives
		# in the game's own pool, so a lambda holding `game` is a reference
		# cycle, and a duel that ended with the bounce still pending leaked
		# the whole game at exit. The stamp is CR 400.7: "this artifact" is
		# the object that was activated, not a Rakalite bounced and replayed
		# before the end step.
		var weak: WeakRef = weakref(game)
		game.schedule_end_step_action(func() -> void:
			var g: MtgGame = weak.get_ref()
			if g == null:
				return
			var inst := g.find_instance(id)
			if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD \
					and inst.layer_timestamp == stamp:
				inst.memory.erase("bounce_booked")
				g.return_to_hand(inst))

	func describe() -> String:
		return "returns Rakalite to its owner's hand at the next end step"
