extends CardScript
## Goblin Wizard — {2}{R}{R} — Creature — Goblin Wizard — 1/1 — (drk, rare)
## Oracle: {T}: You may put a Goblin permanent card from your hand onto the
##         battlefield.
##         {R}: Target Goblin gains protection from white until end of turn.
##
## Implementation: the cheat-in is MtgGame.put_from_hand_into_play (the same
## door Eureka uses), so what arrives enters properly — ETB triggers fire,
## it is summoning-sick, and a Goblin Artisans put in this way still cannot
## tap the turn it lands.
##
## "Goblin PERMANENT card" is wider than "Goblin creature": the pool has
## Goblin artifacts (Goblin Bomb is an enchantment), and the filter reads
## the printed subtype list on a card in HAND, where there are no live
## characteristics to read.
##
## The protection grant is until END OF TURN
## (ContinuousEffects.add_until_eot_protection, new) rather than the
## durationless CardInstance.added_protection a Rainbow Knights carries —
## the pipeline applies both in CR 613 layer 6.
##
## Protection from white on a Goblin is the printed answer to Swords to
## Plowshares and to a white blocker, and it is why this Wizard is the
## Goblin deck's rare.


func build() -> CardData:
	return CardData.new("Goblin Wizard", "{2}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["goblin", "wizard"]) \
		.activated(ActivatedAbility.new("", true, [SummonEffect.new()],
			"{T}: You may put a Goblin permanent card from your hand onto the battlefield.")) \
		.activated(ActivatedAbility.new("{R}", false, [WardEffect.new()],
			"{R}: Target Goblin gains protection from white until end of turn.")) \
		.oracle("{T}: You may put a Goblin permanent card from your hand onto the "
			+ "battlefield.\n{R}: Target Goblin gains protection from white until "
			+ "end of turn.")


class SummonEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var candidates: Array[CardInstance] = []
		for card in game.players[controller].hand:
			# A card in hand has no live characteristics — the printed
			# subtypes are all there is to read.
			if card.data.is_permanent_type() \
					and card.data.subtypes.has("goblin"):
				candidates.append(card)
		if candidates.is_empty():
			return
		if not game.agents[controller].choose_yes_no(game, controller,
				"Put a Goblin onto the battlefield?", true):
			return
		candidates.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			return a.data.cost.mana_value() > b.data.cost.mana_value())
		var pick := game.agents[controller].choose_card(game, controller,
			candidates, "Choose a Goblin to put onto the battlefield")
		if pick == null or not candidates.has(pick):
			pick = candidates[0]
		game.put_from_hand_into_play(pick, controller)

	func describe() -> String:
		return "puts a Goblin from your hand onto the battlefield"


class WardEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature("target Goblin", WardEffect._is_goblin)

	static func _is_goblin(inst: CardInstance) -> bool:
		return inst.has_subtype("goblin")

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var goblin := game.find_instance(target.instance_id)
		if goblin == null or goblin.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.continuous.add_until_eot_protection(goblin.id, Mtg.ManaColor.W)
		game.recalculate()

	func describe() -> String:
		return "target Goblin gains protection from white until end of turn"
