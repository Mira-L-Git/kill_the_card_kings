extends RefCounted

const ART_SIZE := Vector2(240, 336)

# 按三套现有牌框的外沿取点，坐标以原图为准。
const STANDARD := [
	Vector2(12, 2), Vector2(228, 2), Vector2(232, 4), Vector2(236, 7),
	Vector2(238, 11), Vector2(239, 15), Vector2(239, 321), Vector2(238, 325),
	Vector2(236, 329), Vector2(232, 332), Vector2(228, 334), Vector2(12, 334),
	Vector2(8, 332), Vector2(4, 329), Vector2(1, 324), Vector2(0, 320),
	Vector2(0, 15), Vector2(2, 11), Vector2(4, 7), Vector2(8, 4),
]
const GENERAL := [
	Vector2(13, 4), Vector2(227, 4), Vector2(231, 8), Vector2(235, 12),
	Vector2(238, 16), Vector2(238, 320), Vector2(235, 324), Vector2(231, 329),
	Vector2(227, 332), Vector2(13, 332), Vector2(9, 329), Vector2(5, 325),
	Vector2(2, 321), Vector2(2, 16), Vector2(5, 12), Vector2(9, 8),
]
const JOKER := [
	Vector2(14, 4), Vector2(226, 4), Vector2(232, 7), Vector2(236, 11),
	Vector2(239, 16), Vector2(239, 315), Vector2(236, 322), Vector2(231, 326),
	Vector2(225, 330), Vector2(15, 330), Vector2(10, 326), Vector2(6, 322),
	Vector2(3, 316), Vector2(3, 17), Vector2(6, 11), Vector2(10, 7),
]
