extends CardScript
## Tangle Kelp — {U} — Enchantment — Aura — (drk, uncommon)
## Oracle: Enchant creature
##         When this Aura enters, tap enchanted creature.
##         Enchanted creature doesn't untap during its controller's untap
##         step if it attacked during its controller's last turn.
##
## Implementation: a one-mana tapper that then punishes attacking. The
## untap denial is a STATIC (2026-10-03), as printed: while the Kelp is on
## the host, the host skips its controller's untap step
## (CardInstance.cur_skips_untap) if it attacked during that player's last
## turn — the turn number declare_attackers stamps on the attacker
## (`attack_turn_<pid>` in its memory, wiped when it changes zones)
## against MtgGame's per-seat `last_turn_number` (extra turns counted),
## Halls of Mist's reading of the same words.
##
## It used to be an end-step trigger that set the engine's one-shot
## `skip_next_untap`, which outlived the Kelp: an Aura destroyed between
## that end step and the untap step still kept the creature down.


func build() -> CardData:
	return CardData.new("Tangle Kelp", "{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _entangle,
			"When this Aura enters, tap enchanted creature.",
			_is_self)) \
		.static_ability(StaticAbility.new(_hold_it_down,
			"Enchanted creature doesn't untap during its controller's untap step if it attacked during its controller's last turn.")) \
		.oracle("Enchant creature\n"
			+ "When this Aura enters, tap enchanted creature.\n"
			+ "Enchanted creature doesn't untap during its controller's untap step if it "
			+ "attacked during its controller's last turn.")


static func _host_of(game: MtgGame, source: CardInstance) -> CardInstance:
	if source.attached_to == -1:
		return null
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return null
	return host


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _entangle(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var host := _host_of(game, source)
	if host != null:
		game.tap_permanent(host)


static func _hold_it_down(game: MtgGame, source: CardInstance) -> void:
	var host := _host_of(game, source)
	if host == null:
		return
	var pid := host.controller_id
	var last := game.players[pid].last_turn_number
	if last > 0 and int(host.memory.get("attack_turn_%d" % pid, -1)) == last:
		host.cur_skips_untap = true
