extends CardScript
## Purraj of Urborg — {3}{B}{B} — Legendary Creature — Cat Warrior (rare, mir).
## Oracle: Purraj has first strike as long as it's attacking.
##         Whenever a player casts a black spell, you may pay {B}. If you do, put a +1/+1 counter on Purraj.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Purraj of Urborg", "{3}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["cat","warrior"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("Purraj has first strike as long as it's attacking.\nWhenever a player casts a black spell, you may pay {B}. If you do, put a +1/+1 counter on Purraj.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
