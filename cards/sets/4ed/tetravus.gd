extends CardScript
## Tetravus — {6} — Artifact Creature — Construct — 1/1 — (4ed, rare)
## Oracle: Flying
##         This creature enters with three +1/+1 counters on it.
##         At the beginning of your upkeep, you may remove any number of
##         +1/+1 counters from this creature. If you do, create that many
##         1/1 colorless Tetravite artifact creature tokens. They each have
##         flying and "This token can't be enchanted."
##         At the beginning of your upkeep, you may exile any number of
##         tokens created with this creature. If you do, put that many
##         +1/+1 counters on this creature.
##
## Implementation: two upkeep triggers, each asking HOW MANY through
## DecisionAgent.choose_number, and a roster of the Tetravites this
## particular Tetravus made kept in CardInstance.memory — the oracle says
## "tokens created with this creature", not "tokens you control", so a
## Tetravite an opponent has taken can still be absorbed. That is the
## original's ruling too: *"you can absorb a Tetravite that is controlled
## by another player"* (Duel.hlp, Tetravus). Ids that are no longer live
## tokens on the battlefield are pruned as the roster is read, so a
## Tetravite killed in combat simply drops off it.
##
## The tokens are ARTIFACT creatures with flying and CardData's
## `cant_be_aura_target` — the printed "can't be enchanted", and the
## original says the same: *"Tetravite cannot have enchantments played on
## it"*. They arrive untapped and summoning-sick whatever the Tetravus is
## doing (*"Tetravites enter play with summoning sickness. They come into
## play untapped, whether the Tetravus is tapped or not"*), which is what
## MtgGame.create_token does anyway.
##
## A Tetravus that leaves the battlefield leaves its Tetravites behind
## (*"If the Tetravus leaves play, any Tetravites it has in play will
## remain in play, but cannot be absorbed into any Tetravus"* — its memory
## is cleared with the rest of its battlefield state, CR 400.7, so the
## roster goes with it).
##
## WHICH Tetravites are absorbed is the controller's own pick, one
## DecisionAgent.choose_card per body after the count (the original docked
## them one at a time — `@TETRAVUS`, Program/prompts.txt:890: "Dock
## tetravite." / "Move 1 token." …). The list comes strays first — ones an
## opponent has taken control of are pure profit to absorb — and that is
## what the heuristic takes; it never absorbs its own fliers.
##
## Duel.hlp deviates: the original allowed each counter ONE move per upkeep
## — *"each Tetravite can only be moved onto or off of Tetravus during a
## given upkeep, not both"*. Both of the oracle's triggers are "at the
## beginning of your upkeep", so here the second may undo the first in the
## same turn; we follow the oracle, and the round trip is a no-op anyway.


static func _tetravite() -> CardData:
	return CardData.new("Tetravite", "",
			Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.with_no_aura_targeting() \
		.oracle("Flying\nThis token can't be enchanted.")


func build() -> CardData:
	return CardData.new("Tetravus", "{6}",
			Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["construct"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.with_enters_counters("+1/+1", 3) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _bud,
			"At the beginning of your upkeep, you may remove any number of +1/+1 "
			+ "counters from this creature. If you do, create that many 1/1 "
			+ "colorless Tetravite artifact creature tokens.",
			_own_upkeep)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _absorb,
			"At the beginning of your upkeep, you may exile any number of tokens "
			+ "created with this creature. If you do, put that many +1/+1 counters "
			+ "on this creature.",
			_own_upkeep)) \
		.oracle("Flying\nThis creature enters with three +1/+1 counters on it.\n"
			+ "At the beginning of your upkeep, you may remove any number of +1/+1 "
			+ "counters from this creature. If you do, create that many 1/1 colorless "
			+ "Tetravite artifact creature tokens. They each have flying and \"This "
			+ "token can't be enchanted.\"\nAt the beginning of your upkeep, you may "
			+ "exile any number of tokens created with this creature. If you do, put "
			+ "that many +1/+1 counters on this creature.")


static func _own_upkeep(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return source.zone == Mtg.Zone.BATTLEFIELD \
		and event.data["player"] == source.controller_id


## The Tetravites this Tetravus made that are still on the battlefield.
## Reading the roster prunes it, so dead ones never come back.
static func brood(game: MtgGame, source: CardInstance) -> Array[CardInstance]:
	var live: Array[CardInstance] = []
	var ids: Array = []
	for id in source.memory.get("brood", []):
		var tok := game.find_instance(int(id))
		if tok != null and tok.is_token and tok.zone == Mtg.Zone.BATTLEFIELD:
			live.append(tok)
			ids.append(int(id))
	source.memory["brood"] = ids
	return live


static func _bud(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	var have: int = int(source.counters.get("+1/+1", 0))
	if have <= 0:
		return
	# The heuristic sends out every counter it can: four 1/1 fliers beat one
	# 4/4 flier against blockers, and they come back next upkeep.
	var many: int = game.agents[pid].choose_number(game, pid, 0, have,
		"Remove how many +1/+1 counters from Tetravus (each makes a Tetravite)?",
		have)
	if many <= 0:
		return
	game.add_counters(source, "+1/+1", -many)
	var ids: Array = source.memory.get("brood", []).duplicate()
	for tok in game.create_token(pid, _tetravite(), many):
		ids.append(tok.id)
	source.memory["brood"] = ids


static func _absorb(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	var live := brood(game, source)
	if live.is_empty():
		return
	# The heuristic absorbs only Tetravites it has LOST control of — those
	# are pure profit — and leaves its own fliers on the board.
	var strays := 0
	for tok in live:
		if tok.controller_id != pid:
			strays += 1
	var many: int = game.agents[pid].choose_number(game, pid, 0, live.size(),
		"Exile how many Tetravites to put +1/+1 counters on Tetravus?",
		strays)
	if many <= 0:
		return
	# Strays first, so the heuristic's count means what it says — and so
	# its first pick below is a stray.
	live.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		if (a.controller_id != pid) != (b.controller_id != pid):
			return a.controller_id != pid
		return a.id < b.id)
	var taken := 0
	for i in many:
		if live.is_empty():
			break
		var pick := game.agents[pid].choose_card(game, pid, live,
			"Dock tetravite.", false, false, true)
		if pick == null or not live.has(pick):
			pick = live[0]
		live.erase(pick)
		game.exile_permanent(pick)
		taken += 1
	if taken > 0:
		game.add_counters(source, "+1/+1", taken)
	brood(game, source)   # prune the ones just exiled
