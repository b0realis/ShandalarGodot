extends CardScript
## Cocoon — {G} — Enchantment — Aura — (leg, uncommon)
## Oracle: Enchant creature you control
##         When this Aura enters, tap enchanted creature and put three pupa
##         counters on this Aura.
##         Enchanted creature doesn't untap during your untap step if this
##         Aura has a pupa counter on it.
##         At the beginning of your upkeep, remove a pupa counter from this
##         Aura. If you can't, sacrifice it, put a +1/+1 counter on
##         enchanted creature, and that creature gains flying.
##
## Implementation: a three-turn metamorphosis. The counters live on the
## AURA (unlike Venarian Gold's, which sit on the creature), so the static
## untap lock and the countdown read the same object.
##
## "That creature gains flying" carries NO duration, so it is not an
## until-end-of-turn float: it is MtgGame.grant_keyword_permanently, which
## lasts for as long as the creature stays on the battlefield (CR 611.2)
## and survives the Cocoon being sacrificed in that very same resolution.
## The order printed on the card is the order here — sacrifice the Aura
## first, then reward the creature — which is why the reward has to outlive
## its source.


func build() -> CardData:
	var yours := TargetSpec.creature("target creature you control")
	yours.with_source_filter(_yours)
	return CardData.new("Cocoon", "{G}", Mtg.CardType.ENCHANTMENT) \
		.enchants(yours) \
		.static_ability(StaticAbility.new(
			_lock, "Enchanted creature doesn't untap during your untap step if this Aura has a pupa counter on it.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _spin,
			"When this Aura enters, tap enchanted creature and put three pupa counters on this Aura.",
			_is_self)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _hatch,
			"At the beginning of your upkeep, remove a pupa counter from this Aura. If you can't, sacrifice it, put a +1/+1 counter on enchanted creature, and that creature gains flying.",
			_own_upkeep)) \
		.oracle("Enchant creature you control\n"
			+ "When this Aura enters, tap enchanted creature and put three pupa counters on this Aura.\n"
			+ "Enchanted creature doesn't untap during your untap step if this Aura has a pupa counter on it.\n"
			+ "At the beginning of your upkeep, remove a pupa counter from this Aura. If you can't, "
			+ "sacrifice it, put a +1/+1 counter on enchanted creature, and that creature gains flying.")


static func _yours(_game: MtgGame, source: CardInstance, inst: CardInstance) -> bool:
	return inst.controller_id == source.controller_id


static func _host_of(game: MtgGame, source: CardInstance) -> CardInstance:
	if source.attached_to == -1:
		return null
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return null
	return host


static func _lock(game: MtgGame, source: CardInstance) -> void:
	if int(source.counters.get("pupa", 0)) <= 0:
		return
	var host := _host_of(game, source)
	if host != null:
		host.cur_skips_untap = true


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _spin(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var host := _host_of(game, source)
	if host != null:
		game.tap_permanent(host)
	game.add_counters(source, "pupa", 3)


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _hatch(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	if int(source.counters.get("pupa", 0)) > 0:
		game.add_counters(source, "pupa", -1)
		return
	var host := _host_of(game, source)
	game.sacrifice_permanent(source)
	if host == null:
		return
	game.add_counters(host, "+1/+1", 1)
	game.grant_keyword_permanently(host, Mtg.Keyword.FLYING)
