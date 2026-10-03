extends CardScript
## Llanowar Sentinel — {2}{G} — Creature — Elf (common, wth).
## Oracle: When this creature enters, you may pay {1}{G}. If you do, search your library for a card named Llanowar Sentinel, put that card onto the battlefield, then shuffle.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Llanowar Sentinel", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["elf"])
	c.oracle("When this creature enters, you may pay {1}{G}. If you do, search your library for a card named Llanowar Sentinel, put that card onto the battlefield, then shuffle.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
