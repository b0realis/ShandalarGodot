extends CardScript
## Junk Diver — {3} — Artifact Creature — Bird (rare, uds).
## Oracle: Flying
##         When this creature dies, return another target artifact card from your graveyard to your hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Junk Diver", "{3}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(1, 1)
	c.with_subtypes(["bird"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature dies, return another target artifact card from your graveyard to your hand.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
