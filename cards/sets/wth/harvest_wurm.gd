extends CardScript
## Harvest Wurm — {1}{G} — Creature — Wurm (common, wth).
## Oracle: When this creature enters, sacrifice it unless you return a basic land card from your graveyard to your hand.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Harvest Wurm", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["wurm"])
	c.oracle("When this creature enters, sacrifice it unless you return a basic land card from your graveyard to your hand.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
