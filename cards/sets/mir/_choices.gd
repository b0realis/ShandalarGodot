extends RefCounted
## Mirage (_choices, Pack 8). Choices on entry or resolution: colours, players, land types, hidden-zone picks.
##
## Hidden zones are read only while the card's own legal effect resolves,
## and only by the seat the rules let look: a searching player sees their
## own library (CR 701.19b), a bidder sees the public board. No hint here
## reads an opponent's hand or either library's order (CONTRIBUTING rule 8).
## A search is a [SearchLibraryEffect] subclass, so the duel screen opens
## its library picker before the cast and the AI prices it as a search.
##
## The Visions and Weatherlight modules (cards/sets/vis/_choices.gd,
## cards/sets/wth/_choices.gd) reuse [TopTutor] and the helpers here.
const PH := preload("res://cards/sets/mir/_phasing.gd")


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Enlightened Tutor":
			c.spell(TopTutor.new("an artifact or enchantment card", Q.artifact_or_enchantment, true))
		"Mystical Tutor":
			c.spell(TopTutor.new("an instant or sorcery card", Q.instant_or_sorcery, true))
		"Worldly Tutor":
			c.spell(TopTutor.new("a creature card", Q.creature_card, true))
		"Rampant Growth":
			c.spell(BasicToBattlefieldTapped.new())
		"Illicit Auction":
			c.spell(Auction.new())
		"Natural Balance":
			c.spell(NaturalBalance.new())
		_:
			return false
	return true


# ------------------------------------------------------------- predicates

## Predicates and counts the effect classes below (and the Visions and
## Weatherlight modules) name as Q.<name>. A card in a library has only its
## printed characteristics (CR 109.3), so the card predicates read the
## card's data, not a permanent's live cur_* values.
class Q:
	static func artifact_or_enchantment(i: CardInstance) -> bool:
		return i.data.is_type(Mtg.CardType.ARTIFACT) or i.data.is_type(Mtg.CardType.ENCHANTMENT)

	static func instant_or_sorcery(i: CardInstance) -> bool:
		return i.data.is_type(Mtg.CardType.INSTANT) or i.data.is_type(Mtg.CardType.SORCERY)

	static func creature_card(i: CardInstance) -> bool:
		return i.data.is_creature()

	static func basic_land_card(i: CardInstance) -> bool:
		return i.data.is_land() and (i.data.supertypes & Mtg.Supertype.BASIC) != 0

	static func plains_card(i: CardInstance) -> bool:
		return i.data.subtypes.has("plains")

	## Lands [param pid] controls right now (phased-out ones don't exist).
	static func land_count(g: MtgGame, pid: int) -> int:
		var n := 0
		for i in g.players[pid].battlefield:
			if i.is_land(): n += 1
		return n

	## The seats in turn order from the active player (APNAP, CR 101.4).
	static func apnap(g: MtgGame) -> Array[int]:
		var out: Array[int] = [g.active_player, g.opponent_of(g.active_player)]
		return out


# ================================================================ tutors

## "Search your library for <a card>, [reveal it,] then shuffle and put that
## card on top" (Enlightened, Mystical, Worldly and Vampiric Tutor). A
## search for a card with a stated quality may fail to find (CR 701.19b);
## "a card" with none must find one if the library holds any. The card is
## set aside while the library shuffles, then goes on top.
class TopTutor extends SearchLibraryEffect:
	var reveal := true

	func _init(desc: String, predicate: Callable, publicly: bool) -> void:
		super(desc, predicate)
		reveal = publicly

	func resolve(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var cards: Array[CardInstance] = []
		for i in g.players[pid].library:
			if not filter.is_valid() or filter.call(i): cards.append(i)
		var pick := g.agents[pid].choose_card(g, pid, cards, "Search your library for " + description,
			filter.is_valid())
		if pick == null and not filter.is_valid() and not cards.is_empty(): pick = cards[0]
		var found := pick != null and cards.has(pick)
		var who := g.players[pid].player_name
		if found and reveal:
			g.reveal_information(-1, "%s reveals" % s.data.card_name, [pick.data.card_name])
			g.log_line("%s reveals %s and puts it on top of their library" % [who, pick.data.card_name])
		elif found:
			g.log_line("%s puts %s on top of their library" % [who, pick.data.card_name], null, "", pid,
				"%s puts a card from their library on top of it" % who)
		else:
			g.log_line("%s searches their library and finds nothing" % who)
		g.shuffle_library(pid)
		if found: g.move_library_card_to_top(pick)

	func describe() -> String:
		return "search your library for %s%s, then shuffle and put that card on top" % [
			description, ", reveal it" if reveal else ""]


## Rampant Growth: "Search your library for a basic land card, put that card
## onto the battlefield tapped, then shuffle." It enters tapped — no
## "becomes tapped" event (CR 614.1c).
class BasicToBattlefieldTapped extends SearchLibraryEffect:
	func _init() -> void:
		super("a basic land card", Q.basic_land_card)
		to_battlefield()
		with_ai_role(&"land_search")

	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var cards: Array[CardInstance] = []
		for i in g.players[pid].library:
			if filter.call(i): cards.append(i)
		var pick := g.agents[pid].choose_card(g, pid, cards, "Search your library for a basic land card", true)
		if pick != null and cards.has(pick):
			g.put_library_card_onto_battlefield(pick, pid, true)
		g.shuffle_library(pid)

	func describe() -> String:
		return "search your library for a basic land card, put it onto the battlefield tapped, then shuffle"


# ========================================================== Illicit Auction

## "Each player may bid life for control of target creature. You start the
## bidding with a bid of 0. In turn order, each player may top the high bid.
## The bidding ends if the high bid stands. The high bidder loses life equal
## to the high bid and gains control of the creature."
##
## Each bid is the bidder's own question: "Pass" or a number above the high
## bid. A bid may exceed the bidder's life (nothing forbids it); every bid
## that can change the outcome is offered — up to the bidder's life, or one
## more than the high bid when that is already beyond it. The hint is
## public: the creature's body against the bidder's life.
class Auction extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()
		with_ai_role(&"life_bid_steal")

	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		if t == null or t.is_player: return
		var creature := g.find_instance(t.instance_id)
		if not g.is_present(creature): return
		var high := 0
		var leader := pid
		g.log_line("%s opens the bidding for %s at 0 life" % [g.players[pid].player_name, creature.data.card_name])
		var bidder := g.opponent_of(pid)
		var guard := 0
		while guard < 400:
			guard += 1
			var top := maxi(high + 1, g.players[bidder].life)
			var labels: Array[String] = ["Pass (let the bid of %d stand)" % high]
			for n in range(high + 1, top + 1): labels.append("Bid %d life" % n)
			var pick := g.agents[bidder].choose_option(g, bidder, labels,
				"Illicit Auction: top the bid of %d life for %s?" % [high, creature.data.card_name],
				_hint(g, bidder, creature, high))
			if pick <= 0 or pick >= labels.size(): break
			high += pick
			leader = bidder
			g.log_line("%s bids %d life" % [g.players[bidder].player_name, high])
			bidder = g.opponent_of(bidder)
		g.log_line("%s wins the bidding at %d life" % [g.players[leader].player_name, high])
		if high > 0: g.adjust_life(leader, -high)
		if g.is_present(creature): g.change_control(creature, leader)

	## 1 = "top by one" when the creature is worth it to [param bidder] and
	## the bid leaves a safe margin of life; 0 = pass.
	static func _hint(g: MtgGame, bidder: int, creature: CardInstance, high: int) -> int:
		var worth := maxi(creature.cur_power, 0) + maxi(creature.cur_toughness, 0)
		var limit := mini(worth, g.players[bidder].life - 6)
		return 1 if high + 1 <= limit else 0

	func describe() -> String:
		return "each player may bid life for control of target creature; the high bidder loses that much life and gains control of it"


# =========================================================== Natural Balance

## Players with six or more lands each choose five to keep and sacrifice the
## rest (choices in turn order, then one simultaneous sacrifice, CR 101.4);
## then each player with four or fewer may search for up to (5 − lands)
## basic land cards, onto the battlefield, and each who searched shuffles.
## The sacrifice is asked as "choose a land to sacrifice" — the same five
## kept, in fewer questions.
class NaturalBalance extends EffectBase:
	func _init() -> void:
		with_ai_role(&"land_balance")

	func resolve(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		var doomed: Array[CardInstance] = []
		for who in Q.apnap(g):
			var lands: Array[CardInstance] = []
			for i in g.players[who].battlefield:
				if i.is_land(): lands.append(i)
			var extra := lands.size() - 5
			if lands.size() < 6: continue
			var left := PH.H.best_first(lands)
			left.reverse()   # the seat's least valuable land first
			for n in extra:
				var pick := g.agents[who].choose_card(g, who, left,
					"Natural Balance: choose a land to sacrifice (%d of %d; you keep five)" % [n + 1, extra],
					false, false, true)
				if pick == null or not left.has(pick): pick = left[0]
				left.erase(pick)
				doomed.append(pick)
		if not doomed.is_empty():
			g.begin_simultaneous()
			for i in doomed: g.sacrifice_permanent(i)
			g.end_simultaneous()
		for who in Q.apnap(g):
			var count := Q.land_count(g, who)
			if count > 4: continue
			var x := 5 - count
			if not g.agents[who].choose_yes_no(g, who,
					"Natural Balance: search your library for up to %d basic land card(s)?" % x, true):
				continue
			for n in x:
				var cards: Array[CardInstance] = []
				for i in g.players[who].library:
					if Q.basic_land_card(i): cards.append(i)
				if cards.is_empty(): break
				var pick := g.agents[who].choose_card(g, who, cards,
					"Natural Balance: search for a basic land card (%d of up to %d)" % [n + 1, x], true)
				if pick == null or not cards.has(pick): break
				g.put_library_card_onto_battlefield(pick, who)
			g.shuffle_library(who)

	func describe() -> String:
		return "each player with six or more lands keeps five and sacrifices the rest; each with four or fewer may search for basic lands up to five"
