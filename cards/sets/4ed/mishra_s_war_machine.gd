extends CardScript
## Mishra's War Machine — {7} — Artifact Creature — Juggernaut — 5/5 — (4ed, rare)
## Oracle: Banding (Any creatures with banding, and up to one without, can
##         attack in a band. Bands are blocked as a group. If any creatures
##         with banding you control are blocking or being blocked by a
##         creature, you divide that creature's combat damage, not its
##         controller, among any of the creatures it's being blocked by or
##         is blocking.)
##         At the beginning of your upkeep, this creature deals 3 damage to
##         you unless you discard a card. If it deals damage to you this
##         way, tap it.
##
## Implementation: a banding 5/5 whose upkeep asks for a card. The
## discard is the controller's choice ("unless YOU discard a card"), so the
## offer goes through choose_yes_no and the card itself through
## choose_discard — the same pair Disrupting Scepter and Mind Bomb use.
## The tap rides on what MtgGame.deal_damage actually DEALT: "if it deals
## damage to you this way" is false when a Circle of Protection ate the
## whole event, so a fully prevented ping leaves the Machine untapped.


func build() -> CardData:
	return CardData.new("Mishra's War Machine", "{7}",
			Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(5, 5) \
		.with_subtypes(["juggernaut"]) \
		.with_keywords([Mtg.Keyword.BANDING]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _feed,
			"At the beginning of your upkeep, this creature deals 3 damage to you unless you discard a card. If it deals damage to you this way, tap it.",
			_own_upkeep)) \
		.oracle("Banding (Any creatures with banding, and up to one without, can attack in a band. "
			+ "Bands are blocked as a group. If any creatures with banding you control are blocking "
			+ "or being blocked by a creature, you divide that creature's combat damage, not its "
			+ "controller, among any of the creatures it's being blocked by or is blocking.)\n"
			+ "At the beginning of your upkeep, this creature deals 3 damage to you unless you "
			+ "discard a card. If it deals damage to you this way, tap it.")


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _feed(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var pid := int(event.data["player"])
	# Default hint: feed it. A tapped War Machine cannot attack, which is
	# the whole point of a seven-mana 5/5 — so a card is worth paying while
	# there is one to spare, and the last card in hand only while the three
	# damage actually threatens.
	var hint: bool = game.players[pid].hand.size() >= 2 or game.players[pid].life <= 6
	if not game.players[pid].hand.is_empty() and game.agents[pid].choose_yes_no(
			game, pid, "Discard a card to %s?" % source.data.card_name, hint):
		game.discard_cards(pid, game.agents[pid].choose_discard(game, pid, 1))
		return
	# The tap is the consequence of the damage ACTUALLY landing, so it
	# waits for the packet under the 1997 window (§6.8); with the window
	# off the callback runs inside deal_damage and this is unchanged.
	game.deal_damage(source, TargetRef.player(pid), 3, false,
		func(dealt: int) -> void:
			if dealt > 0 and source.zone == Mtg.Zone.BATTLEFIELD:
				game.tap_permanent(source))
