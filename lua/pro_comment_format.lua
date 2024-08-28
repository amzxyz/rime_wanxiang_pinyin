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
--  corrector: true                     # 启用错音错词提醒，例如输入 geiyu 给予 获得 jiyu 提示
--  corrector_type: "{comment}"         # 新增一个显示类型，比如"【{comment}】" 

-- #########################
-- # 错音错字提示模块 (Corrector)
-- #########################
local CR = {}
local corrections_cache = nil  -- 用于缓存已加载的词典

-- 加载纠正词典函数
local function load_corrections(file_path)
    if corrections_cache then
        return corrections_cache  -- 如果缓存已存在，直接返回缓存
    end

    local corrections = {}
    local file = io.open(file_path, "r")

    if file then
        for line in file:lines() do
            -- 跳过以 # 开头的行
            if not line:match("^#") then
                -- 使用 = 分隔拼音、文本和注释
                local pinyin, text, comment = line:match("^(.-)=(.-)=(.-)$")
                if pinyin and text and comment then
                    corrections[pinyin] = { text = text, comment = comment }
                end
            end
        end
        file:close()
        corrections_cache = corrections  -- 将加载的数据存入缓存
    end

    return corrections
end

function CR.init(env)
    local config = env.engine.schema.config

    -- 初始化分隔符和格式
    local delimiter = config:get_string('speller/delimiter')
    if delimiter and #delimiter > 0 and delimiter:sub(1, 1) ~= ' ' then
        env.delimiter = delimiter:sub(1, 1)
    end

    env.settings.corrector_type = env.settings.corrector_type:gsub('^*', '')
    CR.style = config:get_string("pro_comment_format/corrector_type") or '{comment}'

    -- 仅在 corrections_cache 为 nil 时加载词典
    if not corrections_cache then
        local corrections_file_path = rime_api.get_user_data_dir() .. "/comments/corrections.txt"
        CR.corrections = load_corrections(corrections_file_path)
    end
end
function CR.run(cand, env)
    -- 确保词典已经被加载
    if not corrections_cache then
        CR.init(env)
    end

    -- 提取拼音段
    local pinyin_segments = {}
    for segment in cand.comment:gmatch("[^%s]+") do
        local pinyin = segment:match("([^;]+)")
        if pinyin and #pinyin > 0 then
            table.insert(pinyin_segments, pinyin)
        end
    end

    -- 将提取的拼音片段用空格连接起来
    local pinyin = table.concat(pinyin_segments, " ")
    if pinyin and #pinyin > 0 then
        if env.delimiter then
            pinyin = pinyin:gsub(env.delimiter, ' ')
        end

        -- 从 corrections_cache 表中查找对应的修正
        local correction = corrections_cache[pinyin]
        if correction and cand.text == correction.text then
            local final_comment = CR.style:gsub("{comment}", correction.comment)
            return final_comment
        end
    end

    return nil
end

-- #########################
-- # 辅助码提示模块 (Fuzhu)
-- #########################

local FZ = {}
local cached_dictionaries = {}  -- 用于缓存已加载的词典

-- 加载词典函数
local function load_dictionary(file_path)
    local dictionary = {}
    local file = io.open(file_path, "r")
    if file then
        for line in file:lines() do
            -- 跳过以 # 开头的行
            if not line:match("^#") then
                -- 匹配格式：字[注释内容]
                local char, comment = line:match("^(.-)%[(.-)%]$")
                if char and comment then
                    dictionary[char] = comment
                end
            end
        end
        file:close()
    end
    return dictionary
end

-- 获取词典（懒加载和缓存）
local function get_dictionary(fuzhu_type)
    -- 如果词典已加载，则直接返回缓存中的词典
    if cached_dictionaries[fuzhu_type] then
        return cached_dictionaries[fuzhu_type]
    end

    -- 如果词典未加载，则从文件加载
    local dictionary_file_path = rime_api.get_user_data_dir() .. "/comments/" .. fuzhu_type .. ".txt"
    local dictionary = load_dictionary(dictionary_file_path)

    -- 如果成功加载词典，则缓存起来
    if dictionary and next(dictionary) then
        cached_dictionaries[fuzhu_type] = dictionary
    end

    return dictionary
end

-- 查找词典中对应的注释内容
local function lookup_comment(dictionary, char)
    return dictionary[char] or ""
end

-- 分解候选词为单个字符列表
local function split_word(word)
    local characters = {}
    for uchar in string.gmatch(word, ".[\128-\191]*") do
        table.insert(characters, uchar)
    end
    return characters
end

function FZ.run(cand, env)
    local length = utf8.len(cand.text)
    local final_comment = ""

    -- 定义外部 fuzhu_type 类型
    local external_fuzhu_type = {
        moqi_chaifen = true,
        zrm_chaifen = true,
    }

    -- 定义内置 fuzhu_type 类型
    local dict_fuzhu_tape = {
        moqi = true,
        flypy = true,
        zrm = true,
        jdh = true,
        cj = true,
        tiger = true,
        wubi = true,
    }

    -- 检查候选词长度和辅助码设置
    if env.settings.fuzhu_code_enabled and length <= env.settings.candidate_length then
        local fuzhu_comments = {}

        -- 外部词典逻辑
        if external_fuzhu_type[env.settings.fuzhu_type] then
            local dictionary = get_dictionary(env.settings.fuzhu_type)  -- 获取词典

            if dictionary then
                -- 分解候选词并查找注释
                local characters = split_word(cand.text)
                for _, char in ipairs(characters) do
                    local comment = lookup_comment(dictionary, char)
                    if comment ~= "" then
                        table.insert(fuzhu_comments, comment)
                    end
                end
            end

        -- 内置词典逻辑
        elseif dict_fuzhu_tape[env.settings.fuzhu_type] then
            -- 定义 fuzhu_type 与匹配模式的映射表
            local patterns = {
                moqi = "[^;]*;([^;]*);",
                flypy = "[^;]*;[^;]*;([^;]*);",
                zrm = "[^;]*;[^;]*;[^;]*;([^;]*);",
                jdh = "[^;]*;[^;]*;[^;]*;[^;]*;([^;]*);",
                cj = "[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;([^;]*);",
                tiger = "[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;([^;]*);",
                wubi = "[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;([^;]*);"
            }

            local pattern = patterns[env.settings.fuzhu_type]
            if pattern then
                local match = cand.comment:match(pattern)
                if match then
                    table.insert(fuzhu_comments, match)
                end
            end
        else
            return ""
        end

        -- 合并所有提取的注释片段
        if #fuzhu_comments > 0 then
            final_comment = table.concat(fuzhu_comments, "/")
        end
    end

    return final_comment
end
-- #########################
-- 主函数：根据优先级处理候选词的注释
-- #########################
local C = {}
function C.init(env)
    local config = env.engine.schema.config

    -- 获取 pro_comment_format 配置项
    env.settings = {
        corrector_enabled = config:get_bool("pro_comment_format/corrector") or ture,  -- 错音错词提醒功能
        corrector_type = config:get_string("pro_comment_format/corrector_type") or "{comment}",  -- 提示类型
        fuzhu_code_enabled = config:get_bool("pro_comment_format/fuzhu_code") or false,  -- 辅助码提醒功能
        candidate_length = tonumber(config:get_string("pro_comment_format/candidate_length")) or 1,  -- 候选词长度
        fuzhu_type = config:get_string("pro_comment_format/fuzhu_type") or ""  -- 辅助码类型
    }

    -- 检查开关状态
    local is_fuzhu_enabled = env.engine.context:get_option("fuzhu_type_switch")
    
    -- 根据开关状态设置辅助码功能
    if is_fuzhu_enabled then
        env.settings.fuzhu_code_enabled = true
    else
        env.settings.fuzhu_code_enabled = false
    end
end
function C.func(input, env)
    -- 调用全局初始共享环境
    C.init(env)
    CR.init(env)

    local processed_candidates = {}  -- 用于存储处理后的候选词

    -- 遍历输入的候选词
    for cand in input:iter() do
        local initial_comment = cand.comment  -- 保存候选词的初始注释
        local final_comment = initial_comment  -- 初始化最终注释为初始注释

        -- 处理辅助码提示
        if env.settings.fuzhu_code_enabled then
            local fz_comment = FZ.run(cand, env, initial_comment)
            if fz_comment then
                final_comment = fz_comment
            end
        else
            -- 如果辅助码显示被关闭，则清空注释
            final_comment = ""
        end

        -- 处理错词提醒
        if env.settings.corrector_enabled then
            local cr_comment = CR.run(cand, env, initial_comment)
            if cr_comment then
                final_comment = cr_comment
            end
        end

        -- 更新最终注释
        if final_comment ~= initial_comment then
            cand:get_genuine().comment = final_comment
        end

        table.insert(processed_candidates, cand)  -- 存储其他候选词
    end

    -- 输出处理后的候选词
    for _, cand in ipairs(processed_candidates) do
        yield(cand)
    end
end
return {
    CR = CR,
    FZ = FZ,
    C = C,
    func = C.func
}
