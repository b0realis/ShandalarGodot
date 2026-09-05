extends CardScript
## Soul Net — {1} — Artifact — (2ed, uncommon)
## Oracle: Whenever a creature dies, you may pay {1}. If you do, you gain
##         1 life.
##
## Implementation: the lucky-charm payment pattern (see ivory_cup.gd) on
## the DIES event instead of SPELL_CAST — ANY creature's death (either
## player's, combat or removal) offers the {1}.


func build() -> CardData:
	return CardData.new("Soul Net", "{1}", Mtg.CardType.ARTIFACT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DIES, _offer,
			"Whenever a creature dies, you may pay {1}. If you do, you gain 1 life.",
			_creature_died)) \
		.oracle("Whenever a creature dies, you may pay {1}. If you do, you gain 1 life.")


## LAST KNOWN INFORMATION (CR 608.2h): a dying permanent's cur_* are already
## back to printed values by the time the DIES event is dispatched, so
## "whenever a CREATURE dies" is answered from `last_types` — the same
## snapshot `MtgGame.creatures_died_this_turn` counts from. An animated
## Mishra's Factory died as a creature.
static func _creature_died(_game: MtgGame, _source: CardInstance, event: GameEvent) -> bool:
	var inst: CardInstance = event.data["instance"]
	return (inst.last_types & Mtg.CardType.CREATURE) != 0


static func _offer(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var pid := source.controller_id
	var cost := ManaCost.parse("{1}")
	if not game.can_afford_cost(pid, cost):
		return
	if game.agents[pid].choose_yes_no(game, pid,
			"Pay {1} for %s to gain 1 life?" % source.data.card_name, true) \
			and game.try_pay(pid, cost):
		game.adjust_life(pid, 1)
