class_name SgTableRules
extends RefCounted
## THE TABLE RULES (2026-10-02). What a host chooses for their table and
## every seat plays under: the starting life and the seven implemented
## RulesOptions forks. The owner's word: *"establish a togglable,
## modifiable basic table rules when you host the game"*. A plain
## dictionary on the wire — `{"life": 20, "forks": {key: bool, ...}}` —
## so the host command, the room view, a tournament's configuration and
## its checkpoint all carry the same shape, validated by [method valid]
## wherever it arrives from another computer. [method standard] is the
## table every host opened before this existed: 20 life under the player
## default preset (modern rules, mana burn on); a message without the
## field means that table, so an older checkpoint restores unchanged.
## Only the referee's process applies them ([method apply]); a client
## sees them in the room view and again in every duel view's presentation.

const MIN_LIFE := 1
## The local setup screen's own ceiling; the life panels show three digits.
const MAX_LIFE := 400
const DEFAULT_LIFE := 20
## The forks a table may set: exactly RulesOptions.IMPLEMENTED, in its
## order. An unbuilt fork has no place on the wire.
const FORKS := RulesOptions.IMPLEMENTED


## The table every host opened before table rules existed.
static func standard() -> Dictionary:
	var options := RulesOptions.new()
	options.set_preset(RulesOptions.DEFAULT_PRESET)
	return from_options(DEFAULT_LIFE, options)


## A wire dictionary from a life total and a RulesOptions.
static func from_options(life: int, options: RulesOptions) -> Dictionary:
	var forks := {}
	for key: String in FORKS: forks[key] = options.get_fork(key)
	return {"life": clampi(life, MIN_LIFE, MAX_LIFE), "forks": forks}


## Exactly the two fields, an integral life in range, and exactly the
## implemented forks each answered with a bool — nothing else, whatever
## the sender's build knows about.
static func valid(value: Variant) -> bool:
	if not value is Dictionary or not SgProtocol.exact(value, ["life", "forks"]): return false
	if not SgProtocol.integer(value.life, MIN_LIFE, MAX_LIFE): return false
	if not value.forks is Dictionary or not SgProtocol.exact(value.forks, FORKS): return false
	for key: String in FORKS:
		if not value.forks[key] is bool: return false
	return true


## A private copy of a valid value; the standard table for anything else
## (an absent field, an older checkpoint, a hand-built fixture).
static func normalize(value: Variant) -> Dictionary:
	if not valid(value): return standard()
	return {"life": int(value.life), "forks": (value.forks as Dictionary).duplicate()}


static func life(rules: Dictionary) -> int:
	return clampi(int(rules.get("life", DEFAULT_LIFE)), MIN_LIFE, MAX_LIFE)


## The RulesOptions a table plays under: the engine's own answers for
## every fork it cannot set, the table's for the seven it can.
static func options(rules: Dictionary) -> RulesOptions:
	var result := RulesOptions.new()
	var forks: Dictionary = rules.get("forks", {})
	for key: String in FORKS:
		if forks.has(key): result.set_fork(key, bool(forks[key]))
	return result


## Set a game's forks from the table's. Life goes through MtgGame.setup,
## so it is the referee's to pass ([SgPracticeMatch]).
static func apply(game: MtgGame, rules: Dictionary) -> void:
	var forks: Dictionary = rules.get("forks", {})
	for key: String in FORKS:
		if forks.has(key): game.rules.set_fork(key, bool(forks[key]))


## The preset the forks match exactly, by its Options-screen name, or
## "Custom".
static func preset_label(rules: Dictionary) -> String:
	return RulesOptions.preset_label(options(rules).preset())


## One line for a browser row or a readout: "Modern rules, mana burn on
## · 20 life". Bounded by the preset labels and three digits of life.
static func brief(rules: Dictionary) -> String:
	return "%s  ·  %d life" % [preset_label(rules), life(rules)]


## Every fork, on or off, for the waiting room's "Duel rules" column when
## the table is Custom and a name says nothing.
static func detail(rules: Dictionary) -> String:
	var options_value := options(rules)
	var parts: Array[String] = []
	for fork in RulesOptions.FORKS:
		if not FORKS.has(fork["key"]): continue
		parts.append("%s: %s" % [fork["label"], "on" if options_value.get_fork(fork["key"]) else "off"])
	return "  ·  ".join(parts)


## The waiting room's column: the pool and deck bounds every table shares,
## then this table's life and rules.
static func summary(rules: Dictionary) -> String:
	var text := "Full implemented card pool  ·  40–250 cards  ·  %d life\n%s  ·  Single duel" % [life(rules), preset_label(rules)]
	if options(rules).preset() == "custom": text += "\n" + detail(rules)
	return text
