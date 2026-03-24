function [mpc_areas, tie_lines] = partition(mpc)
    % 初始化
    mpc_areas = struct('bus', {}, 'gen', {}, 'branch', {}, 'gencost', {}, ...
                      'baseMVA', {}, 'version', {});
    tie_lines = [];
    
    % 获取所有area编号
    area_numbers = unique(mpc.bus(:,7))';
    
    % 分区处理
    for i = 1:length(area_numbers)
        area_id = area_numbers(i);
        area_buses = mpc.bus(mpc.bus(:,7) == area_id, 1);
        
        % 区域数据
        mpc_areas(i).bus = mpc.bus(mpc.bus(:,7) == area_id, :);
        mpc_areas(i).gen = mpc.gen(ismember(mpc.gen(:,1), area_buses), :);
        
        % 区域内支路
        internal_branches = ismember(mpc.branch(:,1), area_buses) & ...
                           ismember(mpc.branch(:,2), area_buses);
        mpc_areas(i).branch = mpc.branch(internal_branches, :);
        
        % 其他字段
        mpc_areas(i).gencost = mpc.gencost(ismember(mpc.gen(:,1), area_buses), :);
        mpc_areas(i).baseMVA = mpc.baseMVA;
        mpc_areas(i).version = mpc.version;
    end
    
    % 识别联络线(两端在不同区域的支路)
    area_assignment = zeros(max(mpc.bus(:,1)), 1);
    for i = 1:length(area_assignment)
        area_assignment(mpc.bus(i,1)) = mpc.bus(i,7);
    end
    
    for j = 1:size(mpc.branch, 1)
        fbus = mpc.branch(j,1);
        tbus = mpc.branch(j,2);
        if area_assignment(fbus) ~= area_assignment(tbus)
            tie_lines = [tie_lines; mpc.branch(j,:)];
        end
    end
end