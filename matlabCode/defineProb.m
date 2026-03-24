mpc = loadcase('case5.m');

% 补全发电机，为无发电机节点添加0发电机
[mpc, no_gen_buses] = add_null_gen(mpc);

% 使用增强版函数
[tielines, tieinfo] = find_tie_lines_with_info(mpc);
% 在连接线处增加一个中间节点将连接线分开


% 在联络线中添加中间节点，保存到每个area中
% 插入中间节点
[modified_mpc, new_nodes] = insert_tieline_nodes(mpc);

% 分区
[mpc_areas, tie_line] = partition(modified_mpc);

% 2. 创建分布式OPF模型
dOPF1 = create_distributed_OPF(mpc_areas);

% 3. 添加共识约束（使用新版本）
dOPF1 = add_consensus_constraints(dOPF1, mpc_areas, new_nodes);

% 4. 转换为函数句柄
[ffifun, ggifun, hhifun] = create_function_handles(dOPF1);

% 添加Sigma矩阵
for i = 1:length(dOPF1.xx)
    dOPF1.Sigma{i} = eye(length(dOPF1.xx{i}))*100;
end

% 因为共识母线的Pg下界统一设置了0，需要手动为共识母线单独调整界限
dOPF1.lbx{1}(3:5,:)=-100;
dOPF1.lbx{2}(2:4,:)=-100;
dOPF1.lbx{3}(3:4,:)=-100;



Ncons = 16;
%
import casadi.*
% bring into the correct foormat
sProb.locFuns.ffi = ffifun;
sProb.locFuns.ggi = ggifun;
sProb.locFuns.hhi = hhifun;
sProb.AA          = dOPF1.A;
sProb.zz0         = dOPF1.xx0;
sProb.lam0        = 0.01*ones(Ncons,1); 
sProb.llbx        = dOPF1.lbx;
sProb.uubx        = dOPF1.ubx;

opts.SSig         = dOPF1.Sigma;
opts.plot         = 'true';
opts.innerAlg     = 'none';  %;'D-ADMM';
opts.innerIter    = 3100;
opts.maxiter      = 300;
opts.term_eps     = 0.0000000001;

                                
% run ALADIN-M                           
res_ALADIN = run_ALADIN(sProb, opts);
% compare to centralized solution
res_IPOPT  = run_IPOPT(sProb);

fprintf(['\n\nError in primal variables (inf-norm):' ...
        num2str(norm(vertcat(res_ALADIN.xxOpt{:}) - res_IPOPT.x,inf)) '\n'])

