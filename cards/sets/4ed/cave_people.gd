extends CardScript
## Cave People — {1}{R}{R} — Creature — Human — 1/4 — (4ed, uncommon)
## Oracle: Whenever this creature attacks, it gets +1/-2 until end of turn.
##         {1}{R}{R}, {T}: Target creature gains mountainwalk until end of
##         turn. (It can't be blocked as long as defending player controls
##         a Mountain.)
##
## Implementation: a DECLARED_ATTACKERS trigger gated on the People being
## among the attackers (Hasran Ogress's pattern), registering a floating
## +1/-2 — a 2/2 while it swings, a 1/4 wall the rest of the time. The
## second line is the plain landwalk grant (Scarwood Hag's, via
## GrantLandwalkEffect), and its {T} means the People cannot both grant and
## attack in the same turn.


func build() -> CardData:
	return CardData.new("Cave People", "{1}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(1, 4) \
		.with_subtypes(["human"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DECLARED_ATTACKERS, _charge,
			"Whenever this creature attacks, it gets +1/-2 until end of turn.",
			_self_attacks)) \
		.activated(ActivatedAbility.new(
			"{1}{R}{R}", true, [GrantLandwalkEffect.new(["mountain"])],
			"{1}{R}{R}, {T}: Target creature gains mountainwalk until end of turn.")) \
		.oracle("Whenever this creature attacks, it gets +1/-2 until end of turn.\n"
			+ "{1}{R}{R}, {T}: Target creature gains mountainwalk until end of turn. "
			+ "(It can't be blocked as long as defending player controls a Mountain.)")


static func _self_attacks(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return (event.data["attackers"] as Array).has(source)


static func _charge(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	game.continuous.add_until_eot_pump(source.id, 1, -2)
	game.recalculate()
