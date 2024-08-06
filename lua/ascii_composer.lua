-- 中英混输处理器
-- 通用（不包含声笔系列码的特殊逻辑）
-- 本处理器实现了 Shift+Enter 反转首字母大小写、Control+Enter 反转编码大小写等功能

local XK_Return = 0xff0d
local XK_Tab = 0xff09
local XK_Escape = 0xff1b
local rime = require "sbxlm.lib"
local core = require "sbxlm.core"

local this = {}

---@class AsciiComposerEnv: Env
---@field ascii_composer Processor
---@field connection Connection

---@param env AsciiComposerEnv
function this.init(env)
  env.ascii_composer = rime.Processor(env.engine, "", "ascii_composer")
end

---@param ch number
local function is_upper(ch)
  -- ch >= 'A' and ch <= 'Z'
  return ch >= 0x41 and ch <= 0x5a
end

---@param context Context
---@param env AsciiComposerEnv
local function switch_inline(context, env)
  context:set_option("ascii_mode", true)
  env.connection = context.update_notifier:connect(function(ctx)
    if not ctx:is_composing() then
      env.connection:disconnect()
      ctx:set_option("ascii_mode", false)
    end
  end)
end

---@param key_event KeyEvent
---@param env AsciiComposerEnv
function this.func(key_event, env)
  local context = env.engine.context
  local input = context.input
  local ascii_mode = context:get_option("ascii_mode")
  local auto_inline = context:get_option("auto_inline")

  -- auto_inline 启用时，首字母大写时自动切换到内联模式
  if (not ascii_mode and auto_inline and input:len() == 0 and is_upper(key_event.keycode)) then
    if (key_event:shift() and key_event:ctrl()) or key_event:alt() or key_event:super() then
      return rime.process_results.kNoop
    end
    context:push_input(string.char(key_event.keycode))
    switch_inline(context, env)
    -- hack，随便发一个没用的键让 ascii_composer 忘掉之前的 shift
    env.engine:process_key(rime.KeyEvent("Release+A"))
    return rime.process_results.kAccepted
  end

  -- 首字母后的 Tab 键切换到临时英文，Shift+Tab 键切换到缓冲模式
  local segment = env.engine.context.composition:back()
  if (not ascii_mode and segment and not segment:has_tag("punct") and input:len() == 1
      and key_event.keycode == XK_Tab and not key_event:release()) then
        if key_event:shift() then
          if not context:get_option("is_buffered") then
            context:set_option("is_buffered", true)
          end
          context:set_option("temp_buffered", true)
        else
          switch_inline(context, env)
        end
        return rime.process_results.kAccepted
  -- 在码长为4以上时，设置临时重码提示
  elseif (not ascii_mode and segment and segment:has_tag("abc") and input:len() >= 4 and input:len() <= 5
      and key_event.keycode == XK_Tab and not key_event:release()) then
        if context:get_option("single_display") and not context:get_option("not_single_display") then
          context:set_option("not_single_display", true)
        end
        return rime.process_results.kNoop
  -- 声笔简码在码长5以上时，单引号进入打空造词
  elseif (not ascii_mode and segment and segment:has_tag("abc") and segment.length >= 5
      and key_event.keycode == string.byte("'") and not key_event:release()
      and core.jm(env.engine.schema.schema_id)) then
        local diff = 0
        if segment.length == 6 then diff = 1 end
        context:pop_input(segment.length - 4)
        context.caret_pos = segment.start + 1
        context:push_input(input:sub(input:len() - diff, -1))
        return rime.process_results.kAccepted
  -- 声笔双拼在码长5以上时，单引号进入打空造词
  elseif (not ascii_mode and segment and segment:has_tag("abc") and segment.length >= 5
      and key_event.keycode == string.byte("'") and not key_event:release()
      and core.sp(env.engine.schema.schema_id)) then
        local diff = 0
        if segment.length == 6 then diff = 1 end
        context:pop_input(segment.length - 4)
        context.caret_pos = segment.start + 2
        context:push_input(input:sub(input:len() - diff, -1))
        return rime.process_results.kAccepted
  -- 声笔飞码在码长5以上时，单引号进入打空造词，但丢弃已经追加的笔画
  elseif (not ascii_mode and segment and segment:has_tag("abc") and segment.length >= 5
      and key_event.keycode == string.byte("'") and not key_event:release()
      and core.fm(env.engine.schema.schema_id)) then
        local diff = 0
        if segment.length == 6 then diff = 1 end
        context:pop_input(segment.length - 4)
        context.caret_pos = segment.start + 2
        return rime.process_results.kAccepted
  end
  -- 在码长为1时，取消临时重码提示
  if not ascii_mode and segment and segment:has_tag("abc") 
      and input:len() == 1 and context:get_option("single_display") then
    context:set_option("not_single_display", false)
  end

  if input:len() == 0 then
    return rime.process_results.kNoop
  end

  -- 用 Shift+Return 或者 Control+Return 反转大小写
  if key_event.modifier == rime.modifier_masks.kShift and key_event.keycode == XK_Return then
    if is_upper(input:byte(1)) then
      env.engine:commit_text(input:sub(1, 1):lower() .. input:sub(2))
    else
      env.engine:commit_text(input:sub(1, 1):upper() .. input:sub(2))
    end
    context:clear()
    return rime.process_results.kAccepted
  end
  if key_event.modifier == rime.modifier_masks.kControl and key_event.keycode == XK_Return then
    env.engine:commit_text(input:upper())
    context:clear()
    return rime.process_results.kAccepted
  end

  -- Esc 键取消输入
  if key_event.keycode == XK_Escape then
    context:clear()
    return rime.process_results.kAccepted
  end
  return rime.process_results.kNoop
end

return this
