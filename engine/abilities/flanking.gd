class_name Flanking
extends RefCounted
## FLANKING (CR 702.25, the Mirage block's knights): "Whenever a creature
## without flanking blocks this creature, the blocking creature gets -1/-1
## until end of turn."
##
## A TRIGGERED ability (702.25a), and one per INSTANCE (702.25b: "If a
## creature has multiple instances of flanking, each triggers separately")
## — Agility on a Femeref Knight is two of them and a blocker meets -2/-2.
## So it is not a flag the combat code reads but a real stack trigger:
##
## - THE COUNT is the number of `Mtg.Keyword.FLANKING` entries in
##   [member CardInstance.cur_keywords] ([method instances]). Printed
##   flanking is one entry (`CardData.with_keywords([FLANKING])`); every
##   grant adds one more — a floating grant (Jabari's Banner, through
##   `add_until_eot_keywords` or a PumpEffect's keyword list; the layer-6
##   pass keeps duplicates of THIS keyword only) and a static grant
##   ([method grant], Agility). A LOSS ("loses flanking until end of turn",
##   Barbed Foliage, `add_until_eot_loss`) removes every entry, and a grant
##   timestamped after it is back (CR 613.7). "Has flanking" stays
##   `has_keyword(FLANKING)` for Telim'Tor and Knight of Valor.
## - THE TRIGGER is synthesised from the count at the end of every
##   recalculation ([method synthesise], called by
##   ContinuousEffects.recalculate): one entry of the game's ONE shared
##   flanking [TriggeredAbility] per instance in
##   [member CardInstance.cur_triggered_abilities]. One shared object, so
##   the live list is identical across recalculations — the rewinds compare
##   it by identity. MtgGame.dispatch_event does the rest: a silenced
##   permanent (Titania's Song) hears nothing, the attacker's controller
##   controls the trigger, and every trigger goes on the stack, so the
##   blocker can be pumped (or the attack answered) in response.
## - WHEN: on [constant Mtg.EventType.BLOCKED], which MtgGame dispatches
##   once per blocker per attacker — for every member of a band whose
##   blocker it is (CR 702.22h: blocking one member blocks the band) and
##   for a block an effect makes (MtgGame.set_block). That is CR 509.3d's
##   "becomes blocked by a creature" (the modern wording of 702.25a): once
##   per blocking creature, never for "becomes blocked" by an effect
##   without a creature (Dazzling Beauty, MtgGame.make_blocked).
##   "Without flanking" is read as the event happens (CR 509.3f): a
##   blocker that gains flanking in response still shrinks.
## - RESOLUTION: the blocker that blocked — the same object, CR 400.7 —
##   gets -1/-1 until end of turn. Its source need not still be there
##   (CR 113.7a). Not targeted: protection and shroud do not stop it.
##
## Identical under both rules profiles (engine/rules_options.gd forks
## nothing here): Mirage printed flanking as this trigger.
##
## The fair AI prices it as well — see AiPlayer._flanking_shrink and
## CombatSearch.a_flanking.

## The stack line and the card text of one instance.
const TEXT := "Flanking — whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn"


## How many instances of flanking [param inst] has right now (CR 702.25b).
## Live: printed plus granted minus lost.
static func instances(inst: CardInstance) -> int:
	if inst == null:
		return 0
	return inst.cur_keywords.count(Mtg.Keyword.FLANKING)


## Grant ONE more instance of flanking from a layer-6 STATIC ("enchanted
## creature has flanking" — Agility). Call it from the static's `apply`
## callback, built `.changing_abilities()` so it runs in the timestamped
## layer-6 pass with the losses. Never deduplicated: two Agilities are two
## instances.
static func grant(inst: CardInstance) -> void:
	if inst != null:
		inst.cur_keywords.append(Mtg.Keyword.FLANKING)


## The triggered ability ONE instance of flanking is. Built once per game
## (ContinuousEffects.flanking_trigger) and shared by every instance.
static func trigger() -> TriggeredAbility:
	return TriggeredAbility.new(Mtg.EventType.BLOCKED, _shrink, TEXT,
		_blocked_by_a_creature_without_flanking).capturing(_capture)


## Append [param ability] (the game's one flanking trigger) once per
## flanking instance to every permanent in [param battlefield] — the last
## pass of the recalculation, after layer 6 has settled every grant and
## loss.
static func synthesise(battlefield: Array[CardInstance], ability: TriggeredAbility) -> void:
	for inst in battlefield:
		var count := instances(inst)
		for _i in count:
			inst.cur_triggered_abilities.append(ability)


## The trigger condition: THIS creature is the attacker, and the blocker
## has no flanking at the moment it blocks (CR 509.3f).
static func _blocked_by_a_creature_without_flanking(_game: MtgGame,
		source: CardInstance, event: GameEvent) -> bool:
	if event.data.get("attacker") != source:
		return false
	var blocker: CardInstance = event.data.get("blocker")
	return blocker != null and blocker.is_creature() \
		and not blocker.has_keyword(Mtg.Keyword.FLANKING)


## Which object blocked: the blocker's battlefield incarnation as the
## trigger fired, so a blocker that leaves and comes back is a new object
## the -1/-1 never meant (CR 400.7).
static func _capture(_game: MtgGame, _source: CardInstance, event: GameEvent) -> Dictionary:
	var blocker: CardInstance = event.data.get("blocker")
	if blocker == null:
		return {}
	return {"blocker": blocker.id, "stamp": blocker.layer_timestamp}


static func _shrink(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var context := game.trigger_context(source)
	var blocker := game.find_instance(int(context.get("blocker", -1)))
	# Phased out meanwhile: it does not exist, and nothing affects it
	# (CR 702.26b) — MtgGame.is_present.
	if not game.is_present(blocker) \
			or blocker.layer_timestamp != int(context.get("stamp", -1)):
		return
	game.continuous.add_until_eot_pump(blocker.id, -1, -1)
	game.log_line("Flanking: %s gets -1/-1 until end of turn" % blocker.data.card_name,
		blocker)
	game.recalculate()
