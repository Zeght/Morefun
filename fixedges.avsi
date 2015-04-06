/*
fixedges - function for correcting darkened/brightened borders. Multiplies values of border lines by specified amount
Requires Dither package
Parameters:
    string l/t/r/b - values for multiplication, in "A:B1 B2 B3 B4 B5 B6" format which means ith line will be multiplied by (A/Bi).
                           Lines are ordered by distance from border with last line being the nearest one.
                           Example: "100.8: 110.3 110 90" will brighten line nearest to border and darken two next ones.
                           Optionally you can specify values for chroma in similar way after semicolon: "A:B1 B2;C:D1 D2"
                           Stare intensely on frame borders with high luma/chroma values on flat area to get best values.
                           Sample usage: frame should be completely (235) white, but top line has luma value 180, second is 200 third is 240
                                               specify t="235: 240 200 180" to fix that.
    int edge (8) - number of lines to crop and process
    int zero (16) - luma value shift before/after multiplication, 16 is usually fine on tv-range stuff
    float gauss_a1 (60) - strength of post-process blur, more means less blur, set to 100 or more to disable 
    float gauss_thr (1.5) - Dither_limit_dif16 threshold for post-process blur, elast = 1.5, set to 0 to disable
    int dith_mode (6) - dither_post mode, use 2 or -1(adds random noise) if you want to avoid error diffusion between lines
*/

#removes duplicate characters c from s
function str_dedouble(string s, string c)
{
    pos = s.FindStr(c+c)
    return (pos == 0) ? s : s.LeftStr(pos-1) + s.MidStr(pos+1).str_dedouble(c)
}

#counts characters c in s
function str_count(string s, string c)
{
    pos = s.FindStr(c)
    return (pos == 0) ? 0 : s.MidStr(pos+1).str_count(c) + 1
}

#increases height by stacking second line on top
function mirrortop8(clip src)
{
    return stackvertical(src.crop(0, 1, 0, 1), src)    
}

#16 bit version
function mirrortop(clip src)
{
    msb = src.dither_get_msb()
    lsb = src.dither_get_lsb()
    stackvertical(mirrortop8(msb),mirrortop8(lsb))
}

Function Dither_lut8_leaved (clip src,
\	string "expr", string "yexpr", string "uexpr", string "vexpr",
\	int "y", int "u", int "v")
{
	d_msb = Dither_lut8_msb (src,
\		expr=expr, yexpr=yexpr, uexpr=uexpr, vexpr=vexpr, y=y, u=u, v=v)
	d_lsb = Dither_lut8_lsb (src,
\		expr=expr, yexpr=yexpr, uexpr=uexpr, vexpr=vexpr, y=y, u=u, v=v)

	Interleave (d_msb, d_lsb)
}


function fixtopedge_generate_crop_lut(float norm, string vals, float zero, int linenum)
{
    szero = string(zero)
    line = "src.crop(0,"+string(linenum)+",0,1)"
    lineval = vals.LeftStr(vals.FindStr(" ")-1) 
    y = (lineval=="0") ? "2" : "3"
    lineval = lineval.Eval() - zero
    ex = "x "+szero+" - "+string(norm)+" * "+string(lineval)+" / "+szero+" + 256 *"
    lut = """.Dither_lut8_leaved(" """+ex+""" ", y="""+y+")" #mfw can't \n
    linecrop_lut = "line"+string(linenum)+"="+line+lut
    vals = vals.MidStr(vals.FindStr(" ")+1)
    return (vals.FindStr(" ")>1) ? (fixtopedge_generate_crop_lut(norm, vals, zero, linenum-1)+linecrop_lut) : linecrop_lut
}

function lineslist(int linenum)
{
    return (linenum==0) ? "line0" : lineslist(linenum-1) + ",line"+string(linenum) 
}

function fixtopedge_generate_eval(float norm, string vals, float zero, int h)
{
    vals = str_dedouble(vals+" ", " ")
    vals = (vals.LeftStr(1)==" ") ? vals.MidStr(2) : vals
    lines  = str_count(vals, " ") - 1
    crop_lut = fixtopedge_generate_crop_lut(norm, vals, zero, lines)
    lineb = "src.crop(0, "+string(lines+1)+", 0, 0)"
    nolut = (lines+1==h) ? "" : ","+lineb+".interleave(Dither_gen_null_lsb("+lineb+"))"
    stack = "Stackvertical("+lineslist(lines)+nolut+")"
    msblsb ="Stackvertical(SelectEven(), SelectOdd())"
    return "lines="+string(lines)+crop_lut + stack + msblsb
}


function fixtopedge_plane(clip src, string v, float zero, float "a1", float "thr", int "dith_mode")
{
    w = src.Width()
    h = src.Height()
    norm = v.LeftStr(v.FindStr(":")-1).Eval() - zero
    vals = v.MidStr(v.FindStr(":")+1)
    eval(fixtopedge_generate_eval(norm, vals, zero, h))
    blurred = last.mirrortop().dither_resize16(w, h+1, kernel="gauss", a1=a1, taps=2, fv=-1).dither_crop16(0, 1, 0, 0)
    blurred = (thr > 0) ? blurred.Dither_limit_dif16(last, thr=thr, elast=1.5, y=3, u=3, v=3) : blurred
    mask =  stackvertical(blankclip(src, height = lines+1, color_yuv=$FFFFFF),
\                                      blankclip(src, height = 1, color_yuv=$808080),
\                                      blankclip(src, height = h-lines-2, color_yuv=0)).crop(0,0,0,h)
    blurred = dither_merge16_8(last, blurred, mask)
    res = (a1 >= 100) ? last : blurred
    return res.ditherpost(mode=dith_mode, pat=2, ampn = (dith_mode == -1) ? 1 : 0)
}

function fixtopedge(clip src, string values, int "zero", float "a1", float "thr", int "dith_mode")
{
    lzero = zero
    czero = 128
    global count = 0
    splitter = values.FindStr(";")
    valuesl = (splitter == 0) ? values : (splitter == 1) ? "0:0" : values.LeftStr(splitter-1)
    valuesc = (splitter == 0 || splitter == StrLen(values)) ? "0:0" : values.MidStr(splitter+1)
    y = src.converttoy8().fixtopedge_plane(valuesl, lzero, a1, thr, dith_mode)
    splitter = valuesc.FindStr(";")
    valuesU = (splitter == 0) ? valuesc : (splitter == 1) ? "0:0" : valuesc.LeftStr(splitter-1)
    valuesV = (splitter == 0) ? valuesc : (splitter == 1) ? "0:0" : valuesc.MidStr(splitter+1)
    u = src.UtoY8().fixtopedge_plane(valuesU, czero, a1, thr, dith_mode)
    v = src.VtoY8().fixtopedge_plane(valuesV, czero, a1, thr, dith_mode)
    return YtoUV(u, v, y)
}

function fixedges(clip src, string "l", string "t", string "r", string "b", int "edge", float "zero", float "gauss_a1", float "gauss_thr", int "dith_mode")
{
    e = Default(edge, 8)
    zero = default(zero, 16)
    gauss_a1 = Default(dither_min(gauss_a1, 100), 60)
    gauss_thr = Default(gauss_thr, 1.5)
    dith_mode = Default(dith_mode, 6)
    w = src.Width()
    h = src.Height()
    te = src.crop(0,0,0,e)
    te = Defined(t) ? te.fixtopedge(t,zero,gauss_a1,gauss_thr,dith_mode) : te
    c = src.crop(0,e,0,-e)
    be = src.crop(0,h-e,0,0)
    be = Defined(b) ? be.Turn180().fixtopedge(b,zero,gauss_a1,gauss_thr,dith_mode).turn180() : be
    src = stackvertical(te,c,be)
    le = src.crop(0,0,e,0)
    le = Defined(l) ? le.TurnRight().fixtopedge(l,zero,gauss_a1,gauss_thr,dith_mode).TurnLeft() : le
    c = src.crop(e,0, -e, 0)
    re = src.crop(w-e, 0, 0, 0)
    re = Defined(r) ? re.TurnLeft().fixtopedge(r,zero,gauss_a1,gauss_thr,dith_mode).TurnRight() : re
    src = stackhorizontal(le,c,re)
    return src
}