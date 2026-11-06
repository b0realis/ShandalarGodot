extends CardScript
## Serra Avatar — {4}{W}{W}{W} — Creature — Avatar (rare, usg).
## Oracle: Serra Avatar's power and toughness are each equal to your life total.
##         When Serra Avatar is put into a graveyard from anywhere, shuffle it into its owner's library.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Serra Avatar", "{4}{W}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["avatar"])
	c.oracle("Serra Avatar's power and toughness are each equal to your life total.\nWhen Serra Avatar is put into a graveyard from anywhere, shuffle it into its owner's library.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
