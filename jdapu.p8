%import syslib
%import textio
%import diskio
%import string
%import jdbasic
%import jdlang
%import jdcmds
%encoding iso

apu {
    ;expr/relation handling here!
    str strbuf = "\x00" * 255
    str strchr = "\x00" * 2

    sub relation() -> bool {
        uword  r1, r2
        bool r3,r4
        ubyte op4
        r1 = expr();
        op4 = @(main.pcode)
        txt.nl()
        txt.print("if: ")
        txt.print_uwhex(r1,true)
        txt.print("op: ")
        txt.print_ubhex(op4,true)
        txt.nl()
        while(op4 == tokens.C_LT or
            op4 == tokens.C_GT or
            op4 == tokens.C_EQ) {
            ;void main.next()
            main.pcode++
            r2 = expr();
            if op4 == tokens.C_LT r3 = r1 < r2;
            else if op4 == tokens.C_GT r3 = r1 > r2;
            else if op4 == tokens.C_EQ r3 = r1 == r2;
            ;void main.next()
            main.pcode++
            op4 = @(main.pcode)
        }
        return r3;
    }

    sub get_number() -> uword {
        uword n
        ubyte l,m
        l = @(main.pcode)
        main.pcode++
        m = @(main.pcode)
        n = mkword(m,l)
        return n
    }

    sub varfactor() -> uword {
        uword v,v1
        ubyte n
        ubyte op3

        op3 = @(main.pcode)
        if (op3 == tokens.FAST ) {
            main.pcode++        ; Skip Vartype
            v = @(@(main.pcode) as uword)
        } else if (op3 == tokens.INT or op3 == tokens.VARIANT ) {
            main.pcode++        ; Skip Vartype
            v = jdvars.get_value(@(main.pcode));
        } else if (op3 == tokens.ARRAY) {
            main.pcode++        ; Skip Vartype
            n = @(main.pcode)       ;get var number
            main.pcode++  
            callstack_b.push(n)            
            v1 = expr()
            n = callstack_b.pop()        
            v = jdarrvars.get_value(n, v1);
            ;main.pcode++
        } else if (op3 == tokens.L_ARRAY) {
            main.pcode++        ; Skip Vartype
            @(&runlang.varname) = runlang.funcno
            @(&runlang.varname+1) = @(main.pcode)
            n = jdlocal.get_name(runlang.varname) as ubyte      
            main.pcode++  
            callstack_b.push(n)            
            v1 = expr()
            n = callstack_b.pop()        
            v = jdarrvars.get_value(n, v1);
        } else if (op3 == tokens.L_FAST or op3 == tokens.L_INT or op3 == tokens.L_VARIANT) {
                main.pcode++        ; Skip Vartype
                @(&runlang.varname) = runlang.funcno
                @(&runlang.varname+1) = @(main.pcode)
                v = jdlocal.get_name(runlang.varname);
        }

        return v
    }

    sub factor() -> uword {
        uword r,r1
        ubyte op2, lfunc, ind
        
        callstack_w.push(r)
        op2 = @(main.pcode)
        if op2 == tokens.NUMBER  {
                main.pcode++        ; Skip Number
                r = get_number()
        } else if op2 == tokens.NOT {
                main.pcode++        ; Skip not
                if @(main.pcode) == tokens.NUMBER {
                    main.pcode++        ; Skip Number
                    r = get_number()
                } else {
                    r = varfactor()
                }
                r = ~r
        } else if op2 == tokens.C_LEFTPAREN {
                main.pcode++        ; Skip C_LEFTPAREN
                r = expr()
                main.pcode++        ; Skip C_RIGHTPAREN
        } else if op2 == tokens.CALLFUNC {
                r = runlang.do_callfunc(0)
                main.pcode--
        } else if op2 == tokens.L_CALLFUNC {
                main.pcode++
                @(&runlang.varname) =  runlang.funcno
                @(&runlang.varname+1) = 1 ; runcmd.funcvar
                ind = jdlocal.get_indexbyname(runlang.varname) 
                lfunc = jdlocal.get_value(ind)  as ubyte
                r = runlang.do_callfunc(lfunc)
        } else if op2 == tokens.PEEK {
                r = runcmd.do_peek()
        } else if op2 == tokens.VPEEK {
                r = runcmd.do_vpeek()
        } else if op2 == tokens.GET {
                r = runcmd.do_get()
        } else if op2 == tokens.GETXY {
                r = runcmd.do_get_pixel()
        } else if op2 == tokens.LEN {
                r = runcmd.do_len()
        } else if op2 == tokens.JIFFI {
                r = runcmd.do_get_jiffi()
        } 
        else if op2 == tokens.RND {
                r = runcmd.do_get_rnd()
        } else if op2 == tokens.JOY {
                r = runcmd.do_joy()
        }else {
            r = varfactor()
        }
        r1 = r
        r = callstack_w.pop()
        return r1
    }

    sub term() -> uword {
        uword f1, f2, f3
        ubyte op1
        callstack_w.push(f1)
        callstack_w.push(f2)
        f1 = factor();
        main.pcode++
        op1 = @(main.pcode)
        while(op1 == tokens.C_ASTR or
            op1 == tokens.C_SLASH or
            op1 == tokens.MOD) {
                ; void main.next()
                main.pcode++
                f2 = factor()
                if op1 == tokens.C_ASTR   { f1 = f1 * f2 }
                else if op1 == tokens.C_SLASH  {  f1 = f1 / f2 }
                else if op1 == tokens.MOD  { f1 = f1 % f2 }
                ; void main.next()
                main.pcode++
                op1 = @(main.pcode)
            }
        f3 = f1
        f2 = callstack_w.pop()
        f1 = callstack_w.pop()
        return f3
    }

    sub expr() -> uword {
        uword t1, t2, t3
        ubyte op;

        callstack_w.push(t1)
        callstack_w.push(t2)
        t1 = term()
        op = @(main.pcode)
        while(op == tokens.C_PLUS or
            op == tokens.C_MINUS or
            op == tokens.AND or
            op == tokens.OR) {
                ;void main.next()
                main.pcode++
                t2 = term()
                when op {
                    tokens.C_PLUS -> t1 = t1 + t2
                    tokens.C_MINUS ->  t1 = t1 - t2
                    tokens.AND -> t1 = t1 & t2
                    tokens.OR -> t1 = t1 | t2
                }
            op = @(main.pcode)
        }
        t3 = t1
        t2 = callstack_w.pop()
        t1 = callstack_w.pop()
        return t3
    }

    sub expr_f() -> uword {
        uword tf1, tf2
        ubyte opf;

        tf1 = term()
        opf = @(main.pcode)
        while(opf == tokens.C_PLUS or
            opf == tokens.C_MINUS or
            opf == tokens.AND or
            opf == tokens.OR) {
                ;void main.next()
                main.pcode++
                tf2 = term()
                when opf {
                    tokens.C_PLUS -> tf1 = tf1 + tf2
                    tokens.C_MINUS ->  tf1 = tf1 - tf2
                    tokens.AND -> tf1 = tf1 & tf2
                    tokens.OR -> tf1 = tf1 | tf2
                }
            opf = @(main.pcode)
        }
        return tf1
    }

    sub expr_l() -> uword {
        uword tl1, tl2
        ubyte opl;

        tl1 = term()
        opl = @(main.pcode)
        while(opl == tokens.C_PLUS or
            opl == tokens.C_MINUS or
            opl == tokens.AND or
            opl == tokens.OR) {
                ;void main.next()
                main.pcode++
                tl2 = term()
                when opl {
                    tokens.C_PLUS -> tl1 = tl1 + tl2
                    tokens.C_MINUS ->  tl1 = tl1 - tl2
                    tokens.AND -> tl1 = tl1 & tl2
                    tokens.OR -> tl1 = tl1 | tl2
                }
            ;main.next()
            opl = @(main.pcode)
        }
        return tl1
    }

    sub strvarfactor() -> uword {
        uword v
        ubyte op6
        op6 = @(main.pcode)
        if (op6 == tokens.STRVAR ) {
            ;void main.next() ; Skip Vartype
            main.pcode++
            v = jdstrvars.get_value(@(main.pcode));
            v++
            v++
            ;void main.next() ; Skip Varnum
            main.pcode++
        } 
        return v
    }

    sub strfactor() -> uword {
        uword r
        ubyte op4
        
        op4 = @(main.pcode)
        if op4 == tokens.STRING {
            main.pcode++
            r = main.pcode
            op4 = string.length(main.pcode) + 1
            main.pcode += op4
            return r
        } else if op4 == tokens.LEFT { 
            main.pcode++
            ;get varfactor (i think we should not allow terms here ???)
            ;get comma
            ;get left char count
            ;set 0 to left char count
        } else if op4 == tokens.CHR { 
            main.pcode++            ;skip "("
            main.pcode++            ;skip "("
            r = expr() 
            @(&strchr) = r as ubyte 
            main.pcode++            ;skip ")"
            return strchr
        } else r = strvarfactor()
        return r
    }

    sub expr_str() -> uword {
        uword ts1, ts2
        ubyte op5
        uword lp
        uword co

        ts1 = strfactor()
        lp=&strbuf
        co=0
        do {
            @(lp) = @(ts1)
            lp++
            ts1++
            co++
        } until (@(ts1)==0 or co == 255)
        @(lp) = 0 
        op5 = @(main.pcode)
        while(op5 == tokens.C_PLUS ) {
            ;void main.next()
            main.pcode++
            ts2 = strfactor()
            if op5 == tokens.C_PLUS {
                do {
                    @(lp) = @(ts2)
                    lp++
                    ts2++
                    co++
                } until (@(ts2)==0 or co == 255)                
                @(lp) = 0
            }
            ;main.next()
            op5 = @(main.pcode)
        }
        return strbuf
    }
}