extends CardScript
## Hurr Jackal — {R} — Creature — Jackal — 1/1 — (4ed, rare)
## Oracle: {T}: Target creature can't be regenerated this turn.
##
## Implementation: sets the target's regeneration ban for the turn —
## MtgGame.destroy then ignores every shield it has or gains afterwards
## (CR 701.15d). A one-mana answer to Drudge Skeletons and the whole
## regeneration wall, though it costs the Jackal's tap each turn.


func build() -> CardData:
	return CardData.new("Hurr Jackal", "{R}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["jackal"]) \
		.activated(ActivatedAbility.new(
			"", true, [BanRegenerationEffect.new()],
			"{T}: Target creature can't be regenerated this turn.")) \
		.oracle("{T}: Target creature can't be regenerated this turn.")


class BanRegenerationEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		inst.regeneration_banned_this_turn = true
		game.log_line("%s can't be regenerated this turn" % inst.data.card_name)

	func describe() -> String:
		return "target creature can't be regenerated this turn"
