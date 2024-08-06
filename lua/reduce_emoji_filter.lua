-- 降低emoji在候选项的位置
local M = {}

function M.init(env)
  local config = env.engine.schema.config
  -- env.name_space = env.name_space:gsub("^*", "")
  -- 候选页大小
  M.size = config:get_int("menu/page_size") or 0
end

local function isEmoji(cand)
  return cand:get_dynamic_type() == "Shadow" and not (cand.text:find("([\228-\233][\128-\191]-)") and cand.text:find("[%a]"))
end

local function splitInput(input, size)
  local emoji_cands = {}
  local text_cands = {}
  local other_cands = {}
  local prev_text = ""
  local index = 0
  for item in input:iter() do
    index = index + 1
    if index > size then
      table.insert(other_cands, item)
    elseif isEmoji(item) then
      table.insert(emoji_cands, { prev_text, item })
    else
      prev_text = item.text
      table.insert(text_cands, item)
    end
  end

  return text_cands, emoji_cands, other_cands
end

function M.func(input, env)
  -- 候选页小于3原样返回
  if M.size < 3 then
    for cand in input:iter() do
      yield(cand)
    end
    return
  end

  local text_cands, emoji_cands, other_cands = splitInput(input, M.size)

  if #text_cands > 0 then
    for _, cand in ipairs(text_cands) do
      yield(cand)
    end
  end

  if #emoji_cands > 0 then
    for _, cand_item in ipairs(emoji_cands) do
      yield(ShadowCandidate(cand_item[2], cand_item[2].type, cand_item[2].text, cand_item[1]))
    end
  end

  if #other_cands > 0 then
    for _, cand in ipairs(other_cands) do
      yield(cand)
    end
  end
end

return M
