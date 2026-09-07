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
## the Aura's — and bounded by what that player can pay RIGHT NOW: the
## floating pool plus every untapped mana source (MtgGame.can_afford_cost,
## probed upward one mana at a time). "Any amount" has no ceiling of its
## own, and this is the honest one. The third mana onward prevents nothing
## — the Aura deals 2 and the prevention is `min(paid, 2)` — but a player
## may still pay it: under the optional 1997 MANA BURN rule, dumping a
## bigger floating pool into the Aura is how the burn is dodged.
##
## [1997] The original's own text read *"That player may pay up to {2} to
## prevent that amount of damage dealt to him or her by Power Leak"*
## (Duel.hlp, Power Leak), and its prompt offered three answers — "Take
## the 2 damage." / "Pay 1 mana, take 1 damage." / "Pay 2 mana."
## (`@POWERLEAK`, prompts.txt). The engine kept that {2} cap until
## 2026-09-07; the printed card (and mage-go, which bounds the question
## by the hypothetical mana available) allows any amount.
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
	# "Any amount": the bound is what the victim can pay this moment.
	var most := _most_payable(game, pid)
	var paid := 0
	if most > 0:
		# The heuristic never pays past the rent — the third mana buys nothing
		# it wants (it does not play the mana-burn dodge).
		var want: int = mini(most, RENT) if game.players[pid].life <= 10 else 0
		var wish: int = game.agents[pid].choose_number(game, pid, 0, most,
			"Pay how much mana to prevent Power Leak's damage?", want)
		if wish > 0 and game.try_pay(pid, ManaCost.parse("{%d}" % wish)):
			paid = wish
	var prevented := mini(paid, RENT)
	if prevented < RENT:
		game.deal_damage(source, TargetRef.player(pid), RENT - prevented)


## The largest generic cost [param pid] can pay right now — floating mana
## and untapped sources together. Affordability of {n} is monotone in n,
## so the first {n+1} refused is the ceiling.
static func _most_payable(game: MtgGame, pid: int) -> int:
	var n := 0
	while game.can_afford_cost(pid, ManaCost.parse("{%d}" % (n + 1))):
		n += 1
	return n
