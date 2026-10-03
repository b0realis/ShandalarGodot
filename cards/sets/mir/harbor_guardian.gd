extends CardScript
## Harbor Guardian — {2}{W}{U} — Creature — Gargoyle (uncommon, mir).
## Oracle: Reach (This creature can block creatures with flying.)
##         Whenever this creature attacks, defending player may draw a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Harbor Guardian", "{2}{W}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["gargoyle"])
	c.with_keywords([Mtg.Keyword.REACH])
	c.oracle("Reach (This creature can block creatures with flying.)\nWhenever this creature attacks, defending player may draw a card.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
