extends CardScript
## Disciple of Grace — {1}{W} — Creature — Human Cleric (common, usg).
## Oracle: Protection from black
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Disciple of Grace", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["human","cleric"])
	c.with_protection_from(Mtg.ManaColor.B)
	c.oracle("Protection from black\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
