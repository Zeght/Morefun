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
    return stackvertical(mirrortop8(msb),mirrortop8(lsb))
}

Function Dither_lut8_leaved (clip src,
\    string "expr", string "yexpr", string "uexpr", string "vexpr",
\    int "y", int "u", int "v")
{
    d_msb = Dither_lut8_msb (src,
    \    expr=expr, yexpr=yexpr, uexpr=uexpr, vexpr=vexpr, y=y, u=u, v=v)
    d_lsb = Dither_lut8_lsb (src,
    \    expr=expr, yexpr=yexpr, uexpr=uexpr, vexpr=vexpr, y=y, u=u, v=v)
    Interleave (d_msb, d_lsb)
}

function fixtopborder_generate_crop_lut(float norm, string vals, float zero, int linenum)
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
    return (vals.FindStr(" ")>1) ? (fixtopborder_generate_crop_lut(norm, vals, zero, linenum-1)+linecrop_lut) : linecrop_lut
}

function lineslist(int linenum)
{
    return (linenum==0) ? "line0" : lineslist(linenum-1) + ",line"+string(linenum) 
}

function fixtopborder_generate_eval(float norm, string vals, float zero, int h)
{
    vals = str_dedouble(vals+" ", " ")
    vals = (vals.LeftStr(1)==" ") ? vals.MidStr(2) : vals
    lines  = str_count(vals, " ") - 1
    crop_lut = fixtopborder_generate_crop_lut(norm, vals, zero, lines)
    lineb = "src.crop(0, "+string(lines+1)+", 0, 0)"
    nolut = (lines+1==h) ? "" : ","+lineb+".interleave(Dither_gen_null_lsb("+lineb+"))"
    assert(lines<h, "fixborders: 'border' parameter is too low")
    stack = "Stackvertical("+lineslist(lines)+nolut+")"
    msblsb ="Stackvertical(SelectEven(), SelectOdd())"
    return "lines="+string(lines)+crop_lut + stack + msblsb
}


function fixtopborder_plane(clip src, string v, float zero, float "a1", float "thr", int "dith_mode")
{
    dupnum = (v.FindStr("d")<=0) ? 0 : eval(v.MidStr(v.FindStr("d")+1))
    v = (v.FindStr("d")<=0) ? v : v.LeftStr(v.FindStr("d")-1)
    v = (v=="") ? "0:0" : v
    norm = v.LeftStr(v.FindStr(":")-1).Eval() - zero
    vals = v.MidStr(v.FindStr(":")+1)
    src = (dupnum == 0) ? src : src.crop(0, dupnum, 0, 0)
    w = src.Width()
    h = src.Height()
    eval(fixtopborder_generate_eval(norm, vals, zero, h-dupnum))
    (dupnum == 0) ? last : dither_resize16(w, h+dupnum, 0, -dupnum, w, h+dupnum, kernel="point")
    h = h + dupnum
    blurred = last.mirrortop().dither_resize16(w, h+1, kernel="gauss", a1=a1, taps=2, fv=-1).dither_crop16(0, 1, 0, 0)
    blurred = (thr > 0) ? blurred.Dither_limit_dif16(last, thr=thr, elast=1.5, y=3, u=3, v=3) : blurred
    mask =  stackvertical(blankclip(src, height = lines+1, color_yuv=$FFFFFF),
    \                                  blankclip(src, height = 1, color_yuv=$808080),
    \                                  blankclip(src, height = h-lines-2, color_yuv=0)).crop(0,0,0,h)
    blurred = dither_merge16_8(last, blurred, mask)
    res = (a1 >= 100) ? last : blurred
    return res.ditherpost(mode=dith_mode, pat=2, ampn = (dith_mode == -1) ? 1 : 0)
}

function fixtopborder(clip src, string values, int "zero", float "a1", float "thr", int "dith_mode")
{
    lzero = zero
    czero = 128
    global count = 0
    splitter = values.FindStr(";")
    valuesl = (splitter == 0) ? values : (splitter == 1) ? "0:0" : values.LeftStr(splitter-1)
    valuesc = (splitter == 0 || splitter == StrLen(values)) ? "0:0" : values.MidStr(splitter+1)
    y = src.converttoy8().fixtopborder_plane(valuesl, lzero, a1, thr, dith_mode)
    splitter = valuesc.FindStr(";")
    valuesU = (splitter == 0) ? valuesc : (splitter == 1) ? "0:0" : valuesc.LeftStr(splitter-1)
    valuesV = (splitter == 0) ? valuesc : (splitter == 1) ? "0:0" : valuesc.MidStr(splitter+1)
    u = src.UtoY8().fixtopborder_plane(valuesU, czero, a1, thr, dith_mode)
    v = src.VtoY8().fixtopborder_plane(valuesV, czero, a1, thr, dith_mode)
    return YtoUV(u, v, y)
}

function fixborders(clip src, string "l", string "t", string "r", string "b", int "border", float "zero", float "gauss_a1", float "gauss_thr", int "dith_mode", string "stat_file", int "disable_thr")
{
    e = Default(border, 8)
    zero = Default(zero, 16)
    gauss_a1 = min(Default(gauss_a1, 100), 100)
    gauss_thr = Default(gauss_thr, 1.5)
    dith_mode = Default(dith_mode, 6)
    w = src.Width()
    h = src.Height()
    src0 = src
    
    te = src.crop(0,0,0,e)
    te_minmax = te.mt_edge("min/max", 0, 255, u=3, v=3)
    te = Defined(t) ? te.fixtopborder(t,zero,gauss_a1,gauss_thr,dith_mode) : te
    te_minmax = te.mt_edge("min/max", 0, 255, u=3, v=3).mt_makediff(te_minmax, u=3, v=3)
    
    c = src.crop(0,e,0,-e)
    
    be = src.crop(0,h-e,0,0)
    be_minmax = be.mt_edge("min/max", 0, 255, u=3, v=3)
    be = Defined(b) ? be.Turn180().fixtopborder(b,zero,gauss_a1,gauss_thr,dith_mode).turn180() : be
    be_minmax = be.mt_edge("min/max", 0, 255, u=3, v=3).mt_makediff(be_minmax, u=3, v=3)
    
    src = defined(t) || defined(b) ? stackvertical(te, c, be) : src
    tb_minmax = defined(t) || defined(b) ? stackvertical(te_minmax, be_minmax).to16().dither_resize16(16, 16, kernel="linear")
    \                                    : src.blankclip(width=16, height=16, color_yuv=$808080).to16()
    
    le = src.crop(0,0,e,0)
    le_minmax = le.mt_edge("min/max", 0, 255, u=3, v=3)
    le = Defined(l) ? le.TurnRight().fixtopborder(l,zero,gauss_a1,gauss_thr,dith_mode).TurnLeft() : le
    le_minmax = le.mt_edge("min/max", 0, 255, u=3, v=3).mt_makediff(le_minmax, u=3, v=3)
    
    c = src.crop(e,0, -e, 0)
    
    re = src.crop(w-e, 0, 0, 0)
    re_minmax = re.mt_edge("min/max", 0, 255, u=3, v=3)
    re = Defined(r) ? re.TurnLeft().fixtopborder(r,zero,gauss_a1,gauss_thr,dith_mode).TurnRight() : re
    re_minmax = re.mt_edge("min/max", 0, 255, u=3, v=3).mt_makediff(re_minmax, u=3, v=3)
    
    src = defined(l) || defined(r) ? stackhorizontal(le,c,re) : src
    lr_minmax = defined(l) || defined(r) ? stackvertical(le_minmax, re_minmax).to16().dither_resize16(16, 16, kernel="linear")
    \                                    : src.blankclip(width=16, height=16, color_yuv=$808080).to16()
    
    minmax = dither_add16(lr_minmax, tb_minmax, dif=true, u=3, v=3).dither_lut16("x 128 256 * - 8 * 128 256 * + ").ditherpost(mode=-1, ampn=1, staticnoise=true).clense()
    
    wr = Defined(stat_file) ? minmax.WriteFileIf(stat_file, "averageluma()>144",  "current_frame", """ " " """, "averageluma()-128") : src
    src = Defined(disable_thr) ? minmax.ConditionalFilter(src0, src, "averageluma", ">", string(disable_thr)) : src
    src = Defined(stat_file) ? mt_logic("xor", src, wr, y=2, u=2, v=2) : src
    
    return src
}

function fixedges(clip src, string "l", string "t", string "r", string "b", int "edge", float "zero", float "gauss_a1", float "gauss_thr", int "dith_mode")
{
    return fixborders(src, l, t, r, b, edge, zero, gauss_a1, gauss_thr, dith_mode)
}