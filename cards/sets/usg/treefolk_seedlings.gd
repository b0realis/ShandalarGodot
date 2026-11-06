extends CardScript
## Treefolk Seedlings — {2}{G} — Creature — Treefolk (uncommon, usg).
## Oracle: Treefolk Seedlings's toughness is equal to the number of Forests you control.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Treefolk Seedlings", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 0)
	c.with_subtypes(["treefolk"])
	c.oracle("Treefolk Seedlings's toughness is equal to the number of Forests you control.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
