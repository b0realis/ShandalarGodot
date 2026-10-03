extends CardScript
## Ashes to Ashes — {1}{B}{B} — Sorcery — (4ed, uncommon)
## Oracle: Exile two target nonartifact creatures. Ashes to Ashes deals
##         5 damage to you.
##
## Implementation: ONE ExileEffect taking exactly two targets plus a
## self-aimed DamageEffect. "Two target" is one instance of the word, so
## the two must differ (CR 601.2c) — and since 2026-10-03 the engine checks
## that per instance, not across the whole spell, which is why this is no
## longer two one-target ExileEffects. Exile beats
## destruction: no regeneration, no dies-triggers, no Animate Dead later.
## The 5 damage is DAMAGE, not life loss — a Circle of Protection: Black
## can eat it, exactly as 1997 tables discovered.


func build() -> CardData:
	var exile := ExileEffect.new(TargetSpec.creature(
		"target nonartifact creature", _nonartifact))
	exile.target_min = 2
	exile.target_max = 2
	return CardData.new("Ashes to Ashes", "{1}{B}{B}", Mtg.CardType.SORCERY) \
		.spell(exile) \
		.spell(DamageEffect.new(5).to_controller()) \
		.oracle("Exile two target nonartifact creatures. Ashes to Ashes deals 5 damage to you.")


static func _nonartifact(inst: CardInstance) -> bool:
	return not inst.is_type(Mtg.CardType.ARTIFACT)
