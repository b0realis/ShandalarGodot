class_name EchoAbility
extends RefCounted
## ECHO (CR 702.30a, Pack 10 E1): "At the beginning of your upkeep, if this
## permanent came under your control since the beginning of your last
## upkeep, sacrifice it unless you pay [cost]." Thirty-four Urza block
## cards; the 1998 printing's "bury" is a sacrifice (CR 701.17a), so a
## regeneration shield never saves an unpaid echo permanent.
##
## Built on [CumulativeUpkeep]'s shape: ONE printed triggered ability on the
## card (so a copy has it, CR 707.2, and Humility's "loses all abilities"
## silences it, CR 613.1f), triggering on UPKEEP_START with an INTERVENING
## IF (CR 603.4) that is checked twice — as the upkeep begins and again as
## the trigger resolves.
##
## THE CLOCK. "Came under your control since the beginning of your last
## upkeep" is a fact about the past, and the engine keeps it as two
## integers: every seat counts the upkeeps it has begun
## ([member MtgPlayer.upkeeps_begun], bumped just before UPKEEP_START is
## dispatched), and every permanent remembers that count of its controller
## at the moment it came under that controller's control
## ([member CardInstance.control_upkeep_mark], written by the two doors
## every such moment passes through: [method MtgGame._put_on_battlefield]
## and [method MtgGame._set_controller]). The question is then
## [method MtgGame.came_under_control_since_last_upkeep]: was the mark taken
## at or after the start of the seat's previous upkeep? Consequences, each
## the printed rule's:
## - due at the first upkeep after it arrives, never the second;
## - one that arrives DURING your upkeep (after its triggers) is due at the
##   next one;
## - a control change (Control Magic, an exchange, a borrow and its return)
##   makes the NEW controller owe it at their next upkeep, the old owes none;
## - leaving and returning is a new object (CR 400.7) and owes it again;
## - phasing is neither entering nor a control change (CR 702.26d): a
##   phased-out echo permanent keeps its mark and owes nothing new;
## - a Vesuvan Doppelganger that turns into a copy of an echo creature at
##   upkeep did not come under anyone's control and owes nothing.
## A permanent placed by a hand-built test position (Test hands) has no
## mark at all, so it is not due unless the position says so.
##
## The payment is [method MtgGame.try_pay] with the usage key "echo": it
## spends floating mana first and auto-taps the rest (the cumulative-upkeep
## simplification — the payer does not choose which sources, ROADMAP). A
## seat that cannot pay is not asked; a seat that declines, or whose
## payment goes stale, sacrifices it.

const USAGE := ["echo"]


## The one echo trigger of a card, telling the AI and the help readers its
## cost without reading the printed text.
class EchoTrigger extends TriggeredAbility:
	var echo_cost := ""


## Give [param card] "Echo [param cost]". The echo cost may differ from the
## mana cost; it never does in the Urza block, but the API takes it.
static func attach(card: CardData, cost: String) -> CardData:
	return card.triggered(ability(cost))


static func ability(cost: String) -> EchoTrigger:
	var trig := EchoTrigger.new(Mtg.EventType.UPKEEP_START, _resolve.bind(cost),
		"Echo %s (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)" % cost,
		_due)
	trig.echo_cost = cost
	trig.capturing(_capture)
	return trig


## The echo cost [param inst] has NOW (its live abilities: a copy has the
## copied echo, a permanent under Humility has none), or "" for none. With
## two echo abilities the first is named.
static func echo_cost(inst: CardInstance) -> String:
	if inst == null:
		return ""
	var abilities: Array[TriggeredAbility] = inst.cur_triggered_abilities
	if inst.zone != Mtg.Zone.BATTLEFIELD:
		abilities = inst.data.triggered_abilities
	for trig in abilities:
		if trig is EchoTrigger:
			return (trig as EchoTrigger).echo_cost
	return ""


static func has_echo(inst: CardInstance) -> bool:
	return echo_cost(inst) != ""


## Will [param inst]'s controller be asked for its echo at their NEXT
## upkeep? Public: the mark and the count are both open information (the
## permanent arrived in plain sight). An AI deciding whether to cast,
## block with or bounce an echo permanent reads this; so may a front end
## that wants to badge it.
static func due_next_upkeep(g: MtgGame, inst: CardInstance) -> bool:
	if not has_echo(inst) or inst.zone != Mtg.Zone.BATTLEFIELD \
			or inst.control_upkeep_mark < 0:
		return false
	return inst.control_upkeep_mark >= g.players[inst.controller_id].upkeeps_begun


## The trigger condition (CR 603.4 — checked as the upkeep begins): YOUR
## upkeep, and the permanent came under your control since the beginning
## of your last one.
static func _due(g: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data.get("player", -1)) == source.controller_id \
		and g.came_under_control_since_last_upkeep(source)


static func _capture(_g: MtgGame, source: CardInstance, _event: GameEvent) -> Dictionary:
	return {"timestamp": source.layer_timestamp, "controller": source.controller_id}


## CR 603.4 again, on resolution: the very object that triggered (CR 400.7)
## and phased in (CR 702.26b), still controlled by the player whose upkeep
## it was — one cannot sacrifice what one does not control (CR 701.17a), so
## a permanent stolen in response asks nobody anything — and still having
## come under that player's control since their last upkeep.
static func _still_owed(g: MtgGame, source: CardInstance, context: Dictionary) -> bool:
	return g.is_present(source) \
		and source.layer_timestamp == int(context.get("timestamp", -1)) \
		and source.controller_id == int(context.get("controller", -1)) \
		and g.came_under_control_since_last_upkeep(source)


static func _resolve(g: MtgGame, source: CardInstance, _event: GameEvent, cost_text: String) -> void:
	var context := g.trigger_context(source)
	if not _still_owed(g, source, context):
		return
	var pid := source.controller_id
	var cost := ManaCost.parse(cost_text)
	var affordable := g.can_afford_cost(pid, cost, USAGE)
	var hint := affordable and g.agents[pid].echo_hint(g, pid, source, cost)
	var prompt := "Pay echo %s for %s? If you don't, sacrifice it." % [
		cost.text if cost.text != "" else "{0}", source.data.card_name]
	if affordable and g.agents[pid].choose_yes_no(g, pid, prompt, hint) \
			and g.try_pay(pid, cost, USAGE):
		g.log_line("%s pays echo for %s" % [g.players[pid].player_name,
			source.data.card_name], source)
		return
	g.log_line("%s doesn't pay echo for %s" % [g.players[pid].player_name,
		source.data.card_name], source)
	g.sacrifice_permanent(source)
