%import syslib
%import textio
%import diskio
%import string
%import jdbasic
%import jdapu
%import jdapu
%import jderr
%encoding iso

runlang {
    ubyte funcno = 0
    ubyte funcvar = 0
    ubyte funcit = 0
    str varname = "\x00" * 2

    sub do_for() {
        uword from_v,to_v,step_v
        ubyte vt,vn
        main.pcode++        ;get var type
        vt = @(main.pcode)
        main.pcode++        ;get var num
        vn = @(main.pcode)
        main.pcode++        ;skip '='
        main.pcode++
        from_v = apu.expr()     ;get from value
        main.pcode++
        to_v = apu.expr()      ;get to value
        step_v = @(main.pcode)  ;check for step
        if step_v == $46 {
            main.pcode++    
            step_v = apu.expr()
        } else {
            step_v = 1
        }
        if vt == tokens.FAST {
            @(vn as uword) = from_v as ubyte               
        } else if vt == tokens.INT or vt == tokens.VARIANT {
            jdvars.set_value(vn, from_v)
        } 
        forstack.push(main.pcode, vt, vn, from_v, to_v, step_v)
        main.pcode--
    }

    sub do_next() {
        ubyte vt,vn,vns
        uword to_v,f_addr,step_v, value
        main.pcode++        ;get var type
        vt = @(main.pcode)
        main.pcode++        ;get var num
        vn = @(main.pcode)
        vns = forstack.pop3()
        if vns!=vn {
            error.set(6)
        }
        to_v = forstack.pop5()
        step_v = forstack.pop6()
        if vt == tokens.FAST {
            value = @(vn as uword)        
        } else if vt == tokens.INT or vt == tokens.VARIANT {
            value = jdvars.get_value(vn)
        }         
        value += step_v
        if value <= to_v {
            if vt == tokens.FAST {
                @(vn as uword) = value as ubyte               
            } else if vt == tokens.INT or vt == tokens.VARIANT {
                jdvars.set_value(vn, value)
            } 
            f_addr = forstack.pop1()
            main.pcode = f_addr
            main.pcode--
        } else {
            value = forstack.pope()    
        }
    }

    sub do_goto() {
        uword value
        ubyte l,m
        ubyte r = 0
        r = main.next() ;get jump address
        l = @(main.pcode)
        main.pcode++
        m = @(main.pcode)
        value = mkword(m,l)  
        main.pcode = value
        main.pcode--
    }

    sub do_callfunc(ubyte lfunc) -> uword{
        bool lende = false
        uword cv = 0
        uword toaddr = 0
        ubyte token = 0
        ubyte n_funcno = 0
        ubyte n_funcvar = 0
        ubyte n_funcit = 0
        ubyte n_t = 0
        ubyte n_i = 0
        ;main.pcode++
        callstack_b.push(funcvar)
        callstack_b.push(funcno)
        for n_i in 1 to funcvar {
            @(&varname) = funcno
            @(&varname+1) = n_i
            n_t = jdlocal.get_indexbyname(varname)
            cv = jdlocal.get_value(n_t)
            callstack_w.push(cv)
        }
        n_funcvar = 0
        if lfunc > 0 {
            n_funcno = lfunc
        } else {
            main.pcode++
            n_funcno = @(main.pcode)
        }
        n_funcit = jdfunc.get_stack(n_funcno)
        n_funcit++
        jdfunc.set_stack(n_funcno,n_funcit)
        main.pcode++
        ;read all parameter until RIGHTPAREN
        ;we should better know all params, so we can add local vars with values instead stacking etc.
        do {
            if (@(main.pcode)==tokens.CALLFUNC or @(main.pcode)==tokens.L_FAST or @(main.pcode)==tokens.L_INT or @(main.pcode)==tokens.L_VARIANT or @(main.pcode)==tokens.ARRAY or @(main.pcode)==tokens.L_ARRAY or @(main.pcode)==tokens.INT or @(main.pcode)==tokens.VARIANT or @(main.pcode)==tokens.FAST or @(main.pcode)==tokens.NUMBER) { 
                n_funcvar ++
                if @(main.pcode)==tokens.ARRAY or @(main.pcode)==tokens.L_ARRAY {
                    main.pcode++
                    cv = @(main.pcode)
                    main.pcode++
                    n_t = @(main.pcode)
                    if n_t == tokens.C_RIGHTBRACKET {
                        ; txt.print("if ")

                        @(&varname) = n_funcno
                        @(&varname+1) = n_funcvar
                        jdlocal.insert(varname,cv)  ;save our array name to local var n_funcvar

                    } else {
                        ; txt.print("else ")
                        main.pcode--
                        main.pcode--
                        cv = apu.expr_f()
                        ; txt.print_uwhex(cv,true)
                        main.pcode--
                        @(&varname) = n_funcno
                        @(&varname+1) = n_funcvar
                        jdlocal.insert(varname,cv)
                    }
                } else {
                    callstack_b.push(n_funcno)          ;if we are in recursion : print a(b(1))
                    callstack_b.push(n_funcvar)
                    cv = apu.expr()
                    n_funcvar = callstack_b.pop()
                    n_funcno = callstack_b.pop()                    
                    main.pcode--
                    @(&varname) = n_funcno
                    @(&varname+1) = n_funcvar
                    jdlocal.insert(varname,cv)
                }
            } else if @(main.pcode)==tokens.P_CALLFUNC {
                n_funcvar ++
                main.pcode++
                cv = @(main.pcode)              ;put function number to local var
                @(&varname) = n_funcno
                @(&varname+1) = 1
                jdlocal.insert(varname,cv)
                main.pcode++      
            }

            main.pcode++    
            if @(main.pcode) == tokens.C_CR or @(main.pcode) == tokens.NOCMD or @(main.pcode) == tokens.C_RIGHTPAREN {
                lende = true
            }
        } until lende == true  
            
        if @(main.pcode) == tokens.C_RIGHTPAREN {
            main.pcode++
        }
        funcno = n_funcno
        funcvar = n_funcvar
        funcit = n_funcit
        funcstack.push(main.pcode)   
        ;find func address in hashtable and jump there
        toaddr = jdfunc.get_value(funcno)
        toaddr +=4
        cv = mkword(@(toaddr+1),@(toaddr))
        main.pcode = cv
        repeat {
            token = @(main.pcode)
            if token == tokens.NOCMD break
            if token == tokens.RETURN {
                main.pcode++
                cv = apu.expr()
                break
            }
            if token == tokens.ENDFUNC {
                cv = 0
                break
            }
            main.statement(token)
            main.pcode++
            ; if token == tokens.VARIANT {
            ;     ;main.pcode++
            ; }
        }
        do_endfunc()
        return cv
    }

    sub do_func() {
        uword efueaddr
        ubyte l,m
        main.pcode++    
        main.pcode++    ;skip func number
        l = @(main.pcode)
        main.pcode++
        m = @(main.pcode)
        efueaddr = mkword(m,l)   
        main.pcode = efueaddr
        main.pcode--
    }

    sub do_endfunc() {
        uword toaddr = 0
        uword cv = 0
        ubyte n_t = 0
        ubyte n_i = 0        
        toaddr = funcstack.pop()
        funcno = callstack_b.pop()
        funcvar = callstack_b.pop()
        for n_i in funcvar downto 1 {
            @(&varname) = funcno
            @(&varname+1) = n_i
            n_t = jdlocal.get_indexbyname(varname)
            cv = callstack_w.pop()
            jdlocal.set_value(n_t, cv)
        }
        main.pcode = toaddr
        main.pcode--

    }

    sub do_if() {
        uword elseaddr
        uword thenaddr
        uword endifaddr
        ubyte l,m
        bool b1 = true
        main.pcode++
        l = @(main.pcode)
        main.pcode++
        m = @(main.pcode)
        elseaddr = mkword(m,l)   
        main.pcode++     
        l = @(main.pcode)
        main.pcode++
        m = @(main.pcode)
        thenaddr = mkword(m,l)
        main.pcode++     
        l = @(main.pcode)
        main.pcode++
        m = @(main.pcode)
        endifaddr = mkword(m,l)
        ifstack.push(elseaddr, thenaddr, endifaddr) ;Remember my jumpaddresses in case of nested if        
        main.pcode++
        b1 = apu.relation()
        if b1 == true {
            main.pcode = thenaddr               ;jump to then 
            main.pcode--
        } else {
            if elseaddr == 0 {
                main.pcode = endifaddr              ;jump to endif address when there is no else branch
                main.pcode--

            } else {
                main.pcode = elseaddr               ;jump to else address
                main.pcode--
            }
        }
    }

    sub do_then() {
        ;nothing to do
        ubyte r = 0
        r = main.next() 
    }

    sub do_else() {
        ;we are in true branch, pop stack and jump to endif
        uword endifaddr
        endifaddr = ifstack.pope() ;get endif an jump there
        main.pcode = endifaddr
        main.pcode--
    }

    sub do_endif() {
        ;we are in false branch, pop stack
        ubyte r = 0
        uword endifaddr
        ;r = main.next() 
        endifaddr = ifstack.pope() ;ignore endif an clear stack
    }

    sub do_array(ubyte vartype) {
        ubyte r = 0
        ubyte i = 0
        ubyte n = 0
        uword ind = 0
        uword value = 0
        uword t = 0
        uword j = 0
        i = main.next() ;get index
        r = main.next() ;get bracket
        if r == tokens.C_RIGHTBRACKET {
            r = main.next() ;get EQ
            if @(main.pcode) == tokens.C_EQ {
                r = main.next() ;get left bracket
                if @(main.pcode) == tokens.C_LEFTBRACKET {
                    ;init array heap
                    value = jdheap.init_list(i)
                    jdarrvars.arrvars_addr[i] = value
                    do {
                        ;skip vartype
                        main.pcode ++
                        main.pcode ++
                        ;get val
                        value = apu.get_number()
                        ;append list
                        jdheap.add_list(value)
                        main.pcode ++       ;@main.pcode should be 1a(,) or 24 (])
                    } until (@(main.pcode) == tokens.C_RIGHTBRACKET or @(main.pcode) == 0 or @(main.pcode) == tokens.C_CR)
                    if @(main.pcode) == tokens.C_RIGHTBRACKET {
                        ;close list
                        main.pcode ++
                        if @(main.pcode) == tokens.C_ASTR and jdheap.ll == 1 {  ;we have an [val]*n initialiation
                            main.pcode ++ ;skip asterik
                            if @(main.pcode) == tokens.NUMBER {
                                main.pcode ++ ;skip number
                                t = apu.get_number()
                                for j in 1 to t {
                                    jdheap.add_list(value)
                                }
                            }
                        } else {
                            main.pcode --
                        }
                        jdheap.close_list()
                    }
                }
            }
        } else {
            ind = apu.expr()
            r = main.next() ;get bracket
            if @(main.pcode) == tokens.C_EQ {
                r = main.next() ;get EQ
                value = apu.expr()
                if vartype == 1 {               ;vartype 1 == local vars in functions, we need to get the calling list
                    @(&runlang.varname) = runlang.funcno
                    @(&runlang.varname+1) = i
                    n = jdlocal.get_name(runlang.varname) as ubyte
                    i = n
                } 
                jdarrvars.set_value(i, ind, value)
                main.pcode ++ 
            }
        }
    }

    sub do_let(ubyte vartype) {
        ubyte r = 0
        ubyte i = 0
        ubyte mt = @(main.pcode)
        uword value
        i = main.next() ;get index
        r = main.next() ;get C_EQ
        ; txt.print("start mt: ")
        ; txt.print_ubhex(mt,true)        
        ; txt.print(",i: ")
        ; txt.print_ubhex(i,true)        
        if r == tokens.C_EQ {
            main.next() ; Skip C_EQ
            varstack.push(vartype as uword)
            varstack.push(i as uword)
            if @(main.pcode) == tokens.CALLFUNC {
                ; txt.print("call: , ")
                value = apu.expr_l()
            } else {
                if vartype == 2 {
                    ; txt.print("call2 : , ")
                    value = apu.expr_str()
                } else {
                    txt.print("call e: , ")
                    value = apu.expr()
                }
            }
            ; txt.print("val: ")
            ; txt.print_uwhex(value,true)
            i = varstack.pop() as ubyte
            vartype = varstack.pop() as ubyte
            ; txt.print(", mt: ")
            ; txt.print_ubhex(mt,true)        
            ; txt.print(", i: ")
            ; txt.print_ubhex(i,true)        

            txt.nl()

            if vartype == 1 {
                if mt == tokens.L_FAST {
                    jdlocal.set_value(i, value)  
                } else {
                    @(i as uword) = value as ubyte               
                }
            } else if vartype == 0 {
                if mt == tokens.L_VARIANT or mt == tokens.L_INT {
                    jdlocal.set_value(i, value)
                } else {
                    jdvars.set_value(i, value)
                }
            } else if vartype == 2 {
                jdstrvars.set_value(i, value)
            } 
        } else {
            error.set(1)  ;Syntax Error
        }
        main.pcode--
    }
}