extends CardScript
## Psionic Entity — {4}{U} — Creature — Illusion — 2/2 — (4ed, rare)
## Oracle: {T}: This creature deals 2 damage to any target and 3 damage to
##         itself.
##
## Implementation: a free tap ability with a suicidal rider — the 3 self
## damage kills the 2/2 outright unless something has pumped its
## toughness first. Modeled as two effects: the targeted DamageEffect and
## a card-local self-hit.


func build() -> CardData:
	return CardData.new("Psionic Entity", "{4}{U}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["illusion"]) \
		.activated(ActivatedAbility.new(
			"", true,
			[DamageEffect.new(2).any_target(), SelfHarmEffect.new()],
			"{T}: Psionic Entity deals 2 damage to any target and 3 damage to itself.")) \
		.oracle("{T}: This creature deals 2 damage to any target and 3 damage to itself.")


class SelfHarmEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source.zone == Mtg.Zone.BATTLEFIELD:
			game.deal_damage(source, TargetRef.card(source), 3)

	func describe() -> String:
		return "deals 3 damage to itself"
