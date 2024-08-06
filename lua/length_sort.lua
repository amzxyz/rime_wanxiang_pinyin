function length_sort(input, env)
  local candidates = {}
  
  -- 收集所有候选词
  for cand in input:iter() do
    table.insert(candidates, cand)
  end
  
  -- 按长度排序，2个字的优先，之后是3个字和4个字
  table.sort(candidates, function(a, b)
    local len_a = utf8.len(a.text)
    local len_b = utf8.len(b.text)
    if len_a == 2 and len_b ~= 2 then
      return true
    elseif len_a ~= 2 and len_b == 2 then
      return false
    else
      return len_a < len_b
    end
  end)
  
  -- 将排序后的候选词输出
  for _, cand in ipairs(candidates) do
    yield(cand)
  end
end
