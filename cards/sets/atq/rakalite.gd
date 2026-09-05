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
## records that it is already booked.
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
		game.schedule_end_step_action(func() -> void:
			var inst := game.find_instance(id)
			if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD:
				inst.memory.erase("bounce_booked")
				game.return_to_hand(inst))

	func describe() -> String:
		return "returns Rakalite to its owner's hand at the next end step"
