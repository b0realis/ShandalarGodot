class_name DraftStore
extends RefCounted
## [QoL] Unique draft files and atomic, exact-deck recovery checkpoints.

var deck_path := ""
var pool_path := ""
var receipt: Dictionary = {}
var _last_text := ""


func prepare(folder: String, pool: SealedPool, options: Dictionary) -> String:
	if not pool.draft_recipe.is_empty():
		var replay := DraftRecipe.reconstruct(pool.draft_recipe)
		if not replay.ok: return replay.message
		if replay.pool.counts != pool.counts or replay.pool.packs != pool.packs:
			return "The draft recipe does not match the dealt pool."
		for key in DraftRecipe.OPTION_KEYS:
			if options.get(key) != pool.draft_recipe.options[key]: return "Draft options do not match the dealt recipe."
	var refusal := GamePaths.draft_folder_refusal(folder)
	if refusal != "": return refusal
	folder = ProjectSettings.globalize_path(GamePaths.expand(folder.strip_edges())).simplify_path()
	var error := DirAccess.make_dir_recursive_absolute(folder)
	if error != OK: return "Cannot create the save folder: " + error_string(error)
	var bytes := Crypto.new().generate_random_bytes(12)
	if bytes.size() != 12: return "Randomness is unavailable. No draft was started."
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var stem := "draft-%s-%s" % [stamp, bytes.hex_encode().left(12)]
	deck_path = folder.path_join(stem + ".deck")
	pool_path = folder.path_join(stem + ".pool.json")
	for path in [deck_path, pool_path]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			return "The new draft filename is already in use. Try launching again."
	receipt = {"schema": 1, "created": Time.get_datetime_string_from_system(true),
		"version": ProjectSettings.get_setting("application/config/version", ""),
		"collation": "printed-rarity-v1", "pack_shapes": {"booster": SealedPool.BOOSTER, "starter": SealedPool.STARTER},
		# Which card packs this pool needs to be playable again. The recipe
		# itself stays frozen at v1 and carries only card names; this receipt
		# field is what tells an organiser which shelf to switch on.
		"required_packs": CardPacks.packs_required_by(pool.names()),
		"options": options.duplicate(), "counts": pool.counts.duplicate(),
		"packs": pool.packs.duplicate(true), "state": "building"}
	if not pool.draft_recipe.is_empty():
		receipt["recipe"] = pool.draft_recipe.duplicate(true)
		receipt["collation"] = DraftRecipe.ALGORITHM
	return _write(pool_path, JSON.stringify(receipt, "\t") + "\n")


func checkpoint(deck: DeckModel, reason := "building") -> String:
	if deck_path.is_empty(): return "No draft output was prepared."
	# Last-line defence against any future builder command bypassing the pool.
	for card_name in deck.names() + deck.side_names():
		if deck.copies_of(card_name) > int(receipt.counts.get(card_name, 0)):
			return "The deck contains cards outside the dealt pool; it has not been saved."
	var text := deck_text(deck)
	if text != _last_text or reason != "building" or not FileAccess.file_exists(deck_path):
		var refusal := _write(deck_path, text)
		if refusal != "": return refusal
		_last_text = text
	if reason != String(receipt.state):
		receipt.state = reason
		receipt["main_cards"] = deck.total()
		receipt["sideboard_cards"] = deck.side_total()
		receipt["finished"] = Time.get_datetime_string_from_system(true)
		var refusal := _write(pool_path, JSON.stringify(receipt, "\t") + "\n")
		if refusal != "":
			receipt.state = "building"
			return refusal
	return ""


## Both native checkpoints and web downloads must carry identical metadata.
func deck_text(deck: DeckModel) -> String:
	if not receipt.has("recipe"): return deck.to_text()
	var copy := deck.duplicate_model()
	copy.draft_comments = DraftRecipe.comments(receipt.recipe)
	return copy.to_text()


## WHOLE OR NOT AT ALL, through [method Settings.write_atomically] (the
## bug campaign c12, h6-3). The side file was written and renamed into
## place unchecked — on a full disk the buffered store and its flush
## reported no error, so a checkpoint cut short replaced the good one
## and the draft said it was saved. Now the length that reached the disk
## is checked before the rename; anything less leaves the earlier
## checkpoint exactly as it was and no side file behind.
static func _write(path: String, text: String) -> String:
	var error := Settings.write_atomically(path, text.to_utf8_buffer())
	if error != OK: return "Cannot save the draft: " + error_string(error)
	return ""
