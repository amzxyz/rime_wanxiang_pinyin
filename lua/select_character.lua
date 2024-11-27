local select = {}

-- 初始化函数
function select.init(env)
    local config = env.engine.schema.config

    -- 从配置中读取按键绑定
    env.first_key = config:get_string('key_binder/select_first_character')
    env.last_key = config:get_string('key_binder/select_last_character')

    -- 确保按键绑定不为空
    if not env.first_key or not env.last_key then
        log.error("select_character 初始化失败: 未找到按键绑定")
        return
    end

    -- 输出日志确认按键绑定
    log.info("select_character 初始化完成: first_key=" .. env.first_key .. ", last_key=" .. env.last_key)
end

-- 主处理函数
function select.func(key, env)
    local engine = env.engine
    local context = env.engine.context

    -- 确保按键绑定存在
    local first_key = env.first_key
    local last_key = env.last_key

    if not first_key or not last_key then
        log.error("未正确初始化按键绑定，跳过处理")
        return 2
    end

    -- 检查是否处于组合状态或有候选项
    if not key:release() and (context:is_composing() or context:has_menu()) then
        local text = context.input
        if context:get_selected_candidate() then
            text = context:get_selected_candidate().text
        end

        -- 检查文本长度是否大于 1
        if utf8.len(text) > 1 then
            if key:repr() == first_key then
                -- 提交第一个字符
                local first_char = text:sub(1, utf8.offset(text, 2) - 1)
                engine:commit_text(first_char)
                context:clear()
                return 1
            elseif key:repr() == last_key then
                -- 提交最后一个字符
                local last_char = text:sub(utf8.offset(text, -1))
                engine:commit_text(last_char)
                context:clear()
                return 1
            end
        end
    end

    return 2
end

return {
    init = select.init,
    func = select.func
}
