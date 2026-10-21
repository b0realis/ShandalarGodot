extends CardScript
## Dream Coat — {U} — Enchantment — Aura — (leg, uncommon)
## Oracle: Enchant creature
##         {0}: Enchanted creature becomes the color or colors of your
##         choice. Activate only once each turn.
##
## Implementation: a free, once-per-turn indefinite repaint of the host.
## "The color OR COLORS" is why the colour hook returns a bitmask rather
## than one colour — the agent may answer with several bits set, and the
## question says so (`several`, so the duel screen ticks colours; until
## the bug hunt of 2026-10-21 a player could pick only one). The hint the
## card computes is the single colour the opponent's board shows least of
## (see alchor_s_tomb.gd for the same reasoning).


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
		if not game.is_present(host):   # gone, or phased out (CR 702.26e)
			return
		var hint := RecolorHostEffect._rarest_enemy_color(game, controller)
		var chosen: int = game.agents[controller].choose_color(
			game, controller, "Choose the color or colors %s becomes" % host.data.card_name,
			hint, true) & 31
		game.set_color(host, chosen if chosen != 0 else hint)

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
