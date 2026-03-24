function [new_mpc, new_nodes] = insert_tieline_nodes(mpc)
    % INSERT_TIELINE_NODES 在联络线处插入中间节点并添加虚拟发电机
    %
    % 输入:
    %   mpc - MATPOWER格式的电网数据结构
    %
    % 输出:
    %   new_mpc - 修改后的电网数据(包含虚拟发电机)
    %   new_nodes - 新增的节点信息列表
    
    % 复制原始数据
    new_mpc = mpc;
    
    % 找出所有联络线
    tie_lines = find_tie_lines(mpc);
    if isempty(tie_lines)
        new_nodes = [];
        return;
    end
    
    % 初始化新增节点列表
    new_nodes = [];
    
    % 建立节点到区域的映射
    bus_area = containers.Map(mpc.bus(:,1), mpc.bus(:,7));
    
    % 处理每条联络线
    for i = 1:size(tie_lines, 1)
        fbus = tie_lines(i, 1);
        tbus = tie_lines(i, 2);
        
        % 创建新节点编号(使用当前最大节点号+1)
        new_bus_id = max(new_mpc.bus(:,1)) + 1;
        new_bus_id_mirror = new_bus_id + 1;
        
        % 记录新增节点
        new_nodes = [new_nodes; new_bus_id; new_bus_id_mirror];
        
        % 获取原线路参数
        r = tie_lines(i, 3);
        x = tie_lines(i, 4);
        b = tie_lines(i, 5);
        rateA = tie_lines(i, 6);
        rateB = tie_lines(i, 7);
        rateC = tie_lines(i, 8);
        ratio = tie_lines(i, 9);
        angle = tie_lines(i, 10);
        status = tie_lines(i, 11);
        
        % 创建两个新节点(一个属于区域1，一个属于区域2)
        new_bus_data = mpc.bus(mpc.bus(:,1) == fbus, :); % 复制起始节点数据作为模板
        new_bus_data(1, 1) = new_bus_id; % 设置新节点ID
        new_bus_data(1, 2) = 1; % 设置为PQ节点
        new_bus_data(1, 3:6) = 0; % Pg, Qg, Pd, Qd = 0
        new_bus_data(1, 7) = bus_area(fbus); % 与fbus同区域
        new_bus_data(1, 12) = 1.1; % Vmax
        new_bus_data(1, 13) = 0.9; % Vmin
        
        new_bus_mirror = new_bus_data;
        new_bus_mirror(1, 1) = new_bus_id_mirror;
        new_bus_mirror(1, 7) = bus_area(tbus); % 与tbus同区域
        
        % 添加新节点到bus矩阵
        new_mpc.bus = [new_mpc.bus; new_bus_data; new_bus_mirror];
        
        % 为每个新节点添加虚拟发电机
        % 发电机1 (新节点)
        new_gen1 = [new_bus_id,0,0,10000,-10000,1.0,mpc.baseMVA,1,10000,0,zeros(1, 11)];
        
        % 发电机2 (镜像节点)
        new_gen2 = new_gen1;
        new_gen2(1) = new_bus_id_mirror;
        
        % 添加发电机数据
        new_mpc.gen = [new_mpc.gen; new_gen1; new_gen2];
        
        % 添加发电机成本数据(零成本)
        new_gencost = [2,0,0,2,0,0,0];
        new_mpc.gencost = [new_mpc.gencost; new_gencost; new_gencost];
        
        % 创建两条新支路(参数为原支路的一半)
        new_branch1 = [fbus, new_bus_id, r/2, x/2, b/2, rateA, rateB, rateC, ratio, angle, status, -360, 360];
        new_branch2 = [new_bus_id_mirror, tbus, r/2, x/2, b/2, rateA, rateB, rateC, ratio, angle, status, -360, 360];
        
        % 添加新支路
        new_mpc.branch = [new_mpc.branch; new_branch1; new_branch2];
        
        % 标记原支路为待删除(设置status=0)
        orig_idx = find(ismember(new_mpc.branch(:,1:2), [fbus, tbus], 'rows'));
        new_mpc.branch(orig_idx, 11) = 0; % 设置status=0表示删除
    end
    
    % 删除被标记的原始支路
    new_mpc.branch = new_mpc.branch(new_mpc.branch(:,11) == 1, :);
    
    % 更新版本信息
    new_mpc.version = '2';
end