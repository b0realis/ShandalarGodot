extends CardScript
## Sylvan Hierophant — {1}{G} — Creature — Human Cleric (uncommon, wth).
## Oracle: When this creature dies, exile it, then return another target creature card from your graveyard to your hand.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sylvan Hierophant", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["human","cleric"])
	c.oracle("When this creature dies, exile it, then return another target creature card from your graveyard to your hand.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
