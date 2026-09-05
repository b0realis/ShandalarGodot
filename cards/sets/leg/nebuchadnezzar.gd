extends CardScript
## Nebuchadnezzar — {3}{U}{B} — Legendary Creature — Human Wizard — 3/3 — (leg, rare)
## Oracle: {X}, {T}: Choose a card name. Target opponent reveals X cards at
##         random from their hand. Then that player discards all cards with
##         that name revealed this way. Activate only during your turn.
##
## Implementation: the name is chosen by the ACTIVATOR before anything is
## revealed (DecisionAgent.choose_option), the reveal is X different cards
## drawn from the hand through RandomEffects.sample — so a seeded duel
## replays it exactly — and every revealed card with that name is discarded.
## Cards revealed and not discarded stay in hand: revealing is not drawing.
##
## SIMPLIFIED (docs/simplified-cards.md, "Nebuchadnezzar"): the engine has
## no free-text card naming, so the option list is bounded, exactly as it is
## for Petra Sphinx. WHAT MAY BE NAMED here is every distinct name in the
## target opponent's LIBRARY, GRAVEYARD, BATTLEFIELD and EXILE — their deck,
## minus the one zone that would be cheating to read. Their HAND is
## deliberately excluded from the list, which is the anti-cheat guarantee:
## the namer can never be shown that the card is there. The cost is that a
## name whose every copy is already in hand cannot be named at all, and that
## is the honest direction to err in.
##
## The list is ordered by how many copies of each name the deck still holds,
## so the heuristic agent's "first option" is the best guess a player could
## make from public information.
##
## mage-go registers Nebuchadnezzar as a vanilla 3/3 and lists it
## unimplemented; there is no `@NEBUCHADNEZZAR` prompt in the 1997 tables
## either, Legends having arrived with the expansion.


func build() -> CardData:
	return CardData.new("Nebuchadnezzar", "{3}{U}{B}", Mtg.CardType.CREATURE) \
		.pt(3, 3) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "wizard"]) \
		.activated(ActivatedAbility.new(
			"{X}", true, [NameEffect.new()],
			"{X}, {T}: Choose a card name. Target opponent reveals X cards at "
			+ "random from their hand, then discards all cards with that name.") \
			.your_turn_only()) \
		.oracle("{X}, {T}: Choose a card name. Target opponent reveals X cards at "
			+ "random from their hand. Then that player discards all cards with "
			+ "that name revealed this way. Activate only during your turn.")


class NameEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.opponent()

	## The names the activator may choose from: [param pid]'s deck as it can
	## be SEEN — library, graveyard, battlefield and exile, never the hand.
	## Most copies first, alphabetical within a tie, so the order is
	## deterministic and the heuristic's first pick is the best guess.
	static func nameable(game: MtgGame, pid: int) -> Array[String]:
		var counts: Dictionary = {}
		var p := game.players[pid]
		for zone in [p.library, p.graveyard, p.battlefield, p.exile]:
			for inst in zone:
				if inst.is_token:
					continue   # a token has no card name to be named
				var n: String = inst.data.card_name
				counts[n] = int(counts.get(n, 0)) + 1
		var names: Array[String] = []
		for n in counts:
			names.append(n)
		names.sort_custom(func(a: String, b: String) -> bool:
			if int(counts[a]) != int(counts[b]):
				return int(counts[a]) > int(counts[b])
			return a < b)
		return names

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, x_value: int = 0) -> void:
		var pid := target.player_id
		if x_value <= 0 or game.players[pid].hand.is_empty():
			return
		# SIMPLIFIED: the option list is the opponent's visible deck (header).
		var names := NameEffect.nameable(game, pid)
		if names.is_empty():
			game.log_line("%s has nothing Nebuchadnezzar could name"
				% game.players[pid].player_name)
			return
		var picked: int = game.agents[controller].choose_option(game, controller,
			names, "Name a card — Nebuchadnezzar", 0)
		if picked < 0:
			return
		var named: String = names[picked]
		# "reveals X cards at random from their hand" — X DIFFERENT cards.
		var revealed := RandomEffects.sample(game, game.players[pid].hand, x_value)
		var shown := PackedStringArray()
		var doomed: Array[CardInstance] = []
		for inst in revealed:
			shown.append(inst.data.card_name)
			if inst.data.card_name == named:
				doomed.append(inst)
		game.log_line("%s names %s; %s reveals %s" % [
			game.players[controller].player_name, named,
			game.players[pid].player_name, ", ".join(shown)])
		if doomed.is_empty():
			return
		game.discard_cards(pid, doomed)

	func describe() -> String:
		return "target opponent reveals X cards at random and discards the named ones"
