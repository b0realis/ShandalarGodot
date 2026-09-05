extends CardScript
## Power Leak — {1}{U} — Enchantment — Aura — (2ed, common)
## Oracle: Enchant enchantment
##         At the beginning of the upkeep of enchanted enchantment's
##         controller, that player may pay any amount of mana. This Aura
##         deals 2 damage to that player. Prevent X of that damage, where X
##         is the amount of mana that player paid this way.
##
## Implementation: the Warp Artifact aura shape, on an ENCHANTMENT, with a
## rent the victim can buy out of. The amount is a real question
## (DecisionAgent.choose_number), asked of the HOST's controller — never
## the Aura's — and capped at 2: the oracle lets a player pay more, but the
## third mana prevents nothing, and the original's own text already reads
## *"That player may pay up to {2} to prevent that amount of damage dealt
## to him or her by Power Leak"* (Duel.hlp, Power Leak).
##
## SIMPLIFIED (docs/simplified-cards.md, "Power Leak"): that {2} cap.
##
## The prevention is applied at the SOURCE — the Aura deals `2 - X` — rather
## than through MtgPlayer.damage_prevention. That is not a shortcut, it is
## the more faithful of the two: the shared prevention pool is consulted
## AFTER Circle-of-Protection shields (MtgGame.deal_damage), so a player
## holding a Circle of Protection: Blue would have the Circle eat the whole
## 2 and leave X floating to soak an unrelated burn spell later in the turn.
## Dealing the reduced amount leaves no residue and every other interaction
## reads the same.
##
## THE HEURISTIC pays only when the victim is at 10 life or less. Two mana
## every upkeep is a far worse deal than two damage while the game is young
## — which is exactly the trade the card is built on — and the mana would
## come out of lands the victim wants for their own turn.


const RENT := 2


func build() -> CardData:
	var enchantment_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target enchantment",
		func(inst: CardInstance) -> bool:
			return inst.is_type(Mtg.CardType.ENCHANTMENT))
	return CardData.new("Power Leak", "{1}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(enchantment_spec) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _leak,
			"At the beginning of the upkeep of enchanted enchantment's controller, "
			+ "that player may pay any amount of mana. Power Leak deals 2 damage to "
			+ "that player, minus the amount paid.",
			_host_controllers_upkeep)) \
		.oracle("Enchant enchantment\nAt the beginning of the upkeep of enchanted "
			+ "enchantment's controller, that player may pay any amount of mana. This "
			+ "Aura deals 2 damage to that player. Prevent X of that damage, where X "
			+ "is the amount of mana that player paid this way.")


static func _host_controllers_upkeep(game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	if source.attached_to == -1:
		return false
	var host := game.find_instance(source.attached_to)
	return host != null and host.zone == Mtg.Zone.BATTLEFIELD \
		and host.controller_id == event.data["player"]


static func _leak(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	# CR 608.2h — the trigger resolves even if the Aura has fallen off; the
	# victim is the player the event named.
	var pid: int = event.data["player"]
	# SIMPLIFIED (docs/simplified-cards.md, "Power Leak"): capped at RENT.
	# Only the optional 1997 mana-burn rule can tell the difference.
	var most := 0
	for n in range(RENT, 0, -1):
		if game.can_afford_cost(pid, ManaCost.parse("{%d}" % n)):
			most = n
			break
	var paid := 0
	if most > 0:
		var want: int = most if game.players[pid].life <= 10 else 0
		var wish: int = game.agents[pid].choose_number(game, pid, 0, most,
			"Pay how much mana to prevent Power Leak's damage?", want)
		if wish > 0 and game.try_pay(pid, ManaCost.parse("{%d}" % wish)):
			paid = wish
	if paid < RENT:
		game.deal_damage(source, TargetRef.player(pid), RENT - paid)
