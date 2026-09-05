extends CardScript
## Farmstead — {W}{W}{W} — Enchantment — Aura — (2ed, rare)
## Oracle: Enchant land
##         Enchanted land has "At the beginning of your upkeep, you may pay
##         {W}{W}. If you do, you gain 1 life."
##
## Implementation: the granted ability is modelled as the Aura's own upkeep
## trigger, keyed to the LAND's controller — which is who the granted
## ability would belong to. Paying goes through the engine's usual
## triggered-payment path.
##
## The rent is a real QUESTION, asked of the paying seat through its own
## DecisionAgent: the human seat is held open on it (docs/duel-todo.md
## §1.3) and every other seat answers for itself. The `hint` below is
## only the default answer, not a decision the engine takes.


static func _is_land(inst: CardInstance) -> bool:
	return inst.is_land()


func build() -> CardData:
	return CardData.new("Farmstead", "{W}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _is_land)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _harvest,
			"At the beginning of the enchanted land's controller's upkeep, they may pay {W}{W}. If they do, they gain 1 life.",
			_hosts_upkeep)) \
		.oracle("Enchant land\nEnchanted land has \"At the beginning of your upkeep, you may pay {W}{W}. If you do, you gain 1 life.\"")


static func _hosts_upkeep(game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	if source.attached_to == -1:
		return false
	var host := game.find_instance(source.attached_to)
	return host != null and host.zone == Mtg.Zone.BATTLEFIELD \
		and int(event.data["player"]) == host.controller_id


static func _harvest(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var pid := int(event.data["player"])
	var rent := ManaCost.parse("{W}{W}")
	if game.can_afford_cost(pid, rent) and game.agents[pid].choose_yes_no(
			game, pid, "Pay {W}{W} for a life?", true) and game.try_pay(pid, rent):
		game.adjust_life(pid, 1)
