extends CardScript
## Wall of Water — {1}{U}{U} — Creature — Wall — 0/5 — (2ed, uncommon)
## Oracle: Defender (This creature can't attack.)
##         {U}: This creature gets +1/+0 until end of turn.
##
## Implementation: Wall of Fire's blue twin — defender + {U} power
## firebreathing (self_buff pump).


func build() -> CardData:
	return CardData.new("Wall of Water", "{1}{U}{U}", Mtg.CardType.CREATURE) \
		.pt(0, 5) \
		.with_subtypes(["wall"]) \
		.with_keywords([Mtg.Keyword.DEFENDER]) \
		.activated(ActivatedAbility.new(
			"{U}", false,
			[PumpEffect.new(1, 0).self_buff()],
			"{U}: This creature gets +1/+0 until end of turn.")) \
		.oracle("Defender\n{U}: This creature gets +1/+0 until end of turn.")
