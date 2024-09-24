local function modify_preedit_filter(input, env)
    -- 获取配置中的分隔符
    local config = env.engine.schema.config
    local delimiter = config:get_string('speller/delimiter') or " '"  -- 默认是两个空格，确保有自动和手动分隔符

    -- 自动分隔符和手动分隔符分别定义
    local auto_delimiter = delimiter:sub(1, 1)  -- 自动分隔符，默认为空格
    local manual_delimiter = delimiter:sub(2, 2) or "'"  -- 手动分隔符，默认为单引号

    -- 检查开关状态
    local is_tone_display = env.engine.context:get_option("tone_display")

    for cand in input:iter() do
        local genuine_cand = cand:get_genuine()

        -- 获取当前 preedit 中的输入码
        local preedit = genuine_cand.preedit or ""

        -- 只有在开关开启的情况下才执行处理
        if is_tone_display and #preedit >= 2 then
            -- 判断是否为英文候选词
            if string.find(genuine_cand.text, "%w+") then
                -- 如果是英文候选词，保持原始 preedit
                genuine_cand.preedit = genuine_cand.text
            else
                -- 拆分 preedit 为字母和分隔符
                local input_parts = {}
                local current_segment = ""

                -- 遍历 preedit，记录字母部分和分隔符部分
                for i = 1, #preedit do
                    local char = preedit:sub(i, i)
                    if char == auto_delimiter or char == manual_delimiter then
                        -- 记录当前的字母部分并保存分隔符
                        if #current_segment > 0 then
                            table.insert(input_parts, current_segment)
                            current_segment = ""
                        end
                        table.insert(input_parts, char)  -- 保存分隔符
                    else
                        current_segment = current_segment .. char
                    end
                end

                -- 将最后的字母部分加入表中
                if #current_segment > 0 then
                    table.insert(input_parts, current_segment)
                end

                -- 提取注释的拼音片段
                local comment = genuine_cand.comment
                if comment then
                    local pinyin_segments = {}
                    for segment in string.gmatch(comment, "[^" .. auto_delimiter .. manual_delimiter .. "]+") do
                        local pinyin = string.match(segment, "^[^;]+")
                        if pinyin then
                            table.insert(pinyin_segments, pinyin)
                        end
                    end

                    -- 替换 preedit 中的字母部分为注释的拼音片段
                    local pinyin_index = 1
                    for i, part in ipairs(input_parts) do
                        -- 只替换非分隔符的部分
                        if part ~= auto_delimiter and part ~= manual_delimiter and pinyin_index <= #pinyin_segments then
                            input_parts[i] = pinyin_segments[pinyin_index]  -- 替换拼音片段
                            pinyin_index = pinyin_index + 1
                        end
                    end

                    -- 重新组合 preedit 的字母和分隔符
                    local final_preedit = table.concat(input_parts)

                    -- 更新 preedit 显示
                    genuine_cand.preedit = final_preedit
                else
                    -- 如果没有注释，保持原始显示
                    genuine_cand.preedit = genuine_cand.text
                end
            end
        end

        -- 返回候选词
        yield(genuine_cand)
    end
end

return modify_preedit_filter
