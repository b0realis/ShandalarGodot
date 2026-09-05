extends CardScript
## Swords to Plowshares — {W} — Instant (2ed, uncommon)
## Oracle: Exile target creature. Its controller gains life equal to its
##         power.
##
## Implementation: the file defines its own small effect class — the
## documented escape hatch for cards whose effect combination isn't in the
## shared toolbox (docs/adding-cards.md). Exiling is not destruction:
## no dies-trigger, regeneration can't save the creature. The life amount
## reads CURRENT power at resolution (a Giant-Growthed victim feeds its
## controller 3 extra life — as on the real card).
## Note: being white, it cannot target Black Knight (protection) — tested.


func build() -> CardData:
	return CardData.new("Swords to Plowshares", "{W}", Mtg.CardType.INSTANT) \
		.spell(SwordsEffect.new()) \
		.oracle("Exile target creature. Its controller gains life equal to its power.")


class SwordsEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var victim := game.find_instance(target.instance_id)
		if victim == null or victim.zone != Mtg.Zone.BATTLEFIELD:
			return
		var life_gain := victim.cur_power
		var victim_controller := victim.controller_id
		game.exile_permanent(victim)
		if life_gain > 0:
			game.adjust_life(victim_controller, life_gain)

	func describe() -> String:
		return "exiles target creature; its controller gains its power in life"
