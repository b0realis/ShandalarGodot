extends CardScript
## Bloated Toad — {2}{G} — Creature — Frog (uncommon, ulg).
## Oracle: Protection from blue
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bloated Toad", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["frog"])
	c.with_protection_from(Mtg.ManaColor.U)
	c.oracle("Protection from blue\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
