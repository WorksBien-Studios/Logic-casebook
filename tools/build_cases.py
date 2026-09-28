#!/usr/bin/env python3
"""Build the 300-case Logic Casebook content bundle deterministically."""

from __future__ import annotations

import hashlib
import itertools
import json
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
SEED = 20260928

PEOPLE = [
    "葵", "蓮", "凛", "湊", "楓", "結衣", "悠真", "美咲", "陽菜", "颯太",
    "七海", "大和", "琴音", "直樹", "明日香", "拓海", "千尋", "健太", "彩乃", "翔",
]

THEMES = [
    {"code":"museum","title":"消えた展示札","place":"美術館","objectLabel":"展示品","objects":["青い花瓶","古い時計","銀の彫像","風景画","木箱"],"locationLabel":"展示室","locations":["東展示室","西展示室","中央展示室","特別室","南展示室"],"timeLabel":"時刻","times":["9時","10時","11時","12時","13時"]},
    {"code":"cafe","title":"喫茶店の忘れ物","place":"喫茶店","objectLabel":"注文","objects":["紅茶","珈琲","抹茶ラテ","レモネード","ココア"],"locationLabel":"席","locations":["窓側席","入口席","奥の席","カウンター","テラス席"],"timeLabel":"時刻","times":["10時","11時","12時","13時","14時"]},
    {"code":"library","title":"図書館の返却記録","place":"図書館","objectLabel":"本","objects":["歴史書","推理小説","旅行記","図鑑","詩集"],"locationLabel":"閲覧席","locations":["一番席","二番席","三番席","四番席","五番席"],"timeLabel":"返却時刻","times":["13時","14時","15時","16時","17時"]},
    {"code":"station","title":"駅に残された荷物","place":"駅","objectLabel":"荷物","objects":["赤い鞄","傘","紙袋","楽器ケース","小包"],"locationLabel":"場所","locations":["北口","南口","改札前","売店前","待合室"],"timeLabel":"発見時刻","times":["8時","9時","10時","11時","12時"]},
    {"code":"hotel","title":"ホテルの鍵","place":"ホテル","objectLabel":"鍵","objects":["青い鍵","赤い鍵","白い鍵","黒い鍵","金色の鍵"],"locationLabel":"階","locations":["2階","3階","4階","5階","6階"],"timeLabel":"受取時刻","times":["15時","16時","17時","18時","19時"]},
    {"code":"festival","title":"祭りの当番表","place":"秋祭り","objectLabel":"担当","objects":["受付","案内","清掃","放送","警備"],"locationLabel":"持ち場","locations":["東門","西門","本部","広場","舞台"],"timeLabel":"開始時刻","times":["9時","10時","11時","12時","13時"]},
    {"code":"bakery","title":"パン屋の予約票","place":"パン屋","objectLabel":"商品","objects":["食パン","あんパン","クロワッサン","メロンパン","バゲット"],"locationLabel":"受取窓口","locations":["一番窓口","二番窓口","三番窓口","四番窓口","五番窓口"],"timeLabel":"受取時刻","times":["8時","9時","10時","11時","12時"]},
    {"code":"garden","title":"庭園の観察記録","place":"植物園","objectLabel":"植物","objects":["薔薇","椿","菊","百合","桜草"],"locationLabel":"区画","locations":["北区画","南区画","東区画","西区画","中央区画"],"timeLabel":"観察時刻","times":["9時","10時","11時","12時","13時"]},
    {"code":"school","title":"放課後の教室","place":"学校","objectLabel":"持ち物","objects":["ノート","定規","筆箱","水筒","辞書"],"locationLabel":"教室","locations":["音楽室","理科室","図書室","美術室","家庭科室"],"timeLabel":"退出時刻","times":["15時","16時","17時","18時","19時"]},
    {"code":"market","title":"市場の配送記録","place":"市場","objectLabel":"商品","objects":["林檎","蜜柑","葡萄","梨","桃"],"locationLabel":"売場","locations":["北売場","南売場","東売場","西売場","中央売場"],"timeLabel":"配送時刻","times":["6時","7時","8時","9時","10時"]},
    {"code":"clinic","title":"診療所の予約順","place":"診療所","objectLabel":"診療科","objects":["内科","眼科","耳鼻科","皮膚科","歯科"],"locationLabel":"診察室","locations":["第一室","第二室","第三室","第四室","第五室"],"timeLabel":"予約時刻","times":["9時","10時","11時","12時","13時"]},
    {"code":"theater","title":"劇場の小道具","place":"劇場","objectLabel":"小道具","objects":["王冠","手紙","扇子","懐中時計","仮面"],"locationLabel":"保管場所","locations":["舞台袖","楽屋","倉庫","受付","稽古場"],"timeLabel":"確認時刻","times":["14時","15時","16時","17時","18時"]},
    {"code":"harbor","title":"港の積荷台帳","place":"港","objectLabel":"積荷","objects":["木材","布地","陶器","茶葉","工具"],"locationLabel":"埠頭","locations":["第一埠頭","第二埠頭","第三埠頭","第四埠頭","第五埠頭"],"timeLabel":"到着時刻","times":["7時","8時","9時","10時","11時"]},
    {"code":"workshop","title":"工房の制作記録","place":"工房","objectLabel":"作品","objects":["木皿","花瓶","額縁","小箱","置時計"],"locationLabel":"作業台","locations":["赤い台","青い台","白い台","緑の台","黄色い台"],"timeLabel":"完成時刻","times":["13時","14時","15時","16時","17時"]},
    {"code":"observatory","title":"天文台の観測表","place":"天文台","objectLabel":"観測対象","objects":["月","火星","木星","土星","金星"],"locationLabel":"望遠鏡","locations":["北望遠鏡","南望遠鏡","東望遠鏡","西望遠鏡","中央望遠鏡"],"timeLabel":"観測時刻","times":["19時","20時","21時","22時","23時"]},
    {"code":"archive","title":"資料館の整理番号","place":"資料館","objectLabel":"資料","objects":["古地図","写真帳","日記","設計図","新聞束"],"locationLabel":"書架","locations":["A書架","B書架","C書架","D書架","E書架"],"timeLabel":"整理時刻","times":["10時","11時","12時","13時","14時"]},
    {"code":"studio","title":"撮影所の進行表","place":"撮影所","objectLabel":"場面","objects":["駅の場面","食堂の場面","公園の場面","会議の場面","屋上の場面"],"locationLabel":"スタジオ","locations":["第一スタジオ","第二スタジオ","第三スタジオ","第四スタジオ","第五スタジオ"],"timeLabel":"撮影時刻","times":["9時","10時","11時","12時","13時"]},
    {"code":"farm","title":"農園の収穫記録","place":"農園","objectLabel":"作物","objects":["苺","南瓜","胡瓜","茄子","玉葱"],"locationLabel":"畑","locations":["北畑","南畑","東畑","西畑","中央畑"],"timeLabel":"収穫時刻","times":["6時","7時","8時","9時","10時"]},
    {"code":"aquarium","title":"水族館の点検表","place":"水族館","objectLabel":"生き物","objects":["クラゲ","ウミガメ","タツノオトシゴ","ペンギン","イルカ"],"locationLabel":"水槽","locations":["青い水槽","白い水槽","丸い水槽","大水槽","小水槽"],"timeLabel":"点検時刻","times":["9時","10時","11時","12時","13時"]},
    {"code":"bookshop","title":"書店の予約本","place":"書店","objectLabel":"予約本","objects":["料理本","写真集","随筆","科学書","短編集"],"locationLabel":"受取棚","locations":["A棚","B棚","C棚","D棚","E棚"],"timeLabel":"受取時刻","times":["11時","12時","13時","14時","15時"]},
    {"code":"airport","title":"空港の手荷物記録","place":"空港","objectLabel":"手荷物","objects":["青い鞄","白い箱","楽器ケース","赤い袋","銀の鞄"],"locationLabel":"窓口","locations":["A窓口","B窓口","C窓口","D窓口","E窓口"],"timeLabel":"受付時刻","times":["7時","8時","9時","10時","11時"]},
    {"code":"pharmacy","title":"薬局の受取票","place":"薬局","objectLabel":"商品","objects":["包帯","体温計","目薬","湿布","マスク"],"locationLabel":"受取台","locations":["一番台","二番台","三番台","四番台","五番台"],"timeLabel":"受取時刻","times":["9時","10時","11時","12時","13時"]},
    {"code":"university","title":"大学の研究発表","place":"大学","objectLabel":"発表分野","objects":["歴史","物理","文学","生物","建築"],"locationLabel":"会場","locations":["第一講義室","第二講義室","第三講義室","第四講義室","第五講義室"],"timeLabel":"開始時刻","times":["10時","11時","12時","13時","14時"]},
    {"code":"restaurant","title":"食堂の予約席","place":"食堂","objectLabel":"定食","objects":["魚定食","野菜定食","鶏定食","豆腐定食","蕎麦定食"],"locationLabel":"席","locations":["窓側席","入口席","奥の席","中央席","庭側席"],"timeLabel":"予約時刻","times":["11時","12時","13時","14時","15時"]},
    {"code":"music_school","title":"音楽教室の練習表","place":"音楽教室","objectLabel":"楽器","objects":["ピアノ","バイオリン","フルート","ギター","太鼓"],"locationLabel":"練習室","locations":["第一室","第二室","第三室","第四室","第五室"],"timeLabel":"練習時刻","times":["13時","14時","15時","16時","17時"]},
    {"code":"sports_club","title":"運動教室の予定表","place":"運動教室","objectLabel":"種目","objects":["水泳","卓球","弓道","体操","テニス"],"locationLabel":"会場","locations":["第一会場","第二会場","第三会場","第四会場","第五会場"],"timeLabel":"開始時刻","times":["9時","10時","11時","12時","13時"]},
    {"code":"post_office","title":"郵便局の発送記録","place":"郵便局","objectLabel":"郵便物","objects":["小包","封書","葉書","書留","冊子"],"locationLabel":"受付窓口","locations":["一番窓口","二番窓口","三番窓口","四番窓口","五番窓口"],"timeLabel":"受付時刻","times":["9時","10時","11時","12時","13時"]},
    {"code":"flower_shop","title":"花屋の配達表","place":"花屋","objectLabel":"花束","objects":["薔薇の花束","百合の花束","向日葵の花束","菊の花束","桔梗の花束"],"locationLabel":"配達先","locations":["北町","南町","東町","西町","中央町"],"timeLabel":"配達時刻","times":["10時","11時","12時","13時","14時"]},
    {"code":"pottery","title":"陶芸教室の焼成記録","place":"陶芸教室","objectLabel":"作品","objects":["茶碗","湯呑み","花瓶","皿","小鉢"],"locationLabel":"窯","locations":["一号窯","二号窯","三号窯","四号窯","五号窯"],"timeLabel":"完成時刻","times":["12時","13時","14時","15時","16時"]},
    {"code":"newsroom","title":"新聞社の取材表","place":"新聞社","objectLabel":"取材分野","objects":["地域","文化","科学","教育","交通"],"locationLabel":"担当室","locations":["第一室","第二室","第三室","第四室","第五室"],"timeLabel":"締切時刻","times":["14時","15時","16時","17時","18時"]},
    {"code":"radio","title":"放送局の番組表","place":"放送局","objectLabel":"番組","objects":["ニュース番組","音楽番組","朗読番組","天気番組","対談番組"],"locationLabel":"スタジオ","locations":["Aスタジオ","Bスタジオ","Cスタジオ","Dスタジオ","Eスタジオ"],"timeLabel":"放送時刻","times":["8時","9時","10時","11時","12時"]},
    {"code":"lodge","title":"森の宿の貸出帳","place":"森の宿","objectLabel":"貸出品","objects":["双眼鏡","地図","雨具","水筒","毛布"],"locationLabel":"保管棚","locations":["北棚","南棚","東棚","西棚","中央棚"],"timeLabel":"貸出時刻","times":["7時","8時","9時","10時","11時"]},
    {"code":"castle","title":"城跡の案内記録","place":"城跡","objectLabel":"見学場所","objects":["天守跡","石垣","庭園","資料室","門跡"],"locationLabel":"集合場所","locations":["北門","南門","東門","西門","広場"],"timeLabel":"開始時刻","times":["9時","10時","11時","12時","13時"]},
    {"code":"cinema","title":"映画館の上映表","place":"映画館","objectLabel":"作品","objects":["青い海","冬の森","星の旅","古い手紙","朝の街"],"locationLabel":"上映室","locations":["第一上映室","第二上映室","第三上映室","第四上映室","第五上映室"],"timeLabel":"上映時刻","times":["10時","12時","14時","16時","18時"]},
    {"code":"conference","title":"交流会の発表順","place":"交流会","objectLabel":"発表テーマ","objects":["地域活動","読書","健康","防災","環境"],"locationLabel":"会議室","locations":["青の間","白の間","緑の間","黄の間","赤の間"],"timeLabel":"発表時刻","times":["10時","11時","12時","13時","14時"]},
    {"code":"volunteer","title":"地域活動の担当表","place":"地域活動センター","objectLabel":"担当","objects":["受付","清掃","配布","案内","記録"],"locationLabel":"活動場所","locations":["公園","集会所","図書室","広場","遊歩道"],"timeLabel":"開始時刻","times":["8時","9時","10時","11時","12時"]},
    {"code":"repair","title":"修理店の受付票","place":"修理店","objectLabel":"修理品","objects":["時計","鞄","椅子","照明","ラジオ"],"locationLabel":"作業台","locations":["一番台","二番台","三番台","四番台","五番台"],"timeLabel":"受付時刻","times":["9時","10時","11時","12時","13時"]},
    {"code":"laundry","title":"クリーニング店の受取表","place":"クリーニング店","objectLabel":"預かり品","objects":["上着","毛布","帽子","手袋","敷物"],"locationLabel":"保管棚","locations":["A棚","B棚","C棚","D棚","E棚"],"timeLabel":"受取時刻","times":["12時","13時","14時","15時","16時"]},
    {"code":"toy_store","title":"玩具店の予約品","place":"玩具店","objectLabel":"玩具","objects":["積み木","人形","模型","絵札","盤ゲーム"],"locationLabel":"受取棚","locations":["赤い棚","青い棚","白い棚","緑の棚","黄色い棚"],"timeLabel":"受取時刻","times":["10時","11時","12時","13時","14時"]},
    {"code":"tea_shop","title":"茶店の注文控え","place":"茶店","objectLabel":"茶葉","objects":["煎茶","焙じ茶","玄米茶","玉露","和紅茶"],"locationLabel":"席","locations":["窓側席","庭側席","奥の席","入口席","中央席"],"timeLabel":"注文時刻","times":["10時","11時","12時","13時","14時"]},
    {"code":"ferry","title":"連絡船の乗船記録","place":"港の連絡船","objectLabel":"荷物","objects":["旅行鞄","小包","自転車","画材箱","楽器ケース"],"locationLabel":"乗船口","locations":["第一口","第二口","第三口","第四口","第五口"],"timeLabel":"乗船時刻","times":["7時","9時","11時","13時","15時"]},
    {"code":"mountain_hut","title":"山小屋の宿泊帳","place":"山小屋","objectLabel":"貸出品","objects":["毛布","灯り","地図","杖","雨具"],"locationLabel":"部屋","locations":["松の間","竹の間","梅の間","桜の間","楓の間"],"timeLabel":"到着時刻","times":["13時","14時","15時","16時","17時"]},
    {"code":"camp","title":"野外教室の班分け","place":"野外教室","objectLabel":"活動","objects":["炊事","観察","工作","地図読み","清掃"],"locationLabel":"集合場所","locations":["北広場","南広場","東広場","西広場","中央広場"],"timeLabel":"開始時刻","times":["8時","9時","10時","11時","12時"]},
    {"code":"pet_clinic","title":"動物診療所の予約表","place":"動物診療所","objectLabel":"動物","objects":["犬","猫","兎","小鳥","亀"],"locationLabel":"診察室","locations":["第一室","第二室","第三室","第四室","第五室"],"timeLabel":"予約時刻","times":["9時","10時","11時","12時","13時"]},
    {"code":"laboratory","title":"研究室の実験記録","place":"研究室","objectLabel":"試料","objects":["試料A","試料B","試料C","試料D","試料E"],"locationLabel":"実験台","locations":["一番台","二番台","三番台","四番台","五番台"],"timeLabel":"開始時刻","times":["9時","10時","11時","12時","13時"]},
    {"code":"dance","title":"舞踊教室の練習順","place":"舞踊教室","objectLabel":"演目","objects":["春の舞","波の舞","月の舞","森の舞","風の舞"],"locationLabel":"練習室","locations":["第一室","第二室","第三室","第四室","第五室"],"timeLabel":"開始時刻","times":["13時","14時","15時","16時","17時"]},
    {"code":"photo","title":"写真館の撮影表","place":"写真館","objectLabel":"撮影内容","objects":["家族写真","証明写真","記念写真","商品写真","風景写真"],"locationLabel":"撮影室","locations":["A室","B室","C室","D室","E室"],"timeLabel":"撮影時刻","times":["10時","11時","12時","13時","14時"]},
    {"code":"town_hall","title":"市民窓口の受付記録","place":"市民窓口","objectLabel":"手続き","objects":["証明書","相談","届出","申請","案内"],"locationLabel":"窓口","locations":["一番窓口","二番窓口","三番窓口","四番窓口","五番窓口"],"timeLabel":"受付時刻","times":["9時","10時","11時","12時","13時"]},
    {"code":"warehouse","title":"倉庫の入庫台帳","place":"倉庫","objectLabel":"荷物","objects":["木箱","紙箱","布袋","工具箱","書類箱"],"locationLabel":"保管区画","locations":["A区画","B区画","C区画","D区画","E区画"],"timeLabel":"入庫時刻","times":["7時","8時","9時","10時","11時"]},
    {"code":"community_center","title":"公民館の利用予定","place":"公民館","objectLabel":"活動","objects":["読書会","手芸会","健康教室","歴史講座","音楽会"],"locationLabel":"部屋","locations":["第一室","第二室","第三室","第四室","第五室"],"timeLabel":"開始時刻","times":["9時","10時","11時","12時","13時"]},
]

PROFILES = {
    "beginner": {"n":3, "k":3, "count":120, "free":10, "targetRatio":0.38},
    "standard": {"n":4, "k":3, "count":260, "free":8, "targetRatio":0.58},
    "advanced": {"n":5, "k":3, "count":360, "free":8, "targetRatio":0.72},
    "expert": {"n":4, "k":4, "count":260, "free":4, "targetRatio":0.78},
}

SOLUTION_CACHE: dict[tuple[int, int], list[tuple[tuple[int, ...], ...]]] = {}
SOLUTION_INDEX_CACHE = {}
CLUE_MASK_CACHE = {}


def all_assignments(n: int, k: int):
    key = (n, k)
    if key not in SOLUTION_CACHE:
        perms = list(itertools.permutations(range(n)))
        SOLUTION_CACHE[key] = list(itertools.product(perms, repeat=k - 1))
    return SOLUTION_CACHE[key]


def assignment_index(n: int, k: int):
    key = (n, k)
    if key not in SOLUTION_INDEX_CACHE:
        SOLUTION_INDEX_CACHE[key] = {a:i for i,a in enumerate(all_assignments(n, k))}
    return SOLUTION_INDEX_CACHE[key]


def owner(assignment, category: int, value: int) -> int:
    if category == 0:
        return value
    return assignment[category - 1].index(value)


def ordered_value(assignment, entity: tuple[int, int], ordered_category: int) -> int:
    p = owner(assignment, entity[0], entity[1])
    return assignment[ordered_category - 1][p]


def evaluate(clue: dict, assignment) -> bool:
    t = clue["type"]
    a = clue["args"]
    if t == "same":
        return owner(assignment, *a["left"]) == owner(assignment, *a["right"])
    if t == "different":
        return owner(assignment, *a["left"]) != owner(assignment, *a["right"])
    if t == "either":
        subject = owner(assignment, *a["subject"])
        return subject in {owner(assignment, *a["optionA"]), owner(assignment, *a["optionB"])}
    if t == "pairSet":
        left = {owner(assignment, *x) for x in a["left"]}
        right = {owner(assignment, *x) for x in a["right"]}
        return left == right
    if t in {"before", "immediatelyBefore", "offsetBefore"}:
        lv = ordered_value(assignment, tuple(a["left"]), a["orderedCategory"])
        rv = ordered_value(assignment, tuple(a["right"]), a["orderedCategory"])
        if t == "before":
            return lv < rv
        offset = 1 if t == "immediatelyBefore" else a["offset"]
        return rv - lv == offset
    raise ValueError(f"Unknown clue type: {t}")


def vname(categories, ref):
    return categories[ref[0]]["values"][ref[1]]["nameJA"]


def render_clue(clue: dict, categories: list[dict]) -> str:
    t, a = clue["type"], clue["args"]
    q = lambda ref: f"「{vname(categories, ref)}」"
    if t == "same":
        return f"{q(a['left'])}と{q(a['right'])}は同じ組です。"
    if t == "different":
        return f"{q(a['left'])}と{q(a['right'])}は同じ組ではありません。"
    if t == "either":
        return f"{q(a['subject'])}と同じ組なのは、{q(a['optionA'])}または{q(a['optionB'])}のどちらかです。"
    if t == "pairSet":
        return f"{q(a['left'][0])}と{q(a['left'][1])}に対応するのは、{q(a['right'][0])}と{q(a['right'][1])}です（組み合わせの順序は未確定です）。"
    label = categories[a["orderedCategory"]]["nameJA"]
    if t == "before":
        return f"{q(a['left'])}の{label}は、{q(a['right'])}の{label}より前です。"
    if t == "immediatelyBefore":
        return f"{q(a['left'])}の{label}は、{q(a['right'])}の{label}の直前です。"
    if t == "offsetBefore":
        return f"{q(a['left'])}の{label}は、{q(a['right'])}の{label}より{a['offset']}枠前です。"
    raise ValueError(t)


def clue_key(clue):
    return json.dumps({"type": clue["type"], "args": clue["args"]}, sort_keys=True, ensure_ascii=False)


def clue_mask(clue, n, k):
    key = (n, k, clue_key(clue))
    if key not in CLUE_MASK_CACHE:
        mask = 0
        for idx, assignment in enumerate(all_assignments(n, k)):
            if evaluate(clue, assignment):
                mask |= 1 << idx
        CLUE_MASK_CACHE[key] = mask
    return CLUE_MASK_CACHE[key]


def generate_pool(target, n: int, k: int, rng: random.Random):
    pool = []
    for ca in range(k):
        for cb in range(ca + 1, k):
            for va in range(n):
                matching = next(vb for vb in range(n) if owner(target, ca, va) == owner(target, cb, vb))
                pool.append({"type":"same", "args":{"left":[ca,va], "right":[cb,matching]}})
                for vb in range(n):
                    if vb != matching:
                        pool.append({"type":"different", "args":{"left":[ca,va], "right":[cb,vb]}})
                for distractor in range(n):
                    if distractor != matching:
                        opts = [[cb, matching], [cb, distractor]]
                        rng.shuffle(opts)
                        pool.append({"type":"either", "args":{"subject":[ca,va], "optionA":opts[0], "optionB":opts[1]}})
            for va1, va2 in itertools.combinations(range(n), 2):
                right = []
                for va in (va1, va2):
                    right.append([cb, next(vb for vb in range(n) if owner(target, ca, va) == owner(target, cb, vb))])
                rng.shuffle(right)
                pool.append({"type":"pairSet", "args":{"left":[[ca,va1],[ca,va2]], "right":right}})

    ordered = k - 1
    entity_categories = range(k - 1)
    for ca in entity_categories:
        refs = [(ca, v) for v in range(n)]
        for left, right in itertools.permutations(refs, 2):
            lv = ordered_value(target, left, ordered)
            rv = ordered_value(target, right, ordered)
            if lv < rv:
                pool.append({"type":"before", "args":{"left":list(left), "right":list(right), "orderedCategory":ordered}})
                delta = rv - lv
                if delta == 1:
                    pool.append({"type":"immediatelyBefore", "args":{"left":list(left), "right":list(right), "orderedCategory":ordered}})
                elif delta >= 2:
                    pool.append({"type":"offsetBefore", "args":{"left":list(left), "right":list(right), "orderedCategory":ordered, "offset":delta}})

    unique = {clue_key(c): c for c in pool}
    return list(unique.values())


def choose_clues(target, assignments, pool, profile, rng):
    n, k = profile["n"], profile["k"]
    candidates = (1 << len(assignments)) - 1
    chosen = []
    remaining = pool[:]
    direct_limit = {"beginner":4, "standard":2, "advanced":1, "expert":1}
    direct_used = 0
    level = profile["name"]

    while candidates.bit_count() > 1 and remaining:
        scored = []
        desired = max(0.05, min(0.95, rng.gauss(profile["targetRatio"], 0.08)))
        for clue in remaining:
            filtered = candidates & clue_mask(clue, n, k)
            if not filtered or filtered == candidates:
                continue
            ratio = filtered.bit_count() / candidates.bit_count()
            penalty = abs(ratio - desired)
            if clue["type"] == "same" and direct_used >= direct_limit[level]:
                penalty += 0.30
            if level in {"advanced", "expert"} and clue["type"] in {"pairSet", "before", "offsetBefore"}:
                penalty -= 0.04
            scored.append((penalty + rng.random() * 0.025, clue, filtered))
        if not scored:
            break
        scored.sort(key=lambda x: x[0])
        _, clue, candidates = rng.choice(scored[: min(4, len(scored))])
        chosen.append(clue)
        remaining.remove(clue)
        if clue["type"] == "same":
            direct_used += 1

    target_bit = 1 << assignment_index(n, k)[target]
    if candidates != target_bit:
        return None

    # Remove clues that do not contribute to uniqueness.
    changed = True
    while changed:
        changed = False
        for i in list(range(len(chosen) - 1, -1, -1)):
            trial = chosen[:i] + chosen[i+1:]
            survivors = (1 << len(assignments)) - 1
            for clue in trial:
                survivors &= clue_mask(clue, n, k)
            if survivors == target_bit:
                chosen = trial
                changed = True
                break
    return chosen


def forced_pairs(candidate_mask, n, k):
    facts = set()
    for ca in range(k):
        for cb in range(ca + 1, k):
            for va in range(n):
                for vb in range(n):
                    relation = {"type":"same", "args":{"left":[ca,va], "right":[cb,vb]}}
                    if candidate_mask & ~clue_mask(relation, n, k) == 0:
                        facts.add((ca, va, cb, vb))
                        break
    return facts


# Cap how many clues a single hint step may bundle before it force-closes,
# even without a newly forced fact. Without this cap, a set of clues that
# are individually inconclusive but jointly decisive (no fact becomes fully
# certain until the very last clue) collapses into one all-or-nothing step,
# so the first hint on such a case would have to reveal the entire solution.
MAX_PENDING_CLUES = 3


def deduction_steps(chosen, assignments, categories, n, k):
    current = (1 << len(assignments)) - 1
    remaining = list(enumerate(chosen))
    known = forced_pairs(current, n, k)
    steps = []
    pending_ids = []
    pending_before = current.bit_count()

    while remaining:
        ranked = []
        for idx, clue in remaining:
            filtered = current & clue_mask(clue, n, k)
            newfacts = forced_pairs(filtered, n, k) - known
            ranked.append((len(newfacts), current.bit_count() - filtered.bit_count(), -idx, idx, clue, filtered, newfacts))
        ranked.sort(reverse=True, key=lambda x: x[:3])
        _, _, _, idx, clue, filtered, newfacts = ranked[0]
        remaining = [(i, c) for i, c in remaining if i != idx]
        pending_ids.append(f"clue-{idx+1:02d}")
        current = filtered
        if newfacts or not remaining or len(pending_ids) >= MAX_PENDING_CLUES:
            known_now = forced_pairs(current, n, k)
            newfacts = known_now - known
            facts = []
            for ca, va, cb, vb in sorted(newfacts):
                facts.append({
                    "relation":"same",
                    "left":[categories[ca]["id"], categories[ca]["values"][va]["id"]],
                    "right":[categories[cb]["id"], categories[cb]["values"][vb]["id"]],
                    "textJA":f"「{categories[ca]['values'][va]['nameJA']}」と「{categories[cb]['values'][vb]['nameJA']}」は同じ組だと確定します。"
                })
            cited = "、".join(f"手がかり{int(x.split('-')[1])}" for x in pending_ids)
            reason = f"{cited}を使うと、候補は{pending_before}通りから{current.bit_count()}通りに絞れます。"
            if facts:
                reason += facts[0]["textJA"]
            steps.append({
                "step":len(steps)+1,
                "clueIDs":pending_ids,
                "candidateCountBefore":pending_before,
                "candidateCountAfter":current.bit_count(),
                "deducedFacts":facts,
                "explanationJA":reason,
            })
            known = known_now
            pending_ids = []
            pending_before = current.bit_count()
    return steps


def canonical_signature(target, clues, n, k):
    # Normalize each unordered category value by its owner in the target solution.
    # Keep ordered time-slot indices because their order is semantically meaningful.
    ordered = k - 1
    normalized = []
    for clue in clues:
        a = json.loads(json.dumps(clue["args"]))
        def norm(ref):
            cat, val = ref
            return [cat, val if cat == ordered else owner(target, cat, val)]
        t = clue["type"]
        if t in {"same", "different"}:
            a["left"], a["right"] = norm(a["left"]), norm(a["right"])
        elif t == "either":
            a["subject"] = norm(a["subject"])
            a["optionA"], a["optionB"] = norm(a["optionA"]), norm(a["optionB"])
            a["optionA"], a["optionB"] = sorted([a["optionA"], a["optionB"]])
        elif t == "pairSet":
            a["left"] = sorted(norm(x) for x in a["left"])
            a["right"] = sorted(norm(x) for x in a["right"])
        else:
            a["left"], a["right"] = norm(a["left"]), norm(a["right"])
        normalized.append({"type":t, "args":a})
    raw = json.dumps(sorted(normalized, key=lambda x: json.dumps(x, sort_keys=True)), ensure_ascii=False, sort_keys=True)
    return hashlib.sha256(f"{n}:{k}:{raw}".encode()).hexdigest()


def make_categories(theme, n, k, rng):
    names = rng.sample(PEOPLE, n)
    cats = [
        {"id":"people", "nameJA":"人物", "ordered":False, "values":[{"id":f"person-{i+1}","nameJA":v} for i,v in enumerate(names)]},
        {"id":"objects", "nameJA":theme["objectLabel"], "ordered":False, "values":[{"id":f"object-{i+1}","nameJA":v} for i,v in enumerate(rng.sample(theme["objects"], n))]},
    ]
    if k == 4:
        cats.append({"id":"locations", "nameJA":theme["locationLabel"], "ordered":False, "values":[{"id":f"location-{i+1}","nameJA":v} for i,v in enumerate(rng.sample(theme["locations"], n))]})
    cats.append({"id":"times", "nameJA":theme["timeLabel"], "ordered":True, "values":[{"id":f"time-{i+1}","nameJA":v} for i,v in enumerate(theme["times"][:n])]})
    return cats


def solution_json(target, categories):
    rows = []
    n, k = len(categories[0]["values"]), len(categories)
    for p in range(n):
        row = {categories[0]["id"]: categories[0]["values"][p]["id"]}
        for cat in range(1, k):
            row[categories[cat]["id"]] = categories[cat]["values"][target[cat-1][p]]["id"]
        rows.append(row)
    return {"rows":rows}


def convert_args(args, categories):
    def ref(x):
        return [categories[x[0]]["id"], categories[x[0]]["values"][x[1]]["id"]]
    out = {}
    for key, value in args.items():
        if key == "orderedCategory":
            out[key] = categories[value]["id"]
        elif key == "offset":
            out[key] = value
        elif key in {"left", "right"} and value and isinstance(value[0], list):
            out[key] = [ref(x) for x in value]
        elif key in {"left", "right", "subject", "optionA", "optionB"}:
            out[key] = ref(value)
        else:
            out[key] = value
    return out


def score_difficulty(n, k, clue_count, steps):
    search = math.factorial(n) ** (k - 1)
    indirect = sum(1 for s in steps if len(s["clueIDs"]) > 1)
    score = round(math.log2(search) + (k - 3) * 2.5 + indirect * 0.25 + clue_count * 0.08, 2)
    return score, search


def case_checksum(case):
    clean = {k:v for k,v in case.items() if k != "checksum"}
    payload = json.dumps(clean, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode()).hexdigest()


def build_case(case_number, difficulty, is_free, seen_signatures):
    profile = dict(PROFILES[difficulty], name=difficulty)
    n, k = profile["n"], profile["k"]
    assignments = all_assignments(n, k)
    theme = THEMES[(case_number - 1) % len(THEMES)]
    cycle = (case_number - 1) // len(THEMES) + 1

    for attempt in range(1, 250):
        rng = random.Random(SEED * 1_000_003 + case_number * 10_007 + attempt)
        categories = make_categories(theme, n, k, rng)
        target = tuple(tuple(rng.sample(range(n), n)) for _ in range(k - 1))
        pool = generate_pool(target, n, k, rng)
        clues = choose_clues(target, assignments, pool, profile, rng)
        if not clues:
            continue
        signature = canonical_signature(target, clues, n, k)
        if signature in seen_signatures:
            continue

        for idx, clue in enumerate(clues, 1):
            clue["id"] = f"clue-{idx:02d}"
            clue["textJA"] = render_clue(clue, categories)
        steps = deduction_steps(clues, assignments, categories, n, k)
        if not steps or steps[-1]["candidateCountAfter"] != 1:
            continue

        score, search_space = score_difficulty(n, k, len(clues), steps)
        title = f"{theme['title']} その{cycle}"
        category_names = "、".join(c["nameJA"] for c in categories[1:])
        scenario = f"{theme['place']}にいた{n}人の記録が混ざってしまいました。手がかりを整理して、{category_names}の正しい組み合わせを復元してください。"
        case = {
            "schemaVersion":1,
            "caseID":f"jp.logic.{case_number:04d}",
            "contentVersion":1,
            "titleJA":title,
            "scenarioJA":scenario,
            "questionJA":"すべての人物について、各項目の正しい組み合わせを特定してください。",
            "difficulty":difficulty,
            "difficultyScore":score,
            "estimatedMinutes":{"beginner":4,"standard":7,"advanced":12,"expert":16}[difficulty],
            "isFree":is_free,
            "categories":categories,
            "clues":[{"id":c["id"],"type":c["type"],"args":convert_args(c["args"],categories),"textJA":c["textJA"]} for c in clues],
            "solution":solution_json(target, categories),
            "deductionSteps":steps,
            "proofMetrics":{
                "searchSpace":search_space,
                "solutionCount":1,
                "clueCount":len(clues),
                "deductionStepCount":len(steps),
                "requiresGuess":False,
            },
            "structuralSignature":signature,
            "editorialStatus":"pending_native_review",
            "checksum":"",
        }
        case["checksum"] = case_checksum(case)
        seen_signatures.add(signature)
        return case
    raise RuntimeError(f"Unable to build unique case {case_number} ({difficulty})")


def main():
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    cases = []
    seen = set()
    case_number = 1
    for difficulty, profile in PROFILES.items():
        for offset in range(profile["count"]):
            cases.append(build_case(case_number, difficulty, offset < profile["free"], seen))
            if case_number % 100 == 0:
                print(f"built {case_number} cases", flush=True)
            case_number += 1

    bundle = {
        "bundleSchemaVersion":1,
        "bundleID":"jp.logic.casebook.v1",
        "contentVersion":1,
        "generatedAt":"2026-09-28T00:00:00Z",
        "generatorSeed":SEED,
        "releaseStatus":"editorial_review_required",
        "caseCount":len(cases),
        "cases":cases,
    }
    payload = json.dumps(bundle, ensure_ascii=False, indent=2) + "\n"
    (DATA_DIR / "cases.v1.json").write_text(payload, encoding="utf-8")
    bundle_sha = hashlib.sha256(payload.encode()).hexdigest()
    manifest = {
        "bundleID":bundle["bundleID"],
        "contentVersion":1,
        "caseCount":len(cases),
        "freeCaseCount":sum(c["isFree"] for c in cases),
        "paidCaseCount":sum(not c["isFree"] for c in cases),
        "difficultyCounts":{d:sum(c["difficulty"]==d for c in cases) for d in PROFILES},
        "editorialStatusCounts":{
            "pending_native_review":sum(c["editorialStatus"]=="pending_native_review" for c in cases),
            "approved":sum(c["editorialStatus"]=="approved" for c in cases),
        },
        "structuralSignatureCount":len({c["structuralSignature"] for c in cases}),
        "sha256":bundle_sha,
        "releaseReady":False,
    }
    (DATA_DIR / "manifest.v1.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(manifest, ensure_ascii=False))


if __name__ == "__main__":
    main()
