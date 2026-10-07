extends CardScript
## Petra Sphinx — {2}{W}{W}{W} — Creature — Sphinx — 3/4 — (leg, rare)
## Oracle: {T}: Target player chooses a card name, then reveals the top
##         card of their library. If that card has the chosen name, that
##         player puts it into their hand. If it doesn't, the player puts
##         it into their graveyard.
##
## Implementation: the TARGET player names the card, so the question goes
## to THEIR agent (DecisionAgent.choose_option), and the same player takes
## the consequence either way — aim it at yourself for card selection, at
## an opponent to mill them.
##
## WHAT MAY BE NAMED: the chooser's own DECKLIST (MtgPlayer.deck_names —
## what they brought to the duel, known before the first draw), each name
## once, through the ordinary option prompt. The owner's ruling of
## 2026-09-07: *"When you have name a card: you should probably only
## display selection of cards from opponents deck (as you can see the deck
## beforehand in real mtg)... you should be presented with a limited list
## so make things as simple as possible."* There is no free-text naming
## and no long list of every name in the pool: a name outside one's own
## deck can never be on top of one's own library (a card always returns
## to its OWNER's library, CR 400.3), so nothing that can matter in this
## pool is left unsayable. Until 2026-09-07 the list was the names still
## IN the library, which could not say a card whose every copy was drawn.
##
## The hint counts the registered list minus cards the chooser can see,
## never scanning the library. Unknown departures remain uncertainty,
## not permission to inspect hidden zones (docs/fair-play.md).
##
## The card goes to the hand WITHOUT being drawn (MtgGame.
## top_of_library_to_hand, CR 121.8) — Underworld Dreams must stay quiet.
##
## mage-go deviates: it registers Petra Sphinx as a vanilla 3/4 and lists
## it unimplemented ("needs engine support for card naming and reveal").
## Duel.hlp does not cover it — the shipped help file is the base game's
## pool, and Legends arrived with the expansion.


func build() -> CardData:
	return CardData.new("Petra Sphinx", "{2}{W}{W}{W}", Mtg.CardType.CREATURE) \
		.pt(3, 4) \
		.with_subtypes(["sphinx"]) \
		.activated(ActivatedAbility.new(
			"", true,
			[RiddleEffect.new()],
			"{T}: Target player chooses a card name, then reveals the top card of "
			+ "their library.")) \
		.oracle("{T}: Target player chooses a card name, then reveals the top card "
			+ "of their library. If that card has the chosen name, that player puts "
			+ "it into their hand. If it doesn't, the player puts it into their "
			+ "graveyard.")


class RiddleEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()

	## The names in the chooser's own DECKLIST, each once — most copies
	## not accounted for first, alphabetical within a tie.
	static func nameable(game: MtgGame, pid: int) -> Array[String]:
		var left := unaccounted(game, pid)
		var names: Array[String] = []
		for n in left:
			names.append(n)
		names.sort_custom(func(a: String, b: String) -> bool:
			if int(left[a]) != int(left[b]):
				return int(left[a]) > int(left[b])
			return a < b)
		return names

	## name -> copies of [param pid]'s DECKLIST not accounted for by a card
	## [param pid] can see (their hand; every face-up card on a battlefield,
	## in a graveyard, in exile or in the ante) — never the library itself.
	static func unaccounted(game: MtgGame, pid: int) -> Dictionary:
		var p := game.players[pid]
		var left: Dictionary = {}
		for n in p.deck_names:
			left[n] = int(left.get(n, 0)) + 1
		var known: Array = p.hand.duplicate()
		for player in game.players:
			for zone in [player.battlefield, player.graveyard, player.exile, player.ante]:
				for inst in zone:
					if not inst.face_down:
						known.append(inst)
		for inst in known:
			if inst.is_token or inst.owner_id != pid: continue
			var n: String = inst.data.card_name
			if left.has(n): left[n] = maxi(int(left[n]) - 1, 0)
		return left

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var pid := target.player_id
		if game.players[pid].library.is_empty():
			return   # an empty library: nothing to reveal
		var names := nameable(game, pid)
		# No decklist to name from (a bare test game): the name said is one
		# the top card cannot have, and the reveal is a miss.
		var named := ""
		if not names.is_empty():
			var picked: int = game.agents[pid].choose_option(game, pid, names,
				"Name a card — Petra Sphinx reveals the top of your library", 0)
			if picked < 0:
				return
			named = names[picked]
		var top: CardInstance = game.players[pid].library.back()
		game.reveal_information(-1, "Petra Sphinx — revealed card", [top.data.card_name])
		game.log_line("%s names %s; %s reveals %s" % [
			game.players[pid].player_name, named,
			source.data.card_name, top.data.card_name])
		if top.data.card_name == named:
			game.top_of_library_to_hand(pid)
		else:
			game.mill(pid, 1)

	func describe() -> String:
		return "target player names a card and reveals their top card"
