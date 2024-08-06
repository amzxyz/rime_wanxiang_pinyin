--[[
	匹配自然码双拼带辅助码的错音错字提示，本脚本与词库格式与comment_format表达式强相关。
--]]

local M = {}

function M.init(env)
    local config = env.engine.schema.config
    local delimiter = config:get_string('speller/delimiter')
    if delimiter and #delimiter > 0 and delimiter:sub(1,1) ~= ' ' then
        env.delimiter = delimiter:sub(1,1)
    end
    env.name_space = env.name_space:gsub('^*', '')
    M.style = config:get_string(env.name_space) or '{comment}'
    M.corrections = {
        -- 错音
        -- 错音
        ["hp dp"] = { text = "馄饨", comment = "hún tun" },
        ["vu jc"] = { text = "主角", comment = "zhǔ jué" },
        ["jc se"] = { text = "角色", comment = "júe sè" },
        ["pi sa"] = { text = "比萨", comment = "bǐ sà" },
        ["ii pi sa"] = { text = "吃比萨", comment = "chī bǐ sà" },
        ["pi sa bn"] = { text = "比萨饼", comment = "bǐ sà bǐng" },
        ["uv fu"] = { text = "说服", comment = "shuō fú" },
        ["dk hh"] = { text = "道行", comment = "dào héng" },
        ["mo yh"] = { text = "模样", comment = "mú yàng" },
        ["yb mo yb yh"] = { text = "有模有样", comment = "yǒu mú yǒu yàng" },
        ["yi mo yi yb"] = { text = "一模一样", comment = "yī mú yī yàng" },
        ["vd mo zo yh"] = { text = "装模作样", comment = "zhuāng mú zuò yàng" },
        ["rf mo gb yh"] = { text = "人模狗样", comment = "rén mú góu yàng" },
        ["mo bj"] = { text = "模板", comment = "mú bǎn" },
        ["aa mi to fo"] = { text = "阿弥陀佛", comment = "ē mí tuó fó" },
        ["na mo aa mi to fo"] = { text = "南无阿弥陀佛", comment = "nā mó ē mí tuó fó" },
        ["nj wu aa mi to fo"] = { text = "南无阿弥陀佛", comment = "nā mó ē mí tuó fó" },
        ["nj wu ee mi to fo"] = { text = "南无阿弥陀佛", comment = "nā mó ē mí tuó fó" },
        ["gz yu"] = { text = "给予", comment = "jǐ yǔ" },
        ["bn lh"] = { text = "槟榔", comment = "bīng láng" },
        ["vh bl vi"] = { text = "张柏芝", comment = "zhāng bó zhī" },
        ["tg mj"] = { text = "藤蔓", comment = "téng wàn" },
        ["ns th"] = { text = "弄堂", comment = "lòng táng" },
        ["xn kr ti ph"] = { text = "心宽体胖", comment = "xīn kūan tǐ pán" },
        ["ml yr"] = { text = "埋怨", comment = "mán yuàn" },
        ["xu yu wz ue"] = { text = "虚与委蛇", comment = "xū yǔ wēi yí" },
        ["mu na"] = { text = "木讷", comment = "mù nè" },
        ["du le le"] = { text = "独乐乐", comment = "dú yuè lè" },
        ["vr le le"] = { text = "众乐乐", comment = "zhòng yuè lè" },
        ["xp ma"] = { text = "荨麻", comment = "qián má" },
        ["qm ma vf"] = { text = "荨麻疹", comment = "xún má zhěn" },
        ["mo ju"] = { text = "模具", comment = "mú jù" },
        ["ck vi"] = { text = "草薙", comment = "cǎo tì" },
        ["ck vi jy"] = { text = "草薙京", comment = "cǎo tì jīng" },
        ["ck vi jm"] = { text = "草薙剑", comment = "cǎo tì jiàn" },
        ["jw py ao"] = { text = "贾平凹", comment = "jià píng wā" },
        ["xt fo lj"] = { text = "雪佛兰", comment = "xuě fú lán" },
        ["qd jn"] = { text = "强劲", comment = "qiáng jìng" },
        ["ts ti"] = { text = "胴体", comment = "dòng tǐ" },
        ["li ng kh dy"] = { text = "力能扛鼎", comment = "lì néng gāng dǐng" },
        ["ya lv jd"] = { text = "鸭绿江", comment = "yā lù jiāng" },
        ["da fu bm bm"] = { text = "大腹便便", comment = "dà fù pián pián" },
        ["ka bo zi"] = { text = "卡脖子", comment = "qiǎ bó zi" },
        ["vi vg"] = { text = "吱声", comment = "zī shēng" },
        ["ij he"] = { text = "掺和", comment = "chān huo" },
        ["ij ho"] = { text = "掺和", comment = "chān huo" },
        ["ij he"] = { text = "掺和", comment = "chān huo" },
        ["vg vi"] = { text = "称职", comment = "chèn zhí" },
        ["lo vi ff"] = { text = "螺蛳粉", comment = "luó sī fěn" },
        ["tc hr"] = { text = "调换", comment = "diào huàn" },
        ["tk xy vj"] = { text = "太行山", comment = "tài háng shān" },
        ["jx si di li"] = { text = "歇斯底里", comment = "xiē sī dǐ lǐ" },
        ["nr he"] = { text = "暖和", comment = "nuǎn huo" },
        ["mo ly ld ke"] = { text = "模棱两可", comment = "mó léng liǎng kě" },
        ["pj yh hu"] = { text = "鄱阳湖", comment = "pó yáng hú" },
        ["bo jy"] = { text = "脖颈", comment = "bó gěng" },
        ["bo jy er"] = { text = "脖颈儿", comment = "bó gěng er" },
        ["jx va"] = { text = "结扎", comment = "jié zā" },
        ["hl uf wz"] = { text = "海参崴", comment = "hǎi shēn wǎi" },
        ["hb pu"] = { text = "厚朴", comment = "hòu pò " },
        ["da wj ma"] = { text = "大宛马", comment = "dà yuān mǎ" },
        ["ci ya"] = { text = "龇牙", comment = "zī yá" },
        ["ci ve ya"] = { text = "龇着牙", comment = "zī zhe yá" },
        ["ci ya lx zv"] = { text = "龇牙咧嘴", comment = "zī yá liě zuǐ" },
        ["tb pi xt"] = { text = "头皮屑", comment = "tóu pi xiè" },
        ["lw an ui"] = { text = "六安市", comment = "lù ān shì" },
        ["lw an xm"] = { text = "六安县", comment = "lù ān xiàn" },
        ["an hv ug lq an ui"] = { text = "安徽省六安市", comment = "ān huī shěng lù ān shì" },
        ["an hv lq an"] = { text = "安徽六安", comment = "ān huī lù ān" },
        ["an hv lq an ui"] = { text = "安徽六安市", comment = "ān huī lù ān shì" },
        ["nj jy lq he"] = { text = "南京六合", comment = "nán jīng lù hé" },
        ["nj jy ui lq he"] = { text = "南京六合区", comment = "nán jīng lù hé qū" },
        ["nj jy ui lq he qu"] = { text = "南京市六合区", comment = "nán jīng shì lù hé qū" },
        -- 错字
        ["pu jx"] = { text = "扑街", comment = "仆街" },
        ["pu gl"] = { text = "扑街", comment = "仆街" },
        ["pu jx zl"] = { text = "扑街仔", comment = "仆街仔" },
        ["pu gl zl"] = { text = "扑街仔", comment = "仆街仔" },
        ["cg jn"] = { text = "曾今", comment = "曾经" },
        ["an nl"] = { text = "按耐", comment = "按捺(nà)" },
        ["an nl bu vu"] = { text = "按耐不住", comment = "按捺(nà)不住" },
        ["bx jx"] = { text = "别介", comment = "别价(jie)" },
        ["bg jx"] = { text = "甭介", comment = "甭价(jie)" },
        ["xt ml pf vh"] = { text = "血脉喷张", comment = "血脉贲(bēn)张 | 血脉偾(fèn)张" },
        ["qi ke fu"] = { text = "契科夫", comment = "契诃(hē)夫" },
        ["vk ia"] = { text = "找茬", comment = "找碴" },
        ["vk ia er"] = { text = "找茬儿", comment = "找碴儿" },
        ["da jw ll vk va"] = { text = "大家来找茬", comment = "大家来找碴" },
        ["da jw ll vk ia er"] = { text = "大家来找茬儿", comment = "大家来找碴儿" },
        ["cb ho"] = { text = "凑活", comment = "凑合(he)" },
        ["ju hv"] = { text = "钜惠", comment = "巨惠" },
        ["mo xx zo"] = { text = "魔蝎座", comment = "摩羯(jié)座" },
        ["no da"] = { text = "诺大", comment = "偌(ruò)大" },
    }
end

function M.func(input, env)
    for cand in input:iter() do
        -- cand.comment 是目前输入的词汇的完整拼音
        local pinyin = cand.comment:match("^［(.-)］$")
        if pinyin and #pinyin > 0 then
            if env.delimiter then
                pinyin = pinyin:gsub(env.delimiter,' ')
            end
            local c = M.corrections[pinyin]
            if c and cand.text == c.text then
                cand:get_genuine().comment = string.gsub(M.style, "{comment}", c.comment)
            else
                cand:get_genuine().comment = ""
            end
        end
        yield(cand)
    end
end

return M
