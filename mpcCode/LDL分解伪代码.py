Input:  A, Size, Recording_A
Output: L, D, INV_D
Init MT=0, Recording_L=1, 
Function SSQP_LDL_compose(A, Size):
    SetRecordingLFirstColumn()
    SumOfProducts = 0

    for j in range(Size):
        for k in range(j):
            if(Recording_L[j][k] != 0):
                MT[j][k] = L[j][k] * D[k]
                SumOfProducts += L[j][k] * MT[j][k]
        D[j] = A[j][j] - SumOfProducts

        INV_D[j] = reciprocal(D[j])

        for i in range(j+1, n):
            ParallComputeL(A, L, j, i, INV_D)

    return D, L, INV_D

Function ParallComputeL(A, L, Column, Row, INV_D):
    Flag, SumOfProducts = 0, 0
    j, i = Column, Row

    for k in range(j):   # compute_sum_of_multi_items(k):
        if(Recording_L[i][k] != 0 && Recording_L[j][k] != 0)
            SumOfProducts += L[i][k] * MT[j][k]
            Flag = 1

    if(Flag + Recording_A[i][j] == 0)
        L[i][j], Recording_L[i][j]= 0, 0
    else:
        L[i][j] = (A[i][j] - SumOfProducts) * INV_D[j]
        Recording_L[i][j] = 1