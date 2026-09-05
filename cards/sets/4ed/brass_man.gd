extends CardScript
## Brass Man — {1} — Artifact Creature — Construct — 1/3 — (4ed, uncommon)
## Oracle: This creature doesn't untap during your untap step.
##         At the beginning of your upkeep, you may pay {1}. If you do,
##         untap this creature.
##
## Implementation: cur_skips_untap static + the try_pay upkeep offer
## (Mana Vault's little brother in creature form) — one generic per turn
## keeps the man marching.


func build() -> CardData:
	return CardData.new("Brass Man", "{1}",
			Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(1, 3) \
		.with_subtypes(["construct"]) \
		.static_ability(StaticAbility.new(
			_lock, "This creature doesn't untap during your untap step.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _offer_untap,
			"At the beginning of your upkeep, you may pay {1}. If you do, untap this creature.",
			_own_upkeep)) \
		.oracle("This creature doesn't untap during your untap step.\nAt the beginning of your upkeep, you may pay {1}. If you do, untap this creature.")


static func _lock(_game: MtgGame, source: CardInstance) -> void:
	source.cur_skips_untap = true


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data["player"] == source.controller_id


static func _offer_untap(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD or not source.tapped:
		return
	var pid := source.controller_id
	var cost := ManaCost.parse("{1}")
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid,
				"Pay {1} to untap %s?" % source.data.card_name, true) \
			and game.try_pay(pid, cost):
		game.untap_permanent(source)
