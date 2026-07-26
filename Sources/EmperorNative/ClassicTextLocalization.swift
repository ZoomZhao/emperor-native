import EmperorCore
import Foundation

/// Player-facing names decoded from the original English data files.
///
/// Simulation and save data retain the authored strings; the classic shell
/// translates only at presentation time so identifiers and compatibility are
/// unaffected.
enum ClassicTextLocalization {
    private static let originalText = try? OriginalLocalizedTextCatalog(
        root: GameDataSource.defaultRoot
    )

    private static let campaignTitles: [String: String] = [
        "Eight Kingdoms": "八国争霸",
        "Xia Dynasty Tutorials": "夏朝教学",
        "City States of Shang": "商代城邦",
        "The Warring States": "战国时代",
        "The Wall of 10,000 Li": "万里长城",
        "Turbulent Winds of Zhou": "动荡的周朝",
        "The Mighty Qin": "强大的秦国",
        "The Three Kingdoms": "三国时代",
        "The Grand Canal": "大运河",
        "The Silk Road": "丝绸之路",
        "The Magnificent Tang": "盛唐气象",
        "A Time of Grandeur": "盛世华章",
        "Five Dynasties": "五代十国",
        "Invaders from the North": "北方来敌",
        "Wall Against the Mongols": "抗蒙长城",
        "A Tale of Two Cities": "双城记",
        "Open Play - Bronze Age": "开放建造：青铜时代",
        "Chenghuang": "城隍",
        "Caravan Destinations on The Silk Road": "丝绸之路商队",
        "Open Play - Iron Age": "开放建造：铁器时代",
        "Naval trade": "海上贸易",
        "Securing the Silk Road": "保卫丝绸之路",
        "Spring and Autumn": "春秋时代",
        "Open Play - Steel Age": "开放建造：钢铁时代",
        "Strength Against Oppression": "反抗压迫",
        "Supporting the Great Wall": "支援长城",
        "The Strongest Dynasty": "最强盛的王朝",
        "The Usurper": "篡位者",
        "Emperor Jin Wudi": "晋武帝",
    ]

    private static let missionTitles: [String: String] = [
        "Shelter and Sustenance": "安居与生计",
        "Seeds of Civilization": "文明的种子",
        "The Good Things": "美好生活",
        "Trading and Commerce": "贸易与商业",
        "The Elite of Erlitou": "二里头的贵族",
        "Men of Arms": "武装之士",
        "Start of a Dynasty": "王朝肇始",
        "Along the Wei": "沿渭河而行",
        "A Temple for Tang": "成汤之庙",
        "Walls of Zhengzhou": "郑州城墙",
        "A Move to Yin": "迁都殷地",
        "Valley of Rice": "稻米之谷",
        "Tomb for a Queen": "王后陵墓",
        "Eight Kingdoms": "八国争霸",
        "The Warring States": "战国时代",
        "The Wall of 10,000 Li": "万里长城",
        "A New Capital": "营建新都",
        "The Salt Mines of Anyi": "安邑盐矿",
        "Edge of the Ordos": "鄂尔多斯边缘",
        "Spring and Autumn Weather": "春秋风云",
        "New Ways": "新政之道",
        "Iron and Earth": "铁与土",
        "King Cuo's Temple": "错王之庙",
        "Zheng Guo's Canal": "郑国渠",
        "The First Emperor's City": "始皇帝之城",
        "Land of Annam": "安南之地",
        "Emperor Qin's Great Wall": "秦始皇长城",
        "The Terracotta Army": "兵马俑",
        "The Three Kingdoms": "三国时代",
        "The Grand Canal": "大运河",
        "Golden City of Gaodi": "高帝的黄金之城",
        "Wudi Moves South": "武帝南征",
        "The Silk Road Opens": "丝路初开",
        "Hills of Koguryo": "高句丽山地",
        "Outpost in the Desert": "沙漠前哨",
        "A New Capital at Luoyang": "洛阳新都",
        "Silk and Spice": "丝绸与香料",
        "Budding of Buddhism": "佛教初兴",
        "Magnificent Tang MP": "盛唐争霸",
        "The Enlightened One": "开明之主",
        "An Agricultural Community": "农耕乡里",
        "Refurbish Job": "城市复兴",
        "Trouble in the Tarim": "塔里木之乱",
        "The Eastern Capital": "东方都城",
        "Palace for Xuansong": "玄宗行宫",
        "The Siege of Dunhuang": "敦煌之围",
        "Five Dynasties": "五代十国",
        "China Reunited": "华夏一统",
        "The Khitan Strike South": "契丹南侵",
        "Millenium": "千年之交",
        "Luxuries of Kaifeng": "汴京繁华",
        "A Capital for the Jin": "金国都城",
        "The Mongols Are Coming": "蒙古来袭",
        "Genghis at Zhongdu": "成吉思汗兵临中都",
        "Jin Great Wall": "抗蒙长城",
        "A Tale of Two Cities": "双城记",
        "Open Play Bronze Age": "开放建造：青铜时代",
        "Chenghuang": "城隍",
        "Eight Elite Kingdoms": "八国精英争霸",
        "Eight Prosperous Kingdoms": "八国繁荣争霸",
        "Hexi Corridor": "河西走廊",
        "Open Play - Iron Age": "开放建造：铁器时代",
        "Naval trade": "海上贸易",
        "Securing the Silk Road": "保卫丝绸之路",
        "Spring and Autumn": "春秋时代",
        "Open Play - Steel Age": "开放建造：钢铁时代",
        "Strength Against Oppression": "反抗压迫",
        "Supporting the Great Wall": "支援长城",
        "The Strongest Dynasty": "最强盛的王朝",
        "The Usurper": "篡位者",
        "Refilling the Coffers": "充盈国库",
        "Yangzi Outpost": "长江前哨",
        "Estates For All": "广置田庄",
    ]

    private static let cityNames: [String: String] = [
        "Banpo": "半坡",
        "Anyang": "安阳",
        "Anyi": "安邑",
        "Baoji": "宝鸡",
        "Chang'an": "长安",
        "Chengdu": "成都",
        "Dunhuang": "敦煌",
        "Erlitou": "二里头",
        "Handan": "邯郸",
        "Hao": "镐京",
        "Hemudu": "河姆渡",
        "Jiangling": "江陵",
        "Jiaozhou": "交州",
        "Jiayuguan": "嘉峪关",
        "Jinyang": "晋阳",
        "Juyongguan": "居庸关",
        "Kaifeng": "开封",
        "Kashgar": "喀什葛尔",
        "Lanzhou": "兰州",
        "Liangzhou": "凉州",
        "Lingshou": "灵寿",
        "Lo-lang": "乐浪",
        "LopNor": "罗布泊",
        "Loulan": "楼兰",
        "Loyi": "洛邑",
        "Luoyang": "洛阳",
        "Niya": "尼雅",
        "Pingyao": "平遥",
        "Qufu": "曲阜",
        "Shanhaiguan": "山海关",
        "Suzhou": "苏州",
        "Weizhou": "潍州",
        "Wu": "吴",
        "Xiangjun": "象郡",
        "Xianyang": "咸阳",
        "Yangzhou": "扬州",
        "Yen": "燕",
        "Ying": "郢",
        "Yulin": "榆林",
        "Zhengzhou": "郑州",
        "Zhongdu": "中都",
    ]

    private static let houseNames: [String: String] = [
        "Shelter": "茅棚",
        "Hut": "草舍",
        "Plain Cottage": "普通农舍",
        "Attractive Cottage": "整洁农舍",
        "Spacious Dwelling": "宽敞住宅",
        "Elegant Dwelling": "雅致住宅",
        "Ornate Apartment": "华美楼房",
        "Lux. Apartment": "豪华楼房",
        "Unoccupied": "空置贵族宅邸",
        "Abandoned": "废弃庭院",
        "Modest Siheyuan": "普通庭院",
        "Lavish Siheyuan": "富足庭院",
        "Humble Compound": "雅致公馆",
        "Impressive Compound": "华美公馆",
        "Heavenly Compound": "堂皇公馆",
        "Vacant House": "茅棚",
        "Shelter House": "茅棚",
        "Hut House": "草舍",
        "Plain House": "普通农舍",
        "Attractive House": "整洁农舍",
        "Spacious House": "宽敞住宅",
        "Elegant House": "雅致住宅",
        "Ornate House": "华美楼房",
        "Luxurious House": "豪华楼房",
        "Unocc Elite": "空置贵族宅邸",
        "Abandoned Elite": "废弃庭院",
        "Modest Elite": "普通庭院",
        "Lavish Elite": "富足庭院",
        "Humble Elite": "雅致公馆",
        "Impressive Elite": "华美公馆",
        "Heavenly Elite": "堂皇公馆",
    ]

    private static let commodityNames: [String: String] = [
        "None": "无",
        "BeanCurd": "豆腐",
        "Bean Curd": "豆腐",
        "Fish": "鱼",
        "Cabbage": "白菜",
        "Meat": "野味肉",
        "Millet": "粟米",
        "Rice": "稻米",
        "Wheat": "小麦",
        "Salt": "盐",
        "Spices": "香料",
        "Wood": "木材",
        "Bronze": "铜",
        "RawSilk": "生丝",
        "Raw Silk": "生丝",
        "Tea": "茶叶",
        "Lacquer": "树漆",
        "Iron": "铁",
        "Steel": "钢",
        "Jade": "玉石",
        "Clay": "黏土",
        "Hemp": "苎麻",
        "Stone": "石料",
        "Weapons": "武器",
        "Lacquerware": "漆器",
        "Bronzeware": "铜器",
        "Silk": "丝绸",
        "Ceramics": "瓷器",
        "CarvedJade": "玉器",
        "Carved Jade": "玉器",
        "Paper": "纸",
        "Dinners": "食物",
    ]

    private static let mapNames: [String: String] = [
        "Anyang": "安阳",
        "Anyi": "安邑",
        "Anyi-new": "新安邑",
        "Badaling": "八达岭",
        "Banpo": "半坡",
        "Baoji": "宝鸡",
        "Bo": "亳",
        "Chang-an": "长安",
        "Chang-an Han": "汉代长安",
        "Chang-an Sui": "隋代长安",
        "Chang-an Zhou": "周代长安",
        "Chengdu": "成都",
        "Chizhou": "池州",
        "Dunhuang": "敦煌",
        "Erlitou": "二里头",
        "Fo Yu Testin": "佛域测试地图",
        "Guangzhou": "广州",
        "Handan": "邯郸",
        "Hao": "镐京",
        "Haunxian": "环县",
        "Hemudu": "河姆渡",
        "Ji": "蓟",
        "Jiangling": "江陵",
        "Jiangxi": "江西",
        "Jiaozhou": "交州",
        "Jiayuguan": "嘉峪关",
        "Jinyang": "晋阳",
        "Juchengshi": "巨城市",
        "Juyongguan": "居庸关",
        "Kaifeng": "开封",
        "Kashgar": "喀什葛尔",
        "Lanzhou": "兰州",
        "Liangzhou": "凉州",
        "Lingshou": "灵寿",
        "Linzi": "临淄",
        "Lo-lang": "乐浪",
        "LopNor": "罗布泊",
        "Loulan": "楼兰",
        "Loyi": "洛邑",
        "Luoyang": "洛阳",
        "Luoyang Han": "汉代洛阳",
        "Luoyang Tang": "唐代洛阳",
        "Luoyang WJin": "西晋洛阳",
        "Niya": "尼雅",
        "Pingyao": "平遥",
        "Qufu": "曲阜",
        "Shanhaiguan": "山海关",
        "Shu": "蜀",
        "Suzhou": "苏州",
        "Weizhou": "潍州",
        "Wu": "吴",
        "Xia": "夏",
        "Xiangjun": "象郡",
        "Xianyang": "咸阳",
        "Yangzhou": "扬州",
        "Yen": "燕",
        "Ying": "郢",
        "Yong": "雍州",
        "Yulin": "榆林",
        "Zhengzhou": "郑州",
        "Zhongdu": "中都",
    ]

    private static let campaignSummaries: [String: String] = [
        "Xia Dynasty Tutorials": "从聚落营建、农业与贸易开始，逐步掌握古代城市治理。",
        "City States of Shang": "在商代城邦兴起之际发展青铜业、宗庙与王朝都城。",
        "Turbulent Winds of Zhou": "承接天命，在周代的变局中营建都邑并开拓铁器时代。",
        "The Mighty Qin": "以水利、城防与统一战争奠定秦帝国的根基。",
        "The Silk Road": "经营汉代都城与边塞，让丝绸之路贯通东西。",
        "A Time of Grandeur": "从隋唐统一走向盛世，修筑运河、宫殿并守卫西域。",
        "Invaders from the North": "在宋、金与蒙古交锋的时代维持城市繁荣与北方防线。",
        "Emperor Jin Wudi": "重整国库、开拓长江据点，尝试终结三国分立。",
    ]

    private static let commandToolNames: [String: String] = [
        "inspect": "浏览",
        "demolish": "拆除",
        "clearLand": "清理树木",
        "road": "道路",
        "rally": "部队集结",
        "house": "住宅",
        "warehouse": "仓库",
        "mill": "磨坊",
        "market": "市场",
        "clayPit": "粘土坑",
        "kiln": "窑场",
        "well": "水井",
        "herbalist": "药草铺",
        "acupuncture": "针灸所",
        "inspectorTower": "巡察塔",
        "taxOffice": "税务所",
        "musicSchool": "音乐学校",
        "acrobatSchool": "杂技学校",
        "dramaSchool": "戏剧学校",
        "ancestralShrine": "祖庙",
    ]

    static func campaignTitle(_ authoredTitle: String) -> String {
        campaignTitles[authoredTitle] ?? authoredTitle
    }

    static func missionTitle(_ authoredTitle: String) -> String {
        missionTitles[authoredTitle]
            ?? campaignTitles[authoredTitle]
            ?? originalText?.localized(authoredTitle)
            ?? authoredTitle
    }

    static func cityName(_ authoredName: String) -> String {
        cityNames[authoredName]
            ?? originalText?.localized(authoredName, groupID: 21)
            ?? originalText?.localized(authoredName)
            ?? authoredName
    }

    static func houseName(_ authoredName: String) -> String {
        let cleanName: String
        if let separator = authoredName.firstIndex(of: ":") {
            cleanName = String(authoredName[authoredName.index(after: separator)...])
                .trimmingCharacters(in: .whitespaces)
        } else {
            cleanName = authoredName
        }
        let withoutElitePrefix = cleanName
            .replacingOccurrences(
                of: #"^Elite(?:\s+\d+)?:\s*"#,
                with: "",
                options: .regularExpression
            )
        return houseNames[withoutElitePrefix]
            ?? originalText?.localized(withoutElitePrefix, groupID: 29)
            ?? originalText?.localized(withoutElitePrefix)
            ?? withoutElitePrefix
    }

    static func commodityName(_ authoredName: String) -> String {
        commodityNames[authoredName]
            ?? originalText?.localized(authoredName, groupID: 23)
            ?? originalText?.localized(authoredName)
            ?? authoredName
    }

    static func foodQualityName(_ quality: FoodQuality) -> String {
        switch quality {
        case .none: "无"
        case .bland: "粗淡"
        case .plain: "家常"
        case .appetizing: "可口"
        case .tasty: "鲜美"
        case .delicious: "珍馐"
        }
    }

    static func authoredName(_ authoredName: String) -> String {
        let house = houseName(authoredName)
        if house != authoredName { return house }
        let commodity = commodityName(authoredName)
        if commodity != authoredName { return commodity }
        return originalText?.localized(authoredName) ?? authoredName
    }

    static func campaignSummary(_ authoredTitle: String) -> String {
        campaignSummaries[authoredTitle] ?? "原版战役场景，可查看任务目标、年代与初始条件。"
    }

    static func mapName(_ url: URL) -> String {
        mapName(url.deletingPathExtension().lastPathComponent)
    }

    static func mapName(_ authoredStem: String) -> String {
        var stem = authoredStem
        let isSmall = stem.hasSuffix("_S")
        if isSmall {
            stem.removeLast(2)
        }

        let scenarioPrefixes: [(String, String)] = [
            ("ASSR-", "保卫丝绸之路"),
            ("NavalT-", "海上贸易"),
            ("SAO-", "反抗压迫"),
            ("SA-", "春秋时代"),
            ("STGW-", "支援长城"),
        ]
        let prefix = scenarioPrefixes.first { stem.hasPrefix($0.0) }
        if let prefix {
            stem.removeFirst(prefix.0.count)
        }

        let baseName: String
        if let multiplayer = numericSuffix(stem, prefix: "MP") {
            baseName = "多人地图 \(multiplayer)"
        } else if let wall = numericSuffix(stem, prefix: "MPWall") {
            baseName = "多人长城地图 \(wall)"
        } else if let canal = numericSuffix(stem, prefix: "MPcanal") {
            baseName = "多人运河地图 \(canal)"
        } else {
            baseName = mapNames[stem]
                ?? cityName(stem)
        }

        let scenarioName = prefix.map { "\($0.1)：\(baseName)" } ?? baseName
        return isSmall ? "\(scenarioName)（小型）" : scenarioName
    }

    static func statusMessage(_ authoredMessage: String) -> String {
        let message = authoredMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let exact: [String: String] = [
            "save does not identify a campaign mission": "存档未关联到有效的战役任务",
            "restored persisted mission": "已恢复保存的战役任务",
            "production building does not exist": "生产建筑不存在",
            "warehouse does not exist": "仓库不存在",
            "trading building does not exist": "贸易建筑不存在",
            "mission has reached a terminal outcome": "任务已经结束",
            "no active mission": "当前没有进行中的任务",
            "campaign or mission does not exist": "战役或任务不存在",
            "no active city": "当前没有可操作的城市",
            "select a construction tool": "请先选择建造工具",
            "nothing to demolish at tile": "这里没有可拆除的对象",
            "simulation is paused": "游戏已暂停",
            "tile is outside the playable map": "目标格超出可玩地图",
            "tile is occupied": "目标格已经被占用",
            "terrain, footprint, road access, resource layer or treasury blocks construction":
                "地形、占地、道路、资源层或国库条件不允许在这里建造",
        ]
        if let localized = exact[message] { return localized }

        if message.hasPrefix("selected ") {
            let rawTool = String(message.dropFirst("selected ".count))
            return "已选择\(commandToolNames[rawTool] ?? "建造工具")"
        }
        if message.hasPrefix("placed "),
           let coordinateRange = message.range(of: " at ", options: .backwards) {
            let toolStart = message.index(
                message.startIndex,
                offsetBy: "placed ".count
            )
            let rawTool = String(message[toolStart..<coordinateRange.lowerBound])
            let coordinates = String(message[coordinateRange.upperBound...])
            return "已在 \(coordinates) 建造\(commandToolNames[rawTool] ?? "建筑")"
        }
        if message.hasPrefix("demolished tile ") {
            return "已拆除坐标 \(message.dropFirst("demolished tile ".count)) 的对象"
        }
        if message.hasPrefix("started ") {
            return "已开始：\(missionTitle(String(message.dropFirst("started ".count))))"
        }
        if message.hasPrefix("speed ") {
            return "游戏速度已设为 \(message.dropFirst("speed ".count))×"
        }
        if message.hasPrefix("advanced tick ") {
            return "模拟已推进一日"
        }
        if message.hasPrefix("mission initialization failed:") {
            return "任务初始化失败，请检查原版资料"
        }
        if message.hasPrefix("campaign restriction:") {
            return "当前任务尚未开放这项建筑"
        }
        let localizedName = authoredName(message)
        if localizedName != message { return localizedName }
        return message.range(of: #"[A-Za-z]"#, options: .regularExpression) == nil
            ? message
            : "操作未完成，请检查当前任务条件"
    }

    private static func numericSuffix(_ value: String, prefix: String) -> Int? {
        guard value.hasPrefix(prefix) else { return nil }
        return Int(value.dropFirst(prefix.count))
    }
}
