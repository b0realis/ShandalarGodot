extends CardScript
## Treasure Hunter — {2}{W} — Creature — Human (uncommon, exo).
## Oracle: When this creature enters, you may return target artifact card from your graveyard to your hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Treasure Hunter", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human"])
	c.oracle("When this creature enters, you may return target artifact card from your graveyard to your hand.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
