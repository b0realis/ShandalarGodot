extends CardScript
## Wall of Brambles — {2}{G} — Creature — Plant Wall — 2/3 — (2ed, uncommon)
## Oracle: Defender (This creature can't attack.)
##         {G}: Regenerate this creature.
##
## Implementation: defender + the Drudge Skeletons regeneration package —
## a wall that shrugs off anything except "can't be regenerated" (Tunnel
## exists precisely for it; the wave-10 tests pin that duel).


func build() -> CardData:
	return CardData.new("Wall of Brambles", "{2}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 3) \
		.with_subtypes(["plant", "wall"]) \
		.with_keywords([Mtg.Keyword.DEFENDER]) \
		.activated(ActivatedAbility.new(
			"{G}", false,
			[RegenerateEffect.new()],
			"{G}: Regenerate this creature.")) \
		.oracle("Defender\n{G}: Regenerate this creature.")
