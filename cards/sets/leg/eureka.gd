extends CardScript
## Eureka — {2}{G}{G} — Sorcery — (leg, rare)
## Oracle: Starting with you, each player may put a permanent card from
##         their hand onto the battlefield. Repeat this process until no one
##         puts a card onto the battlefield.
##
## Implementation: the round-robin is literal — starting with the caster,
## each player in turn is offered ONE permanent card, and the whole circuit
## repeats until a full lap goes by with nothing played. The cards arrive
## through MtgGame.put_from_hand_into_play, so they enter the battlefield
## properly: ETB triggers fire and they are summoning-sick.
##
## An AURA is not cast, so it targets nothing — but CR 303.4f still has it
## enter attached: the player putting it down chooses something it could
## legally enchant as it enters (its own enchant restriction, and not a
## permanent with protection from its colour), and an Aura with nothing to
## enchant cannot be put onto the battlefield at all and stays in the hand —
## so it is not offered. The host is asked of the same seat (the hint puts
## a helpful Aura on their own creature, a hostile one on the opponent's)
## and the Aura arrives through MtgGame.attach_aura_from_anywhere. Until
## 2026-10-03 every Aura entered attached to nothing and the state-based
## actions binned it.
##
## An Aura that enchants a creature card in a GRAVEYARD (Animate Dead,
## Dance of the Dead) chooses one there as it enters (CR 303.4f) and raises
## it the way it does when cast — MtgGame.attach_aura_from_anywhere takes a
## graveyard host for those two shapes (2026-10-03; until then they were
## never offered).
##
## Symmetric, and the opponent gets the last word — Eureka empties both
## hands, which is exactly why it was banned.
##
## Both halves of each player's turn in the circuit — whether to put a card
## down and WHICH one — are asked of that player's own DecisionAgent, so a
## human seat is held open on each in turn (docs/duel-todo.md §1.3) and
## every other seat answers for itself. The default answer is "yes, the
## biggest one"; the candidates are pre-sorted for it.


func build() -> CardData:
	return CardData.new("Eureka", "{2}{G}{G}", Mtg.CardType.SORCERY) \
		.spell(EurekaEffect.new()) \
		.oracle("Starting with you, each player may put a permanent card from their hand "
			+ "onto the battlefield. Repeat this process until no one puts a card onto the "
			+ "battlefield.")


class EurekaEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var order: Array[int] = [controller, game.opponent_of(controller)]
		var guard := 0
		var anyone_played := true
		while anyone_played and guard < 100 and not game.game_over:
			anyone_played = false
			for pid in order:
				guard += 1
				if _offer(game, pid):
					anyone_played = true

	## One player's turn in the circuit; true when they put a card down.
	static func _offer(game: MtgGame, pid: int) -> bool:
		if game.players[pid].has_lost:
			return false
		var candidates: Array[CardInstance] = []
		for card in game.players[pid].hand:
			if not card.data.is_permanent_type():
				continue
			if card.data.is_aura() and _hosts(game, card).is_empty():
				continue   # CR 303.4f: nothing to enchant, so it stays put
			candidates.append(card)
		if candidates.is_empty():
			return false
		if not game.agents[pid].choose_yes_no(game, pid,
				"Put a permanent card onto the battlefield with Eureka?", true):
			return false
		candidates.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			return a.data.cost.mana_value() > b.data.cost.mana_value())
		var pick := game.agents[pid].choose_card(game, pid, candidates,
			"Choose a permanent card to put onto the battlefield")
		if pick == null or not candidates.has(pick):
			pick = candidates[0]
		if not pick.data.is_aura():
			game.put_from_hand_into_play(pick, pid)
			return true
		# CR 303.4f: the Aura's controller chooses what it enchants as it
		# enters — the hint is the helpful side's biggest body, and the ask
		# is ORDERED (campaign 2026-10, w1-3: a heuristic seat put a hostile
		# Aura on its own best creature by card value).
		var hosts := _hosts(game, pick)
		var friendly := EffectIntent.aura_aim(pick.data) != EffectIntent.Aim.HOSTILE
		hosts.sort_custom(_host_order.bind(pid, friendly))
		var host := game.agents[pid].choose_card(game, pid, hosts,
			"Choose what %s enchants" % pick.data.card_name, false, false, true)
		if host == null or not hosts.has(host):
			host = hosts[0]
		game.attach_aura_from_anywhere(pick, host, pid)
		return true

	## The hint: the helpful side's biggest body first. A card in a
	## graveyard is raised for the Aura's controller whoever owned it, so
	## only its size counts — its PRINTED size, which is what a card off
	## the battlefield has (CR 109.3).
	static func _host_order(a: CardInstance, b: CardInstance, pid: int, friendly: bool) -> bool:
		if a.zone == Mtg.Zone.BATTLEFIELD and b.zone == Mtg.Zone.BATTLEFIELD:
			var a_side := (a.controller_id == pid) == friendly
			var b_side := (b.controller_id == pid) == friendly
			if a_side != b_side:
				return a_side
		var a_size := _size(a)
		var b_size := _size(b)
		if a_size != b_size:
			return a_size > b_size
		return a.id < b.id

	static func _size(card: CardInstance) -> int:
		if card.zone == Mtg.Zone.BATTLEFIELD:
			return card.cur_power + card.cur_toughness
		return card.data.power + card.data.toughness

	## What [param aura] could legally be attached to as it enters (CR
	## 303.4f): its own enchant restriction and protection — nothing it
	## would have to TARGET, since it is not cast. For an Aura that
	## enchants a creature card in a graveyard, the cards its enchant
	## spec names there.
	static func _hosts(game: MtgGame, aura: CardInstance) -> Array[CardInstance]:
		var hosts: Array[CardInstance] = []
		if aura.data.aura_reanimates or aura.data.aura_graveyard_entry:
			if aura.data.aura_target == null:
				return hosts
			for ref in aura.data.aura_target.legal_targets(game, aura):
				var card := game.find_instance(ref.instance_id)
				if card != null and card.zone == Mtg.Zone.GRAVEYARD:
					hosts.append(card)
			return hosts
		for inst in game.all_battlefield():
			if inst == aura or inst.phased_out:
				continue
			if not game.aura_can_enchant(aura, inst):
				continue
			if (inst.cur_protection & aura.cur_colors) != 0:
				continue
			hosts.append(inst)
		return hosts

	func describe() -> String:
		return "each player empties their hand of permanents onto the battlefield"
