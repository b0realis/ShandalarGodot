extends CardScript
## Drain Power — {U}{U} — Sorcery — (2ed, rare)
## Oracle: Target player activates a mana ability of each land they control.
##         Then that player loses all unspent mana and you add the mana lost
##         this way.
##
## Implementation: literally what it says — each of the target's lands is
## tapped for mana through MtgGame.tap_for_mana, a land that is already
## tapped simply refuses and is skipped, and every mana trigger (Mana Flare)
## fires as it would. "Target player ACTIVATES a mana ability" — which one
## is THAT player's choice (campaign 2026-10, w1-10): a land with several it
## could activate right now (City of Brass, a dual) asks its controller,
## hinting the first without a life, mana or sacrifice cost; a land with one
## usable ability is never asked.
## The victim's whole pool — including mana they were holding before Drain
## Power resolved — then moves across, which is the printed "all unspent
## mana".
##
## RESTRICTED mana (CR 106.6, a Mishra's Workshop's "spend only on
## artifacts") is drained as PLAIN mana: the restriction belonged to the
## ability that made it, and what arrives in your pool is mana you were
## given, not mana you produced.
##
## The victim's lands stay tapped, which is half the point: Drain Power is a
## Time Walk against a mana-heavy board as much as it is a ritual.


func build() -> CardData:
	return CardData.new("Drain Power", "{U}{U}", Mtg.CardType.SORCERY) \
		.spell(DrainEffect.new()) \
		.oracle("Target player activates a mana ability of each land they control. "
			+ "Then that player loses all unspent mana and you add the mana lost "
			+ "this way.")


class DrainEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var victim := target.player_id
		for land in game.players[victim].battlefield.duplicate():
			if land.is_land() and not land.cur_mana_abilities.is_empty() \
					and game.is_present(land) and land.controller_id == victim:
				DrainEffect._activate_one(game, victim, land)
		var pool := game.players[victim].mana_pool
		var moved := 0
		for color in [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B,
				Mtg.ManaColor.R, Mtg.ManaColor.G, Mtg.ManaColor.C]:
			var n := pool.total_of(color)
			if n > 0:
				game.players[controller].mana_pool.add(color, n)
				moved += n
		pool.clear()
		game.log_line("%s drains %d mana from %s" % [
			game.players[controller].player_name, moved,
			game.players[victim].player_name])

	## One mana ability of [param land], [param who]'s pick among those it
	## could activate right now; one usable ability is not a question, none
	## skips the land.
	static func _activate_one(game: MtgGame, who: int, land: CardInstance) -> void:
		var usable: Array[int] = []
		for n in land.cur_mana_abilities.size():
			if game.mana_ability_refusal(who, land, n) == "":
				usable.append(n)
		if usable.is_empty():
			return
		var pick := 0
		if usable.size() > 1:
			var labels: Array[String] = []
			var hint := -1
			for k in usable.size():
				var ability: ManaAbility = land.cur_mana_abilities[usable[k]]
				labels.append(_mana_label(ability))
				if hint < 0 and ability.life_cost == 0 and ability.pain == 0 \
						and ability.cost == null and not ability.sacrifice_source:
					hint = k
			pick = game.agents[who].choose_option(game, who, labels,
				"Drain Power: activate which mana ability of %s?" % land.data.card_name,
				maxi(hint, 0))
			pick = clampi(pick, 0, usable.size() - 1)
		# The chosen one first; should it refuse after all, the next usable.
		var order: Array[int] = [usable[pick]]
		for n in usable:
			if n != usable[pick]: order.append(n)
		for n in order:
			if game.tap_for_mana(who, land, n) == "":
				return

	static func _mana_label(ability: ManaAbility) -> String:
		var parts := PackedStringArray()
		for pair in ability.produces:
			parts.append("%d %s" % [int(pair[1]), str(Mtg.COLOR_NAMES.get(int(pair[0]), "mana"))])
		var label := "Add " + ", ".join(parts)
		if ability.pain > 0 or ability.life_cost > 0:
			label += " (%d damage/life to you)" % maxi(ability.pain, ability.life_cost)
		return label

	func describe() -> String:
		return "target player taps out and you take the mana"
