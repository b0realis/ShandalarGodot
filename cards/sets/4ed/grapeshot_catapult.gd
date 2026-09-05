extends CardScript
## Grapeshot Catapult — {4} — Artifact Creature — Construct — 2/3 — (4ed, common)
## Oracle: {T}: This creature deals 1 damage to target creature with flying.
##
## Implementation: anti-air artillery — a tap-ping restricted to flyers
## (live keyword filter). mage-go: DealDamage(1) + Tap + flying target.


func build() -> CardData:
	return CardData.new("Grapeshot Catapult", "{4}",
			Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(2, 3) \
		.with_subtypes(["construct"]) \
		.activated(ActivatedAbility.new(
			"", true,
			[DamageEffect.new(1).target_creature(
				"target creature with flying", _has_flying)],
			"{T}: This creature deals 1 damage to target creature with flying.")) \
		.oracle("{T}: This creature deals 1 damage to target creature with flying.")


static func _has_flying(inst: CardInstance) -> bool:
	return inst.has_keyword(Mtg.Keyword.FLYING)
