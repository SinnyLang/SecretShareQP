function x2 = SSQP(iter)
    % SSQP - 自定义算法（Secret Share QP）
    % 输入: current_iteration - 当前迭代次数
    % 输出: x2 - 计算结果

    % 获取3个子问题的约束矩阵的行数
    numHH = cellfun(@(x) size(x, 1), iter.loc.sensEval.JJacCon);
    
    % --- 初始化 ---
    % 1. 定义BAT脚本路径和输出文件路径
    bat_script = ['D:\FTProot\remoteSSQP.bat ', ...
                    num2str(iter.i),   ' ', ...
                    num2str(numHH(1)), ' ', ...
                    num2str(numHH(2)), ' ', ...
                    num2str(numHH(3))];
    output_file = 'D:\FTProot\data_X.mat';
    archived_output = sprintf('dataX_iter_%d.mat', iter.i);

    try
        data = load(archived_output);
        if ~isfield(data, 'X2')
            error('dataX.mat文件中缺少 <X2> 变量');
        end
        x2 = data.X2';
        fprintf('从缓存文件%s加载 <X2>\n', archived_output)
        return;
    catch ME
        fprintf('当前在第%d次循环:执行remoteSSQP\n', iter.i)
    end
    
    % 2. 执行BAT脚本
    [status, cmdout] = system(bat_script);
    
    % 3. 检查BAT执行是否成功
    if status ~= 0
        error('BAT脚本执行失败: %s', cmdout);
    end
    
    % 4. 等待文件生成（带超时机制）
    max_wait_time = 30;  % 最大等待时间(秒)
    check_interval = 60;  % 检查间隔(秒)
    elapsed_time = 0;
    file_exists = false;
    pause('on')
    
    while ~file_exists   % && elapsed_time < max_wait_time
        if exist(output_file, 'file') == 2
            file_exists = true;
            break;
        end
        pause(check_interval);
        elapsed_time = elapsed_time + check_interval;
        fprintf('当前在第%d次循环-用时%d秒\n', iter.i, elapsed_time)
    end
    
    % 5. 检查文件是否生成
    if ~file_exists
        error('等待超时: dataX.mat文件未在%d秒内生成', max_wait_time);
    end
    
    % 6. 尝试加载文件内容
    try
        data = load(output_file);
        if ~isfield(data, 'X2')
            error('dataX.mat文件中缺少 <X2> 变量');
        end
        x2 = data.X2';

        % 重命名文件，追加迭代次数
        if exist(archived_output, 'file') == 2
            delete(archived_output);  % 如果目标文件已存在，先删除
        end
        movefile(output_file, archived_output);
    catch ME
        error('读取dataX.mat文件失败: %s', ME.message);
    end
    
    % --- 返回x2 ---
    
end