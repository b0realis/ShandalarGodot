extends CardScript
## Frankenstein's Monster — {X}{B}{B} — Creature — Zombie — 0/1 — (drk, rare)
## Oracle: As this creature enters, exile X creature cards from your
##         graveyard. If you can't, put this creature into its owner's
##         graveyard instead of onto the battlefield. For each creature card
##         exiled this way, this creature enters with a +2/+0, +1/+1, or
##         +0/+2 counter on it.
##
## Implementation: one printed replacement (CR 614.1c) in two halves, and
## both run before anything can see a 0/1 zombie on the table. The X it was
## cast for rides on the card's own memory (MtgGame records it at cast
## time and forgets it whenever the card leaves the stack or the
## battlefield without being cast — CR 107.3b, X is 0 anywhere but the
## stack), so a Monster REANIMATED rather than cast is assembled from
## nothing and enters as the 0/1 it is printed as.
##
## - The VETO (CardData.enters_only_if → MtgGame.entry_refused) is the
##   "if you can't" half. With fewer than X creature cards in the graveyard
##   the Monster NEVER ENTERS THE BATTLEFIELD: it goes to its owner's
##   graveyard straight off the stack, which is what "instead of onto the
##   battlefield" says. So it does not die — no leave-trigger, no
##   dies-trigger, and nothing that counts creatures dying this turn
##   (Scavenging Ghoul, Khabal Ghoul, Soul Net) is fed. The previous
##   implementation was an arrival TRIGGER that let the Monster land and
##   then SACRIFICED it, which was wrong twice over: a put-into-graveyard
##   is not a sacrifice (CR 701.17), and a permanent that was replaced on
##   the way in never entered at all.
## - The PAYMENT (CardData.as_it_enters) exiles the corpses and adds the
##   counters, in the window MtgGame opens after the permanent is on the
##   battlefield but before state-based actions and before the
##   enters-the-battlefield trigger — the same window Rock Hydra's X
##   counters and Wood Elemental's body use.
##
## Both choices are the controller's, asked through the DecisionAgent
## funnel from inside the resolution (§1.3 holds each one open for a human
## seat): WHICH corpse to exile (choose_card, once per corpse) and WHICH of
## the three printed counters it pays for (choose_option). The hints are
## the old hard-wired answers — the cheapest bodies, and +1/+1 — so a seat
## that just follows the hint plays exactly as before.
##
## mage-go does not implement this card, and `Duel.hlp` does not cover it:
## the shipped help file is the base game's pool and The Dark arrived with
## the expansion, so there is no 1997 prompt for either question.

## The three counters the card prints, in oracle order. Parsed by
## ContinuousEffects._parse_pt_counter like any other P/T counter kind.
const COUNTER_KINDS: Array[String] = ["+2/+0", "+1/+1", "+0/+2"]

## Index into COUNTER_KINDS used as the hint. +1/+1 keeps the Monster's
## power and toughness level, which is the only one of the three that both
## survives a Lightning Bolt and threatens something back; the engine used
## to add it without asking.
const BALANCED := 1


func build() -> CardData:
	return CardData.new("Frankenstein's Monster", "{X}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(0, 1) \
		.with_subtypes(["zombie"]) \
		.enters_only_if(_can_be_assembled) \
		.as_it_enters(_assemble) \
		.oracle("As this creature enters, exile X creature cards from your graveyard. If you can't, put this creature into its owner's graveyard instead of onto the battlefield. For each creature card exiled this way, this creature enters with a +2/+0, +1/+1, or +0/+2 counter on it.")


## Every creature card in [param controller]'s graveyard, cheapest first —
## the candidate list, pre-sorted so its head is the hint the funnel offers.
static func corpses(game: MtgGame, controller: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for card in game.players[controller].graveyard:
		if card.data.is_creature():
			out.append(card)
	out.sort_custom(_cheapest_first)
	return out


static func _cheapest_first(a: CardInstance, b: CardInstance) -> bool:
	return a.data.cost.mana_value() < b.data.cost.mana_value()


## "If you can't, put this creature into its owner's graveyard instead of
## onto the battlefield." Only an actual SHORTFALL refuses the arrival:
## exiling ZERO cards for X=0 is carried out trivially, so a Monster cast
## for X=0 enters and stays as a 0/1.
static func _can_be_assembled(game: MtgGame, inst: CardInstance,
		controller: int) -> String:
	var wanted := int(inst.memory.get("x_value", 0))
	if corpses(game, controller).size() >= wanted:
		return ""
	return "there are not %d creature cards in your graveyard to exile" % wanted


static func _assemble(game: MtgGame, inst: CardInstance, controller: int) -> void:
	var wanted := int(inst.memory.get("x_value", 0))
	if wanted <= 0:
		return
	for _i in wanted:
		var available := corpses(game, controller)
		if available.is_empty():
			return   # the veto guarantees this cannot happen; belt and braces
		var corpse: CardInstance = game.agents[controller].choose_card(
			game, controller, available,
			"Exile which creature card to build Frankenstein's Monster?")
		if corpse == null or corpse.zone != Mtg.Zone.GRAVEYARD:
			corpse = available[0]   # not optional: the exile is not a choice
		game.exile_from_graveyard(corpse)
		var kind := COUNTER_KINDS[game.agents[controller].choose_option(
			game, controller, COUNTER_KINDS,
			"Which counter does %s put on Frankenstein's Monster?"
				% corpse.data.card_name,
			BALANCED)]
		game.add_counters(inst, kind, 1)
