function ivtcpp_deadfeedclip(clip src)
{
    #xdeadfeed = 1011 0111 0111 1111 1011 0101 0111 1011 (big endian)
    return src.mt_lutspa("absolute", expr="x 1 == x 4 == x 8 == x 17 == x 20 == x 22 == x 24 == x 29 == | | | | | | | 0 1 ? ") 
}

function ivtcpp_deadfeedpmatchclip(clip src)
{
    #xdeadfeed = 1011 0111 0111 1111 1011 0101 0111 1011 (big endian)
    # p, n, u matches are 0 in bit 32
    return src.mt_lutspa("absolute", expr="x 1 == x 4 == x 8 == x 17 == x 20 == x 22 == x 24 == x 29 == x 32 == | | | | | | | | 0 1 ? ") 
}

function ivtcpp_checkTFMhints(clip src)
{
    src
    magic_number = converttoy8().crop(0, 0, 32, 1) 
    magic_number = magic_number.mt_logic(magic_number.blankclip(color_yuv=$010101), "and")
    contains_hints = magic_number.mt_logic(magic_number.ivtcpp_deadfeedclip(), "xor")
    return contains_hints.ConditionalFilter(Subtitle("hints found"), Subtitle("hints not found"), "AverageLuma", "==", "0.0")
}

function ivtcpp_ghostbuster(clip src, float "overshoot", bool "hint", bool "dither")
{
    hint = Default(hint, true)
    dither = Default(dither, true)
    overshoot = string(default(overshoot, 1.4))
    src
    
    #separating fields, masking horizontal edges by making simple vertical intrafield edge mask
    odd = separatefields().selectodd().ConverttoY8()
    even = separatefields().selecteven().ConverttoY8()
    infielddiffodd = mt_makediff(odd.separaterows(2).selecteven(),odd.separaterows(2).selectodd()).bilinearresize(width, height/2).mt_lut("x 128 - abs 4 *").ablur(1, 1, 1)
    infielddiffeven = mt_makediff(even.separaterows(2).selecteven(),even.separaterows(2).selectodd()).bilinearresize(width, height/2).mt_lut("x 128 - abs 4 *").ablur(1, 1, 1)
    infielddiff = mt_logic(infielddiffodd, infielddiffeven, "max")
    
    #deghosting even field
    bobbed = bob().selectodd().separatefields().selecteven().ConverttoY8()
    ghost = separatefields().selecteven()
    diff = mt_makediff(bobbed, ghost.ConverttoY8(), u=1, v=1).mt_lut("x 128 - 8 * 128 +").ablur(1, 1)
    exp = "x 128 - 8 / "+overshoot+" * abs y 4 / 1 - 0 max  - 0 max x 128 > 1 -1 ? * 128 + "
    diff = dither ? dither_lutxy8(diff, infielddiff, exp+" 256 *").ditherpost(mode=-1, ampn=1) : mt_lutxy(diff, infielddiff, exp)
    diff_even = diff.converttoyv12()
    deghost = ghost.mt_adddiff(diff, u=2, v=2)
    deghost_frame_even = interleave(deghost, separatefields.selectodd()).weave()
    #deghosting odd field
    
    bobbed = bob().selecteven().separatefields().selectodd().ConverttoY8()
    ghost = separatefields().selectodd()
    diff = mt_makediff(bobbed, ghost.ConverttoY8(), u=1, v=1).mt_lut("x 128 - 8 * 128 +").ablur(1, 1)
    exp = "x 128 - 8 / "+overshoot+" * abs y 4 / 1 - 0 max  - 0 max x 128 > 1 -1 ? * 128 + "
    diff = dither ? dither_lutxy8(diff, infielddiff, exp+" 256 *").ditherpost(mode=-1, ampn=1) : mt_lutxy(diff, infielddiff, exp)
    diff_odd = diff.converttoyv12()
    deghost = ghost.mt_adddiff(diff, u=2, v=2)
    deghost_frame_odd = interleave(separatefields().selecteven(), deghost).weave()

    #hints
    hints = src.converttoy8().crop(0, 0, 33, 1)
    hints = hints.mt_logic(hints.blankclip(color_yuv=$010101), "and")
    pmatch = mt_logic(hints, hints.ivtcpp_deadfeedpmatchclip(), "xor")
    deghost_frame = pmatch.ConditionalFilter(deghost_frame_odd, deghost_frame_even, "AverageLuma()", "==", "0.0", show=false)
    diff                   = pmatch.ConditionalFilter(diff_odd, diff_even, "AverageLuma()", "==", "0.0", show=false)
    #just assume even field first if hints are disabled
    deghost_frame = hint ? deghost_frame : deghost_frame_even
    diff                   = hint ? diff : diff_even
    #conditional disable
    disablecondition  = """br=yplanemax(0.02)
                           dk=yplanemin(0.02)
                          (br>140 || dk<116 || (br < 132 && dk > 124))"""
    deghost_frame = diff.ConditionalFilter(src, deghost_frame, disablecondition, "==", "true", show=false)
    
    return deghost_frame
}

Function SD2_preset_plane(clip src, int "strength", int "num_shift")
{
    strength = Default(strength, 0)
    matrix = (strength < 22) ? 9 : 22
    quant =  (strength < 13) ? strength+1
    \                        : (strength < 22) ? strength*2-11
    \                                          : strength/9+2
    quant = min(30, max(1, quant))
    db = src.SMoothD2(quant=quant, matrix=matrix, num_shift=num_shift)
    return (strength < 0) ? src : db
}

Function SD2_preset(clip src, int "strength", int "strengthC", int "num_shift", bool "display")
{
    strength = Default(strength, 0)
    strengthC = Default(strengthC, strength*2/3)
    display = Default(display, false)
    Y = src.SD2_preset_plane(strength, num_shift)
    UV = interleave(src.UtoY(), src.VtoY()).SD2_preset_plane(strength, num_shift)
    YUV = YtoUV(UV.selecteven(), UV.selectodd(), Y)
    UV = YtoUV(UV.selecteven(), UV.selectodd(), src)
    db = (strength < 0 && strengthC < 0) ? src
    \  : (strengthC < 0 ) ? Y
    \  : (strength < 0 )  ? UV
    \                     : YUV
    db = display && strength>0 ? db.subtitle("deblocked, strength="+string(strength), y=60) : db
    return db
}

Function ivtcpp_blockymask(clip src)
{
    return src.mt_lutspa("absolute", expr = "x 1 + 8 % y 1 + 8 % min 2 < 255 0 ?", u=3, v=3)
    \         .removegrain(12).removegrain(12).mt_lut("x 1.6 *", u=3, v=3).Dither_convert_8_to_16().trim(0,-1).loop(src.framecount())
}

Function ivtcpp_deringmask(clip src, bool "MPEG2")
{
    src
    edge = mt_edge("min/max", 0,255, u=3, v=3)
    blockyrange = edge.logicdownscale(8, "max").desusample(Width(), Height(), 8, point=true).mt_inflate(u=3, v=3)
    range = edge.mt_expand_oct(2).mt_inflate(u=3, v=3)
    range = (Default(MPEG2, false)) ? blockyrange : range
    return mt_lutxy(edge, range, "255 x 18 - 0 max 64 * x y - 16 + 0 max 64 * + -", u=3, v=3).mt_inflate(u=3, v=3).mt_inflate(u=3, v=3)
}

Function ivtcpp_mvdeblock(clip src, string vardeblockfile, string ignorefile, clip "cleanclip", int "trad", int "sad", bool "mpeg2", string "spdeblock", bool "demosquito", bool "cachesuper", bool "lsb", bool "display")
{
    global __mvddisplay = Default(display, false)
    trad = max(1, Default(trad, 2))
    lsb = Default(lsb, false)
    sad = Default(sad, 25)
    demosquito = Default(demosquito, true)
    mpeg2 = Default(mpeg2, true)
    spdeblock = Default(spdeblock, "")
    spdeblock = (spdeblock=="SD2_FILE") ? """ScriptClip("SD2_preset(strength=strength-3, display=__mvddisplay)").ConditionalReader(vardeblockfile, "strength")"""
    \                                   : spdeblock
    deblockscript = """(strength>0) ?  SD2_preset(strength=strength*4 - 3 - abs(ignorestrength), num_shift=2)
                       \            :  SD2_preset(strength=0, num_shift=1)"""
    src = (spdeblock!="") ? src.eval(spdeblock) : src
    anclip = Default(cleanclip, src).ScriptClip(deblockscript).ConditionalReader(vardeblockfile, "strength").ConditionalReader(ignorefile, "ignorestrength").removegrain(12)
    cachesuper = false
    src = cachesuper ? src.requestlinear(clim=trad*2+3, elim=2*trad+3) : src
    w = src.Width()
    h = src.Height()
    # Motion analysis
    super_an = anclip.MSuper ()
    super_an = cachesuper ? super_an.requestlinear(clim=trad*2+3, elim=trad+2) : super_an
    super = src.MSuper (levels=1)
    super = cachesuper ? super.requestlinear(clim=trad*2+3, elim=trad+2) : super
    mv32 = super_an.MAnalyse (delta=trad, multi = true, overlap=4, blksize=32, pzero=300)
    mv8 = super_an.MRecalculate (mv32, tr=trad, thsad=sad*2/3, overlap=2, blksize=8)
    #3 denoised clips merged depending on deblock strength and deblock/dering mask
    denoised1 = src.MDegrainN (super, mv8, trad, thSAD=sad, thSAD2=sad*2/3, lsb=true)
    denoised2 = src.MDegrainN (super, mv8, trad, thSAD=sad*2, thSAD2=sad*4/3, lsb=true)
    denoised3 = src.MDegrainN (super, mv8, trad, thSAD=sad*4, thSAD2=sad*8/3, lsb=true)
    mask = src.ivtcpp_deringmask(mpeg2=mpeg2)
    ivtcpp_blockymask = demosquito ? mt_logic(mask, ivtcpp_blockymask(src), "max") : ivtcpp_blockymask(src)
    denoised12 = (MPEG2 || demosquito) ? denoised1.dither_merge16_8(denoised2, ivtcpp_blockymask, u=3, v=3, luma=false) : denoised1
    denoised23 = (MPEG2 || demosquito) ? denoised2.dither_merge16_8(denoised3, ivtcpp_blockymask, u=3, v=3, luma=false) : denoised2
    denoised =  denoised1.ConditionalSelect("strength<2 ? 0 : strength<5 ? 1 : 2", denoised1, denoised12, denoised23)
    \                            .ConditionalReader(vardeblockfile, "strength")
    return (sad <= 0) ? lsb ? src.to16() : src
    \                 : lsb ? denoised : denoised.ditherpost(mode=0, ampo=0.3, ampn=0.7)
}

Function ivtcpp_shiftcolor(clip src, clip ref, int "block", bool "doublechroma")
{
    w = src.Width()
    h = src.Height()
    ss = Default(block, 4)
    csp = Default(doublechroma, true) ? "YV12" : "YV24"
    ssf = float(ss)
    nw = w/(2*ss)*2
    nh = h/(2*ss)*2
    pw = w%(2*ss)
    ph = h%(2*ss)   
    down = src.nnedi3_resize16(nw, nh, 0, 0, w+pw, h+ph, kernel_d="box", output=csp, cplace="MPEG1", lsb=true)
    ref = ref.nnedi3_resize16(nw, nh, 0, 0, w+pw, h+ph, kernel_d="box", output=csp, cplace="MPEG1", lsb=true)
    diff = dither_sub16(ref, down, u=3, v=3, dif=true)
    \     .nnedi3_resize16(w, h, 0, 0, w/ssf, h/ssf, kernel_u="linear", ratiothr=1024, output="YV12", cplace="MPEG1", lsb_in=true, lsb=true)
    corrected = src.mt_adddiff(diff.Dither_box_filter16(radius=6).dither_removegrain16(12).ditherpost(mode=-1, ampn=1), u=3, v=3)
    return corrected
}

Function ivtcpp_ScriptBDMC(clip src,  clip "anclip", clip "cleanclip", int "mc_colorize", bool "dct", bool "display")
{
    global basesad = 30
    mc_colorize = Default(mc_colorize, 2)
    anclip = Default(anclip, src)
    an = Default(cleanclip, anclip)
    an = an.ScriptClip("SD2_preset(strength=abs(mc_strength))")
    #sad = basesad + int(pow(mc_strength, 0.2)*7)
    dct = Default(dct, false)
    display = Default(display, false)
    super_a = an.MSuper()
    super = src.MSuper(levels = 1)
    v = MAnalyse(super_a, delta=1, multi=true, blksize=32, overlap=0, pglobal=10, pzero=0, lambda=500, searchparam=16)
    v = MRecalculate(super_a, v, blksize=8, overlap=4, pnew=10, thsad=basesad/3, lambda=500, smooth=1, tr=1, dct=dct?1:0)
    b=v.selecteven()
    f=v.selectodd()
    bmask = MMask(src,b,kind=1, ml=basesad, Ysc=255)
    fmask = MMask(src,f,kind=1, ml=basesad, Ysc=255)
    bcomp = MCompensate(src, super, b, thsad=basesad*20)
    fcomp = MCompensate(src, super, f, thsad=basesad*20)
    colorclip = (mc_colorize==3 && Defined(cleanclip)) ?  cleanclip : anclip
    bcomp = (mc_colorize>1) ? ivtcpp_shiftcolor(bcomp, colorclip) : bcomp
    fcomp = (mc_colorize>1) ? ivtcpp_shiftcolor(fcomp, colorclip) : fcomp
    fmask = fmask.converttoy8().mt_expand().mt_expand()
    bmask = bmask.converttoy8().mt_expand().mt_expand()
    fbmask = mt_lutxy(fmask, bmask, "y x - x y + 24 max * 20 / 128 +")
    fbcomp = bcomp.mt_merge(fcomp, fbmask, luma=true,u=3,v=3)
    mn = mt_logic(fmask, bmask, "min")
    
    #use only one frame if other looks useless
    both = interleave(fbcomp, mn.converttoyv12())
    selector = """m=YPlaneMedian() a=Averageluma()
                        (m<2 && a<35) ? 0 : (m>253 && a>220) ? 1 : 2"""
    fbcomp = fbmask.converttoyv12().ConditionalSelect(selector, bcomp, fcomp, fbcomp, show=false)
    mn = fbmask.ConditionalSelect(selector, bmask, fmask, mn, show=false)
    
    script = """mt_lut("x "+string(basesad/(basesad + (pow(abs(mc_strength), 0.2)*7)))+" * 10 - 0 max 245 / 2 ^ 1000 *")"""
    fbtosrcmask = mn.Scriptclip(script).mt_expand().mt_expand(mode="both").mt_inflate()
    merged = fbcomp.mt_merge(src, fbtosrcmask, luma=true, u=3, v=3)
    merged = display ? merged.subtitle("bidirectional motion compensation,", y=100) : merged
    return merged
}

Function ivtcpp_ScriptUDMC(clip src, clip "anclip", clip "cleanclip", int "mc_colorize", bool "isb", bool "dct", bool "display")
{
    global basesad = 30
    mc_colorize = Default(mc_colorize, 0)
    anclip = Default(anclip, src)
    an = Default(cleanclip, anclip)
    an = an.ScriptClip("SD2_preset(strength=abs(mc_strength))")
    #sad = basesad + int(pow(mc_strength, 0.2)*7)
    dct = Default(dct, false)
    display = Default(display, false)
    super_a = an.MSuper()
    super = src.MSuper(levels = 1)
    v = MAnalyse(super_a, isb=isb, delta=1, blksize=32, overlap=0, pglobal=40, pzero=5, lambda=500, searchparam=16)
    v = MRecalculate(super_a, v, blksize=8, overlap=4, pnew=20, thsad=basesad/2, lambda=500, smooth=1, dct=dct?1:0)
    comp = MCompensate(src, super, v, thsad=500)
    colorclip = (mc_colorize==3 && Defined(cleanclip)) ?  cleanclip : anclip
    comp = (mc_colorize>1) ? ivtcpp_shiftcolor(comp, colorclip) : comp
    mask = MMask(src, v,  kind=1, ml=basesad, Ysc=255).converttoy8()
    script = """mt_lut("x "+string(basesad/(basesad + (pow(abs(mc_strength), 0.2)*7)))+" * 15 - 0 max 240 / 2 ^ 1000 *", u=3, v=3)"""
    mask = mask.ScriptClip(script).mt_expand().mt_expand().mt_inflate()
    merged = comp.mt_merge(src, mask, luma=true, u=3, v=3)
    merged = display ? merged.subtitle("motion compensated from " + (isb?"next":"previous")+" frame,", y=100) : merged
    return merged
}

Function ivtcpp_ScriptRad1MC(clip src, clip "anclip", clip "cleanclip", int "mc_colorize", bool "dct", bool "display")
{
    an = Default(anclip, src)
    display = Default(display, false)
    Back = src.ivtcpp_ScriptUDMC(anclip=an.nnedi3(src.Getparity ? 1 : 0), cleanclip=cleanclip, mc_colorize=mc_colorize, isb=true, dct=dct, display=display)
    Forward = src.ivtcpp_ScriptUDMC(anclip=an.nnedi3(src.Getparity ? 0 : 1), cleanclip=cleanclip, mc_colorize=mc_colorize, isb=false, dct=dct, display=display)
    Both = src.ivtcpp_ScriptBDMC(anclip=an.mpeg2stinx2(), cleanclip=cleanclip, mc_colorize=mc_colorize, dct=dct, display=display)
    BothB = src.ivtcpp_ScriptBDMC(anclip=an.nnedi3(src.Getparity ? 1 : 0), cleanclip=cleanclip, mc_colorize=mc_colorize, dct=dct, display=display)
    BothF = src.ivtcpp_ScriptBDMC(anclip=an.nnedi3(src.Getparity ? 0 : 1), cleanclip=cleanclip, mc_colorize=mc_colorize, dct=dct, display=display)
    selector = """(mc_strength==0) ? -1 : (mc_strength>0) ? (mc_isb+1) : (mc_isb+3)"""
    mocomp = src.ConditionalSelect(selector, Both, BothF, BothB, Forward, Back)
    mocomp = display ? mocomp.ScriptClip("""subtitle("strength="+string(mc_strength), y=115)""") : mocomp
    return mocomp
}

Function ivtcpp_ScriptIVTC_X0mc (clip src, bool "draft", string "deint")
{
    draft     = Default (draft,  false)

    pel       = (draft) ? 1 : 2

    src
    src60 = (draft) ? Bob ()
\                   : Defined(deint) ? eval(deint)
\                                    : QTGMC (SourceMatch=3, Lossless=2, tr0=1, tr1=1, tr2=1)
    #60i+24t
    clean  = src60.ScriptClip("SelectEvery (5, 1 - ((50 - frame_ref*2) % 5))")
    jitter  = src60.ScriptClip("ip=((50 - frame_ref*2) % 5) SelectEvery(5, 3-ip, 4-ip)")
    jsup   = jitter.MSuper (pel=pel)
    vect_f = jsup.MAnalyse (isb=false, delta=1, overlap=4)
    vect_b = jsup.MAnalyse (isb=true,  delta=1, overlap=4)
    comp   = jitter.MFlowInter (jsup, vect_b, vect_f, time=50, thSCD1=400)
    fixed  = comp.SelectEvery (2, 0)
    Interleave (clean, fixed)
    txt60 = last.ScriptClip("Trim(min(1, ((50 - frame_ref*2) % 5) / 2), 0)")
    #30p+24t
    clean  = src.scriptclip("SelectEvery (5, -1 - (40 - frame_ref * 2  % 10)%10/2)")
    jitter = src60.ScriptClip("SelectEvery (1, -1 - (40 - frame_ref * 2  % 10) % 10)").DeleteEvery(10, 8).AssumeFPS(9)
    jsup   = jitter.MSuper (pel=pel)
    vect_f = jsup.MAnalyse (isb=false, delta=1, overlap=4)
    vect_b = jsup.MAnalyse (isb=true,  delta=1, overlap=4)
    comp   = jitter.MFlowFPS (jsup, vect_b, vect_f, num=4, den=1, thSCD1=400)
    fixed  = comp.SelectEvery (4, 1, 2, 3)
    InterleaveEvery (clean, fixed, 4, 1, 2, 3)
    txt30 = last.ScriptClip("Trim (Select((40 - frame_ref * 2  % 10) % 10 / 2, 1, 2, 2, 3, 4), 0)")
    
    return src.ConditionalSelect("(frame_ref<5) ? 0 : 1", txt60, txt30)
}

Function ivtcpp_mixedcontent(clip src, clip ivtc, string "filename", int "x1", int "y1", int "x2", int "y2", int "inflate", int "slow", string "deint")
{
    inflate = Default(inflate, 40)
    box = "255 "+lutspa_whitebox(x1, y1, x2, y2, inflate)+" -"#mt_merge 255 bug is real
    #gotta crop to ((x1, y1, x2, y2)+inflate) box
    x1 = max(0, default(x1, 0) - inflate)
    y1 = max(0, default(y1, 0) - inflate)
    x2 = min(default(x2, src.Width()) + inflate, src.Width())
    y2= min(default(y2, src.Height()) + inflate, src.Height())
    crop_r = src.Width - x2
    crop_b = src.Height - y2
    slow = Default(slow, 2)
    srccrop = src.crop(x1, y1, -crop_r, -crop_b)
    mixivtc = srccrop.ivtcpp_ScriptIVTC_X0mc(draft=slow<2, deint=deint).ConditionalReader(filename, "frame_ref")
    mixivtc = mixivtc.AddBorders(x1, y1, crop_r, crop_b).trim(0, -ivtc.FrameCount()).AssumeFPS(ivtc)
    mask = mixivtc.mt_lutspa(mode="absolute", expr=box)
    mixivtc = mixivtc.mt_merge(ivtc, mask, luma=true, u=3, v=3)
    return (slow<1) ? ivtc 
    \               : ivtc.ConditionalSelect("(frame_ref >= 0) ? 0 : 1", mixivtc.scriptclip("subtitle(string(frame_ref))")).ConditionalReader(filename, "frame_ref")
}

function ivtcpp_blockingmask(clip src, bool "compress")
{
    expr = Default(compress, false) ? " 38 - 0 max 0.70 ^ " : ""
    src.ConvertToY8()
    mt_edge("min/max", 1, 255, 1, 255, 3, 3, 3)
    ((width%8 > 0) || (height%8 > 0)) ? addborders(0, 0, (8000-width)%8, (8000-height)%8) : last
    in = separaterows(8).selectevery(8, 1, 2, 3, 4, 5, 6).weaverows(6).separatecolumns(8).selectevery(8, 1, 2, 3, 4, 5, 6).weavecolumns(6).bilinearresize(width/4*3, height/4*3)
    ed = separaterows(8).selectevery(8, 0, 7).weaverows(2).separatecolumns(8).selectevery(8, 0, 7).weavecolumns(2).bilinearresize(width/4*3, height/4*3)
    ratio = mt_lutxy(ed.ablur(1, 1), in.ablur(1, 1), "x y 2 ^ 1 + / 32 * "+expr).ablur(1, 1)
    return ratio
}

Function ivtcpp(clip src, string "fileprefix", clip "cleanclip", int "mc_cleanquality", int "mc_colorize",
\                bool "fieldcleaning", bool "mpeg2", string "spdeblock", int "mvdeblock_sad", bool "demosquito",
\                int "slow", bool "lsb", bool "display")
{
    fileprefix = Default(fileprefix, "")
    nnedifile = fileprefix+"nnedi.txt"
    stinxfile = fileprefix+"m2s2maps.txt"
    deblockfile = fileprefix+"deblock.txt"
    vardeblockfile = fileprefix+"vardeblock.txt"
    mcompfile = fileprefix+"mc_presets.txt"
    mpeg2 = Default(mpeg2, true)
    spdeblock = ucase(Default(spdeblock, mpeg2 ? "SD2_file" : ""))
    spdeblock2 = (spdeblock=="SD2_AN") ? """ScriptClip("SD2_preset(strength=int(YPlaneMax(ivtcpp_blockingmask(true), 7))*min(3, dstrength)/3-1, display=__display)").ConditionalReader(""""+vardeblockfile+"""", "dstrength").ConditionalReader(""""+mcompfile+"""", "mcdstrength")"""
    \                                  : spdeblock 
    spdeblock = (spdeblock=="SD2_AN") ? """ScriptClip("SD2_preset(strength=max(mcdstrength/3, int(YPlaneMax(ivtcpp_blockingmask(true), 7))*min(3, dstrength)/3)-1, display=__display)").ConditionalReader(""""+vardeblockfile+"""", "dstrength").ConditionalReader(""""+mcompfile+"""", "mcdstrength")"""
    \                                 : spdeblock 
    #spdeblock = (spdeblock=="SD2_AN") ? """ScriptClip("subtitle(string(YPlaneMax(ivtcpp_blockingmask, 10)), y=30)")"""
    #\                                 : spdeblock 
    mvdeblock_sad = Default(mvdeblock_sad, 25)
    demosquito = Default(demosquito, true)
    fieldcleaning = Default(fieldcleaning, true)
    slow = Default(slow, 4)
    lsb = Default(lsb, true)
    display = Default(display, false)
    mc_colorize = Default(mc_colorize, 2)
    mc_colorize = (mc_colorize==1) ? Undefined() : mc_colorize
    #Condditional filter needs global vars
    global __display = display
    global blockingmask = ivtcpp_blockingmask(src)
    
    src
    mm = SeparateFields().blur(0.5, 0.2).weave().minmotion(post="3 - 85 *").mt_expand(u=3,v=3).mt_expand(u=3,v=3).mt_inflate(u=3, v=3)
    swh = (slow<1) ? 1 : 2 
    stinx = last.mpeg2stinx2(sw=swh, sh=swh, dither=false)
    stinx = (slow<1) ? stinx : mt_merge(last, stinx, mm, luma=false, u=3, v=3)
    stinx = display ? stinx.subtitle("mpeg2stinx2", y=20) : stinx
    nnedi1 = display ? nnedi3(1).subtitle("nnedi(1)", y=20) : nnedi3(1)
    nnedi1 = display ? nnedi3(1).subtitle("nnedi(1)", y=20) : mt_merge(last, nnedi3(1), mm, luma=false, u=3, v=3)
    nnedi0 = display ? nnedi3(0).subtitle("nnedi(0)", y=20) : nnedi3(0)
    nnedi0 = display ? nnedi3(0).subtitle("nnedi(0)", y=20) : mt_merge(last, nnedi3(0), mm, luma=false, u=3, v=3)
    src.ConditionalSelect("(nnedimode+3) % 3", Getparity() ? nnedi0 : nnedi1, Getparity() ? nnedi1 : nnedi0, stinx)
    \    .ConditionalReader(nnedifile, "nnedimode")
    
    !fieldcleaning ? src : ReplaceFramesSimple(src, last, stinxfile)
    
    spdeblocked = ((slow<1) || (spdeblock == "")) ? last
    \                   : ((spdeblock == "SD2_FILE")) ? last.ScriptClip("SD2_preset(strength=strength-1, display=__display)").ConditionalReader(vardeblockfile, "strength")
    \                                                 : last.eval(spdeblock)    
    
    spdeblocked = (slow<1) ? last : spdeblocked
    
    mvdeblocked = last.ivtcpp_mvdeblock(vardeblockfile, mcompfile, cleanclip=cleanclip, trad=slow-2, sad=mvdeblock_sad, mpeg2=mpeg2,
    \                                   spdeblock=spdeblock, demosquito=demosquito, cachesuper=(slow>2), lsb=lsb, display=display)
    (slow>=4) ? last : mvdeblocked #with slow<4 ivtcpp_mvdeblock is done before mocomp
    
    global __cleanquality = Default(mc_cleanquality, 50)
    mcclip = (Defined(cleanclip) && __cleanquality>=0) ? cleanclip.ConditionalSelect("abs(curstrength)>__cleanquality ? 1 : 0", spdeblocked)
             \                                                    .ConditionalReader(mcompfile, "curstrength")
             \                                         : spdeblocked
    MC = mcclip.ivtcpp_ScriptRad1MC(anclip=src, cleanclip=cleanclip, mc_colorize=mc_colorize, dct=true, display=display)
    \          .ConditionalReader(mcompfile, "mc_strength").ConditionalReader(nnedifile, "mc_isb")
    MC = (slow<4 && lsb) ? MC.Dither_convert_8_to_16() : MC
    mocomped = MC.ConditionalSelect("strength!=0 ? 0 : 1", MC, last).ConditionalReader(mcompfile, "strength")
    mvdeblocked = (slow<4) ? last : mocomped.ivtcpp_mvdeblock(vardeblockfile, mcompfile, cleanclip=cleanclip, trad=slow-2, sad=mvdeblock_sad, mpeg2=mpeg2,
    \                                                         spdeblock=spdeblock2, demosquito=demosquito, cachesuper=(slow>2), lsb=lsb, display=display)
    spdeblocked = lsb ? spdeblocked.Dither_convert_8_to_16() : spdeblocked
    lsb ? mocomped.Dither_convert_8_to_16() : mocomped
    mvdeblocked = (slow<3) ? mocomped.ReplaceFramesSimple(mvdeblocked, deblockfile)
    \                      : mvdeblocked
    res  = (slow<2) ? spdeblocked
    \               :(slow<4) ? mocomped
    \                         : mvdeblocked
    
    #res = display ? res.ScriptClip("""subtitle("frame "+string(current_frame), y=0)""")
    #\             : res
    return res
}
