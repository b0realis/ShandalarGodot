extends CardScript
## Magnetic Web — {2} — Artifact (rare, tmp).
## Oracle: If a creature with a magnet counter on it attacks, all creatures with magnet counters on them attack if able.
##         Whenever a creature with a magnet counter on it attacks, all creatures with magnet counters on them block that creature this turn if able.
##         {1}, {T}: Put a magnet counter on target creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Magnetic Web", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("If a creature with a magnet counter on it attacks, all creatures with magnet counters on them attack if able.\nWhenever a creature with a magnet counter on it attacks, all creatures with magnet counters on them block that creature this turn if able.\n{1}, {T}: Put a magnet counter on target creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
