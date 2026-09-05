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
## SIMPLIFIED (docs/simplified-cards.md, "Petra Sphinx").
## WHAT MAY BE NAMED: the distinct card names in the chooser's own library.
## That is a bound, and it is the honest one — a player knows their own
## deck list and knows what they have already drawn, so the names left in
## their library are information they already have; and naming a card that
## cannot be there is never a play. The engine has no free-text naming and
## an option list of all 896 pool names would be neither playable nor
## answerable by an AI. The list is ordered by how many copies remain, so
## the heuristic's "first option" is the best guess a player could make.
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

	## The names in [param pid]'s library, most copies first and
	## alphabetical within a tie so the order is deterministic.
	static func nameable(game: MtgGame, pid: int) -> Array[String]:
		var counts: Dictionary = {}
		for inst in game.players[pid].library:
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

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var pid := target.player_id
		var names := nameable(game, pid)
		if names.is_empty():
			return   # an empty library: nothing to reveal
		# SIMPLIFIED (docs/simplified-cards.md, "Petra Sphinx"): the option
		# list is the chooser's own library, not every card name there is.
		var picked: int = game.agents[pid].choose_option(game, pid, names,
			"Name a card — Petra Sphinx reveals the top of your library", 0)
		if picked < 0:
			return
		var named: String = names[picked]
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
