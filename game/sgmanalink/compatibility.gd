class_name SgCompatibility
extends RefCounted
## Portable compatibility stamp, not authentication or cheat detection.
## Bump RULES_REVISION whenever engine/card behavior changes without a release
## version change. The catalogue digest additionally pins printed definitions.
## The readable stamp travels beside the digest so a mismatch can be named
## ("you run 0.31.0", "the host has Pack 3 enabled") instead of only detected.

const RULES_REVISION := "sgmanalink-damage-window-2026-09-23"
const MAX_PACKS := 12
static var _fingerprint := ""
static var _cache_key := ""

static func fingerprint() -> String:
	CardRegistry.ensure_loaded()
	var cache_key := str([CardRegistry.revision, SgProtocol.VERSION, RULES_REVISION,
		ProjectSettings.get_setting("application/config/version", "")])
	if _cache_key == cache_key and not _fingerprint.is_empty(): return _fingerprint
	var names: Array = CardRegistry._cards.keys()
	names.sort()
	var catalogue: Array = []
	for name in names:
		var card := CardRegistry.get_card(name)
		catalogue.append([name, str(card.cost), card.oracle_text, card.types, card.power, card.toughness])
	_fingerprint = JSON.stringify([SgProtocol.VERSION, RULES_REVISION,
		ProjectSettings.get_setting("application/config/version", ""), catalogue]).sha256_text()
	_cache_key = cache_key
	return _fingerprint


static func game_version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", ""))


## Enabled card pack ids, sorted; the packs a duel's catalogue is built from.
static func enabled_packs() -> Array:
	var packs: Array = []
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id): packs.append(String(id))
	packs.sort()
	return packs


## Readable, bounded facts about this build. Wire-safe: short ASCII only.
static func stamp() -> Dictionary:
	return {"game": game_version(), "rules": RULES_REVISION, "packs": enabled_packs()}


static func valid_stamp(value: Variant) -> bool:
	if not value is Dictionary or not SgProtocol.exact(value, ["game", "rules", "packs"]) \
		or not plain(value.game, 24) or not plain(value.rules, 48) \
		or not value.packs is Array or value.packs.size() > MAX_PACKS:
		return false
	for id in value.packs:
		if not plain(id, 12): return false
	return true


## Version-like text: ASCII letters, digits, dots, dashes and underscores.
static func plain(value: Variant, limit: int) -> bool:
	if not value is String or value.is_empty() or value.length() > limit:
		return false
	for c in value:
		if not "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-".contains(c):
			return false
	return true


static func pack_labels(ids: Array) -> String:
	if ids.is_empty(): return "no card packs"
	var numbers: PackedStringArray = []
	for id in ids: numbers.append(String(id).trim_prefix("pack-"))
	return ("Pack " if ids.size() == 1 else "Packs ") + ", ".join(numbers)


## One line for the lobby: what the other computer must match.
static func summary() -> String:
	return "Shandalar %s  ·  %s" % [game_version(), pack_labels(enabled_packs())]


## Name the first difference between the reader's own stamp and another one,
## or "" when they agree. Read from the reader's side: "you" versus `them`.
static func difference(mine: Dictionary, theirs: Dictionary, them := "The host") -> String:
	if not valid_stamp(mine) or not valid_stamp(theirs):
		return "%s runs an unknown game build." % them
	if mine.game != theirs.game:
		return "%s runs Shandalar %s; you run %s. Both players need the same version." % [them, theirs.game, mine.game]
	var missing: Array = []
	for id in theirs.packs:
		if not mine.packs.has(id): missing.append(id)
	var extra: Array = []
	for id in mine.packs:
		if not theirs.packs.has(id): extra.append(id)
	if not missing.is_empty():
		return "%s has %s enabled; you do not. Enable the same packs in Options." % [them, pack_labels(missing)]
	if not extra.is_empty():
		return "You have %s enabled; %s does not. Both players need the same enabled packs." % [pack_labels(extra), them.to_lower()]
	if mine.rules != theirs.rules:
		return "%s runs a different build of Shandalar %s (rules %s; yours is %s). Both players need the same build." \
			% [them, theirs.game, theirs.rules, mine.rules]
	return ""


## The same first difference for a table cell: a few words, "" when none.
static func brief(mine: Dictionary, theirs: Dictionary) -> String:
	if not valid_stamp(mine) or not valid_stamp(theirs): return "Unknown build"
	if mine.game != theirs.game: return "Shandalar %s" % theirs.game
	if mine.packs != theirs.packs: return "No card packs" if theirs.packs.is_empty() else pack_labels(theirs.packs)
	if mine.rules != theirs.rules: return "Different build"
	return ""


## Why two builds with equal stamps still differ: modified files or card data.
static func catalogue_mismatch(them := "The host") -> String:
	return "%s runs Shandalar %s with the same packs, but its card catalogue differs (modified game or card files). Both players need identical, unmodified files." % [them, game_version()]
