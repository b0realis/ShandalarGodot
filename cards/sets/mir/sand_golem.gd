extends CardScript
## Sand Golem — {5} — Artifact Creature — Golem (uncommon, mir).
## Oracle: When a spell or ability an opponent controls causes you to discard this card, return this card from your graveyard to the battlefield with a +1/+1 counter on it at the beginning of the next end step.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sand Golem", "{5}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(3, 3)
	c.with_subtypes(["golem"])
	c.oracle("When a spell or ability an opponent controls causes you to discard this card, return this card from your graveyard to the battlefield with a +1/+1 counter on it at the beginning of the next end step.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
