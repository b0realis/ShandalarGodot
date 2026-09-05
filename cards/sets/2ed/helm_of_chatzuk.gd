extends CardScript
## Helm of Chatzuk — {1} — Artifact — (2ed, rare)
## Oracle: {1}, {T}: Target creature gains banding until end of turn.
##
## Implementation: a plain until-end-of-turn keyword grant. Banding itself
## is the engine's attack-band system (offensive banding only — defensive
## banding is a documented engine-wide gap, docs/ROADMAP.md), so the Helm
## turns any creature into a legal band member for the turn.


func build() -> CardData:
	return CardData.new("Helm of Chatzuk", "{1}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{1}", true,
			[PumpEffect.new(0, 0, [Mtg.Keyword.BANDING])],
			"{1}, {T}: Target creature gains banding until end of turn.")) \
		.oracle("{1}, {T}: Target creature gains banding until end of turn.")
