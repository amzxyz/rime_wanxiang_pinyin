local function modify_preedit_filter(input, env)
    -- 获取配置中的分隔符
    local config = env.engine.schema.config
    local delimiter = config:get_string('speller/delimiter') or " '"  -- 默认是两个空格

    -- 初始化开关状态和分隔符
    env.settings = {tone_display = env.engine.context:get_option("tone_display")} or false
    -- 自动分隔符和手动分隔符分别定义
    local auto_delimiter = delimiter:sub(1, 1)
    local manual_delimiter = delimiter:sub(2, 2)

    -- 获取开关状态
    local is_tone_display = env.settings.tone_display
    local context = env.engine.context

    for cand in input:iter() do
        -- 检查输入状态是否符合不执行条件，即进入反查模式
        if context.input:len() == 0 or context.input:find("^az") or context.input:find("^ab") then
            yield(cand)  -- 不执行替换，直接返回原候选
            goto continue  -- 跳过后续处理
        end

        local genuine_cand = cand:get_genuine()
        local preedit = genuine_cand.preedit or ""

        if is_tone_display and #preedit >= 2 then
            if string.find(genuine_cand.text, "%w+") then
                genuine_cand.preedit = genuine_cand.text
            else
                -- 处理 preedit
                local input_parts = {}
                local current_segment = ""

                for i = 1, #preedit do
                    local char = preedit:sub(i, i)
                    if char == auto_delimiter or char == manual_delimiter then
                        if #current_segment > 0 then
                            table.insert(input_parts, current_segment)
                            current_segment = ""
                        end
                        table.insert(input_parts, char)
                    else
                        current_segment = current_segment .. char
                    end
                end

                if #current_segment > 0 then
                    table.insert(input_parts, current_segment)
                end

                -- 提取拼音片段
                local comment = genuine_cand.comment
                if comment then
                    local pinyin_segments = {}
                    for segment in string.gmatch(comment, "[^" .. auto_delimiter .. manual_delimiter .. "]+") do
                        local pinyin = string.match(segment, "^[^;]+")
                        if pinyin then
                            table.insert(pinyin_segments, pinyin)
                        end
                    end

                    local pinyin_index = 1
                    for i, part in ipairs(input_parts) do
                        if part ~= auto_delimiter and part ~= manual_delimiter and pinyin_index <= #pinyin_segments then
                            input_parts[i] = pinyin_segments[pinyin_index]
                            pinyin_index = pinyin_index + 1
                        end
                    end

                    local final_preedit = table.concat(input_parts)
                    genuine_cand.preedit = final_preedit
                else
                    genuine_cand.preedit = genuine_cand.text
                end
            end
        end
        yield(genuine_cand)
        ::continue::
    end
end

return modify_preedit_filter
