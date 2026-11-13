## Joke headlines that fit any stock: one list for rumors that claim a rise, one for a fall.
## The text holds a single %s for the company name. Specific rumors (data/news) are preferred when a stock has one.
class_name GenericRumors
extends RefCounted

const UP: Array[String] = [
	"GENERIC_UP_1", "GENERIC_UP_2", "GENERIC_UP_3", "GENERIC_UP_4", "GENERIC_UP_5", "GENERIC_UP_6",
	"GENERIC_UP_7", "GENERIC_UP_8", "GENERIC_UP_9", "GENERIC_UP_10",
]
const DOWN: Array[String] = [
	"GENERIC_DOWN_1", "GENERIC_DOWN_2", "GENERIC_DOWN_3", "GENERIC_DOWN_4", "GENERIC_DOWN_5", "GENERIC_DOWN_6",
	"GENERIC_DOWN_7", "GENERIC_DOWN_8", "GENERIC_DOWN_9", "GENERIC_DOWN_10",
]


static func keys(dir: int) -> Array[String]:
	return UP if dir > 0 else DOWN
