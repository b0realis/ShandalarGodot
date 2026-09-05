extends CardScript
## Witch Hunter — {2}{W}{W} — Creature — Human Cleric — 1/1 — (drk, rare)
## Oracle: {T}: This creature deals 1 damage to target player or
##         planeswalker.
##         {1}{W}{W}, {T}: Return target creature an opponent controls to
##         its owner's hand.
##
## Implementation: two abilities sharing one untap — both carry {T}, so the
## Hunter either pings or bounces in a turn, never both. "An opponent
## controls" is part of TARGETING (CR 115.4), so it lives in the
## TargetSpec as a source-aware filter rather than in resolution: pointing
## the bounce at your own creature is refused at activation, and a creature
## that changes hands before the ability resolves is no longer a legal
## target and the ability fizzles (CR 608.2b). Planeswalkers do not exist
## in the 1997 pool, so the printed "or planeswalker" has nothing to name.


func build() -> CardData:
	var ping := DamageEffect.new(1)
	ping.target_spec = TargetSpec.player()
	var theirs := TargetSpec.creature("target creature an opponent controls")
	theirs.with_source_filter(_enemy_creature)
	theirs.because(TargetSpec.WHY["controller"])   # "an opponent controls"
	return CardData.new("Witch Hunter", "{2}{W}{W}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "cleric"]) \
		.activated(ActivatedAbility.new(
			"", true, [ping],
			"{T}: Witch Hunter deals 1 damage to target player.")) \
		.activated(ActivatedAbility.new(
			"{1}{W}{W}", true, [ReturnToHandEffect.new(theirs)],
			"{1}{W}{W}, {T}: Return target creature an opponent controls to its owner's hand.")) \
		.oracle("{T}: This creature deals 1 damage to target player or planeswalker.\n"
			+ "{1}{W}{W}, {T}: Return target creature an opponent controls to its owner's hand.")


static func _enemy_creature(_game: MtgGame, source: CardInstance,
		inst: CardInstance) -> bool:
	return inst.controller_id != source.controller_id
