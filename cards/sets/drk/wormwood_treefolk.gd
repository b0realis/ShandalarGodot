extends CardScript
## Wormwood Treefolk — {3}{G}{G} — Creature — Treefolk — 4/4 — (drk, rare)
## Oracle: {G}{G}: This creature gains forestwalk until end of turn and
##         deals 2 damage to you.
##         {B}{B}: This creature gains swampwalk until end of turn and
##         deals 2 damage to you.
##
## Implementation: two abilities, each a floating landwalk grant on
## itself paired with a card-local 2-damage self-burn. A 4/4 that can
## make itself unblockable against either of two colours — for a fifth of
## your life each time.


func build() -> CardData:
	return CardData.new("Wormwood Treefolk", "{3}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(4, 4) \
		.with_subtypes(["treefolk"]) \
		.activated(ActivatedAbility.new(
			"{G}{G}", false, [WalkEffect.new("forest")],
			"{G}{G}: Wormwood Treefolk gains forestwalk until end of turn and deals "
			+ "2 damage to you.")) \
		.activated(ActivatedAbility.new(
			"{B}{B}", false, [WalkEffect.new("swamp")],
			"{B}{B}: Wormwood Treefolk gains swampwalk until end of turn and deals "
			+ "2 damage to you.")) \
		.oracle("{G}{G}: This creature gains forestwalk until end of turn and deals 2 "
			+ "damage to you.\n{B}{B}: This creature gains swampwalk until end of turn "
			+ "and deals 2 damage to you.")


class WalkEffect extends EffectBase:
	var land_type: String

	func _init(p_type: String) -> void:
		land_type = p_type

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		# CR 608.2h — the ability resolves with or without its source. Only
		# the landwalk grant has nothing left to attach to; the 2 damage is
		# owed either way, exactly like Electric Eel's self-burn in this set.
		if source.zone == Mtg.Zone.BATTLEFIELD:
			game.continuous.add_until_eot_landwalk(source.id, [land_type])
			game.recalculate()
		game.deal_damage(source, TargetRef.player(controller), 2)

	func describe() -> String:
		return "gains %swalk until end of turn and deals 2 damage to you" % land_type
