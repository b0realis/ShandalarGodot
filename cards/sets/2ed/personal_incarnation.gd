extends CardScript
## Personal Incarnation — {3}{W}{W}{W} — Creature — Avatar Incarnation — 6/6 — (2ed, rare)
## Oracle: {0}: The next 1 damage that would be dealt to this creature this
##         turn is dealt to its owner instead. Only this creature's owner
##         may activate this ability.
##         When this creature dies, its owner loses half their life,
##         rounded up.
##
## 1997 (`Duel.hlp`, topic Personal Incarnation): *"Personal Incarnation's
## owner may redirect any amount of damage from it to himself or herself.
## If Personal Incarnation is put into any graveyard from play, its owner
## loses half of his or her life, rounded up."* Rulings there: the loss
## *"is loss of life, so may not be prevented, redirected, etc. If your
## life total is negative, it does not change"*; *"it is the OWNER of the
## Incarnation who loses life, not its controller, even if the Incarnation
## was put into play by someone other than its owner (e.g., revived by
## Animate Dead)"*; and *"if two of your Incarnations die, each triggered
## effect is played separately, so you lose half your life, then half of
## what's left."* The prompts (`Program/prompts.txt`,
## `@PERSONAL_INCARNATION`): *"Select damage to redirect."* / *"How much
## damage to redirect to you?"* — the original METERED it: a damage card
## is picked in the prevention step and an amount is typed.
##
## Implementation (lifted 2026-09-02; until then the card rode Jade
## Monolith's whole-event redirect and one free activation soaked a whole
## Shivan Dragon hit): each activation books ONE point of metered
## redirection on the creature (MtgGame.add_point_redirect →
## CardInstance.damage_point_redirect_to / damage_point_redirects), and
## when damage lands MtgGame._divert_damage_points splits that many points
## off into a new packet aimed at the OWNER while the rest is marked on
## the Avatar (DamagePacket.divert). The 1997 "how much" prompt is N
## activations of the {0} ability, which the Oracle text also says; under
## the 1997 damage-prevention window (§6.8) the moved point gets its own
## second prevention step, as `Duel.hlp`'s Veteran Bodyguard ruling
## describes for every redirect. Points expire at cleanup and when the
## card leaves the battlefield. Oracle and 1997 agree on everything else:
## owner, not controller, both for the activation and the toll.
##
## Manalink's `card_personal_incarnation` (unlimited.c, no 1997 address)
## and mage-go's `SetCreatureDamageRedirect` both move the whole damage
## card — the 1997 prompt is the Tier-1 evidence that the original did not.
##
## The 1997 FAQ (`s30/shandalar-faq.txt`) notes that Swords to Plowshares
## and Ashes to Ashes no longer trigger graveyard effects — they exile, so
## the toll is never paid for them; ours reads DIES (CR 700.4) and agrees.
##
## "Only this creature's owner may activate this ability" needed the one
## new piece: ActivatedAbility.owner_only(), which replaces the usual
## "you must control it" check with "you must OWN it". A stolen Personal
## Incarnation therefore still answers only to the player whose card it is —
## the thief gets a 6/6 they cannot protect, and its death still costs the
## OWNER half their life. That asymmetry is the whole card.
##
## Free to activate and repeatable, so a 6/6 that is unkillable by damage as
## long as its owner has the life to pay — one point at a time.
##
## Half, ROUNDED UP (CR 107.2): at 20 life the death costs 10, at 19 it
## costs 10 as well.


func build() -> CardData:
	return CardData.new("Personal Incarnation", "{3}{W}{W}{W}",
			Mtg.CardType.CREATURE) \
		.pt(6, 6) \
		.with_subtypes(["avatar", "incarnation"]) \
		.activated(ActivatedAbility.new("", false, [SoakEffect.new()],
			"{0}: The next 1 damage that would be dealt to this creature this turn is dealt to its owner instead.") \
			.owner_only()) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DIES, _toll,
			"When this creature dies, its owner loses half their life, rounded up.",
			_it_was_me)) \
		.oracle("{0}: The next 1 damage that would be dealt to this creature this "
			+ "turn is dealt to its owner instead. Only this creatures owner may "
			+ "activate this ability.\nWhen this creature dies, its owner loses half "
			+ "their life, rounded up.")


static func _it_was_me(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return event.data["instance"] == source


static func _toll(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var owner := source.owner_id
	var life := game.players[owner].life
	# Half, rounded UP (CR 107.2).
	var toll := (life + 1) / 2 if life > 0 else 0
	if toll <= 0:
		return
	game.log_line("%s's death costs %s %d life" % [
		source.data.card_name, game.players[owner].player_name, toll])
	game.adjust_life(owner, -toll)


class SoakEffect extends EffectBase:
	func _init() -> void:
		is_damage_prevention = true   # a redirection: legal in the window

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source == null or source.zone != Mtg.Zone.BATTLEFIELD:
			return
		# ONE point per activation (metered — the rest of the event still
		# lands on the Avatar); lifted 2026-09-02 off Jade Monolith's
		# whole-event redirect.
		game.add_point_redirect(source, source.owner_id, 1)

	func describe() -> String:
		return "the next 1 damage to it is dealt to its owner instead"
