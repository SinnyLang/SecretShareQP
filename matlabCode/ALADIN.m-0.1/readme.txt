Replace matlab code at line 37 in iterateAL.m, ALADIN.m-v0.1.

Replace:
```matlab
[ xs, lamTot] = solveQP(HQP,gQP,AQP,bQP,opts.solveQP);
```
with:
```matlab
[xs, lamTot] = solveQPWithSSQP(HQP,gQP,AQP,bQP,opts.solveQP,iter);
```