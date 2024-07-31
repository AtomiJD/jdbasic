%import syslib
%import textio
%import diskio
%import string
%import graphics
%import sprites
%import psg
%import jdbasic
%import jdapu
%import jderr
%encoding iso

runcx16 {
    sub do_sprinit() {
        ubyte r = 0
        ubyte a = 0 ;nr
        ubyte b = 0 ;bank  
        uword c = 0 ;address
        ubyte d = 0 ;sizex
        ubyte e = 0 ;sizey
        ubyte f = 0 ;color
        ubyte g = 0 ;paloffset
        r = main.next()         ;get next param
        a = apu.expr() as ubyte
        if @(main.pcode) == tokens.C_COMMA {
            r = main.next()         ;skip comma
            b = apu.expr() as ubyte
            r = main.next()         ;get next param            
            c = apu.expr() 
            r = main.next()         ;get next param            
            d = apu.expr() as ubyte
            r = main.next()         ;get next param            
            e = apu.expr() as ubyte
            r = main.next()         ;get next param            
            f = apu.expr() as ubyte
            r = main.next()         ;get next param            
            g = apu.expr() as ubyte
            sprites.init(a,b,c,d,e,f,g)
        } 
        main.pcode--
    }

    sub do_sprpos() {
        ubyte r = 0
        ubyte a = 0 ;nr
        ubyte b = 0 ;x
        ubyte c = 0 ;y

        r = main.next()         ;get next param
        a = apu.expr() as ubyte
        if @(main.pcode) == tokens.C_COMMA {
            r = main.next()         ;skip comma
            b = apu.expr() as ubyte
            r = main.next()         ;get next param            
            c = apu.expr() as ubyte
            sprites.pos(a,b,c)
        } 
        main.pcode--
    }

    sub do_sprflip() {
        ubyte r = 0
        ubyte a = 0 ;nr
        ubyte b = 0 ;x or y
        ubyte c = 0 ;flipped?

        r = main.next()         ;get next param
        a = apu.expr() as ubyte
        if @(main.pcode) == tokens.C_COMMA {
            r = main.next()         ;skip comma
            b = apu.expr() as ubyte
            r = main.next()         ;get next param            
            c = apu.expr() as ubyte
            sprites.pos(a,b,c)
        } 
        main.pcode--
    }
    sub do_sprhide() {
        ubyte r = 0
        ubyte a = 0 ;nr
        ubyte b = 0 ;x or y
        ubyte c = 0 ;flipped?

        r = main.next()         ;get next param
        a = apu.expr() as ubyte
        sprites.hide(a)

        main.pcode--
    }

    sub do_sprdata() {
        ubyte r = 0
        ubyte a = 0 ;nr
        ubyte b = 0 ;bank
        uword c = 0 ;address

        r = main.next()         ;get next param
        a = apu.expr() as ubyte
        if @(main.pcode) == tokens.C_COMMA {
            r = main.next()         ;skip comma
            b = apu.expr() as ubyte
            r = main.next()         ;get next param            
            c = apu.expr()
            sprites.data(a,b,c)
        } 
        main.pcode--
    }

    sub do_psgstart() {
        cx16.enable_irq_handlers(true)
        cx16.set_vsync_irq_handler(&psg.envelopes_irq)        
    }

    sub do_psgvoice() {
        ubyte r = 0
        ubyte a = 0 ;nr         0-15
        ubyte b = 0 ;channel    left=64,right=128,both = 192
        ubyte c = 0 ;volume     0-63
        ubyte d = 0 ;waveform   0=pulse, 64=sawtooth, 128=triangle, 192=noise
        ubyte e = 0 ;pulsewidth pulsewidth = 0-63
        r = main.next()         ;get next param
        a = apu.expr() as ubyte
        if @(main.pcode) == tokens.C_COMMA {
            r = main.next()         ;skip comma
            b = apu.expr() as ubyte
            r = main.next()         ;get next param            
            c = apu.expr() as ubyte
            r = main.next()         ;skip comma
            d = apu.expr() as ubyte
            r = main.next()         ;skip comma
            e = apu.expr() as ubyte
            psg.voice(a, b, c, d, e)
        }
        main.pcode--
    }

    sub do_psgsilent() {
        psg.silent()
    }

    sub do_psgfreq() {
        ubyte r = 0
        ubyte a = 0 ;nr
        uword b = 0 ;freq       ;0-65535 Example: to output a frequency of 440Hz (note A4) the Frequency word should be set to 440 / (48828.125 / (2^17)) = 1181
        r = main.next()         ;get next param
        a = apu.expr() as ubyte
        if @(main.pcode) == tokens.C_COMMA {
            r = main.next()         ;skip comma
            b = apu.expr() 
            psg.freq(a, b)
        }
        main.pcode--
    }

    sub do_psgenv() {
        ubyte r = 0
        ubyte a = 0 ;nr         0-15
        ubyte b = 0 ;max vol    0-63
        ubyte c = 0 ;attack     MAXVOL/15/attack  seconds.    higher value = faster attack.
        ubyte d = 0 ;sustain    sustain/60 seconds    higher sustain value = longer sustain (!).
        ubyte e = 0 ;release    MAXVOL/15/release seconds.   higher vaule = faster release.
        r = main.next()         ;get next param
        a = apu.expr() as ubyte
        if @(main.pcode) == tokens.C_COMMA {
            r = main.next()         ;skip comma
            b = apu.expr() as ubyte
            r = main.next()         ;get next param            
            c = apu.expr() as ubyte
            r = main.next()         ;skip comma
            d = apu.expr() as ubyte
            r = main.next()         ;skip comma
            e = apu.expr() as ubyte
            psg.envelope(a, b, c, d, e)
        }
        main.pcode--
    }

    sub do_psgvol() {
        ubyte r = 0
        ubyte a = 0 ;nr
        ubyte b = 0 ;volume     0-15
        r = main.next()         ;get next param
        a = apu.expr() as ubyte
        if @(main.pcode) == tokens.C_COMMA {
            r = main.next()         ;skip comma
            b = apu.expr() as ubyte
            psg.volume(a,b)
        }
        main.pcode--
    }

    sub do_psgstop() {
        psg.silent()
        cx16.disable_irq_handlers()
    }

}