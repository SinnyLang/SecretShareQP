import scipy.io
import numpy as np

def read_A_b_P_from_mat(file_path1: str, file_path2: str):
    """从mat读取矩阵"""
    # 加载 MATLAB 数据
    data1 = scipy.io.loadmat(file_path1)
    A, b = data1['A2'], data1['full_bs']
    data2 = scipy.io.loadmat(file_path2)
    P = data2['P2']
    return A, b, P


QP_A, b, P = read_A_b_P_from_mat(
        'Player-Data/temp_data_A_b.mat',
        'Player-Data/temp_data_P.mat'
    )

n_parties = 3
### 分离二次项 Q = diag(H1,H2,H3,mu)
H1, H2, H3 = QP_A[0:20, 0:20], QP_A[20:36, 20:36], QP_A[36:52, 36:52]
mu = QP_A[52:68, 52:68]

### 分离约束项 [A1,A2,A3,-E; J1,0,0,0; 0,J2,0,0; 0,0,J3,0]
idx = H1.shape[0] + H2.shape[0] + H3.shape[0] + mu.shape[0]  # 68
A1, A2, A3 = QP_A[idx + 0:idx + 16, 0:20], QP_A[idx + 0:idx + 16, 20:36], QP_A[idx + 0:idx + 16, 36:52]
J1, J2, J3 = (QP_A[idx + 16:idx + 16 + 12, 0:20], QP_A[idx + 16 + 12:idx + 16 + 12 + 10, 20:36],
              QP_A[idx + 16 + 12 + 10:idx + 16 + 12 + 10 + 8, 36:52])

### 分离b向量 [g1,g2,g3,lambda,rhs,0,0,0]
g1, g2, g3 = b[0:20, :], b[20:36, :], b[36:52, :]
lambda_global = b[52:68, :]
rhs = b[68:84]


def flatten_all(*arrays):
    """将多个数组 flatten 后按顺序拼接"""
    return np.concatenate([arr.flatten() for arr in arrays], axis=0)


input_data1 = flatten_all(H1, mu, A1, J1, g1, lambda_global, rhs)
input_data2 = flatten_all(H2, A2, J2, g2)
input_data3 = flatten_all(H3, A3, J3, g3)

np.savetxt('Player-Data/Input-P0-0', input_data1, fmt='%.16f')
np.savetxt('Player-Data/Input-P1-0', input_data2, fmt='%.16f')
np.savetxt('Player-Data/Input-P2-0', input_data3, fmt='%.16f')


AA = np.array([
    [1, 2, 3, 4],
    [2, 8, 6, 7],
    [3, 6, 10, 9],
    [4, 7, 9, 5]
])
bb = np.array([[2,2,1,3]]).T
# xx1 == [3,2,-7,4]
# xx2 == [4.3333333333, -0.2469135802, -1.9629629630, 1.0123456790]

l,d,p = scipy.linalg.ldl(AA, lower=False)
print('l\n', l)
print('d\n', d)
print('p', p)


import numpy as np

def ldl_pivoting(A):
    """
    返回主元置换矩阵 P，使得 P @ A @ P.T 适合进行 LDLᵀ 分解
    """
    A = np.array(A, dtype=float)
    n = A.shape[0]
    P = np.eye(n)
    idx = list(range(n))

    for j in range(n):
        # 从对角线中选最大主元
        submat = np.abs(A[np.ix_(idx[j:], idx[j:])])
        pivot = j + np.argmax(np.diag(submat))
        if pivot != j:
            idx[j], idx[pivot] = idx[pivot], idx[j]

    # 构造置换矩阵
    P = np.eye(n)[idx]
    return P

def ldl_factor(A, P):
    """
    对对称矩阵 A 进行 LDLᵀ 分解，返回 L 和 D，输入置换矩阵 P。
    要求 A 是对称矩阵，P 是从 ldl_pivoting 得到的置换矩阵。
    """
    A_perm = P @ A @ P.T
    print(A_perm)
    n = A_perm.shape[0]
    L = np.eye(n)
    D = np.zeros(n)

    for j in range(n):
        # 计算 D[j]
        sum_ldl = sum(L[j, k]**2 * D[k] for k in range(j))
        D[j] = A_perm[j, j] - sum_ldl

        # 计算 L[i, j]，其中 i > j
        for i in range(j + 1, n):
            sum_ = sum(L[i, k] * D[k] * L[j, k] for k in range(j))
            L[i, j] = (A_perm[i, j] - sum_) / D[j]

    return L, D


PP = ldl_pivoting(AA)
ll, dd = ldl_factor(AA, PP)
print('PP\n', PP)
print('dd\n', dd)
print('ll\n', ll)
# ==================== 解方程  ====================
bb1 = PP @ bb
n = bb.shape[0]

X = np.zeros((n, 1))
y = np.zeros((n, 1))
# y[0] = bb1[0]
for i in range(0, n):
    s = 0
    for k in range(0, i):
        s += ll[i][k] * y[k]
    y[i] = bb1[i] - s
print('y\n', y)

# X[n-1] = y[n-1] / dd[n-1]
for i in range(n-1, -1, -1):
    s = 0
    for k in range(i+1, n):
        s += ll[k][i] * X[k]
    X[i] = y[i]/dd[i] - s

X = PP.T @ X
print('X\n', X)

def permute_rows(A, P):
    """
    返回 PA，其中 P 是置换矩阵，A 是 n x n 矩阵。
    实现使用行交换，而非矩阵乘法。
    """
    row = A.shape[0]
    column = A.shape[1]
    PA = [[0.0 for _ in range(row)] for _ in range(column)]

    for i in range(row):
        # 找出 P[i] 为 1 的列号 j ⇒ 第 i 行来自 A 的第 j 行
        for j in range(column):
            if P[i][j] == 1:
                for k in range(n):
                    PA[i][k] = A[j][k]
                break

    return PA

print(permute_rows(AA, PP))
print('bb:', permute_rows(bb, PP))

