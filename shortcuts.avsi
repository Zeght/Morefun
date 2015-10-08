Function mt_expand_multi(clip src, int "thY", int "thC", string "mode",
\    int "offx", int "offy", int "w", int "h", int "y", int "u", int "v",
\    string "chroma", int "sw", int "sh", int "swc", int "shc", bool "halfchroma")
{
    sw   = Default (sw, 1)
    mode = Default (mode, "rectangle")
    halfchroma = Default (halfchroma, false)
    swc   = Default (swc, halfchroma ? sw/2 : sw)
    shc   = Default (shc, halfchroma ? sh/2 : sh)

    mode_m =
\      (sw > 0 && sh > 0) ? (
\          (mode == "losange" || (mode == "ellipse" && (sw % 3) != 1))
\        ? "both" : "square"
\                           )
\    : (sw > 0          ) ? "horizontal"
\    : (          sh > 0) ? "vertical"
\    :                      ""

    (mode_m != "") ? src.mt_expand (
\        thY=thY, thC=thC, mode=mode_m, offx=offx, offy=offy, w=w, h=h,
\       y=y, u=(shc <=0 && swc <= 0) ? 2 : u, 
\        v=(shc <=0 && swc <= 0) ? 2 : v, chroma=chroma
\    ).mt_expand_multi (
\        thY=thY, thC=thC, mode=mode,
\        offx=offx, offy=offy, w=w, h=h, y=y, u=u, v=v, chroma=chroma,
\        sw=sw-1, sh=sh-1, swc=swc-1, shc=shc-1, halfchroma=halfchroma
\    ) : src
}

Function mt_inpand_multi(clip src, int "thY", int "thC", string "mode",
\    int "offx", int "offy", int "w", int "h", int "y", int "u", int "v",
\    string "chroma", int "sw", int "sh", int "swc", int "shc", bool "halfchroma")
{
    sw   = Default (sw, 1)
    mode = Default (mode, "rectangle")
    halfchroma = Default (halfchroma, false)
    swc   = Default (swc, halfchroma ? sw/2 : sw)
    shc   = Default (shc, halfchroma ? sh/2 : sh)

    mode_m =
\      (sw > 0 && sh > 0) ? (
\          (mode == "losange" || (mode == "ellipse" && (sw % 3) != 1))
\        ? "both" : "square"
\                           )
\    : (sw > 0          ) ? "horizontal"
\    : (          sh > 0) ? "vertical"
\    :                      ""

    (mode_m != "") ? src.mt_inpand (
\        thY=thY, thC=thC, mode=mode_m, offx=offx, offy=offy, w=w, h=h,
\       y=y, u=(shc <=0 && swc <= 0) ? 2 : u, 
\        v=(shc <=0 && swc <= 0) ? 2 : v, chroma=chroma
\    ).mt_inpand_multi (
\        thY=thY, thC=thC, mode=mode,
\        offx=offx, offy=offy, w=w, h=h, y=y, u=u, v=v, chroma=chroma,
\        sw=sw-1, sh=sh-1, swc=swc-1, shc=shc-1, halfchroma=halfchroma
\    ) : src
}

Function mt_xxpand_shortcut(clip src, int "radius", int "radiusc", bool "halfchroma",
\                           int "y", int "u", int "v", string "mode", bool "inpand")
{
    u = Default(u, 3)
    v = Default(v, 3)
    halfchroma = Default(halfchroma, src.IsYV12())
    radiusc = Default(radiusc, halfchroma ? radius/2 : radius)
    return inpand ? src.mt_inpand_multi (sw=radius, sh=radius, swc=radius, shc=radiusc,
\                                        mode=mode, y=y, u=u, v=v)
\                 : src.mt_expand_multi (sw=radius, sh=radius, swc=radius, shc=radiusc,
\                                        mode=mode, y=y, u=u, v=v)
}

Function mt_expand_oct(clip src, int "radius", int "radiusc", bool "halfchroma", int "y", int "u", int "v")
{
    return src.mt_xxpand_shortcut(radius, radiusc, halfchroma, y, u, v, "ellipse", false)
}

Function mt_inpand_oct(clip src, int "radius", int "radiusc", bool "halfchroma", int "y", int "u", int "v")
{
    return src.mt_xxpand_shortcut(radius, radiusc, halfchroma, y, u, v, "ellipse", true)
}

Function mt_expand_sq(clip src, int "radius", int "radiusc", bool "halfchroma", int "y", int "u", int "v")
{
    return src.mt_xxpand_shortcut(radius, radiusc, halfchroma, y, u, v, "square", false)
}

Function mt_inpand_sq(clip src, int "radius", int "radiusc", bool "halfchroma", int "y", int "u", int "v")
{
    return src.mt_xxpand_shortcut(radius, radiusc, halfchroma, y, u, v, "square", true)
}

function Dfttest_sp(clip src, bool "Y", bool "U", bool "V", int "ftype", float "sigma", float "sigma2", float "pmin",
\                    float "pmax", int "sbsize", int "smode", int "sosize", int "tbsize", int "tmode",
\                    int "tosize", int "swin", int "twin", float "sbeta", float "tbeta", bool "zmean",
\                    string "sfile", string "sfile2", string "pminfile", string "pmaxfile", float "f0beta",
\                    string "nfile", int "threads", int "opt", string "nstring", string "sstring",
\                    string "ssx", string "ssy", string "sst", int "dither", bool "lsb", bool "lsb_in",
\                    bool "quiet")
{
    newversionparams =  (Defined(nstring) || Defined(sstring) || Defined(ssx) || Defined(ssy) || 
\                                         Defined(sst) || Defined(dither) || Defined(lsb) || Defined(lsb_in) || Defined(quiet))
    tbsize = Default(tbsize, 1)
    lsb_in = Default(lsb_in, true)
    lsb    = Default(lsb, true)
    try {
        dfttest(src, Y, U, V, ftype, sigma, sigma2, pmin,
\                pmax, sbsize, smode, sosize, tbsize, tmode,
\                tosize, swin, twin, sbeta, tbeta, zmean,
\                sfile, sfile2, pminfile, pmaxfile, f0beta,
\                nfile, threads, opt, nstring, sstring,
\                ssx, ssy, sst, dither, lsb, lsb_in,
\                quiet)
    }
    catch(err_msg)#x64 version is pretty old
    {
        assert(!newversionparams, err_msg)
        try {
        dfttest(src, Y, U, V, ftype, sigma, sigma2, pmin,
\                pmax, sbsize, smode, sosize, tbsize, tmode,
\                tosize, swin, twin, sbeta, tbeta, zmean,
\                sfile, sfile2, pminfile, pmaxfile, f0beta,
\                nfile, threads, opt)
        }
        catch(err_msg64)
        {
            assert(false, err_msg64)
        }
    }
}

Function To16(clip src, bool "nullmsb")
{
    nullmsb = Default(nullmsb, false)
    return nullmsb ? StackVertical(src.Dither_gen_null_lsb(), src)
\                  : StackVertical(src, src.Dither_gen_null_lsb())
}

Function AVSource(string "source", int "stream_index", int "threads", bool "cache", int "seek_mode", int "seek_threshold", bool "dr", bool "repeat", int "dominance", bool "stacked", string "format")
{
    LWLibavVideoSource(source=source, stream_index=stream_index, threads=threads, cache=cache, seek_mode=seek_mode, seek_threshold=seek_threshold, dr=dr, repeat=repeat, dominance=dominance, stacked=stacked, format=format)
}

Function AVSource16(string "source", int "stream_index", int "threads", bool "cache", int "seek_mode", int "seek_threshold", bool "dr", bool "repeat", int "dominance", bool "stacked", string "format")
{
    format = Default(format, "YUV420P16")
    stacked = Default(stacked, true)    
    LWLibavVideoSource(source=source, stream_index=stream_index, threads=threads, cache=cache, seek_mode=seek_mode, seek_threshold=seek_threshold, dr=dr, repeat=repeat, dominance=dominance, stacked=stacked, format=format)
}

Function ToRGB(clip src, string "matrix", bool "interlaced", bool "tv_range", string "cplace", string "chromak", float "fh", float "fv", int "taps", float "a1", float "a2", float "a3", bool "lsb_in", string "output", int "mode", float "ampo", float "ampn", bool "staticnoise", bool "noring")
{
    Dither_convert_yuv_to_rgb(src, matrix=matrix, interlaced=interlaced, tv_range=tv_range, cplace=cplace, chromak=chromak, fh=fh, fv=fv, taps=taps, a1=a1, a2=a2, a3=a3, lsb_in=lsb_in, output=output, mode=mode, ampo=ampo, ampn=ampn, staticnoise=staticnoise, noring=noring)
}
