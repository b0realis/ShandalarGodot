extends CardScript
## Dark Heart of the Wood — {B}{G} — Enchantment — (drk, common)
## Oracle: Sacrifice a Forest: You gain 3 life.
##
## Implementation: the sacrifice-ANOTHER-permanent cost
## (with_sacrifice_of) — the activating player's agent picks which Forest
## feeds the heart; no mana, no tap, repeatable while forests last.


func build() -> CardData:
	return CardData.new("Dark Heart of the Wood", "{B}{G}", Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new(
			"", false,
			[GainLifeEffect.new(3)],
			"Sacrifice a Forest: You gain 3 life.").with_sacrifice_of("Forest", _is_forest)) \
		.oracle("Sacrifice a Forest: You gain 3 life.")


static func _is_forest(inst: CardInstance) -> bool:
	return inst.is_land() and inst.has_subtype("forest")
