extends CardScript
## Scarwood Hag — {1}{G} — Creature — Hag — 1/1 — (drk, uncommon)
## Oracle: {G}{G}{G}{G}, {T}: Target creature gains forestwalk until end
##         of turn. (It can't be blocked as long as defending player
##         controls a Forest.)
##         {T}: Target creature loses forestwalk until end of turn.
##
## Implementation: two abilities sharing one untap — a floating landwalk
## GRANT (four green mana) and a free landwalk LOSS of forestwalk alone
## (LoseAbilityEffect.and_landwalk_of(["forest"]) — a creature with a
## second landwalk type keeps it). The continuous pipeline applies losses
## after grants, so pointing both at the same creature in one turn leaves
## it without forestwalk.


func build() -> CardData:
	return CardData.new("Scarwood Hag", "{1}{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["hag"]) \
		.activated(ActivatedAbility.new(
			"{G}{G}{G}{G}", true, [GrantForestwalkEffect.new()],
			"{G}{G}{G}{G}, {T}: Target creature gains forestwalk until end of turn.")) \
		.activated(ActivatedAbility.new(
			"", true,
			[LoseAbilityEffect.new([], "forestwalk").and_landwalk_of(["forest"])],
			"{T}: Target creature loses forestwalk until end of turn.")) \
		.oracle("{G}{G}{G}{G}, {T}: Target creature gains forestwalk until end of "
			+ "turn. (It can't be blocked as long as defending player controls a "
			+ "Forest.)\n{T}: Target creature loses forestwalk until end of turn.")


class GrantForestwalkEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.continuous.add_until_eot_landwalk(inst.id, ["forest"])
		game.recalculate()

	func describe() -> String:
		return "target creature gains forestwalk until end of turn"
