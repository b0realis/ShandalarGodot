extends CardScript
## Wild Dogs — {G} — Creature — Dog (common, usg).
## Oracle: At the beginning of your upkeep, if a player has more life than each other player, the player with the most life gains control of this creature.
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wild Dogs", "{G}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["dog"])
	c.oracle("At the beginning of your upkeep, if a player has more life than each other player, the player with the most life gains control of this creature.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
