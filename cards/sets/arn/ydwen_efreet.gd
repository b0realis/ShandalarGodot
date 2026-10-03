extends CardScript
## Ydwen Efreet — {R}{R}{R} — Creature — Efreet — 3/6 — (arn, rare)
## Oracle: Whenever this creature blocks, flip a coin. If you lose the
##         flip, remove this creature from combat and it can't block this
##         turn. Creatures it was blocking that had become blocked by only
##         this creature this combat become unblocked.
##
## Implementation: a BLOCKED trigger (gated on the Efreet being the
## blocker) that flips and, on a loss, removes it from combat WITH the
## printed unblock exception (MtgGame.remove_from_combat's
## `unblock_solo_attackers`), so a creature the Efreet was blocking alone
## really becomes unblocked instead of staying blocked-by-nobody. A 3/6
## for three mana that blocks half the time.
##
## "And it can't block this turn" is a floating static bound to the
## Efreet until end of turn (Panic's mechanism: cur_cant_block_filter), so
## nothing — an extra combat, or an effect that makes a creature block —
## can put it back in front of an attacker (2026-10-03; it was unmodelled
## and unmarked before).


func build() -> CardData:
	return CardData.new("Ydwen Efreet", "{R}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(3, 6) \
		.with_subtypes(["efreet"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BLOCKED, _gamble,
			"Whenever Ydwen Efreet blocks, flip a coin. If you lose the flip, remove "
			+ "it from combat.",
			_is_the_blocker)) \
		.oracle("Whenever this creature blocks, flip a coin. If you lose the flip, "
			+ "remove this creature from combat and it can't block this turn. "
			+ "Creatures it was blocking that had become blocked by only this creature "
			+ "this combat become unblocked.")


## "Whenever this creature BLOCKS" — ONE trigger per combat however many
## attackers it blocks (CR 509.1h; a Blaze of Glory or Two-Headed Giant of
## Foriys conscript really can block two). The engine dispatches BLOCKED
## once per declared PAIR, so only the FIRST attacker the Efreet is
## blocking counts — Spitting Slug's `_in_the_pair` is the same guard. It
## flipped once per pair until 2026-09-17, which gave a double-blocking
## Efreet two chances to run away instead of one.
static func _is_the_blocker(game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	if event.data.get("blocker") != source:
		return false
	var attacked := game.combat.attackers_blocked_by(source.id)
	var attacker: CardInstance = event.data.get("attacker")
	return not attacked.is_empty() and attacker != null \
		and attacked[0] == attacker.id


static func _gamble(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if not game.is_present(source):   # gone, or phased out (CR 702.26e)
		return
	if game.flip_coin(source.controller_id):
		return
	# The printed third sentence is the CR 509.1h EXCEPTION — "creatures it
	# was blocking that had become blocked by ONLY this creature this combat
	# become unblocked" — which MtgGame.remove_from_combat implements behind
	# an opt-in flag (False Orders is the other caller). Without it a lost
	# flip turned the Efreet into a Fog: the attacker stayed BLOCKED with no
	# blockers and dealt its damage to nobody.
	game.remove_from_combat(source, true)
	game.continuous.add_floating_static(source, StaticAbility.new(
			_cant_block.bind(source.id), "It can't block this turn."),
		ContinuousEffects.Duration.END_OF_TURN, -1, false, source.id)
	game.recalculate()


static func _cant_block(game: MtgGame, _source: CardInstance, efreet_id: int) -> void:
	var efreet := game.find_instance(efreet_id)
	if efreet != null and efreet.zone == Mtg.Zone.BATTLEFIELD:
		efreet.cur_cant_block_filter = _any_attacker


static func _any_attacker(_attacker: CardInstance) -> bool:
	return true
