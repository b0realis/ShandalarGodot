extends CardScript
## Crystal Rod — {1} — Artifact — (2ed, uncommon)
## Oracle: Whenever a player casts a blue spell, you may pay {1}. If you
##         do, you gain 1 life.
##
## Implementation: the lucky-charm cycle (see ivory_cup.gd) — blue flavor.


func build() -> CardData:
	return CardData.new("Crystal Rod", "{1}", Mtg.CardType.ARTIFACT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.SPELL_CAST, _offer,
			"Whenever a player casts a blue spell, you may pay {1}. If you do, you gain 1 life.",
			_blue_spell)) \
		.oracle("Whenever a player casts a blue spell, you may pay {1}. If you do, you gain 1 life.")


static func _blue_spell(_game: MtgGame, _source: CardInstance, event: GameEvent) -> bool:
	var inst: CardInstance = event.data["instance"]
	return (inst.cur_colors & Mtg.ManaColor.U) != 0


static func _offer(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var pid := source.controller_id
	var cost := ManaCost.parse("{1}")
	if not game.can_afford_cost(pid, cost):
		return
	if game.agents[pid].choose_yes_no(game, pid,
			"Pay {1} for %s to gain 1 life?" % source.data.card_name, true) \
			and game.try_pay(pid, cost):
		game.adjust_life(pid, 1)
