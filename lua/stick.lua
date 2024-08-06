-- 配合简码词库将编码类型为(安装包 avb/ )，遇到这类词库1-3码简码时Tab上屏词 置顶到第一候选词的注释中，无基础候选词时将检索到的词典内容显示为第一候选词，不受词频影响
-- 增加在快捷词汇后面显示闪电符号来表示快速输入字符、也可以理解为来自简码词库，配合方案快捷设置，闪电出现时按下Tab可以上屏。
-- @gaboolic @amzxyz
local M = {}

function M.init(env)
    -- 初始化逻辑，加载固定词典等
    local config = env.engine.schema.config
    env.name_space = env.name_space:gsub("^*", "")
    env.fixed = {}
    M.count = config:get_int(env.name_space .. "/count") or 2  -- 获取配置中的 count 参数，默认值为 2
    M.idx = config:get_int(env.name_space .. "/idx") or 4  -- 获取配置中的 idx 参数，默认值为 4
    M.input_str = env.engine.context.input  -- 获取当前输入的字符串

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
            log.info("stick path not file")
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

function M.func(input, env)
    local first_cand = nil
    local found = false

    -- 遍历输入的候选词
    for cand in input:iter() do
        if not first_cand then
            first_cand = cand
            local preedit_str = cand.preedit
            if utf8.len(preedit_str) <= 3 and isAllLetters(preedit_str) then
                local stick_phrase = env.fixed[preedit_str] or ""
                if stick_phrase ~= "" and first_cand.text ~= stick_phrase then
                    -- first_cand.comment = stick_phrase .. "⚡"  -- 在注释后面加上闪电符号，表示快速输入，不想要置空
                    first_cand.comment = stick_phrase
                end
                yield(first_cand)
                found = true
            end
        end
        yield(cand)
        found = true
    end

    -- 如果没有找到匹配的候选词，显示固定词典内容作为第一候选词
    if not found then
        local preedit_str = env.engine.context.input
        local stick_phrase = env.fixed[preedit_str] or ""
        if stick_phrase ~= "" then
            yield(create_candidate(stick_phrase, "⚡"))  -- 在注释中加上闪电符号，表示快速输入，不想要置空
        end
    end
end

return M