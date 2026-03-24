function dOPF = add_consensus_constraints(dOPF, mpc_area, new_nodes)
    % BUILD_CONSENSUS_MATRIX 构建全局共识约束矩阵
    %
    % 输入:
    %   dOPF - 分布式OPF结构
    %   mpc_area - 分区后的电网数据
    %   new_nodes - 插入的中间节点列表(必须是成对出现)
    %
    % 输出:
    %   dOPF - 添加了共识约束的分布式OPF结构

    num_areas = length(mpc_area);
    
    % 1. 计算各区域的变量偏移量
    var_offsets = [0, cumsum(cellfun(@length, dOPF.xx(1:end-1)))];
    total_vars = sum(cellfun(@length, dOPF.xx));
    
    % 2. 初始化全局共识矩阵A
    num_consensus_vars = length(new_nodes) * 4 / 2; % 每个节点4个变量
    A = zeros(num_consensus_vars, total_vars);
    
    % 3. 建立节点到区域的映射
    node_area_map = containers.Map();
    for i = 1:num_areas
        buses = mpc_area(i).bus(:,1);
        for j = 1:length(buses)
            node_area_map(num2str(buses(j))) = i;
        end
    end
    
    % 4. 遍历每对插入节点，构建共识约束
    constraint_row = 1;
    for n = 1:length(new_nodes)/2
        node1 = new_nodes(2*n-1);
        node2 = new_nodes(2*n);
        
        % 确定这两个节点所在的区域
        area1 = node_area_map(num2str(node1));
        area2 = node_area_map(num2str(node2));
        
        % 为4种变量类型创建约束
        var_types = {'Pg', 'Qg', 'theta', 'V'};
        for v = 1:length(var_types)
            var_type = var_types{v};
            
            
            % 在区域1中找到变量位置
            %var1_name = sprintf('%s%d', var_type, node1);
            %var1_idx = find(strcmp(var1_name, arrayfun(@char, dOPF.xx{area1}, 'UniformOutput', false)));
            %var1_global = var_offsets(area1) + var1_idx;
            var1_global = dOPF.Sig{area1}.bus_map(node1) + ... 
                var_type_offset_of_area(dOPF, area1, var_type) + ...
                var_offsets(area1);
            
            % 在区域2中找到变量位置
            %var2_name = sprintf('%s%d', var_type, node2);
            %var2_idx = find(strcmp(var2_name, arrayfun(@char, dOPF.xx{area2}, 'UniformOutput', false)));
            %var2_global = var_offsets(area2) + var2_idx;
            var2_global = dOPF.Sig{area2}.bus_map(node2) + ... 
                var_type_offset_of_area(dOPF, area2, var_type) + ...
                var_offsets(area2);
            
            % 根据变量类型设置系数
            if strcmp(var_type, 'Pg') || strcmp(var_type, 'Qg')
                % Pg/Qg: 两个区域都设为1
                A(constraint_row, var1_global) = 1;
                A(constraint_row, var2_global) = 1;
            else
                % theta/V: 区域1设为1，区域2设为-1
                A(constraint_row, var1_global) = 1;
                A(constraint_row, var2_global) = -1;
            end
            
            constraint_row = constraint_row + 1;
        end
    end
    
    % 5. 将全局A矩阵分割到各个区域
    for i = 1:num_areas
        start_col = var_offsets(i) + 1;
        end_col = var_offsets(i) + length(dOPF.xx{i});
        dOPF.A{i} = A(:, start_col:end_col);
    end
end

function var_type_offset = var_type_offset_of_area(dOPF, area, var_type)
    var_type_offset = 0;
    num_bus = length(dOPF.xx{area})/4;
    switch var_type
        case 'Pg'
            var_type_offset = 0*num_bus;
        case 'Qg'
            var_type_offset = 1*num_bus;
        case 'theta'
            var_type_offset = 2*num_bus;
        case 'V'
            var_type_offset = 3*num_bus;
    end
end