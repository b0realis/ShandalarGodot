extends CardScript
## Backdraft — {1}{R} — Instant — (leg, uncommon)
## Oracle: Choose a player who cast one or more sorcery spells this turn.
##         Backdraft deals damage to that player equal to half the damage
##         dealt by one of those sorcery spells this turn, rounded down.
##
## Implementation: this card wanted a piece of bookkeeping the engine kept
## saying it owed (docs/ROADMAP.md, "damage bookkeeping records source IDs,
## not amounts") — MtgGame.damage_dealt_this_turn, a per-source running
## total, cleared at cleanup. A sorcery that has resolved is in its owner's
## graveyard with its instance id intact, so "the damage dealt by one of
## those sorcery spells this turn" is a dictionary lookup.
##
## Both choices are the caster's and both are real: WHICH player (only seats
## that actually cast a sorcery this turn are offered) and WHICH of their
## sorceries. The heuristic takes the opponent, and their biggest burn.
##
## Not a target — the printed word is "choose" — so shroud does not protect
## and there is nothing to fizzle. Cast it in response to the Fireball, when
## the damage is on the record but the caster still has to live with it.


func build() -> CardData:
	return CardData.new("Backdraft", "{1}{R}", Mtg.CardType.INSTANT) \
		.spell(BackdraftEffect.new()) \
		.oracle("Choose a player who cast one or more sorcery spells this turn. "
			+ "Backdraft deals damage to that player equal to half the damage dealt "
			+ "by one of those sorcery spells this turn, rounded down.")


class BackdraftEffect extends EffectBase:
	## Every sorcery [param pid] owns that dealt damage this turn.
	static func burners(game: MtgGame, pid: int) -> Array[CardInstance]:
		var out: Array[CardInstance] = []
		for zone in [game.players[pid].graveyard, game.players[pid].exile]:
			for card in zone:
				if card.data.is_type(Mtg.CardType.SORCERY) \
						and int(game.damage_dealt_this_turn.get(card.id, 0)) > 0:
					out.append(card)
		for item in game.stack:
			if item.card != null and item.card.owner_id == pid \
					and item.card.data.is_type(Mtg.CardType.SORCERY) \
					and int(game.damage_dealt_this_turn.get(item.card.id, 0)) > 0:
				out.append(item.card)
		out.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			return int(game.damage_dealt_this_turn.get(a.id, 0)) \
				> int(game.damage_dealt_this_turn.get(b.id, 0)))
		return out

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var seats: Array[int] = []
		var labels: Array[String] = []
		# The opponent first, so the heuristic's "first option" is the play.
		for pid in [game.opponent_of(controller), controller]:
			if not BackdraftEffect.burners(game, pid).is_empty():
				seats.append(pid)
				labels.append(game.players[pid].player_name)
		if seats.is_empty():
			game.log_line("Backdraft finds no sorcery to feed on")
			return
		var seat_index: int = game.agents[controller].choose_option(game,
			controller, labels, "Choose a player who cast a sorcery this turn", 0)
		var victim: int = seats[maxi(seat_index, 0)]
		var spells := BackdraftEffect.burners(game, victim)
		var pick := game.agents[controller].choose_card(game, controller, spells,
			"Choose one of their sorceries")
		if pick == null or not spells.has(pick):
			pick = spells[0]
		var dealt := int(game.damage_dealt_this_turn.get(pick.id, 0))
		game.log_line("Backdraft feeds on %s (%d damage)" % [
			pick.data.card_name, dealt])
		game.deal_damage(source, TargetRef.player(victim), dealt / 2)

	func describe() -> String:
		return "burns a player for half the damage one of their sorceries dealt"
