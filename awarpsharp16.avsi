function adddiff16_8_8(clip a, clip b, clip c, int "y", int "u", int "v")
{
    diff = mt_makediff(b, c, y=y, u=u, v=v)
    msb = a.dither_get_msb().mt_adddiff(diff, y=y, u=u, v=v)
    lsb = a.dither_get_lsb()
    return stackvertical(msb,lsb)
}

function box8(clip src, int "radius", int "radius2", int "radius3", int "y", int "u", int "v", int "mode")
{
	mode = Default(mode, -1)
    box = src.Dither_convert_8_to_16().Dither_box_filter16(radius=radius, y=y, u=u, v=v)
    box = Defined(radius2) ? box.Dither_box_filter16(radius=radius2, y=y, u=u, v=v) : box
    box = Defined(radius3) ? box.Dither_box_filter16(radius=radius3, y=y, u=u, v=v) : box
    return (mode<-1) ? box.dither_get_msb() : box.ditherpost(mode = mode)
}

function Guidedwarp(clip src, clip guidesobel, int "thresh", int "blur", int "type", int "depth")
{
    guidesobel = guidesobel.aBlur(1, 1)
    srcsobel = src.aSobel(thresh=thresh, chroma=1).aBlur(1, 1)
    avgguide = guidesobel.box8(radius=5, u=1, v=1, mode=-2)
    avgsrc = srcsobel.box8(radius=5, u=1, v=1, mode=-2)
    mul = mt_lutxy(avgsrc, avgguide, "x y / 255 *")
    #amplify sobel mask of src to match average values of guidesobel
    srcsobel_amp = mt_lutxy(srcsobel, mul, "x y / 270 * x x max")
    #similar to max(min(guidesobel, srcsobel_amp), srcsobel) - reduce guidesobel in areas with no edges in src
    #to avoid warping edges in wrong way (for example when chroma doesn't correlate much with luma),
    #adds edges from srcsobel when those are not present in guidesobel
    sobel = mt_clamp(guidesobel,srcsobel_amp,srcsobel,8,8).aBlur(blur=blur-1, type=type, chroma = 1)
    return src.awarp(sobel, depth=depth, chroma=1)
}

function awarpsharp16(clip src, int "thresh", int "blur", int "type", int "depth", int "chroma", int "depthC", clip "uclip", clip "vclip", bool "lsb", string "cplace")
{
    src
    blur = Default(blur, 2)
    type = Default(type, 0)
    depthY = Default(depth, 16)
    chroma = Default(chroma, IsY8 ? 1 : 4)
    depthC = Default(depthC, IsYV24 ? depthY : depthY/3) #depth/2 in original warpsharp
    lsb = Default(lsb, true)
    cplace = UCase(Default(cplace, "MPEG2"))
    Assert(cplace == "MPEG2" || cplace == "MPEG2", "awarpsharp16: unknown colorplacing "+cplace)
    cshift = (cplace=="MPEG1") ? 0 : IsYV411 ? -1.5 : -0.5

    src8 = (lsb) ? src.ditherpost(mode=-1) : src
    if ((chroma != 4 && chroma !=6 || IsYV24 || cshift==0) && chroma!=-1)
    {
        return lsb ? src.adddiff16_8_8(src8.awarpsharp2(thresh, blur, type, depth, chroma, depthC), src8, u=3, v=3)
\                     : awarpsharp2(src, thresh, blur, type, depth, chroma, depthC)
    }
    else
    {
        y8 = src8.ConvertToY8()
        u8 = src8.UtoY8
        v8 = src8.VtoY8
        sobel = y8.asobel(thresh = thresh, chroma=1)
        if (chroma == -1)
        {
            blurC  = IsYV24 ? blur : (blur+1)/2
            y8warp = y8.awarpsharp2(thresh=thresh, blur=blur, type=type, depth=depthY, chroma=1)
            sobel = IsYV24 ? sobel : sobel.BilinearResize(u8.Width, u8.Height, src_left=cshift)
            u8warp = Guidedwarp(u8, sobel, thresh, blurC, type, depthC)
            v8warp = Guidedwarp(v8, sobel, thresh, blurC, type, depthC)
        }
        else
        {
            sobel = sobel.ablur(blur = blur, type=type, chroma=1)
            y8warp = (chroma == 4) ? y8.awarp(sobel, depth=depthY, chroma=1) : y8
            sobel = sobel.BilinearResize(u8.Width, u8.Height, src_left=cshift)
            u8warp= u8.awarp(sobel, depth=depthC, chroma=1)
            v8warp= v8.awarp(sobel, depth=depthC, chroma=1)
        }
        res8 = YtoUV(u8warp, v8warp, y8warp)
        res16 = src.adddiff16_8_8(res8, src8, y=(chroma != 6) ? 3 : 2, u=3, v=3)
        return (lsb) ? res16 : res8
    }
}