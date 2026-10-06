extends CardScript
## Energizer — {4} — Artifact Creature — Juggernaut (rare, tmp).
## Oracle: {2}, {T}: Put a +1/+1 counter on this creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Energizer", "{4}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(2, 2)
	c.with_subtypes(["juggernaut"])
	c.oracle("{2}, {T}: Put a +1/+1 counter on this creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
