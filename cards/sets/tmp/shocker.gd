extends CardScript
## Shocker — {1}{R} — Creature — Insect (rare, tmp).
## Oracle: Whenever this creature deals damage to a player, that player discards all the cards in their hand, then draws that many cards.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shocker", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["insect"])
	c.oracle("Whenever this creature deals damage to a player, that player discards all the cards in their hand, then draws that many cards.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
