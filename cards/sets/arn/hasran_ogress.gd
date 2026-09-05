extends CardScript
## Hasran Ogress — {B}{B} — Creature — Ogre — 3/2 — (arn, common)
## Oracle: Whenever this creature attacks, it deals 3 damage to you unless
##         you pay {2}.
##
## Implementation: an attack tax — DECLARED_ATTACKERS trigger gated on the
## ogress being among them; resolving offers {2} via try_pay, else the
## ogress bites its own controller for 3. The trigger resolves whatever
## became of the Ogress meanwhile (CR 603.6): sacrificing her in response
## does not refund the tax, and the damage is dealt by her last known
## existence (CR 608.2h).


func build() -> CardData:
	return CardData.new("Hasran Ogress", "{B}{B}", Mtg.CardType.CREATURE) \
		.pt(3, 2) \
		.with_subtypes(["ogre"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DECLARED_ATTACKERS, _tax,
			"Whenever this creature attacks, it deals 3 damage to you unless you pay {2}.",
			_self_attacks)) \
		.oracle("Whenever this creature attacks, it deals 3 damage to you unless you pay {2}.")


static func _self_attacks(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return (event.data["attackers"] as Array).has(source)


static func _tax(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var pid := source.controller_id
	var cost := ManaCost.parse("{2}")
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid,
				"Pay {2} to appease %s?" % source.data.card_name, true) \
			and game.try_pay(pid, cost):
		return
	game.deal_damage(source, TargetRef.player(pid), 3)
