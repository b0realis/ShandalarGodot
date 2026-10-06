extends CardScript
## Patchwork Gnomes — {3} — Artifact Creature — Gnome (uncommon, tmp).
## Oracle: Discard a card: Regenerate this creature. (The next time this creature would be destroyed this turn, instead tap it, remove it from combat, and heal all damage on it.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Patchwork Gnomes", "{3}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(2, 1)
	c.with_subtypes(["gnome"])
	c.oracle("Discard a card: Regenerate this creature. (The next time this creature would be destroyed this turn, instead tap it, remove it from combat, and heal all damage on it.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
