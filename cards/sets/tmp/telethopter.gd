extends CardScript
## Telethopter — {4} — Artifact Creature — Thopter (uncommon, tmp).
## Oracle: Tap an untapped creature you control: This creature gains flying until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Telethopter", "{4}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(3, 1)
	c.with_subtypes(["thopter"])
	c.oracle("Tap an untapped creature you control: This creature gains flying until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
