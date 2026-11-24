extends RefCounted
## Extra SVG drawn over Char's art for outfits that change his shape, not just
## his colours (Defs.OUTFITS "overlay"). Same viewBox as assets/char/*.svg
## (x 20..180, y 0..252; head flame ~y 12..128, eye ~(100, 92), torso
## y 128..198, legs y 194..250). Inserted just before </svg>, so it covers
## everything; ids are prefixed "o" to stay clear of the base art's.

## Great helm: a flat-topped barrel helm, dark iron with gold edging and a red
## cross; flame pours out of the two eye holes and the head flame's tip shows
## above the crown like a crest.
const HELM := """
<defs>
<linearGradient id="oHelm" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#4a4654"/><stop offset=".35" stop-color="#2a2830"/><stop offset="1" stop-color="#0c0b0f"/></linearGradient>
<linearGradient id="oGold" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffe9a8"/><stop offset=".5" stop-color="#d4a530"/><stop offset="1" stop-color="#7a5a1e"/></linearGradient>
<linearGradient id="oRed" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#e0483c"/><stop offset=".6" stop-color="#a8161c"/><stop offset="1" stop-color="#5c0a0e"/></linearGradient>
<radialGradient id="oSlit" cx=".5" cy=".5" r=".6"><stop offset="0" stop-color="#fff3c4"/><stop offset=".5" stop-color="#ffb238"/><stop offset="1" stop-color="#d8341c"/></radialGradient>
</defs>
<path d="M64 130 L64 60 Q64 40 100 37 Q136 40 136 60 L136 130 Q100 141 64 130Z" fill="url(#oHelm)"/>
<path d="M64 130 L64 60 Q64 40 100 37 Q136 40 136 60 L136 130 Q100 141 64 130Z" fill="none" stroke="url(#oGold)" stroke-width="3"/>
<path d="M65 58 Q100 50 135 58" stroke="url(#oGold)" stroke-width="3.5" fill="none"/>
<path d="M66 70 L66 124" stroke="#9fb2ff" stroke-width="2" opacity=".35"/>
<path d="M95 39 L105 39 L105 132 Q100 133 95 132Z" fill="url(#oRed)"/>
<path d="M95 39 L95 132 M105 39 L105 132" stroke="url(#oGold)" stroke-width="1.6"/>
<path d="M65 104 Q100 112 135 104 L135 112 Q100 120 65 112Z" fill="url(#oRed)"/>
<path d="M65 104 Q100 112 135 104 M65 112 Q100 120 135 112" stroke="url(#oGold)" stroke-width="1.6" fill="none"/>
<path d="M70 80 L93 82 L93 91 L70 89Z" fill="#050406"/>
<path d="M107 82 L130 80 L130 89 L107 91Z" fill="#050406"/>
<path d="M72 82 L91 83.5 L91 89 L72 87.5Z" fill="url(#oSlit)"/>
<path d="M109 83.5 L128 82 L128 87.5 L109 89Z" fill="url(#oSlit)"/>
<path d="M72 83 C68 74 70 66 76 60 C76 68 80 70 82 66 C84 72 88 76 90 83Z" fill="url(#flameO)" opacity=".95"/>
<path d="M76 83 C74 77 76 72 79 69 C80 73 84 75 86 83Z" fill="url(#flameM)"/>
<path d="M128 83 C132 74 130 66 124 60 C124 68 120 70 118 66 C116 72 112 76 110 83Z" fill="url(#flameO)" opacity=".95"/>
<path d="M124 83 C126 77 124 72 121 69 C120 73 116 75 114 83Z" fill="url(#flameM)"/>
<g fill="#050406"><circle cx="116" cy="96" r="1.6"/><circle cx="122" cy="96" r="1.6"/><circle cx="128" cy="96" r="1.6"/><circle cx="119" cy="100" r="1.6"/><circle cx="125" cy="100" r="1.6"/><circle cx="84" cy="96" r="1.6"/><circle cx="78" cy="96" r="1.6"/><circle cx="72" cy="96" r="1.6"/><circle cx="81" cy="100" r="1.6"/><circle cx="75" cy="100" r="1.6"/></g>
<g fill="url(#oGold)"><circle cx="69" cy="122" r="2"/><circle cx="131" cy="122" r="2"/><circle cx="69" cy="66" r="2"/><circle cx="131" cy="66" r="2"/></g>
"""

## Greek robes: a white chiton to the shins with a gold meander hem, a blue
## himation over one shoulder pinned with a gold brooch, draped sleeves, a
## gold cord belt and a laurel wreath round the flame. (The armour underneath
## is recoloured to bronze, so the arms and shins read as bracers and greaves.)
const ROBES := """
<defs>
<linearGradient id="oCloth" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#fffdf7"/><stop offset=".55" stop-color="#ece5d6"/><stop offset="1" stop-color="#b9ae99"/></linearGradient>
<linearGradient id="oSash" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#4a72c4"/><stop offset=".6" stop-color="#2a4a94"/><stop offset="1" stop-color="#16285a"/></linearGradient>
<linearGradient id="oGold" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffe9a8"/><stop offset=".5" stop-color="#d4a530"/><stop offset="1" stop-color="#7a5a1e"/></linearGradient>
<pattern id="oKey" x="0" y="223" width="10" height="9" patternUnits="userSpaceOnUse"><rect width="10" height="9" fill="#d4a530"/><path d="M1 8 L1 1 L8 1 L8 6 L4 6 L4 4" stroke="#7a5a1e" stroke-width="1.3" fill="none"/></pattern>
</defs>
<path d="M66 128 Q100 141 134 128 L139 152 Q141 192 144 234 Q100 245 56 234 Q59 192 61 152Z" fill="url(#oCloth)"/>
<path d="M58 222 Q100 232 142 222 L143.5 234 Q100 245 56.5 234Z" fill="url(#oKey)"/>
<path d="M58 222 Q100 232 142 222 M56.5 234 Q100 245 143.5 234" stroke="#7a5a1e" stroke-width="1" fill="none"/>
<g stroke="#a99d86" stroke-width="1.4" fill="none" opacity=".7"><path d="M74 182 Q72 204 70 226"/><path d="M86 184 Q85 206 85 230"/><path d="M100 184 L100 232"/><path d="M114 184 Q115 206 115 230"/><path d="M126 182 Q128 204 130 226"/><path d="M80 146 Q84 162 82 176"/><path d="M120 146 Q116 162 118 176"/></g>
<path d="M62 178 Q100 190 138 178" stroke="url(#oGold)" stroke-width="3.2" fill="none"/>
<path d="M98 186 Q96 196 93 204 M102 186 Q104 196 107 204" stroke="url(#oGold)" stroke-width="2" fill="none"/>
<path d="M64 132 Q72 126 80 134 L140 206 Q140 214 132 214 L118 210 L68 146Z" fill="url(#oSash)"/>
<g stroke="#122048" stroke-width="1.2" fill="none" opacity=".6"><path d="M76 140 L134 208"/><path d="M70 144 L122 208"/></g>
<path d="M66 134 L74 140" stroke="url(#oGold)" stroke-width="1.5"/>
<ellipse cx="56" cy="148" rx="19" ry="13" fill="url(#oCloth)"/>
<ellipse cx="144" cy="148" rx="19" ry="13" fill="url(#oCloth)"/>
<path d="M44 152 Q56 162 68 152 M132 152 Q144 162 156 152" stroke="#a99d86" stroke-width="1.3" fill="none" opacity=".75"/>
<path d="M40 146 Q56 136 72 140 Q66 134 56 134 Q44 136 40 146Z" fill="url(#oSash)"/>
<circle cx="70" cy="138" r="5" fill="url(#oGold)"/><circle cx="70" cy="138" r="2" fill="#7a5a1e"/>
<g fill="url(#oGold)" stroke="#7a5a1e" stroke-width=".6">
<path d="M72 64 Q100 74 128 64" stroke="url(#oGold)" stroke-width="2" fill="none"/>
<ellipse cx="74" cy="62" rx="5" ry="2.4" transform="rotate(-40 74 62)"/>
<ellipse cx="80" cy="67.5" rx="5" ry="2.4" transform="rotate(-25 80 67.5)"/>
<ellipse cx="78" cy="61" rx="4.6" ry="2.2" transform="rotate(-70 78 61)"/>
<ellipse cx="88" cy="70.5" rx="5" ry="2.4" transform="rotate(-12 88 70.5)"/>
<ellipse cx="86" cy="64.5" rx="4.6" ry="2.2" transform="rotate(-60 86 64.5)"/>
<ellipse cx="126" cy="62" rx="5" ry="2.4" transform="rotate(40 126 62)"/>
<ellipse cx="120" cy="67.5" rx="5" ry="2.4" transform="rotate(25 120 67.5)"/>
<ellipse cx="122" cy="61" rx="4.6" ry="2.2" transform="rotate(70 122 61)"/>
<ellipse cx="112" cy="70.5" rx="5" ry="2.4" transform="rotate(12 112 70.5)"/>
<ellipse cx="114" cy="64.5" rx="4.6" ry="2.2" transform="rotate(60 114 64.5)"/>
<circle cx="100" cy="72.5" r="2.2"/>
</g>
"""

const OVERLAYS := {"helm": HELM, "robes": ROBES}
