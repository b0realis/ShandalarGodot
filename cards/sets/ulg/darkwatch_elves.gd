extends CardScript
## Darkwatch Elves — {2}{G} — Creature — Elf (uncommon, ulg).
## Oracle: Protection from black
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Darkwatch Elves", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["elf"])
	c.with_protection_from(Mtg.ManaColor.B)
	c.oracle("Protection from black\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
