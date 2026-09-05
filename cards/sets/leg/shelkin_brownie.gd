extends CardScript
## Shelkin Brownie — {1}{G} — Creature — Ouphe — 1/1 — (leg, common)
## Oracle: {T}: Target creature loses all "bands with other" abilities
##         until end of turn.
##
## Implementation: LoseAbilityEffect stripping the BANDING keyword, which
## is how this engine models both banding and the "bands with other"
## variants the Legends lands grant.


func build() -> CardData:
	return CardData.new("Shelkin Brownie", "{1}{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["ouphe"]) \
		.activated(ActivatedAbility.new(
			"", true,
			[LoseAbilityEffect.new([Mtg.Keyword.BANDING], "banding")],
			"{T}: Target creature loses all \"bands with other\" abilities until end of turn.")) \
		.oracle("{T}: Target creature loses all \"bands with other\" abilities until "
			+ "end of turn.")
