%import syslib
%import textio
%import diskio
%import string
%import conv
%import jdcmds
%import jdlang
%import jddos
%import jdvars
%import jdstacks
%import jderr
%encoding iso
%zeropage floatsafe 
%zpreserved $41, $5B
%option no_sysinit

main {
    const uword mend = $9EFF
    str buffer = "\x00" * 64
    str lineinput = "?"*160
    str filename = "\x00" * 40
    uword prgptr = 0
    uword @requirezp pcode = 0
    uword pend = 0
    uword linenr = 0
    uword fstack = 0
    uword fstack1 = 0
    ubyte graphmode = 0     ;0=text, 1=320x200
    ubyte fgcolor = 5
    ubyte bgcolor = 0
    ubyte trace = 0
    ubyte fake = 0

    sub start() {
        ;cx16.rombank(0)
        ubyte e
        init_screen()
        init_system()
        init_basic()

        repeat {
            error.clear()
            sys.memset(&lineinput,160,0)
            ;sys.memset(pend,160,0)
            void txt.input_chars(lineinput)
            txt.nl()
            string.strip(lineinput)
            e = tokenize(&lineinput, pend)
            if error.get() > 0 {
                error.print()
            } else {
                if e == 0 runl()
            }
        }
    }

    sub init_basic() {
        txt.print("Ready")
        txt.nl()
        fake = 0
    }

    sub init_system() {
        uword mem = 0
        pend = sys.progend ()
        txt.print("Basic end:   ")
        txt.print_uwhex(pend,true)
        txt.nl()
        txt.print("Prog start:  ")
        txt.print_uwhex(pend+160,true)
        txt.nl()
        pcode = pend
        mem = (mend as word - pend as word) as uword
        txt.print("Free memory: ")
        txt.print_uw(mem)
        txt.nl()
        trace = 0
    }

    sub init_screen() {
        txt.color2(5, 0)
        ;cx16.VERA_DC_BORDER = 0
        txt.iso()
        txt.clear_screen()
        txt.print("NeReLa Basic v 0.6")
        txt.nl()
        txt.print("(c) 2024")
        txt.nl()
        fake=1 ;txt.CMD should never be last command in function, it will be compiled as jmp, not jsr!
    }   

    sub parse() -> ubyte {
        uword lp = 0
        ubyte p =0
        bool  flag
        uword basic_cmd
        uword prevptr
        buffer = ""
        repeat {
            if @(prgptr) == 0 { return tokens.NOCMD }

            if @(prgptr) == $0D or @(prgptr) == $0A { return tokens.C_CR }

            if string.isspace(@(prgptr)) { 
                prgptr++
                continue
            }

            ;no unary '-' - until i fix that parse error
            ;if (string.isdigit(@(prgptr)) or (@(prgptr) == '-' and string.isdigit(@(prgptr+1)))) or 
            if (string.isdigit(@(prgptr)) ) or 
                ( (@(prgptr) == '$' or @(prgptr) == '%') and ( string.isdigit(@(prgptr+1)) or @(prgptr+1)=='A' or @(prgptr+1)=='B'or @(prgptr+1)=='C'or @(prgptr+1)=='D'or @(prgptr+1)=='E'or @(prgptr+1)=='F' )) {
                lp=&buffer
                do {
                    @(lp) = @(prgptr)
                    lp++
                    prgptr++
                } until (string.contains(consts.DELIMITERCHAR, @(prgptr)) or @(prgptr) == $0D or @(prgptr) == $0A or @(prgptr) == $00)
                @(lp) = 0
                return tokens.NUMBER
            }

            p = singlechar( @(prgptr))
            if p == tokens.C_SEMICOLON {
                do {
                    prgptr++
                } until (@(prgptr) == 0 or @(prgptr) == $0D or @(prgptr) == $0A)             
                continue
            }
            if p>0 {
                prgptr++
                return p
            }

            if @(prgptr) == '"' {
                prgptr++
                lp=&buffer
                do {
                    @(lp) = @(prgptr)
                    lp++
                    prgptr++
                } until (@(prgptr) == '"' or @(prgptr) == 0 or @(prgptr) == $0D or @(prgptr) == $0A)
                if @(prgptr) == '"' {
                    @(lp) = 0
                    prgptr++
                    return tokens.STRING
                } else {
                  error.set(1)
                  return tokens.NOCMD
                }
            }

            if string.isletter(@(prgptr)) {    
               prgptr++ 
               if @(prgptr) == '!' {        ;FAST vars are !
                prgptr++
                flag = string.contains(consts.DELIMITERCHAR, @(prgptr))
                if @(prgptr) == 0  or @(prgptr) == $0a flag = true
                prgptr--
                ;prgptr--
                if flag {
                        buffer=""
                        return tokens.FAST
                } 
               }
               prgptr--
            }

            if string.isletter(@(prgptr)) {
                prevptr = prgptr
                lp=&buffer
                do {
                    @(lp) = @(prgptr)
                    lp++
                    prgptr++
                } until (string.isletter(@(prgptr))==false)
                @(lp) = 0
                basic_cmd = statements.get(buffer)
                if basic_cmd > 0 {
                    buffer = ""
                    return basic_cmd as ubyte
                }
                prgptr = prevptr
            }

            if string.isletter(@(prgptr)) {
                lp=&buffer
                do {
                    @(lp) = @(prgptr)
                    lp++
                    prgptr++
                } until ( (string.isletter(@(prgptr)) or string.isdigit(@(prgptr)) or @(prgptr)=='_') == false)
                @(lp) = 0

                if  @(prgptr) == '$' {
                    return tokens.STRVAR
                } else if @(prgptr) == '[' {
                    return tokens.ARRAY
                } else if @(prgptr) == '(' {
                    return tokens.CALLFUNC
                } else if @(prgptr) == '@' {
                    return tokens.P_CALLFUNC
                } else if @(prgptr) == '#' {
                    return tokens.FLOAT
                } else if @(prgptr) == '%' {
                    return tokens.INT
                } else if @(prgptr) == '&' {
                    return tokens.LONG
                } else if @(prgptr) == '!' {
                    return tokens.BYTE
                } else if @(prgptr) == ':' {
                    return tokens.LABEL
                } else {
                    return tokens.VARIANT            
                }
            }

            prgptr++
            return 0
        }
    }   

    sub tokenize(uword rprgptr, uword pcodebase) -> ubyte{
        uword t1 = 0
        uword strb = 0
        uword val = 0
        ubyte index = 0
        uword lp = 0
        ubyte infuncheader = 0
        ubyte paramcount = 0
        ubyte p_funcno = 0
        ubyte token = 0
        pcode = pcodebase
        prgptr = rprgptr
        do {
            token = parse()
            if (token > 0) {
                @(pcode) = token
                pcode++;
                strb = buffer
                if @(strb) != 0 {
                    if token == tokens.STRING {
                        do {
                            @(pcode) = @(strb)
                            pcode++
                            strb++
                        } until @(strb) == 0
                        @(pcode) = 0
                        pcode++
                    } else if token == tokens.NUMBER {
                        ;strb = conv.str2uword(buffer)
                        strb = conv.any2uword(buffer)
                        @(pcode) = lsb(cx16.r15)
                        pcode++
                        @(pcode) = msb(cx16.r15)
                        pcode++
                    } else if token == tokens.STRVAR {
                        @(pcode) = jdstrvars.insert(buffer, "")
                        prgptr++
                        pcode++                        
                    } else if token == tokens.ARRAY {
                        if infuncheader > 0 { ;we are in a function header, lets mark it local
                            paramcount++
                            pcode--
                            token = token + $80
                            @(pcode) = token
                            pcode++
                            @(pcode) = jdlocal.insert(buffer, paramcount)
                            prgptr++
                            pcode++
                        } else {
                            if fstack > 0 { ; is there an local var?
                                index = jdlocal.get_name(buffer) as ubyte
                                if index > 0 {
                                    pcode--
                                    token = token + $80
                                    @(pcode) = token
                                    pcode++
                                    @(pcode) = index
                                    prgptr++
                                    pcode++
                                } else {
                                    @(pcode) = jdarrvars.insert(buffer, "")
                                    prgptr++
                                    pcode++    
                                }
                            } else {
                                @(pcode) = jdarrvars.insert(buffer, "")
                                prgptr++
                                pcode++    
                            }
                        }
                    } else if token == tokens.VARIANT or token == tokens.INT {
                        if infuncheader > 0 { ;we are in a function header, lets mark it local
                            paramcount++
                            pcode--
                            token = token + $80
                            @(pcode) = token
                            pcode++
                            @(pcode) = jdlocal.insert(buffer, paramcount)
                            pcode++
                        } else {
                            if fstack > 0 { ; is there an local var?
                                index = jdlocal.get_name(buffer) as ubyte
                                if index > 0 {
                                    pcode--
                                    token = token + $80
                                    @(pcode) = token
                                    pcode++
                                    @(pcode) = index
                                    pcode++
                                } else {
                                    @(pcode) = jdvars.insert(buffer, 0)
                                    pcode++
                                }
                            } else {
                                @(pcode) = jdvars.insert(buffer, 0)
                                pcode++
                            }
                        }
                    } else if token == tokens.CALLFUNC {
                        if infuncheader > 0 {               ;we are in a function header, add local function 
                            paramcount++
                            pcode--
                            @(pcode) = tokens.L_CALLFUNC
                            pcode++
                            ;@(&buffer) = p_funcno
                            ;@(&buffer+1) = paramcount
                            @(pcode) = jdlocal.insert(buffer, $FF)
                            pcode++
                            prgptr++
                            prgptr++                        ;skip rightparen
                        } else if fstack > 0 {              ;we have to change function call to local
                                index = jdfunc.get_FuncNoByName(buffer)
                                if index > 0 {
                                    @(pcode) = index
                                    prgptr++
                                    pcode++
                                } else {
                                    index = jdlocal.get_indexbyname(buffer) as ubyte
                                    t1 = jdlocal.get_value(index)
                                    if index > 0 {
                                        pcode--
                                        token = token + $80
                                        @(pcode) = token
                                        pcode++
                                        @(pcode) = index
                                        pcode++
                                    }
                                    txt.nl()                                    
                                }
                        } else {
                            @(pcode) = jdfunc.get_FuncNoByName(buffer)
                            prgptr++
                            pcode++
                        }
                    } else if token == tokens.P_CALLFUNC {
                        @(pcode) = jdfunc.get_FuncNoByName(buffer)
                        prgptr++
                        pcode++
                    } else if token == tokens.LABEL {
                        index = labels.insert(buffer, 0)
                        @(pcode) = index 
                        pcode++
                        labels.set_value(index,pcode)
                        prgptr++
                    }
                } else {
                    if token == tokens.C_CR {
                        linenr++
                        @(pcode) = lsb(linenr)
                        pcode++
                        @(pcode) = msb(linenr)
                        pcode++
                        prgptr++
                    } else if token == tokens.FAST {
                        if infuncheader > 0 { ;we are in a function header, SYNTAX ERROR !!! NO FAST in locals!
                            paramcount++
                            pcode--
                            token = token + $80
                            @(pcode) = token
                            pcode++
                            lp=&buffer
                            if @(prgptr) > $60 
                                @(lp) = @(prgptr) - $20
                            else    
                                @(lp) = @(prgptr)
                            lp++
                            @(lp)  = 0
                            pcode++
                            @(pcode) = jdlocal.insert(buffer, paramcount)
                            prgptr++
                            pcode++
                        } else if fstack > 0 { ; is there a local var?
                                lp=&buffer
                                if @(prgptr) > $60 
                                    @(lp) = @(prgptr) - $20
                                else    
                                    @(lp) = @(prgptr)
                                lp++
                                @(lp)  = 0                        
                                index = jdlocal.get_name(buffer) as ubyte
                                if index > 0 {
                                    pcode--
                                    token = token + $80
                                    @(pcode) = token
                                    pcode++                                    
                                    @(pcode) = index
                                    pcode++
                                } else {
                                    if @(prgptr) > $60 
                                        @(pcode) = @(prgptr) - $20
                                    else    
                                        @(pcode) = @(prgptr)
                                    pcode++
                                }
                                prgptr++
                        } else {
                            if @(prgptr) > $60 
                                @(pcode) = @(prgptr) - $20
                            else    
                                @(pcode) = @(prgptr)
                            prgptr++
                            pcode++
                        }
                    } else if token == tokens.FUNC {
                        val = pcode
                        val--           ;flupp
                        token = parse()
                        if token == tokens.CALLFUNC {
                            infuncheader = 1
                            paramcount = 0
                            @(pcode) = jdfunc.insert(buffer, val)
                            ; txt.print("func: ")
                            ; txt.print(buffer)
                            ; txt.print(", ")
                            ; txt.print_ubhex(@(pcode),true)
                            p_funcno = @(pcode)
                            pcode++
                            @(pcode) = 0        ;2 byte for end func address
                            fstack = pcode      ;put address to stack
                            pcode++
                            @(pcode) = 0
                            pcode++
                            @(pcode) = 0        ;2 byte for start func address
                            fstack1 = pcode      ;put address to stack
                            pcode++
                            @(pcode) = 0
                            pcode++
                            prgptr++
                        }
                     } else if token == tokens.C_RIGHTPAREN {
                        if infuncheader > 0 {
                            infuncheader = 0
                            strb = fstack1
                            ; txt.print(", add1: ")
                            ; txt.print_uwhex(pcode,true)
                            @(strb) = lsb(pcode)
                            strb++
                            @(strb) = msb(pcode)
                            fstack1 = 0                            
                        }
                    } else if token == tokens.RETURN {
                        if infuncheader > 0 {
                            infuncheader = 0
                            strb = fstack1
                            ; txt.print(", ret: ")
                            ; txt.print_uwhex(pcode,true)                            
                            @(strb) = lsb(pcode)
                            strb++
                            @(strb) = msb(pcode)
                            fstack1 = 0                            
                        }
                    } else if token == tokens.IF {
                        ifstack.push(pcode, pcode+2, pcode+4)
                        @(pcode) = 0
                        pcode++
                        @(pcode) = 0
                        pcode++
                        @(pcode) = 0
                        pcode++
                        @(pcode) = 0
                        pcode++
                        @(pcode) = 0
                        pcode++
                        @(pcode) = 0
                        pcode++
                    } else if token == tokens.ELSE {
                        strb = ifstack.pops()
                        @(strb) = lsb(pcode)
                        strb++
                        @(strb) = msb(pcode)
                    } else if token == tokens.THEN {
                        strb = ifstack.popm()
                        @(strb) = lsb(pcode)
                        strb++
                        @(strb) = msb(pcode)
                    } else if token == tokens.ENDIF {
                        strb = ifstack.pope()
                        @(strb) = lsb(pcode)
                        strb++
                        @(strb) = msb(pcode)
                    } else if token == tokens.ENDFUNC {
                        @(pcode) = tokens.ENDFUNC
                        pcode++                        
                        strb = fstack
                            ; txt.print(", end: ")
                            ; txt.print_uwhex(pcode,true)
                            ; txt.nl()
                        @(strb) = lsb(pcode)
                        strb++
                        @(strb) = msb(pcode)
                        fstack = 0
                    } else if token == tokens.GOTO {
                        if string.isletter(@(prgptr))==false {
                            do {
                                    prgptr++
                            } until string.isletter(@(prgptr))
                        }
                        if string.isletter(@(prgptr)) {
                            lp=&buffer
                            do {
                                @(lp) = @(prgptr)
                                lp++
                                prgptr++
                            } until (string.isletter(@(prgptr))==false)
                            @(lp) = 0
                            strb = labels.get_jmpaddress(buffer)
                            @(pcode) = lsb(strb)
                            pcode++
                            @(pcode) = msb(strb)
                            pcode++
                        }
                    }
                }

            } else {
                ;error.set(1)
                break
            }

        } until token == tokens.NOCMD
        return 0
    }  

    sub get_string(str fname) {
        uword fptr
        fptr  = fname
        pcode++
        do {
            @(fptr) = @(pcode)
            pcode++
            fptr++
        } until @(pcode)==0
        @(fptr) = 0
    }

    sub next() -> ubyte {
        ubyte token = 0
        pcode++
        token = @(pcode)
        return token
    }

    ; sub get_token() -> ubyte {
    ;     ubyte token = 0
    ;     token = @(pcode)
    ;     return token
    ; }

    sub tokenize_all() {
        ubyte e
        ubyte sbank
        main.linenr = 0
        sbank = cx16.getrambank()
        cx16.rambank(2) 
        e = tokenize($A000, pend+160)
        @(pcode) = tokens.NOCMD
        @(pcode+1) = 0
        cx16.rambank(sbank) 
        if ifstack.isc > 0 and ifstack.isc < 255 {
            error.set(4)
            error.print()
            error.clear()
        }
        if fstack > 0 {
            error.set(5)
            error.print()
            error.clear()
        }
    }

    sub runl() {
        ubyte token = 0
        pcode = pend
        repeat {
            token = @(pcode)
            if token == tokens.NOCMD break
            statement(token)
            if error.get() > 0 {
                error.print()
                break
            }
            token = @(pcode)
            if token == tokens.NOCMD break
            pcode++
        }
    }

    sub runp() {
        ubyte token = 0
        uword ocode = 0
        ocode = pcode
        pcode = pend + 160
        ifstack.clear()
        funcstack.clear()
        forstack.clear()
        varstack.clear()
        callstack_b.clear()
        callstack_w.clear()
        repeat {
            token = @(pcode)
            ; txt.print_ubhex(token,true)
            ; txt.print(" , ")
            if token == tokens.NOCMD or cbm.STOP2() break
            statement(token)
            pcode++
        }
        txt.print("Ready")
        txt.nl()
        pcode = ocode
    }

    sub statement(ubyte token) {
        ubyte status = 0
        uword line = 0
        ubyte l,m
        if trace == 1 {
            txt.print("(")
            txt.print_uwhex(token,true)
            txt.print(")")            
        }
        if token == tokens.CLS {
            runcmd.do_cls()
        } else if token == tokens.L_INT or token == tokens.L_VARIANT or token == tokens.VARIANT or token == tokens.INT {
            runlang.do_let(0)
        } else if token == tokens.L_FAST or token == tokens.FAST {
            runlang.do_let(1)
        } else if token == tokens.STRVAR {
            runlang.do_let(2)
        } else if token == tokens.ARRAY {
            runlang.do_array(0)
        } else if token == tokens.L_ARRAY {
            runlang.do_array(1)
        } else if token == tokens.FUNC {
            runlang.do_func()
        } else if token == tokens.CALLFUNC {
            void runlang.do_callfunc(0)
        } else if token == tokens.ENDFUNC {
            runlang.do_endfunc()
        } else if token == tokens.IF {
            runlang.do_if()          
        } else if token == tokens.THEN {
            runlang.do_then()
        } else if token == tokens.C_CR {
            pcode++
            if trace == 1 {
                l = @(main.pcode)
                pcode++
                m = @(main.pcode)
                line = mkword(m,l)                 
                txt.print("[")
                txt.print_uwhex(line,true)
                txt.print("]")
            } else {
                pcode++
            }
        } else if token == tokens.ELSE {
            runlang.do_else()
        } else if token == tokens.ENDIF {
            runlang.do_endif()
        } else if token == tokens.FOR {
            runlang.do_for()
        } else if token == tokens.NEXT {
            runlang.do_next()
        } else if token == tokens.PRINT {
            runcmd.do_print()
            pcode--
        } else if token == tokens.LIST {
            void rundos.do_list()
        } else if token == tokens.GOTO {
            runlang.do_goto()
        } else if token == tokens.LABEL {
            pcode++     ;scip label no
        } else if token == tokens.POKE {
            runcmd.do_poke()
        } else if token == tokens.VPOKE {
            runcmd.do_vpoke()
        } else if token == tokens.FLUPP {
            runcmd.do_flupp()
        } else if token == tokens.SETCHR {
            runcmd.do_setchr()
        } else if token == tokens.SETCLR {
            runcmd.do_setclr()
        } else if token == tokens.COLOR {
            runcmd.do_color()
        } else if token == tokens.LOCATE {
            runcmd.do_locate()
        } else if token == tokens.GRAPH {
            runcmd.do_graph()
        } else if token == tokens.LINE {
            runcmd.do_line()
        } else if token == tokens.RECT {
            runcmd.do_rect()
        } else if token == tokens.CIRCLE {
            runcmd.do_wait()
        } else if token == tokens.TRON {
            trace = 1
        } else if token == tokens.TROFF {
            trace = 0
        } else if token == tokens.PLOT {
            runcmd.do_plot()
        } else if token == tokens.LOAD {
            status = rundos.do_load()
            if status == 0 {
                tokenize_all()
                uword mem = (mend as word - pcode as word) as uword
                txt.print("Free memory: ")
                txt.print_uw(mem)
                txt.nl()                
            }
        } else if token == tokens.EDIT {
            void rundos.do_edit()
        } else if token == tokens.DIR {
            void rundos.do_dir()
        } else if token == tokens.RUN {
            runcmd.do_run()
        }
    }

    sub singlechar(ubyte ptr) -> ubyte
    {
        if(ptr == '\n') {
            return tokens.C_CR;
        } else if(ptr == ',') {
            return tokens.C_COMMA;
        } else if(ptr == ';') {
            return tokens.C_SEMICOLON;
        } else if(ptr == '+') {
            return tokens.C_PLUS;
        } else if(ptr == '-') {
            return tokens.C_MINUS;
        } else if(ptr == '|') {
            return tokens.C_OR;
        } else if(ptr == '*') {
            return tokens.C_ASTR;
        } else if(ptr == '/') {
            return tokens.C_SLASH;
        } else if(ptr == '%') {
            return tokens.C_MOD;
        } else if(ptr == '(') {
            return tokens.C_LEFTPAREN;
        } else if(ptr == '[') {
            return tokens.C_LEFTBRACKET;
        } else if(ptr == ']') {
            return tokens.C_RIGHTBRACKET;
        } else if(ptr == '#') {
            return tokens.C_HASH;
        } else if(ptr == ')') {
            return tokens.C_RIGHTPAREN;
        } else if(ptr == '<') {
            return tokens.C_LT;
        } else if(ptr == '>') {
            return tokens.C_GT;
        } else if(ptr == '=') {
            return tokens.C_EQ;
        } else if(ptr == '$') {
            return tokens.C_DOLLAR;
        }
        return 0;
    }

}

consts {
    str DELIMITERCHAR = " =,;#()]*/-+%&><"
}

tokens {
    const ubyte T_EOF       = 0
    const ubyte FUNC        = $01
    const ubyte ENDFUNC     = $02
    const ubyte LOCAL       = $03
    const ubyte FOR         = $04
    const ubyte BREAK       = $05
    const ubyte IF          = $06
    const ubyte THEN        = $07
    const ubyte ELSE        = $08
    const ubyte ENDIF       = $09
    const ubyte AND         = $0A
    const ubyte OR          = $0B
    const ubyte NOT         = $0C
    const ubyte MOD         = $0D
    const ubyte TRUE        = $0E
    const ubyte FALSE       = $0F
    const ubyte DO          = $10
    const ubyte WHILE       = $11
    const ubyte REPEAT      = $12
    const ubyte UNTIL       = $13
    const ubyte DIM         = $14
    const ubyte AS          = $15 
    const ubyte LABEL       = $16
    const ubyte GOTO        = $17
    const ubyte PRINT       = $18
    const ubyte C_CR        = $19; Single character C_*
    const ubyte C_COMMA     = $1A
    const ubyte C_SEMICOLON = $1B
    const ubyte C_PLUS      = $1C
    const ubyte C_MINUS     = $1D
    const ubyte C_OR        = $1E
    const ubyte C_ASTR      = $1F
    const ubyte C_SLASH     = $20
    const ubyte C_MOD       = $21
    const ubyte C_LEFTPAREN = $22
    const ubyte C_LEFTBRACKET= $23
    const ubyte C_RIGHTBRACKET= $24
    const ubyte C_HASH      = $25
    const ubyte C_RIGHTPAREN= $26
    const ubyte C_LT        = $27
    const ubyte C_GT        = $28
    const ubyte C_EQ        = $29
    const ubyte C_DOLLAR    = $2A    
    const ubyte RETURN      = $2B
    const ubyte NUMBER      = $2C
    const ubyte STRING      = $2D
    const ubyte FAST        = $2E
    const ubyte BYTE        = $2F
    const ubyte INT         = $30
    const ubyte LONG        = $31
    const ubyte FLOAT       = $32
    const ubyte DOUBLE      = $33
    const ubyte ARRAY       = $34
    const ubyte STRVAR      = $35
    const ubyte L_FAST      = $AE
    const ubyte L_BYTE      = $AF
    const ubyte L_INT       = $B0
    const ubyte L_LONG      = $B1
    const ubyte L_FLOAT     = $B2
    const ubyte L_DOUBLE    = $B3
    const ubyte L_ARRAY     = $B4
    const ubyte MODULE      = $40
    const ubyte GOFUNC      = $41
    const ubyte F_INC       = $42
    const ubyte TO          = $43
    const ubyte VARIANT     = $44
    const ubyte L_VARIANT   = $C4
    const ubyte NEXT        = $45
    const ubyte STEP        = $46
    const ubyte CALLFUNC    = $47
    const ubyte L_CALLFUNC  = $C7
    const ubyte P_CALLFUNC  = $D7
    const ubyte PEEK        = $48
    const ubyte POKE        = $49
    const ubyte VPEEK       = $4A
    const ubyte VPOKE       = $4B
    const ubyte FLUPP       = $4C
    const ubyte INPUT       = $4D   ;continue with $BA!
    const ubyte GET         = $BA
    const ubyte LEN         = $BB
    const ubyte COLOR       = $BC
    const ubyte LOCATE      = $BD
    const ubyte SETCHR      = $BE
    const ubyte JIFFI       = $BF
    const ubyte LEFT        = $C0
    const ubyte RIGHT       = $C1
    const ubyte MID         = $C2
    const ubyte TRIM        = $C3
    const ubyte ASC         = $C5
    const ubyte RND         = $C6
    const ubyte JOY         = $C8   ;c7 is L_CALLFUNC
    const ubyte SETCLR      = $C9   
    const ubyte CHR         = $CA
    const ubyte GRAPH       = $CB
    const ubyte LINE        = $CC
    const ubyte RECT        = $CD
    const ubyte CIRCLE      = $CE
    const ubyte PLOT        = $CF
    const ubyte GETXY       = $D0
    const ubyte WAIT        = $D1
    const ubyte LIST        = $70
    const ubyte RUN         = $71
    const ubyte EDIT        = $72
    const ubyte DIR         = $73
    const ubyte LOAD        = $74
    const ubyte CLS         = $75
    const ubyte TRON        = $76
    const ubyte TROFF       = $77
    const ubyte WHITE       = $7D
    const ubyte TOKEN       = $7E
    const ubyte NOCMD       = $7F    
}

statements {
    uword[] statements_table = [
        "list", tokens.LIST,
        "run", tokens.RUN,
        "edit", tokens.EDIT,
        "dir", tokens.DIR,
        "load", tokens.LOAD,
        "cls", tokens.CLS,
        "func", tokens.FUNC, 
        "endfunc", tokens.ENDFUNC,
        "local", tokens.LOCAL,
        "for", tokens.FOR,
        "break", tokens.BREAK,
        "if", tokens.IF,
        "then", tokens.THEN,
        "else", tokens.ELSE,
        "endif", tokens.ENDIF,
        "and", tokens.AND,
        "or", tokens.OR,
        "not", tokens.NOT,
        "mod", tokens.MOD,
        "true", tokens.TRUE,
        "false", tokens.FALSE,
        "do", tokens.DO,
        "while", tokens.WHILE,
        "repeat", tokens.REPEAT,
        "until", tokens.UNTIL,
        "dim", tokens.DIM,
        "as", tokens.AS,
        "goto", tokens.GOTO,
        "print", tokens.PRINT,
        "return", tokens.RETURN,
        "to", tokens.TO,
        "next", tokens.NEXT,
        "step", tokens.STEP,
        "peek", tokens.PEEK,
        "poke", tokens.POKE,
        "vpeek", tokens.VPEEK,
        "vpoke", tokens.VPOKE,
        "flupp", tokens.FLUPP,
        "input", tokens.INPUT,
        "get", tokens.GET,
        "len", tokens.LEN,
        "color", tokens.COLOR,
        "locate", tokens.LOCATE,
        "setchr", tokens.SETCHR,
        "setclr", tokens.SETCLR,
        "jiffi", tokens.JIFFI,
        "left", tokens.LEFT,
        "right", tokens.RIGHT,
        "mid", tokens.MID,         
        "trim", tokens.TRIM,        
        "chr", tokens.CHR,         
        "asc", tokens.ASC,         
        "rnd", tokens.RND,         
        "joy", tokens.JOY,
        "chr", tokens.CHR,
        "graph", tokens.GRAPH,
        "line", tokens.LINE,
        "rect", tokens.RECT,
        "circle", tokens.CIRCLE,
        "plot", tokens.PLOT,
        "getxy", tokens.GETXY,
        "wait", tokens.WAIT,
        "tron", tokens.TRON,
        "troff", tokens.TROFF

    ]

    sub get(str statement) -> uword {
        ubyte i
        for i in 0 to len(statements_table)-1 step 2 {
            if string.compare(statement, statements_table[i])==0
                return statements_table[i+1] 
        }
        return 0
    }
}