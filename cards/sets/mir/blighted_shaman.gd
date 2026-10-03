extends CardScript
## Blighted Shaman — {1}{B} — Creature — Human Cleric Shaman (uncommon, mir).
## Oracle: {T}, Sacrifice a Swamp: Target creature gets +1/+1 until end of turn.
##         {T}, Sacrifice a creature: Target creature gets +2/+2 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Blighted Shaman", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","cleric","shaman"])
	c.oracle("{T}, Sacrifice a Swamp: Target creature gets +1/+1 until end of turn.\n{T}, Sacrifice a creature: Target creature gets +2/+2 until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
