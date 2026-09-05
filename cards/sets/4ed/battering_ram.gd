extends CardScript
## Battering Ram — {2} — Artifact Creature — Construct — 1/1 — (4ed, common)
## Oracle: At the beginning of combat on your turn, this creature gains
##         banding until end of combat.
##         Whenever this creature becomes blocked by a Wall, destroy that
##         Wall at end of combat.
##
## Implementation: the banding is a floating until-END-OF-COMBAT keyword
## grant (ContinuousEffects.add_until_eot_keywords, new) hung on the Ram by
## a COMBAT_START trigger (Mtg.EventType.COMBAT_START, new) — the moment
## before attackers are declared, which is exactly when a band has to exist
## to be declared.
##
## The Wall is doomed with MtgGame.doom_at_end_of_combat, so it fights
## normally and only then falls — a Wall of Stone stops the Ram this combat
## and is gone by the next one.
##
## Attack bands are implemented; DEFENSIVE banding is not (engine-wide,
## docs/ROADMAP.md), so the granted keyword does what banding does here:
## the Ram may attack in a band.


func build() -> CardData:
	return CardData.new("Battering Ram", "{2}", Mtg.CardType.ARTIFACT
			| Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["construct"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.COMBAT_START, _band_up,
			"At the beginning of combat on your turn, this creature gains banding until end of combat.",
			_your_combat)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BLOCKED, _doom_the_wall,
			"Whenever this creature becomes blocked by a Wall, destroy that Wall at end of combat.",
			_blocked_by_a_wall)) \
		.oracle("At the beginning of combat on your turn, this creature gains "
			+ "banding until end of combat. (Any creatures with banding, and up to "
			+ "one without, can attack in a band. Bands are blocked as a group. If "
			+ "any creatures with banding you control are being blocked by a "
			+ "creature, you divide that creature's combat damage, not its "
			+ "controller, among any of the creatures it's blocking.)\nWhenever this "
			+ "creature becomes blocked by a Wall, destroy that Wall at end of combat.")


static func _your_combat(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _band_up(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	game.continuous.add_until_eot_keywords(source.id, [Mtg.Keyword.BANDING], true)
	game.recalculate()


static func _blocked_by_a_wall(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	var attacker: CardInstance = event.data["attacker"]
	var blocker: CardInstance = event.data["blocker"]
	return attacker == source and blocker.has_subtype("wall")


static func _doom_the_wall(game: MtgGame, _source: CardInstance,
		event: GameEvent) -> void:
	var wall: CardInstance = event.data["blocker"]
	if wall.zone == Mtg.Zone.BATTLEFIELD:
		game.doom_at_end_of_combat(wall)
