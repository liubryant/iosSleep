import Foundation

enum WellnessAssessmentKind: String, Codable, CaseIterable, Hashable, Identifiable {
    case sleepHealth
    case mood
    case anxiety
    case mbti
    case bigFive
    case stress
    case chronotype

    var id: String { rawValue }
}

struct WellnessChoice: Identifiable, Hashable {
    let text: String
    let score: Int

    var id: String { "\(text)-\(score)" }
}

struct WellnessQuestion: Identifiable, Hashable {
    let id: String
    let text: String
    let choices: [WellnessChoice]
    let dimension: String?
}

struct WellnessAssessmentDefinition: Identifiable, Hashable {
    let kind: WellnessAssessmentKind
    let title: String
    let subtitle: String
    let introduction: String
    let periodText: String
    let icon: String
    let colors: [WellnessColorToken]
    let questions: [WellnessQuestion]

    var id: String { kind.rawValue }
    var maximumScore: Int { questions.reduce(0) { $0 + ($1.choices.map(\.score).max() ?? 0) } }

    static func definition(for kind: WellnessAssessmentKind) -> Self {
        switch kind {
        case .sleepHealth:
            return .init(
                kind: kind,
                title: "睡眠状态测评",
                subtitle: "了解近期睡眠困扰",
                introduction: "从入睡、夜醒、睡眠时长和白天状态几个方面，梳理最近的睡眠体验。",
                periodText: "请根据最近 2 周的真实感受作答",
                icon: "moon.zzz.fill",
                colors: [.indigo, .blue],
                questions: numberedQuestions(prefix: "sleep", texts: [
                    "躺下后超过 30 分钟仍难以入睡",
                    "夜间醒来后很难再次入睡",
                    "比期望时间更早醒来，并且无法继续睡",
                    "实际睡眠时间不足，醒来仍感到疲惫",
                    "睡眠时间每天变化较大，作息不规律",
                    "白天容易困倦、注意力不集中",
                    "会因为担心睡不好而变得紧张",
                    "睡眠问题影响了工作、学习或情绪"
                ], choices: frequencyChoices)
            )
        case .mood:
            return .init(
                kind: kind,
                title: "情绪状态筛查",
                subtitle: "PHQ-2 两题快速筛查",
                introduction: "这是简短的情绪健康筛查，用于帮助你觉察近期状态，不用于诊断。",
                periodText: "过去 2 周内，你有多少时间受到以下问题困扰？",
                icon: "heart.text.square.fill",
                colors: [.pink, .orange],
                questions: numberedQuestions(prefix: "mood", texts: [
                    "做事时提不起劲或没有兴趣",
                    "感到心情低落、沮丧或没有希望"
                ], choices: clinicalFrequencyChoices)
            )
        case .anxiety:
            return .init(
                kind: kind,
                title: "焦虑状态筛查",
                subtitle: "GAD-7 近期焦虑感受",
                introduction: "通过 7 个问题了解紧张、担忧和放松困难的程度，结果仅作为自我观察参考。",
                periodText: "过去 2 周内，你有多少时间受到以下问题困扰？",
                icon: "wind",
                colors: [.cyan, .blue],
                questions: numberedQuestions(prefix: "anxiety", texts: [
                    "感到紧张、焦虑或急切",
                    "不能停止或控制担忧",
                    "对各种事情担忧过多",
                    "很难放松下来",
                    "由于不安而无法静坐",
                    "变得容易烦恼或急躁",
                    "感到似乎将有可怕的事情发生"
                ], choices: clinicalFrequencyChoices)
            )
        case .mbti:
            let items: [(String, String, Bool)] = [
                ("参加热闹活动时，我通常会越聊越有精神", "EI", false),
                ("忙碌一天后，我更想独处一会儿恢复精力", "EI", true),
                ("进入陌生群体时，我常会主动开启话题", "EI", false),
                ("表达观点前，我习惯先在心里整理清楚", "EI", true),
                ("频繁与人互动通常会让我充满能量", "EI", false),
                ("相比认识很多人，我更看重少数深入的关系", "EI", true),
                ("讨论问题时，我常常边说边形成自己的想法", "EI", false),
                ("安静、不被打扰的环境更容易让我进入状态", "EI", true),
                ("一场聚会结束后，我通常还想继续参加活动", "EI", false),

                ("接触新事物时，我会先留意具体事实和细节", "SN", false),
                ("我常能从零散信息中联想到未来的可能性", "SN", true),
                ("我更信任经过验证、步骤清楚的做法", "SN", false),
                ("比起操作细节，我更容易被概念和整体图景吸引", "SN", true),
                ("做决定时，现实经验通常比灵感更可靠", "SN", false),
                ("我喜欢思考事物背后的含义、趋势和关联", "SN", true),
                ("说明越具体直接，我越容易理解和执行", "SN", false),
                ("我经常想象一件事还可以有哪些不同发展", "SN", true),
                ("有可观察的证据时，我才更愿意相信一个判断", "SN", false),

                ("意见冲突时，我会优先依据一致的原则和逻辑", "TF", false),
                ("做选择时，我会特别考虑它对相关人的感受影响", "TF", true),
                ("指出问题时，准确直接通常比委婉更重要", "TF", false),
                ("即使效率稍低，我也愿意照顾团队关系与和谐", "TF", true),
                ("只要规则公平，我能接受一个让人不舒服的结论", "TF", false),
                ("是否符合自己的价值观，会明显影响我的决定", "TF", true),
                ("讨论中，我更关注观点是否成立，而不是谁提出它", "TF", false),
                ("我会根据对方的状态调整表达方式和语气", "TF", true),
                ("面对难题时，客观分析通常比共情更能帮助我判断", "TF", false),

                ("重要事情开始前，我喜欢先确定计划和完成节点", "JP", false),
                ("保留调整空间，会让我比严格按计划更自在", "JP", true),
                ("事情有明确结论后，我会感到更轻松", "JP", false),
                ("临时变化常能激发我随机应变的能力", "JP", true),
                ("清晰的日程和截止时间能帮助我保持掌控感", "JP", false),
                ("在真正需要决定前，我倾向继续保留不同选项", "JP", true),
                ("我喜欢用清单逐项完成任务，很少随意跳过", "JP", false),
                ("越接近截止时间，我有时反而越容易集中精力", "JP", true),
                ("自由安排一天时，我也倾向提前规划大致节奏", "JP", false)
            ]
            return .init(
                kind: kind,
                title: "MBTI 人格测试",
                subtitle: "探索你的 16 型人格偏好",
                introduction: "从精力来源、信息获取、决策方式和生活态度四个维度，了解你更自然的人格偏好。",
                periodText: "共 36 题，请按长期真实状态作答，不必选择理想中的自己",
                icon: "person.2.wave.2.fill",
                colors: [.purple, .pink],
                questions: items.enumerated().map { index, item in
                    .init(
                        id: "mbti_\(index + 1)",
                        text: item.0,
                        choices: mbtiChoices(towardRight: item.2),
                        dimension: item.1
                    )
                }
            )
        case .bigFive:
            let items: [(String, String, Bool)] = [
                ("我愿意主动认识新朋友", "外向性", false),
                ("在人多的场合，我通常比较安静", "外向性", true),
                ("与他人相处会让我感到有活力", "外向性", false),
                ("我更喜欢独自待着，而不是参加聚会", "外向性", true),
                ("我会关心并体谅他人的感受", "宜人性", false),
                ("发生分歧时，我很难站在对方角度思考", "宜人性", true),
                ("我通常愿意信任和帮助别人", "宜人性", false),
                ("我有时会对别人表现得冷淡", "宜人性", true),
                ("我习惯提前安排并按计划完成事情", "尽责性", false),
                ("我经常把重要的事情拖到最后", "尽责性", true),
                ("我会留意细节并把事情做完整", "尽责性", false),
                ("我的物品和日程常常比较混乱", "尽责性", true),
                ("压力来临时，我通常能保持平稳", "情绪稳定性", false),
                ("我容易因小事变得焦虑或不安", "情绪稳定性", true),
                ("遇到挫折后，我能较快恢复", "情绪稳定性", false),
                ("我的情绪很容易出现较大波动", "情绪稳定性", true),
                ("我喜欢探索新知识和不同观点", "开放性", false),
                ("我对陌生的想法通常没有兴趣", "开放性", true),
                ("艺术、想象或创意会吸引我", "开放性", false),
                ("我更偏好熟悉的方法，不太愿意尝试变化", "开放性", true)
            ]
            return .init(
                kind: kind,
                title: "大五性格探索",
                subtitle: "了解稳定的人格倾向",
                introduction: "基于 IPIP 公共领域题项思路设计，从五个维度描绘你的性格倾向。性格没有好坏，也不建议频繁重复测量。",
                periodText: "请选择最符合你平时状态的选项",
                icon: "person.crop.circle.fill",
                colors: [.purple, .indigo],
                questions: items.enumerated().map { index, item in
                    .init(
                        id: "bigfive_\(index + 1)",
                        text: item.0,
                        choices: likertChoices(reverse: item.2),
                        dimension: item.1
                    )
                }
            )
        case .stress:
            return .init(
                kind: kind,
                title: "压力状态自测",
                subtitle: "觉察身心负荷与恢复",
                introduction: "从身体紧绷、思绪负担和恢复能力三个方面，了解当前压力状态。",
                periodText: "请根据最近 7 天的感受作答",
                icon: "speedometer",
                colors: [.orange, .red],
                questions: numberedQuestions(prefix: "stress", texts: [
                    "即使休息后，身体仍感到疲惫",
                    "脑中有很多事情，很难真正安静下来",
                    "肩颈、下颌或身体其他部位经常紧绷",
                    "容易因为小事烦躁或失去耐心",
                    "忙碌结束后仍无法从工作或学习中抽离",
                    "近期难以集中注意力或做决定",
                    "休息时会因为没有做事而感到不安",
                    "压力已经影响到睡眠或食欲"
                ], choices: frequencyChoices)
            )
        case .chronotype:
            let choices = [
                WellnessChoice(text: "明显偏早", score: 0),
                WellnessChoice(text: "稍微偏早", score: 1),
                WellnessChoice(text: "稍微偏晚", score: 2),
                WellnessChoice(text: "明显偏晚", score: 3)
            ]
            return .init(
                kind: kind,
                title: "作息类型探索",
                subtitle: "认识自己的昼夜节律",
                introduction: "根据自然状态下的精神高峰、入睡和起床偏好，了解你更接近晨型、弹性型还是夜型。",
                periodText: "请按没有闹钟和临时任务时的自然倾向作答",
                icon: "sun.and.horizon.fill",
                colors: [.yellow, .orange],
                questions: numberedQuestions(prefix: "chronotype", texts: [
                    "你的自然入睡时间倾向",
                    "你的自然起床时间倾向",
                    "一天中精神最好的时间倾向",
                    "如果自由安排，重要工作会放在什么时间",
                    "周末作息相对工作日的变化倾向",
                    "晚上 10 点后的清醒程度倾向"
                ], choices: choices)
            )
        }
    }

    func makeResult(answers: [String: Int]) -> WellnessAssessmentRecord {
        if kind == .mbti {
            let dimensions: [(id: String, leftName: String, leftLetter: String, rightName: String, rightLetter: String)] = [
                ("EI", "外向", "E", "内向", "I"),
                ("SN", "实感", "S", "直觉", "N"),
                ("TF", "思考", "T", "情感", "F"),
                ("JP", "判断", "J", "感知", "P")
            ]
            var type = ""
            let metrics = dimensions.map { dimension -> WellnessMetricResult in
                let items = questions.filter { $0.dimension == dimension.id }
                let points = items.reduce(0) { $0 + (answers[$1.id] ?? 0) }
                let minimum = items.count
                let maximum = items.count * 4
                let position = maximum == minimum ? 0.5 : Double(points - minimum) / Double(maximum - minimum)
                let prefersRight = position > 0.5
                let letter = prefersRight ? dimension.rightLetter : dimension.leftLetter
                let name = prefersRight ? dimension.rightName : dimension.leftName
                let strength = Int((abs(position - 0.5) * 200).rounded())
                type += letter
                return .init(title: "\(name) \(letter)", value: strength)
            }
            let profile = Self.mbtiProfiles[type] ?? Self.defaultMBTIProfile
            let averageStrength = metrics.map(\.value).reduce(0, +) / max(metrics.count, 1)
            return .init(
                assessmentID: id,
                title: title,
                date: Date(),
                score: averageStrength,
                maximumScore: 100,
                level: "\(type) · \(profile.nickname)",
                summary: profile.summary,
                suggestions: [
                    "优势：\(profile.strengths)",
                    "沟通与关系：\(profile.relationships)",
                    "学习与工作：\(profile.workStyle)",
                    "成长提醒：\(profile.growth)"
                ],
                metrics: metrics
            )
        }

        if kind == .bigFive {
            let dimensionNames = ["外向性", "宜人性", "尽责性", "情绪稳定性", "开放性"]
            let metrics = dimensionNames.map { name -> WellnessMetricResult in
                let items = questions.filter { $0.dimension == name }
                let points = items.reduce(0) { $0 + (answers[$1.id] ?? 0) }
                let maximum = items.reduce(0) { $0 + ($1.choices.map(\.score).max() ?? 0) }
                let percentage = maximum == 0 ? 0 : Int((Double(points) / Double(maximum) * 100).rounded())
                return .init(title: name, value: percentage)
            }
            let strongest = metrics.max(by: { $0.value < $1.value })?.title ?? "开放性"
            let average = metrics.isEmpty ? 0 : metrics.map(\.value).reduce(0, +) / metrics.count
            return .init(
                assessmentID: id,
                title: title,
                date: Date(),
                score: average,
                maximumScore: 100,
                level: "个性画像",
                summary: "你目前表现更突出的倾向是\(strongest)。五个维度共同构成完整画像，不代表能力高低，也不会把你限制在固定类型里。",
                suggestions: ["关注各维度在真实生活中的表现，而不是只看最高分。", "人格倾向较稳定，建议间隔 6 个月以上再测。", "可以结合睡眠、压力和情绪记录，观察状态对行为的影响。"],
                metrics: metrics
            )
        }

        let total = questions.reduce(0) { $0 + (answers[$1.id] ?? 0) }
        let result = resultCopy(for: total)
        return .init(
            assessmentID: id,
            title: title,
            date: Date(),
            score: total,
            maximumScore: maximumScore,
            level: result.level,
            summary: result.summary,
            suggestions: result.suggestions,
            metrics: []
        )
    }

    private func resultCopy(for score: Int) -> (level: String, summary: String, suggestions: [String]) {
        switch kind {
        case .sleepHealth:
            switch score {
            case 0...5:
                return ("睡眠较稳定", "近期睡眠困扰较少，继续保持规律作息和舒适的睡眠环境。", ["保持相对固定的起床时间。", "睡前留出 30 分钟放松时间。", "继续记录睡眠，观察长期趋势。"])
            case 6...11:
                return ("轻度波动", "近期睡眠出现一些波动，可以从作息、压力和睡前习惯开始调整。", ["固定起床时间，周末也尽量不要相差太多。", "下午减少咖啡因，睡前减少强光和高强度信息。", "连续记录两周，找出影响睡眠的因素。"])
            case 12...17:
                return ("需要关注", "多项睡眠体验正在影响恢复，建议主动调整并持续观察。", ["尝试规律作息和睡前放松练习。", "白天适度运动，但避免临睡前剧烈运动。", "若持续数周影响生活，可咨询睡眠门诊或专业人员。"])
            default:
                return ("困扰较明显", "近期睡眠困扰较为集中，单靠偶尔补觉可能难以恢复。", ["记录就寝、夜醒和白天状态，便于专业沟通。", "不要自行长期依赖酒精或助眠药物。", "建议尽早向睡眠门诊或专业人员寻求评估。"])
            }
        case .mood:
            if score < 3 {
                return ("近期较平稳", "筛查结果暂未显示明显的持续低落信号，请继续关注真实感受。", ["保持规律睡眠、运动与社交联系。", "记录让自己感到轻松或有意义的小事。", "如果感受发生明显变化，可以再次筛查或寻求支持。"])
            }
            return ("建议进一步关注", "近期低落或兴趣下降出现得较频繁。该结果不是诊断，建议做更完整的专业评估。", ["与信任的人谈谈近期状态。", "如果持续影响睡眠、工作或生活，请联系心理或医疗专业人员。", "若感到自己或他人可能处于危险中，请立即联系当地急救服务并寻求身边人的帮助。"])
        case .anxiety:
            switch score {
            case 0...4:
                return ("焦虑感较少", "近期紧张和担忧处在较低水平。", ["继续保持规律睡眠和适度运动。", "每天给自己留出短暂的无屏幕休息时间。", "用呼吸练习维持放松能力。"])
            case 5...9:
                return ("轻度焦虑感", "近期存在一些紧张和担忧，可以通过日常调整持续观察。", ["把担忧写下来，区分可行动与暂不可控的部分。", "减少睡前信息摄入，练习缓慢呼吸。", "若持续加重或影响生活，建议寻求专业支持。"])
            case 10...14:
                return ("中度焦虑感", "紧张和担忧可能已经影响到放松、专注或睡眠，建议进一步关注。", ["与心理或医疗专业人员讨论近期状态。", "保持基本作息，不用酒精等方式回避焦虑。", "出现急性不适或安全风险时，立即寻求线下帮助。"])
            default:
                return ("焦虑感较明显", "近期焦虑相关体验较为频繁。该结果不是诊断，建议尽快获得专业评估。", ["联系心理咨询师、精神心理科或可信赖的医疗机构。", "让信任的人知道你的状态，避免独自承受。", "若感到自己或他人可能处于危险中，请立即联系当地急救服务。"])
            }
        case .stress:
            switch score {
            case 0...5:
                return ("恢复良好", "目前身心负荷总体可控，仍有较好的恢复空间。", ["维持当前的休息节奏。", "把有效的放松方式固定下来。", "关注连续忙碌后的恢复时间。"])
            case 6...11:
                return ("轻度负荷", "近期有一些压力反应，需要更主动地安排恢复。", ["每天安排至少一次短暂停顿。", "优先保证睡眠和规律饮食。", "一次只处理一件最重要的事。"])
            case 12...17:
                return ("负荷偏高", "压力可能正在影响情绪、专注或睡眠。", ["减少非必要任务，为恢复留出明确时间。", "和信任的人沟通当前负担。", "持续影响生活时，考虑寻求专业支持。"])
            default:
                return ("需要及时休整", "多方面压力反应较明显，建议把恢复与求助放在更高优先级。", ["尽快减少可推迟的负荷并保证基本睡眠。", "联系可信赖的人或专业人员获得支持。", "如出现明显身体不适或安全风险，请及时就医。"])
            }
        case .chronotype:
            switch score {
            case 0...5:
                return ("偏晨型", "你更可能在较早时段保持清醒和高效，晚间能量下降也会更早。", ["把重要任务安排在上午。", "晚间提前降低灯光和信息刺激。", "社交晚睡后仍尽量守住稳定起床时间。"])
            case 6...12:
                return ("弹性型", "你的作息偏好相对灵活，能在不同日程间调整。", ["选择一个稳定起床锚点。", "根据当天精神高峰安排高难度任务。", "避免因灵活而频繁大幅改变作息。"])
            default:
                return ("偏夜型", "你更可能在傍晚或夜间进入状态，过早起床时需要更长时间清醒。", ["起床后尽快接触自然光。", "需要早起时，每几天只提前 15 至 30 分钟。", "晚间减少强光刺激，帮助生物钟逐步前移。"])
            }
        case .bigFive:
            return ("个性画像", "", [])
        case .mbti:
            return ("人格偏好", "", [])
        }
    }

    private static let frequencyChoices = [
        WellnessChoice(text: "从不", score: 0),
        WellnessChoice(text: "偶尔", score: 1),
        WellnessChoice(text: "经常", score: 2),
        WellnessChoice(text: "几乎总是", score: 3)
    ]

    private static let clinicalFrequencyChoices = [
        WellnessChoice(text: "完全没有", score: 0),
        WellnessChoice(text: "有几天", score: 1),
        WellnessChoice(text: "一半以上天数", score: 2),
        WellnessChoice(text: "几乎每天", score: 3)
    ]

    private static func likertChoices(reverse: Bool) -> [WellnessChoice] {
        let texts = ["非常不同意", "比较不同意", "不确定", "比较同意", "非常同意"]
        return texts.enumerated().map { index, text in
            WellnessChoice(text: text, score: reverse ? 5 - index : index + 1)
        }
    }

    private static func mbtiChoices(towardRight: Bool) -> [WellnessChoice] {
        let texts = ["非常不同意", "比较不同意", "比较同意", "非常同意"]
        return texts.enumerated().map { index, text in
            WellnessChoice(text: text, score: towardRight ? index + 1 : 4 - index)
        }
    }

    private struct MBTIProfile {
        let nickname: String
        let summary: String
        let strengths: String
        let relationships: String
        let workStyle: String
        let growth: String
    }

    private static let defaultMBTIProfile = MBTIProfile(
        nickname: "探索者",
        summary: "你在四个人格维度上形成了独特的偏好组合。偏好描述的是更自然的方式，并不限制你的能力和选择。",
        strengths: "能以自己的方式理解信息、建立关系并推动事情。",
        relationships: "说清自己的需求，也为不同表达方式留出空间。",
        workStyle: "选择能发挥自然偏好、同时允许补足弱项的环境。",
        growth: "把结果当作观察起点，而不是固定标签。"
    )

    private static let mbtiProfiles: [String: MBTIProfile] = [
        "ISTJ": .init(nickname: "物流师", summary: "你重视事实、责任与秩序，习惯用可靠的方法把承诺落实。稳定和可预期会让你发挥得更好。", strengths: "细致可靠、善于规划，面对长期任务有耐心和执行力。", relationships: "你常用行动表达在意，也可以更直接地说出感受与肯定。", workStyle: "适合目标清晰、标准明确、能够持续积累专业能力的环境。", growth: "给变化和新方法留一点试验空间，不必凡事都独自承担。"),
        "ISFJ": .init(nickname: "守卫者", summary: "你温和务实，容易注意到他人的实际需要，并愿意默默维护熟悉的人和秩序。", strengths: "体贴、有责任感，能记住细节并持续照顾团队需要。", relationships: "关心别人时也要表达自己的界限，避免把需求一直放在最后。", workStyle: "适合重视协作、服务质量和稳定推进的工作方式。", growth: "练习面对冲突和拒绝，让付出建立在自愿与余力之上。"),
        "INFJ": .init(nickname: "提倡者", summary: "你关注意义、长期方向和人的成长，常把敏锐洞察转化为温和而坚定的行动。", strengths: "富有同理心和想象力，能够理解复杂动机并坚持重要价值。", relationships: "深度连接对你很重要，及时沟通期待能减少独自猜测和消耗。", workStyle: "适合能结合创意、助人价值与独立思考的长期项目。", growth: "降低对完美理解的期待，用小步行动代替过度内耗。"),
        "INTJ": .init(nickname: "建筑师", summary: "你擅长看见系统与长期路径，倾向独立思考，并持续优化低效的方法。", strengths: "战略清晰、学习自主，能把复杂目标拆成可执行结构。", relationships: "表达结论时补充感受和背景，会让你的关心更容易被接收到。", workStyle: "适合高自主度、需要分析创新和长期设计的挑战。", growth: "为现实反馈和他人经验保留位置，避免方案只在头脑中追求完美。"),
        "ISTP": .init(nickname: "鉴赏家", summary: "你冷静灵活，喜欢通过观察和亲手尝试理解事物，并能在突发情境中迅速解决问题。", strengths: "动手能力强、判断务实，面对压力时通常能抓住关键。", relationships: "给彼此空间很重要，也可以主动说明沉默并不等于疏远。", workStyle: "适合可独立探索、重视技能和即时问题解决的任务。", growth: "为长期承诺设置简单节点，减少兴趣下降后的搁置。"),
        "ISFP": .init(nickname: "探险家", summary: "你敏感真诚，重视个人价值和当下体验，常以自然、不张扬的方式表达审美与善意。", strengths: "观察细腻、适应力好，能用实际行动营造舒适和美感。", relationships: "不喜欢冲突时仍要说出真实需要，避免情绪累积后突然抽离。", workStyle: "适合有创造空间、节奏灵活且能看见真实影响的环境。", growth: "把重要愿望转化为小计划，让自由与持续行动同时存在。"),
        "INFP": .init(nickname: "调停者", summary: "你由内在价值和想象力驱动，珍视真诚，也容易看见人与世界尚未实现的可能。", strengths: "富有同理心、创造力和价值感，能为重要的事投入深度。", relationships: "别期待他人自动理解你的内心，清楚表达需求会让关系更稳固。", workStyle: "适合有意义、能自主创作并允许深度专注的任务。", growth: "用可完成的小步骤承接理想，避免选择过多导致迟迟不开始。"),
        "INTP": .init(nickname: "逻辑学家", summary: "你好奇而独立，喜欢拆解概念、寻找规律，并不断检验一个解释是否自洽。", strengths: "分析深入、想法新颖，能发现系统中的矛盾和改进空间。", relationships: "分享推理的同时也回应情绪，能减少“讲清了却没被理解”的落差。", workStyle: "适合探索复杂问题、保有自主权和学习空间的环境。", growth: "为想法设定交付点，用真实反馈结束无止境的优化。"),
        "ESTP": .init(nickname: "企业家", summary: "你行动直接、反应敏锐，喜欢在真实情境中把握机会，并通过尝试快速校准方向。", strengths: "果断务实、善于应变，能调动现场气氛并推动事情发生。", relationships: "在解决问题前先听完感受，会让你的直接变得更有支持感。", workStyle: "适合节奏快、反馈及时、需要谈判或现场决策的任务。", growth: "重要决定多看一步长期后果，为重复性收尾预留精力。"),
        "ESFP": .init(nickname: "表演者", summary: "你热情开放，容易感受到当下的乐趣和他人的状态，也愿意把活力带进关系与生活。", strengths: "亲和、灵活、有感染力，能快速营造轻松和参与感。", relationships: "保持热情的同时说清界限，不必用持续付出来维持所有关系。", workStyle: "适合有人际互动、创意表达和即时成果反馈的环境。", growth: "为金钱、时间和长期目标建立简单规则，减少冲动带来的压力。"),
        "ENFP": .init(nickname: "竞选者", summary: "你热情好奇，擅长发现人与想法之间的连接，并愿意为充满意义的可能性投入。", strengths: "创意丰富、善于鼓舞他人，能快速看见新的方向和潜力。", relationships: "新鲜感之外也要稳定回应承诺，让深度关系得到持续滋养。", workStyle: "适合变化丰富、可以创造和连接他人的项目。", growth: "减少同时启动的目标，用固定节奏完成最重要的一两件事。"),
        "ENTP": .init(nickname: "辩论家", summary: "你敏捷好奇，喜欢挑战默认答案，并通过观点碰撞发现更有趣、更有效的可能。", strengths: "反应快、善创新，能从多角度重构问题并激发讨论。", relationships: "辩论不一定是冲突，但需要确认对方此刻想讨论还是想被理解。", workStyle: "适合高变化、需要创意策略和快速试验的环境。", growth: "把注意力从“能否做到”延伸到“是否值得并能否完成”。"),
        "ESTJ": .init(nickname: "总经理", summary: "你务实果断，重视责任、规则和结果，习惯组织资源让计划稳定落地。", strengths: "执行有力、条理清楚，能够建立标准并推动团队达成目标。", relationships: "效率之外留意不同节奏和情绪，邀请反馈比直接判断更有效。", workStyle: "适合职责明确、需要组织协调和结果管理的环境。", growth: "面对新情况时允许先探索，再决定唯一正确的路径。"),
        "ESFJ": .init(nickname: "执政官", summary: "你热情可靠，重视归属与合作，常能察觉群体需要并主动维系关系。", strengths: "善于照顾细节、组织协作，能够让他人感到被看见和接纳。", relationships: "认可很重要，但不必用所有人的满意来衡量自己的价值。", workStyle: "适合沟通密集、服务他人并有清晰反馈的团队环境。", growth: "练习接纳分歧和不确定性，把精力留给真正重要的人和事。"),
        "ENFJ": .init(nickname: "主人公", summary: "你关注共同愿景和人的潜力，善于理解氛围，并推动大家朝更有意义的方向行动。", strengths: "有感染力、同理心强，能够组织协作并帮助他人成长。", relationships: "照顾全局时也要诚实表达自己的疲惫、边界和真实期待。", workStyle: "适合需要沟通领导、人才发展和价值驱动的工作。", growth: "把他人的选择还给他人，避免为所有人的结果承担责任。"),
        "ENTJ": .init(nickname: "指挥官", summary: "你目标清晰、重视效率，擅长整合资源、制定策略，并推动复杂计划获得结果。", strengths: "决策果断、视野长远，能在挑战中建立秩序和行动方向。", relationships: "放慢结论速度，先确认他人的顾虑，会让合作更持久。", workStyle: "适合高挑战、可承担责任并影响系统方向的环境。", growth: "将休息和情感连接也视为长期表现的一部分，而非效率的阻碍。")
    ]

    private static func numberedQuestions(
        prefix: String,
        texts: [String],
        choices: [WellnessChoice]
    ) -> [WellnessQuestion] {
        texts.enumerated().map { index, text in
            .init(id: "\(prefix)_\(index + 1)", text: text, choices: choices, dimension: nil)
        }
    }
}

enum WellnessColorToken: String, Codable, Hashable {
    case blue, cyan, teal, green, yellow, orange, red, pink, purple, indigo, mint
}

struct WellnessMetricResult: Codable, Hashable, Identifiable {
    let title: String
    let value: Int

    var id: String { title }
}

struct WellnessAssessmentRecord: Codable, Hashable, Identifiable {
    let id: UUID
    let assessmentID: String
    let title: String
    let date: Date
    let score: Int
    let maximumScore: Int
    let level: String
    let summary: String
    let suggestions: [String]
    let metrics: [WellnessMetricResult]

    init(
        id: UUID = UUID(),
        assessmentID: String,
        title: String,
        date: Date,
        score: Int,
        maximumScore: Int,
        level: String,
        summary: String,
        suggestions: [String],
        metrics: [WellnessMetricResult]
    ) {
        self.id = id
        self.assessmentID = assessmentID
        self.title = title
        self.date = date
        self.score = score
        self.maximumScore = maximumScore
        self.level = level
        self.summary = summary
        self.suggestions = suggestions
        self.metrics = metrics
    }
}

@MainActor
final class WellnessHistoryStore: ObservableObject {
    static let shared = WellnessHistoryStore()

    @Published private(set) var records: [WellnessAssessmentRecord] = []

    private let defaultsKey = "wellness.assessment.history.v1"

    private init() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let stored = try? JSONDecoder().decode([WellnessAssessmentRecord].self, from: data) else { return }
        records = stored.sorted { $0.date > $1.date }
    }

    func add(_ record: WellnessAssessmentRecord) {
        records.insert(record, at: 0)
        records = Array(records.prefix(100))
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

struct SleepDiaryEntry: Codable, Hashable, Identifiable {
    let id: UUID
    let date: Date
    let bedtime: Date
    let wakeTime: Date
    let sleepLatencyMinutes: Int
    let awakenings: Int
    let quality: Int
    let morningEnergy: Int
    let lateCaffeine: Bool
    let exercised: Bool
    let note: String

    init(
        id: UUID = UUID(),
        date: Date,
        bedtime: Date,
        wakeTime: Date,
        sleepLatencyMinutes: Int,
        awakenings: Int,
        quality: Int,
        morningEnergy: Int,
        lateCaffeine: Bool,
        exercised: Bool,
        note: String
    ) {
        self.id = id
        self.date = date
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.sleepLatencyMinutes = sleepLatencyMinutes
        self.awakenings = awakenings
        self.quality = quality
        self.morningEnergy = morningEnergy
        self.lateCaffeine = lateCaffeine
        self.exercised = exercised
        self.note = note
    }

    var estimatedDuration: TimeInterval {
        let calendar = Calendar.current
        let bedtimeComponents = calendar.dateComponents([.hour, .minute], from: bedtime)
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: wakeTime)
        let dayStart = calendar.startOfDay(for: date)
        guard let start = calendar.date(bySettingHour: bedtimeComponents.hour ?? 23, minute: bedtimeComponents.minute ?? 0, second: 0, of: dayStart),
              var end = calendar.date(bySettingHour: wakeComponents.hour ?? 7, minute: wakeComponents.minute ?? 0, second: 0, of: dayStart) else { return 0 }
        if end <= start {
            end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        }
        return max(0, end.timeIntervalSince(start) - Double(sleepLatencyMinutes * 60))
    }
}

@MainActor
final class SleepDiaryStore: ObservableObject {
    static let shared = SleepDiaryStore()

    @Published private(set) var entries: [SleepDiaryEntry] = []

    private let defaultsKey = "wellness.sleep.diary.v1"

    private init() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let stored = try? JSONDecoder().decode([SleepDiaryEntry].self, from: data) else { return }
        entries = stored.sorted { $0.date > $1.date }
    }

    func add(_ entry: SleepDiaryEntry) {
        entries.removeAll { Calendar.current.isDate($0.date, inSameDayAs: entry.date) }
        entries.append(entry)
        entries.sort { $0.date > $1.date }
        entries = Array(entries.prefix(180))
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
