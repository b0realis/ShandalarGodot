extends CardScript
## Ashes to Ashes — {1}{B}{B} — Sorcery — (4ed, uncommon)
## Oracle: Exile two target nonartifact creatures. Ashes to Ashes deals
##         5 damage to you.
##
## Implementation: two ExileEffects (one target slot each — the caster
## picks two creatures) plus a self-aimed DamageEffect. Exile beats
## destruction: no regeneration, no dies-triggers, no Animate Dead later.
## The 5 damage is DAMAGE, not life loss — a Circle of Protection: Black
## can eat it, exactly as 1997 tables discovered.


func build() -> CardData:
	return CardData.new("Ashes to Ashes", "{1}{B}{B}", Mtg.CardType.SORCERY) \
		.spell(ExileEffect.new(TargetSpec.creature(
			"target nonartifact creature", _nonartifact))) \
		.spell(ExileEffect.new(TargetSpec.creature(
			"target nonartifact creature", _nonartifact))) \
		.spell(DamageEffect.new(5).to_controller()) \
		.oracle("Exile two target nonartifact creatures. Ashes to Ashes deals 5 damage to you.")


static func _nonartifact(inst: CardInstance) -> bool:
	return not inst.is_type(Mtg.CardType.ARTIFACT)
