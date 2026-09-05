extends CardScript
## Erosion — {U}{U}{U} — Enchantment — Aura — (4ed, common)
## Oracle: Enchant land
##         At the beginning of the upkeep of enchanted land's controller,
##         destroy that land unless that player pays {1} or 1 life.
##
## Implementation: an upkeep trigger gated on the HOST'S controller (not
## the aura's). The printed "{1} OR 1 life" is the VICTIM's choice, asked
## on resolution with the original's own three lines — `@EROSION`
## (Program/prompts.txt:306): "Destroy enchanted land." / "Pay 1 mana to
## counter." / "Pay 1 life." — through DecisionAgent.choose_option. The
## mana is paid through MtgGame.try_pay (auto-tapping, the way every
## "unless you pay" in the pool pays); the life through adjust_life,
## legal down to 0 (CR 119.4). A slow, inevitable land tax that the
## victim can always pay — until they can't.
##
## The heuristic pays the mana when it can, a life when it cannot and has
## more than one, and otherwise lets the land go. A mana answer the pool
## cannot cover is no payment at all, and the land goes.


func build() -> CardData:
	return CardData.new("Erosion", "{U}{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _is_land)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _erode,
			"At the beginning of the upkeep of enchanted land's controller, destroy "
			+ "that land unless that player pays {1} or 1 life.",
			_hosts_upkeep)) \
		.oracle("Enchant land\nAt the beginning of the upkeep of enchanted land's "
			+ "controller, destroy that land unless that player pays {1} or 1 life.")


static func _is_land(inst: CardInstance) -> bool:
	return inst.is_land()


static func _hosts_upkeep(game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	var host := game.find_instance(source.attached_to)
	return host != null and host.zone == Mtg.Zone.BATTLEFIELD \
		and int(event.data["player"]) == host.controller_id


const WAYS: Array[String] = ["Destroy enchanted land.", "Pay 1 mana to counter.", "Pay 1 life."]
const GIVE_UP := 0
const PAY_MANA := 1
const PAY_LIFE := 2


static func _erode(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := host.controller_id
	var cost := ManaCost.parse("{1}")
	var hint := GIVE_UP
	if game.can_afford_cost(pid, cost):
		hint = PAY_MANA
	elif game.players[pid].life > 1:
		hint = PAY_LIFE
	var way: int = game.agents[pid].choose_option(game, pid, WAYS,
		"Erosion: destroy the land unless you pay {1} or 1 life?", hint)
	if way == PAY_MANA and game.can_afford_cost(pid, cost) and game.try_pay(pid, cost):
		return
	if way == PAY_LIFE:
		game.adjust_life(pid, -1)
		return
	game.destroy(host)   # gave it up — or named a mana payment that was not there
