extends CardScript
## Tragic Poet — {W} — Creature — Human (common, ulg).
## Oracle: {T}, Sacrifice this creature: Return target enchantment card from your graveyard to your hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tragic Poet", "{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human"])
	c.oracle("{T}, Sacrifice this creature: Return target enchantment card from your graveyard to your hand.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
