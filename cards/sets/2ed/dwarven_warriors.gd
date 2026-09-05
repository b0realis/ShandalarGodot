extends CardScript
## Dwarven Warriors — {2}{R} — Creature — Dwarf Warrior — 1/1 (2ed, common)
## Oracle: {T}: Target creature with power 2 or less can't be blocked this
##         turn.
##
## Implementation: the UNBLOCKABLE grant — a tap ability whose PumpEffect
## carries only the granted keyword (0/+0 + UNBLOCKABLE until end of
## turn); block legality refuses everything against it. The live-power
## filter reads cur_power, so a Giant-Growthed 4/4 is no longer smuggleable
## — matching the modern ruling.


func build() -> CardData:
	var spec := TargetSpec.creature("target creature with power 2 or less",
		func(inst: CardInstance) -> bool: return inst.cur_power <= 2)
	var sneak := PumpEffect.new(0, 0, [Mtg.Keyword.UNBLOCKABLE])
	sneak.target_spec = spec
	return CardData.new("Dwarven Warriors", "{2}{R}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["dwarf", "warrior"]) \
		.activated(ActivatedAbility.new(
			"", true, [sneak],
			"{T}: Target creature with power 2 or less can't be blocked this turn.")) \
		.oracle("{T}: Target creature with power 2 or less can't be blocked this turn.")
