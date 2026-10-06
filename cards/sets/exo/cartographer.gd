extends CardScript
## Cartographer — {2}{G} — Creature — Human (uncommon, exo).
## Oracle: When this creature enters, you may return target land card from your graveyard to your hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cartographer", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human"])
	c.oracle("When this creature enters, you may return target land card from your graveyard to your hand.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
