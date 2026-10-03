class_name CreatureRedirectEffect
extends EffectBase
## Metered damage replacement onto this ability's source. Exposes amount,
## X and target shape to AI without describing the effect as prevention.
var amount := 1
var use_x := false

func _init(points := 1, x := false) -> void:
	amount = points
	use_x = x
	is_damage_prevention = true # also legal in the classic redirection window
	ai_helpful = true
	target_spec = TargetSpec.creature()

func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, x := 0) -> void:
	if not g.is_present(s) or s.layer_timestamp != int(g.cost_paid("_source_timestamp", s.layer_timestamp)): return
	g.book_creature_redirect(g.find_instance(t.instance_id), s, x if use_x else amount)

func describe() -> String:
	return "the next %s damage to target creature this turn is dealt to this creature instead" % ("X" if use_x else str(amount))
