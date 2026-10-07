extends CardScript
## Juxtapose — {3}{U} — Sorcery — (leg, rare)
## Oracle: You and target player exchange control of the creature you each
##         control with the greatest mana value. Then exchange control of
##         artifacts the same way. If two or more permanents a player
##         controls are tied for greatest, their controller chooses one of
##         them.
##
## Implementation: two passes — creatures, then artifacts — each finding
## the greatest mana value on both sides and handing the pair to
## MtgGame.exchange_control (CR 701.10). Each half of a tie is broken by the
## permanent's OWN controller, through their agent, because the printed card
## says so. The pick is the one HANDED OVER, so the hint offers the least
## valuable first (campaign 2026-10, w1-3 — it offered the biggest body, and
## a heuristic seat gave away its Serra Angel for a tied vanilla 4/5); the
## ask is ORDERED, so a heuristic seat takes the head of the list.
##
## The exchange is all-or-nothing (CR 701.10c): a side with no creature at
## all means no creature trade, and the artifact pass then runs on its own.
##
## Mana value is the printed cost (CR 202.3) — a token, or an animated land,
## counts as 0 and so is the last thing to be handed over.
##
## mage-go registers Juxtapose as an unimplemented shell
## (cards/legends/spells.go): *"complex control exchange not supported"*.
## The engine piece that makes it expressible here is MtgGame.exchange_control.


func build() -> CardData:
	return CardData.new("Juxtapose", "{3}{U}", Mtg.CardType.SORCERY) \
		.spell(JuxtaposeEffect.new()) \
		.oracle("You and target player exchange control of the creature you each "
			+ "control with the greatest mana value. Then exchange control of "
			+ "artifacts the same way. If two or more permanents a player controls "
			+ "are tied for greatest, their controller chooses one of them.")


class JuxtaposeEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var them := target.player_id
		if them == controller:
			return   # "you and target player" — trading with yourself is nothing
		_swap_greatest(game, controller, them, JuxtaposeEffect._is_creature,
			"creature")
		_swap_greatest(game, controller, them, JuxtaposeEffect._is_artifact,
			"artifact")

	static func _is_creature(inst: CardInstance) -> bool:
		return inst.is_creature()

	static func _is_artifact(inst: CardInstance) -> bool:
		return inst.is_type(Mtg.CardType.ARTIFACT)

	## Each side's greatest-mana-value match trades places.
	static func _swap_greatest(game: MtgGame, you: int, them: int,
			matches: Callable, what: String) -> void:
		var mine := _greatest(game, you, matches, what)
		var theirs := _greatest(game, them, matches, what)
		if mine == null or theirs == null:
			return
		game.exchange_control(mine, theirs)

	## [param pid]'s match with the greatest mana value; a tie is broken by
	## [param pid] themselves ("their controller chooses one of them").
	static func _greatest(game: MtgGame, pid: int, matches: Callable,
			what: String) -> CardInstance:
		var best := -1
		var tied: Array[CardInstance] = []
		for inst in game.players[pid].battlefield:
			if not matches.call(inst):
				continue
			var mv := inst.data.cost.mana_value()
			if mv > best:
				best = mv
				tied = [inst]
			elif mv == best:
				tied.append(inst)
		if tied.is_empty():
			return null
		if tied.size() == 1:
			return tied[0]
		tied.sort_custom(JuxtaposeEffect._least_first)
		var pick := game.agents[pid].choose_card(game, pid, tied,
			"Choose which %s Juxtapose takes" % what, false, false, true)
		return pick if pick != null and tied.has(pick) else tied[0]

	## The least valuable first: it is the one its controller gives away.
	static func _least_first(a: CardInstance, b: CardInstance) -> bool:
		var av := Evaluator.permanent_value(a)
		var bv := Evaluator.permanent_value(b)
		if av != bv:
			return av < bv
		return a.id < b.id

	func describe() -> String:
		return "you and target player trade your biggest creature and artifact"
