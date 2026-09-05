extends CardScript
## Steal Artifact — {2}{U}{U} — Enchantment — Aura — (2ed, uncommon)
## Oracle: Enchant artifact
##         You control enchanted artifact.
##
## Implementation: the engine's control-stealing aura flag
## (CardData.steals_control, Control Magic's mechanism) pointed at an
## artifact instead of a creature — control moves on attach and reverts
## to the owner when the aura leaves, both handled in MtgGame.


func build() -> CardData:
	return CardData.new("Steal Artifact", "{2}{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact", _is_artifact)) \
		.steals_control() \
		.oracle("Enchant artifact\nYou control enchanted artifact.")


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)
