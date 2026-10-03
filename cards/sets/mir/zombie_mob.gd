extends CardScript
## Zombie Mob — {2}{B}{B} — Creature — Zombie (uncommon, mir).
## Oracle: This creature enters with a +1/+1 counter on it for each creature card in your graveyard.
##         When this creature enters, exile all creature cards from your graveyard.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Zombie Mob", "{2}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 0)
	c.with_subtypes(["zombie"])
	c.oracle("This creature enters with a +1/+1 counter on it for each creature card in your graveyard.\nWhen this creature enters, exile all creature cards from your graveyard.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
