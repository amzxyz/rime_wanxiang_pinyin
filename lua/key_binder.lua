-- 正则按键绑定处理器
-- 通用（不包含声笔系列码的特殊逻辑）
-- 本处理器在 Rime 标准库的按键绑定处理器（key_binder）的基础上增加了用正则表达式判断当前输入的编码的功能
-- 也即，在输入编码不同时，可以将按键绑定到不同的功能

local rime = require "lib"

local this = {}

---@class KeyBinderEnv: Env
---@field redirecting boolean
---@field bindings Binding[]

---@class Binding
---element
---@field match string
---@field accept KeyEvent
---@field send_sequence KeySequence

---解析配置文件中的按键绑定配置
---@param value ConfigMap
---@return Binding | nil
local function parse(value)
  local match = value:get_value("match")
  local accept = value:get_value("accept")
  local send_sequence = value:get_value("send_sequence")
  if not match or not accept or not send_sequence then
    return nil
  end
  local key_event = rime.KeyEvent(accept:get_string())
  local sequence = rime.KeySequence(send_sequence:get_string())
  local binding = { match = match:get_string(), accept = key_event, send_sequence = sequence }
  return binding
end

---@param env KeyBinderEnv
function this.init(env)
  env.redirecting = false
  ---@type Binding[]
  env.bindings = {}
  local bindings = env.engine.schema.config:get_list("key_binder/bindings")
  if not bindings then
    return
  end
  for i = 1, bindings.size do
    local item = bindings:get_at(i - 1)
    if not item then goto continue end
    local value = item:get_map()
    if not value then goto continue end
    local binding = parse(value)
    if not binding then goto continue end
    table.insert(env.bindings, binding)
    ::continue::
  end
end

---@param key_event KeyEvent
---@param env KeyBinderEnv
function this.func(key_event, env)
  -- local input = rime.current(env.engine.context)
  local input = rime.input(env.engine.context)
  -- log.info("key_binder"..input)
  if env.redirecting then
    return rime.process_results.kNoop
  end


  if not input then
    return rime.process_results.kNoop
  end
  if env.engine.context == nil or env.engine.context.composition == nil or env.engine.context.composition:back() == nil then
    return rime.process_results.kNoop
  end
  if not env.engine.context.composition:back():has_tag("abc") then
    return rime.process_results.kNoop
  end
  for _, binding in ipairs(env.bindings) do
    -- 只有当按键和当前输入的模式都匹配的时候，才起作用
    if key_event:eq(binding.accept) and rime.match(input, binding.match) then
      env.redirecting = true
      for _, event in ipairs(binding.send_sequence:toKeyEvent()) do
        env.engine:process_key(event)
      end
      env.redirecting = false
      return rime.process_results.kAccepted
    end
  end
  return rime.process_results.kNoop
end

return this
