extends CardScript
## Tin-Wing Chimera — {4} — Artifact Creature — Chimera (uncommon, vis).
## Oracle: Flying
##         Sacrifice this creature: Put a +2/+2 counter on target Chimera creature. It gains flying. (This effect lasts indefinitely.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tin-Wing Chimera", "{4}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(2, 2)
	c.with_subtypes(["chimera"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nSacrifice this creature: Put a +2/+2 counter on target Chimera creature. It gains flying. (This effect lasts indefinitely.)")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
