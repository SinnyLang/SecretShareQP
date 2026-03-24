function tie_lines = find_tie_lines(mpc)
    % FIND_TIE_LINES 识别电网中的区域间联络线
    %
    % 输入参数:
    %   mpc - MATPOWER格式的电网数据结构
    %
    % 输出参数:
    %   tie_lines - 联络线数据矩阵，格式与mpc.branch相同
    
    % 检查输入有效性
    if ~isstruct(mpc) || ~isfield(mpc, 'bus') || ~isfield(mpc, 'branch')
        error('输入必须是包含bus和branch字段的MATPOWER数据结构');
    end
    
    % 建立节点到区域的映射字典
    bus_area_dict = containers.Map(mpc.bus(:,1), mpc.bus(:,7));
    
    % 初始化联络线集合
    tie_lines = [];
    
    % 遍历所有支路
    for i = 1:size(mpc.branch, 1)
        fbus = mpc.branch(i, 1);
        tbus = mpc.branch(i, 2);
        
        % 获取支路两端的区域编号
        area_from = bus_area_dict(fbus);
        area_to = bus_area_dict(tbus);
        
        % 如果两端区域不同，则判定为联络线
        if area_from ~= area_to
            tie_lines = [tie_lines; mpc.branch(i, :)];
        end
    end
    
    % 如果没有找到联络线，返回空矩阵
    if isempty(tie_lines)
        tie_lines = zeros(0, size(mpc.branch, 2));
    end
end