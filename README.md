#MoreFun
Some Avisynth  scipts
##MoreFun.avsi
Collection of small scripts. Some may be documented upon request.
###Debicubic16, DebicubicY16
lsb output for debicubic is broken, those wrappers make it less broken.
It shifts error from [+0..+128](on 16 bit scale) range to [-64..64] range.
Pass a clip downscaled with Dither_resize16 to completely fix gradients or use iter=true (stolen from a certain encoder's blog) for actually precise debicubic at half speed 
###Mdenoise
Simple MDegrain wrapper. Disable cachesuper if you want to use backward seeking.
###MoreFun
modified gradfun3 with following changes (not tested well)
*different defaults: smode=2, lsb=lsb_in=true
*thr_edg removed
*removegrain instead of Dither_removegrain_emul because rgtools works with all colorspaces
*optional maskclip, merged with internal rangemask
*optional chroma rangemasking (chromamask=true to mask chroma with chroma-based mask mixedmask=true to merge chroma-based and luma-based masks)
*optional blur with big radius and big rangemask(bigmode=0 for Dither_smoothgrad, bigmode>1 for Dither_Bilateral and mask computed with pseudo (8+log(bigmode)) precision)
*debug=2 shows clip after blurring with big radius, debug=1 stacks usual small radius rangemask with the big one
##shortcuts.avsi
Some shortcuts. Used by some scripts from MoreFun.avsi
##fixedges (fixedges.avsi)
Function for correcting darkened/brightened borders. Multiplies values of border lines by specified amount

Requires Dither package

Parameters:

* string l/t/r/b - values for multiplication, in "A:B1 B2 B3 B4 B5 B6" format which means ith line will be multiplied by (A/Bi).
 * Lines are ordered by distance from border with last line being the nearest one.
 * Example: "100.8: 110.3 110 90" will brighten line nearest to border and darken two next ones.
 * Optionally you can specify values for chroma in similar way after semicolon: "A:B1 B2;C:D1 D2"
 * You can also add d[number] after list of values to throw away data from [number] last lines instead of trying to fix them. Data will be copued from next line
 * Stare intensely on frame borders with high luma/chroma values on flat area to get best values.
 * Sample usage: frame should be completely (235) white, but top line has luma value 180, second is 200 third is 240. Specify t="235: 240 200 180" to fix that or t="235: 240 200 180d1" if you think last line can't be fixed properly
 * block "A:B1 B2 B3 B4 B5 B6" may be omited, for instance ";100:50" will only process chroma, "d1;d1" will mirror last luma and last chroma line
* int edge (8) - number of lines to crop and process
* int zero (16) - luma value shift before/after multiplication, 16 is usually fine on tv-range stuff
* float gauss_a1 (100) - strength of post-process blur, more means less blur, set to 100 or more to disable 
* float gauss_thr (1.5) - Dither_limit_dif16 threshold for post-process blur, elast = 1.5, set to 0 to disable
* int dith_mode (6) - dither_post mode, use 2 or -1(adds random noise) if you want to avoid error diffusion between lines

##awarpsharp16 (awarpsharp16.avsi)
awarpsharp2 wrapper with additional features.

Works with any planar YUV colorspaces, usage of non-square pixels is discouraged.

Requires Dither package and a certain awarpsharp2 build.

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
* cplace: chroma placement "MPEG2"(default) or "MPEG1"

##awarpsharp2-2015.04.06.zip
awarpsharp2 build required by awarpsharp16