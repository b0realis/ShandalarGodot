extends CardScript
## Puppet Master — {U}{U}{U} — Enchantment — Aura — (leg, uncommon)
## Oracle: Enchant creature
##         When enchanted creature dies, return that card to its owner's
##         hand. If that card is returned to its owner's hand this way, you
##         may pay {U}{U}{U}. If you do, return this card to its owner's
##         hand.
##
## Implementation: a reusable Aura that buys its host back. The DIES event
## is dispatched before state-based actions bury the orphaned Aura, so the
## Aura is still on the battlefield to hear its own host die; by the time
## the trigger RESOLVES both cards are in graveyards, which is exactly
## where the two returns pick them up.
##
## The buy-back is conditional on the FIRST return actually happening
## ("if that card is returned to its owner's hand this way"): a host that
## was replaced on its way to the graveyard, exiled, or already moved on is
## not returned, and then the Aura stays dead too.


func build() -> CardData:
	return CardData.new("Puppet Master", "{U}{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DIES, _pull_the_strings,
			"When enchanted creature dies, return that card to its owner's hand. If that card is returned to its owner's hand this way, you may pay {U}{U}{U}. If you do, return this card to its owner's hand.",
			_host_died)) \
		.oracle("Enchant creature\n"
			+ "When enchanted creature dies, return that card to its owner's hand. If that "
			+ "card is returned to its owner's hand this way, you may pay {U}{U}{U}. If you "
			+ "do, return this card to its owner's hand.")


static func _host_died(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	var dead: CardInstance = event.data["instance"]
	return dead != null and source.attached_to == dead.id


static func _pull_the_strings(game: MtgGame, source: CardInstance,
		event: GameEvent) -> void:
	var dead: CardInstance = event.data["instance"]
	if dead == null or dead.zone != Mtg.Zone.GRAVEYARD or dead.is_token:
		return
	game.return_from_graveyard_to_hand(dead)
	# "If that card is returned to its owner's hand THIS WAY" — verified,
	# not assumed: a replacement could have sent it somewhere else.
	if dead.zone != Mtg.Zone.HAND:
		return
	if source.zone != Mtg.Zone.GRAVEYARD or source.is_token:
		return
	# The Aura is already in a graveyard, where CardInstance reset its
	# controller to its owner (CR 400.3) — and nothing in this pool can
	# steal an enchantment, so the two were the same anyway.
	var pid := source.owner_id
	var cost := ManaCost.parse("{U}{U}{U}")
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid,
				"Pay {U}{U}{U} to take %s back?" % source.data.card_name, true) \
			and game.try_pay(pid, cost):
		game.return_from_graveyard_to_hand(source)
