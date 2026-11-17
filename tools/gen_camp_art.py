#!/usr/bin/env python3
"""Builds the 2.5D camp props (stagecoach, resting horse) as shaded SVGs.

The props are modelled as simple 3D shapes (boxes, extruded panels,
cylinders, ellipsoids), projected with the board's camera (ground squash
K = 0.56, see board.gd) and lit by the campfire (warm point light) plus a
cool moonlight from above. The output is scripts/game/camp_art.gd.

Run:  python3 tools/gen_camp_art.py
Coordinates are art pixels: x right, y away from the viewer, z up.
"""
import math
import os

K = 0.56
C = math.sqrt(1.0 - K * K)
TO_CAM = (0.0, -C, K)
INK = "#1a110b"


# ------------------------------------------------------------ vectors
def add(a, b): return (a[0] + b[0], a[1] + b[1], a[2] + b[2])
def sub(a, b): return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def mul(a, s): return (a[0] * s, a[1] * s, a[2] * s)
def dot(a, b): return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def cross(a, b): return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
def length(a): return math.sqrt(dot(a, a))
def norm(a):
    l = length(a)
    return mul(a, 1.0 / l) if l > 1e-9 else (0.0, 0.0, 1.0)
def lerp(a, b, t): return add(a, mul(sub(b, a), t))


def proj(p): return (p[0], -(K * p[1] + C * p[2]))
def depth(p): return C * p[1] - K * p[2]


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def tohex(c):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(v * 255)))) for v in c)


def f(v): return "%.1f" % v


def pts_attr(pts):
    return " ".join("%s,%s" % (f(x), f(y)) for x, y in pts)


def hull(points):
    pts = sorted(set((round(x, 2), round(y, 2)) for x, y in points))
    if len(pts) < 3:
        return pts
    def turn(o, a, b): return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, hi = [], []
    for p in pts:
        while len(lo) >= 2 and turn(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(hi) >= 2 and turn(hi[-2], hi[-1], p) <= 0:
            hi.pop()
        hi.append(p)
    return lo[:-1] + hi[:-1]


# ------------------------------------------------------------ lighting
AMB = (0.20, 0.21, 0.32)
MOON_DIR = norm((0.25, 0.7, 1.0))
MOON = (0.20, 0.24, 0.42)
WARM = (1.30, 0.80, 0.42)
FILL = (0.42, 0.32, 0.24)       # soft firelit fill on faces turned to the camera


class Scene:
    def __init__(self, fire, yaw_deg, falloff):
        self.fire = fire              # fire position in this prop's art space
        self.falloff = falloff
        a = math.radians(yaw_deg)
        self.ca, self.sa = math.cos(a), math.sin(a)
        self.items = []               # (depth, svg)
        self.defs = []
        self.allpts = []
        self._gid = 0

    # model -> scene (yaw about z)
    def xf(self, p):
        return (p[0] * self.ca - p[1] * self.sa, p[0] * self.sa + p[1] * self.ca, p[2])

    def xn(self, n):
        return (n[0] * self.ca - n[1] * self.sa, n[0] * self.sa + n[1] * self.ca, n[2])

    def light(self, base, n, p, warm=1.0):
        lf = sub(self.fire, p)
        d = length(lf)
        lf = mul(lf, 1.0 / d)
        att = 1.0 / (1.0 + (d / self.falloff) ** 2)
        w = max(0.0, dot(n, lf)) * att * warm
        m = max(0.0, dot(n, MOON_DIR))
        fl = max(0.0, dot(n, TO_CAM))
        return tuple(base[i] * (AMB[i] + MOON[i] * m + WARM[i] * w + FILL[i] * fl) for i in range(3))

    def light_dir(self, p):
        lf = norm(sub(self.fire, p))
        return norm(add(mul(lf, 0.8), mul(MOON_DIR, 0.25)))

    def gid(self, prefix):
        self._gid += 1
        return "%s%d" % (prefix, self._gid)

    def add(self, d, svg, pts2=()):
        self.items.append((d, svg))
        self.allpts.extend(pts2)

    # ---------------------------------------------------- faces
    def face_svg(self, wpts, vnormals, base, edge=0.35, warm=1.0):
        """A lit polygon (scene space). Gradient between its darkest and
        brightest vertices gives soft shading. Returns (svg, 2d pts)."""
        cols = [self.light(base, n, p, warm) for p, n in zip(wpts, vnormals)]
        lum = [0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2] for c in cols]
        p2 = [proj(p) for p in wpts]
        i0, i1 = lum.index(min(lum)), lum.index(max(lum))
        if abs(lum[i1] - lum[i0]) < 0.02 or p2[i0] == p2[i1]:
            fill = tohex(cols[i1])
        else:
            g = self.gid("g")
            self.defs.append(
                '<linearGradient id="%s" gradientUnits="userSpaceOnUse" x1="%s" y1="%s" x2="%s" y2="%s">'
                '<stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>'
                % (g, f(p2[i0][0]), f(p2[i0][1]), f(p2[i1][0]), f(p2[i1][1]), tohex(cols[i0]), tohex(cols[i1])))
            fill = "url(#%s)" % g
        if edge > 0:
            st = 'stroke="%s" stroke-opacity="%s" stroke-width="1"' % (INK, edge)
        else:
            st = 'stroke="%s" stroke-width=".8"' % fill
        return ('<polygon points="%s" fill="%s" %s stroke-linejoin="round"/>' % (pts_attr(p2), fill, st), p2)

    def group(self, faces, outline=3.0, extra="", bias=0.0, centre=None):
        """faces: list of (scene pts, vertex normals, base, edge, face normal).
        Culls back faces, sorts the rest far-to-near, adds a dark silhouette."""
        vis = []
        for wpts, vns, base, edge, fn in faces:
            if dot(fn, TO_CAM) <= 1e-4:
                continue
            cen = mul(sum_pts(wpts), 1.0 / len(wpts))
            vis.append((depth(cen), wpts, vns, base, edge))
        if not vis:
            return
        vis.sort(key=lambda t: -t[0])
        body = ""
        p2all = []
        for _, wpts, vns, base, edge in vis:
            s, p2 = self.face_svg(wpts, vns, base, edge)
            body += s
            p2all += p2
        out = ""
        if outline > 0:
            out = '<polygon points="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round"/>' % (
                pts_attr(hull(p2all)), INK, INK, f(outline))
        if centre is None:
            centre = mul(sum_pts([p for v in vis for p in v[1]]), 1.0 / sum(len(v[1]) for v in vis))
        self.add(depth(centre) + bias, "<g>" + out + body + extra + "</g>", p2all)

    # ---------------------------------------------------- primitives (model space in, scene out)
    def box_faces(self, c, size, base, edge=0.35, axes=None):
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        ex, ey, ez = axes or ((1, 0, 0), (0, 1, 0), (0, 0, 1))
        def P(sx, sy, sz):
            return self.xf(add(c, add(add(mul(ex, sx * hx), mul(ey, sy * hy)), mul(ez, sz * hz))))
        faces = []
        quads = [
            ((1, 0, 0), [(1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)]),
            ((-1, 0, 0), [(-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)]),
            ((0, 1, 0), [(-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)]),
            ((0, -1, 0), [(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)]),
            ((0, 0, 1), [(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]),
            ((0, 0, -1), [(-1, -1, -1), (-1, 1, -1), (1, 1, -1), (1, -1, -1)]),
        ]
        for nl, corners in quads:
            n = self.xn(norm(add(add(mul(ex, nl[0]), mul(ey, nl[1])), mul(ez, nl[2]))))
            faces.append(([P(*k) for k in corners], [n] * 4, base, edge, n))
        return faces

    def box(self, c, size, color, edge=0.35, outline=2.6, bias=0.0, axes=None):
        self.group(self.box_faces(c, size, hexc(color), edge, axes), outline, bias=bias)

    def beam(self, a, b, thick, color, outline=2.4, bias=0.0):
        d = sub(b, a)
        ex = norm(d)
        up = (0, 0, 1) if abs(ex[2]) < 0.9 else (0, 1, 0)
        ey = norm(cross(up, ex))
        ez = cross(ex, ey)
        self.box(lerp(a, b, 0.5), (length(d), thick, thick), color, 0.3, outline, bias, (ex, ey, ez))

    def extrude(self, profile, y0, y1, color, smooth_deg=40.0, outline=3.0, extra_fn=None, bias=0.0):
        """Extrudes a CCW (x, z) profile between y0 and y1 (model space)."""
        base = hexc(color)
        n = len(profile)
        en = []
        for i in range(n):
            (x0, z0), (x1, z1) = profile[i], profile[(i + 1) % n]
            en.append(norm((z1 - z0, 0.0, -(x1 - x0))))
        vn = []
        for i in range(n):
            a, b = en[i - 1], en[i]
            vn.append(norm(add(a, b)) if dot(a, b) > math.cos(math.radians(smooth_deg)) else None)
        faces = []
        for i in range(n):
            j = (i + 1) % n
            (x0, z0), (x1, z1) = profile[i], profile[j]
            fn = self.xn(en[i])
            ni = self.xn(vn[i]) if vn[i] else fn
            nj = self.xn(vn[j]) if vn[j] else fn
            pts = [self.xf((x0, y0, z0)), self.xf((x1, y0, z1)), self.xf((x1, y1, z1)), self.xf((x0, y1, z0))]
            smooth = vn[i] is not None and vn[j] is not None
            faces.append((pts, [ni, nj, nj, ni], base, 0.0 if smooth else 0.3, fn))
        for y, s in ((y0, -1.0), (y1, 1.0)):
            fn = self.xn((0.0, s, 0.0))
            pts = [self.xf((x, y, z)) for x, z in (profile if s < 0 else list(reversed(profile)))]
            faces.append((pts, [fn] * len(pts), base, 0.35, fn))
        extra = extra_fn() if extra_fn else ""
        self.group(faces, outline, extra, bias)

    def wheel(self, c, r, w, rim, tire, hub, spokes=12, seg=36):
        """A spoked wheel on an axle along model y."""
        cs = self.xf(c)
        side = 1.0 if dot(self.xn((0, 1, 0)), TO_CAM) > 0 else -1.0
        fy = c[1] + side * w / 2           # the visible face's plane
        def ring_pt(rad, a, y):
            return self.xf((c[0] + rad * math.cos(a), y, c[2] + rad * math.sin(a)))
        tb, tr = hexc(tire), hexc(rim)
        faces = []
        for i in range(seg):
            a0, a1 = TAU * i / seg, TAU * (i + 1) / seg
            n0 = self.xn((math.cos(a0), 0, math.sin(a0)))
            n1 = self.xn((math.cos(a1), 0, math.sin(a1)))
            fn = self.xn(norm((math.cos((a0 + a1) / 2), 0, math.sin((a0 + a1) / 2))))
            pts = [ring_pt(r, a0, c[1] - w / 2), ring_pt(r, a1, c[1] - w / 2),
                   ring_pt(r, a1, c[1] + w / 2), ring_pt(r, a0, c[1] + w / 2)]
            faces.append((pts, [n0, n1, n1, n0], tb, 0.0, fn))
        vis = [fc for fc in faces if dot(fc[4], TO_CAM) > 0]
        vis.sort(key=lambda t: -depth(mul(sum_pts(t[0]), 0.25)))
        body = ""
        p2all = []
        for wpts, vns, base, edge, _ in vis:
            s, p2 = self.face_svg(wpts, vns, base, edge)
            body += s
            p2all += p2
        fnrm = self.xn((0, side, 0))
        # Visible face: iron tire band, then the painted felloe ring.
        def circle(rad, y):
            return [proj(ring_pt(rad, TAU * i / seg, y)) for i in range(seg)]
        outer, mid, inner = circle(r, fy), circle(r * 0.86, fy), circle(r * 0.72, fy)
        p2all += outer
        tcol = tohex(self.light(tb, fnrm, cs))
        rcol = tohex(self.light(tr, fnrm, cs))
        rdark = tohex(mul(self.light(tr, fnrm, cs), 0.6))
        def path(pts):
            return "M" + " L".join("%s %s" % (f(x), f(y)) for x, y in pts) + " Z"
        body += '<path d="%s %s" fill="%s" fill-rule="evenodd"/>' % (path(outer), path(mid), tcol)
        body += '<path d="%s %s" fill="%s" fill-rule="evenodd" stroke="%s" stroke-width="1" stroke-opacity=".5"/>' % (
            path(mid), path(inner), rcol, INK)
        # Spokes.
        hub_c = proj(self.xf((c[0], fy + side * 1.5, c[2])))
        for i in range(spokes):
            a = TAU * i / spokes + 0.13
            e = proj(ring_pt(r * 0.74, a, fy))
            nd = self.xn((math.cos(a), 0, math.sin(a)))
            sc = self.light(tr, norm(add(mul(fnrm, 0.7), mul(nd, 0.5))), cs)
            body += '<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="%s" stroke-linecap="round"/>' % (
                f(hub_c[0]), f(hub_c[1]), f(e[0]), f(e[1]), INK, f(max(2.6, r * 0.1)))
            body += '<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="%s" stroke-linecap="round"/>' % (
                f(hub_c[0]), f(hub_c[1]), f(e[0]), f(e[1]), tohex(sc), f(max(1.4, r * 0.06)))
        # Hub.
        hpts = [proj(ring_pt(r * 0.16, TAU * i / 20, fy + side * 4)) for i in range(20)]
        hcol = self.light(hexc(hub), fnrm, cs)
        g = self.gid("h")
        self.defs.append('<radialGradient id="%s" cx=".35" cy=".3" r=".9"><stop offset="0" stop-color="%s"/>'
                         '<stop offset="1" stop-color="%s"/></radialGradient>' % (
                             g, tohex(mul(hcol, 1.5)), tohex(mul(hcol, 0.55))))
        body += '<polygon points="%s" fill="url(#%s)" stroke="%s" stroke-width="1.6"/>' % (pts_attr(hpts), g, INK)
        out = '<polygon points="%s" fill="none" stroke="%s" stroke-width="3" stroke-linejoin="round"/>' % (
            pts_attr(hull(p2all)), INK)
        self.add(depth(cs), "<g>" + body + out + "</g>", p2all)

    # ---------------------------------------------------- ellipsoids
    def ellipsoid(self, c, d, radii, up=(0, 0, 1)):
        """Returns (scene centre, 3x3 columns) for an ellipsoid whose first
        radius lies along direction d (model space)."""
        e1 = norm(d)
        e2 = cross(up, e1)
        e2 = norm(e2) if length(e2) > 1e-6 else (0, 1, 0)
        e3 = cross(e1, e2)
        cols = [mul(self.xn(e1), radii[0]), mul(self.xn(e2), radii[1]), mul(self.xn(e3), radii[2])]
        return self.xf(c), cols

    def ellipse2d(self, c, cols):
        A = [[cols[k][0] for k in range(3)], [-(K * cols[k][1] + C * cols[k][2]) for k in range(3)]]
        a = sum(A[0][k] ** 2 for k in range(3))
        b = sum(A[0][k] * A[1][k] for k in range(3))
        d = sum(A[1][k] ** 2 for k in range(3))
        tr, det = a + d, a * d - b * b
        disc = math.sqrt(max(0.0, tr * tr / 4 - det))
        l1, l2 = tr / 2 + disc, tr / 2 - disc
        ang = 0.5 * math.atan2(2 * b, a - d)
        return proj(c), math.sqrt(max(l1, 0.01)), math.sqrt(max(l2, 0.01)), math.degrees(ang)

    def blob_svg(self, c, cols, color, grow=0.0, ink=False, edge=0.0, shade=None):
        (cx, cy), rx, ry, ang = self.ellipse2d(c, cols)
        if ink:
            return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" transform="rotate(%s %s %s)" fill="%s"/>' % (
                f(cx), f(cy), f(rx + grow), f(ry + grow), f(ang), f(cx), f(cy), INK)
        if shade is not None:
            return self._ellipse_tag(cx, cy, rx, ry, ang, self.blob_gradient(*shade, color), edge)
        return self._ellipse_tag(cx, cy, rx, ry, ang, self.blob_gradient(c, cols, color), edge)

    def _ellipse_tag(self, cx, cy, rx, ry, ang, g, edge):
        st = ' stroke="%s" stroke-opacity="%s" stroke-width="1.2"' % (INK, edge) if edge > 0 else ""
        return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" transform="rotate(%s %s %s)" fill="url(#%s)"%s/>' % (
            f(cx), f(cy), f(rx), f(ry), f(ang), f(cx), f(cy), g, st)

    def blob_gradient(self, c, cols, color):
        """Radial gradient lighting an ellipsoid: bright where it faces the fire."""
        (cx, cy), rx, ry, ang = self.ellipse2d(c, cols)
        base = hexc(color)
        L = self.light_dir(c)
        # The surface point whose normal faces the light.
        u = norm((dot(cols[0], L) / 1.0, dot(cols[1], L), dot(cols[2], L)))
        hp = add(c, add(add(mul(cols[0], u[0]), mul(cols[1], u[1])), mul(cols[2], u[2])))
        h2 = proj(hp)
        bright = self.light(base, L, hp)
        side = self.light(base, norm(TO_CAM), c)
        dark = self.light(base, mul(L, -1.0), c)
        g = self.gid("b")
        r = max(rx, ry) * 1.7
        self.defs.append(
            '<radialGradient id="%s" gradientUnits="userSpaceOnUse" cx="%s" cy="%s" r="%s">'
            '<stop offset="0" stop-color="%s"/><stop offset=".42" stop-color="%s"/><stop offset="1" stop-color="%s"/>'
            '</radialGradient>' % (g, f(h2[0]), f(h2[1]), f(r), tohex(bright), tohex(side), tohex(dark)))
        return g

    # ---------------------------------------------------- output
    def shadow(self, c, rx, ry, alpha=0.5):
        p = proj(self.xf(c))
        g = self.gid("s")
        self.defs.append('<radialGradient id="%s"><stop offset="0" stop-color="#000" stop-opacity="%s"/>'
                         '<stop offset=".7" stop-color="#000" stop-opacity="%s"/>'
                         '<stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>' % (g, alpha, alpha * 0.6))
        self.add(1e9, '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="url(#%s)"/>' % (
            f(p[0]), f(p[1]), f(rx), f(ry * K), g), [(p[0] - rx, p[1] - ry * K), (p[0] + rx, p[1] + ry * K)])

    def svg(self, pad=10):
        xs = [p[0] for p in self.allpts]
        ys = [p[1] for p in self.allpts]
        x0, y0 = math.floor(min(xs)) - pad, math.floor(min(ys)) - pad
        w, h = math.ceil(max(xs)) + pad - x0, math.ceil(max(ys)) + pad - y0
        body = "".join(s for _, s in sorted(self.items, key=lambda t: -t[0]))
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="%d %d %d %d">'
               '<defs>%s</defs>%s</svg>') % (w, h, x0, y0, w, h, "".join(self.defs), body)
        return svg, (-x0, -y0)


TAU = math.tau


def sum_pts(pts):
    s = (0.0, 0.0, 0.0)
    for p in pts:
        s = add(s, p)
    return s


# ------------------------------------------------------------ stagecoach
def stagecoach():
    # World position (10, -66) at 0.5 art scale: the fire sits in front of it.
    s = Scene(fire=(-20.0, -140.0, 50.0), yaw_deg=-24.0, falloff=260.0)
    RED, GOLD, WHEEL, IRON = "#a3302a", "#e0a838", "#d29a32", "#3a3640"
    ROOF, LEATHER, WOOD = "#5a463c", "#7a4a2c", "#6a4428"

    s.shadow((0, 0, 0), 150, 92, 0.55)
    W = 34.0                                   # half width of the body
    # Wheels (far side first; the painter sorts by depth anyway).
    for y in (W + 14, -(W + 14)):
        s.wheel((-58, y, 46), 46, 8, WHEEL, IRON, GOLD)
        s.wheel((62, y, 36), 36, 8, WHEEL, IRON, GOLD)
    # Undercarriage: axles and the perch.
    s.box((-58, 0, 46), (8, 2 * W + 26, 8), WOOD, outline=2.0)
    s.box((62, 0, 36), (8, 2 * W + 26, 8), WOOD, outline=2.0)
    s.beam((-96, 0, 50), (92, 0, 42), 9, WOOD)
    # Pole for the team, resting on the ground.
    s.beam((92, 0, 40), (172, 0, 5), 7, WOOD)
    s.beam((158, -20, 10), (158, 20, 10), 6, WOOD)

    # The egg-shaped body (side profile, CCW in x/z).
    prof = [(-74, 96), (-70, 76), (-56, 62), (-34, 54), (0, 51), (34, 54), (56, 62), (70, 76), (75, 96),
            (76, 134), (70, 146), (-70, 146), (-76, 134)]

    def body_decals():
        out = ""
        if dot(s.xn((0, -1, 0)), TO_CAM) <= 0:
            return out
        y = -W - 0.6
        def P(x, z): return proj(s.xf((x, y, z)))
        def poly(pts, **kw):
            attrs = " ".join('%s="%s"' % (k.replace("_", "-"), v) for k, v in kw.items())
            return '<polygon points="%s" %s/>' % (pts_attr([P(x, z) for x, z in pts]), attrs)
        def line(pts, col, wdt):
            return '<polyline points="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/>' % (
                pts_attr([P(x, z) for x, z in pts]), col, wdt)
        lit = tohex(s.light(hexc(GOLD), s.xn((0, -1, 0)), s.xf((0, y, 100))))
        # Gold belt line and the curved lower trim.
        out += line([(-74, 112), (75, 112)], INK, 4.4) + line([(-74, 112), (75, 112)], lit, 2.2)
        out += line([(-64, 68), (-34, 58), (0, 55), (34, 58), (64, 68)], lit, 2)
        # Door with its window.
        out += poly([(-20, 60), (20, 60), (20, 138), (-20, 138)], fill="none", stroke=INK, stroke_width="3")
        out += poly([(-20, 60), (20, 60), (20, 138), (-20, 138)], fill="none", stroke=lit, stroke_width="1.4")
        g = s.gid("w")
        a, b = P(-14, 136), P(14, 116)
        s.defs.append('<linearGradient id="%s" gradientUnits="userSpaceOnUse" x1="%s" y1="%s" x2="%s" y2="%s">'
                      '<stop offset="0" stop-color="#1c1820"/><stop offset=".55" stop-color="#3a2a26"/>'
                      '<stop offset="1" stop-color="#ffae62"/></linearGradient>' % (g, f(a[0]), f(a[1]), f(b[0]), f(b[1])))
        for x0, x1 in ((-14, 14), (-62, -30), (30, 62)):
            out += poly([(x0, 116), (x1, 116), (x1, 138), (x0, 138)], fill="url(#%s)" % g, stroke=INK, stroke_width="2.4")
        out += '<circle cx="%s" cy="%s" r="2.6" fill="%s" stroke="%s" stroke-width="1"/>' % (
            f(P(14, 96)[0]), f(P(14, 96)[1]), lit, INK)
        return out

    s.extrude(prof, -W, W, RED, extra_fn=body_decals)
    # Roof with overhang and a low luggage rail.
    s.box((0, 0, 150), (156, 2 * W + 8, 8), ROOF)
    s.box((-38, 0, 166), (44, 44, 24), LEATHER, outline=2.4)
    s.box((10, -2, 162), (34, 36, 16), "#7a5233", outline=2.4)
    s.beam((-76, -W - 3, 160), (76, -W - 3, 160), 3, GOLD, outline=1.6)
    s.beam((-76, W + 3, 160), (76, W + 3, 160), 3, GOLD, outline=1.6)
    # Rear boot (leather-covered luggage).
    s.box((-90, 0, 92), (24, 2 * W - 4, 50), LEATHER)
    # Driver's box: footboard, seat and backrest, plus two lanterns.
    s.box((104, 0, 92), (30, 2 * W + 4, 5), WOOD)
    s.beam((78, 0, 70), (112, 0, 92), 6, WOOD, outline=2.0)
    s.box((86, 0, 122), (22, 2 * W + 4, 7), LEATHER)
    s.box((76, 0, 136), (6, 2 * W + 4, 24), LEATHER)
    for y in (-W - 4, W + 4):
        s.box((80, y, 104), (9, 9, 14), "#ffd27a", outline=2.0)
        s.box((80, y, 113), (11, 11, 4), GOLD, outline=1.6)
    svg, anchor = s.svg()
    return svg, anchor


# ------------------------------------------------------------ horse
def horse():
    # World position (94, 26) at 0.42 art scale: the fire is to its left.
    s = Scene(fire=(-215.0, 60.0, 60.0), yaw_deg=6.0, falloff=650.0)
    COAT, DARK, MANE, HOOF = "#b8703c", "#5a2c16", "#2a170d", "#2a1d18"
    s.shadow((-10, 0, 0), 175, 70, 0.5)
    blobs = []      # (model centre, dir, radii, colour, bias, edge)

    def blob(c, d, r, col=COAT, bias=0.0, edge=0.0, shade=None):
        blobs.append((c, d, r, col, bias, edge, shade))

    # Body.
    blob((0, 0, 40), (1, 0, 0), (70, 38, 36))
    blob((54, 4, 44), (1, 0, 0.1), (36, 37, 37), bias=-4.0)
    blob((-48, 2, 44), (1, 0, 0.2), (30, 32, 33), shade="body")
    # Folded forelegs.
    blob((-28, -26, 12), (1, -0.15, -0.1), (22, 9, 9), edge=0.35)
    blob((-6, -30, 8), (1, 0, 0), (8, 7, 6), HOOF, edge=0.4)
    blob((-36, 26, 12), (1, 0.1, -0.1), (22, 9, 9))
    # Tucked hind leg on the near side.
    blob((50, -26, 28), (-1, 0, -0.35), (30, 14, 20), edge=0.3)
    blob((18, -36, 9), (-1, 0, 0), (20, 7, 7), edge=0.35)
    blob((-4, -37, 8), (-1, 0, 0), (7, 7, 6), HOOF, edge=0.4)
    # Tail along the ground.
    tail = [(90, 2, 46), (104, -2, 32), (116, -10, 16), (126, -20, 6)]
    for i, p in enumerate(tail):
        d = sub(tail[min(i + 1, 3)], tail[max(i - 1, 0)])
        blob(p, d, (13, 7 - i, 7 - i), MANE)

    # The chest shares the barrel's shading so it reads as one body.
    shades = {"body": s.ellipsoid((0, 0, 40), (1, 0, 0), (70, 38, 36))}
    ink, fills = [], []
    for c, d, r, col, bias, edge, shade in blobs:
        sc, cols = s.ellipsoid(c, d, r)
        ink.append(s.blob_svg(sc, cols, col, grow=2.6, ink=True))
        fills.append((depth(sc) + bias, s.blob_svg(sc, cols, col, edge=edge, shade=shades.get(shade))))
        (cx, cy), rx, ry, _ = s.ellipse2d(sc, cols)
        s.allpts += [(cx - rx - 4, cy - ry - 4), (cx + rx + 4, cy + ry + 4)]

    # Plaid blanket draped over the back (quads on the barrel's surface).
    bc, brx, bry, brz = (0, 0, 40), 70.0, 38.0, 36.0
    plaid = []
    nx, na = 9, 12
    for i in range(nx):
        for j in range(na):
            corners = []
            for (ii, jj) in ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)):
                x = -30 + 60.0 * ii / nx
                a = math.radians(-112 + 224.0 * jj / na)
                k = math.sqrt(max(0.0, 1 - (x / brx) ** 2)) * 1.05
                corners.append((bc[0] + x, bc[1] + bry * math.sin(a) * k, bc[2] + brz * math.cos(a) * k))
            cen = mul(sum_pts(corners), 0.25)
            nm = s.xn(norm(((cen[0] - bc[0]) / brx ** 2, (cen[1] - bc[1]) / bry ** 2, (cen[2] - bc[2]) / brz ** 2)))
            if dot(nm, TO_CAM) <= 0:
                continue
            stripe_a, stripe_b = i % 3 == 1, j % 3 == 1
            col = "#d8c8ae" if stripe_a and stripe_b else ("#c98a7c" if stripe_a or stripe_b else "#b8262a")
            wp = [s.xf(p) for p in corners]
            sv, _ = s.face_svg(wp, [nm] * 4, hexc(col), edge=0.0)
            plaid.append((depth(s.xf(cen)), sv))
    # Blanket outline: the edge loop of the grid.
    edge_pts = []
    for (ii, jj) in [(t, 0) for t in range(nx + 1)] + [(nx, t) for t in range(na + 1)] + \
            [(t, na) for t in range(nx, -1, -1)] + [(0, t) for t in range(na, -1, -1)]:
        x = -30 + 60.0 * ii / nx
        a = math.radians(-112 + 224.0 * jj / na)
        k = math.sqrt(max(0.0, 1 - (x / brx) ** 2)) * 1.05
        p = (bc[0] + x, bc[1] + bry * math.sin(a) * k, bc[2] + brz * math.cos(a) * k)
        edge_pts.append(proj(s.xf(p)))
    plaid.sort(key=lambda t: -t[0])
    barrel_depth = depth(s.xf(bc))
    fills.append((barrel_depth - 0.5, "<g>" + "".join(sv for _, sv in plaid) +
                  '<polygon points="%s" fill="none" stroke="%s" stroke-width="2" stroke-linejoin="round" stroke-opacity=".8"/>' % (
                      pts_attr(edge_pts), INK) + "</g>"))

    # Head and neck, held up in a sleepy pose.
    chest_depth = depth(s.xf((-50, 0, 44)))
    neck_ink, neck_svg, head_svg = head_and_neck(s, COAT, DARK, MANE)
    ink.append(neck_ink)
    fills.append((chest_depth + 1.0, neck_svg))
    fills.append((chest_depth - 0.5, head_svg))

    fills.sort(key=lambda t: -t[0])
    s.add(0.0, "<g>" + "".join(ink) + "".join(sv for _, sv in fills) + "</g>")
    return s.svg()


def head_and_neck(s, COAT, DARK, MANE):
    """The neck and head, drawn as smooth side-profile shapes on the horse's
    mid plane (it is seen nearly side-on) and shaded for roundness: lit on
    the front facing the fire, falling into shadow toward the crest.
    Points are (x, z) in the horse's model space; the head points to -x."""
    def P(x, z, y=0.0):
        # Scaled up a touch about the base of the neck.
        return proj(s.xf((-40 + (x + 40) * 1.15, y, 56 + (z - 56) * 1.15)))

    def d(cmds, y=0.0):
        out = []
        for c in cmds:
            out.append(c[0] + " ".join("%s %s" % tuple(f(v) for v in P(x, z, y)) for x, z in c[1:]))
        return " ".join(out)

    def grad(kind, a, b_or_r, stops):
        g = s.gid("n")
        st = "".join('<stop offset="%s" stop-color="%s" stop-opacity="%s"/>' % (o, c, op) for o, c, op in stops)
        if kind == "lin":
            pa, pb = P(*a), P(*b_or_r)
            s.defs.append('<linearGradient id="%s" gradientUnits="userSpaceOnUse" x1="%s" y1="%s" x2="%s" y2="%s">%s</linearGradient>'
                          % (g, f(pa[0]), f(pa[1]), f(pb[0]), f(pb[1]), st))
        else:
            pa = P(*a)
            s.defs.append('<radialGradient id="%s" gradientUnits="userSpaceOnUse" cx="%s" cy="%s" r="%s">%s</radialGradient>'
                          % (g, f(pa[0]), f(pa[1]), f(b_or_r), st))
        return "url(#%s)" % g

    def tone(col, n, at=(-100, 0, 90)):
        return tohex(s.light(hexc(col), s.xn(norm(n)), s.xf(at)))

    lit, mid, shade = tone(COAT, (-1, -0.4, 0.3)), tone(COAT, TO_CAM), tone(COAT, (1, 0.3, 0.2))
    rim = tohex(mul(s.light(hexc(COAT), s.xn(norm((-1, -0.2, 0.4))), s.xf((-110, 0, 100))), 1.25))
    pts = []

    # ---- neck: crest from the withers up to the poll, throat back down to the chest.
    crest = [(-24, 74), (-44, 98), (-66, 120), (-86, 130)]
    neck = [("M", crest[0]), ("C",) + tuple(crest[1:]), ("L", (-92, 104)),
            ("C", (-98, 86), (-92, 64), (-82, 50)), ("C", (-66, 40), (-44, 42), (-26, 54)), ("Z",)]
    nfill = grad("lin", (-96, 80), (-48, 100), [(0, lit, 1), (".55", mid, 1), (1, shade, 1)])
    neck_ink = '<path d="%s" fill="%s" stroke="%s" stroke-width="5.2" stroke-linejoin="round"/>' % (d(neck), INK, INK)
    neck_svg = '<path d="%s" fill="%s"/>' % (d(neck), nfill)
    # Rim of firelight down the front of the neck.
    neck_svg += '<path d="%s" fill="none" stroke="%s" stroke-width="3" stroke-linecap="round" opacity=".55"/>' % (
        d([("M", (-93, 100)), ("C", (-97, 86), (-92, 66), (-84, 54))]), rim)

    # ---- mane along the crest, falling onto the near side in tufts.
    def bez(p, t):
        u = 1 - t
        return tuple(u ** 3 * p[0][k] + 3 * u * u * t * p[1][k] + 3 * u * t * t * p[2][k] + t ** 3 * p[3][k] for k in (0, 1))
    n_s = 9
    top, low = [], []
    for i in range(n_s + 1):
        t = i / n_s
        a, b = bez(crest, max(0, t - 0.01)), bez(crest, min(1, t + 0.01))
        tx, tz = b[0] - a[0], b[1] - a[1]
        l = math.hypot(tx, tz)
        nx, nz = tz / l, -tx / l              # points up/back, away from the neck
        if nz < 0:
            nx, nz = -nx, -nz
        c = bez(crest, t)
        top.append((c[0] + nx * 4, c[1] + nz * 4))
        dep = 8 + (4 if i % 2 else 0) - 2 * t
        low.append((c[0] - nx * dep, c[1] - nz * dep))
    mane = [("M", top[0])]
    for i in range(1, len(top)):
        mane.append(("L", top[i]))
    mane.append(("L", low[-1]))
    for i in range(len(low) - 1, 0, -1):
        mx, mz = (low[i][0] + low[i - 1][0]) / 2, (low[i][1] + low[i - 1][1]) / 2
        mane.append(("Q", (mx + 2, mz - 3), low[i - 1]))
    mane.append(("Z",))
    mfill = grad("lin", (-60, 126), (-60, 96), [(0, tone(MANE, (-0.5, -0.3, 1)), 1), (1, tone(MANE, (0.3, -0.5, -0.2)), 1)])
    neck_svg += '<path d="%s" fill="%s" stroke="%s" stroke-width="2" stroke-linejoin="round"/>' % (d(mane), mfill, INK)
    for i in range(1, n_s, 2):
        c = bez(crest, i / n_s)
        neck_svg += '<path d="%s" fill="none" stroke="%s" stroke-width="1.2" opacity=".5" stroke-linecap="round"/>' % (
            d([("M", (c[0] - 1, c[1] + 2)), ("Q", (c[0] - 4, c[1] - 4), (c[0] - 3, c[1] - 9))]), tone(MANE, (-1, -0.2, 0.5)))

    # ---- far ear (behind the head), tipped back sleepily.
    head = ""
    far_ear = [("M", (-86, 124)), ("C", (-86, 136), (-82, 146), (-77, 150)), ("C", (-76, 141), (-78, 131), (-80, 122)), ("Z",)]
    head += '<path d="%s" fill="%s" stroke="%s" stroke-width="2.4" stroke-linejoin="round"/>' % (
        d(far_ear, 8), shade, INK)

    # ---- head: broad round cheek, straight nose, soft muzzle.
    hd = [("M", (-88, 128)),
          ("C", (-96, 130), (-104, 127), (-106, 122)),        # forehead
          ("C", (-114, 110), (-122, 98), (-129, 86)),         # nose bridge
          ("C", (-134, 78), (-137, 68), (-131, 62)),          # muzzle front
          ("C", (-127, 58), (-119, 59), (-116, 65)),          # lip and chin
          ("C", (-113, 70), (-108, 72), (-104, 72)),          # under the jaw
          ("C", (-94, 73), (-86, 84), (-87, 96)),             # round jowl
          ("C", (-88, 108), (-84, 120), (-88, 128)), ("Z",)]  # throatlatch to poll
    hfill = grad("rad", (-112, 100), 52, [(0, lit, 1), (".5", mid, 1), (1, shade, 1)])
    head += '<path d="%s" fill="%s" stroke="%s" stroke-width="2.8" stroke-linejoin="round"/>' % (d(hd), hfill, INK)
    pts += [P(x, z) for c in hd for x, z in c[1:]]
    # Rounded cheek muscle.
    jc = P(-98, 92)
    jfill = grad("rad", (-102, 96), 16, [(0, rim, ".55"), (1, mid, "0")])
    head += '<ellipse cx="%s" cy="%s" rx="16" ry="17" fill="%s"/>' % (f(jc[0]), f(jc[1]), jfill)
    head += '<path d="%s" fill="none" stroke="%s" stroke-width="1.4" opacity=".45" stroke-linecap="round"/>' % (
        d([("M", (-111, 77)), ("C", (-104, 80), (-92, 82), (-90, 98))]), INK)
    # Darker, velvety muzzle.
    mz = [("M", (-122, 92)), ("C", (-132, 84), (-137, 70), (-131, 62)), ("C", (-127, 58), (-119, 59), (-116, 65)),
          ("C", (-114, 74), (-116, 84), (-122, 92)), ("Z",)]
    mzfill = grad("lin", (-118, 88), (-132, 64), [(0, DARK, "0"), (".55", DARK, ".75"), (1, "#2a140a", ".95")])
    head += '<path d="%s" fill="%s"/>' % (d(mz), mzfill)
    # Firelight along the nose.
    head += '<path d="%s" fill="none" stroke="%s" stroke-width="3" stroke-linecap="round" opacity=".6"/>' % (
        d([("M", (-104, 123)), ("C", (-112, 110), (-120, 98), (-127, 87))]), rim)
    # Nostril and mouth.
    head += '<path d="%s" fill="%s"/>' % (d([("M", (-129, 77)), ("C", (-134, 76), (-134, 71), (-130, 70)),
                                              ("C", (-131, 73), (-130, 75), (-129, 77)), ("Z",)]), INK)
    head += '<path d="%s" fill="none" stroke="%s" stroke-width="1.6" stroke-linecap="round" opacity=".8"/>' % (
        d([("M", (-130, 64)), ("Q", (-125, 62), (-120, 64))]), INK)
    # Leather halter: noseband and cheekpiece with a brass ring.
    strap = d([("M", (-124, 93)), ("Q", (-114, 86), (-104, 80)), ("C", (-98, 94), (-94, 110), (-90, 126))])
    head += '<path d="%s" fill="none" stroke="%s" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round"/>' % (strap, INK)
    head += '<path d="%s" fill="none" stroke="%s" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>' % (
        strap, tone("#7a4a2c", (-1, -0.4, 0.4)))
    rc = P(-104, 80)
    head += '<circle cx="%s" cy="%s" r="3.4" fill="none" stroke="%s" stroke-width="3.6"/>' % (f(rc[0]), f(rc[1]), INK)
    head += '<circle cx="%s" cy="%s" r="3.4" fill="none" stroke="%s" stroke-width="1.8"/>' % (f(rc[0]), f(rc[1]), "#f2c25a")
    # Sleepy closed eye with lashes, and a soft brow.
    e = P(-108, 108)
    head += ('<path d="M%s %s q5 4 10 0" fill="none" stroke="%s" stroke-width="2.4" stroke-linecap="round"/>'
             '<path d="M%s %s l-1.5 3 M%s %s l0 3.4 M%s %s l1.5 3" stroke="%s" stroke-width="1.4" stroke-linecap="round"/>'
             '<path d="M%s %s q6 -4 12 0" fill="none" stroke="%s" stroke-width="2" stroke-linecap="round" opacity=".5"/>') % (
        f(e[0] - 5), f(e[1]), INK, f(e[0] - 2.5), f(e[1] + 2.6), f(e[0]), f(e[1] + 3), f(e[0] + 2.5), f(e[1] + 2.6), INK,
        f(e[0] - 6), f(e[1] - 6), rim)
    # Near ear, upright with a dark inner cup.
    ear = [("M", (-96, 125)), ("C", (-100, 137), (-96, 148), (-90, 153)), ("C", (-86, 145), (-86, 134), (-88, 125)), ("Z",)]
    head += '<path d="%s" fill="%s" stroke="%s" stroke-width="2.6" stroke-linejoin="round"/>' % (
        d(ear, -6), grad("lin", (-96, 126), (-88, 150), [(0, mid, 1), (1, lit, 1)]), INK)
    head += '<path d="%s" fill="%s" opacity=".75"/>' % (d([("M", (-94, 128)), ("C", (-96, 137), (-93, 144), (-90, 148)),
                                                        ("C", (-89, 141), (-89, 134), (-90, 128)), ("Z",)], -6), DARK)
    # Forelock falling over the forehead.
    fl = [("M", (-86, 130)), ("C", (-94, 134), (-102, 128), (-106, 116)), ("C", (-102, 119), (-99, 120), (-97, 119)),
          ("C", (-100, 124), (-96, 127), (-91, 126)), ("Z",)]
    head += '<path d="%s" fill="%s" stroke="%s" stroke-width="2" stroke-linejoin="round"/>' % (d(fl, -4), mfill, INK)
    s.allpts += pts + [P(-70, 150), P(-90, 155)]
    return neck_ink, "<g>" + neck_svg + "</g>", "<g>" + head + "</g>"


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    coach_svg, coach_anchor = stagecoach()
    horse_svg, horse_anchor = horse()
    out = ['extends RefCounted',
           '## GENERATED by tools/gen_camp_art.py; edit that script and re-run it.',
           '## 2.5D art for the stagecoach and the resting horse. *_ANCHOR is the',
           '## ground point (the prop\'s origin) inside each SVG.', '',
           'const STAGECOACH_ANCHOR := Vector2(%s, %s)' % (f(coach_anchor[0]), f(coach_anchor[1])),
           'const HORSE_ANCHOR := Vector2(%s, %s)' % (f(horse_anchor[0]), f(horse_anchor[1])), '',
           'const STAGECOACH_SVG := """%s"""' % coach_svg, '',
           'const HORSE_SVG := """%s"""' % horse_svg, '']
    path = os.path.join(root, "scripts", "game", "camp_art.gd")
    with open(path, "w") as fh:
        fh.write("\n".join(out))
    print("wrote", path)


if __name__ == "__main__":
    main()
