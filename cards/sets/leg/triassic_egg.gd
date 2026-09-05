extends CardScript
## Triassic Egg — {4} — Artifact — (leg, rare)
## Oracle: {3}, {T}: Put a hatchling counter on this artifact.
##         Sacrifice this artifact: Choose one. Activate only if there are
##         two or more hatchling counters on this artifact.
##         • You may put a creature card from your hand onto the battlefield.
##         • Return target creature card from your graveyard to the
##           battlefield.
##
## Implementation: the modal half is two separate abilities, both gated on
## the two-counter clause — activated abilities have no modes in this
## engine, and two abilities read the same in a menu.
##
## The choice on resolution is the acting seat's own, asked through their
## DecisionAgent: a human seat is held open on it (docs/duel-todo.md
## §1.3) and every other seat answers for itself. The value the card
## computes is only the HINT, and the candidates are pre-sorted for it.
##
## The "you MAY" is honoured too: a seat that declines puts nothing down.


static func _is_creature_card(inst: CardInstance) -> bool:
	return inst.data.is_creature()


static func _has_two_hatchlings(_game: MtgGame, source: CardInstance) -> String:
	if int(source.counters.get("hatchling", 0)) < 2:
		return "activate only with two or more hatchling counters"
	return ""


func build() -> CardData:
	return CardData.new("Triassic Egg", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{3}", true, [IncubateEffect.new()],
			"{3}, {T}: Put a hatchling counter on this artifact.")) \
		.activated(ActivatedAbility.new("", false, [HatchFromHandEffect.new(_is_creature_card)],
			"Sacrifice this artifact: You may put a creature card from your hand onto the battlefield.") \
			.with_sacrifice_cost().only_if(_has_two_hatchlings)) \
		.activated(ActivatedAbility.new("", false,
			[HatchFromGraveEffect.new(TargetSpec.new(
				TargetSpec.Kind.CREATURE_IN_YOUR_GRAVEYARD))],
			"Sacrifice this artifact: Return target creature card from your graveyard to the battlefield.") \
			.with_sacrifice_cost().only_if(_has_two_hatchlings)) \
		.oracle("{3}, {T}: Put a hatchling counter on this artifact.\nSacrifice this artifact: Choose one. Activate only if there are two or more hatchling counters on this artifact.\n• You may put a creature card from your hand onto the battlefield.\n• Return target creature card from your graveyard to the battlefield.")


class IncubateEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source != null and source.zone == Mtg.Zone.BATTLEFIELD:
			game.add_counters(source, "hatchling", 1)

	func describe() -> String:
		return "puts a hatchling counter on this artifact"


class HatchFromHandEffect extends EffectBase:
	var creature_filter: Callable

	func _init(filter: Callable) -> void:
		creature_filter = filter

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var candidates: Array[CardInstance] = []
		for card in game.players[controller].hand:
			if creature_filter.call(card):
				candidates.append(card)
		if candidates.is_empty():
			return
		candidates.sort_custom(HatchFromHandEffect._bigger_first)
		var chosen := game.agents[controller].choose_card(game, controller,
			candidates, "You may put a creature card onto the battlefield")
		# "You MAY put ..." — a declined choice (a null pick) is a legal
		# answer and the ability simply does nothing (CR 608.2).
		if chosen == null or not candidates.has(chosen):
			return
		game.put_from_hand_into_play(chosen, controller)

	static func _bigger_first(a: CardInstance, b: CardInstance) -> bool:
		return a.data.power + a.data.toughness > b.data.power + b.data.toughness

	func describe() -> String:
		return "puts a creature card from your hand onto the battlefield"


class HatchFromGraveEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var dead := game.find_instance(target.instance_id)
		if dead != null and dead.zone == Mtg.Zone.GRAVEYARD:
			game.reanimate(dead, controller)

	func describe() -> String:
		return "returns target creature card from your graveyard to the battlefield"
