extends CardScript
## Mantis Engine — {5} — Artifact Creature — Insect (uncommon, uds).
## Oracle: {2}: This creature gains flying until end of turn. (It can't be blocked except by creatures with flying or reach.)
##         {2}: This creature gains first strike until end of turn. (It deals combat damage before creatures without first strike.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mantis Engine", "{5}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(3, 3)
	c.with_subtypes(["insect"])
	c.oracle("{2}: This creature gains flying until end of turn. (It can't be blocked except by creatures with flying or reach.)\n{2}: This creature gains first strike until end of turn. (It deals combat damage before creatures without first strike.)")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
