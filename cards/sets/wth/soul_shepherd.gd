extends CardScript
## Soul Shepherd — {1}{W} — Creature — Human Cleric (common, wth).
## Oracle: {W}, Exile a creature card from your graveyard: You gain 1 life.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Soul Shepherd", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["human","cleric"])
	c.oracle("{W}, Exile a creature card from your graveyard: You gain 1 life.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
