function [mpc, no_gen_buses] = add_null_gen(mpc_old) 
    mpc = mpc_old;

    % 找出所有有发电机的节点
    gen_buses = mpc.gen(:, 1);
    % 找出所有节点
    all_buses = mpc.bus(:, 1);
    % 找出没有发电机的节点
    no_gen_buses = setdiff(all_buses, gen_buses);
    
    % 为每个没有发电机的节点添加零参数发电机
    for i = 1:length(no_gen_buses)
        bus = no_gen_buses(i);
        
        % 创建新的发电机数据行
        new_gen = [
            bus    ... % 节点号
            0      ... % Pg (有功发电，设置为0)
            0      ... % Qg (无功发电，设置为0)
            0      ... % Qmax (最大无功，设置为0)
            0      ... % Qmin (最小无功，设置为0)
            1      ... % Vg (电压设定值，保持1 pu)
            mpc.baseMVA ... % mBase (基准功率)
            1      ... % status (状态，1表示在线)
            0      ... % Pmax (最大有功，设置为0)
            0      ... % Pmin (最小有功，设置为0)
            zeros(1, 11) ... % 其他参数全部设为0
        ];
        
        % 创建对应的发电机成本数据行
        new_gencost = [
            2      ... % 成本模型类型 (2表示多项式)
            0      ... % 启动成本
            0      ... % 停机成本
            2      ... % 成本曲线分段数
            0      ... % 二次项系数
            0      ... % 一次项系数
            0      ... % 常数项系数
        ];
        
        % 将新发电机添加到gen和gencost矩阵中
        mpc.gen = [mpc.gen; new_gen];
        mpc.gencost = [mpc.gencost; new_gencost];
    end
    
    % 按节点号排序发电机数据
    [~, idx] = sort(mpc.gen(:, 1));
    mpc.gen = mpc.gen(idx, :);
    mpc.gencost = mpc.gencost(idx, :);
    
    % 可以将修改后的mpc结构保存回文件或用于进一步计算
    % save('modified_case5.mat', 'mpc');

end