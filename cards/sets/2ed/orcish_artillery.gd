extends CardScript
## Orcish Artillery — {1}{R}{R} — Creature — Orc Warrior — 1/3 (2ed, uncommon)
## Oracle: {T}: Orcish Artillery deals 2 damage to any target and 3 damage
##         to you.
##
## Implementation: card-local effect — one activation, two damage packets
## (2 to the chosen target, 3 to the CONTROLLER, both real damage from a
## red source, so a Circle of Protection: Red can eat the self-hit — a
## classic original-game trick worth preserving).


func build() -> CardData:
	return CardData.new("Orcish Artillery", "{1}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(1, 3) \
		.with_subtypes(["orc", "warrior"]) \
		.activated(ActivatedAbility.new(
			"", true,
			[ArtilleryEffect.new()],
			"{T}: Orcish Artillery deals 2 damage to any target and 3 damage to you.")) \
		.oracle("{T}: Orcish Artillery deals 2 damage to any target and 3 damage to you.")


class ArtilleryEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.any_target()

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		game.deal_damage(source, target, 2)
		game.deal_damage(source, TargetRef.player(controller), 3)

	func describe() -> String:
		return "deals 2 damage to any target and 3 damage to you"
