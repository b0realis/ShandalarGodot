extends CardScript
## Cursed Totem — {2} — Artifact (rare, mir).
## Oracle: Activated abilities of creatures can't be activated.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cursed Totem", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("Activated abilities of creatures can't be activated.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
