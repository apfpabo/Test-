import sys, numpy as np
from PIL import Image
T=np.load(sys.argv[1]); k=50/235375.0
# ship axes: x = along (model Y), y = across (model X, centred), z = up (model Z)
P=np.stack([T[:,:,1]*k-25.0, (T[:,:,0]-50124.0)*k, T[:,:,2]*k],axis=2)
np.save(sys.argv[2]+'_ship.npy',P)
def raster(P,ia,ib,ic,sc=10,flip=False):
    a=P[:,:,ia]; b=P[:,:,ib]; c=P[:,:,ic]
    a0,b0=a.min(),b.min(); W=int((a.max()-a0)*sc)+3; H=int((b.max()-b0)*sc)+3; Z=np.full((H,W),-1e9)
    for t in range(len(P)):
        x=(a[t]-a0)*sc+1; y=(b[t]-b0)*sc+1; z=c[t]
        x0,x1=int(np.floor(x.min())),int(np.ceil(x.max())); y0,y1=int(np.floor(y.min())),int(np.ceil(y.max()))
        d=(y[1]-y[2])*(x[0]-x[2])+(x[2]-x[1])*(y[0]-y[2])
        if abs(d)<1e-9: continue
        xs,ys=np.meshgrid(np.arange(x0,x1+1),np.arange(y0,y1+1))
        l0=((y[1]-y[2])*(xs-x[2])+(x[2]-x[1])*(ys-y[2]))/d; l1=((y[2]-y[0])*(xs-x[2])+(x[0]-x[2])*(ys-y[2]))/d; l2=1-l0-l1
        m=(l0>=-1e-6)&(l1>=-1e-6)&(l2>=-1e-6); zz=l0*z[0]+l1*z[1]+l2*z[2]
        sub=Z[y0:y1+1,x0:x1+1]; sub[m]=np.maximum(sub[m],zz[m])
    return Z
def img(Z):
    M=Z>-1e8; lo,hi=Z[M].min(),Z[M].max(); G=np.zeros(Z.shape,np.uint8); G[M]=(50+205*(Z[M]-lo)/(hi-lo)).astype(np.uint8)
    gy,gx=np.gradient(np.where(M,Z,lo)); sh=np.clip(0.55-0.5*gx-0.5*gy,0,1); S=np.zeros(Z.shape,np.uint8); S[M]=(40+215*sh[M]).astype(np.uint8); return G,S
top=raster(P,0,1,2); np.save(sys.argv[2]+'_top.npy',top)
side=raster(P,0,2,1)   # looking from starboard: x along, z up
front=raster(P,1,2,0)  # looking from ahead
G,S2=img(top); gs,ss=img(side); gf,sf=img(front)
W=max(G.shape[1],gs.shape[1],gf.shape[1]); pad=lambda a: np.pad(a,((0,0),(0,W-a.shape[1])))
Image.fromarray(np.vstack([pad(G),pad(S2),pad(ss[::-1]),pad(sf[::-1])])).save(sys.argv[2]+'_views.png'); print(G.shape, gs.shape, gf.shape)
