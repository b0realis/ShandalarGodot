extends CardScript
## Takklemaggot — {2}{B}{B} — Enchantment — Aura — (leg, uncommon)
## Oracle: Enchant creature
##         At the beginning of the upkeep of enchanted creature's
##         controller, put a -0/-1 counter on that creature.
##         When enchanted creature dies, that creature's controller chooses
##         a creature that this card could enchant. If the player does,
##         return this card to the battlefield under your control attached
##         to that creature. If they don't, return this card to the
##         battlefield under your control as a non-Aura enchantment. …
##
## Implementation: the wasting clause is a real -0/-1 counter each upkeep,
## and the plague really spreads — when the host dies the Maggot comes back
## out of the graveyard onto another creature, still under YOUR control.
##
## WHO chooses: "that creature's CONTROLLER chooses a creature that this
## card could enchant" — so the jump is offered to the VICTIM's own agent
## (choose_card, optional: "IF the player does"), over EVERY creature the
## Maggot's own enchant spec accepts on EITHER side of the table —
## protection from black (CR 702.16e) rules a body out, and the Maggot
## controller's own creatures are on the list, which is exactly where the
## victim would send it. The list is ordered from the victim's point of
## view: the Maggot controller's creatures first, best first, then the
## victim's own, worst first; the heuristic takes the head of the list
## and never declines (Manalink's card_takklemaggot offers no cancel at
## all when a legal creature exists — allow_cancel = 0). A human may.
##
## If they don't — nothing legal, or they declined — "return this card to
## the battlefield under your control as a non-Aura enchantment"
## (MtgGame.return_aura_unattached): it sits attached to nothing with
## CardInstance.lost_enchant set, the orphaned-Aura state-based action (CR
## 704.5m) leaves it alone, the wasting trigger has no host to find, and
## the granted "at the beginning of THAT player's upkeep, deals 1 damage
## to that player" is the third trigger below, keyed on the victim the
## Maggot remembers (memory["victim"]) for as long as it stays on the
## battlefield (CR 400.7 wipes both when it leaves). Lifted 2026-09-02;
## it used to stay in the graveyard and only offer the victim's own
## creatures.


func build() -> CardData:
	return CardData.new("Takklemaggot", "{2}{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _waste_the_host,
			"At the beginning of the upkeep of enchanted creature's controller, put a -0/-1 counter on that creature.",
			_hosts_upkeep)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DIES, _spread,
			"When enchanted creature dies, that creature's controller chooses a creature this card could enchant; return this card to the battlefield attached to it, or as a non-Aura enchantment.",
			_host_died)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _ping_the_victim,
			"At the beginning of that player's upkeep, this enchantment deals 1 damage to that player.",
			_victims_upkeep)) \
		.oracle("Enchant creature\nAt the beginning of the upkeep of enchanted creature's controller, put a -0/-1 counter on that creature.\nWhen enchanted creature dies, that creature's controller chooses a creature that this card could enchant. If the player does, return this card to the battlefield under your control attached to that creature. If they don't, return this card to the battlefield under your control as a non-Aura enchantment. It loses \"enchant creature\" and gains \"At the beginning of that player's upkeep, this enchantment deals 1 damage to that player.\"")


static func _hosts_upkeep(game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	if source.attached_to == -1:
		return false
	var host := game.find_instance(source.attached_to)
	return host != null and host.zone == Mtg.Zone.BATTLEFIELD \
		and int(event.data["player"]) == host.controller_id


## The granted ability of the non-Aura Maggot only: "that player" is the
## controller of the creature that died.
static func _victims_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return source.lost_enchant and source.memory.has("victim") \
		and int(event.data["player"]) == int(source.memory["victim"])


static func _host_died(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	# The condition is checked while the Maggot is still attached, before
	# the orphaned-aura state-based action sweeps it away.
	var dead: CardInstance = event.data.get("instance")
	return dead != null and source.attached_to == dead.id


static func _waste_the_host(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	game.add_counters(host, "-0/-1", 1)


static func _ping_the_victim(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD or not source.lost_enchant:
		return
	game.deal_damage(source, TargetRef.player(int(event.data["player"])), 1)


static func _spread(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	# The DIES event carries the dead creature's controller — the Maggot's
	# own memory is already wiped by the time this resolves.
	var victim := int(event.data.get("controller", -1))
	if victim < 0 or source.zone != Mtg.Zone.GRAVEYARD:
		return
	# "a creature that this card COULD ENCHANT" — the Maggot's own enchant
	# spec answers that, protection and aura bans included, on EITHER side.
	var spec: TargetSpec = source.data.aura_target
	var candidates: Array[CardInstance] = []
	for inst in game.all_battlefield():
		if spec.is_legal(game, TargetRef.card(inst), source):
			candidates.append(inst)
	var host: CardInstance = null
	if not candidates.is_empty():
		# The VICTIM chooses: the Maggot controller's creatures first (their
		# best first), then the victim's own, worst first — the head of the
		# list is what their heuristic takes.
		candidates.sort_custom(_victims_order.bind(victim))
		host = game.agents[victim].choose_card(game, victim, candidates,
			"Takklemaggot: choose a creature for the plague to move to, or none",
			true, true)
		if host != null and not candidates.has(host):
			host = candidates[0]
	if host != null:
		game.attach_aura_from_anywhere(source, host, source.owner_id)
		return
	# "If they don't, return this card to the battlefield under your
	# control as a non-Aura enchantment."
	if not game.return_aura_unattached(source, source.owner_id):
		return
	source.memory["victim"] = victim


## From the VICTIM's point of view: the Maggot controller's creatures
## first (their best first), then the victim's own, worst first.
static func _victims_order(a: CardInstance, b: CardInstance, victim: int) -> bool:
	var a_mine := a.controller_id == victim
	var b_mine := b.controller_id == victim
	if a_mine != b_mine:
		return b_mine
	var va := a.cur_power + a.cur_toughness
	var vb := b.cur_power + b.cur_toughness
	if va != vb:
		return va < vb if a_mine else va > vb
	return a.id < b.id
