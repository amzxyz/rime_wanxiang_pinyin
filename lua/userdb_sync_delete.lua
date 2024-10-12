--欢迎使用带声调的词库:飞声词库
--https://github.com/amzxyz/rime_feisheng
--@amzxyz
--引入方式: - lua_processor@*userdb_sync_delete
--这个脚本通过输入 /del 触发,用于清理自定义同步目录下txt用户词典里被标记c<0的词条,同时删除rime目录下的*.userdb目录,之后手动执行重新部署以彻底删除由Ctrl+del删除的用户词
--⚠️使用前先执行同步保存现有的用户词,再执行/del,等待提示完成清理多少条,即完成清理,之后重新部署一下刷新数据,最后执行同步才能加载回来清理后的用户词,这部分工作单靠lua无法完成
-- 兼容linux windows ,有通知；安卓同文输入法测试通过,无通知
-- 初始化函数
function init(env)
    log.info("用户词库清理程序初始化成功")
    if not env.initialized then
        env.initialized = true
        env.os_type = detect_os_type()  -- 全局变量，存储系统类型
        env.pending_directories = {}  -- 用于保存所有待处理的目录路径
        env.total_deleted = 0  -- 记录删除的总条目数
    end
end

-- 手动维护的操作系统检测模式表
local os_detection_patterns = {
    windows = { "weasel", "Weasel" },    -- Windows 的标识符列表
    linux = { "fcitx%-rime" },           -- Linux 的标识符
    macos = { "squirrel" },              -- macOS 的标识符
    android = { "trime" }                -- android 的标识符
}

-- 定义全局函数 detect_os_type
function detect_os_type()
    local user_data_dir = rime_api.get_user_data_dir()
    local yaml_path = user_data_dir .. "/installation.yaml"

    -- 打开 installation.yaml 文件
    local file, err = io.open(yaml_path, "r")
    if not file then
        log.error("无法打开 installation.yaml 文件: " .. tostring(err))
        return "unknown"
    end

    -- 遍历文件内容并检测 distribution_code_name 字段
    local os_type = "unknown"
    for line in file:lines() do
        local dist_name = line:match('^%s*distribution_code_name:%s*"?([%w%-]+)"?')
        if dist_name then
            -- 遍历 os_detection_patterns 表来匹配系统类型
            for os, patterns in pairs(os_detection_patterns) do
                for _, pattern in ipairs(patterns) do
                    if dist_name:match(pattern) then
                        os_type = os
                        break
                    end
                end
                if os_type ~= "unknown" then break end
            end
            break
        end
    end

    file:close()  -- 关闭文件
    log.info("检测到的操作系统类型为: " .. os_type)
    return os_type
end

-- 检测并处理路径分隔符转换
function convert_path_separator(path, os_type)
    if os_type == "windows" then
        path = path:gsub("\\\\", "\\")  -- 将双反斜杠替换为单反斜杠
    end
    return path
end

-- 从 installation.yaml 文件中获取 sync_dir 路径
function get_sync_path_from_yaml(env)
    local user_data_dir = rime_api.get_user_data_dir()
    local yaml_path = user_data_dir .. "/installation.yaml"

    -- 使用标准 Lua io.open 打开文件
    local file, err = io.open(yaml_path, "r")
    if not file then
        log.error("无法打开 installation.yaml 文件: " .. tostring(err))
        return nil, "无法打开 installation.yaml 文件"
    end

    -- 读取文件并提取 sync_dir 的值
    local sync_dir = nil
    for line in file:lines() do
        local key, value = line:match('(sync_dir):%s*"?(.-)"?%s*$')
        if key and value then
            sync_dir = value:match("^%s*(.-)%s*$")
            sync_dir = convert_path_separator(sync_dir, env.os_type)  -- 根据系统类型转换路径分隔符
            sync_dir = sync_dir:gsub('%"', '')  -- 去掉路径中的引号
            break
        end
    end

    file:close()  -- 关闭文件

    if sync_dir then
        log.info("获取的 sync_dir 路径为: " .. sync_dir)
        return sync_dir, nil
    else
        local default_sync_dir = user_data_dir .. "/sync"  -- 与 installation.yaml 同级的 sync 目录
        log.info("未能从 installation.yaml 获取到 sync_dir，使用默认路径: " .. default_sync_dir)
        return default_sync_dir, nil
    end
end



-- 捕获输入并执行相应的操作
function UserDictCleaner_process(key_event, env)
    local engine = env.engine
    local context = engine.context
    local input = context.input

    -- 检查是否输入 /del
    if input == "/del" and env.initialized then
        log.info("检测到 /del 输入，开始执行清理操作...")
        env.total_deleted = 0  -- 重置计数器

        local success, err = pcall(trigger_sync_cleanup, env)
        if not success then
            log.error("清理操作失败: " .. tostring(err))
            send_user_notification(0, env)  -- 清理操作失败时发送0
        else
            log.info("清理操作完成。")
            send_user_notification(env.total_deleted, env)
        end

        -- 清空输入内容，防止输入保留
        context:clear()
        return 1  -- 返回 1 表示已处理该事件
    end

    return 2  -- 返回 2 继续处理其它输入
end

-- 定义固定部分的ANSI编码
local base_message = "\xD3\xC3\xBB\xA7\xB4\xCA\xB5\xE4\xB9\xB2\xC7\xE5\xC0\xED\x20" -- "用户词典共清理 "（注意结尾有一个空格）
local end_message = "\x20\xD0\xD0\xCE\xDE\xD0\xA7\xB4\xCA\xCC\xF5" -- " 行无效词条"（前面带一个空格）

-- 预定义数字0-9的ANSI编码表示
local digit_to_ansi = {
    ["0"] = "\x30", ["1"] = "\x31", ["2"] = "\x32", ["3"] = "\x33",
    ["4"] = "\x34", ["5"] = "\x35", ["6"] = "\x36", ["7"] = "\x37",
    ["8"] = "\x38", ["9"] = "\x39"
}

-- 生成ANSI编码的删除条目数量部分
function encode_deleted_count_to_ansi(deleted_count)
    local ansi_count = ""
    for i = 1, #tostring(deleted_count) do
        local digit = tostring(deleted_count):sub(i, i)
        local encoded_digit = digit_to_ansi[digit] or ""
        ansi_count = ansi_count .. encoded_digit
    end
    return ansi_count
end

-- 动态生成完整的ANSI消息（适用于Windows）
function generate_ansi_message(deleted_count)
    local encoded_count = encode_deleted_count_to_ansi(deleted_count)
    return base_message .. encoded_count .. end_message
end

-- 动态生成UTF-8消息（适用于Linux）
function generate_utf8_message(deleted_count)
    return "用户词典共清理 " .. tostring(deleted_count) .. " 行无效词条"
end

-- 发送通知反馈函数，使用动态生成的消息
function send_user_notification(deleted_count, env)
    if env.os_type == "windows" then
        local ansi_message = generate_ansi_message(deleted_count)
        os.execute('msg * "' .. ansi_message .. '"')
    elseif env.os_type == "linux" then
        local utf8_message = generate_utf8_message(deleted_count)
        os.execute('notify-send "' .. utf8_message .. '"')
    elseif env.os_type == "macos" then
        local utf8_message = generate_utf8_message(deleted_count)
        os.execute('osascript -e \'display notification "' .. utf8_message .. '"\'')
    elseif env.os_type == "android" then
        local utf8_message = generate_utf8_message(deleted_count)
        os.execute('notify "' .. utf8_message .. '"')
    else
        log.info("无法发送通知，未识别的操作系统")
    end
end

-- 使用 os 执行不同的命令，列出文件
function list_files(path, env)
    local command = env.os_type == "windows" and ('dir "' .. path .. '" /b') or ('ls -1 "' .. path .. '"')
    local handle = io.popen(command)
    if not handle then
        log.error("无法遍历路径: " .. path)
        return nil, "无法遍历路径: " .. path
    end

    local files = {}
    for file in handle:lines() do
        table.insert(files, file)
    end
    handle:close()
    return files, nil
end

-- 递归删除 installation.yaml 同级目录下的 .userdb 文件夹
function delete_userdb_folders(env)
    local user_data_dir = rime_api.get_user_data_dir()
    local files, err = list_files(user_data_dir, env)

    if not files then
        log.error("无法列出文件夹")
        return
    end

    -- 遍历文件夹，删除以 .userdb 结尾的文件夹
    for _, file in ipairs(files) do
        if file:match("%.userdb$") then
            local full_path = user_data_dir .. "/" .. file
            log.info("发现并删除 userdb 文件夹: " .. full_path)
            if env.os_type == "windows" then
                os.execute('rmdir /S /Q "' .. full_path .. '"')
            else
                os.execute('rm -rf "' .. full_path .. '"')
            end
            log.info("删除 userdb 文件夹完成: " .. full_path)
        end
    end
end

-- 收集目录的函数
function collect_directories(path, env)
    local directories, err = list_files(path, env)
    if not directories then
        log.error("收集目录失败: " .. tostring(err))
        return
    end

    -- 将找到的所有目录添加到 pending_directories 列表
    for _, dir in ipairs(directories) do
        local full_path = path .. "/" .. dir
        table.insert(env.pending_directories, full_path)
    end
end

-- 处理所有已收集的目录
function process_collected_directories(env)
    while #env.pending_directories > 0 do
        local directory = table.remove(env.pending_directories)
        log.info("处理目录: " .. directory)

        local files, err = list_files(directory, env)
        if not files then
            log.error("处理目录失败: " .. tostring(err))
        else
            for _, file in ipairs(files) do
                if file:match("%.userdb%.txt$") then
                    log.info("发现 userdb 文件: " .. directory .. "/" .. file)
                    process_userdb_file(directory .. "/" .. file, env)
                end
            end
        end
    end
end

-- 处理 .userdb.txt 文件并删除 c < 0 条目的函数
function process_userdb_file(file_path, env)
    log.info("开始处理 userdb 文件: " .. file_path)

    local file, err = io.open(file_path, "r")
    if not file then
        log.error("无法打开文件: " .. file_path .. " 错误: " .. tostring(err))
        return
    end

    local temp_file_path = file_path .. ".tmp"
    local temp_file = io.open(temp_file_path, "w")
    if not temp_file then
        log.error("无法创建临时文件: " .. temp_file_path .. " 错误: " .. tostring(err))
        file:close()
        return
    end

    local entries_deleted = false
    local delete_count = 0
    for line in file:lines() do
        local c_value = line:match("c=(%-?%d+)")
        if c_value then
            c_value = tonumber(c_value)
            if c_value > 0 then
                temp_file:write(line .. "\n")
            else
                log.info("删除条目: " .. line:sub(1, 30) .. "...")
                entries_deleted = true
                delete_count = delete_count + 1
            end
        else
            temp_file:write(line .. "\n")
        end
    end

    file:close()
    temp_file:close()

    if entries_deleted then
        log.info("已删除 " .. tostring(delete_count) .. " 个条目，替换原文件。")
        os.remove(file_path)
        os.rename(temp_file_path, file_path)
        -- 更新总删除计数
        env.total_deleted = env.total_deleted + delete_count
    else
        log.info("没有发现无效条目，跳过文件替换。")
        os.remove(temp_file_path)
    end
end

-- 触发清理操作
function trigger_sync_cleanup(env)
    local sync_path, err = get_sync_path_from_yaml(env)
    if not sync_path then
        log.error(err)
        send_user_notification(0, env)
        return
    end

    -- 收集所有子目录
    collect_directories(sync_path, env)

    -- 处理所有收集到的目录
    process_collected_directories(env)

    -- 删除 .userdb 文件夹
    delete_userdb_folders(env)
end

-- 返回初始化和处理函数
return {
    init = init,
    func = UserDictCleaner_process
}
