#MoreFun
Some Avisynth  scipts

##MoreFun.avsi
Collection of small scripts. Some may be documented upon request.

### Common parameters
y, u and v are parameters for Y, U and V planes processing mode, same as in dither tools and masktools.
lsb_in/lsb are parameters for setting 16bit input/output, same as in dither tools.

### bilatinpaint(clip diff, clip msk, clip ref, float "subspl", int "y", int "u", int "v")
Function tries to interpolate data in msk area of diff by blurring it using ref clip as reference.
Most of processing is done on clips subsampled with subspl factor.

Sample usage:
```
#"subbed" is clip with overlayed sutitles, "clean" is clean clip with slightly alternated colors, "msk" is a blurry subtitle mask
#This alternates color of clean clip script masks subtitles
#"clean" and "subbed" are 16bit, "msk" is 8bit
diff = dither_sub16(subbed, clean, dif=true, u=3, v=3)
#bilatinpaint fills msk area of diff clip with colors from outside of mask, uses clean clip as reference to know how to fill
diff = bilatinpaint(diff, msk, clean)
cleanshifted  = clean.dither_add16(diff, dif=true, u=3, v=3)
merged = subbed.dither_merge16_8(cleanshifted, msk, u=3, v=3, luma=true)
```

###Debicubic16, DebicubicY16, DebicubicY16PlusMask
lsb output for debicubic is broken, those wrappers make it less broken.
By default, script just shifts error from [+0..+128]\(on 16 bit scale) range to [-64..64] range.
Pass a clip downscaled with Dither_resize16 to completely fix gradients or use iter=true (stolen from a certain encoder's blog) for actually precise debicubic at half speed.

DebicubicY16PlusMask returns debicubic clip interleaved with so-called "detail mask".
Mask is created by subtracting rescaled debicubic clip from source clip, applying Dither_lut16(expr) (default expr - "x 128 256 * - abs") and downscaling result.

###dfttest_ss
Subsamples image with subspl factor, performs dfttest on a subsampled picture, computes difference between result and original subsampled picture and adds difference to full-size picture.
This allow to filter oly lower frequencies at relatively low cost.
Works with 16bit clips only.

###Framematch(clip src, clip ref, clip "msk", clip "out", int "mskmode", int "rad", string "outfile", float "subspl", float "gamma")
Takes 2 clips with same content, similar colors, crop, but with different framenumbers. Tries to match frames rearrange frames of _src_ clip to match frames of _ref_ clip.

Function compares frame from ref to nearby frames from src using Cframediff from TVIVTC (same metric as tdecimate).

Runtime filters use global variables, so it's not recommended to use this script twice in same AviSynth instance.

You can check history of https://gist.github.com/Zeght/89c9a763efba0b32486b for simpler versions of this script.
* clip ref - reference clip that has frames arranged in desired way.
* clip src - similar clip with slightly rearanged frames (e.g. misdecimated). Doesn't need to be same size as ref as it will be resized in the process.
* clip msk (Undefined) - mask clip, masked areas wont be compared.
* clip out (src) - clip which frames will be returned according to src->ref mappings. Can be 16-bit version of _src_, some kind of mask or stacked clips.
* int mskmode(0) - defines if mask clip is relative to _src_ (_mskmode_=0) or _ref_ (_mskmode_=1)
* int rad (3) - temporal radius for frames comparison/search.
* string outfile (Undefined) - name of file to write logs. Format - lines consisting of space-separated pairs (_frame_number_, _shift_(where to get frame frame from _ref_ to get same frame as _frame_number_ from src)).
* float subspl (width/640) - clips are subsampled by this factor and then get 8px-wide borders cropped for comparison. _subspl=0_ disables subsampling and cropping.
* float gamma (0.05) - penalizes sudden changes in frame shift. Negative values allows for crossings/decreasing mappings which is normally not required.

###Framematch_selectrangeevery(clip src, int "every", int "length", int "offset", int "mul", bool "blackpad")
Unlike AviSynth's SelectRangeEvery this version does properly with every>length and works with negative offsets.

It picks ranges [_offset_, _offset_+_length_], [_offset+every_, _offset_+_every_+_length_], [_offset+2*every_, _offset_+_2*every_+_length_] and so on.

If _mul_>0 then it repeats every range described above _mul_ times.

Frames that are pulled from outside of clip (with negative or too big frame numbers) are replaced by black frames if _blackpad_ is set to true (Default), otherwise it these frames are replaced by first or last frame.

SelectEvery is used internally and it wont work if _length*mul_ is larger than 1023.

Length of returned clip is always _src.framescount*length*mul/every_.

###HD_Edge
A hack to compute an edge mask with bit depth higher than 8 bit. It works by taking clip lsb1 - some lower bits and lsb2 - lsb1 with values circularly shifted by 128.
Edge mask is computed for both according to selected mode, and two masks are merged using mt_logic(mode="min").
Mode is one of mt_edge modes.
You can also compute a rangemask by setting range parameter, subsampling is automatically used for large ranges and it can be overridden with subspl parameter, mask isn't upscaled back if range is negative.
Post parameter is meant for simple post-processing of resulting values and is results in output equivalent to HD_Edge(post="none").mt_lut("x "+post), "none" or "" disables this post-processing, default - " 2 *".
Depth=2^n means that bits from n to n+8 will be used for computing mask, e.g with depth=256 only 8 least significant bits will be used.

###logicdownscale(clip src, int "ss", string "mode", int "u", int "v", bool "turn")
Performs downscaling by ss factor using separaterows and mt_logic.
mode is mt_logic mode (default - "max"), turn indicates whether clip is downscaled turned with vertically, turned, downscaled vertically, and turned (true) or clip is downscaled vertically and then horizontally (false, default).

###lutspa_whitebox(int "x1", int "y1", int "x2", int "y2", int "inflate")
Makes an expression for mt_lutspa to draw a box with corners in (x1, x2) and (y1, y2) inflated by inflate pixels.

###Mdenoise
Simple MDegrain wrapper. Disable _cachesuper_ if you want to use backward seeking.

If altsad is defined then Mdenoise returns two interleaved clips: even frames are result of denoising with "sad", odd frames - "altsad".

With positive _blksize_ search is done with 32x32 blocks first and then refined using _blksize blocks_, negative _blksize_ results in 1-pass search with _-blksize_ blocks. Default is 8.
###MoreFun
modified gradfun3 with following changes (not tested well):
*different defaults: smode=2, lsb=lsb_in=true
*thr_edg removed
*removegrain instead of Dither_removegrain_emul because rgtools works with all colorspaces
*optional maskclip, merged with internal rangemask
*optional chroma rangemasking (chromamask=true to mask chroma with chroma-based mask, mixedmask=true to merge chroma-based and luma-based masks)
*optional blur with big radius and big rangemask(bigmode=0 for Dither_smoothgrad, bigmode>1 for Dither_Bilateral and mask computed with pseudo (8+log(bigmode))-bit precision)
*debug=2 shows clip after blurring with big radius, debug=1 stacks usual small radius rangemask with the big one

###mt_xxpand_ss (clip src, int "radius", int "radiusc", bool "halfchroma", int "subspl", int "prer", bool "square", int "y", int "u", int "v")
Performs expanding/inpanding using multiple mt_expand/mt_expand calls with subsampling, subspl factor is used.
By default, radiusc is set to raduis/2 if halfchroma is true, otherwise radius c is set to radus.
prer=n means that mask was already inpanded/expanded n times, so it's possible to skip some inpanding/expanding before subsampling, default is 0.
Square kernel is used if sqare is set to true, octagonal kernel is used otherwise(default).

###qeedi
Runs horizontal anti-aliasing (turn, eedi3, downscale, turn) and vertical anti-aliasing (eedi3, downscale).
Runs slightly faster then eedi3_resize16 because eedi3 is done on a smaller clip.
splinesclip indicates whether Dither_resize16nr() is used to generate sclip instead of default cubic.
revert=true means that pixels not belonging to edge (edge wasn't found by eedi) will be reverted to original values instead of being upscaled and then downscaled.
target_width, target_height, src_left , src_top , src_width ,src_height can be used to do custom resizing/cropping instead of reverting size back on downscaling.
Chroma processing is discouraged because downscaling is inaccurate in this wrapper.

###RangeMask
Computes a range mask (difference between maximum and minimum in the radius), similar to Dither_build_gf3_range_mask.
Subsampling is used for radius>5, factor can be overridden with subspl parameter, mask isn't upscaled back if noup parameter is set to true.
Post parameter is same as in HD_Edge, default=""

###RemapFramesSimpleR
RemapFramesSimple with support of ranges and without support of files. Provides an alternative way to splice a number of trims, e.g. RemapFramesSimpleR("[100 200] [500 800]") is same as Trim(100, 200)++Trim(500, 800).

###susample/desusample
Susample subsamples picture with defined factor using pointresize and adds padding when necessary.
Used in functions mt_inpand_ss/mt_expand_ss and RangeMask.
Desusample reverts susample and returns clip with w x h dimensions, point is used if point parameter is set to true (default) bilinear is used otherwise.

###tblur, texpand, tinpand, tinflate, tdeflate
Simple temporal filters: tblur does temporal blur with (0.25, 0.5, 0.25) kernel using raveragew (or average/dither_merge if raveragew isn't avaliable), 

##shortcuts.avsi
Some shortcuts. Used by some scripts from MoreFun.avsi
###mt_xxpand_sq, mt_xxpand_oct
Same as mt_xxpand_ss but without subsampling.
mt_xxpand_sq uses square kernel, mt_xxpand_oct uses octagonal kernel.
###dfttest_sp
Spatial dfttest - dfttest with different defaults. tbsize is 1, lsb_in/lsb is true.

##fixborders (fixborders.avsi)
Function for correcting darkened/brightened borders. Multiplies values of border lines by specified amount

Requires Dither package

Parameters:

* string l/t/r/b - values for multiplication, in "A:B1 B2 B3 B4 B5 B6" format which means ith line will be multiplied by (A/Bi).
 * Lines are ordered by distance from border with last line being the nearest one.
 * Example: "100.8: 110.3 110 90" will brighten line nearest to border and darken two next ones.
 * Optionally you can specify values for chroma in similar way after semicolon: "A:B1 B2;C:D1 D2"
 * You can also add d[number] after list of values to throw away data from [number] last lines instead of trying to fix them. Data will be copied from next line
 * Stare intensely on frame borders with high luma/chroma values on flat area to get best values.
 * Sample usage: frame should be completely (235) white, but top line has luma value 180, second is 200 third is 240. Specify t="235: 240 200 180" to fix that or t="235: 240 200 180d1" if you think last line can't be fixed properly
 * block "A:B1 B2 B3 B4 B5 B6" may be omitted, for instance ";100:50" will only process chroma, "d1;d1" will mirror last luma and last chroma line (same as FillMargins plugin)
* int edge (8) - number of lines to crop and process
* int zero (16) - luma value shift before/after multiplication, 16 is usually fine on tv-range stuff
* float gauss_a1 (100) - strength of post-process blur, more means less blur, set to 100 or more to disable 
* float gauss_thr (1.5) - Dither_limit_dif16 threshold for post-process blur, elast = 1.5, set to 0 to disable
* int dith_mode (6) - dither_post mode, use 2 or -1(adds random noise) if you want to avoid error diffusion between lines
* string stat_file - if defined, writes difference of edge masks between result and input on frames where script seems to fail (wring l, t, r, b values).
* int disable_thr - reverts image on frames where script seems to fail (144 is sane value, smaller values make it disable more)


##awarpsharp16 (awarpsharp16.avsi)
awarpsharp2 wrapper with additional features.

Works with any planar YUV colorspaces, usage of non-square pixels is discouraged.

Requires Dither package and a recent awarpsharp2 build by Firesledge http://forum.doom9.org/showpost.php?p=1751543&postcount=79

Parameters:

* thresh: 0..255, default 128
 * Saturation limit for edge detection. Reduce for less aggressive sharpening.
* blur: 0..100, default 2 for type 0, 3 for type 1
 * Number of blur passes over edge mask. Less passes increase sharpening effect,
 * but can produce major artefacts with high depth and thresh. You can use values
 * higher than 100, but probably won't see any difference.
 * Chroma is processed with (blur+1)/2 passes.
* type: 0..1, default 0 for aWarpSharp2, 1 for aBlur
 * Type of blur:
   * 0 - radius 6 blur
    * 1 - radius 2 blur, requires around 8x more passes than type 0 for the same effect (will be just 2.5x slower), but produce better quality
* depth: -128..127, default 16 for aWarpSharp2, 3 for aWarp and aWarp4
  *Strength of the final warping. Negative values result in warping in opposite direction.
* chroma: 0..6
  * Processing mode for chroma planes (U and V):
    * -1 - similar to 4, additionally uses chroma sobel mask
    * 0 - fill with zeroes
    * 1 - don't care, default for aSobel and aBlur
    * 2 - copy
    * 3 - process
    * 4 - guide by luma - aWarpSharp, aWarp and aWarp4 only, default for them
    * 5 - same as 3, but don't process luma
    * 6 - same as 4, but don't process luma
* depthC: -128..127, default depth/3 for non-4:4:4 colorspaces, depth for YV24.
  *  Strength of the final warping of chroma planes. Negative values result in warping in opposite direction.
* lsb: 16bit stacked input and output
* cplace: chroma placement "MPEG2" (default) or "MPEG1"

##IVTCPP (ivtcpp.avsi)
A collection of scripts for post-processing telecined material. Required by Macron_IVTC(https://github.com/Zeght/Macron)