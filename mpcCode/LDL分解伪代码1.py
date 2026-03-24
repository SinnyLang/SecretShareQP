Input:  A, Size, RA
Output: L, D, INV_D
Init MT=0, RL=1, 
Function SSQP_LDL_compose(A, Size):
    SetRecordingLFirstColumn()
    SumOfProducts = 0

    for j in range(Size):
        for k in range(j):
            if(RL_{jk} != 0):
                MT_{jk} = L_{jk} * D_{k}
                SumOfProducts += L_{jk} * MT_{jk}
        D_{j} = A_{jj} - SumOfProducts

        INV_D_{j} = reciprocal(D_{j})

        for i in range(j+1, n):
            ParallComputeL(A, L, j, i, INV_D)

    return D, L, INV_D

Function ParallComputeL(A, L, Column, Row, INV_D):
    Flag, SumOfProducts = 0, 0
    j, i = Column, Row

    for k in range(j): 
        if(RL_{ik} != 0 && RL_{jk} != 0)
            SumOfProducts += L_{ik} * MT_{jk}
            Flag = 1

    if(Flag + RA_{ij} == 0)
        L_{ij}, RL_{ij}= 0, 0
    else:
        L_{ij} = (A_{ij} - SumOfProducts) * INV_D_{j}
        RL_{ij} = 1