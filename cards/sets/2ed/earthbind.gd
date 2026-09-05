extends CardScript
## Earthbind — {R} — Enchantment — Aura — (2ed, common)
## Oracle: Enchant creature
##         When this Aura enters, if enchanted creature has flying, this
##         Aura deals 2 damage to that creature and this Aura gains
##         "Enchanted creature loses flying."
##
## Implementation: an "intervening if" trigger (CR 603.4): the condition
## "if enchanted creature has flying" is checked BOTH when the Aura enters
## (the trigger condition below — an Earthbind landing on a grounded
## creature never triggers at all, nothing goes on the stack) AND again as
## the ability resolves (_shoot_it_down — a host that lost flying in
## response is spared). The Aura sees its host in its own arrival trigger
## because an Aura enters the battlefield already attached (CR 303.4a,
## MtgGame._put_on_battlefield's `host`). When it fires it deals its 2 and
## arms the Aura (its own memory), and a static then strips flying for as
## long as the Aura stays.


func build() -> CardData:
	return CardData.new("Earthbind", "{R}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(_ground_it,
			"Enchanted creature loses flying.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _shoot_it_down,
			"When this Aura enters, if enchanted creature has flying, this Aura deals 2 damage to that creature and gains \"Enchanted creature loses flying.\"",
			_is_self)) \
		.oracle("Enchant creature\nWhen this Aura enters, if enchanted creature has flying, this Aura deals 2 damage to that creature and this Aura gains \"Enchanted creature loses flying.\"")


## The trigger condition: this Aura entering, AND its host has flying at
## that moment (CR 603.4 — "if" in the trigger condition is checked as the
## event happens; with a grounded host the ability does not trigger).
static func _is_self(game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source and _host_flies(game, source)


static func _host_flies(game: MtgGame, source: CardInstance) -> bool:
	if source.attached_to == -1:
		return false
	var host := game.find_instance(source.attached_to)
	return host != null and host.zone == Mtg.Zone.BATTLEFIELD \
		and host.has_keyword(Mtg.Keyword.FLYING)


static func _shoot_it_down(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	# CR 603.4: checked again on resolution — a host that lost flying in
	# response is left alone.
	if not _host_flies(game, source):
		return
	var host := game.find_instance(source.attached_to)
	source.memory["armed"] = true
	game.recalculate()
	game.deal_damage(source, TargetRef.card(host), 2)


static func _ground_it(game: MtgGame, source: CardInstance) -> void:
	if not source.memory.has("armed") or source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.cur_keywords.erase(Mtg.Keyword.FLYING)
