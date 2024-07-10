%import syslib
%import textio
%import diskio
%import string
%import graphics
%import jdbasic
%import jdapu
%import jderr
%encoding iso

runcmd {

    sub do_flupp() {
        txt.print("command FLUPP testcode here.")
        txt.nl()
    }

    sub do_cls() {
        if main.graphmode == 1 {
            graphics.clear_screen(main.fgcolor, main.bgcolor)
            txt.clear_screen()
        } else {
            txt.clear_screen()
        }
    }

    sub do_run() {
        main.runp()
    }

    sub do_input() {
        ubyte r = 0
        ubyte i = 0
        uword v = 0
        sys.memset(&main.lineinput,160,0)
        r = main.next()
        i = main.next()
        void txt.input_chars(main.lineinput)   
        txt.nl()     
        if r == tokens.STRVAR {
            jdstrvars.set_value(i, main.lineinput)
        } else if r == tokens.VARIANT or r == tokens.INT {
            v = conv.str2uword(main.lineinput)
            ; txt.print("lall: ")
            ; txt.print_uw(v)
            ; txt.nl()
            jdvars.set_value(i,v)
        } 
    }

    sub do_get() -> ubyte {
        ubyte r = 0
        ubyte v = 0
        r = main.next()         ;skip LEFTPAREN
        r = main.next()         ;skip RIGHTPAREN
        v = txt.waitkey()
        return v
    }

    sub do_len() -> uword {
        ubyte r = 0
        uword v = 0
        r = main.next()         ;skip LEFTPAREN
        r = main.next()         ;get next param
        if r == tokens.ARRAY  { ; need or r == tokens.L_ARRAY TODO!
            r = main.next()     ;get var nr
            v = jdarrvars.get_len(r)
        } else if r == tokens.STRVAR {
            r = main.next()     ;get var nr
            ;jdtodo remember string.length
        }
        return v
    }


    sub do_joy() -> uword {
        ubyte r = 0
        ubyte a = 0
        r = main.next()         ;skip LEFTPAREN
        r = main.next()         ;skip LEFTPAREN
        a = apu.expr() as ubyte
        cx16.r1, void = cx16.joystick_get(a)
        return cx16.r1
    }

    sub do_peek() -> uword {
        ubyte r = 0
        uword a = 0
        uword v = 0
        r = main.next()         ;skip LEFTPAREN
        a = apu.expr()
        v = peek(a) as uword
        r = main.next()         ;skip RIGHTPAREN
        return v
    }

    sub do_get_jiffi() -> uword {
        ubyte r = 0
        uword v = 0
        r = main.next()         ;skip LEFTPAREN
        v = cbm.RDTIM16()
        r = main.next()         ;skip RIGHTPAREN        
        return v
    }

    sub do_get_rnd() -> uword {
        ubyte r = 0
        uword a = 0
        uword v = 0
        r = main.next()         ;skip token
        r = main.next()         ;skip LEFTPAREN
        if r != tokens.C_RIGHTPAREN {
            a = apu.expr()
            math.rndseed(a,a)
        } 
        v = math.rndw()
        ;r = main.next()         ;skip RIGHTPAREN   
        return v
    }    

    sub do_get_pixel() -> uword {
        ubyte r = 0
        uword a = 0
        uword b = 0
        uword v = 0
        r = main.next()         ;skip token
        r = main.next()         ;skip LEFTPAREN
        if r != tokens.C_RIGHTPAREN {
            a = apu.expr()
            r = main.next()         ;skip komma
            b = apu.expr()
        } 
        cx16.FB_cursor_position(a,b)
        v = cx16.FB_get_pixel() 
        ;r = main.next()         ;skip RIGHTPAREN   
        return v
    }    

    sub do_poke() {
        ubyte r = 0
        uword a = 0
        uword v = 0
        r = main.next()         ;get next param
        a = apu.expr()
        r = main.next()         ;skip comma
        v = apu.expr()
        poke(a,v as ubyte)
        main.pcode--
    }

    sub do_vpeek() -> uword {
        ubyte r = 0
        uword a = 0
        const ubyte b = 1
        uword v = 0
        r = main.next()         ;skip LEFTPAREN
        a = apu.expr()
        v = cx16.vpeek(b,a) as uword
        r = main.next()         ;skip RIGHTPAREN
        return v
    }

    sub do_vpoke() {
        ubyte r = 0
        uword a = 0
        uword v = 0
        r = main.next()         ;get next param
        a = apu.expr()
        r = main.next()         ;skip comma
        v = apu.expr()
        ;vpoke do a jmp not a jsr in asm
        ; cx16.vpoke(b, a,v as ubyte)
        %asm {{
        lda  p8v_a
        sta  cx16.r0
        lda  p8v_a+1
        sta  cx16.r0+1
        ldy  p8v_v
        lda  #1        
        stz  cx16.VERA_CTRL
        sta  cx16.VERA_ADDR_H
        lda  cx16.r0
        sta  cx16.VERA_ADDR_L
        lda  cx16.r0+1
        sta  cx16.VERA_ADDR_M
        sty  cx16.VERA_DATA0        
        }}
        main.pcode--
    }

    sub do_color() {
        ubyte r = 0
        ubyte a = 0
        ubyte v = 0
        r = main.next()         ;get next param
        a = apu.expr() as ubyte
        if @(main.pcode) == tokens.C_COMMA {
            r = main.next()         ;skip comma
            v = apu.expr() as ubyte
            if main.graphmode == 0 {
                txt.color2(a, v)
            } else {
                main.fgcolor = a
                main.bgcolor = v
                graphics.colors(a, v)
            }
            main.pcode--
        } else {
            txt.color(a)
            main.pcode--
        }
    }

    sub do_setchr() {
        ubyte r = 0
        ubyte a = 0
        ubyte b = 0
        ubyte v = 0
        r = main.next()         ;get next param
        a = apu.expr() as ubyte
        if @(main.pcode) == tokens.C_COMMA {
            r = main.next()         ;skip comma
            b = apu.expr() as ubyte
            r = main.next()         ;get next param            
            v = apu.expr() as ubyte
            txt.setchr(a,b,v)
        } 
        main.pcode--
    }

    sub do_setclr() {
        ubyte r = 0
        ubyte a = 0
        ubyte b = 0
        ubyte v = 0
        r = main.next()         ;get next param
        a = apu.expr() as ubyte
        if @(main.pcode) == tokens.C_COMMA {
            r = main.next()         ;skip comma
            b = apu.expr() as ubyte
            r = main.next()         ;get next param            
            v = apu.expr() as ubyte
            txt.setclr(a,b,v)
        } 
        main.pcode--
    }

    sub do_locate() {
        ubyte r = 0
        ubyte a = 0
        ubyte b = 0
        r = main.next()         ;get next param
        a = apu.expr() as ubyte
        if @(main.pcode) == tokens.C_COMMA {
            r = main.next()         ;skip comma
            b = apu.expr() as ubyte
            txt.plot(a,b)
        } 
        main.pcode--
    }    

    sub do_graph() {
        ubyte r = 0
        uword a = 0
        uword v = 0
        r = main.next()         ;get next param
        a = apu.expr()
        if a==1 {
            main.graphmode = 1
            graphics.enable_bitmap_mode()
        } else {
            main.graphmode = 0
            graphics.disable_bitmap_mode()
        }
        main.pcode--
    }

    sub do_wait() {
        ubyte r = 0
        uword a = 0
        r = main.next()         ;get next param
        a = apu.expr()
        sys.wait(a)
        main.pcode--
    }

    sub do_line() {
        ubyte r = 0
        uword a = 0
        ubyte b = 0      
        uword c = 0
        ubyte d = 0  
        r = main.next()         ;get next param
        a = apu.expr() 
        if @(main.pcode) == tokens.C_COMMA {
            r = main.next()         ;skip comma
            b = apu.expr() as ubyte
            r = main.next()         ;get next param            
            c = apu.expr() 
            r = main.next()         ;get next param            
            d = apu.expr() as ubyte
            graphics.line(a, b, c, d)
        } 
        main.pcode--            
    }

    sub do_rect() {
        ubyte r = 0
        uword a = 0
        uword b = 0      
        uword c = 0
        uword d = 0    
        uword e = 0    
        r = main.next()         ;get next param
        a = apu.expr() 
        if @(main.pcode) == tokens.C_COMMA {
            r = main.next()         ;skip comma
            b = apu.expr() 
            r = main.next()         ;get next param            
            c = apu.expr() 
            r = main.next()         ;get next param            
            d = apu.expr() 
            if @(main.pcode) == tokens.C_COMMA {
                r = main.next()
                e = apu.expr() 
                graphics.fillrect(a, b, c, d)
            } else {
                graphics.rect(a, b, c, d)
            }
        } 
        main.pcode--             
    }    

    sub do_circle() {
        ubyte r = 0
        uword a = 0
        ubyte b = 0      
        ubyte c = 0
        r = main.next()         ;get next param
        a = apu.expr() 
        if @(main.pcode) == tokens.C_COMMA {
            r = main.next()         ;skip comma
            b = apu.expr() as ubyte
            r = main.next()         ;get next param            
            c = apu.expr() as ubyte
            graphics.circle(a, b, c)
        } 
        main.pcode--             
    }

    sub do_plot() {
        ubyte r = 0
        uword a = 0
        uword b = 0   
        r = main.next()         ;get next param
        a = apu.expr() 
        if @(main.pcode) == tokens.C_COMMA {
            r = main.next()         ;skip comma
            b = apu.expr() 
            graphics.plot(a, b)
        } 
        main.pcode--              
    }

    sub do_print() {
        ubyte r = 0
        bool nl = true
        uword v = 0
        ubyte lg = 0
        r = main.next()
        
        do {
            if r == tokens.C_COMMA {
                txt.print(" ")
                r = main.next()
            } else if r == tokens.C_SEMICOLON {
                nl = false
                r = main.next()
            } else if r == tokens.GETXY or r == tokens.RND or r == tokens.LEN or r == tokens.JIFFI or r == tokens.ARRAY or r == tokens.CALLFUNC or r == tokens.L_FAST or r == tokens.L_INT or r == tokens.L_VARIANT or r == tokens.FAST or r == tokens.INT or r == tokens.VARIANT or r == tokens.NUMBER or r == tokens.C_LEFTPAREN {
                v = apu.expr()
                txt.print_uw(v)
                r = @(main.pcode)
            } else if r == tokens.STRING {
                main.pcode++
                lg = string.length(main.pcode)
                txt.print(main.pcode)
                main.pcode +=lg
                r = main.next()
            } else if r == tokens.STRVAR or r == tokens.CHR {
                v = apu.expr_str()
                txt.print(v)
                r = @(main.pcode)                
            } else {
                break;
            }
        }  until ( r == tokens.C_CR or r == tokens.NOCMD or r == 0)
        if nl == true {
            txt.nl()
        }
        
    }

}