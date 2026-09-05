extends CardScript
## Scarwood Bandits — {2}{G}{G} — Creature — Human Rogue — 2/2 — (drk, rare)
## Oracle: Forestwalk
##         {2}{G}, {T}: Unless an opponent pays {2}, gain control of target
##         artifact for as long as this creature remains on the battlefield.
##
## Implementation: printed forestwalk plus a leashed steal that the
## artifact's controller may buy off for {2} (offered through their
## DecisionAgent and MtgGame.try_pay). Either way the Bandits spent their
## turn — which is exactly the printed bargain.


func build() -> CardData:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact", _is_artifact)
	return CardData.new("Scarwood Bandits", "{2}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["human", "rogue"]) \
		.with_landwalk(["forest"]) \
		.activated(ActivatedAbility.new(
			"{2}{G}", true, [BanditEffect.new(spec)],
			"{2}{G}, {T}: Unless an opponent pays {2}, gain control of target "
			+ "artifact for as long as Scarwood Bandits remains on the battlefield.")) \
		.oracle("Forestwalk (This creature can't be blocked as long as defending "
			+ "player controls a Forest.)\n{2}{G}, {T}: Unless an opponent pays {2}, "
			+ "gain control of target artifact for as long as this creature remains "
			+ "on the battlefield.")


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)


class BanditEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var prize := game.find_instance(target.instance_id)
		if prize == null or prize.zone != Mtg.Zone.BATTLEFIELD \
				or source.zone != Mtg.Zone.BATTLEFIELD:
			return
		var defender := game.opponent_of(controller)
		var toll := ManaCost.parse("{2}")
		if game.can_afford_cost(defender, toll) \
				and game.agents[defender].choose_yes_no(game, defender,
					"Pay {2} to keep %s?" % prize.data.card_name, true) \
				and game.try_pay(defender, toll):
			game.log_line("%s pays the Bandits off" % game.players[defender].player_name)
			return
		game.gain_control_leashed(prize, source, false)

	func describe() -> String:
		return "steal target artifact unless an opponent pays {2}"
