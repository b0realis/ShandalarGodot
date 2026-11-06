extends CardScript
## Dragon Blood — {3} — Artifact (uncommon, usg).
## Oracle: {3}, {T}: Put a +1/+1 counter on target creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dragon Blood", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("{3}, {T}: Put a +1/+1 counter on target creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
