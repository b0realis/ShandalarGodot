extends CardScript
## Keeper of the Light — {W}{W} — Creature — Human Wizard (uncommon, exo).
## Oracle: {W}, {T}: Choose target opponent who has more life than you do as you activate this ability. You gain 3 life.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Keeper of the Light", "{W}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["human","wizard"])
	c.oracle("{W}, {T}: Choose target opponent who has more life than you do as you activate this ability. You gain 3 life.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
