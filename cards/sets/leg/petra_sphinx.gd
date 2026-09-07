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
## The list is ordered by how many copies remain in the library, most
## first — a player knows what they have drawn, so that is their own
## information — and the heuristic's "first option" is the likeliest top
## card, as it was before.
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

	## The names in [param pid]'s DECKLIST, each once — most copies still
	## in the library first, alphabetical within a tie, so the order is
	## deterministic and the first is the likeliest top card.
	static func nameable(game: MtgGame, pid: int) -> Array[String]:
		var p := game.players[pid]
		var left: Dictionary = {}   # name -> copies still in the library
		for n in p.deck_names:
			left[n] = 0
		for inst in p.library:
			var n: String = inst.data.card_name
			if left.has(n):
				left[n] = int(left[n]) + 1
		var names: Array[String] = []
		for n in left:
			names.append(n)
		names.sort_custom(func(a: String, b: String) -> bool:
			if int(left[a]) != int(left[b]):
				return int(left[a]) > int(left[b])
			return a < b)
		return names

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
		game.log_line("%s names %s; %s reveals %s" % [
			game.players[pid].player_name, named,
			source.data.card_name, top.data.card_name])
		if top.data.card_name == named:
			game.top_of_library_to_hand(pid)
		else:
			game.mill(pid, 1)

	func describe() -> String:
		return "target player names a card and reveals their top card"
