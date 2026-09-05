extends CardScript
## Relic Barrier — {2} — Artifact — (leg, uncommon)
## Oracle: {T}: Tap target artifact.
##
## Implementation: a repeatable TapEffect filtered to artifacts. Two mana
## to shut off one artifact a turn — and, aimed at an opposing mana rock
## before its controller's main phase, a genuine tax. Artifacts have no
## summoning sickness for {T} abilities (CR 302.6), so it works the turn
## it lands.


func build() -> CardData:
	return CardData.new("Relic Barrier", "{2}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"", true,
			[TapEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
				"target artifact", _is_artifact))],
			"{T}: Tap target artifact.")) \
		.oracle("{T}: Tap target artifact.")


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)
