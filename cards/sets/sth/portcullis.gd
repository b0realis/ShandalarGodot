extends CardScript
## Portcullis — {4} — Artifact (rare, sth).
## Oracle: Whenever a creature enters, if there are two or more other creatures on the battlefield, exile that creature. Return that card to the battlefield under its owner's control when this artifact leaves the battlefield.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Portcullis", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("Whenever a creature enters, if there are two or more other creatures on the battlefield, exile that creature. Return that card to the battlefield under its owner's control when this artifact leaves the battlefield.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
