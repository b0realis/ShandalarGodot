extends CardScript
## Amok — {1}{R} — Enchantment (rare, sth).
## Oracle: {1}, Discard a card at random: Put a +1/+1 counter on target creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Amok", "{1}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{1}, Discard a card at random: Put a +1/+1 counter on target creature.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
