extends CardScript
## Transmute Artifact — {U}{U} — Sorcery — (atq, uncommon)
## Oracle: Sacrifice an artifact. If you do, search your library for an
##         artifact card. If that card's mana value is less than or equal
##         to the sacrificed artifact's mana value, put it onto the
##         battlefield. If it's greater, you may pay {X}, where X is the
##         difference. If you do, put it onto the battlefield. If you
##         don't, put it into its owner's graveyard. Then shuffle.
##
## Implementation: the sacrifice is part of the RESOLUTION, not an
## additional cost — the printed line sits in the rules text, not in the
## cost line (CR 601.2h lists what an additional cost is), so the spell can
## be cast with no artifact at all and a countered Transmute Artifact eats
## nothing. The search then runs through the engine's normal
## library-search path, the difference is paid through the
## triggered-payment route — floating mana first, then auto-tapped lands —
## and a refusal really does bury the card.
##
## The choice on resolution is the acting seat's own, asked through their
## DecisionAgent: a human seat is held open on it (docs/duel-todo.md
## §1.3) and every other seat answers for itself. The value the card
## computes is only the HINT, and the candidates are pre-sorted for it.


static func _any_artifact(inst: CardInstance) -> bool:
	return inst.data.is_type(Mtg.CardType.ARTIFACT)


func build() -> CardData:
	return CardData.new("Transmute Artifact", "{U}{U}", Mtg.CardType.SORCERY) \
		.spell(TransmuteEffect.new(_any_artifact)) \
		.oracle("Sacrifice an artifact. If you do, search your library for an artifact card. If that card's mana value is less than or equal to the sacrificed artifact's mana value, put it onto the battlefield. If it's greater, you may pay {X}, where X is the difference. If you do, put it onto the battlefield. If you don't, put it into its owner's graveyard. Then shuffle.")


class TransmuteEffect extends EffectBase:
	var artifact_filter: Callable

	func _init(filter: Callable) -> void:
		artifact_filter = filter

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		# "Sacrifice an artifact. If you do, ..." — on resolution.
		var bodies: Array[CardInstance] = []
		for perm in game.players[controller].battlefield:
			if artifact_filter.call(perm):
				bodies.append(perm)
		if bodies.is_empty():
			game.log_line("Transmute Artifact has no artifact to sacrifice")
			return   # "if you do" never happens; the spell does nothing else
		bodies.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			return a.data.cost.mana_value() < b.data.cost.mana_value())
		var eaten: CardInstance = game.agents[controller].choose_card(
			game, controller, bodies, "Sacrifice an artifact")
		if eaten == null or not bodies.has(eaten):
			eaten = bodies[0]
		var paid: int = eaten.data.cost.mana_value()
		game.sacrifice_permanent(eaten)
		var found := game.pick_from_library(controller, artifact_filter,
			"Search for an artifact card")
		if found == null:
			return
		var gap: int = found.data.cost.mana_value() - paid
		if gap <= 0:
			game.put_into_play(found, controller)
			return
		var toll := ManaCost.parse("{%d}" % gap)
		if game.can_afford_cost(controller, toll) \
				and game.agents[controller].choose_yes_no(game, controller,
					"Pay {%d} to keep %s?" % [gap, found.data.card_name], true) \
				and game.try_pay(controller, toll):
			game.put_into_play(found, controller)
			return
		game.put_into_graveyard(found)

	func describe() -> String:
		return "trades an artifact for one from your library"
