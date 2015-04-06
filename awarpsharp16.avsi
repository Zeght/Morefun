/*
awarpsharp16 - awarpsharp2 wrapper with additional features.
Works with any planar YUV colorspaces, usage of non-square pixels is discouraged.
Requires Dither package and a certain awarpsharp2 build.
Parameters:
  thresh: 0..255, default 128
    Saturation limit for edge detection. Reduce for less aggressive sharpening.

  blur: 0..100, default 2 for type 0, 3 for type 1
    Number of blur passes over edge mask. Less passes increase sharpening effect,
    but can produce major artefacts with high depth and thresh. You can use values
    higher than 100, but probably won't see any difference.
    Chroma is processed with (blur+1)/2 passes.

  type: 0..1, default 0 for aWarpSharp2, 1 for aBlur
    Type of blur:
      0 - radius 6 blur
      1 - radius 2 blur, requires around 8x more passes than type 0 for the same
          effect (will be just 2.5x slower), but produce better quality

  depth: -128..127, default 16 for aWarpSharp2, 3 for aWarp and aWarp4
    Strength of the final warping. Negative values result in warping in opposite
    direction.

  chroma: 0..6
    Processing mode for chroma planes (U and V):
     -1 - similar to 4, additionally uses chroma sobel mask
      0 - fill with zeroes
      1 - don't care, default for aSobel and aBlur
      2 - copy
      3 - process
      4 - guide by luma - aWarpSharp, aWarp and aWarp4 only, default for them
      5 - same as 3, but don't process luma
      6 - same as 4, but don't process luma

  depthC: -128..127, default depth/3 for non-4:4:4 colorspaces, depth for YV24.
    Strength of the final warping of chroma planes. Negative values result in 
    warping in opposite direction.

  lsb: 16bit stacked input and output

  cplace: chroma placement "MPEG2"(default) or "MPEG1"
*/

function adddiff16_8_8(clip a, clip b, clip c, int "y", int "u", int "v")
{
    diff = mt_makediff(b, c, y=y, u=u, v=v)
    msb = a.dither_get_msb().mt_adddiff(diff, y=y, u=u, v=v)
    lsb = a.dither_get_lsb()
    return stackvertical(msb,lsb)
}

function box8(clip src, int "radius", int "y", int "u", int "v", int "mode")
{
    box = src.Dither_convert_8_to_16().Dither_box_filter16(radius=radius, y=y, u=u, v=v)
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
    srcsobel_amp = mt_lutxy(srcsobel, mul, "x y / 255 * x")
    #same as max(min(guidesobel, srcsobel_amp), srcsobel) - reduce guidesobel in areas with no edges in src to avoid warping edges in wrong way
    #(for example when chroma doesn't correlate much with luma), addes edges from srcsobel when those are not present in guidesobel
    sobel = mt_clamp(guidesobel,srcsobel_amp,srcsobel,0,0).aBlur(blur=blur-1, type=type, chroma = 1)
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