extends CardScript
## Paralyze — {B} — Enchantment — Aura (2ed, common)
## Oracle: Enchant creature. When Paralyze enters the battlefield, tap
##         enchanted creature. Enchanted creature doesn't untap during its
##         controller's untap step. At the beginning of the upkeep of
##         enchanted creature's controller, that player may pay {4}. If the
##         player does, untap the creature.
##
## Implementation, piece by piece:
## - ETB tap: an ENTERS_BATTLEFIELD trigger on itself taps the host.
## - Untap lock: static setting the host's cur_skips_untap (Meekstone infra).
## - The {4} escape: an upkeep trigger asking the host controller's
##   DecisionAgent (choose_yes_no, hinted by affordability), paid through
##   MtgGame.try_pay — floating mana first, then auto-tapped lands (that
##   helper's engine-wide limits are documented in docs/ROADMAP.md).
## THE dos486-guide tech card — the AI famously always pays the {4}; ours
## pays when it can afford it, which is already smarter than 1997.


func build() -> CardData:
	return CardData.new("Paralyze", "{B}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _tap_host_on_etb,
			"When Paralyze enters the battlefield, tap enchanted creature.",
			_is_self_etb)) \
		.static_ability(StaticAbility.new(
			_lock_host, "Enchanted creature doesn't untap during its controller's untap step.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _offer_payment,
			"At the beginning of the upkeep of enchanted creature's controller, that player may pay {4} to untap it.",
			_is_host_controllers_upkeep)) \
		.oracle("Enchant creature. When Paralyze enters the battlefield, tap enchanted creature. Enchanted creature doesn't untap during its controller's untap step. At the beginning of the upkeep of enchanted creature's controller, that player may pay {4}. If the player does, untap the creature.")


static func _is_self_etb(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _tap_host_on_etb(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		game.tap_permanent(host)


static func _lock_host(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.cur_skips_untap = true


static func _is_host_controllers_upkeep(game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	if source.attached_to == -1:
		return false
	var host := game.find_instance(source.attached_to)
	return host != null and host.zone == Mtg.Zone.BATTLEFIELD \
		and host.controller_id == event.data["player"]


static func _offer_payment(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD or not host.tapped:
		return
	var pid: int = event.data["player"]
	var cost := ManaCost.parse("{4}")
	if not game.can_afford_cost(pid, cost):
		return
	if game.agents[pid].choose_yes_no(game, pid,
			"Pay {4} to untap %s?" % host.data.card_name, true) \
			and game.try_pay(pid, cost):
		game.untap_permanent(host)
