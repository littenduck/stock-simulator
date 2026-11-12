## One numeric effect of a perk: changes RunModifiers field `stat` with `op`.
## CONTRACT: frozen.
class_name PerkEffectDef
extends Resource

enum Op { ADD, MULTIPLY, SET }

## Must be an existing RunModifiers field, e.g. &"fee_mult".
@export var stat: StringName
@export var op: Op = Op.ADD
@export var value: float = 0.0
