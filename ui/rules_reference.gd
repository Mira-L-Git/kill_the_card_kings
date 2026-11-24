extends "res://ui/tutorial_overlay.gd"

signal closed

const BattleScreen = preload("res://ui/battle_screen.gd")
const PAGES := [
	{
		"key": "Interface", "tab": "界面", "title": "认识战斗界面",
		"text": "左上角是牌王进度。依次击败 J、Q、K 共十二位牌王。\n牌王上方是生命和攻击，下方是手牌和出牌按钮。\n右下角的抽牌堆和弃牌堆显示各自的牌数。\n反击时看桌面中央。点击手牌会立即弃掉，用点数抵伤。\nA 不能抵伤。",
		"focus": ["progress", "stats", "hand", "submit", "piles"],
	},
	{
		"key": "Play", "tab": "出牌", "title": "哪些牌可以一起出",
		"text": "主牌　可单出 4 到 10，或 J、Q、K（11、12、13）。\n连携　2 和 3 可单出，也可一起打出多张同点数的牌。\n宠物　A 可搭配一张主牌。A 不能单出或搭配连携牌。\n选牌顺序不限，再点已选牌可取消。选好后点「出牌」。",
		"focus": ["hand", "submit"],
	},
	{
		"key": "Suits", "tab": "花色", "title": "四种花色怎么结算",
		"text": "先按出牌总数值造成基础伤害，再按以下顺序结算。\n♥ 红桃　从弃牌堆回收，放回抽牌堆底\n♦ 方片　从抽牌堆抽牌，手牌最多八张\n♣ 梅花　追加伤害\n♠ 黑桃　获得本回合用来抵挡反击的护盾\n打出的花色各触发一次，效果强度都取出牌总数值。\n牌王封锁同花色的效果，基础伤害照常。",
		"focus": ["enemy", "piles"],
	},
	{
		"key": "Revival", "tab": "复活", "title": "王牌让你复活",
		"text": "出牌开始或承受反击时，手牌用尽或只剩 A 就会死亡。\n复活先消耗大王，再消耗小王。\n弃掉旧手牌，尽量补到八张。抽牌堆不够时从弃牌堆回收。\n反击时复活会结束本次伤害。\n王牌用完后再死亡，本局结束。",
		"focus": ["jokers", "hand"],
	},
	{
		"key": "Pacification", "tab": "感化", "title": "恰好打到 0 就能感化",
		"text": "等伤害和花色效果全部结算后，再看牌王生命。\n恰好是 0　获得将军牌。手牌已满时放到抽牌堆顶。\n低于 0　直接击败牌王。\n牌王被击败或感化后，这次不会反击。",
		"focus": ["enemy", "stats", "hand"],
	},
]

var _battle: BattleScreen
var _page := 0
var _navigation: HBoxContainer
var _chapters: Array[Button] = []


func _ready() -> void:
	super._ready()
	name = "RulesReference"
	_panel.name = "ReferencePanel"
	advanced.connect(_advance)
	_navigation = HBoxContainer.new()
	_navigation.name = "Chapters"
	_navigation.position.x = 52
	_navigation.size.x = 1016
	_navigation.add_theme_constant_override("separation", 14)
	_panel.add_child(_navigation)
	for i in range(PAGES.size()):
		var chapter := _chapter_button(PAGES[i].key, PAGES[i].tab, _select_page.bind(i))
		chapter.toggle_mode = true
		_chapters.append(chapter)
	_chapter_button("Close", "返回对战", func(): closed.emit())


func show_on(battle: BattleScreen) -> void:
	_battle = battle
	_select_page(_page)


func dismiss() -> void:
	_battle = null
	_page = 0
	present({}, [])


func _select_page(index: int) -> void:
	_page = index
	var page: Dictionary = PAGES[index]
	var targets: Array[Control] = _battle.guide_targets(page.focus)
	present({"title": page.title, "text": page.text, "explanation": true, "diagram": false}, targets)
	focus_mode = Control.FOCUS_CLICK
	_hint.text = "点击空白处返回对战" if index == PAGES.size() - 1 else "点击空白处继续"
	_navigation.position.y = maxf(530, _panel.size.y - 12)
	_hint.position.y = _navigation.position.y - 64
	_panel.size.y = _navigation.position.y + 90
	for i in range(_chapters.size()):
		_chapters[i].set_pressed_no_signal(i == index)


func _advance() -> void:
	if _page == PAGES.size() - 1:
		closed.emit()
	else:
		_select_page(_page + 1)


func _chapter_button(node_name: String, caption: String, action: Callable) -> Button:
	var button := Style.button(_navigation, node_name, caption, Rect2(), action)
	button.custom_minimum_size.y = 62
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", Style.box(Color("282026"), Color("584337")))
	button.add_theme_stylebox_override("hover", Style.box(Color("382a28"), Color("b19165")))
	button.add_theme_stylebox_override("pressed", Style.box(Color("493329"), Color("d2aa74")))
	button.add_theme_stylebox_override("hover_pressed", button.get_theme_stylebox("pressed"))
	button.add_theme_color_override("font_pressed_color", Color("e9c88c"))
	return button
