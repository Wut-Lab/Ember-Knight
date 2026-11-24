# Prints the Seraph Knight's left wing as GDScript constants for scripts/game/outfit_art.gd:
# WING_INNER (forearm), WING_OUTER (hand), and the shoulder and wrist pivots.
import math
def lerp(a,b,t): return a+(b-a)*t
def lp(p,q,t): return (lerp(p[0],q[0],t),lerp(p[1],q[1],t))
def bez(p0,p1,p2,t): return tuple((1-t)**2*p0[i]+2*(1-t)*t*p1[i]+t*t*p2[i] for i in range(2))
tips=[]
def feather(b,a,L,w,grad,shade=True):
    x,y=b; r=math.radians(a)
    tips.append((x+L*math.sin(r), y-L*math.cos(r)))
    p=(f'M0 0 C{w*.95:.1f} {-L*.18:.1f} {w:.1f} {-L*.72:.1f} 0 {-L:.1f} '
       f'C{-w*.7:.1f} {-L*.8:.1f} {-w*.85:.1f} {-L*.22:.1f} 0 0Z')
    g=f'<g transform="translate({x:.1f} {y:.1f}) rotate({a:.1f})"><path d="{p}" fill="url(#{grad})" stroke="#a89a84" stroke-width=".6"/>'
    if shade: g+=f'<path d="M0 -2 L0 {-L*.92:.1f}" stroke="#cfc4b2" stroke-width=".8"/>'
    return g+'</g>'
S,E,W,T=(84,134),(70,64),(42,30),(-4,58)   # shoulder, forearm control, wrist joint, hand tip
fore=lambda t: bez(S,E,W,t)
hand=lambda t: bez(W,(16,34),T,t)
inner, outer = [], []   # forearm piece (turns at the shoulder) and hand piece (turns at the wrist)
# primaries off the hand: long, swinging from down to outward
n=9
for i in range(n):
    t=i/(n-1)
    outer.append(feather(hand(lerp(.12,1,t)),lerp(-172,-112,t),lerp(70,64,t)+10*math.sin(t*math.pi),8,'oFeather'))
# secondaries off the forearm, hanging down; tertials near the body
n=8
for i in range(n):
    t=i/(n-1)
    inner.insert(0,feather(fore(lerp(.12,.95,t)),lerp(-184,-176,t),lerp(46,64,t),8,'oFeather'))
# greater coverts (forearm + hand), then median coverts
for L,da,dy in ((30,4,4),(18,8,1)):
    for i in range(8):
        t=i/7; b=fore(lerp(.1,.98,t)); inner.append(feather((b[0],b[1]+dy),lerp(-182,-170,t)+da,L,7.5,'oCovert',False))
    for i in range(6):
        t=i/5; b=hand(lerp(.08,.9,t)); outer.append(feather((b[0],b[1]+dy),lerp(-170,-120,t)+da,L*.9,7,'oCovert',False))
# alula: little thumb feathers at the wrist, pointing forward
for a,L in ((-80,20),(-62,24),(-44,18)):
    outer.append(feather((W[0]+2,W[1]+2),a,L,5,'oCovert',False))
# bone: forearm and hand as padded limbs, and the wrist joint
def limb(p,c,q,w0,w1):
    return (f'<path d="M{p[0]} {p[1]} Q{c[0]} {c[1]} {q[0]} {q[1]}" stroke="#b9ad98" stroke-width="{w0+2}" stroke-linecap="round" fill="none"/>'
            f'<path d="M{p[0]} {p[1]} Q{c[0]} {c[1]} {q[0]} {q[1]}" stroke="url(#oBone)" stroke-width="{w0}" stroke-linecap="round" fill="none"/>'
            f'<path d="M{p[0]-1} {p[1]-2} Q{c[0]-1} {c[1]-2.5} {q[0]} {q[1]-2.5}" stroke="#ffffff" stroke-width="{w1}" stroke-linecap="round" fill="none" opacity=".9"/>')
inner.append(limb(S,E,W,11,3))
outer.append(limb(W,(16,34),T,7,2))
inner.append(f'<circle cx="{W[0]}" cy="{W[1]}" r="7.5" fill="url(#oBone)" stroke="#a89a84" stroke-width=".8"/>')
inner.append(f'<circle cx="{W[0]-1.5}" cy="{W[1]-2}" r="3" fill="#ffffff"/>')
inner.append(f'<path d="M{W[0]-5} {W[1]+4} Q{W[0]} {W[1]+7} {W[0]+5} {W[1]+4}" stroke="#a89a84" stroke-width=".8" fill="none"/>')
xs=[p[0] for p in tips]; ys=[p[1] for p in tips]
minx,miny=min(xs),min(ys)
# fit inside x >= -36, y >= 4, scaling about the shoulder
k=min(1,(S[0]+36)/(S[0]-minx),(S[1]-4)/(S[1]-miny))
DY = 24   # lowers the whole wing so its root sits behind Char's back
g=f'<g transform="translate({S[0]} {S[1]+DY}) scale({k:.3f}) translate({-S[0]} {-S[1]})">'
place=lambda p: (S[0]+k*(p[0]-S[0]), S[1]+DY+k*(p[1]-S[1]))
# GDScript for scripts/game/outfit_art.gd (left wing; the right one is mirrored about x = 100)
print('const WING_INNER := """'); print(g); print('\n'.join(inner)); print('</g>\n"""\n')
print('const WING_OUTER := """'); print(g); print('\n'.join(outer)); print('</g>\n"""\n')
print('const WING_SHOULDER := Vector2(%.2f, %.2f)' % place(S))
print('const WING_WRIST := Vector2(%.2f, %.2f)' % place(W))
