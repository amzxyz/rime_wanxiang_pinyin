-- doing 末码为/时，候选项如果唯一，则自动上屏
-- @gaboolic


local M = {}

-- function M.init(env)
--     M.input_str = env.engine.context.input
-- end


-- input Translation 对象，为待过滤的 Candidate 流。注意：此 input 并非 Rime 源代码中的 (raw) input
-- env lua table 对象。预设 engine 和 name_space 两个成员，分别是 Engine 对象和前述 name_space 配置字符串。
function M.func(input,env,cands)
    log.info("slach_pop M.func")
    local context = env.engine.context
    -- lua文档 https://github.com/hchunhui/librime-lua/wiki/Scripting
    if env.engine.context.input == 'uiui/' or env.engine.context.input == 'zssr/' then
        log.info("进入/顶屏模式")
        local candLength = 0
        local l = {}
        local text = {}
        for cand in input:iter() do
            candLength = candLength + 1
            text = cand.text
            log.info(text)
        end
        log.info(candLength)
        log.info(text)
        if candLength == 1 then
            env.engine:commit_text(text)
        end

        -- yield l 及后续的候选项
        for _, cand in ipairs(l) do
            yield(cand)
        end
        log.info("done")
    end

    for cand in input:iter() do
        yield(cand)
    end
end

return M
