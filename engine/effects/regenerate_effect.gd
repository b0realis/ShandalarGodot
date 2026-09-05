class_name RegenerateEffect
extends EffectBase
## "Regenerate [this]." — builds a regeneration shield on the effect's
## source (CR 701.15). Typically the payload of an activated ability like
## Drudge Skeletons' "{B}: Regenerate Drudge Skeletons."
##
## The shield is consumed by MtgGame.destroy: instead of dying, the
## creature taps, its damage clears, and it is removed from combat. Shields
## expire at cleanup. Destruction marked "can't be regenerated" (Terror,
## Wrath of God) ignores shields entirely.


func _init() -> void:
	# The SECOND 1997 window's only legal action (§6.8). `Duel.hlp`, topic
	# **Regeneration**: *"You can use regeneration only at the time when a
	# creature is about to go to the graveyard."*
	is_regeneration = true


## Fluent: shield a TARGET creature instead of the source ("Regenerate
## target creature" — Death Ward).
func target_creature(desc: String = "", filter: Callable = Callable()) -> RegenerateEffect:
	target_spec = TargetSpec.creature(desc, filter)
	return self


## Increments CardInstance.regeneration_shields on the affected permanent.
## Written directly rather than through an MtgGame helper because a shield
## is inert bookkeeping — nothing triggers on gaining one, and the rules
## consequence happens later, inside MtgGame.destroy. Note this is the
## classic pre-emptive shield: it must resolve BEFORE the lethal damage, so
## a creature that already died cannot be saved retroactively.
func resolve(game: MtgGame, source: CardInstance, _controller: int, target: TargetRef,
		_x_value: int = 0) -> void:
	var affected := source
	if target_spec != null:
		affected = game.find_instance(target.instance_id)
	if affected == null or affected.zone != Mtg.Zone.BATTLEFIELD:
		return   # died before the shield resolved — too late (no retroactive save)
	affected.regeneration_shields += 1
	game.log_line("%s gains a regeneration shield (%d)" % [
		affected.data.card_name, affected.regeneration_shields])


## One-line log/UI text.
func describe() -> String:
	if target_spec != null:
		return "regenerates %s" % target_spec.description
	return "regenerates this permanent"
