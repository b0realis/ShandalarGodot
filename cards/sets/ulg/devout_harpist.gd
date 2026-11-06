extends CardScript
## Devout Harpist — {W} — Creature — Human (common, ulg).
## Oracle: {T}: Destroy target Aura attached to a creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Devout Harpist", "{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human"])
	c.oracle("{T}: Destroy target Aura attached to a creature.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
