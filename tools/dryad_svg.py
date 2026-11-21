import math, random, sys
random.seed(7)
W,H=160,252
out=[]
def P(*a): out.append(''.join(a))
def f(v): return f'{v:.1f}'
defs='''<defs>
<linearGradient id="bark" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#a5764a"/><stop offset=".35" stop-color="#7a5232"/><stop offset=".75" stop-color="#4e331d"/><stop offset="1" stop-color="#2a190d"/></linearGradient>
<linearGradient id="barkLimb" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#9a6d43"/><stop offset=".6" stop-color="#5e3e23"/><stop offset="1" stop-color="#2e1c0f"/></linearGradient>
<radialGradient id="face" cx=".38" cy=".32" r=".8"><stop offset="0" stop-color="#f1fbdc"/><stop offset=".55" stop-color="#cfe8a8"/><stop offset="1" stop-color="#86ad62"/></radialGradient>
<radialGradient id="cowl" cx=".4" cy=".3" r=".85"><stop offset="0" stop-color="#4fae3c"/><stop offset=".6" stop-color="#2f7d2a"/><stop offset="1" stop-color="#16461a"/></radialGradient>
<linearGradient id="leafL" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#b6f37f"/><stop offset=".5" stop-color="#6fd64a"/><stop offset="1" stop-color="#2f8f2e"/></linearGradient>
<linearGradient id="leafD" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#6fc24c"/><stop offset=".55" stop-color="#3f9a36"/><stop offset="1" stop-color="#1c5a20"/></linearGradient>
<linearGradient id="moss" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7fcf55"/><stop offset="1" stop-color="#2f7a2a"/></linearGradient>
<radialGradient id="petal" cx=".3" cy=".3" r=".9"><stop offset="0" stop-color="#fff2f8"/><stop offset=".6" stop-color="#ffc4de"/><stop offset="1" stop-color="#e889b4"/></radialGradient>
<radialGradient id="eye" cx=".35" cy=".3" r=".8"><stop offset="0" stop-color="#3d8a3a"/><stop offset="1" stop-color="#123814"/></radialGradient>
<linearGradient id="vert" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#d8ffb0" stop-opacity=".35"/><stop offset=".35" stop-color="#8cf06a" stop-opacity="0"/><stop offset=".7" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".45"/></linearGradient>
<linearGradient id="rim" x1="1" y1="0" x2="0" y2="0"><stop offset="0" stop-color="#ffb060" stop-opacity=".55"/><stop offset=".18" stop-color="#ff9a3c" stop-opacity="0"/></linearGradient>
'''
clips=[]
# ---------- helpers
def taper(pts_l, pts_r, top=0, bot=0):
    # closes the outline with rounded caps (top bulges up, bottom down) so it reads as a cylinder
    def cap(a,b,h):
        if not h: return ''
        mx,my=(a[0]+b[0])/2,(a[1]+b[1])/2
        return f' Q{f(mx)},{f(my+h*2)} {f(b[0])},{f(b[1])}'
    d='M'+' L'.join(f'{f(x)},{f(y)}' for x,y in pts_l)
    d+=cap(pts_l[-1],pts_r[-1],-top) if top else f' L{f(pts_r[-1][0])},{f(pts_r[-1][1])}'
    d+=' L'+' L'.join(f'{f(x)},{f(y)}' for x,y in pts_r[::-1])
    d+=cap(pts_r[0],pts_l[0],bot)
    return d+' Z'
def limb(x0,y0,x1,y1,w0,w1,bend=0,n=14,prof=None):
    # centreline with a bend; returns left/right outlines and frames
    L,R,C=[],[],[]
    for i in range(n+1):
        t=i/n
        x=x0+(x1-x0)*t+bend*math.sin(math.pi*t); y=y0+(y1-y0)*t
        dx=(x1-x0)+bend*math.pi*math.cos(math.pi*t); dy=(y1-y0)
        l=math.hypot(dx,dy); nx,ny=-dy/l,dx/l
        w=(prof(t) if prof else (w0+(w1-w0)*t))/2
        L.append((x+nx*w,y+ny*w)); R.append((x-nx*w,y-ny*w)); C.append((x,y,nx,ny,w))
    return L,R,C
def ridges(C,count,cid,seed):
    # bark ridges: grooves that follow the limb, packed toward its edges (cylinder)
    rnd=random.Random(seed); s=[]
    for k in range(count):
        u=-0.95+1.9*(k+0.5)/count
        off=math.sin(u*math.pi/2)
        ph=rnd.random()*6; amp=0.5+rnd.random()*0.5
        pts=[]
        for i,(x,y,nx,ny,w) in enumerate(C):
            o=(off+amp*0.12*math.sin(i*1.3+ph))*w*0.95
            pts.append((x+nx*o,y+ny*o))
        # split the groove into 2-3 runs (bark plates)
        cuts=sorted(rnd.sample(range(2,len(pts)-2),2))
        segs=[pts[:cuts[0]],pts[cuts[0]+1:cuts[1]],pts[cuts[1]+1:]]
        dark=0.55+0.4*abs(off)
        for sg in segs:
            if len(sg)<2: continue
            d='M'+' L'.join(f'{f(x)},{f(y)}' for x,y in sg)
            s.append(f'<path d="{d}" fill="none" stroke="#1f1308" stroke-opacity="{dark:.2f}" stroke-width="{1.5 if abs(off)<.8 else 1.1}" stroke-linecap="round"/>')
            # lit crest beside the groove (light from the upper left)
            d2='M'+' L'.join(f'{f(x-0.9)},{f(y-0.3)}' for x,y in sg)
            s.append(f'<path d="{d2}" fill="none" stroke="#c4955f" stroke-opacity="{0.55*(1-abs(off)) + (0.25 if off<0 else 0):.2f}" stroke-width=".7" stroke-linecap="round"/>')
    return f'<g clip-path="url(#{cid})">'+''.join(s)+'</g>'
def barkpart(L,R,C,count,cid,seed,grad='bark',top=0,bot=0):
    d=taper(L,R,top,bot); clips.append(f'<clipPath id="{cid}"><path d="{d}"/></clipPath>')
    return (f'<path d="{d}" fill="url(#{grad})"/>'+ridges(C,count,cid,seed)+
            f'<path d="{d}" fill="url(#vert)"/><path d="{d}" fill="none" stroke="#1a0f06" stroke-width="1.1" stroke-opacity=".8"/>')
def leaf(cx,cy,ln,wd,ang,g='leafL',vein='#2a6a22'):
    # pointed leaf along `ang` degrees (0 = up), base at (cx,cy)
    d=f'M0,0 C{f(wd)},{f(-ln*.25)} {f(wd*.8)},{f(-ln*.75)} 0,{f(-ln)} C{f(-wd*.8)},{f(-ln*.75)} {f(-wd)},{f(-ln*.25)} 0,0 Z'
    v=f'M0,-1 L0,{f(-ln*.88)}'
    side=''.join(f'<path d="M0,{f(-ln*t)} l{f(wd*.55*sg)},{f(-ln*.16)}" stroke="{vein}" stroke-width=".45" stroke-opacity=".6" fill="none"/>' for t in (.3,.5,.68) for sg in (-1,1))
    return (f'<g transform="translate({f(cx)},{f(cy)}) rotate({f(ang)})"><path d="{d}" fill="url(#{g})" stroke="#164a18" stroke-width=".6"/>'
            f'<path d="{v}" stroke="{vein}" stroke-width=".8" stroke-opacity=".8" fill="none"/>{side}</g>')
def bez(p0,p1,p2,p3,n=24):
    out=[]
    for i in range(n+1):
        t=i/n; u=1-t
        out.append((u**3*p0[0]+3*u*u*t*p1[0]+3*u*t*t*p2[0]+t**3*p3[0], u**3*p0[1]+3*u*u*t*p1[1]+3*u*t*t*p2[1]+t**3*p3[1]))
    return out
def poly(pts): return 'M'+' L'.join(f'{f(x)},{f(y)}' for x,y in pts)
def vine(pts,w,seed,dark=False,leaves=3,curl=True,lsize=7):
    # one vine: dark outline, green body, a lit stripe, a few leaves and a tendril curl
    rnd=random.Random(seed); d=poly(pts); o=[]
    body='#2f7d2a' if dark else '#4fae3c'
    o.append(f'<path d="{d}" stroke="#0f3412" stroke-width="{f(w+1.3)}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')
    o.append(f'<path d="{d}" stroke="{body}" stroke-width="{f(w)}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')
    o.append(f'<path d="{poly([(x-w*.22,y-w*.22) for x,y in pts])}" stroke="{"#7fcf55" if dark else "#a8ec78"}" stroke-width="{f(w*.32)}" stroke-opacity=".8" fill="none" stroke-linecap="round"/>')
    n=len(pts)
    for k in range(leaves):
        i=int((k+1)*(n-2)/(leaves+1))+rnd.randint(-1,1); i=max(1,min(n-2,i))
        (x0,y0),(x1,y1)=pts[i-1],pts[i+1]
        ang=math.degrees(math.atan2(x1-x0,-(y1-y0)))+(55 if k%2 else -55)
        o.append(leaf(pts[i][0],pts[i][1],lsize*rnd.uniform(.8,1.1),lsize*.42,ang,'leafD' if dark else 'leafL'))
    if curl:
        (xa,ya),(xb,yb)=pts[-2],pts[-1]; a0=math.atan2(yb-ya,xb-xa); sg=rnd.choice((-1,1)); c=[]
        for i in range(14):
            t=i/13; a=a0+sg*t*4.2; rr=3.2*(1-t*.7)
            c.append((xb+math.cos(a0+sg*math.pi/2)*-3.2*sg*0+ (math.cos(a)-math.cos(a0))*rr*sg*0 + rr*math.cos(a - sg*math.pi/2)+3.2*math.cos(a0+sg*math.pi/2), yb+rr*math.sin(a - sg*math.pi/2)+3.2*math.sin(a0+sg*math.pi/2)))
        o.append(f'<path d="{poly(c)}" stroke="#2f7d2a" stroke-width="{f(max(.8,w*.4))}" fill="none" stroke-linecap="round"/>')
    return ''.join(o)
# ---------- body
body=[]
# legs: root-like, ridged, with curling root toes
for side,seed in ((-1,3),(1,4)):
    L,R,C=limb(80+side*5,196,80+side*8,243,7.5,5.5,bend=side*1.5)
    body.append(barkpart(L,R,C,3,f'leg{seed}',seed,'barkLimb'))
    fx=80+side*8
    for k,(dx,dy,c) in enumerate(((side*9,1,side*4),(side*3,3,side*2),(-side*5,1,-side*3))):
        body.append(f'<path d="M{f(fx)},{241} q{f(c)},{f(dy+2)} {f(dx)},{f(dy)}" stroke="#3a2412" stroke-width="{2.4-k*0.5:.1f}" fill="none" stroke-linecap="round"/>')
# torso: a tapered trunk with a slight lean
def tprof(t):   # hem flare, waist, chest, round shoulders
    pts=[(0,26),(.14,21),(.42,14),(.72,18),(.9,17),(1,12)]
    for (a,wa),(b,wb) in zip(pts,pts[1:]):
        if a<=t<=b:
            u=(t-a)/(b-a); u=u*u*(3-2*u); return wa+(wb-wa)*u
    return 22
L,R,C=limb(80,200,81,120,0,0,bend=-1.5,n=24,prof=tprof)
body.append(barkpart(L,R,C,6,'torso',11,top=3,bot=3))
# the hem: a darker underside lip and a few root tips poking out
body.append(f'<path d="M{f(L[0][0])},{f(L[0][1])} Q80,{f(L[0][1]+8)} {f(R[0][0])},{f(R[0][1])}" stroke="#1a0f06" stroke-width="2.2" fill="none" stroke-opacity=".7"/>')
# knot hole and a lichen spot
body.append('<ellipse cx="84" cy="178" rx="2.4" ry="3.4" fill="#24160b"/><ellipse cx="83.6" cy="177.4" rx="1.4" ry="2.2" fill="#120a04"/><path d="M81.8,175 q2,-2.4 4.4,0" stroke="#c4955f" stroke-width=".8" fill="none" stroke-opacity=".7"/>')
body.append('<g fill="#a8d06a" fill-opacity=".75"><circle cx="75" cy="190" r="1.3"/><circle cx="77" cy="192" r=".9"/><circle cx="74" cy="193" r=".7"/></g>')
# sash: a bundle of three twisted vines across the chest, with leaves and a dangling tendril
sx0,sy0,sx1,sy1=68,166,94,134
for k in range(3):
    ph=k*2*math.pi/3; pts=[]
    for i in range(25):
        t=i/24; x=sx0+(sx1-sx0)*t; y=sy0+(sy1-sy0)*t
        off=2.2*math.sin(t*math.pi*3+ph)
        pts.append((x+off*.6,y+off))
    body.append(vine(pts,2.0,40+k,dark=(k==1),leaves=1 if k else 2,curl=False,lsize=5.5))
body.append(vine(bez((sx0+3,sy0-3),(sx0-2,sy0+6),(sx0+4,sy0+12),(sx0-1,sy0+18),12),1.3,45,leaves=1,lsize=4.5))
# rim of firelight on the right edge of the trunk
body.append(f'<path d="{taper(L,R,3,3)}" fill="url(#rim)" clip-path="url(#torso)"/>')
# arms: branches with twig fingers and a leaf
arms=[]
for side,seed,bend in ((-1,21,-3),(1,22,3)):
    L,R,C=limb(80+side*7,126,80+side*24,174,5,3.2,bend=bend,n=12)
    arms.append(barkpart(L,R,C,3,f'arm{seed}',seed,'barkLimb'))
    hx,hy=80+side*24,174
    for dx,dy in ((side*5,3),(side*1,6),(-side*3,5)):
        arms.append(f'<path d="M{hx},{hy} q{f(dx*.4)},{f(dy*.7)} {f(dx)},{f(dy)}" stroke="#3a2412" stroke-width="1.2" fill="none" stroke-linecap="round"/>')
    arms.append(leaf(hx+side*5,hy+3,11,4.5,side*120,'leafL'))
    # a small leaf bud at the elbow
    arms.append(leaf(80+side*16,150,6,2.6,side*60,'leafD'))
# head: cowl behind, rim leaves, face, leaf scales, sprout, blossom
head=[]
hx,hy=80,96
# hair: a dark mass behind, then vines that sweep from the crown around the face to the shoulders
head.append(f'<path d="M{hx-22},{hy+14} C{hx-30},{hy-14} {hx-16},{hy-40} {hx+1},{hy-44} C{hx+18},{hy-40} {hx+30},{hy-14} {hx+22},{hy+14} C{hx+12},{hy+22} {hx-12},{hy+22} {hx-22},{hy+14} Z" fill="url(#cowl)"/>')
crown=(hx+1,hy-42)
for k in range(7):   # back vines: long, falling past the shoulders
    for sg in (-1,1):
        sp=12+k*4.5
        end=(hx+sg*(17+k*2.2),hy+14+k*3.2)
        pts=bez(crown,(hx+sg*sp*.5,hy-48+k*2),(hx+sg*(sp+10),hy-10+k*2),end)
        head.append(vine(pts,2.4,100+k*2+(sg>0),dark=True,leaves=2,curl=True,lsize=8))
# face: inset in the cowl
head.append(f'<ellipse cx="{hx}" cy="{hy+4}" rx="16.5" ry="17.5" fill="#173f17"/>')
head.append(f'<ellipse cx="{hx}" cy="{hy+5}" rx="15" ry="16" fill="url(#face)"/>')
# faint wood grain on the face
for dx in (-8,-3,3,8):
    head.append(f'<path d="M{hx+dx},{hy-8} q{dx*0.15},{12} 0,{24}" stroke="#9cbc74" stroke-width=".5" stroke-opacity=".5" fill="none"/>')
# eyes, cheeks, smile
for sg in (-1,1):
    ex=hx+sg*6+1
    head.append(f'<ellipse cx="{ex}" cy="{hy+4}" rx="3.4" ry="4.2" fill="url(#eye)"/><circle cx="{ex-1.1}" cy="{hy+2.4}" r="1.3" fill="#f4ffe0"/><circle cx="{ex+1.2}" cy="{hy+5.6}" r=".55" fill="#f4ffe0" fill-opacity=".8"/>')
    head.append(f'<ellipse cx="{hx+sg*10}" cy="{hy+11}" rx="3" ry="1.8" fill="#f2a0a8" fill-opacity=".45"/>')
head.append(f'<path d="M{hx-3},{hy+13} q3,2.6 6,0" stroke="#3d6b2c" stroke-width="1.1" fill="none" stroke-linecap="round"/>')
# front vines framing the face: across the brow and down each cheek
for k,(sp,drop) in enumerate(((19,6),(22,14),(24,24))):
    for sg in (-1,1):
        pts=bez(crown,(hx+sg*sp*.35,hy-34),(hx+sg*(sp+1),hy-16+k*3),(hx+sg*(sp-3),hy+drop))
        head.append(vine(pts,2.6-k*.3,200+k*2+(sg>0),leaves=2,curl=(k==2),lsize=7.5))
for sg in (-1,1):   # a fringe vine curling over the brow
    pts=bez(crown,(hx+sg*4,hy-30),(hx+sg*12,hy-14),(hx+sg*15,hy-10))
    head.append(vine(pts,2.0,210+(sg>0),leaves=1,curl=True,lsize=5.5))
# curled sprout at the peak
head.append(f'<path d="M{hx+2},{hy-44} C{hx+3},{hy-54} {hx+12},{hy-58} {hx+13},{hy-51} C{hx+13},{hy-47} {hx+8},{hy-47} {hx+9},{hy-50}" stroke="#2f7d2a" stroke-width="2.2" fill="none" stroke-linecap="round"/>')
head.append(leaf(hx+3,hy-50,12,5,-28,'leafL'))
# blossom tucked into the hood
bx,by=hx-17,hy-14
for i in range(5):
    a=i*72-10
    head.append(f'<ellipse cx="{f(bx+math.sin(math.radians(a))*3.6)}" cy="{f(by-math.cos(math.radians(a))*3.6)}" rx="2.9" ry="3.6" transform="rotate({a} {f(bx+math.sin(math.radians(a))*3.6)} {f(by-math.cos(math.radians(a))*3.6)})" fill="url(#petal)" stroke="#c9668f" stroke-width=".4"/>')
head.append(f'<circle cx="{bx}" cy="{by}" r="2.2" fill="#ffd34d" stroke="#c99a1e" stroke-width=".5"/><circle cx="{bx-.6}" cy="{by-.6}" r=".7" fill="#fff6c0"/>')
# shadow on the ground
shadow=f'<ellipse cx="80" cy="245" rx="26" ry="5" fill="#000" fill-opacity=".35"/>'
parts={'body':''.join(body),'arms':''.join(arms),'head':''.join(head)}
svg=(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'+defs+''.join(clips)+'</defs>'+
     shadow+f'<g id="arm-back">{arms[0] if False else ""}</g>'+f'<g id="body">{parts["body"]}</g><g id="arms">{parts["arms"]}</g><g id="head">{parts["head"]}</g></svg>')
open(sys.argv[1],'w').write(svg)
