extends CardScript
## Keeper of the Flame — {R}{R} — Creature — Human Wizard (uncommon, exo).
## Oracle: {R}, {T}: Choose target opponent who has more life than you do as you activate this ability. This creature deals 2 damage to that player.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Keeper of the Flame", "{R}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["human","wizard"])
	c.oracle("{R}, {T}: Choose target opponent who has more life than you do as you activate this ability. This creature deals 2 damage to that player.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
