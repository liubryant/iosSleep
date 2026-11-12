import Foundation

struct DailyInspiration {
    enum Theme: String, CaseIterable {
        case evening = "睡前收尾"
        case kindness = "自我关怀"
        case feelings = "接纳情绪"
        case presence = "回到当下"
        case release = "放下焦虑"
        case moments = "日常微光"

        var coverIndex: Int {
            switch self {
            case .evening: return 7
            case .kindness: return 29
            case .feelings: return 6
            case .presence: return 3
            case .release: return 16
            case .moments: return 11
            }
        }
    }

    let day: Int
    private var edition: Int { (day + 54) % 60 }
    var theme: Theme { Theme.allCases[edition % Theme.allCases.count] }
    var text: String { Self.quotes[theme]![edition / Theme.allCases.count] }
    var date: Date { Self.calendar.date(byAdding: .day, value: day, to: Self.firstDate) ?? Self.firstDate }

    var practice: MindfulnessTrack? {
        switch edition {
        case 0: return .calmingSleep
        case 3: return .walking
        case 8: return .emotionalRelease
        case 17: return .daytimeEnergy
        default: return nil
        }
    }

    static var calendar: Calendar { Calendar(identifier: .gregorian) }
    static let displayLocale = Locale(identifier: "zh_CN")

    static var firstDate: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 4)) ?? .distantPast
    }

    static func day(for date: Date) -> Int {
        max(0, calendar.dateComponents([.day], from: firstDate, to: calendar.startOfDay(for: date)).day ?? 0)
    }

    private static let quotes: [Theme: [String]] = [
        .evening: [
            "今天还没做完的事，留一张便签给明天。现在可以关灯了。",
            "把明早要带的东西放到门边。今天的最后一件小事，就做到这里。",
            "夜里不用给今天打分。把枕头拍松一些，让身体先休息。",
            "窗外的灯一盏一盏暗下去。你也可以慢一点，把白天还给白天。",
            "如果还舍不得结束今天，就留下一件值得记住的小事，再把灯关掉。",
            "睡前给桌上那杯水添满。明早醒来，有一口水在等你。",
            "事情没有全部做完，今天依然可以结束。休息有自己的时间。",
            "把手机放到手够不着的地方。让夜晚最后一点光，留给窗外。",
            "今天说过的话不用逐句重播。让安静陪你把这一页翻过去。",
            "先照顾眼前这一点困意。明早再决定，哪些事情值得继续。"
        ],
        .kindness: [
            "如果今天已经很用力了，今晚就把对自己的要求放轻一点。",
            "给朋友留得出的宽容，也可以留一点给今天犯错的自己。",
            "累的时候，把要做的事缩到一个小动作。喝口水，也算照顾自己。",
            "你可以承认今天过得辛苦，然后为自己换一件舒服的衣服。",
            "想重新开始时，先站稳。你可以从一个不会把自己压垮的小步骤开始。",
            "今天的力气只够做好一件事，也可以把这一件事认认真真记下来。",
            "把心里那句责备读慢一点。也许换个语气，你就愿意听下去了。",
            "想休息时，给自己一段不用交代成果的时间，哪怕只有几分钟。",
            "允许自己暂时拿不定主意。吃顿饭、睡一觉，决定可以稍后再做。",
            "有些日子需要别人的帮忙。说出一个具体的请求，就已经迈出一步。"
        ],
        .feelings: [
            "有些感受一时说不清。你可以先让它待一会儿，等它有了名字。",
            "烦躁的时候，先听听身体在说什么。也许它只是想离开喧闹一会儿。",
            "一件小事也可能让人难过。给自己一点时间，感受不必按大小排队。",
            "开心和疲惫可以出现在同一天。你可以同时承认它们。",
            "当怒气上来，先把手从键盘上拿开。等你愿意，再决定怎么回应。",
            "想哭的时候，可以坐在一个安全的地方。让眼泪自己决定何时停下。",
            "失落的时候，记得吃饭。心里的事可以慢慢想，身体先照顾好。",
            "有些委屈暂时讲不出口。先写下一句你最想让人听见的话。",
            "情绪过去之后，肩膀也许还紧着。给它一点时间，慢慢松下来。",
            "偶尔说一句「我还没想好」，就能给心里的感受留出一点空地。"
        ],
        .presence: [
            "听一听窗外，再感受脚底。此刻有些东西，正稳稳地托着你。",
            "走路时试着留意一步。脚跟落地，再慢慢把重量交给脚掌。",
            "洗手时，感受水从指缝经过。还有几秒钟，你可以只做这一件事。",
            "把杯子握在手里，感受它的温度。先喝一口，再接着想别的。",
            "等电梯时，看看门缝里的光。让这十几秒只是十几秒。",
            "留意你正在听到的最远的声音。然后把注意力带回自己坐着的地方。",
            "抬头看看今天的云。它的形状，只有这一刻的你刚好遇见。",
            "吃第一口饭时，试着尝清楚它的味道。下一口再回到平常的节奏。",
            "关灯之前，听听房间里还剩下哪些声音。安静也有自己的层次。",
            "眼睛累了，就看一会儿远处。让视线落在一个不用仔细辨认的地方。"
        ],
        .release: [
            "明天的事可以先留在纸上。今晚只需要把这一口气慢慢呼完。",
            "等消息的时候，先做一件有结束的事。叠好一件衣服，就到这里。",
            "脑海里反复排演的话，写下最重要的一句。剩下的等见面再说。",
            "不确定的时候，可以先把眼前的一步走完。下一步会有自己的时机。",
            "把担心和能做的事分开写。今晚只挑一件小到现在就能做完的事。",
            "念头又回来了也没关系。你可以摸摸被角，让手先回到这间房里。",
            "如果答案今晚到不了，就给等待留一个明天再看的时间。",
            "先放松握着手机的手。你可以过几分钟，再决定要不要刷新一次。",
            "想到最坏结果时，试着说一句「这是我的担心」。给它一个准确的名字。",
            "把反复推敲的事情写下一行。纸会替你记住，你可以先歇一会儿。"
        ],
        .moments: [
            "一杯温水，一扇开着的窗。今天也有值得慢一点的片刻。",
            "路边的树影落在鞋尖上。只是经过，也可以抬头看看。",
            "晒过的衣服带着一点阳光的味道。把它收进柜子，顺手留给明天。",
            "雨停以后，街灯在水洼里多亮了一盏。慢慢走，别急着绕过去。",
            "今天吃到的第一口热饭，也值得你在心里轻轻记上一笔。",
            "傍晚的风刚好吹过窗帘。手头的事可以等这一阵风过去。",
            "把喜欢的歌从头听到尾。只听这一次，不急着找下一首。",
            "清早的厨房还很安静。水刚烧开时，给自己泡一杯喜欢的茶。",
            "路上遇到一只专心晒太阳的猫。你也可以在有阳光的地方站一会儿。",
            "夜晚回家，看见门口熟悉的一点灯光。一天里，有些地方一直在等你。"
        ]
    ]
}
