extends CardScript
## Mogg Assassin — {2}{R} — Creature — Goblin Assassin (uncommon, exo).
## Oracle: {T}: You choose target creature an opponent controls, and that opponent chooses target creature. Flip a coin. If you win the flip, destroy the creature you chose. If you lose the flip, destroy the creature your opponent chose.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mogg Assassin", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["goblin","assassin"])
	c.oracle("{T}: You choose target creature an opponent controls, and that opponent chooses target creature. Flip a coin. If you win the flip, destroy the creature you chose. If you lose the flip, destroy the creature your opponent chose.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
