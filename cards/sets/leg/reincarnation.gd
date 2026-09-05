extends CardScript
## Reincarnation — {1}{G}{G} — Instant — (leg, uncommon)
## Oracle: Choose target creature. When that creature dies this turn, return
##         a creature card from its owner's graveyard to the battlefield
##         under the control of that creature's owner.
##
## Implementation: a DELAYED dies-trigger, which the engine now has as a
## floating watch (MtgGame.watch_death, new) rather than as a stack object
## (docs/ROADMAP.md still owes the real CR 603.7a version). The watch
## outlives Reincarnation itself, fires once, and is dropped at cleanup if
## the creature never dies.
##
## Whose graveyard and whose creature: BOTH are the dying creature's OWNER,
## not the caster. Cast on your opponent's creature it hands THEM something
## back, so the card is a rescue for your own board or a way to upgrade a
## dying body of theirs into the best thing in their yard — read the second
## sentence twice before pointing it.
##
## The returned card is chosen by that owner (they are the one being paid),
## and the heuristic offers the biggest body first. The creature that just
## died is already in the graveyard by then, so it may return itself, which
## is the printed behaviour and the usual line.


func build() -> CardData:
	return CardData.new("Reincarnation", "{1}{G}{G}", Mtg.CardType.INSTANT) \
		.spell(MarkEffect.new()) \
		.oracle("Choose target creature. When that creature dies this turn, return "
			+ "a creature card from its owner's graveyard to the battlefield under "
			+ "the control of that creature's owner.")


class MarkEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var doomed := game.find_instance(target.instance_id)
		if doomed == null or doomed.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.watch_death(doomed, MarkEffect._reincarnate)
		game.log_line("%s is marked for reincarnation" % doomed.data.card_name)

	static func _reincarnate(game: MtgGame, dead: CardInstance) -> void:
		var owner := dead.owner_id
		var candidates: Array[CardInstance] = []
		for card in game.players[owner].graveyard:
			if card.data.is_creature():
				candidates.append(card)
		if candidates.is_empty():
			return
		candidates.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			return a.data.cost.mana_value() > b.data.cost.mana_value())
		var pick := game.agents[owner].choose_card(game, owner, candidates,
			"Return a creature card to the battlefield")
		if pick == null or not candidates.has(pick):
			pick = candidates[0]
		game.reanimate(pick, owner)

	func describe() -> String:
		return "when the target dies this turn, its owner raises a creature"
