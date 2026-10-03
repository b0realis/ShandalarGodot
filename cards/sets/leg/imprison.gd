extends CardScript
## Imprison — {B} — Enchantment — Aura — (leg, rare)
## Oracle: Enchant creature
##         Whenever a player activates an ability of enchanted creature with
##         {T} in its activation cost that isn't a mana ability, you may pay
##         {1}. If you do, counter that ability. If you don't, destroy this
##         Aura.
##         Whenever enchanted creature attacks or blocks, you may pay {1}.
##         If you do, tap the creature, remove it from combat, and creatures
##         it was blocking that had become blocked by only that creature
##         this combat become unblocked. If you don't, destroy this Aura.
##
## Implementation: BOTH clauses.
##
## The COMBAT clause, both halves — attacking and blocking. Paying {1} taps
## the enchanted creature and pulls it out of combat, and whatever it was
## blocking ALONE really does become unblocked (the printed third clause;
## see `_collect_the_toll`); not paying destroys the Aura, which is the
## printed price of letting it go.
##
## The TAP-ABILITY clause rides on Mtg.EventType.ABILITY_ACTIVATED, which
## carries the activated ability's own STACK id. The event is dispatched
## after the ability is appended (CR 602.2b), so this trigger sits ABOVE it
## and MtgGame.counter_ability reaches it while it is still waiting.
## "That isn't a mana ability" needs no test of its own: a mana ability
## never uses the stack (CR 605.3a) and arrives here with `stack_id` -1.
## "With {T} in its activation cost" is the event's `taps` flag.
##
## Every "you may pay {1}" is put to the Aura's controller through their own
## DecisionAgent, so a human seat is held open on it (docs/duel-todo.md
## §1.3); the hint is "pay", because letting the Aura go is rarely right.


func build() -> CardData:
	return CardData.new("Imprison", "{B}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DECLARED_ATTACKERS, _host_attacks,
			"Whenever enchanted creature attacks, you may pay {1}. If you do, tap it and remove it from combat. If you don't, destroy this Aura.",
			_host_is_attacking)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ABILITY_ACTIVATED, _host_taps_for_something,
			"Whenever a player activates an ability of enchanted creature with {T} in its activation cost that isn't a mana ability, you may pay {1}. If you do, counter that ability. If you don't, destroy this Aura.",
			_host_used_a_tap_ability)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BLOCKED, _host_blocks,
			"Whenever enchanted creature blocks, you may pay {1}. If you do, tap it and remove it from combat. If you don't, destroy this Aura.",
			_host_is_blocking)) \
		.oracle("Enchant creature\nWhenever a player activates an ability of enchanted creature with {T} in its activation cost that isn't a mana ability, you may pay {1}. If you do, counter that ability. If you don't, destroy this Aura.\nWhenever enchanted creature attacks or blocks, you may pay {1}. If you do, tap the creature, remove it from combat, and creatures it was blocking that had become blocked by only that creature this combat become unblocked. If you don't, destroy this Aura.")


static func _host_is_attacking(game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	if source.attached_to == -1:
		return false
	for inst in event.data.get("attackers", []):
		if inst.id == source.attached_to:
			return true
	return false


## "Whenever enchanted creature … BLOCKS" — ONE toll per combat however
## many attackers it blocks (CR 509.1h; Blaze of Glory and Two-Headed
## Giant of Foriys both make that reachable). BLOCKED is dispatched once
## per declared PAIR, so only the FIRST attacker counts, the same guard
## Spitting Slug's `_in_the_pair` uses; it charged per pair until
## 2026-09-17.
static func _host_is_blocking(game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	var blocker: CardInstance = event.data.get("blocker")
	if blocker == null or blocker.id != source.attached_to:
		return false
	var attacked := game.combat.attackers_blocked_by(blocker.id)
	var attacker: CardInstance = event.data.get("attacker")
	return not attacked.is_empty() and attacker != null \
		and attacked[0] == attacker.id


## "Whenever a PLAYER activates an ability of enchanted creature with {T}
## in its activation cost that isn't a mana ability" — any player, so a
## stolen creature's thief is caught too.
static func _host_used_a_tap_ability(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	if source.attached_to == -1:
		return false
	var used: CardInstance = event.data.get("instance")
	if used == null or used.id != source.attached_to:
		return false
	if not bool(event.data.get("taps", false)):
		return false
	return int(event.data.get("stack_id", -1)) != -1   # not a mana ability


## Both tolls resolve even if Imprison has left the battlefield in
## response (CR 603.6 / 608.2h): the payment is still offered and still
## does its work — "destroy this Aura" is all that has become impossible
## (CR 609.3). Until 2026-10-03 destroying the Aura in response also
## dropped the counter and the haul out of combat.
static func _toll_payer(game: MtgGame, source: CardInstance) -> int:
	var pid := game.current_resolution_controller()
	return pid if pid >= 0 else source.controller_id


static func _host_taps_for_something(game: MtgGame, source: CardInstance,
		event: GameEvent) -> void:
	var pid := _toll_payer(game, source)
	var toll := ManaCost.parse("{1}")
	if game.can_afford_cost(pid, toll) and game.agents[pid].choose_yes_no(
			game, pid, "Pay {1} to counter that ability?", true) \
			and game.try_pay(pid, toll):
		game.counter_ability(int(event.data.get("stack_id", -1)))
		return
	game.destroy(source)


static func _host_attacks(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	_collect_the_toll(game, source)


static func _host_blocks(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	_collect_the_toll(game, source)


static func _collect_the_toll(game: MtgGame, source: CardInstance) -> void:
	# "The creature" is the one it enchanted — as it last was, for an Aura
	# that has already gone (CardInstance.last_attached_to).
	var host_id := source.attached_to if source.zone == Mtg.Zone.BATTLEFIELD \
		else source.last_attached_to
	var host := game.find_instance(host_id)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := _toll_payer(game, source)
	var toll := ManaCost.parse("{1}")
	if game.can_afford_cost(pid, toll) and game.agents[pid].choose_yes_no(
			game, pid, "Pay {1} to hold %s?" % host.data.card_name, true) \
			and game.try_pay(pid, toll):
		game.tap_permanent(host)
		# "…and creatures it was blocking that had become blocked by only
		# that creature this combat become UNBLOCKED" — the printed
		# exception to CR 509.1h, which MtgGame.remove_from_combat keeps
		# behind an opt-in flag (Ydwen Efreet and False Orders are the
		# other callers). Without it the toll was a Fog: the attacker
		# stayed blocked with no blockers and hit nobody (until 2026-09-17).
		game.remove_from_combat(host, true)
		return
	game.destroy(source)
