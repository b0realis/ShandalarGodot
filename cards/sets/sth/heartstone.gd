extends CardScript
## Heartstone — {3} — Artifact (uncommon, sth).
## Oracle: Activated abilities of creatures cost {1} less to activate. This effect can't reduce the mana in that cost to less than one mana.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Heartstone", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("Activated abilities of creatures cost {1} less to activate. This effect can't reduce the mana in that cost to less than one mana.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
