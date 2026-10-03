extends CardScript
## Elixir of Vitality — {4} — Artifact (uncommon, mir).
## Oracle: This artifact enters tapped.
##         {T}, Sacrifice this artifact: You gain 4 life.
##         {8}, {T}, Sacrifice this artifact: You gain 8 life.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Elixir of Vitality", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("This artifact enters tapped.\n{T}, Sacrifice this artifact: You gain 4 life.\n{8}, {T}, Sacrifice this artifact: You gain 8 life.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
