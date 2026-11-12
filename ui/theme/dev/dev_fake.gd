## Dev harness helpers: fake content and screenshot capture. Not used by the game.
class_name DevFake
extends RefCounted


static func perk(id: String, rarity: PerkDef.Rarity, desc: String) -> PerkDef:
	var p := PerkDef.new()
	p.id = StringName(id)
	p.title_key = id.capitalize()
	p.description_key = desc
	p.rarity = rarity
	return p


static func perks(count: int) -> Array:
	var all: Array = [
		perk("low_fees", PerkDef.Rarity.COMMON, "Trading fees are halved."),
		perk("margin_account", PerkDef.Rarity.RARE, "Maximum leverage +1x. Margin calls hurt more."),
		perk("market_maker", PerkDef.Rarity.LEGENDARY, "No fees at all, and limit orders fill slightly better."),
		perk("savings_account", PerkDef.Rarity.COMMON, "Idle cash earns 0.05% per day."),
	]
	return all.slice(0, count)


static func character(id: String, cash: float, unlock: String = "") -> CharacterDef:
	var c := CharacterDef.new()
	c.id = StringName(id)
	c.title_key = id.capitalize()
	c.description_key = "A starting character called %s." % id.capitalize()
	c.start_cash = cash
	c.unlock_id = StringName(unlock)
	return c


## Waits for layout to settle, writes a PNG if `--shot=<path>` was passed, then quits.
static func shot_if_requested(node: Node) -> void:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			path = arg.trim_prefix("--shot=")
	if path.is_empty():
		return
	for i in 6:
		await node.get_tree().process_frame
	var img := node.get_viewport().get_texture().get_image()
	img.save_png(path)
	node.get_tree().quit()
