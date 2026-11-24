extends RefCounted

const ENEMY_SUITS := ["diamonds", "hearts", "clubs", "spades"]
const CARD_ORDER := [
	"clubs_6", "hearts_10", "spades_10", "hearts_8", "spades_1", "hearts_3", "spades_3", "clubs_2",
	"diamonds_8", "clubs_8", "diamonds_10", "diamonds_9", "spades_7", "clubs_10", "diamonds_7", "spades_9",
	"diamonds_6", "hearts_9", "diamonds_1", "clubs_9", "diamonds_5", "diamonds_4", "clubs_7", "clubs_1",
]

const STEPS := [
	{"title": "认识牌桌", "text": "牌王上方是生命与攻击。下方是你的手牌、出牌按钮和两个牌堆。击败四位 J 级牌王即可通过教程。", "focus": ["stats", "hand", "submit", "piles"]},
	{"title": "认识手牌", "text": "4 到 10 是普通牌，可以单张打出。2 和 3 是连携牌，可以单出或将同点数的一起打出。A 是宠物牌，可以搭配一张主牌。", "focus": ["hand"]},
	{"title": "打出一张主牌", "text": "选中梅花 6，再点击出牌。", "play": ["clubs_6"]},
	{"title": "基础伤害与梅花", "text": "出牌数值是 6，先造成 6 点基础伤害。梅花追加 6 点伤害，牌王还剩 18 点生命。现在它要反击了。", "focus": ["stats", "defense"]},
	{"title": "弃牌抵伤", "text": "点击红桃 10，立即弃置这张牌，抵掉 10 点伤害。防御时点击手牌就会弃掉，无法撤回。", "focus": ["defense"], "discard": "hearts_10"},
	{"title": "黑桃提供护盾", "text": "打出黑桃 10。它会造成 10 点基础伤害，并给你 10 点护盾。", "play": ["spades_10"]},
	{"title": "挡下反击", "text": "护盾先抵掉了全部 10 点攻击，这回合无需弃牌。护盾只在当前回合有效。", "focus": ["stats"]},
	{"title": "方片补充手牌", "text": "方片按出牌数值抽牌，手牌最多八张。", "focus": ["piles"], "diagram": true},
	{"title": "主牌搭配宠物牌", "text": "一起打出红桃 8 和黑桃 A，数值相加为 9。红桃会从弃牌堆回收最多 9 张牌，放回抽牌堆底。", "focus": ["piles"], "play": ["hearts_8", "spades_1"]},
	{"title": "击败第一位牌王", "text": "红桃把先前弃掉的三张牌放回了抽牌堆底。方片 J 的生命被打到低于 0，已被击败。", "focus": ["piles"]},
	{"title": "连携出牌", "text": "一起打出两张点数相同的 3，出牌数值就是 6。试试红桃 3 和黑桃 3。", "play": ["hearts_3", "spades_3"]},
	{"title": "花色封锁", "text": "对面是红桃 J，封锁了红桃回收。但 6 点基础伤害照常生效，黑桃护盾也挡掉了 6 点攻击。现在还剩 4 点待抵伤。", "focus": ["stats", "defense"]},
	{"title": "只剩一张可弃的牌", "text": "点击梅花 2。它只能抵掉 2 点伤害，弃掉以后手牌就用尽了。", "focus": ["defense"], "discard": "clubs_2"},
	{"title": "王牌让你复活", "text": "手牌用尽或只剩 A 时会死亡。有王牌就能复活，先消耗大王，再消耗小王。这次抽回八张手牌，反击也结束了。", "focus": ["jokers", "hand"]},
	{"title": "试试方片抽牌", "text": "打出方片 8。注意抽牌堆和手牌的变化。", "focus": ["piles"], "play": ["diamonds_8"]},
	{"title": "挡下反击", "text": "点击方片 10 抵掉伤害，为下一次出牌做准备。", "focus": ["defense"], "discard": "diamonds_10"},
	{"title": "把生命恰好打到 0", "text": "红桃 J 还剩 16 点生命。梅花 8 先造成 8 点基础伤害，再追加 8 点。选中并打出它。", "focus": ["stats"], "play": ["clubs_8"]},
	{"title": "获得将军牌", "text": "全部效果结束时，生命恰好为 0 的牌王会被感化。红桃 J 现在是你手里的一张 11 点主牌。接下来由你独立击败剩下的两位牌王。", "cards": ["hearts_11"]},
]
