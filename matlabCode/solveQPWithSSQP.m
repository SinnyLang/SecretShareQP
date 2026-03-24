function [ delx, lam  ] = solveQPWithSSQP( H, g, A, b, solver, iter)
% QP问题:min L(x)=1/2*x'Hx + g'x , s.t. Ax=b
% min arg L(x,lamb)= 1/2*x'Hx + g'x + lamb'(Ax-b)
% 闭式解：[H A'; A 0]*[x; lamb] = [-g; b]

if strcmp(solver, 'MA57')
    % the MATLAB ldl() command uses MA57
    neq = size(A,1);
    nx  = size(H,1);
     
    
    % sparse solution
    % 构建QP问题闭式解-构建系数[H A'; A 0]
    LEQS_As = [H A';
               A zeros(neq)];
    % 构建QP问题闭式解-构建得数[-g; b]
    LEQS_Bs = [-g; b];
    
    % constraint regularization (Parameter from IPOPT paper)
%     reg = false;
%     if reg == true
%         LEQS_As(end-Nhact+1:end,end-Nhact+1:end) = -1e-8*eye(Nhact);
%     end
    
%   计算 x=A'b
    %cheack_matrix_difiniteness(LEQS_As)
    full_bs=full(LEQS_Bs);
    full_As=full(LEQS_As);
    full_n = size(full_As, 1);
    full_P = eye(full_n);  % 初始置换矩阵
    for full_k = 1:full_n-1
        [~, max_idx] = max(abs(diag(full_As(full_k:full_n, full_k:full_n))));  % 找最大对角元
        max_idx = max_idx + full_k - 1;
        % 交换行和列
        full_As([full_k, max_idx], :) = full_As([max_idx, full_k], :);
        full_As(:, [full_k, max_idx]) = full_As(:, [max_idx, full_k]);
        full_P(:, [full_k, max_idx]) = full_P(:, [max_idx, full_k]);
    end
    % 现在 A 的对角元均非零，可以进行 LDL' 分解
    %[full_L, full_D] = ldl(full_As);  % 不再需要额外置换
    n = size(full_As, 1);
    full_L = eye(n);
    full_D = zeros(n);
    for k = 1:n
        full_D(k, k) = full_As(k, k);
        if abs(full_D(k, k)) < 1e-20
            error('矩阵接近奇异。 Zero pivot detected. Matrix may be singular or need 2×2 pivoting.');
        end
        
        full_L(k+1:n, k) = full_As(k+1:n, k) / full_D(k, k);
        full_As(k+1:n, k+1:n) = full_As(k+1:n, k+1:n) - ...
            full_L(k+1:n, k) * full_D(k, k) * full_L(k+1:n, k)';
    end

    save('D:\test_data\temp_data_P.mat',"full_P");
    has_zero = any(diag(full_As) == 0);
    if has_zero
        error("置换后的A矩阵对角线含有0");
    end


    % P*A*P'=LDL'
    A2=full(LEQS_As);
    save('D:\FTProot\data_A_b.mat',"A2","full_bs");
    P2=ldl_permutation(A2);
    save('D:\FTProot\data_P.mat',"P2");

    [L2, D2] = ldl_decomposition(A2,P2);
    D2=diag(D2);
    x2=P2'*(L2'\(D2\(L2\(P2*LEQS_Bs))));
    % 使用SSQP解X
    x2 = SSQP(iter);
    LEQS_xs = x2;



    %   分解 x->[delx; lamb]
    delx    = LEQS_xs(1:nx);
    lam     = LEQS_xs((nx+1):end); 
    %   eigH    = []; %eig(H); % takes a lot of time...
    %   rankLEQS_ex = []; %rank([LEQS_A LEQS_B]);
    
end

end

function P = ldl_permutation(A)
% 返回主元置换矩阵 P，使得 P*A*P' 更适合进行 LDLᵀ 分解
    n = size(A, 1);
    P = eye(n);
    idx = 1:n;

    for j = 1:n
        % 选择对角线中最大的元素作为主元
        [~, pivot_rel] = max(abs(diag(A(idx(j:end), idx(j:end)))));
        pivot = pivot_rel + j - 1;

        % 交换索引和置换矩阵的行
        if pivot ~= j
            idx([j, pivot]) = idx([pivot, j]);
            P([j, pivot], :) = P([pivot, j], :);
        end
    end
end

function [L, D] = ldl_decomposition(A, P)
% 对 P*A*P' 做 LDLᵀ 分解，返回单位下三角矩阵 L 和对角向量 D

    A_perm = P * A * P';
    n = size(A, 1);
    L = zeros(n);
    D = zeros(n, 1);

    for j = 1:n
        D(j) = A_perm(j, j) - sum((L(j,1:j-1).^2) .* D(1:j-1)');
        for i = j+1:n
            L(i,j) = (A_perm(i,j) - sum(L(i,1:j-1) .* D(1:j-1)' .* L(j,1:j-1))) / D(j);
        end
    end

    % 对角线设为 1
    L = L + eye(n);
end
    
      


