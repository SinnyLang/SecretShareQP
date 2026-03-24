function dOPF = create_distributed_OPF(mpc_area)
    % CREATE_DISTRIBUTED_OPF 为每个分区创建分布式OPF模型(修正版)
    %
    % 主要修正:
    % 1. 处理分区后节点编号不连续的问题
    % 2. 完善功率平衡方程
    % 3. 优化约束条件生成

    num_areas = length(mpc_area);
    dOPF = struct();
    
    % 初始化各字段
    dOPF.lbx = cell(1, num_areas);
    dOPF.ubx = cell(1, num_areas);
    dOPF.Sig = cell(1, num_areas);
    dOPF.ffi = cell(1, num_areas);
    dOPF.ggi = cell(1, num_areas);
    dOPF.hhi = cell(1, num_areas);
    dOPF.xx = cell(1, num_areas);
    dOPF.xx0 = cell(1, num_areas);
    dOPF.AA = cell(1, num_areas);
    
    % 为每个区域创建OPF模型
    for i = 1:num_areas
        mpc = mpc_area(i);
        
        % 转换节点编号为连续编号
        [mpc_int, bus_map, gen_map] = convert_to_internal_ordering(mpc);
        
        % 1. 定义变量
        [xx, xx0, lbx, ubx] = define_variables(mpc_int);
        dOPF.xx{i} = xx;
        dOPF.xx0{i} = xx0;
        dOPF.lbx{i} = lbx;
        dOPF.ubx{i} = ubx;
        
        % 2. 目标函数(发电成本)
        dOPF.ffi{i} = create_cost_function(mpc_int, xx);
        
        % 3. 等式约束
        dOPF.ggi{i} = create_equality_constraints(mpc_int, xx);
        
        % 4. 不等式约束
        dOPF.hhi{i} = create_inequality_constraints(mpc_int, xx);
        
        % 5. 存储映射关系以便后续使用
        dOPF.Sig{i} = struct('bus_map', bus_map, 'gen_map', gen_map);
    end
end

function [mpc_int, bus_map, gen_map] = convert_to_internal_ordering(mpc)
    % 将节点编号转换为连续编号
    
    % 创建bus映射
    original_bus = mpc.bus(:,1);
    new_bus = (1:length(original_bus))';
    bus_map = containers.Map(original_bus, new_bus);
    
    % 创建gen映射
    original_gen_bus = mpc.gen(:,1);
    new_gen_bus = arrayfun(@(x) bus_map(x), original_gen_bus);
    gen_map = containers.Map(original_gen_bus, new_gen_bus);
    
    % 更新bus矩阵
    mpc_int = mpc;
    mpc_int.bus(:,1) = new_bus;
    
    % 更新gen矩阵
    mpc_int.gen(:,1) = new_gen_bus;
    
    % 更新branch矩阵
    mpc_int.branch(:,1) = arrayfun(@(x) bus_map(x), mpc.branch(:,1));
    mpc_int.branch(:,2) = arrayfun(@(x) bus_map(x), mpc.branch(:,2));
end

function [xx, xx0, lbx, ubx] = define_variables(mpc)
    % 定义变量: Pg, Qg, theta, V
    
    num_bus = size(mpc.bus, 1);
    num_gen = size(mpc.gen, 1);
    area = mpc.bus(1, 7);
    Pg_Name = ['Pg','0'+area ,'_'];
    Qg_Name = ['Qg','0'+area ,'_'];
    theta_Name = ['theta','0'+area ,'_'];
    V_Name = ['V','0'+area ,'_'];

    % 创建符号变量
    Pg = sym(Pg_Name, [num_gen, 1], 'real');
    Qg = sym(Qg_Name, [num_gen, 1], 'real');
    theta = sym(theta_Name, [num_bus, 1], 'real');
    V = sym(V_Name, [num_bus, 1], 'real');
    
    % 合并所有变量
    xx = [Pg; Qg; theta; V];
    
    % 初始值
    xx0 = zeros(size(xx));
    
    % 发电机初始值
    xx0(1:num_gen) = 0; %mpc.gen(:, 2)/mpc.baseMVA; % Pg(转换为标幺值)
    xx0(num_gen+1:2*num_gen) = 0; %mpc.gen(:, 3)/mpc.baseMVA; % Qg(转换为标幺值)
    
    % 电压初始值
    xx0(end-num_bus+1:end) = 1; %mpc.bus(:, 8); % V
    xx0(end-2*num_bus+1:end-num_bus) = 0; %mpc.bus(:, 9)*pi/180; % theta(转换为弧度)
    
    % 上下界
    lbx = -inf(size(xx));
    ubx = inf(size(xx));
    
    % Pg bounds(转换为标幺值)
    % todo: note!! 注意:对于下界，共识母线的gen下界不应为0
    %   1. 统一设置为-100，然后为真实母线添加hhi不等式界限约束
    %   2. 统一设置为0   ，然后为共识母线单独调整界限
    lbx(1:num_gen) = 0; % mpc.gen(:, 10)/mpc.baseMVA; % Pmin
    ubx(1:num_gen) = 100; %mpc.gen(:, 9)/mpc.baseMVA; % Pmax
    
    % Qg bounds(转换为标幺值)
    lbx(num_gen+1:2*num_gen) = -100; %mpc.gen(:, 5)/mpc.baseMVA; % Qmin
    ubx(num_gen+1:2*num_gen) = 100; %pc.gen(:, 4)/mpc.baseMVA; % Qmax
    
    % V bounds
    lbx(end-num_bus+1:end) = mpc.bus(:, 13); % Vmin
    ubx(end-num_bus+1:end) = mpc.bus(:, 12); % Vmax
    
    % Theta bounds (通常无限制，但可设置)
    lbx(end-2*num_bus+1:end-num_bus) = -pi/4;
    ubx(end-2*num_bus+1:end-num_bus) = pi/4;
end

function ffi = create_cost_function(mpc, xx)
    % 创建目标函数(发电成本)
    
    num_gen = size(mpc.gen, 1);
    Pg = xx(1:num_gen); % 提取Pg变量(已经是标幺值)
    
    % 假设二次成本函数: cost = a*(Pg*baseMVA)^2 + b*(Pg*baseMVA) + c
    ffi = 0;
    for i = 1:num_gen
        if mpc.gencost(i, 1) == 2 % 多项式成本函数
            coeff = mpc.gencost(i, 5:end);
            order = length(coeff) - 1;
            cost = 0;
            Pg_MW = Pg(i) * mpc.baseMVA; % 转换为实际值(MW)
            for j = 0:order
                cost = cost + coeff(end-j) * Pg_MW^j;
            end
            ffi = ffi + cost;
        else
            error('仅支持多项式成本函数');
        end
    end
    
    % 转换为符号表达式
    ffi = sym(ffi);
end

function ggi = create_equality_constraints(mpc, xx)
    % 创建等式约束
    
    num_bus = size(mpc.bus, 1);
    num_gen = size(mpc.gen, 1);
    
    % 提取变量
    Pg = xx(1:num_gen);
    Qg = xx(num_gen+1:2*num_gen);
    theta = xx(2*num_gen+1:2*num_gen+num_bus);
    V = xx(2*num_gen+num_bus+1:end);
    
    % 1. 功率平衡约束
    [P_balance, Q_balance] = create_power_balance(mpc, Pg, Qg, theta, V);
    
    % 2. 参考节点约束(相角为0) ,还需要加上电压为1
    ref_bus = find(mpc.bus(:, 2) == 3); % 平衡节点
    if ~isempty(ref_bus)
        ref_eq = theta(ref_bus);
        ref_eq_V = V(ref_bus)-1;
    else
        ref_eq = [];
        ref_eq_V = [];
    end
    
    % 合并所有等式约束
    ggi = [P_balance; Q_balance; ref_eq; ref_eq_V];
end

function [P_balance, Q_balance] = create_power_balance(mpc, Pg, Qg, theta, V)
    % 创建功率平衡方程
    
    num_bus = size(mpc.bus, 1);
    num_gen = size(mpc.gen, 1);
    
    % 构建节点导纳矩阵
    [Ybus, ~, ~] = makeYbus(mpc);
    % 提取实部和虚部
    G = real(Ybus);
    B = imag(Ybus);
    
    % 初始化功率注入
    P_inj = zeros(num_bus, 1, 'sym');
    Q_inj = zeros(num_bus, 1, 'sym');
    
    % 发电机注入(已经是标幺值)
    for i = 1:num_gen
        bus = mpc.gen(i, 1);
        P_inj(bus) = P_inj(bus) + Pg(i);
        Q_inj(bus) = Q_inj(bus) + Qg(i);
    end
    
    % 负荷减去(注意MATPOWER中Pd,Qd为正表示负荷，转换为标幺值)
    P_inj = P_inj - mpc.bus(:, 3)/mpc.baseMVA;
    Q_inj = Q_inj - mpc.bus(:, 4)/mpc.baseMVA;
    
    % 计算网络注入功率
    P_net = zeros(num_bus, 1, 'sym');
    Q_net = zeros(num_bus, 1, 'sym');
    
    for i = 1:num_bus
        for k = 1:num_bus
            theta_ik = theta(i) - theta(k);
            P_net(i) = P_net(i) + V(i)*V(k)*(G(i,k)*cos(theta_ik) + B(i,k)*sin(theta_ik));
            Q_net(i) = Q_net(i) + V(i)*V(k)*(G(i,k)*sin(theta_ik) - B(i,k)*cos(theta_ik));
        end
    end
    
    % 功率平衡方程
    P_balance = P_inj - P_net;
    Q_balance = Q_inj + Q_net; % 注意Q_net定义与MATPOWER一致
end

function hhi = create_inequality_constraints(mpc, xx)
    % 创建不等式约束
    
    num_bus = size(mpc.bus, 1);
    num_gen = size(mpc.gen, 1);
    
    % 提取变量
    Pg = xx(1:num_gen);
    Qg = xx(num_gen+1:2*num_gen);
    theta = xx(2*num_gen+1:2*num_gen+num_bus);
    V = xx(2*num_gen+num_bus+1:end);
    
    % 1. 支路功率流约束
    branch_limits = create_branch_limits(mpc, theta, V);
    
    % 2. 发电机无功能力约束(考虑电压影响)
    gen_q_limits = create_gen_q_limits(mpc, V);
    
    % 合并所有不等式约束
    hhi = [branch_limits; gen_q_limits];
end

function branch_limits = create_branch_limits(mpc, theta, V)
    % 创建支路功率流约束
    
    num_branch = size(mpc.branch, 1);
    branch_limits = sym([]);
    
    for i = 1:num_branch
        fbus = mpc.branch(i, 1);
        tbus = mpc.branch(i, 2);
        r = mpc.branch(i, 3);
        x = mpc.branch(i, 4);
        b = mpc.branch(i, 5);
        rateA = mpc.branch(i, 6)/mpc.baseMVA; % 转换为标幺值
        
        if rateA > 0 % 只有有限制的支路才添加约束
            % 计算支路电流
            z = r + 1i*x;
            y = 1/z;
            ys = 1i*b/2;
            
            % 从端功率流
            Vf = V(fbus) * exp(1i*theta(fbus));
            Vt = V(tbus) * exp(1i*theta(tbus));
            If = (Vf - Vt)*y + Vf*ys;
            Sf = Vf * conj(If);
            
            % 添加约束(视在功率限制)
            branch_limits = [branch_limits; real(Sf)^2 + imag(Sf)^2 - rateA^2];
        end
    end
end

function gen_q_limits = create_gen_q_limits(mpc, V)
    % 创建发电机无功能力约束(考虑电压影响)
    
    num_gen = size(mpc.gen, 1);
    gen_q_limits = sym([]);
    
    for i = 1:num_gen
        bus = mpc.gen(i, 1);
        Vg = V(bus);
        Qmax = mpc.gen(i, 4)/mpc.baseMVA; % 转换为标幺值
        Qmin = mpc.gen(i, 5)/mpc.baseMVA; % 转换为标幺值
        
        % 添加约束: Qmin ≤ Qg ≤ Qmax
        % 这些已经在变量边界中处理，这里可以添加更复杂的约束
        % 例如考虑电压相关的无功限制
        
        % 示例: 添加电压相关的约束(可选)
        % gen_q_limits = [gen_q_limits; Vg - 1.1; 0.9 - Vg];
    end
end