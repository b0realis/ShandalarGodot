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
## WHAT MAY BE NAMED: the target opponent's DECKLIST (MtgPlayer.deck_names
## — what they brought to the duel, known before the first draw), each
## name once, through the ordinary option prompt. The owner's ruling of
## 2026-09-07: *"When you have name a card: you should probably only
## display selection of cards from opponents deck (as you can see the deck
## beforehand in real mtg)... you should be presented with a limited list
## so make things as simple as possible."* There is no free-text naming
## and no long list of every name in the pool: a card the opponent never
## brought cannot be in their hand (a card wished in from outside the game
## joins the decklist when its arrival is announced), so nothing that can
## matter in this pool is left unsayable. Nothing leaks either — the list
## is the same whatever is in the hand, which is the anti-cheat guarantee
## the old list bought by scanning the library, graveyard, battlefield and
## exile and skipping the hand (until 2026-09-07); that scan read the
## library, which is hidden too, and could not say a name whose every copy
## was already in hand.
##
## The list is ordered by how many copies are still UNACCOUNTED FOR — the
## decklist's count minus the copies in the graveyard, on the battlefield
## and in exile, the zones anyone can see — most first, alphabetical within
## a tie: the copies not yet seen are the ones that can be in the hand, so
## the heuristic agent's "first option" is the best guess a player could
## make from public information.
##
## mage-go registers Nebuchadnezzar as a vanilla 3/3 and lists it
## unimplemented; there is no `@NEBUCHADNEZZAR` prompt in the 1997 tables
## either, Legends having arrived with the expansion. The Manalink rewrite
## (`card_nebuchadnezzar`, legends.c) has the human pick from the whole
## card list and the AI name a random card of the target's library.


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

	## The names the activator may choose from: [param pid]'s DECKLIST, each
	## once. Most copies unaccounted for first — the deck's count less the
	## copies in a zone anyone can see (graveyard, battlefield, exile,
	## whoever controls them) — alphabetical within a tie, so the order is
	## deterministic and the heuristic's first pick is the best guess.
	static func nameable(game: MtgGame, pid: int) -> Array[String]:
		var hidden: Dictionary = {}   # name -> copies not in a public zone
		for n in game.players[pid].deck_names:
			hidden[n] = int(hidden.get(n, 0)) + 1
		for q in game.players:
			for zone in [q.graveyard, q.battlefield, q.exile]:
				for inst in zone:
					if inst.is_token or inst.owner_id != pid:
						continue   # a token has no card name; theirs only
					var n: String = inst.data.card_name
					if hidden.has(n):
						hidden[n] = maxi(int(hidden[n]) - 1, 0)
		var names: Array[String] = []
		for n in hidden:
			names.append(n)
		names.sort_custom(func(a: String, b: String) -> bool:
			if int(hidden[a]) != int(hidden[b]):
				return int(hidden[a]) > int(hidden[b])
			return a < b)
		return names

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, x_value: int = 0) -> void:
		var pid := target.player_id
		if x_value <= 0 or game.players[pid].hand.is_empty():
			return
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
