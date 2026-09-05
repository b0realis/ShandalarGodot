extends CardScript
## Grave Robbers — {1}{B}{B} — Creature — Human Rogue — 1/1 — (drk, rare)
## Oracle: {B}, {T}: Exile target artifact card from a graveyard. You
##         gain 2 life.
##
## Implementation: graveyard-hate on legs — a CARD_IN_ANY_GRAVEYARD
## target filtered to artifacts, exiled via exile_from_graveyard, plus
## the 2-life fee. Works on either player's graveyard.


func build() -> CardData:
	return CardData.new("Grave Robbers", "{1}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "rogue"]) \
		.activated(ActivatedAbility.new(
			"{B}", true,
			[RobberyEffect.new(), GainLifeEffect.new(2)],
			"{B}, {T}: Exile target artifact card from a graveyard. You gain 2 life.")) \
		.oracle("{B}, {T}: Exile target artifact card from a graveyard. You gain 2 life.")


class RobberyEffect extends EffectBase:
	static func _is_artifact(inst: CardInstance) -> bool:
		return inst.data.is_type(Mtg.CardType.ARTIFACT)

	func _init() -> void:
		target_spec = TargetSpec.new(TargetSpec.Kind.CARD_IN_ANY_GRAVEYARD,
			"target artifact card in a graveyard", RobberyEffect._is_artifact)

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst != null:
			game.exile_from_graveyard(inst)

	func describe() -> String:
		return "exiles target artifact card from a graveyard"
