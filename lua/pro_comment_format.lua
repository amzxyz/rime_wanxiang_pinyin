--@amzxyz https://github.com/amzxyz/rime_wanxiang_pinyin
--由于comment_format不管你的表达式怎么写，只能获得一类输出，导致的结果只能用于一个功能类别
--如果依赖lua_filter载入多个lua也只能实现一些单一的、不依赖原始注释的功能，有的时候不可避免的发生一些逻辑冲突
--所以此脚本专门为了协调各式需求，逻辑优化，实现参数自定义，功能可开关，相关的配置跟着方案文件走，如下所示：
--将如下相关位置完全暴露出来，注释掉其它相关参数--
--  comment_format: {comment}   #将注释以词典字符串形式完全暴露，通过pro_comment_format.lua完全接管。
--  spelling_hints: 10          # 将注释以词典字符串形式完全暴露，通过pro_comment_format.lua完全接管。
--在方案文件顶层置入如下设置--
--#Lua 配置: 超级注释模块
--pro_comment_format:                   # 超级注释，子项配置 true 开启，false 关闭
--  fuzhu_code: true                    # 启用辅助码提醒，用于辅助输入练习辅助码，成熟后可关闭
--  candidate_length: 3                 # 候选词辅助码提醒的生效长度，0为关闭  但同时清空其它，应当使用上面开关来处理    
--  fuzhu_type: zrm                     # 用于匹配对应的辅助码注释显示，可选显示类型有：moqi, flypy, zrm, jdh, cj, tiger, wubi,选择一个填入，应与上面辅助码类型一致
--
--  jiancode_priority: false             # 简码前置：开启即查询 1-3 简码的词库回显到第一个候选词的注释里，可配合快捷键设置上屏       
--  jiancode_identifier: "{identifier}⚡" #回显样式定义：假设值为 "*{identifier}*", 然后注释会被生成为 "*注释*" 的形式。如果值为 "⚡", 则注释会显示为 "注释⚡"，清空⚡也是默认值
--
--  corrector: true                     # 启用错音错词提醒，例如输入 geiyu 给予 获得 jiyu 提示
--  corrector_type: "{comment}"         # 新增一个显示类型，比如"【{comment}】" 

-- #########################
-- # 错音错字提示模块 (Corrector)
-- #########################
local CR = {}
function CR.init(env)
    local config = env.engine.schema.config
    local delimiter = config:get_string('speller/delimiter')
    if delimiter and #delimiter > 0 and delimiter:sub(1,1) ~= ' ' then
        env.delimiter = delimiter:sub(1,1)
    end
    env.settings.corrector_type = env.settings.corrector_type:gsub('^*', '')
    CR.style = config:get_string("pro_comment_format/corrector_type") or '{comment}'
    CR.corrections = {
        -- 错音
        ["hun dun"] = { text = "馄饨", comment = "hún tun" },
        ["zhu jiao"] = { text = "主角", comment = "zhǔ jué" },
        ["jiao se"] = { text = "角色", comment = "júe sè" },
        ["chi pi sa"] = { text = "吃比萨", comment = "chī bǐ sà" },
        ["pi sa bing"] = { text = "比萨饼", comment = "bǐ sà bǐng" },
        ["shui fu"] = { text = "说服", comment = "shuō fú" },
        ["dao hang"] = { text = "道行", comment = "dào héng" },
        ["mo yang"] = { text = "模样", comment = "mú yàng" },
        ["you mo you yang"] = { text = "有模有样", comment = "yǒu mú yǒu yàng" },
        ["yi mo yi yang"] = { text = "一模一样", comment = "yī mú yī yàng" },
        ["zhuang mo zuo yang"] = { text = "装模作样", comment = "zhuāng mú zuò yàng" },
        ["ren mo gou yang"] = { text = "人模狗样", comment = "rén mú góu yàng" },
        ["mo ban"] = { text = "模板", comment = "mú bǎn" },
        ["a mi tuo fo"] = { text = "阿弥陀佛", comment = "ē mí tuó fó" },
        ["na mo a mi tuo fo"] = { text = "南无阿弥陀佛", comment = "nā mó ē mí tuó fó" },
        ["nan wu a mi tuo fo"] = { text = "南无阿弥陀佛", comment = "nā mó ē mí tuó fó" },
        ["nan wu e mi tuo fo"] = { text = "南无阿弥陀佛", comment = "nā mó ē mí tuó fó" },
        ["gei yu"] = { text = "给予", comment = "jǐ yǔ" },
        ["bin lang"] = { text = "槟榔", comment = "bīng láng" },
        ["zhang bai zhi"] = { text = "张柏芝", comment = "zhāng bó zhī" },
        ["teng man"] = { text = "藤蔓", comment = "téng wàn" },
        ["nong tang"] = { text = "弄堂", comment = "lòng táng" },
        ["xin kuan ti pang"] = { text = "心宽体胖", comment = "xīn kūan tǐ pán" },
        ["mai yuan"] = { text = "埋怨", comment = "mán yuàn" },
        ["xu yu wei she"] = { text = "虚与委蛇", comment = "xū yǔ wēi yí" },
        ["mu na"] = { text = "木讷", comment = "mù nè" },
        ["du le le"] = { text = "独乐乐", comment = "dú yuè lè" },
        ["zhong le le"] = { text = "众乐乐", comment = "zhòng yuè lè" },
        ["xun ma"] = { text = "荨麻", comment = "qián má" },
        ["qian ma zhen"] = { text = "荨麻疹", comment = "xún má zhěn" },
        ["mo ju"] = { text = "模具", comment = "mú jù" },
        ["cao zhi"] = { text = "草薙", comment = "cǎo tì" },
        ["cao zhi jing"] = { text = "草薙京", comment = "cǎo tì jīng" },
        ["cao zhi jian"] = { text = "草薙剑", comment = "cǎo tì jiàn" },
        ["jia ping ao"] = { text = "贾平凹", comment = "jià píng wā" },
        ["xue fo lan"] = { text = "雪佛兰", comment = "xuě fú lán" },
        ["qiang jin"] = { text = "强劲", comment = "qiáng jìng" },
        ["tong ti"] = { text = "胴体", comment = "dòng tǐ" },
        ["li neng kang ding"] = { text = "力能扛鼎", comment = "lì néng gāng dǐng" },
        ["ya lv jiang"] = { text = "鸭绿江", comment = "yā lù jiāng" },
        ["da fu bian bian"] = { text = "大腹便便", comment = "dà fù pián pián" },
        ["ka bo zi"] = { text = "卡脖子", comment = "qiǎ bó zi" },
        ["zhi sheng"] = { text = "吱声", comment = "zī shēng" },
        ["chan he"] = { text = "掺和", comment = "chān huo" },
        ["can huo"] = { text = "掺和", comment = "chān huo" },
        ["can he"] = { text = "掺和", comment = "chān huo" },
        ["cheng zhi"] = { text = "称职", comment = "chèn zhí" },
        ["luo shi fen"] = { text = "螺蛳粉", comment = "luó sī fěn" },
        ["tiao huan"] = { text = "调换", comment = "diào huàn" },
        ["tai xing shan"] = { text = "太行山", comment = "tài háng shān" },
        ["jie si di li"] = { text = "歇斯底里", comment = "xiē sī dǐ lǐ" },
        ["nuan he"] = { text = "暖和", comment = "nuǎn huo" },
        ["mo ling liang ke"] = { text = "模棱两可", comment = "mó léng liǎng kě" },
        ["pan yang hu"] = { text = "鄱阳湖", comment = "pó yáng hú" },
        ["bo jing"] = { text = "脖颈", comment = "bó gěng" },
        ["bo jing er"] = { text = "脖颈儿", comment = "bó gěng er" },
        ["jie zha"] = { text = "结扎", comment = "jié zā" },
        ["hai shen wei"] = { text = "海参崴", comment = "hǎi shēn wǎi" },
        ["hou pu"] = { text = "厚朴", comment = "hòu pò " },
        ["da wan ma"] = { text = "大宛马", comment = "dà yuān mǎ" },
        ["ci ya"] = { text = "龇牙", comment = "zī yá" },
        ["ci zhe ya"] = { text = "龇着牙", comment = "zī zhe yá" },
        ["ci ya lie zui"] = { text = "龇牙咧嘴", comment = "zī yá liě zuǐ" },
        ["tou pi xue"] = { text = "头皮屑", comment = "tóu pi xiè" },
        ["liu an shi"] = { text = "六安市", comment = "lù ān shì" },
        ["liu an xian"] = { text = "六安县", comment = "lù ān xiàn" },
        ["an hui sheng liu an shi"] = { text = "安徽省六安市", comment = "ān huī shěng lù ān shì" },
        ["an hui liu an"] = { text = "安徽六安", comment = "ān huī lù ān" },
        ["an hui liu an shi"] = { text = "安徽六安市", comment = "ān huī lù ān shì" },
        ["nan jing liu he"] = { text = "南京六合", comment = "nán jīng lù hé" },
        ["nan jing shi liu he"] = { text = "南京六合区", comment = "nán jīng lù hé qū" },
        ["nan jing shi liu he qu"] = { text = "南京市六合区", comment = "nán jīng shì lù hé qū" },
        ["nuo da"] = { text = "偌大", comment = "偌(ruò)大" },
        ["yin jiu zhi ke"] = { text = "饮鸩止渴", comment = "饮鸩(zhèn)止渴" },
        ["yin jiu jie ke"] = { text = "饮鸩解渴", comment = "饮鸩(zhèn)解渴" },
        ["gong shang jiao zhi yu"] = { text = "宫商角徵羽", comment = "宫商角(jué)徵羽" },
        ["wan bo lin"] = { text = "万柏林", comment = "wàn bǎi lín" },
        -- 错字
        ["pu jie"] = { text = "扑街", comment = "仆街" },
        ["pu gai"] = { text = "扑街", comment = "仆街" },
        ["pu jie zai"] = { text = "扑街仔", comment = "仆街仔" },
        ["pu gai zai"] = { text = "扑街仔", comment = "仆街仔" },
        ["ceng jin"] = { text = "曾今", comment = "曾经" },
        ["an nai"] = { text = "按耐", comment = "按捺(nà)" },
        ["an nai bu zhu"] = { text = "按耐不住", comment = "按捺(nà)不住" },
        ["bie jie"] = { text = "别介", comment = "别价(jie)" },
        ["beng jie"] = { text = "甭介", comment = "甭价(jie)" },
        ["xue mai pen zhang"] = { text = "血脉喷张", comment = "血脉贲(bēn)张 | 血脉偾(fèn)张" },
        ["qi ke fu"] = { text = "契科夫", comment = "契诃(hē)夫" },
        ["zhao cha"] = { text = "找茬", comment = "找碴" },
        ["zhao cha er"] = { text = "找茬儿", comment = "找碴儿" },
        ["da jia lai zhao cha"] = { text = "大家来找茬", comment = "大家来找碴" },
        ["da jia lai zhao cha er"] = { text = "大家来找茬儿", comment = "大家来找碴儿" },
        ["cou huo"] = { text = "凑活", comment = "凑合(he)" },
        ["ju hui"] = { text = "钜惠", comment = "巨惠" },
        ["mo xie zuo"] = { text = "魔蝎座", comment = "摩羯(jié)座" },
        ["pi sa"] = { text = "披萨", comment = "比(bǐ)萨" },
    }
end

function CR.run(cand, env, initial_comment)
    -- 用空格分隔注释中的每个片段
    local pinyin_segments = {}
    for segment in initial_comment:gmatch("[^%s]+") do
        -- 提取每个片段中的第一个分号前的拼音
        local pinyin = segment:match("([^;]+)")
        if pinyin and #pinyin > 0 then
            table.insert(pinyin_segments, pinyin)
        end
    end
    -- 将提取的拼音片段用空格连接起来
    local pinyin = table.concat(pinyin_segments, " ")
    if pinyin and #pinyin > 0 then
        -- 替换自定义的分隔符
        if env.delimiter then
            pinyin = pinyin:gsub(env.delimiter, ' ')
        end
        -- 从 CR.corrections 表中查找对应的修正
        local c = CR.corrections[pinyin]
        if c and cand.text == c.text then
            -- 使用 CR.style 模板构建最终的注释内容
            local final_comment = CR.style:gsub("{comment}", c.comment)
            return final_comment  -- 返回修正后的注释
        end
    end
    return nil  -- 没有修改注释，返回 nil
end
-- #########################
-- # 辅助码提示模块 (Fuzhu)
-- #########################

local FZ = {}

function FZ.init(env)
    -- 初始化逻辑，加载配置文件中的设定
    local config = env.engine.schema.config
end
function FZ.run(cand, env, initial_comment)
    local length = utf8.len(cand.text)
    local final_comment = nil

    -- 确保候选词长度检查使用从配置中读取的值
    if env.settings.fuzhu_code_enabled and length <= env.settings.candidate_length then
        local fuzhu_comments = {}

        -- 先用空格将注释分成多个片段
        local segments = {}
        for segment in initial_comment:gmatch("[^%s]+") do
            table.insert(segments, segment)
        end

        -- 根据 fuzhu_type 选择处理逻辑
        if env.settings.fuzhu_type == "moqi" then
            -- 提取每个片段的第一个分号到第二个分号之间的内容
            for _, segment in ipairs(segments) do
                local match = segment:match("[^;]*;([^;]*);")
                if match then
                    table.insert(fuzhu_comments, match)
                end
            end
        elseif env.settings.fuzhu_type == "flypy" then
            -- 提取每个片段的第二个分号到第三个分号之间的内容
            for _, segment in ipairs(segments) do
                local match = segment:match("[^;]*;[^;]*;([^;]*);")
                if match then
                    table.insert(fuzhu_comments, match)
                end
            end
        elseif env.settings.fuzhu_type == "zrm" then
            -- 提取每个片段的第三个分号到第四个分号之间的内容
            for _, segment in ipairs(segments) do
                local match = segment:match("[^;]*;[^;]*;[^;]*;([^;]*);")
                if match then
                    table.insert(fuzhu_comments, match)
                end
            end
        elseif env.settings.fuzhu_type == "jdh" then
            -- 提取每个片段的第四个分号到第五个分号之间的内容
            for _, segment in ipairs(segments) do
                local match = segment:match("[^;]*;[^;]*;[^;]*;[^;]*;([^;]*);")
                if match then
                    table.insert(fuzhu_comments, match)
                end
            end
        elseif env.settings.fuzhu_type == "cj" then
            -- 提取每个片段的第五个分号到第六个分号之间的内容
            for _, segment in ipairs(segments) do
                local match = segment:match("[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;([^;]*);")
                if match then
                    table.insert(fuzhu_comments, match)
                end
            end
        elseif env.settings.fuzhu_type == "tager" then
            -- 提取每个片段的第六个分号到第七个分号之间的内容
            for _, segment in ipairs(segments) do
                local match = segment:match("[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;([^;]*);")
                if match then
                    table.insert(fuzhu_comments, match)
                end
            end
        elseif env.settings.fuzhu_type == "wubi" then
            -- 提取每个片段的第七个分号到第八个分号之间的内容
            for _, segment in ipairs(segments) do
                local match = segment:match("[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;([^;]*);")
                if match then
                    table.insert(fuzhu_comments, match)
                end
            end
        else
            -- 如果类型不匹配，返回空字符串
            return ""
        end
        -- 将提取的拼音片段用空格连接起来
        if #fuzhu_comments > 0 then
            final_comment = table.concat(fuzhu_comments, "/")
        end
    else
        -- 如果候选词长度超过指定值，返回空字符串
        final_comment = ""
    end

    return final_comment or ""  -- 确保返回最终值
end
-- #########################
-- 主函数：根据优先级处理候选词的注释
-- #########################
local C = {}
function C.init(env)
    local config = env.engine.schema.config

    -- 获取 pro_comment_format 配置项
    env.settings = {
        jiancode_priority = config:get_bool("pro_comment_format/jiancode_priority") or false,  -- 简码前置功能
        jiancode_identifier = config:get_string("pro_comment_format/jiancode_identifier") or "⚡",  -- 简码标识符
        corrector_enabled = config:get_bool("pro_comment_format/corrector") or false,  -- 错音错词提醒功能
        corrector_type = config:get_string("pro_comment_format/corrector_type") or "{comment}",  -- 提示类型
        fuzhu_code_enabled = config:get_bool("pro_comment_format/fuzhu_code") or false,  -- 辅助码提醒功能
        candidate_length = tonumber(config:get_string("pro_comment_format/candidate_length")) or 1,  -- 候选词长度
        fuzhu_type = config:get_string("pro_comment_format/fuzhu_code/fuzhu_type") or "zrm"  -- 辅助码类型
    }
-- #########################
-- 一起初始化简码前置
-- #########################
    env.fixed = {}
    env.name_space = env.name_space:gsub("^*", "")
    C.input_str = env.engine.context.input  -- 获取当前输入的字符串
    -- 定义固定词典文件的路径
    local paths = {
        rime_api.get_user_data_dir() .. "/jm_dicts/custom_phrase_super_1jian.txt",
        rime_api.get_user_data_dir() .. "/jm_dicts/custom_phrase_super_2jian.txt",
        rime_api.get_user_data_dir() .. "/jm_dicts/custom_phrase_super_3jian.txt"
    }
    -- 遍历每个路径，加载固定词典
    for _, path in ipairs(paths) do
        local file = io.open(path, "r")
        if not file then
            return
        end
        -- 逐行读取文件内容
        for line in file:lines() do
            if string.sub(line, 1, 1) == "#" then
                goto continue
            end
            -- 匹配编码和词条内容
            local code, content = line:match("([^\t]+)\t([^\t]+)")
            if content and code then
                content = string.sub(content, 1, -2)  -- 去除词条内容末尾的换行符
                env.fixed[content] = code  -- 将编码和词条内容存储到 env.fixed 表中
            end
            ::continue::
        end
        file:close()  -- 关闭文件
    end 
end 
-- 检查字符串是否全为字母
local function isAllLetters(str)
    return not (string.find(str, "[^%a]"))
end

-- 创建候选词
local function create_candidate(text, comment)
    return Candidate("word", 0, string.len(text), text, comment)
end
function C.func(input, env)
    -- 调用全局初始共享环境
    C.init(env)
    CR.init(env)
    FZ.init(env)

    local first_cand = nil           -- 用于简码前置存储第一候选词
    local found = false              -- 用于简码前置的有无候选词判断
    local processed_candidates = {}  -- 用于存储进一步处理后的候选词

    -- 遍历输入的候选词
    for cand in input:iter() do
        -- 对候选词进行进一步处理（辅助码提示和错词提醒）
        local initial_comment = cand.comment  -- 保存候选词的初始注释
        local final_comment = initial_comment  -- 初始化最终注释为初始注释
        -- 1. 辅助码提示模块处理（适用于所有候选词）
        if env.settings.fuzhu_code_enabled then
            local fz_comment = FZ.run(cand, env, initial_comment)
            if fz_comment then
                final_comment = fz_comment  -- 更新最终注释为辅助码提示的结果
            end
        else
            -- 如果辅助码显示被关闭，则清空注释
            final_comment = ""
        end
        -- 2. 错词提醒模块处理（适用于所有候选词）
        if env.settings.corrector_enabled then
            local cr_comment = CR.run(cand, env, initial_comment)
            if cr_comment then
                final_comment = cr_comment  -- 更新最终注释为错词提醒的结果
            end
        end
        -- 应用最终注释到候选词
        if final_comment ~= initial_comment then
            cand:get_genuine().comment = final_comment
        end

        table.insert(processed_candidates, cand)  -- 存储进一步处理后的候选词
    end

    -- 存储简码处理的候选词
    local initial_candidates = {}  -- 用于存储简码处理后的候选词
    local identifier = env.settings.jiancode_identifier   -- 使用占位符的逻辑，将 jiancode_identifier 添加到注释中
    local jiancode_identifier            -- 使用占位符的逻辑，将 jiancode_identifier 添加到注释中
    if env.settings.jiancode_priority then 
    -- 遍历所有进一步处理后的候选词
        for _, cand in ipairs(processed_candidates) do
            if not first_cand then
                first_cand = cand
                local preedit_str = cand.preedit
                if utf8.len(preedit_str) <= 3 and isAllLetters(preedit_str) then
                    local jiancode_priority = env.fixed[preedit_str] or ""
                    if jiancode_priority ~= "" and first_cand.text ~= jiancode_priority then              
                        if identifier:find("{identifier}") then
                            jiancode_identifier = identifier:gsub("{identifier}", jiancode_priority)
                        else
                            jiancode_identifier = jiancode_priority .. identifier
                        end
                        first_cand.comment = jiancode_identifier
                    end
                    table.insert(initial_candidates, first_cand)  -- 存储简码处理后的第一个候选词
                    found = true
                else
                    table.insert(initial_candidates, cand)  -- 存储其他候选词
                end
            else
                table.insert(initial_candidates, cand)  -- 存储其他候选词
            end
        end

    -- 如果没有找到匹配的候选词，显示固定词典内容作为第一候选词
        if not found then
            local preedit_str = env.engine.context.input
            local jiancode_priority = env.fixed[preedit_str] or ""
            if jiancode_priority ~= "" then
                if identifier:find("{identifier}") then
                    jiancode_identifier = identifier:gsub("{identifier}", jiancode_priority)
                else
                    jiancode_identifier = jiancode_priority .. identifier
                end
                table.insert(initial_candidates, create_candidate(jiancode_identifier, "")) --这种情况不显示注释了，简码词已经被设置为候选词因此注释为空，而且没有其它候选词因此任何注释都是多余的
            end
        end
    -- 输出简码处理后的候选词
        for _, cand in ipairs(initial_candidates) do
           yield(cand)
        end
    else
        for _, cand in ipairs(processed_candidates) do
           yield(cand)
        end
    end
end

return {
    CR = CR,
    FZ = FZ,
    C = C,
    func = C.func
}