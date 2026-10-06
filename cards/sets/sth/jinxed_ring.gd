extends CardScript
## Jinxed Ring — {2} — Artifact (rare, sth).
## Oracle: Whenever a nontoken permanent is put into your graveyard from the battlefield, this artifact deals 1 damage to you.
##         Sacrifice a creature: Target opponent gains control of this artifact. (This effect lasts indefinitely.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Jinxed Ring", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("Whenever a nontoken permanent is put into your graveyard from the battlefield, this artifact deals 1 damage to you.\nSacrifice a creature: Target opponent gains control of this artifact. (This effect lasts indefinitely.)")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
