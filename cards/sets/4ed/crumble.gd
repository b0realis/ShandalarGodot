extends CardScript
## Crumble — {G} — Instant — (4ed, uncommon)
## Oracle: Destroy target artifact. It can't be regenerated. That
##         artifact's controller gains life equal to its mana value.
##
## Implementation: Divine Offering's green cousin with both riders
## flipped — no regeneration allowed, and the consolation life goes to
## the artifact's CONTROLLER (read before the destruction wipes
## controller state). One green mana for any artifact was a bargain even
## with the gift attached.


func build() -> CardData:
	return CardData.new("Crumble", "{G}", Mtg.CardType.INSTANT) \
		.spell(CrumbleEffect.new()) \
		.oracle("Destroy target artifact. It can't be regenerated. That artifact's controller gains life equal to its mana value.")


class CrumbleEffect extends EffectBase:
	static func _is_artifact(inst: CardInstance) -> bool:
		return inst.is_type(Mtg.CardType.ARTIFACT)

	func _init() -> void:
		target_spec = TargetSpec.new(TargetSpec.Kind.PERMANENT,
			"target artifact", _is_artifact)

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		var owner: int = inst.controller_id
		var mv: int = inst.data.cost.mana_value()
		game.destroy(inst, false)
		game.adjust_life(owner, mv)

	func describe() -> String:
		return "destroys target artifact (no regeneration); its controller gains its mana value in life"
