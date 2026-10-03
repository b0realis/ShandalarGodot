extends RefCounted
## Weatherlight (_choices, Pack 8). Choices on entry or resolution: colours, players, land types, hidden-zone picks.
##
## Same conventions as the Mirage module (cards/sets/mir/_choices.gd, whose
## predicates class Q this one shares).
const MC := preload("res://cards/sets/mir/_choices.gd")
const PH := preload("res://cards/sets/mir/_phasing.gd")
const M := preload("res://cards/sets/mir/_spells.gd")


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Tariff":
			c.spell(Tariff.new())
		"Doomsday":
			c.spell(Doomsday.new())
		_:
			return false
	return true


# =================================================================== Tariff

## "Each player sacrifices the creature they control with the greatest mana
## value unless they pay that creature's mana cost. If two or more creatures
## a player controls are tied for greatest, that player chooses one."
## In turn order each player names their creature and decides whether to
## pay; then the unpaid ones are sacrificed together (CR 101.4). The mana
## cost is the copiable one (a face-down creature has none); X is 0
## (CR 107.3b), and an object with no mana cost can't have it paid
## (CR 118.6) — a token is sacrificed.
class Tariff extends EffectBase:
	func _init() -> void:
		with_ai_role(&"tariff")

	func resolve(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		var unpaid: Array[CardInstance] = []
		for who in MC.Q.apnap(g):
			var creatures := g.players[who].creatures()
			if creatures.is_empty(): continue
			var most := -1
			for i in creatures: most = maxi(most, g.copiable_data(i).cost.mana_value())
			var tied: Array[CardInstance] = []
			for i in creatures:
				if g.copiable_data(i).cost.mana_value() == most: tied.append(i)
			var victim: CardInstance = tied[0]
			if tied.size() > 1:
				var ranked := PH.H.best_first(tied)
				ranked.reverse()   # the least valuable first
				victim = g.agents[who].choose_card(g, who, ranked,
					"Tariff: choose which of your tied creatures to sacrifice unless you pay its mana cost",
					false, false, true)
				if victim == null or not ranked.has(victim): victim = ranked[0]
			var text := g.copiable_data(victim).cost.text
			var paid := text != "" and EffectBase.unless_paid(g, who, ManaCost.parse(text),
				"Tariff: pay %s to keep %s?" % [text, victim.data.card_name], true)
			if paid:
				g.log_line("%s pays %s for %s" % [g.players[who].player_name, text, victim.data.card_name])
			else:
				unpaid.append(victim)
		if unpaid.is_empty(): return
		g.begin_simultaneous()
		for i in unpaid: g.sacrifice_permanent(i)
		g.end_simultaneous()

	func describe() -> String:
		return "each player sacrifices their creature with the greatest mana value unless they pay its mana cost"


# ================================================================= Doomsday

## "Search your library and graveyard for five cards and exile the rest. Put
## the chosen cards on top of your library in any order. You lose half your
## life, rounded up." Five, or every card when there are fewer (a search
## for cards without a stated quality must find them, CR 701.19b); the
## rest of both zones is exiled, the five form the whole library in the
## order chosen, and no shuffle follows. Only the caster's own library and
## graveyard are read, during the search.
class Doomsday extends EffectBase:
	func _init() -> void:
		with_ai_role(&"library_build")

	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var me := g.players[pid]
		var pool: Array[CardInstance] = []
		pool.append_array(me.library)
		pool.append_array(me.graveyard)
		var left := M.P.best_first(g, pool)
		var kept: Array[CardInstance] = []
		for n in mini(5, pool.size()):
			var pick := g.agents[pid].choose_card(g, pid, left,
				"Doomsday: choose a card to keep (%d of %d)" % [n + 1, mini(5, pool.size())], false, false, true)
			if pick == null or not left.has(pick): pick = left[0]
			left.erase(pick)
			kept.append(pick)
		g.log_line("%s keeps five cards" % me.player_name)
		for i in left:
			if i.zone == Mtg.Zone.LIBRARY: g.exile_library_card(i)
			elif i.zone == Mtg.Zone.GRAVEYARD: g.exile_from_graveyard(i)
		for i in kept:
			if i.zone == Mtg.Zone.GRAVEYARD: g.return_from_graveyard_to_library_top(i)
		var stack: Array[CardInstance] = []
		for i in kept:
			if i.zone == Mtg.Zone.LIBRARY: stack.append(i)
		var ordered: Array[CardInstance] = []
		while not stack.is_empty():
			var next: CardInstance = stack[0] if stack.size() == 1 else g.agents[pid].choose_card(g, pid, stack,
				"Doomsday: choose the card to put on top next (the first one chosen is the top card)",
				false, false, true)
			if next == null or not stack.has(next): next = stack[0]
			stack.erase(next)
			ordered.append(next)
		g.reorder_top_of_library(pid, ordered)
		if me.life > 0: g.adjust_life(pid, -ceili(me.life / 2.0))

	func describe() -> String:
		return "keep five cards of your library and graveyard on top of your library in any order, exile the rest, and lose half your life rounded up"
