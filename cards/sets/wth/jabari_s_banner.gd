extends CardScript
## Jabari's Banner — {2} — Artifact (uncommon, wth).
## Oracle: {1}, {T}: Target creature gains flanking until end of turn. (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Jabari's Banner", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("{1}, {T}: Target creature gains flanking until end of turn. (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
