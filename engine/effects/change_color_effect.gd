class_name ChangeColorEffect
extends EffectBase
## "Target spell or permanent becomes <colour>." — the Laces (indefinite)
## and the Legends colour cycle (until end of turn).
##
## Colour changes live in CR 613 layer 5. Two durations exist:
## - INDEFINITE (the Laces, Alchor's Tomb, Aisling Leprechaun) — stored on
##   the object as CardInstance.color_override, so it survives the cleanup
##   step and, for a Laced SPELL, rides along into the permanent it becomes.
## - UNTIL END OF TURN (Dwarven Song and its cycle) — a floating entry in
##   ContinuousEffects, expired with every other until-EOT effect.
##
## The colour REPLACES the object's colours ("becomes blue", not "is blue in
## addition"); pass a multi-colour mask for "becomes the colours of your
## choice" (Dream Coat) and 0 for colourless.
##
## Where layer 5 sits in this engine's pipeline: after the layer-4 type
## statics and the layer-7b base-P/T setters, before the remaining statics —
## so a Bad Moon still sees a creature that Touch of Darkness just painted
## black. Nothing in the pipeline depends on colour, so the floating entries
## apply in creation order and the last spell cast wins.

## Mtg.ManaColor bitmask the target becomes.
var colors: int

## Until end of turn instead of indefinitely.
var until_eot: bool = false


func _init(p_colors: int, spec: TargetSpec = null) -> void:
	colors = p_colors
	target_spec = spec if spec != null else TargetSpec.spell_or_permanent()


## Fluent: the change lasts only until end of turn (the Legends cycle).
func until_end_of_turn() -> ChangeColorEffect:
	until_eot = true
	return self


## Until-end-of-turn: registers a floating layer-5 entry with game.continuous
## and recalculates, then rechecks state-based actions — repainting can arm a
## protection or a Circle that now kills the object. This path is
## battlefield-only (the pipeline recomputes permanents, not stack objects),
## which costs nothing: the whole until-EOT cycle targets creatures.
## Indefinite: hands off to MtgGame.set_color, which writes
## CardInstance.color_override — that is what lets a Laced SPELL keep the
## colour when it resolves into a permanent.
func resolve(game: MtgGame, _source: CardInstance, _controller: int, target: TargetRef,
		_x_value: int = 0) -> void:
	var inst := game.find_instance(target.instance_id)
	if inst == null:
		return
	if until_eot:
		if inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.continuous.add_until_eot_color(inst.id, colors)
		game.recalculate()
		game.check_state_based_actions()
		game.log_line("%s becomes %s until end of turn" % [
			inst.data.card_name, ChangeColorEffect.color_name(colors)])
		return
	game.set_color(inst, colors)


## Card-English name of a colour mask ("blue", "white and black",
## "colorless") — used by logs and describe().
static func color_name(mask: int) -> String:
	var names := PackedStringArray()
	for c in Mtg.WUBRG:
		if (mask & c) != 0:
			names.append(String(Mtg.COLOR_NAMES[c]).to_lower())
	if names.is_empty():
		return "colorless"
	return " and ".join(names)


## One-line log/UI text.
func describe() -> String:
	return "%s becomes %s%s" % [
		target_spec.description if target_spec else "?",
		ChangeColorEffect.color_name(colors),
		" until end of turn" if until_eot else ""]
