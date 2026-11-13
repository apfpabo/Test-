import sys, numpy as np, base64, io, json
from PIL import Image, ImageFilter
P=np.load(sys.argv[1]); out=sys.argv[2]
P=P.copy(); P[:,:,0]*=-1            # bow to +x (the propellers are at the model's +x end)
WL=float(sys.argv[3]) if len(sys.argv)>3 else 4.4   # waterline above the keel, metres (her real draught)
SC=32; X0,X1,Y0,Y1=-27.0,27.0,-12.0,12.0; W=int((X1-X0)*SC); H=int((Y1-Y0)*SC); Z=np.full((H,W),-1e9); ALL=np.zeros((H,W),bool); WIN=np.zeros((H,W),bool)
OBJ=np.load(sys.argv[4]) if len(sys.argv)>4 else None   # which part of the model each triangle belongs to: part 3 is her bridge windows
# ALL: everything in the model seen from above, her underwater hulls too
for ti,t in enumerate(P):
    x=(t[:,0]-X0)*SC; y=(t[:,1]-Y0)*SC; z=t[:,2]
    x0,x1=max(0,int(np.floor(x.min()))),min(W-1,int(np.ceil(x.max()))); y0,y1=max(0,int(np.floor(y.min()))),min(H-1,int(np.ceil(y.max())))
    d=(y[1]-y[2])*(x[0]-x[2])+(x[2]-x[1])*(y[0]-y[2])
    if abs(d)<1e-9 or x1<x0 or y1<y0: continue
    xs,ys=np.meshgrid(np.arange(x0,x1+1)+0.5,np.arange(y0,y1+1)+0.5)
    l0=((y[1]-y[2])*(xs-x[2])+(x[2]-x[1])*(ys-y[2]))/d; l1=((y[2]-y[0])*(xs-x[2])+(x[0]-x[2])*(ys-y[2]))/d; l2=1-l0-l1
    m=(l0>=-1e-6)&(l1>=-1e-6)&(l2>=-1e-6); zz=l0*z[0]+l1*z[1]+l2*z[2]
    ALL[y0:y1+1,x0:x1+1]|=m
    if OBJ is not None and OBJ[ti]==3: WIN[y0:y1+1,x0:x1+1]|=m
    if z.max()<WL: continue
    sub=Z[y0:y1+1,x0:x1+1]; sub[m]=np.maximum(sub[m],zz[m])
Hm=np.clip(Z-WL,0,None); Hm=np.maximum(Hm,Hm[::-1])          # above the water; made the same on both sides
# small fittings (aerials, the mast) are left off the hull's own height: anything standing more than a metre proud of its surroundings
def uniform_filter(a,n):
    k=n//2; c=np.cumsum(np.pad(a,((k+1,k),(0,0)),mode='edge'),axis=0); a=(c[n:]-c[:-n])/n
    c=np.cumsum(np.pad(a,((0,0),(k+1,k)),mode='edge'),axis=1); return (c[:,n:]-c[:,:-n])/n
def grey_opening(a,size):
    n=size[0]; im=Image.fromarray((np.clip(a/20.0,0,1)*65535).astype(np.uint16).astype(np.int32),'I')
    lo=Image.fromarray((np.clip(a/20.0,0,1)*255).astype(np.uint8)).filter(ImageFilter.MinFilter(n)).filter(ImageFilter.MaxFilter(n))
    return np.asarray(lo).astype(float)/255*20.0
pass
M=(Hm>0.05).astype(float)
print('height above water %.1f m; length %.1f, beam %.1f'%(Hm.max(), np.ptp(np.where(M.any(0))[0])/SC, np.ptp(np.where(M.any(1))[0])/SC))
# normals for the colour picture: each plate one flat tone, a hair lighter the more it faces up, creases drawn where the plates meet
gy,gx=np.gradient(Hm*SC/ SC, 1.0/SC)
gxs=uniform_filter(gx,5); gys=uniform_filter(gy,5)
slope=np.sqrt(gxs**2+gys**2); up=1/np.sqrt(1+slope**2)
tone=0.30+0.16*up                                                    # grey, to be darkened by the game to her paint
lap=np.abs(np.gradient(gxs,axis=1))+np.abs(np.gradient(gys,axis=0))+np.abs(np.gradient(gxs,axis=0))+np.abs(np.gradient(gys,axis=1))
crease=np.clip(lap*1.2,0,1); crease=uniform_filter(crease,3)
tone=tone*(1-0.55*np.clip(crease*3,0,1))
# her paint: near black (the owner's word), the plates still telling apart
rgb=np.stack([tone*0.40,tone*0.42,tone*0.45],axis=2)
xx=(np.arange(W)+0.5)/SC+X0; hmax=float(np.percentile(Hm[Hm>0.05],98.5)); flat=(slope<0.2)&(Hm>hmax*0.75)   # flat: her roof
# her bridge windows are the model's own panes (the owner, 13 Nov 2026: 'you modeled the windows correctly': no band): glass with a light blue tint, their frames kept
WIN=WIN|WIN[::-1]
glass=WIN&(crease<0.12)
rgb[glass]=rgb[glass]*0.35+np.array([0.20,0.33,0.42])*0.65

def down(a): return a.reshape(H//2,2,W//2,2).mean(axis=(1,3))
A=down(M); Hd=down(Hm*M)/np.maximum(A,1e-6)
col=np.zeros((H//2,W//2,4),np.uint8)
for c in range(3): col[...,c]=np.clip(down(rgb[...,c]*M)/np.maximum(A,1e-6)*255,0,255).astype(np.uint8)
col[...,3]=np.clip(A*255,0,255).astype(np.uint8)
hm=np.zeros((H//2,W//2,4),np.uint8); hv=np.clip(Hd/40.0*255,0,255).astype(np.uint8); hm[...,0]=hv; hm[...,1]=hv; hm[...,2]=hv; hm[...,3]=np.where(A>0.5,255,0).astype(np.uint8)
# her twin hulls under the water, seen through it: whatever of the model lies outside her waterline plan
ALL=ALL|ALL[::-1]; under=ALL&(M<0.5); ua=down(under.astype(float))
sub=np.zeros((H//2,W//2,4),np.uint8); sub[...,0]=8; sub[...,1]=30; sub[...,2]=38; sub[...,3]=np.clip(ua*150,0,255).astype(np.uint8)
Image.fromarray(sub).save(out+'_sub.png',optimize=True)
Image.fromarray(col).save(out+'_col.png',optimize=True); Image.fromarray(hm).save(out+'_hm.png',optimize=True)
# outline, knuckle-free: half-width at stations, then thinned to the points that matter
def half_at(mask, sc):
    xs=np.where(mask.any(0))[0]; pts=[]
    for xi in range(xs.min(), xs.max()+1):
        ys=np.where(mask[:,xi])[0]
        if len(ys)==0: continue
        pts.append(((xi+0.5)/sc+X0, (ys.max()-ys.min()+1)/sc/2))
    return pts
def thin(pts, eps):
    if len(pts)<3: return pts
    a,b=np.array(pts[0]),np.array(pts[-1]); d=b-a; n=np.array([-d[1],d[0]])/max(1e-9,np.hypot(*d)); ds=[abs(np.dot(np.array(p)-a,n)) for p in pts]; i=int(np.argmax(ds))
    return pts if False else (thin(pts[:i+1],eps)[:-1]+thin(pts[i:],eps) if ds[i]>eps else [pts[0],pts[-1]])
ol=thin(half_at(M>0.5,SC),0.18)[::-1]; ol[0]=(ol[0][0],0.15); ol[-1]=(ol[-1][0],0.15)
roof=thin(half_at(flat,SC),0.15)[::-1]
res={'L':round(ol[0][0]-ol[-1][0],1),'B':round(2*max(p[1] for p in ol),1),'height':round(hmax,1),'outline':[[round(x,1),round(y,2)] for x,y in ol],'roof':[[round(x,1),round(y,2)] for x,y in roof],
     'x0':X0,'y0':Y0,'w':X1-X0,'h':Y1-Y0,'col':'data:image/png;base64,'+base64.b64encode(open(out+'_col.png','rb').read()).decode(),'hm':'data:image/png;base64,'+base64.b64encode(open(out+'_hm.png','rb').read()).decode(),'sub':'data:image/png;base64,'+base64.b64encode(open(out+'_sub.png','rb').read()).decode()}
json.dump(res,open(out+'.json','w')); print({k:(v if not isinstance(v,str) else len(v)) for k,v in res.items()})
