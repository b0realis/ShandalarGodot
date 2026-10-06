extends CardScript
## Essence Bottle — {2} — Artifact (uncommon, tmp).
## Oracle: {3}, {T}: Put an elixir counter on this artifact.
##         {T}, Remove all elixir counters from this artifact: You gain 2 life for each elixir counter removed this way.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Essence Bottle", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("{3}, {T}: Put an elixir counter on this artifact.\n{T}, Remove all elixir counters from this artifact: You gain 2 life for each elixir counter removed this way.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
