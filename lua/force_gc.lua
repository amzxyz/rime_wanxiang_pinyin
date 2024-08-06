-- 暴力 GC
-- 详情 https://github.com/hchunhui/librime-lua/issues/307
-- collectgarbage()：默认调用，等同于 collectgarbage("collect")，触发完整的垃圾回收。
-- collectgarbage("step")：执行垃圾回收的一小步。这个函数会返回一个布尔值，表示这一步是否完成了整个收集周期。
-- 这样也不会导致卡顿，那就每次都调用一下吧，内存稳稳的
local function force_gc()
    -- collectgarbage()
    collectgarbage("step")
end

return force_gc
