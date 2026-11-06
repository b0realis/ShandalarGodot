extends CardScript
## Disciple of Law — {1}{W} — Creature — Human Cleric (common, usg).
## Oracle: Protection from red
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Disciple of Law", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["human","cleric"])
	c.with_protection_from(Mtg.ManaColor.R)
	c.oracle("Protection from red\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
