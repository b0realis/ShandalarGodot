extends CardScript
## Tawnos's Wand — {4} — Artifact — (4ed, uncommon)
## Oracle: {2}, {T}: Target creature with power 2 or less can't be blocked
##         this turn.
##
## Implementation: an activated UNBLOCKABLE grant (the Dwarven Warriors
## keyword, until end of turn) restricted to LIVE power 2 or less at
## activation.


func build() -> CardData:
	var sneak := PumpEffect.new(0, 0, [Mtg.Keyword.UNBLOCKABLE])
	sneak.target_spec = TargetSpec.creature(
		"target creature with power 2 or less", _small)
	return CardData.new("Tawnos's Wand", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{2}", true,
			[sneak],
			"{2}, {T}: Target creature with power 2 or less can't be blocked this turn.")) \
		.oracle("{2}, {T}: Target creature with power 2 or less can't be blocked this turn.")


static func _small(inst: CardInstance) -> bool:
	return inst.cur_power <= 2
