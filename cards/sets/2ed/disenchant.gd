extends CardScript
## Disenchant — {1}{W} — Instant (2ed, common)
## Oracle: Destroy target artifact or enchantment.
##
## Implementation: DestroyEffect with a PERMANENT spec filtered to
## artifact-or-enchantment. Kills auras too (they're enchantments on the
## battlefield) — the pool's universal answer card.


func build() -> CardData:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target artifact or enchantment", _valid_target)
	return CardData.new("Disenchant", "{1}{W}", Mtg.CardType.INSTANT) \
		.spell(DestroyEffect.new(spec)) \
		.oracle("Destroy target artifact or enchantment.")


static func _valid_target(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT) \
		or inst.is_type(Mtg.CardType.ENCHANTMENT)
