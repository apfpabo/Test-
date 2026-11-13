import sys, numpy as np
f=sys.argv[1]; V=[]; F=[]; obj=-1; fo=[]
for ln in open(f, errors='ignore'):
    if ln.startswith('v '): V.append([float(x) for x in ln.split()[1:4]])
    elif ln.startswith('o '): obj+=1
    elif ln.startswith('f '):
        idx=[int(t.split('/')[0]) for t in ln.split()[1:]]
        idx=[i-1 if i>0 else len(V)+i for i in idx]
        for k in range(1,len(idx)-1): F.append([idx[0],idx[k],idx[k+1]]); fo.append(obj)
V=np.array(V); F=np.array(F); fo=np.array(fo)
print('verts',len(V),'tris',len(F)); print('min',V.min(0),'max',V.max(0),'size',V.max(0)-V.min(0))
for o in range(obj+1):
    P=V[np.unique(F[fo==o])]; print('obj',o,'tris',(fo==o).sum(),'min',P.min(0).round(0),'max',P.max(0).round(0))
np.save(sys.argv[2],V[F]); np.save(sys.argv[2]+'_obj',fo)
