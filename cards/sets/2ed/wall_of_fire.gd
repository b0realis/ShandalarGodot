extends CardScript
## Wall of Fire — {1}{R}{R} — Creature — Wall — 0/5 — (2ed, uncommon)
## Oracle: Defender (This creature can't attack.)
##         {R}: This creature gets +1/+0 until end of turn.
##
## Implementation: a firebreathing wall — defender plus the standard
## self_buff pump (Granite Gargoyle's pattern, power-side). Each {R} is
## one +1/+0 activation; a big turn of mana turns it into a real killer
## on defense.


func build() -> CardData:
	return CardData.new("Wall of Fire", "{1}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(0, 5) \
		.with_subtypes(["wall"]) \
		.with_keywords([Mtg.Keyword.DEFENDER]) \
		.activated(ActivatedAbility.new(
			"{R}", false,
			[PumpEffect.new(1, 0).self_buff()],
			"{R}: This creature gets +1/+0 until end of turn.")) \
		.oracle("Defender\n{R}: This creature gets +1/+0 until end of turn.")
