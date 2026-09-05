extends CardScript
## Wall of Opposition — {3}{R}{R} — Creature — Wall — 0/6 — (leg, rare)
## Oracle: Defender (This creature can't attack.)
##         {1}: This creature gets +1/+0 until end of turn.
##
## Implementation: DEFENDER plus an uncapped generic-mana self pump — the
## Wall blocks and then eats whatever it stopped, given enough mana. No
## tap in the cost, so it works while it is blocking.


func build() -> CardData:
	return CardData.new("Wall of Opposition", "{3}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(0, 6) \
		.with_subtypes(["wall"]) \
		.with_keywords([Mtg.Keyword.DEFENDER]) \
		.activated(ActivatedAbility.new(
			"{1}", false,
			[PumpEffect.new(1, 0).self_buff()],
			"{1}: Wall of Opposition gets +1/+0 until end of turn.")) \
		.oracle("Defender (This creature can't attack.)\n{1}: This creature gets +1/+0 until end of turn.")
