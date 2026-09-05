extends CardScript
## Wyluli Wolf — {1}{G} — Creature — Wolf — 1/1 — (arn, common)
## Oracle: {T}: Target creature gets +1/+1 until end of turn.
##
## Implementation: tap-to-pump utility — a targeted +1/+1 PumpEffect,
## usable on itself too (abilities may target their own source).


func build() -> CardData:
	var pump := PumpEffect.new(1, 1)
	pump.target_spec = TargetSpec.creature()
	return CardData.new("Wyluli Wolf", "{1}{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["wolf"]) \
		.activated(ActivatedAbility.new(
			"", true,
			[pump],
			"{T}: Target creature gets +1/+1 until end of turn.")) \
		.oracle("{T}: Target creature gets +1/+1 until end of turn.")
