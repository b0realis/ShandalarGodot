extends CardScript
## Mage il-Vec — {2}{R} — Creature — Human Wizard (common, exo).
## Oracle: {T}, Discard a card at random: This creature deals 1 damage to any target.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mage il-Vec", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","wizard"])
	c.oracle("{T}, Discard a card at random: This creature deals 1 damage to any target.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
