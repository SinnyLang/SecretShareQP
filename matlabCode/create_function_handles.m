function [ffifun, ggifun, hhifun] = create_function_handles(dOPF)
    % CREATE_FUNCTION_HANDLES 将符号表达式转换为函数句柄
    %
    % 输入:
    %   dOPF - 包含符号表达式的分布式OPF结构
    %
    % 输出:
    %   ffifun - 目标函数句柄(1×N cell数组)
    %   ggifun - 等式约束函数句柄(1×N cell数组)
    %   hhifun - 不等式约束函数句柄(1×N cell数组)

    num_areas = length(dOPF.ffi);
    ffifun = cell(1, num_areas);
    ggifun = cell(1, num_areas);
    hhifun = cell(1, num_areas);
    
    for i = 1:num_areas
        % 1. 转换目标函数
        if ~isempty(dOPF.ffi{i})
            ffifun{i} = matlabFunction(dOPF.ffi{i}, 'Vars', {dOPF.xx{i}});
        else
            ffifun{i} = @(x) 0; % 空目标函数
        end
        
        % 2. 转换等式约束
        if ~isempty(dOPF.ggi{i})
            ggi_vector = dOPF.ggi{i}(:); % 确保是列向量
            ggifun{i} = matlabFunction(ggi_vector, 'Vars', {dOPF.xx{i}});
        else
            ggifun{i} = @(x) []; % 空等式约束
        end
        
        % 3. 转换不等式约束
        if ~isempty(dOPF.hhi{i})
            hhi_vector = dOPF.hhi{i}(:); % 确保是列向量
            hhifun{i} = matlabFunction(hhi_vector, 'Vars', {dOPF.xx{i}});
        else
            hhifun{i} = @(x) []; % 空不等式约束
        end
    end
end
