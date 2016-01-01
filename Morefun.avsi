Function susample(clip src, int "factor", bool "lsb")
{
    f = default(factor, 3)
    lsb = default(lsb, false)
    tw = (src.Width()+f-1)/f
    tw = (tw % 2 == 0) ? tw : (tw+1)
    th16 = (src.Height()/2+f-1)/f
    th16 = ((th16 % 2 == 0) && ! ((src.IsY8) || (src.IsYV24))) ? th16 : (th16+1)
    th8 = (src.Height()+f-1)/f
    th8 = ((th8 % 2 == 0) && ! ((src.IsY8) || (src.IsYV24))) ? th8 : (th8+1)
    useresize16 = (lsb) || (f % 2 == 0) && ((th16 % 2 == 0) && (src.Height() % 4 == 0) || (src.IsY8) || (src.IsYV24))
    th =  useresize16 ? th16 : th8 #point is somehow faster with dither_resize16
    return useresize16 ? src.dither_resize16(tw, th, (f-1)/2,(f-1)/2, tw*f, th*f,"point") : src.pointresize(tw, th, (f-1)/2,(f-1)/2, tw*f, th*f)
}

Function desusample(clip src,int w, int h, int "factor", bool "point")
{
    f = default(factor, Round(w/src.Width))
    point = default(point, true)
    ff = float(f)
    point16 = (f % 2 == 0) && (src.Height()%4 == 0) && (h%4 == 0)
    res = (!point) ? src.bilinearresize(w, h, 0, 0, w/ff, h/ff) : (point16) ? src.dither_resize16(w, h/2, 0, 0, w/ff, h/ff/2, "point"): src.pointresize(w, h, 0, 0, w/ff, h/ff)
    return (f == 1) ? src : res
}

Function mt_expand_ss (clip src, int "radius", int "radiusc", bool "halfchroma", int "subspl", int "prer", bool "square", int "y", int "u", int "v")
{
    ss = Default(subspl, 1)
    prer = Default(prer, 0)
    srad = ss/2 - prer
    halfchroma = Default(halfchroma, false)
    square = Default(square, false)
    radiusc = Default(radiusc, halfchroma ? radius/2 : radius)
    rad1 =  radius % ss  
    rad1 =  (rad1 < srad) ? rad1 + ss : rad1
    rad1c =  radiusc % ss  
    rad1c =  (rad1c < srad) ? rad1c + ss : rad1c
    rad2 = (radius - rad1)  / ss
    rad2c = (radiusc - rad1c)  / ss
    (ss > 1) ? src.mt_expand_sq(rad1,rad1c, halfchroma = false, y=y, u=u, v=v).susample(ss) : src
    (square) ? mt_expand_sq(rad2, rad2c, y=y, u=u, v=v) : mt_expand_oct(rad2, rad2c, y=y, u=u, v=v)
    return last
}

Function mt_inpand_ss (clip src, int "radius", int "radiusc", bool "halfchroma", int "subspl", int "prer", bool "square", int "y", int "u", int "v")
{
    ss = Default(subspl, 1)
    prer = Default(prer, 0)
    srad = ss/2 - prer
    halfchroma = Default(halfchroma, false)
    square = Default(square, false)
    radiusc = Default(radiusc, halfchroma ? radius/2 : radius)
    rad1 =  radius % ss  
    rad1 =  (rad1 < srad) ? rad1 + ss : rad1
    rad1c =  radiusc % ss  
    rad1c =  (rad1c < srad) ? rad1c + ss : rad1c
    rad2 = (radius - rad1)  / ss
    rad2c = (radiusc - rad1c)  / ss
    (ss > 1) ? src.mt_inpand_sq(rad1,rad1c, halfchroma = false, y=y, u=u, v=v).susample(ss) : src
    (square) ? mt_inpand_sq(rad2, rad2c, y=y, u=u, v=v) : mt_inpand_oct(rad2, rad2c, y=y, u=u, v=v)
    return last
}

Function RangeMask (clip src, int "radius", int "radiusc", int "subspl", string "post", bool "noup", int "y", int "u", int "v")
{
    defss = (radius <= 5) ? 1 : (radius < 16) ? 3 : (radius < 36) ? 5 : 7
    subspl = Default(subspl, defss)
    post = Default(post, "")
    noup = Default(noup, false)
    y = Default(y, 3)
    u = Default(u, 1)
    v = Default(v, 1)
    mx  = (radius >  1) ? src.mt_expand_ss (radius=radius, radiusc=radiusc, subspl = subspl, y=y, u=u, v=v) : last
    mn  = (radius >  1) ? src.mt_inpand_ss (radius=radius, radiusc=radiusc, subspl = subspl, y=y, u=u, v=v) : last

    (radius ==  1) ? src.mt_edge (mode="min/max", thY1=0, thY2=255, thC1=0, thC2=255, y=y, u=u, v=v)
\                  : (noup) ? mt_lutxy (mx, mn, "x y - "+post, y=y, u=u, v=v)
\                  : mt_lutxy (mx, mn, "x y - "+post, y=y, u=u, v=v).desusample(src.Width(), src.Height(), subspl, false)
}

Function HD_Edge(clip src, clip "msb", clip "lsb", string "mode", int "depth", int "depthy", int "depthc", \
                            int "thY1", int "thY2", int "thC1", int "thC2", int "y", int "u", int "v", \
                            string "post", bool "hc", int "range", int "subspl")
{
    #mt_edge params
    mode = default(mode, (Defined(range)&& range > 1) ? "range" : "min/max")
    thY1 = default(thY1, 0)
    thY2 = default(thY2, 255)
    thC1 = default(thC1, 0)
    thC2 = default(thC2, 255)
    #additional depth, depth = 2^n means n additional bits
    depth = default(depth, 4)
    depthy = default(depthy, depth)
    depthc = default(depthc, depth)
    divy = 256/depthy
    divc = 256/depthc
    #function usually returns values in [0:128] range, you may want to stretch that, use "none" or "" to skip
    post = default(post, " 2 *")
    post = (post == "none") ? "" : post
    #mask high contrast edges separately
    hc = default(hc, false)
    expry = "x " + string(divy) + " /"
    exprc = "x " + string(divc) + " /"
    lsb = default(lsb,dither_get_lsb(src))
    msb = default(msb,dither_get_msb(src))
    lsb1 = dither_lut16_lsb(msb, lsb, expr=exprc, yexpr=expry, y=y, u=u, v=v)
    lsb2 = lsb1.mt_lut("x 128 + 256 %", y=y, u=u, v=v)
    e1 = (mode == "range") ? lsb1.RangeMask(radius=range, subspl=subspl, post=post, y=y, u=u, v=v)
\                          : lsb1.mt_edge(mode=mode, thY1=thY1, thY2=thY2, thC1=thC1, thC2=thC2, y=y, u=u, v=v)
    e2 = (mode == "range") ? lsb2.RangeMask(radius=range, subspl=subspl, post=post, y=y, u=u, v=v)
\                          : lsb2.mt_edge(mode=mode, thY1=thY1, thY2=thY2, thC1=thC1, thC2=thC2, y=y, u=u, v=v)
    res = (post==""  || mode =="range") ? mt_logic(e1, e2, mode = "min", y=y, u=u, v=v) 
\                                                                : mt_lutxy(e1, e2, "x y min " + post, u=u, v=v)
    thY2 = 256/divy
    thC2 = 256/divc
    res = (Defined(subspl)) ? res.desusample(lsb.width, lsb.height, subspl, false) : res
    return (!hc) ? res : res.mt_logic(msb.mt_edge(mode=mode, thY1=thY2, thY2=thY2, thC1=thC2, thC2=thC2, y=y, u=u, v=v), "or")
}

Function PlanesMax(clip src)
{
    src
    w = Width()
    h = Height()
    y = Converttoy8().BilinearResize(w/2,h/2)
    u = UtoY8()
    v = VtoY8()
    return y.mt_logic(mt_logic(u, v,"max"), "max")
}

Function lut_xy8(clip src1, clip src2, string "expr", int "y", int "u", int "v")
{
    u = (!src1.IsY8() && src2.IsY8 && (u==3 || u==4)) ? 2 : u
    v = (!src1.IsY8() && src2.IsY8 && (v==3 || v==4)) ? 2 : v
    u = (src1.IsY8() && !src2.IsY8 && (u==2 || u==4)) ? 6-u : u
    v = (src1.IsY8() && !src2.IsY8 && (v==2 || v==4)) ? 6-v : v
    return (src1.IsY8 && !src2.IsY8()) ? lut_xy8(src2, src1, expr, y=y, u=v,v=v)
\                                                          : mt_lutxy(src1, src2, expr, y=y, u=v,v=v)
}

Function MergeMasks(clip src1, clip src2)
{
    #255 - (255-y)*(255-x)/255 = x + y - xy/255
    return lut_xy8(src1, src2, "x y + x y * 255 / -", u=3,v=3)
}

Function Cx2(clip src, bool "MPEG2", bool "lsb", string "kernel")
{
    shift = (Default(MPEG2, true)) ? 0.25 : 0
    src
    w = Width()
    h = Height()
    return Default(lsb, False) ? Dither_resize16(w, h/2, shift, kernel=kernel) : bilinearresize(w*2, h*2, shift)
}

Function MergePlanes(clip src)
{
    src
    y = ConvertToY8()
    u = UToY8()
    v = VToY8()
    uv = MergeMasks(u, v).Cx2()
    return MergeMasks(y, uv)
}

Function MoreFun (clip src, float "thr", int "radius", float "elast",
\    int "mask", int "mode", float "ampo", float "ampn", int "pat",
\    bool "dyn", float "dthr", int "smode", float "wmin", float "thr_det",
\    int "debug", int "subspl", bool "lsb", bool "lsb_in",
\    bool "staticnoise", float "thrc", int "radiusc", float "elastc",
\    int "y", int "u", int "v", clip "ref",
\ clip "maskclip", bool "chromamask", bool "mixedmask", int "thr_detc",
\ int "bigmode", int "bigrad", float "bigthr", float "bigthr_det")
{
    thr     = Default (thr,       0.35)
    thrc    = Default (thrc,       thr)
    radius  = Default (radius,      12)
    radiusc = Default (radiusc, radius)
    elast   = Default (elast,      3.0)
    elastc  = Default (elastc,   elast)
    mask    = Default (mask,         2)
    smode   = Default (smode,        2)
    wmin    = Default (wmin,       1.0)
    thr_det = Default (thr_det, 2 + Round (Dither_max (thr - 0.35, 0) / 0.3))
    thr_detc = Default (thr_detc, thr_det)
    debug   = Default (debug,        0)
    subspl  = Default (subspl,       0)
    lsb     = Default (lsb,      true)
    lsb_in  = Default (lsb_in,   true)
    ref     = Default (ref,        src)
    bigrad = Default(bigrad, min(91, radius * 3))
    bigmode = Default(bigmode, -1)
    bigthr = Default(bigthr, thr)
    bigthr_det = string(Default(bigthr_det, Round((bigthr+0.2)*2)))
    mixedmask = Default (mixedmask,  false)
    chromamask = Default (chromamask,  false)
    
    # Input range check. The other parameters are checked by the plugins.
    Assert (radius  > 0, "MoreFun: "+chr(34)+"radius" +chr(34)+" must be strictly positive.")
    Assert (bigrad  > 0, "MoreFun: "+chr(34)+"bigrad" +chr(34)+" must be strictly positive.")
    Assert (radiusc > 0, "MoreFun: "+chr(34)+"radiusc"+chr(34)+" must be strictly positive.")
    Assert (thr     > 0, "MoreFun: "+chr(34)+"thr"    +chr(34)+" must be strictly positive.")
    Assert (thrc    > 0, "MoreFun: "+chr(34)+"thrc"   +chr(34)+" must be strictly positive.")
    Assert (thr_det > 0, "MoreFun: "+chr(34)+"thr_det"+chr(34)+" must be strictly positive.")
    Assert (thr_detc> 0, "MoreFun: "+chr(34)+"thr_detc"+chr(34)+" must be strictly positive.")
    Assert (elast  >= 1, "MoreFun: "+chr(34)+"elast"  +chr(34)+" must be greater or equal to 1.")
    Assert (elastc >= 1, "MoreFun: "+chr(34)+"elastc" +chr(34)+" must be greater or equal to 1.")
    
    src_8  = (lsb_in) ? src.DitherPost (mode=-1) : src
    src_16 = (lsb_in) ? src : src.Dither_convert_8_to_16 ()
    ref_16 = (lsb_in) ? ref : ref.Dither_convert_8_to_16 ()
    yv411_flag = src.Dither_isyv411 ()

    # Main debanding

    yp     = (! Defined (y) || (y == 3)) ? 3 : 1
    up     = (! Defined (u) || (u == 3)) ? 3 : 1
    vp     = (! Defined (v) || (v == 3)) ? 3 : 1

    chroma_flag = (  (thrc != thr || radiusc != radius || elastc != elast)
\                   && yp == 3 && (up == 3 || vp == 3))
    up2    = (chroma_flag) ? 1 : up
    vp2    = (chroma_flag) ? 1 : vp

    # Edge/detail mask

    td_lo  = Dither_max (thr_det * 0.75, 1)
    td_hi  = Dither_max (thr_det,        1)
    td_loc  = Dither_max (thr_detc * 0.75, 1)
    td_hic  = Dither_max (thr_detc,        1)
    mexpr  = Dither_make_expr_gate (td_lo, td_hi)
    mexprc  = Dither_make_expr_gate (td_loc, td_hic)
    my = yp
    mu = (chromamask || mixedmask) ? up : 1
    mv = (chromamask || mixedmask) ? vp : 1
    extramask = Defined (maskclip)
    maskclip = Default(maskclip, src_8)
    dmask  = (mask > 0 && yv411_flag) ? src_8.ConvertToY8 ()       : src_8
    dmask  = (mask > 0) ? dmask.RangeMask (mask, y=my, u=mu, v=mv) : dmask
    dmask  = (mask > 0) ? dmask.mt_lut (expr=mexprc, yexpr=mexpr, u=mu,v=mv)                : dmask
    dmask = (mask > 0) ? ((mixedmask && extramask && maskclip.IsYV12()) ? MergeMasks(maskclip, dmask).MergePlanes() :
\                        (mixedmask && extramask) ? MergeMasks(maskclip.MergePlanes(), dmask.MergePlanes()) :
\                        (extramask && mask>0) ? MergeMasks(maskclip, dmask) :
\                        (extramask) ? maskclip :
\                        (mixedmask) ? dmask.MergePlanes()
\                                    : dmask)
\                        : extramask
    dmask  = (mask > 0) ? dmask.removegrain (22, (chromamask) ? mu : -1)   : dmask
    dmask  = (mask > 1) ? dmask.removegrain (11, (chromamask) ? mu : -1)   : dmask
    dmask  = (mask > 2) ? dmask.removegrain (20, (chromamask) ? mu : -1)   : dmask
    dmask  = (mask > 0 && yv411_flag) ? dmask.ConvertToYV411 ()    : dmask
    
    bigmask = (bigmode <  2) ? src_8.ConvertToY8 ().RangeMask(bigrad * 2 / 3, y=my, u=2, v=2, post=string(bigthr_det)+"  - abs 128 * ")
\                                              : src_16.ConvertToY8 ().HD_edge(depth = bigmode, range = bigrad * 2 / 3, y=my, u=2, v=2, post=string(bigmode)+" / "+bigthr_det+" - 128 *")    
    bigbl_16 = (bigmode > 0) ? src_16.dither_bilateral16(radius=bigrad, thr=bigthr*4.5, wmin=0.8, flat=0.9, subspl=bigrad * 6, u=2, v=2).Dither_limit_dif16(ref_16, thr=bigthr, elast=3.00, y=3, u=2, v=2)
\                                                   : src_16.dither_smoothgrad(radius=bigrad, thr=bigthr)    
    merged = ConditionalFilter(bigmask, dither_merge16_8(bigbl_16, src_16, bigmask, luma = true), src_16, "AverageLuma()", "<","250")
    src_16 = (bigmode < 0) ? src_16  : merged
    src_16
    flt_y  =                 Dither_gf3_smooth (last, src_8, ref_16, smode, radius,  thr,  elast,  lsb_in, wmin, subspl, yp, up2, vp2)
    flt_c  = (chroma_flag) ? Dither_gf3_smooth (last, src_8, ref_16, smode, radiusc, thrc, elastc, lsb_in, wmin, subspl, 1,  up,  vp) : flt_y
    flt    = (chroma_flag) ? flt_y.MergeChroma (flt_c) : flt_y
    
    res_16 = ((mask > 0) || extramask) ? Dither_merge16_8 (flt, src_16, dmask, luma=(! chromamask), y=yp, u=up, v=vp) : flt
    
    # Dithering

    result = (lsb) ? res_16 : res_16.DitherPost (
\        mode=mode, ampo=ampo, ampn=ampn, pat=pat, dyn=dyn,
\        prot=false, thr=dthr, staticnoise=staticnoise,
\        y=yp, u=up, v=vp
\    )
    result = (lsb)
\        ? Dither_switch_planes16 (src_16, result, y=y, u=u, v=v)
\        : Dither_switch_planes8  (src_8,  result, y=y, u=u, v=v)

    (debug == 1       ) ? dmask    : result
    (debug == 1 && lsb) ? last.converttoyv12().stackvertical(bigmask.converttoyv12()) : last
    (debug == 2      ) ? src_16 : last
    return last
}

Function box8(clip src, int "radius", int "radius2", int "radius3", int "y", int "u", int "v", int "mode")
{
    mode = Default(mode, -1)
    box = src.Dither_convert_8_to_16().Dither_box_filter16(radius=radius, y=y, u=u, v=v)
    box = Defined(radius2) ? box.Dither_box_filter16(radius=radius2, y=y, u=u, v=v) : box
    box = Defined(radius3) ? box.Dither_box_filter16(radius=radius3, y=y, u=u, v=v) : box
    return (mode<-1) ? box.dither_get_msb() : box.ditherpost(mode = mode, y=y, u=u, v=v)
}

function adddiff16_8_8(clip a, clip b, clip c, int "y", int "u", int "v")
{
    diff = mt_makediff(b, c, y=y, u=u, v=v)
    msb = a.dither_get_msb().mt_adddiff(diff, y=y, u=u, v=v)
    lsb = a.dither_get_lsb()
    return stackvertical(msb,lsb)
}

Function Dither_round(clip src, int "depth", bool "reducerange")
{
    depth = Default(depth, 10)
    reducerange = Default(reducerange, false)
    step = BitSal(1, 16-depth)
    sstep = string(step)
    lsb = dither_get_lsb(src)
    msb = dither_get_msb(src)
    reducedrange = src.dither_lut16("x "+sstep+" / round", u=3, v=3)
    msb = mt_lutxy(lsb, msb, "x "+string(256 - step/2)+" >= y 1 + y ?", u=3, v=3)
    lsb = mt_lut(lsb, string(256+step)+" x - "+string(step/2-1)+" + "+sstep+" % "+string(step/2-1)+" - x + 256 %", u=3, v=3)
    keptrange = stackvertical(msb,lsb)
    return reducerange ? reducedrange : keptrange
}

function average16(clip src1, clip src2, int "y", int "u", int "v")
{
    u = Default(u, 3)
    v = Default(v, 3)
    half = src1.blankclip(height = src1.height()/2, color_yuv =$808080).dither_convert_8_to_16()
    return src1.dither_merge16(src2, half, y=y, u=u, v=v)
}

function Dfttest_ss(clip src, int "subspl", bool "Y", bool "U", bool "V", int "ftype", float "sigma", float "sigma2", float "pmin",
\                    float "pmax", int "sbsize", int "smode", int "sosize", int "tbsize", int "tmode",
\                    int "tosize", int "swin", int "twin", float "sbeta", float "tbeta", bool "zmean",
\                    string "sfile", string "sfile2", string "pminfile", string "pmaxfile", float "f0beta",
\                    string "nfile", int "threads", int "opt", string "nstring", string "sstring",
\                    string "ssx", string "ssy", string "sst", int "dither", bool "lsb", bool "lsb_in",
\                    bool "quiet")
{
        src
        w = Width()
        h = Height()/2
        ss = Default(subspl, (w>1300) ? 3 : 2)
        nw = w/(2*ss)*2
        nh = h/(2*ss)*2
        Y = Default(Y, True)
        U = Default(U, True)
        V = Default(V, True)
        yp = (Y) ? 3 : 1
        up = (U) ? 3 : 1
        vp = (V) ? 3 : 1
        ss = dither_resize16(nw, nh,kernel = "lanczos", y=yp, u=up,v=vp)
        ssf = Dfttest_sp(ss, Y, U, V, ftype, sigma, sigma2, pmin,
\                pmax, sbsize, smode, sosize, tbsize, tmode,
\                tosize, swin, twin, sbeta, tbeta, zmean,
\                sfile, sfile2, pminfile, pmaxfile, f0beta,
\                nfile, threads, opt, nstring, sstring,
\                ssx, ssy, sst, dither, lsb, lsb_in,
\                quiet)
        diff = dither_sub16(ssf,ss,dif = true, y=yp, u=up,v=vp).dither_resize16(w, h,kernel = "lanczos", y=yp, u=up,v=vp)
        return dither_add16(src, diff, dif = true, y=Y?3:2, u=U?3:2,v=V?3:2)
}

Function MDegrainN16(clip src, clip super, clip mv, int tr, clip "lsbclip", clip "super_lsb", int "thSAD", int "thSADC", int "plane", int "limit", int "limitC", int "thSCD1", int "thSCD2", bool "isse", bool "planar", bool "lsb", int "thsad2", int "thsadc2", bool "mt")
{
    msb = src.MDegrainN(super, mv, tr, thSAD=thSAD, thSADC=thSADC, plane=plane, limit=limit, limitC=limitC, thSCD1=thSCD1, thSCD2=thSCD2, isse=isse, planar=planar, lsb=lsb, thsad2=thsad2, thsadc2=thsadc2, mt=mt)
    lsb = src.MDegrainN(Default(super_lsb, super), mv, tr, thSAD=thSAD, thSADC=thSADC, plane=plane, limit=limit, limitC=limitC, thSCD1=thSCD1, thSCD2=thSCD2, isse=isse, planar=planar, lsb=true, thsad2=thsad2, thsadc2=thsadc2, mt=mt).ditherpost().To16(nullmsb=true)
    return Defined(super_lsb) ? msb.dither_add16(lsb, u=3, v=3) : msb
}

Function MDegrainN16(clip src, clip super, clip mv, int tr, clip "super_lsb", int "thSAD", int "thSADC", int "plane", int "limit", int "limitC", int "thSCD1", int "thSCD2", bool "isse", bool "planar", bool "lsb", int "thsad2", int "thsadc2", bool "mt")
{
    resmsb = src.MDegrainN(super, mv, tr, thSAD=thSAD, thSADC=thSADC, plane=plane, limit=limit, limitC=limitC, thSCD1=thSCD1, thSCD2=thSCD2, isse=isse, planar=planar, lsb=true, thsad2=thsad2, thsadc2=thsadc2, mt=mt)
    reslsb = src.MDegrainN(Default(super_lsb, super), mv, tr, thSAD=thSAD, thSADC=thSADC, plane=plane, limit=limit, limitC=limitC, thSCD1=thSCD1, thSCD2=thSCD2, isse=isse, planar=planar, lsb=false, thsad2=thsad2, thsadc2=thsadc2, mt=mt).To16(nullmsb=true)
    res16 = Defined(super_lsb) ? resmsb.dither_add16(reslsb, u=3, v=3) : resmsb
    return lsb ? res16 : res16.ditherpost(mode=6)
}

Function Mdenoise(clip src, clip "anclip", int "pel", int "trad", int "sad", int "sadc",
\                int "altsad", int "limit", clip "super", clip "super_an", bool "cachesuper", bool "lsb_in", bool "lsb")
{
    sad  = Default(sad, 200)
    sadc = Default(sadc, sad)
    tr   = Default(trad, 5)
    pel  = Default(pel, 2)
    lsb  = Default(lsb, true)
    lsb_in = Default(lsb_in, false)
    cachesuper = Default(cachesuper, true)
    # 16bit stuff
    pelclip16 = pelclip(src, true)
    pelmsb = pelclip16.dither_get_msb()
    pellsb = pelclip16.dither_get_lsb()
    lsbclip = lsb_in ? src.dither_get_lsb : src
    src = lsb_in ? src.dither_get_msb : src
    # Defaults, super clips, caching
    anclip   = Default(anclip, lsb_in ? src : src.removegrain(12))
    super_an = Default(super_an, anclip.MSuper (pel=pel, pelclip=((lsb_in && anclip==src) ? pelmsb : Undefined())))
    super_an = cachesuper ? super_an.requestlinear(clim=tr*2+3, elim=tr+2) : super_an
    default_super = src.MSuper (pel=pel, levels=1, pelclip=(lsb_in ? pelmsb : Undefined()))
    super = Default(super, (anclip==src) ? super_an 
    \                                    : cachesuper ? default_super.requestlinear(clim=tr*2+3, elim=tr+2) : default_super)
    super_lsb = !lsb_in ? Undefined() : lsbclip.MSuper (pel=pel, levels=1, pelclip=pellsb)
    super_lsb = !lsb_in ? Undefined() : cachesuper ? super_lsb.requestlinear(clim=tr*2+3, elim=tr+2) : super_lsb
    # Motion analysis
    mv32 = super_an.MAnalyse (delta=tr, multi=true, overlap=4, blksize=32, pzero=300)
    mv8 = super_an.MRecalculate (mv32, tr=tr, thsad=sad*2/3, overlap=2, blksize=8)
    # Degrain
    deg = src.MDegrainN16(super, mv8, tr, super_lsb=super_lsb, thSAD=sad, thSAD2=sad*2/3, thSADC=sadC, thSADC2=sadC*2/3, lsb=lsb, limit=limit)
    altdeg = src.MDegrainN16(super, mv8, tr, super_lsb=super_lsb, thSAD=sad, thSAD2=sad*2/3, thSADC=sadC, thSADC2=sadC*2/3, lsb=lsb, limit=limit)
    deg = !Defined(altsad) ? deg : interleave(deg, altdeg)
    return deg
}

Function Debicubic16(clip src, int target_width, int target_height, float "src_left", float "src_top", float "src_width", float "src_height", bool "lsb_inout", float "b", float "c", clip "downscaled", bool "pp_only", bool "iter")
{
    src.Debicubic16_internal(target_width, target_height, src_left=src_left, src_top=src_top, src_width=src_width, src_height=src_height,
\                         lsb_inout=lsb_inout, b=b, c=c, downscaled=downscaled, pp_only=pp_only, chroma=true, iter=iter)
}

Function DebicubicY16(clip src, int target_width, int target_height, float "src_left", float "src_top", float "src_width", float "src_height", bool "lsb_inout", float "b", float "c", clip "downscaled", bool "pp_only", bool "Y8", bool "iter")
{
    src.Debicubic16_internal(target_width, target_height, src_left=src_left, src_top=src_top, src_width=src_width, src_height=src_height,
\                         lsb_inout=lsb_inout, b=b, c=c, downscaled=downscaled, pp_only=pp_only, Y8=Y8, chroma=true, iter=iter)
}
Function Debicubic16_internal(clip src, int target_width, int target_height, float "src_left", float "src_top", float "src_width", float "src_height", bool "lsb_inout", float "b", float "c", clip "downscaled", bool "pp_only", bool "Y8", bool "chroma", bool "iter")
{
    src_left = Default(src_left, 0)
    src_top = Default(src_top, 0)
    src_width = Default(src_width, src.Width)
    src_width = (src_width > 0) ? src_width : src.Width + src_width - src_left
    src_height = Default(src_height, src.Height/2)
    src_height = (src_height > 0) ? src_height : src.Height/2 + src_height - src_top
    #src_width/src_height actually means src_right/src_bottom in debicubic
    src_widthd = src_left + src_width
    src_heightd = src_top + src_height
    chroma = default(Chroma, false) ? 3 : 1
    Y8 = Default(Y8, false)
    pp_only = Default(pp_only, false)
    iter = Default(iter, false)
    src = (!pp_only && !src.IsYV12) ? src.ConvertToYV12 : src
    debic = pp_only ? src 
\                   : (chroma==3) ? src.debicubic(target_width, target_height, src_left, src_top, src_widthd, src_heightd, true, b, c)
\                                 : src.debicubicY(target_width, target_height, src_left, src_top, src_widthd, src_heightd, true, b, c)
    debic = Y8 ? debic.ConvertToY8() : debic
    msb = debic.dither_get_msb()
    lsb = debic.dither_get_lsb()
    msb = mt_lutxy(msb, lsb, "y 0 == x 1 - x ?", u=chroma, v=chroma)
    lsb = mt_lut(lsb, "x 0 == 192 x ?", u=chroma, v=chroma)
    debic = stackvertical(msb, lsb)
    downscaled = (Defined(downscaled) && Y8 && !IsY8(downscaled)) ? downscaled.ConvertToY8() : downscaled
    debic = Defined(downscaled) ? downscaled.Dither_limit_dif16(debic, thr = 0.25, elast = 1.5, u=chroma, v=chroma) : debic
    
    #optional "second pass"
    inv_left = -src_left * target_width/src_width
    inv_top = -src_top * target_height/src_height
    inv_width = (src.Width) * target_width/src_width
    inv_height = (src.Height/2) * target_height/src_height
    rebic = debic.dither_resize16(src.Width, src.Height/2, inv_left, inv_top, inv_width, inv_height, kernel="cubic", a1=b, a2=c, fh=-1, fv=-1, u=chroma, v=chroma, cplace="MPEG1")
    diff = Diff16_8(src, rebic.ConvertToYV12(), u=chroma, mul=256, v=chroma).Dither_convert_8_to_16()
    assert(diff.isYV12(), string("NO"))
    diff_debic = (chroma==3) ? diff.debicubic(target_width, target_height, src_left, src_top, src_widthd, src_heightd, true, b, c)
    \                        : diff.debicubicY(target_width, target_height, src_left, src_topd, src_widthd, src_height, true, b, c)
    diff_debic = diff_debic.ditherpost(mode = -1, u=chroma, v=chroma).dither_lut8("x 128 255 * +", u=chroma, v=chroma)
    diff_debic = Y8 ? diff_debic.ConvertToY8() : diff_debic
    debic = (iter) ? debic.dither_add16(diff_debic, dif = true, u=chroma, v=chroma) : debic
    return debic
}

Function AbsDiff(clip src1, clip src2, int "mul", int "y", int "u", int "v", bool "absolute")
{
    return Diff16_8(src1, src2, mul, y, u, v, true)
}
Function Diff16_8(clip src1, clip src2, int "mul", int "y", int "u", int "v", bool "absolute")
{
    y = Default(y, 3)
    u = Default(u, 1)
    v = Default(v, 1)
    absolute = Default(absolute, false)
    div = 256.0/Default(mul, 8)
    diff = dither_sub16(src1,src2, dif = true, y=y, u=u, v=v)
    msb = diff.dither_get_msb()
    lsb = diff.dither_get_lsb()
    expr = "x 256 * y + 128 256 * - " + ((absolute)?"abs ":"") +
\           String(div)+" /" + ((absolute)?"":" 128 +")
    diff = mt_lutxy(msb, lsb, expr, y=y, u=u, v=v)
    return diff 
}

Function lutspa_whitebox(int "x1", int "y1", int "x2", int "y2", int "inflate", bool "cropped")
{
    inflate = Default(inflate, 8)
    cropped = Default(cropped, false)
    x1 = (cropped && Defined(x1)) ? inflate : x1
    y1 = (cropped && Defined(y1)) ? inflate : y1
    x2 = (cropped && Defined(x2)) ? inflate : x2
    y2 = (cropped && Defined(y2)) ? inflate : y2
    gr = 255.0 / (inflate + 1)
    exp = ""
    exp = Defined(x1) ? exp+"x "+string(x1-inflate)+" - " : exp
    exp = Defined(y1) ? exp+"y "+string(y1-inflate)+" - " : exp
    exp = Defined(x2) ? exp+string(x2+inflate)+" x - " : exp
    exp = Defined(y2) ? exp+string(y2+inflate)+" y - " : exp
    exp = Defined(x1) ? exp + "min  " : exp
    exp = Defined(x2) ? exp + "min  " : exp
    exp = Defined(y1) ? exp + "min  " : exp
    exp = Defined(y2) ? exp + "min  " : exp
    exp = exp.LeftStr(StrLen(exp)-5)+string(gr)+" * 0 max 255 min "
    return exp
}

Function RFSR_Process_mappings_pair(string str, int frame)
{
     n = Chr(10)
     split = str.FindStr(" ")
     str = (split==1) ? str.RightStr(str.StrLen()-1) : str
     split = str.FindStr(" ")
     l = eval(str.LeftStr(split-1)) 
     r = eval(str.RightStr(str.StrLen()-split))
     map = "["+string(frame)+" "+string(frame+r-l)+"]"+"["+string(l)+" "+string(r)+"]"+n
     frame = frame+r-l+1
     return map+";"+string(frame)
}
Function RFSR_Process_mappings_single(string str, int frame)
{ 
    n = Chr(10)
    a = str.FindStr(" ")
    t = (a>0) ? eval(str.LeftStr(a)) : eval(str)
    map = (IsInt(t)) ? string(frame) + " " + string(t) + n : ""
    frame = IsInt(t) ? frame+1 : frame
    return (a>0) ? map + RFSR_Process_mappings_single(str.RightStr(str.StrLen()-a), frame) : map+";"+string(frame)
}

Function  RFSR_Process_mappings(string mappings, int frame)
{
    l = mappings.FindStr("[")
    r = mappings.FindStr("]")
    map = (l>1) ? RFSR_Process_mappings_single(mappings.LeftStr(l-1), frame)
    \     : (l==1) ? RFSR_Process_mappings_pair(mappings.MidStr(l+1, r-l-1), frame)
    \                 :  RFSR_Process_mappings_single(mappings, frame)
    sc = map.FindStr(";")
    frame = eval(map.RightStr(map.StrLen()-sc))
    map = map.LeftStr(sc-1)
    r = (l>1) ? l-1 : r
    return (l<=0) ? map+";"+string(frame) : map+RFSR_Process_mappings(mappings.RightStr(mappings.StrLen()-r), frame)
}

Function RemapFramesSimpleR(clip a, string "mappings")
{
    mappings = Default(mappings+" ", "").str_dedouble(" ")
    mappings = RFSR_Process_mappings(mappings, 0)
    sc = mappings.FindStr(";")
    frames = eval(mappings.RightStr(mappings.StrLen()-sc))
    mappings= mappings.LeftStr(sc-1)
    a = (a.FrameCount()<frames) ? a.LengthenClip(frames) : a
    a = RemapFrames(a, mappings = mappings)
    return (a.FrameCount()>frames) ? a.Trim(0, frames-1) : a
}

Function quote(string s)
{
    return chr(34)+s+chr(34)
}

Function logicdownscale_makeexpr(int i, int n, string mode, int u, int v)
{
    ilogic = ".mt_logic(s.selectevery("+string(n)+","+string(i)+"), "+quote(mode)+", u="+string(u)+", v="+string(v)+")"
    return (i==0) ? "s.selectevery("+string(n)+")" : logicdownscale_makeexpr(i-1, n, mode, u, v)+ilogic
}

Function logicdownscale_v(clip src, int "ss", string "mode", int "u", int "v", bool "vert")
{
    n = Default(ss, 2)
    mode = Default(mode, "max")
    u = Default(u, 3)
    v = Default(v, 3)
    vert = Default(vert, true)
    h = vert ? src.Height : src.Width
    mod = (src.IsYV12 || src.isYV16 && !vert) ? 2 : 1
    neutral = (mode=="max" || mode == "or" || mode == "xor") ? $000000 : $FFFFFF
    pad = vert ? src.Blankclip(height=mod*n - h%(mod*n), color_yuv=neutral).trim(0,-1).loop(src.FrameCount())
\               : src.Blankclip(width=mod*n - h%(mod*n), color_yuv=neutral).trim(0,-1).loop(src.FrameCount())
    src = (h%(n*mod)==0) ? src : vert ? src.StackVertical(pad) : src.StackHorizontal(pad)
    s = vert ? src.separaterows(n) : src.separatecolumns(n)
    exp = logicdownscale_makeexpr(n-1, n, mode, u, v)
    return Eval(exp)
}

Function logicdownscale(clip src, int "ss", string "mode", int "u", int "v", bool "turn")
{
    turn = Default(turn, false)
    return turn ? src.logicdownscale_v(ss, mode, u, v).turnLeft().logicdownscale_v(ss, mode, u, v).turnright()
\               : src.logicdownscale_v(ss, mode, u, v).logicdownscale_v(ss, mode, u, v, false)
}

Function pelclip(clip src, bool "lsb")
{
    src
    y = converttoy8().LanczosResize (width*2, height*2, src_left=0.25, src_top=0.25)
    u = utoy8().LanczosResize (width, height, 0.25, 0.25)
    v = vtoy8().LanczosResize (width, height, 0.25, 0.25)
    return Default(lsb, false) ? dither_resize16(width*2, height, kernel="lanczos", center = false) : ytouv(u,v,y)
}

Function minmotion(clip src, string "post", int "u", int "v")
{
    post = Default(post, "")
    u = Default(u, 3)
    v = Default(v, 3)
    prevdiff = mt_makediff(src, src.selectevery(1, -1), u=3, v=3)
    nextdiff = prevdiff.selectevery(1,  1)
    minabs = mt_lutxy(nextdiff, prevdiff, "x 128 - abs y 128 - abs min "+post, u=3, v=3)
    return minabs
}

Function Odither(clip src, int "depth", bool "fullrange", bool "keepavg", string "fpre", string "fpost", int "colors", bool "random")
{
    #new palette bitdepth
    depth = default(depth, 2)
    colors = default(colors, bitsal(1, depth))
    #step between colors in new palette
    step = (256.0/colors)
    #try to preserve average luma/chroma values, useless parameter
    keepavg = default(keepavg, false)
    #multiply output by colorstep to get ~[0:256] range instead of [0:2^depth]
    fullrange = default(fullrange, true)
    random = default(random, false)
    #additional function
    fpre = default(fpre, "x")
    fpost = default(fpost, "")
    sstep = string(step)
    #bayer matrix
    e7 = " 1 << x 3 >> y 3 >> + 2 % +"
    e5 = " 1 << x 2 >> y 2 >> + 2 % +"
    e3 = " 1 << x 1 >> y 1 >> + 2 % +"
    e1 = " 1 << x 0 >> y 0 >> + 2 % +"
    e8 = " 1 << x 4 >> 2 % +"
    e6 = " 1 << x 2 >> 2 % +"
    e4 = " 1 << x 1 >> 2 % +"
    e2 = " 1 << x 0 >> 2 % +"
    bayer8bit = "0"+e1+e2+e3+e4+e5+e6+e7+e8
    bayer6bit = "0"+e1+e2+e3+e4+e5+e6+" 2 <<"
    bayer = ((colors > 2) && (BitAnd(colors, colors-1) == 0)) ? bayer6bit : bayer8bit
    #6bit is prob enough tho
    #bayer values are in [0:255] range
    #gotta stretch source values and dither with color_step = 256
    mul = colors
    fpre = fpre + " " + string(mul) + " *"
    divexp =  " 256 / " + ((keepavg) ? "round " : "trunc ")
    clipexp = string(colors - 1) + " min 0 max "
    postexp = ((fullrange)?(sstep+" * "):" ") + fpost
    patternclip = src.mt_lutspa("absolute", expr = bayer)
    randgrain = src.blankclip(color_yuv=$808080).f3kdb(Y=0, Cb=0, Cr=0, grainY=4096, grainC=0, dynamic_grain=true)
    patternclip = (random) ? randgrain : patternclip
    exp = fpre + " y + + 128 - " + divexp + clipexp + postexp
    return mt_lutxy(src, patternclip, expr = exp)
}

Function MaskCheckboard(clip src)
{
    src.separaterows(2)
    mt_makediff(SelectOdd(), SelectEven())
    TurnLeft().separaterows(2)
    return mt_makediff(selectodd(), selecteven()).TurnRight()
}

Function tinflate(clip src, int "y", int "u", int "v")
{
    src
    prev = Trim(0,-1)++Trim(0, FrameCount-2)
    next = Trim(1, FrameCount-1)++Trim(FrameCount-1,FrameCount-1)
    try
    {
        avg = RAverageW(prev, 0.5, next, 0.5, y=y, u=IsY8()?1:u, v=IsY8()?1:v)
    }
    catch(err_msg)
    {
        avg = mt_average(prev, next, y=y, u=u, v=v)
    }
    return last.mt_logic(avg, "max", y=y, u=u, v=v)
}

Function tdeflate(clip src, int "y", int "u", int "v")
{
    src
    prev = Trim(0,-1)++Trim(0, FrameCount-2)
    next = Trim(1, FrameCount-1)++Trim(FrameCount-1,FrameCount-1)
    try
    {
        avg = RAverageW(prev, 0.5, next, 0.5, y=y, u=IsY8()?1:u, v=IsY8()?1:v)
    }
    catch(err_msg)
    {
        avg = mt_average(prev, next, y=y, u=u, v=v)
    }
    return last.mt_logic(avg, "min", y=y, u=u, v=v)
}

Function tblur(clip src, int "y", int "u", int "v", bool "lsb_in", bool "lsb")
{
    lsb_in = Default(lsb_in, false)
    lsb = Default(lsb, false)
    src
    prev = Trim(0,-1)++Trim(0, FrameCount-2)
    next = Trim(1, FrameCount-1)++Trim(FrameCount-1,FrameCount-1)
    try
    {
        RAverageW(prev, 0.25, src, 0.5, next, 0.25, y=y, u=(Undefined(u)&&IsY8())?1:u, v=(Undefined(v)&&IsY8())?1:v, lsb_in = lsb_in, lsb_out = lsb)
    }
    catch(err_msg)
    {
        (!lsb_in && lsb) ? src.To16() : src
        average16(prev, next, y=y, u=u, v=v).average16(last, y=y, u=u, v=v)
        lsb ? last : ditherpost(mode = -1)
        (lsb || lsb_in) ? last : mt_average(prev, next, y=y, u=u, v=v).mt_average(src, y=y, u=u, v=v)
    }
    return last
}

function Dither_sum16_8(clip src1, clip src2)
{
    src1 = StackVertical(Dither_gen_null_lsb(src2), src1)
    src2 = StackVertical(Dither_gen_null_lsb(src2), src2)
    return dither_add16(src1, src2)
}

function Rsum(clip src, int range)
{
    src
    return (range == 1) ? src : dither_add16(src.trim(0,src.FrameCount() - range), Rsum(src.trim(1,0), range-1), u=3, v=3) 
}

Function qeedi_vert(clip input, clip "mclip", bool "Y", bool "U", bool "V", float "alpha", float "beta", float "gamma", int "nrad", int "mdis", 
\                              bool "hp",  int "threads", int "vcheck", float "vthreshmul", float "vthresh2", bool "splinesclip", bool "revert")
{
    Y        = Default(Y,        True   )
    U        = Default(U,        False  )
    V        = Default(V,        False  )
    yy = (Y) ? 3 : 1
    uu = (U) ? 3 : 1
    vv = (V) ? 3 : 1
    mclip    = Default(mclip,    Undefined())
    vthreshmul  = Default(vthreshmul, 1)
    splinesclip = Default(splinesclip, False)
    revert = Default(revert, False)
    vthresh0 = vthreshmul*32
    vthresh1 = vthreshmul*64
    input
    splinex2 = dither_convert_8_to_16().dither_resize16(width(),height()*2,src_top = 0.25, y=yy, u=uu, v=vv).ditherpost(mode=-1)
    cubicx2 = bicubicresize(width(),height()*2,src_top = 0.25)
    sclip = splinesclip ? splinex2 : cubicx2
    edi = eedi3(1, True, Y, U, V, alpha, beta, gamma, nrad, mdis, hp, mclip=mclip, threads=threads,
    \                vcheck=vcheck, vthresh0=vthresh0, vthresh1=vthresh1, vthresh2=vthresh2, sclip = sclip)
    newfield_sclip = sclip.AssumeBFF().separatefields().selecteven()
    newfield_eedi3 = edi.AssumeBFF().separatefields().selecteven()
    edied = mt_logic(newfield_sclip, newfield_eedi3, "xor", y=yy, u=uu, v=vv)
    edi_halved = edi.Dither_convert_8_to_16().dither_resize16(width(),height(), src_top = -0.5, y=yy, u=uu, v=vv).ditherpost(mode=-1, y=yy, u=uu, v=vv)
    return revert ? input.mt_merge(edi_halved, edied.bilinearresize(width(),height(), src_top = -0.5).mt_binarize(0, y=yy, u=uu, v=vv))
    \             : edi_halved
    #return edi.interleave(sclip)
}

Function qeedi(clip input, clip "mclip", bool "Y", bool "U", bool "V", float "alpha", float "beta", float "gamma", int "nrad", int "mdis", 
\                              bool "hp",  int "threads", int "vcheck", float "vthreshmul", float "vthresh2", bool "splinesclip", bool "revert")
{
    input
    TurnRight()
    mclipR = IsClip(mclip) ? mclip.TurnRight() : Undefined()
    qeedi_vert(last, mclipR, Y, U, V, alpha, beta, gamma, nrad, mdis, hp, threads, vcheck, vthreshmul, vthresh2, splinesclip, revert)
    TurnLeft()
    qeedi_vert(last, mclip, Y, U, V, alpha, beta, gamma, nrad, mdis, hp, threads, vcheck, vthreshmul, vthresh2, splinesclip, revert)
    return last
}

Function IsByte(int a)
{
    return (0 <= a) and (a <= 255)
}

Function Credmask_Bmask(clip src, int "BThr1", int "BExp1", int "BThr2", int "BExp2", int "BThr3", int "BExp3", bool "soft", bool "inv")
{
    inv = Default(inv, false)
    BExp1 = Default(BExp1, 0)
    BExp2 = Default(BExp2, 0)
    BExp3 = Default(BExp3, 0)
    BThr1 = Default(BThr1, 0)
    BThr2 = Default(BThr2, 0)
    BThr3 = Default(BThr3, 0)
    soft = Default(soft, false)
    src = inv ? src.mt_expand_oct(BExp1) : src.mt_inpand_oct(BExp1)
    m1 = soft ? src.mt_shiftnmul(BThr1, 128, 4, upper=!inv) : src.mt_binarize(BThr1, !inv)
    #if (BExp2>BExp1)
    #{
        src = inv ? src.mt_expand_ss(BExp2-BExp1+1, prer=1, subspl = 3)
\                 : src.mt_inpand_ss(BExp2-BExp1+1, prer=1, subspl = 3)
        m2 = soft ? src.mt_shiftnmul(BThr2, 128, 6, upper=!inv) : src.mt_binarize(BThr2, !inv)
        BExp3 = (BExp3-BExp2)/3-1
        #if (BExp3>0)
        #{
            src = inv ? src.mt_expand_ss(BExp3, prer=1, subspl = 3)
\                     : src.mt_inpand_ss(BExp3, prer=1, subspl = 3)
            m3 = soft ? src.mt_shiftnmul(BThr3, 128, 8, upper=!inv) : src.mt_binarize(BThr3, !inv)
            m3 = m3.desusample(m2.Width, m2.Height, 3, point =false)
            m23 = IsByte(BThr2) ? mt_logic(m2, m3, soft ? "min" : "and") : m3
        #}
        m2 = (BExp3>0) ? m23 : m2
        m2 = m2.desusample(m1.Width(), m1.Height(), 3, point =false)
        m12 = IsByte(BThr1) ? mt_logic(m1, m2, soft ? "min" : "and") : m2
    #}
    m1 = (BExp2>BExp1) ? m12 : m1
    return m1
}

function Credmask(clip src, int "BThr1", int "BExp1", int "BThr2", int "BExp2", int "BThr3", int "BExp3"
\                                  , int "WThr1", int "WExp1", int "WThr2", int "WExp2", int "WThr3", int "WExp3"
\                                  , int "CThr1", int "CExp1", int "CThr2", int "CExp2", int "CThr3", int "CExp3", int "u", int "v"
\                                  , int "EThr1", int "EExp1", int "EThr2", int "EExp2", int "EThr3", int "EExp3", bool "soft")
{
    BThr1 = Default(BThr1, 0)
    WThr1 = Default(WThr1, 0)
    CThr1 = Default(CThr1, 0)
    EThr1 = Default(EThr1, 0)
    soft = Default(soft, false)
    uc = Default(u, 128).string()
    vc = Default(v, 128).string()
    y = src.converttoy8()
    u = src.IsY8 ? src : src.UtoY8()
    V = src.IsY8 ? src : src.VtoY8()
    b = y.Credmask_Bmask(BThr1, BExp1, BThr2, BExp2, BThr3, BExp3, soft)
    w = y.Credmask_Bmask(WThr1, WExp1, WThr2, WExp2, WThr3, WExp3, soft, inv=true)
    c = mt_lutxy(u, v, "x "+uc+" - abs y "+vc+" - abs +").Credmask_Bmask(CThr1, CExp1, CThr2, CExp2, CThr3, CExp3, soft).Cx2()    
    e = y.mt_edge("min/max", 0,255).Credmask_Bmask(EThr1, EExp1, EThr2, EExp2, EThr3, EExp3, soft, inv=true)
    w = (WThr1!=0) ? w : y.mt_lut(y=0)
    wb = (BThr1!=0) ? ((WThr1!=0) ? mt_logic(w,b,"min") : b) : w
    wbc = (CThr1!=0) ?  mt_logic(wb,c,"min") : wb
    wbce = (EThr1!=0) ? mt_logic(wbc,e,"min") : wbc
    return wbce
}

Function SMoothD2yuv(clip src, int "quant", int "num_shift", int "Matrix", int "Qtype", int "ZW",  int "ncpu")
{
    Y = src.SmoothD2(quant=quant, num_shift=num_shift, Matrix=Matrix, Qtype=Qtype, ZW=ZW, ncpu=ncpu)
    U = src.UtoY().SmoothD2(quant=quant, num_shift=num_shift, Matrix=Matrix, Qtype=Qtype, ZW=ZW, ncpu=ncpu)
    V = src.VtoY().SmoothD2(quant=quant, num_shift=num_shift, Matrix=Matrix, Qtype=Qtype, ZW=ZW, ncpu=ncpu)
    return YtoUV(U, V, Y)
}

Function SD2_preset(clip src, int "strength", int "num_shift", bool "display")
{
    strength = Default(strength, 0)
    display = Default(display, false)
    matrix = (strength < 22) ? 9 : 22
    quant =  (strength < 13) ? strength+1
    \          : (strength < 22) ? strength*2-11
    \                                   : min(strength/9+2, 30)
    quant = max(quant, 1)
    db = src.SMoothD2yuv(quant=quant, matrix=matrix, num_shift=num_shift)
    db = display ? db.subtitle("deblocked, strength="+string(strength), y=40) : db
    return (strength < 0) ? src : db
}

Function shiftcolor(clip src, clip ref, int "block", bool "doublechroma")
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

#nnedimode is either 0/1 (like in nnedi, TFF assumed) or -1/1 to use prev/next frame
Function UDMC(clip src,  clip "anclip", int "sad", bool "isb", bool "dct", bool "display")
{
    an = Default(anclip, src)
    sad = Default(sad, 100)
    dct = Default(dct, false)
    display = Default(display, false)
    isb = Default(isb, true)
    super_a = an.MSuper()
    super = src.MSuper(levels = 1)
    v = manalyse(super_a, isb=isb, delta=1, blksize=32, overlap=0, pglobal=200, pzero=200, lambda=500, searchparam=16)
    v = mrecalculate(super_a, v, blksize=8, overlap=4, pnew=20, thsad=sad/3, lambda=500, smooth=0, dct=dct?1:0)
    comp = MCompensate(src, super, v, thsad=10000)
    mask = mmask(src, v,  kind=1, ml=sad).converttoy8()
    mask = mask.mt_lut("x 15 - 0 max 240 / 2 ^ 1000 *", u=3, v=3).mt_expand().mt_inflate().mt_inflate()
    merged = comp.mt_merge(src, mask, luma=true,u=3,v=3)
    merged = display ? merged.subtitle("motion compensated from " + (isb?"next":"previous")+" frame,", y=80) : merged
    return merged
}

Function BDMC(clip src,  clip "anclip", clip "colorclip", int "sad", bool "dct", bool "display")
{
    an = Default(anclip, src)
    colorclip = Default(colorclip, an)
    sad = Default(sad, 100)
    dct = Default(dct, false)
    display = Default(display, false)
    super_a = an.MSuper()
    super = src.MSuper(levels = 1)
    v = manalyse(super_a, delta=1, multi=true, blksize=32, overlap=0, pglobal=0, pzero=0, lambda=500, searchparam=16)
    v = mrecalculate(super_a, v, blksize=8,overlap=4, pnew=20, thsad=sad/3, lambda=500, smooth=0, tr=1, dct=dct?1:0)
    b=v.selecteven()
    f=v.selectodd()
    bmask = mmask(src,b,kind=1, ml=sad, Ysc=255)
    fmask = mmask(src,f,kind=1, ml=sad, Ysc=255)
    bcomp = MCompensate(src, super, b, thsad=10000)
    fcomp = MCompensate(src, super, f, thsad=10000)
    bcomp = shiftcolor(bcomp, colorclip)
    fcomp = shiftcolor(fcomp, colorclip)
    fmask = fmask.converttoy8().mt_expand()
    bmask = bmask.converttoy8().mt_expand()
    fbmask = mt_lutxy(fmask, bmask, "y x - x y + 24 max * 20 / 128 +")
    fbtosrcmask = mt_lutxy(fmask, bmask, "x y min 10 - 0 max 245 / 2 ^ 1000 *").mt_expand().mt_inflate()
    fbcomp = bcomp.mt_merge(fcomp, fbmask, luma=true,u=3,v=3)
    merged = fbcomp.mt_merge(src, fbtosrcmask, luma=true,u=3,v=3)
    merged = display ? merged.subtitle("bidirectional motion compensation,", y=80) : merged
    return merged
}