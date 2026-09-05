extends CardScript
## Metamorphosis — {G} — Sorcery — (arn, common)
## Oracle: As an additional cost to cast this spell, sacrifice a creature.
##         Add X mana of any one color, where X is 1 plus the sacrificed
##         creature's mana value. Spend this mana only to cast creature
##         spells.
##
## Implementation: the sacrifice is an additional COST, paid before the
## spell goes on the stack; the mana it makes is restricted to creature
## spells (CR 106.6) and floats until the step ends like any other mana.
##
## The choice on resolution is the acting seat's own, asked through their
## DecisionAgent: a human seat is held open on it (docs/duel-todo.md
## §1.3) and every other seat answers for itself. The value the card
## computes is only the HINT, and the candidates are pre-sorted for it.


static func _any_creature(inst: CardInstance) -> bool:
	return inst.is_creature()


func build() -> CardData:
	return CardData.new("Metamorphosis", "{G}", Mtg.CardType.SORCERY) \
		.with_additional_sacrifice("creature", _any_creature) \
		.spell(MetamorphosisEffect.new()) \
		.oracle("As an additional cost to cast this spell, sacrifice a creature.\nAdd X mana of any one color, where X is 1 plus the sacrificed creature's mana value. Spend this mana only to cast creature spells.")


class MetamorphosisEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var paid := int(source.memory.get("sacrificed_mv", 0))
		var amount := 1 + paid
		var hint := MetamorphosisEffect._most_needed_color(game, controller)
		var color: int = game.agents[controller].choose_color(game, controller,
			"Choose a color for Metamorphosis' mana", hint)
		game.players[controller].mana_pool.add_restricted(color, amount, "creature")
		game.log_line("Metamorphosis adds %d %s (creature spells only)" % [
			amount, String(Mtg.COLOR_NAMES[color]).to_lower()])

	## The colour the caster's hand of creatures needs most.
	static func _most_needed_color(game: MtgGame, pid: int) -> int:
		var counts := {}
		for card in game.players[pid].hand:
			if not card.data.is_creature():
				continue
			for c in card.data.cost.colored:
				counts[c] = int(counts.get(c, 0)) + int(card.data.cost.colored[c])
		var best: int = Mtg.ManaColor.G
		var best_count := 0
		for c in Mtg.WUBRG:
			if int(counts.get(c, 0)) > best_count:
				best_count = int(counts.get(c, 0))
				best = c
		return best

	func describe() -> String:
		return "adds X mana of one colour, spendable only on creature spells"
