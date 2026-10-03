extends CardScript
## Benevolent Unicorn — {1}{W} — Creature — Unicorn (common, mir).
## Oracle: If a spell would deal damage to a permanent or player, it deals that much damage minus 1 to that permanent or player instead.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Benevolent Unicorn", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["unicorn"])
	c.oracle("If a spell would deal damage to a permanent or player, it deals that much damage minus 1 to that permanent or player instead.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
