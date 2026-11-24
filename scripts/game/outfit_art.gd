extends RefCounted
## Extra SVG drawn over Char's art for outfits that change his shape, not just
## his colours (Defs.OUTFITS "overlay"). Same viewBox as assets/char/*.svg
## (x 20..180, y 0..252; head flame ~y 12..128, eye ~(100, 92), torso
## y 128..198, legs y 194..250). Inserted just before </svg>, so it covers
## everything; ids are prefixed "o" to stay clear of the base art's.

## Great helm (13th-century style): a riveted iron barrel with a flat crown
## plate, a gold-edged brow band and nasal strip forming a cross (red enamel
## inlay), narrow eye slits with fire licking out of them, and cross-shaped
## breaths on one cheek. The head flame is hidden by the outfit's "swap".
const HELM := """
<defs>
<linearGradient id="oHelm" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#26242b"/><stop offset=".12" stop-color="#5a5664"/><stop offset=".2" stop-color="#8a8596"/><stop offset=".28" stop-color="#46434f"/><stop offset=".62" stop-color="#1e1d24"/><stop offset=".9" stop-color="#0c0b0f"/><stop offset="1" stop-color="#1a1920"/></linearGradient>
<linearGradient id="oCrown" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#6a6674"/><stop offset=".5" stop-color="#34313b"/><stop offset="1" stop-color="#121116"/></linearGradient>
<linearGradient id="oStrip" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#6e6a7a"/><stop offset=".5" stop-color="#2e2c35"/><stop offset="1" stop-color="#131217"/></linearGradient>
<linearGradient id="oGold" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffe9a8"/><stop offset=".45" stop-color="#d4a530"/><stop offset="1" stop-color="#6a4c16"/></linearGradient>
<linearGradient id="oShade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#000" stop-opacity="0"/><stop offset=".75" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".45"/></linearGradient>
<radialGradient id="oGlow"><stop offset="0" stop-color="#ffb238" stop-opacity=".55"/><stop offset="1" stop-color="#ff6a1f" stop-opacity="0"/></radialGradient>
<linearGradient id="oSlit" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff3c4"/><stop offset=".6" stop-color="#ffb238"/><stop offset="1" stop-color="#d8341c"/></linearGradient>
</defs>
<path d="M66 48 L63.5 127 Q100 139 136.5 127 L134 48 Q100 57 66 48Z" fill="url(#oHelm)"/>
<path d="M66 48 L63.5 127 Q100 139 136.5 127 L134 48 Q100 57 66 48Z" fill="url(#oShade)"/>
<ellipse cx="100" cy="47.5" rx="34" ry="7.5" fill="url(#oCrown)"/>
<ellipse cx="100" cy="47.5" rx="34" ry="7.5" fill="none" stroke="url(#oGold)" stroke-width="1.6"/>
<path d="M76 45 Q90 42 104 43" stroke="#a9a4b4" stroke-width="1.2" fill="none" opacity=".5"/>
<g fill="#1a1920" stroke="#8a8596" stroke-width=".5"><circle cx="72" cy="50.5" r="1.3"/><circle cx="84" cy="53.5" r="1.3"/><circle cx="116" cy="53.5" r="1.3"/><circle cx="128" cy="50.5" r="1.3"/></g>
<path d="M65 66 Q100 75 135 66" stroke="#121116" stroke-width="1.4" fill="none" opacity=".8"/>
<path d="M65 67.5 Q100 76.5 135 67.5" stroke="#8a8596" stroke-width=".7" fill="none" opacity=".45"/>
<path d="M64.6 74 Q100 83 135.4 74 L135.4 80 Q100 89 64.6 80Z" fill="url(#oStrip)"/>
<path d="M64.6 74 Q100 83 135.4 74 M64.6 80 Q100 89 135.4 80" stroke="url(#oGold)" stroke-width="1.3" fill="none"/>
<path d="M66 77 Q100 86 134 77" stroke="#8e1418" stroke-width="1.6" fill="none"/>
<path d="M68 81.5 Q82 85.5 95.5 86.5 L95.5 90 Q82 89 68 85Z" fill="#050406"/>
<path d="M104.5 86.5 Q118 85.5 132 81.5 L132 85 Q118 89 104.5 90Z" fill="#050406"/>
<path d="M70 82.6 Q82 86 94 87.2 L94 88.8 Q82 87.8 70 84.2Z" fill="url(#oSlit)"/>
<path d="M106 87.2 Q118 86 130 82.6 L130 84.2 Q118 87.8 106 88.8Z" fill="url(#oSlit)"/>
<ellipse cx="82" cy="80" rx="16" ry="9" fill="url(#oGlow)"/>
<ellipse cx="118" cy="80" rx="16" ry="9" fill="url(#oGlow)"/>
<path d="M96 56.5 L104 56.5 L104.5 133 Q100 133.6 95.5 133Z" fill="url(#oStrip)"/>
<path d="M96 56.5 L95.5 133 M104 56.5 L104.5 133" stroke="url(#oGold)" stroke-width="1.3"/>
<path d="M100 58 L100 132" stroke="#8e1418" stroke-width="1.6"/>
<g fill="url(#oGold)"><circle cx="100" cy="62" r="1.5"/><circle cx="100" cy="98" r="1.5"/><circle cx="100" cy="110" r="1.5"/><circle cx="100" cy="122" r="1.5"/></g>
<g fill="#050406"><path d="M112 99 h2 v-2.5 h2 v2.5 h2 v2 h-2 v2.5 h-2 v-2.5 h-2Z"/><path d="M121 98 h2 v-2.5 h2 v2.5 h2 v2 h-2 v2.5 h-2 v-2.5 h-2Z"/><path d="M112 108 h2 v-2.5 h2 v2.5 h2 v2 h-2 v2.5 h-2 v-2.5 h-2Z"/><path d="M121 107 h2 v-2.5 h2 v2.5 h2 v2 h-2 v2.5 h-2 v-2.5 h-2Z"/><path d="M112 117 h2 v-2.5 h2 v2.5 h2 v2 h-2 v2.5 h-2 v-2.5 h-2Z"/><path d="M121 116 h2 v-2.5 h2 v2.5 h2 v2 h-2 v2.5 h-2 v-2.5 h-2Z"/></g>
<path d="M63.5 122 Q100 134 136.5 122 L136.5 127 Q100 139 63.5 127Z" fill="url(#oStrip)"/>
<path d="M63.5 122 Q100 134 136.5 122 M63.5 127 Q100 139 136.5 127" stroke="url(#oGold)" stroke-width="1.3" fill="none"/>
<g fill="#1a1920" stroke="#8a8596" stroke-width=".5"><circle cx="70" cy="126.5" r="1.3"/><circle cx="82" cy="129.5" r="1.3"/><circle cx="118" cy="129.5" r="1.3"/><circle cx="130" cy="126.5" r="1.3"/><circle cx="68" cy="77.5" r="1.2"/><circle cx="132" cy="77.5" r="1.2"/></g>
<path d="M68.5 60 L67 118" stroke="#c4c0cf" stroke-width="1.4" opacity=".35"/>
<path d="M65 92 L64.2 120" stroke="#9fb2ff" stroke-width="1.6" opacity=".3"/>
<path d="M72 84 C68 78 69 72 72 67 C72.5 72 75 73 76 70 C77 75 80 78 82 85Z" fill="url(#flameO)" opacity=".9"/>
<path d="M80 86 C78 80 80 75 83 72 C83 76 86 77 87 75 C88 79 90 82 90 87Z" fill="url(#flameO)" opacity=".9"/>
<path d="M75 84.5 C74 80 75.5 77 77 75.5 C77.5 78.5 79 80 80 85.5Z" fill="url(#flameM)"/>
<path d="M83 86.5 C82 83 83 80.5 84.5 79 C85 81.5 86.5 83 87 87Z" fill="url(#flameM)"/>
<path d="M128 84 C132 78 131 72 128 67 C127.5 72 125 73 124 70 C123 75 120 78 118 85Z" fill="url(#flameO)" opacity=".9"/>
<path d="M120 86 C122 80 120 75 117 72 C117 76 114 77 113 75 C112 79 110 82 110 87Z" fill="url(#flameO)" opacity=".9"/>
<path d="M125 84.5 C126 80 124.5 77 123 75.5 C122.5 78.5 121 80 120 85.5Z" fill="url(#flameM)"/>
<path d="M117 86.5 C118 83 117 80.5 115.5 79 C115 81.5 113.5 83 113 87Z" fill="url(#flameM)"/>
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

## Seraph Knight: white feathered wings behind Char, the feather tips running
## yellow, orange and red, and a gold halo over his flame (back arc here,
## front arc in ANGEL). Wings are generated (feather fans along each arm) and
## need the wider canvas (Defs.OUTFITS "wide"). Drawn just after </defs>.
const ANGEL_BACK := """
<defs>
<linearGradient id="oFeather" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#ffffff"/><stop offset=".5" stop-color="#f8f3ea"/><stop offset=".68" stop-color="#ffe27a"/><stop offset=".82" stop-color="#ff9a2a"/><stop offset="1" stop-color="#d8261c"/></linearGradient>
<linearGradient id="oCovert" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#ffffff"/><stop offset=".7" stop-color="#f4eee2"/><stop offset=".9" stop-color="#ffe9a0"/><stop offset="1" stop-color="#ffc14a"/></linearGradient>
<linearGradient id="oBone" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#ddd4c4"/></linearGradient>
<linearGradient id="oGold" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff2b8"/><stop offset=".5" stop-color="#e8b83a"/><stop offset="1" stop-color="#8a6420"/></linearGradient>
<radialGradient id="oAura"><stop offset="0" stop-color="#fff3c4" stop-opacity=".35"/><stop offset="1" stop-color="#ffb238" stop-opacity="0"/></radialGradient>
</defs>
<ellipse cx="100" cy="24" rx="34" ry="12" fill="url(#oAura)"/>
<path d="M76 26 Q100 14 124 26" stroke="url(#oGold)" stroke-width="3.2" fill="none" opacity=".85"/>
<g transform="translate(86 140) scale(.86) translate(-86 -140)">
<g transform="translate(44.0 86.0) rotate(-118.0)"><path d="M0 0 C7.1 -10.2 7.5 -40.6 0 -56.4 C-5.2 -45.1 -6.4 -12.4 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -50.8" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(42.6 82.1) rotate(-105.0)"><path d="M0 0 C7.1 -10.8 7.5 -43.1 0 -59.8 C-5.2 -47.9 -6.4 -13.2 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -53.9" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(41.1 78.2) rotate(-92.0)"><path d="M0 0 C7.1 -11.4 7.5 -45.6 0 -63.4 C-5.2 -50.7 -6.4 -13.9 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -57.0" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(39.5 74.5) rotate(-79.0)"><path d="M0 0 C7.1 -12.1 7.5 -48.2 0 -67.0 C-5.2 -53.6 -6.4 -14.7 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -60.3" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(37.8 70.9) rotate(-66.0)"><path d="M0 0 C7.1 -12.5 7.5 -49.9 0 -69.3 C-5.2 -55.4 -6.4 -15.2 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -62.4" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(35.9 67.4) rotate(-53.0)"><path d="M0 0 C7.1 -12.5 7.5 -50.0 0 -69.5 C-5.2 -55.6 -6.4 -15.3 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -62.5" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(34.0 64.0) rotate(-40.0)"><path d="M0 0 C7.1 -12.5 7.5 -50.1 0 -69.6 C-5.2 -55.6 -6.4 -15.3 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -62.6" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(44.0 88.0) rotate(-128.0)"><path d="M0 0 C7.6 -11.5 8.0 -46.1 0 -64.0 C-5.6 -51.2 -6.8 -14.1 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -57.6" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(49.1 97.7) rotate(-135.3)"><path d="M0 0 C7.6 -11.2 8.0 -44.9 0 -62.3 C-5.6 -49.9 -6.8 -13.7 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -56.1" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(54.9 106.9) rotate(-142.7)"><path d="M0 0 C7.6 -10.9 8.0 -43.7 0 -60.7 C-5.6 -48.5 -6.8 -13.3 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -54.6" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(61.5 115.5) rotate(-150.0)"><path d="M0 0 C7.6 -10.6 8.0 -42.5 0 -59.0 C-5.6 -47.2 -6.8 -13.0 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -53.1" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(68.9 123.6) rotate(-157.3)"><path d="M0 0 C7.6 -10.3 8.0 -41.3 0 -57.3 C-5.6 -45.9 -6.8 -12.6 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -51.6" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(77.1 131.1) rotate(-164.7)"><path d="M0 0 C7.6 -10.0 8.0 -40.1 0 -55.7 C-5.6 -44.5 -6.8 -12.2 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -50.1" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(86.0 138.0) rotate(-172.0)"><path d="M0 0 C7.6 -9.7 8.0 -38.9 0 -54.0 C-5.6 -43.2 -6.8 -11.9 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -48.6" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(86.0 138.0) rotate(-152.0)"><path d="M0 0 C6.6 -6.1 7.0 -24.5 0 -34.0 C-4.9 -27.2 -6.0 -7.5 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -30.6" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(79.1 132.5) rotate(-140.8)"><path d="M0 0 C6.6 -5.9 7.0 -23.7 0 -32.9 C-4.9 -26.4 -6.0 -7.2 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -29.6" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(72.2 125.9) rotate(-129.5)"><path d="M0 0 C6.6 -5.7 7.0 -22.9 0 -31.9 C-4.9 -25.5 -6.0 -7.0 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -28.7" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(65.6 118.2) rotate(-118.2)"><path d="M0 0 C6.6 -5.5 7.0 -22.2 0 -30.8 C-4.9 -24.7 -6.0 -6.8 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -27.7" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(59.0 109.5) rotate(-107.0)"><path d="M0 0 C6.6 -5.4 7.0 -21.4 0 -29.8 C-4.9 -23.8 -6.0 -6.5 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -26.8" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(52.6 99.7) rotate(-95.8)"><path d="M0 0 C6.6 -5.2 7.0 -20.7 0 -28.7 C-4.9 -23.0 -6.0 -6.3 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -25.8" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(46.2 88.9) rotate(-84.5)"><path d="M0 0 C6.6 -5.0 7.0 -19.9 0 -27.6 C-4.9 -22.1 -6.0 -6.1 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -24.9" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(40.1 77.0) rotate(-73.2)"><path d="M0 0 C6.6 -4.8 7.0 -19.1 0 -26.6 C-4.9 -21.2 -6.0 -5.8 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -23.9" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(34.0 64.0) rotate(-62.0)"><path d="M0 0 C6.6 -4.6 7.0 -18.4 0 -25.5 C-4.9 -20.4 -6.0 -5.6 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -22.9" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(84.5 133.0) rotate(-146.0)"><path d="M0 0 C6.6 -4.0 7.0 -15.8 0 -22.0 C-4.9 -17.6 -6.0 -4.8 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -19.8" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(77.6 127.5) rotate(-134.8)"><path d="M0 0 C6.6 -3.8 7.0 -15.3 0 -21.3 C-4.9 -17.1 -6.0 -4.7 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -19.2" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(70.8 120.9) rotate(-123.5)"><path d="M0 0 C6.6 -3.7 7.0 -14.8 0 -20.6 C-4.9 -16.5 -6.0 -4.5 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -18.6" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(64.1 113.2) rotate(-112.2)"><path d="M0 0 C6.6 -3.6 7.0 -14.4 0 -19.9 C-4.9 -16.0 -6.0 -4.4 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -17.9" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(57.5 104.5) rotate(-101.0)"><path d="M0 0 C6.6 -3.5 7.0 -13.9 0 -19.2 C-4.9 -15.4 -6.0 -4.2 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -17.3" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(51.1 94.7) rotate(-89.8)"><path d="M0 0 C6.6 -3.3 7.0 -13.4 0 -18.6 C-4.9 -14.9 -6.0 -4.1 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -16.7" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(44.8 83.9) rotate(-78.5)"><path d="M0 0 C6.6 -3.2 7.0 -12.9 0 -17.9 C-4.9 -14.3 -6.0 -3.9 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -16.1" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(38.6 72.0) rotate(-67.2)"><path d="M0 0 C6.6 -3.1 7.0 -12.4 0 -17.2 C-4.9 -13.8 -6.0 -3.8 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -15.5" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(32.5 59.0) rotate(-56.0)"><path d="M0 0 C6.6 -3.0 7.0 -11.9 0 -16.5 C-4.9 -13.2 -6.0 -3.6 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -14.8" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<path d="M86 132 Q56 104 32 60 Q40 68 42 76 Q64 116 88 142Z" fill="url(#oBone)" stroke="#c9bfae" stroke-width=".6"/>
</g>
<g transform="translate(200 0) scale(-1 1) translate(86 140) scale(.86) translate(-86 -140)">
<g transform="translate(44.0 86.0) rotate(-118.0)"><path d="M0 0 C7.1 -10.2 7.5 -40.6 0 -56.4 C-5.2 -45.1 -6.4 -12.4 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -50.8" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(42.6 82.1) rotate(-105.0)"><path d="M0 0 C7.1 -10.8 7.5 -43.1 0 -59.8 C-5.2 -47.9 -6.4 -13.2 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -53.9" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(41.1 78.2) rotate(-92.0)"><path d="M0 0 C7.1 -11.4 7.5 -45.6 0 -63.4 C-5.2 -50.7 -6.4 -13.9 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -57.0" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(39.5 74.5) rotate(-79.0)"><path d="M0 0 C7.1 -12.1 7.5 -48.2 0 -67.0 C-5.2 -53.6 -6.4 -14.7 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -60.3" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(37.8 70.9) rotate(-66.0)"><path d="M0 0 C7.1 -12.5 7.5 -49.9 0 -69.3 C-5.2 -55.4 -6.4 -15.2 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -62.4" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(35.9 67.4) rotate(-53.0)"><path d="M0 0 C7.1 -12.5 7.5 -50.0 0 -69.5 C-5.2 -55.6 -6.4 -15.3 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -62.5" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(34.0 64.0) rotate(-40.0)"><path d="M0 0 C7.1 -12.5 7.5 -50.1 0 -69.6 C-5.2 -55.6 -6.4 -15.3 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -62.6" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(44.0 88.0) rotate(-128.0)"><path d="M0 0 C7.6 -11.5 8.0 -46.1 0 -64.0 C-5.6 -51.2 -6.8 -14.1 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -57.6" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(49.1 97.7) rotate(-135.3)"><path d="M0 0 C7.6 -11.2 8.0 -44.9 0 -62.3 C-5.6 -49.9 -6.8 -13.7 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -56.1" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(54.9 106.9) rotate(-142.7)"><path d="M0 0 C7.6 -10.9 8.0 -43.7 0 -60.7 C-5.6 -48.5 -6.8 -13.3 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -54.6" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(61.5 115.5) rotate(-150.0)"><path d="M0 0 C7.6 -10.6 8.0 -42.5 0 -59.0 C-5.6 -47.2 -6.8 -13.0 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -53.1" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(68.9 123.6) rotate(-157.3)"><path d="M0 0 C7.6 -10.3 8.0 -41.3 0 -57.3 C-5.6 -45.9 -6.8 -12.6 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -51.6" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(77.1 131.1) rotate(-164.7)"><path d="M0 0 C7.6 -10.0 8.0 -40.1 0 -55.7 C-5.6 -44.5 -6.8 -12.2 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -50.1" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(86.0 138.0) rotate(-172.0)"><path d="M0 0 C7.6 -9.7 8.0 -38.9 0 -54.0 C-5.6 -43.2 -6.8 -11.9 0 0Z" fill="url(#oFeather)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -48.6" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(86.0 138.0) rotate(-152.0)"><path d="M0 0 C6.6 -6.1 7.0 -24.5 0 -34.0 C-4.9 -27.2 -6.0 -7.5 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -30.6" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(79.1 132.5) rotate(-140.8)"><path d="M0 0 C6.6 -5.9 7.0 -23.7 0 -32.9 C-4.9 -26.4 -6.0 -7.2 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -29.6" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(72.2 125.9) rotate(-129.5)"><path d="M0 0 C6.6 -5.7 7.0 -22.9 0 -31.9 C-4.9 -25.5 -6.0 -7.0 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -28.7" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(65.6 118.2) rotate(-118.2)"><path d="M0 0 C6.6 -5.5 7.0 -22.2 0 -30.8 C-4.9 -24.7 -6.0 -6.8 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -27.7" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(59.0 109.5) rotate(-107.0)"><path d="M0 0 C6.6 -5.4 7.0 -21.4 0 -29.8 C-4.9 -23.8 -6.0 -6.5 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -26.8" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(52.6 99.7) rotate(-95.8)"><path d="M0 0 C6.6 -5.2 7.0 -20.7 0 -28.7 C-4.9 -23.0 -6.0 -6.3 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -25.8" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(46.2 88.9) rotate(-84.5)"><path d="M0 0 C6.6 -5.0 7.0 -19.9 0 -27.6 C-4.9 -22.1 -6.0 -6.1 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -24.9" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(40.1 77.0) rotate(-73.2)"><path d="M0 0 C6.6 -4.8 7.0 -19.1 0 -26.6 C-4.9 -21.2 -6.0 -5.8 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -23.9" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(34.0 64.0) rotate(-62.0)"><path d="M0 0 C6.6 -4.6 7.0 -18.4 0 -25.5 C-4.9 -20.4 -6.0 -5.6 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -22.9" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(84.5 133.0) rotate(-146.0)"><path d="M0 0 C6.6 -4.0 7.0 -15.8 0 -22.0 C-4.9 -17.6 -6.0 -4.8 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -19.8" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(77.6 127.5) rotate(-134.8)"><path d="M0 0 C6.6 -3.8 7.0 -15.3 0 -21.3 C-4.9 -17.1 -6.0 -4.7 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -19.2" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(70.8 120.9) rotate(-123.5)"><path d="M0 0 C6.6 -3.7 7.0 -14.8 0 -20.6 C-4.9 -16.5 -6.0 -4.5 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -18.6" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(64.1 113.2) rotate(-112.2)"><path d="M0 0 C6.6 -3.6 7.0 -14.4 0 -19.9 C-4.9 -16.0 -6.0 -4.4 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -17.9" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(57.5 104.5) rotate(-101.0)"><path d="M0 0 C6.6 -3.5 7.0 -13.9 0 -19.2 C-4.9 -15.4 -6.0 -4.2 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -17.3" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(51.1 94.7) rotate(-89.8)"><path d="M0 0 C6.6 -3.3 7.0 -13.4 0 -18.6 C-4.9 -14.9 -6.0 -4.1 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -16.7" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(44.8 83.9) rotate(-78.5)"><path d="M0 0 C6.6 -3.2 7.0 -12.9 0 -17.9 C-4.9 -14.3 -6.0 -3.9 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -16.1" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(38.6 72.0) rotate(-67.2)"><path d="M0 0 C6.6 -3.1 7.0 -12.4 0 -17.2 C-4.9 -13.8 -6.0 -3.8 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -15.5" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<g transform="translate(32.5 59.0) rotate(-56.0)"><path d="M0 0 C6.6 -3.0 7.0 -11.9 0 -16.5 C-4.9 -13.2 -6.0 -3.6 0 0Z" fill="url(#oCovert)" stroke="#b8ab96" stroke-width=".6"/><path d="M0 -2 L0 -14.8" stroke="#d9cfbf" stroke-width=".7" opacity=".8"/></g>
<path d="M86 132 Q56 104 32 60 Q40 68 42 76 Q64 116 88 142Z" fill="url(#oBone)" stroke="#c9bfae" stroke-width=".6"/>
</g>
"""

const ANGEL := """
<path d="M76 26 Q100 38 124 26" stroke="url(#oGold)" stroke-width="3.6" fill="none"/>
<path d="M80 28.5 Q100 37 120 28.5" stroke="#fff6d0" stroke-width="1" fill="none" opacity=".8"/>
"""

const OVERLAYS := {"helm": HELM, "robes": ROBES, "angel": ANGEL}
const UNDERLAYS := {"angel": ANGEL_BACK}
