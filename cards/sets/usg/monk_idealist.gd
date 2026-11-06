extends CardScript
## Monk Idealist — {2}{W} — Creature — Human Monk Cleric (uncommon, usg).
## Oracle: When this creature enters, return target enchantment card from your graveyard to your hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Monk Idealist", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","monk","cleric"])
	c.oracle("When this creature enters, return target enchantment card from your graveyard to your hand.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
