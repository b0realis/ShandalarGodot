extends CardScript
## Dream Coat — {U} — Enchantment — Aura — (leg, uncommon)
## Oracle: Enchant creature
##         {0}: Enchanted creature becomes the color or colors of your
##         choice. Activate only once each turn.
##
## Implementation: a free, once-per-turn indefinite repaint of the host.
## "The color OR COLORS" is why the colour hook returns a bitmask rather
## than one colour — the agent may answer with several bits set. The hint
## the card computes is the single colour the opponent's board shows least
## of (see alchor_s_tomb.gd for the same reasoning).


func build() -> CardData:
	return CardData.new("Dream Coat", "{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.activated(ActivatedAbility.new("", false, [RecolorHostEffect.new()],
			"{0}: Enchanted creature becomes the color or colors of your choice. Activate only once each turn.").per_turn(1)) \
		.oracle("Enchant creature\n{0}: Enchanted creature becomes the color or colors of your choice. Activate only once each turn.")


class RecolorHostEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source == null or source.attached_to == -1:
			return
		var host := game.find_instance(source.attached_to)
		if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
			return
		var hint := RecolorHostEffect._rarest_enemy_color(game, controller)
		var chosen: int = game.agents[controller].choose_color(
			game, controller, "Choose a color for %s" % host.data.card_name, hint)
		game.set_color(host, chosen)

	static func _rarest_enemy_color(game: MtgGame, controller: int) -> int:
		var enemy := game.opponent_of(controller)
		var best: int = Mtg.ManaColor.W
		var best_count := -1
		for color in Mtg.WUBRG:
			var count := 0
			for inst in game.players[enemy].battlefield:
				if inst.has_color(color):
					count += 1
			if best_count < 0 or count < best_count:
				best = color
				best_count = count
		return best

	func describe() -> String:
		return "enchanted creature becomes the color or colors of your choice"
