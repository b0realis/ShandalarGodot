extends CardScript
## Rootwater Diver — {U} — Creature — Merfolk (uncommon, tmp).
## Oracle: {T}, Sacrifice this creature: Return target artifact card from your graveyard to your hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rootwater Diver", "{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["merfolk"])
	c.oracle("{T}, Sacrifice this creature: Return target artifact card from your graveyard to your hand.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
