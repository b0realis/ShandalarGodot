extends CardScript
## Sword of the Chosen — {2} — Legendary Artifact (rare, sth).
## Oracle: {T}: Target legendary creature gets +2/+2 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sword of the Chosen", "{2}", Mtg.CardType.ARTIFACT)
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("{T}: Target legendary creature gets +2/+2 until end of turn.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
