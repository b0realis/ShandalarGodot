extends RefCounted
## Urza's Saga (_combat, Pack 10). Combat restrictions, requirements and
## combat-damage effects — the cards on Pack 10 E6 (engine/combat.gd):
##
## - Defensive Formation: its controller assigns the combat damage of each
##   creature attacking them, divided as they choose among its blockers
##   (CombatState.defender_assigns_damage — the defensive-banding request,
##   CR 510.1a-d, 702.22j); the attacking player's own Formation does
##   nothing, an unblocked attacker is untouched.
## - Okk: two printed restrictions, each a companion requirement checked as
##   attackers / blockers are declared, with powers as they are then (CR
##   508.1c, 509.1b). Under Humility it has no ability, so no restriction.
## - Outmaneuver: X target BLOCKED creatures deal all their combat damage to
##   the defending player this turn, no question asked; they stay blocked
##   and their blockers still deal theirs (CR 509.1h, 510.1a-c).
## tests/cards/test_pack_10_B13_combat.gd pins each card.
const F := preload("res://cards/sets/fem/_rules.gd")

const GREATER := "a creature with greater power"


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Defensive Formation":
			c.static_ability(CombatState.defender_assigns_damage())
		"Okk":
			c.static_ability(CombatState.attack_companion(CombatState.has_greater_power, GREATER,
				"This creature can't attack unless a creature with greater power also attacks."))
			c.static_ability(CombatState.block_companion(CombatState.has_greater_power, GREATER,
				"This creature can't block unless a creature with greater power also blocks."))
		"Outmaneuver":
			var aim := F.Action.new(_outmaneuver,
				"X target blocked creatures assign their combat damage this turn as though they weren't blocked",
				TargetSpec.creature("target blocked creature").with_game_filter(CombatState.is_blocked_attacker),
				true)
			aim.x_targets()
			c.spell(aim)
		_: return false
	return true


static func _outmaneuver(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	CombatState.assign_as_though_unblocked_this_turn(g, s, t.instance_id)
