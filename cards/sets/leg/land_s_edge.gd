extends CardScript
## Land's Edge — {1}{R}{R} — World Enchantment — (leg, rare)
## Oracle: Discard a card: If the discarded card was a land card, this
##         enchantment deals 2 damage to target player or planeswalker. Any
##         player may activate this ability.
##
## Implementation: a chosen-discard COST
## (ActivatedAbility.with_discard_cost, new) — the card goes as the ability
## is activated, whatever it turns out to be, which is what makes Land's
## Edge a real gamble rather than a free filter. What was discarded is left
## on THIS ACTIVATION's stack item by the engine (`StackItem.cost_paid`,
## key `_discarded_types`), read back through `MtgGame.cost_paid` when the
## ability resolves — per activation, because "any player may activate"
## plus a mana-free cost means two of them waiting at once is the ordinary
## case here, and a record on the enchantment would have them read each
## other's discard.
##
## "Any player may activate this ability" is
## ActivatedAbility.anyone_activated, and it is why this is a World
## Enchantment worth killing: the opponent can burn you with your own card.
##
## The damage source is the enchantment (its controller's colours matter for
## a Circle of Protection), but the ACTIVATOR chooses the target — which the
## engine already does, since targets are chosen by whoever activates.


func build() -> CardData:
	return CardData.new("Land's Edge", "{1}{R}{R}", Mtg.CardType.ENCHANTMENT) \
		.with_supertypes(Mtg.Supertype.WORLD) \
		.activated(ActivatedAbility.new("", false, [EdgeEffect.new()],
			"Discard a card: If the discarded card was a land card, this enchantment deals 2 damage to target player.") \
			.with_discard_cost(1).anyone_activated()) \
		.oracle("Discard a card: If the discarded card was a land card, this "
			+ "enchantment deals 2 damage to target player or planeswalker. Any "
			+ "player may activate this ability.")


class EdgeEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		if source == null:
			return
		# On the activation, not on the enchantment: any player may
		# activate this for free, so two activations on the stack at once
		# is the normal case here, not the corner one. Nothing to erase
		# afterwards either — the record dies with the stack item.
		var types := int(game.cost_paid("_discarded_types", 0))
		if (types & Mtg.CardType.LAND) == 0:
			game.log_line("Land's Edge: the discard was no land")
			return
		game.deal_damage(source, target, 2)

	func describe() -> String:
		return "2 damage to target player if the discarded card was a land"
