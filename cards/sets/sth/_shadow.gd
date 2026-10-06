extends RefCounted
## Stronghold (_shadow, Pack 9). Shadow (CR 702.28): creatures that can block or be blocked only by creatures with shadow, and the cards that grant or answer it.
##
## Batch B1, over the Pack 9 E1 shadow keyword and the Tempest shadow
## module's helpers (cards/sets/tmp/_shadow.gd: [code]S.shadow[/code],
## [code]S.sacrificed_by_choice[/code], [code]S.pid_of[/code]):
## - Dauthi Trapper: an until-end-of-turn keyword grant on a target (Jump's
##   shape, PumpEffect 0/0 carrying SHADOW) behind {T}.
## - Soltari Champion: "whenever this creature attacks" (DECLARED_ATTACKERS,
##   the attacker itself), a one-shot MassPumpEffect over the OTHER creatures
##   its trigger's controller controls as it resolves.
## - Thalakos Deceiver: Mindstab Thrull's "attacks and isn't blocked, you may
##   sacrifice it" (UNBLOCKED_ATTACKER) with a target chosen as the trigger
##   goes on the stack (CR 603.3d); "if you do, gain control of target
##   creature" is an indefinite control change (MtgGame.change_control).
## tests/cards/test_pack_9_B1_*.gd pin each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const S := preload("res://cards/sets/tmp/_shadow.gd")


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Dauthi Trapper":
			c.activated(ActivatedAbility.new("", true, [PumpEffect.new(0, 0, [Mtg.Keyword.SHADOW])],
				"{T}: Target creature gains shadow until end of turn."))
		"Soltari Champion":
			S.shadow(c)
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _champion,
				"Whenever this creature attacks, other creatures you control get +1/+1 until end of turn.",
				F._self_attack))
		"Thalakos Deceiver":
			S.shadow(c)
			c.triggered(TriggeredAbility.new(Mtg.EventType.UNBLOCKED_ATTACKER, _deceiver,
				"Whenever this creature attacks and isn't blocked, you may sacrifice it. If you do, gain control of target creature. (This effect lasts indefinitely.)",
				F._self_enter).targeting(TargetSpec.creature(), F._enemy_first))
		_:
			return false
	return true


## Soltari Champion: "other creatures you control" as the trigger resolves
## (CR 608.2h: the affected set is fixed then; one entering later gets
## nothing). "You" is the trigger's controller (CR 603.3a).
static func _champion(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	MassPumpEffect.new(1, 1, "other creatures you control").yours_only().excluding_source() \
		.resolve(g, s, S.pid_of(g, s), null)


## Thalakos Deceiver: the target is judged again on resolution by the
## engine (CR 608.2b); the hint takes only an opposing creature that is
## worth more than the Deceiver's 1/1 body.
static func _deceiver(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var targets := g.current_targets()
	if targets.is_empty():
		return
	var prize := g.find_instance(targets[0].instance_id)
	if not g.is_present(prize):
		return
	var pid := S.pid_of(g, s)
	var hint := prize.controller_id != pid and prize.cur_power + prize.cur_toughness >= 4
	if not S.sacrificed_by_choice(g, s, "Sacrifice %s to gain control of %s?" % [
			s.data.card_name, prize.data.card_name], hint):
		return
	if g.is_present(prize):
		g.change_control(prize, pid)
