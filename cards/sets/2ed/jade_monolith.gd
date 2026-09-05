extends CardScript
## Jade Monolith — {4} — Artifact — (2ed, rare)
## Oracle: {1}: The next time a source of your choice would deal damage to
##         target creature this turn, that source deals that damage to you
##         instead.
##
## Implementation: a one-shot redirection stored on the creature
## (CardInstance.damage_redirect_to / damage_redirects, cleared at cleanup).
## The activator takes the blow — including for an OPPONENT's creature,
## which is exactly the Monolith's famous use with a regenerating wall.
##
## "A source of your choice": the activator names ONE source as the
## ability resolves (DecisionAgent.choose_card over
## MtgGame.damage_sources, ranked so the first entry is the one about to
## deal damage to the creature — a spell on the stack aimed at it, the
## creature it is fighting in combat), and the redirection
## (CardInstance.damage_redirect_sources) fires only for that source.
## `@JADE_MONOLITH` (Program/prompts.txt:499) is the original's line for
## the creature: "Select target creature."


func build() -> CardData:
	return CardData.new("Jade Monolith", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{1}", false, [MonolithEffect.new()],
			"{1}: The next time a source of your choice would deal damage to target creature this turn, that source deals that damage to you instead.")) \
		.oracle("{1}: The next time a source of your choice would deal damage to target creature this turn, that source deals that damage to you instead.")


class MonolithEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var shielded := game.find_instance(target.instance_id)
		if shielded == null or shielded.zone != Mtg.Zone.BATTLEFIELD:
			return
		var choices := game.damage_sources(Callable(), target)
		if choices.is_empty():
			return
		var named := game.agents[controller].choose_card(game, controller,
			choices, "Jade Monolith: Select a source of damage to %s."
				% shielded.data.card_name, false, false, true)
		if named == null or not choices.has(named):
			named = choices[0]
		shielded.damage_redirect_to = controller
		shielded.damage_redirects += 1
		shielded.damage_redirect_sources.append(named.id)
		game.log_line("Jade Monolith turns %s's damage to %s onto %s" % [
			named.data.card_name, shielded.data.card_name,
			game.players[controller].player_name])

	func describe() -> String:
		return "the next damage to target creature is dealt to you instead"
