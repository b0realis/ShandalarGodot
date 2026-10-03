class_name SourceShieldEffect
extends EffectBase
## "The next time a source of your choice would deal damage <to whom> this
## turn, <prevent that damage | that damage is dealt to that source's
## controller instead>" — the Mirage block's family, as one declarative
## effect over the engine's damage replacement suite
## (`engine/damage_replacements.gd`, [method MtgGame.add_damage_effect]).
##
## THE SOURCE is chosen AS THE EFFECT RESOLVES (CR 609.7a: "The source is
## chosen when the effect is created") from [method MtgGame.damage_sources]
## — every permanent and every spell on the stack, ranked so the default is
## the one about to deal damage to what is being shielded — narrowed by
## [method from_sources] ("a source you control", "a red source"). With
## nothing to name the effect does nothing (CR 608.2), which is why these
## spells are cast in response.
##
## THE VICTIMS ([enum Victims]):
## - TARGET — "... to any target" (Circle of Despair, Honorable Passage):
##   the effect targets a creature or player ([method to_target]); a
##   target gone by resolution fizzles the spell, and a creature that
##   leaves afterwards is a new object the shield does not follow (CR 400.7).
## - YOU_AND_YOUR_CREATURES — "... to you and/or creatures you control"
##   (Shadowbane): untargeted, ONE shield over the controller and every
##   creature they control when the damage would be dealt, used up by ONE
##   damage event however many of them it touches (CR 615.8).
## - ENCHANTED — "... to enchanted creature" (Kithkin Armor): the creature
##   the effect's source is (or, sacrificed as the cost, last was)
##   attached to.
## - ANY — "the next time a source of your choice would deal damage this
##   turn" (Reflect Damage): every victim.
##
## THE ACTION ([enum Action]): PREVENT the damage; REFLECT it onto the
## source's controller (a redirect, so the reflected damage is still that
## source's); or DOUBLE it. [method with_rider] adds the "if damage from a
## black source is prevented this way, you gain that much life" sentence —
## run with the amount each damage packet lost (CR 615.5).
##
## Legal in the 1997 damage-prevention window ([member
## EffectBase.is_damage_prevention]): created during the window, the shield
## applies as the waiting damage lands at the window's end.

enum Victims { TARGET, YOU_AND_YOUR_CREATURES, ENCHANTED, ANY, YOU }
enum Action { PREVENT, REFLECT, DOUBLE }

var victims: int = Victims.TARGET
var action: int = Action.PREVENT
## `func(game: MtgGame, source: CardInstance, controller: int) -> bool` —
## which sources may be named; invalid = any source.
var source_accept: Callable = Callable()
## Card English for the prompt: "a source", "a source you control".
var source_desc: String = "a source"
## `func(game: MtgGame, packet: DamagePacket, amount: int, effect_source:
## CardInstance, controller: int) -> void` — the rider.
var rider: Callable = Callable()


func _init(p_victims: int = Victims.TARGET, p_action: int = Action.PREVENT) -> void:
	victims = p_victims
	action = p_action
	is_damage_prevention = true
	if victims == Victims.TARGET:
		target_spec = TargetSpec.any_target()


## "The next time a source of your choice would deal damage to any target
## this turn, prevent that damage." (Circle of Despair, Honorable Passage)
static func prevent_to_target() -> SourceShieldEffect:
	return SourceShieldEffect.new(Victims.TARGET, Action.PREVENT)


## "... to you and/or creatures you control this turn, prevent that
## damage." (Shadowbane)
static func prevent_to_you_and_your_creatures() -> SourceShieldEffect:
	return SourceShieldEffect.new(Victims.YOU_AND_YOUR_CREATURES, Action.PREVENT)


## "... to you this turn, prevent that damage."
static func prevent_to_you() -> SourceShieldEffect:
	return SourceShieldEffect.new(Victims.YOU, Action.PREVENT)


## "... to enchanted creature this turn, prevent that damage." (Kithkin
## Armor — the effect's source is the Aura, sacrificed as the cost.)
static func prevent_to_enchanted() -> SourceShieldEffect:
	return SourceShieldEffect.new(Victims.ENCHANTED, Action.PREVENT)


## "The next time a source of your choice would deal damage this turn,
## that damage is dealt to that source's controller instead." (Reflect
## Damage)
static func reflect() -> SourceShieldEffect:
	return SourceShieldEffect.new(Victims.ANY, Action.REFLECT)


## Fluent: narrow the sources that may be named (CR 609.7a): [param desc]
## is the card English for the prompt ("a source you control"),
## [param accept] `func(game, source, controller) -> bool`.
func from_sources(desc: String, accept: Callable) -> SourceShieldEffect:
	source_desc = desc
	source_accept = accept
	return self


## Fluent: the target is a creature or player of [param spec] instead of
## "any target".
func to_target(spec: TargetSpec) -> SourceShieldEffect:
	victims = Victims.TARGET
	target_spec = spec
	return self


## Fluent: add the rider (see [member rider]).
func with_rider(cb: Callable) -> SourceShieldEffect:
	rider = cb
	return self


func resolve(game: MtgGame, source: CardInstance, controller: int,
		target: TargetRef, _x_value: int = 0) -> void:
	var shielded: Array = []
	var creatures_of := -1
	var threatened: TargetRef = null
	match victims:
		Victims.TARGET:
			if target == null:
				return
			shielded = [target]
			threatened = target
		Victims.YOU_AND_YOUR_CREATURES:
			shielded = [TargetRef.player(controller)]
			creatures_of = controller
			threatened = null   # ranked for you AND your creatures
		Victims.YOU:
			shielded = [TargetRef.player(controller)]
			threatened = TargetRef.player(controller)
		Victims.ENCHANTED:
			var host_id := source.attached_to if source.attached_to >= 0 \
				else source.last_attached_to
			var host := game.find_instance(host_id)
			if host == null or not game.is_present(host):
				game.log_line("%s: the creature is gone, nothing is shielded"
					% source.data.card_name)
				return
			shielded = [host]
			threatened = TargetRef.card(host)
	var named := game.choose_damage_source(controller,
		"%s: Select %s." % [source.data.card_name, source_desc],
		_accepts.bind(game, controller), threatened)
	if named == null:
		game.log_line("%s: nothing to name as %s, nothing happens" % [
			source.data.card_name, source_desc])
		return
	var then := Callable()
	if rider.is_valid():
		then = SourceShieldEffect._run_rider.bind(rider, source, controller)
	var desc := "%s (%s)" % [source.data.card_name, named.data.card_name]
	match action:
		Action.PREVENT:
			var spec := {"kind": &"prevent", "one_shot": true, "controller": controller,
				"card": source.data.card_name, "source": named, "victims": shielded,
				"creatures_of": creatures_of, "desc": desc}
			if then.is_valid():
				spec["then"] = then
			game.add_damage_effect(spec)
		Action.REFLECT:
			var spec := {"kind": &"redirect", "one_shot": true,
				"to_source_controller": true, "controller": controller,
				"card": source.data.card_name, "source": named, "victims": shielded,
				"creatures_of": creatures_of, "desc": desc}
			if then.is_valid():
				spec["then"] = then
			game.add_damage_effect(spec)
		Action.DOUBLE:
			game.add_damage_effect({"kind": &"modify", "factor": 2, "one_shot": true,
				"controller": controller, "card": source.data.card_name,
				"source": named, "victims": shielded, "creatures_of": creatures_of,
				"desc": desc})
	game.log_line("%s watches %s" % [source.data.card_name, named.data.card_name])


func _accepts(inst: CardInstance, game: MtgGame, controller: int) -> bool:
	return not source_accept.is_valid() or bool(source_accept.call(game, inst, controller))


static func _run_rider(game: MtgGame, packet: DamagePacket, amount: int,
		cb: Callable, effect_source: CardInstance, controller: int) -> void:
	cb.call(game, packet, amount, effect_source, controller)


func describe() -> String:
	var whom := ""
	match victims:
		Victims.TARGET: whom = " to %s" % (target_spec.description if target_spec != null else "any target")
		Victims.YOU_AND_YOUR_CREATURES: whom = " to you and/or creatures you control"
		Victims.YOU: whom = " to you"
		Victims.ENCHANTED: whom = " to enchanted creature"
	var what := "prevent that damage"
	match action:
		Action.REFLECT: what = "that damage is dealt to that source's controller instead"
		Action.DOUBLE: what = "it deals double that damage instead"
	return "the next time %s of your choice would deal damage%s this turn, %s" % [
		source_desc, whom, what]
