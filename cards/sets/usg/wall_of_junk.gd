extends CardScript
## Wall of Junk — {2} — Artifact Creature — Wall (uncommon, usg).
## Oracle: Defender (This creature can't attack.)
##         When this creature blocks, return it to its owner's hand at end of combat. (Return it only if it's on the battlefield.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wall of Junk", "{2}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(0, 7)
	c.with_subtypes(["wall"])
	c.with_keywords([Mtg.Keyword.DEFENDER])
	c.oracle("Defender (This creature can't attack.)\nWhen this creature blocks, return it to its owner's hand at end of combat. (Return it only if it's on the battlefield.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
