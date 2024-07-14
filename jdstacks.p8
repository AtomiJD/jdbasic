; all my stacks

ifstack {
    uword[16] elseadd
    uword[16] thenadd
    uword[16] eifeadd
    uword val = 0
    ubyte isc = $FF

    sub clear() {
        isc = $FF
    }

    sub push(uword elseaddress, uword thenaddress, uword endifaddress) {
        isc++
        elseadd[isc] = elseaddress
        thenadd[isc] = thenaddress
        eifeadd[isc] = endifaddress
    }

    sub pops() -> uword {
        val = elseadd[isc]
        return val
    }

    sub popm() -> uword {
        val = thenadd[isc]
        return val
    }

    sub pope() -> uword {
        val = eifeadd[isc]
        isc--
        return val
    }
}

funcstack {
    uword[32] retaddr
    uword val = 0
    ubyte fsc = $FF

    sub clear() {
        fsc = $FF
    }

    sub push(uword retaddr1) {
        fsc++
        retaddr[fsc] = retaddr1
    }

    sub pop() -> uword {
        val = retaddr[fsc]
        fsc--
        return val
    }
}

forstack {
    uword[16] start_address_code
    ubyte[16] for_var_type
    ubyte[16] for_var_num
    uword[16] for_from
    uword[16] for_to
    uword[16] for_step

    uword val = 0
    ubyte valb = 0
    ubyte osc = $FF

    sub clear() {
        osc = $FF
    }

    sub push(uword start_address_code1, ubyte var_type, ubyte var_num, uword for_from_val, uword for_to_val, uword for_step_val) {
        osc++
        start_address_code[osc] = start_address_code1
        for_var_type[osc] = var_type
        for_var_num[osc] = var_num
        for_from[osc] = for_from_val
        for_to[osc] = for_to_val
        for_step[osc] = for_step_val
    }

    sub pop1() -> uword {
        val = start_address_code[osc]
        return val
    }

    sub pop2() -> ubyte {
        valb = for_var_type[osc]
        return valb
    }
    
    sub pop3() -> ubyte {
        valb = for_var_num[osc]
        return valb
    }

    sub pop4() -> uword {
        val = for_from[osc]
        return val
    }

    sub pop5() -> uword {
        val = for_to[osc]
        return val
    }

    sub pop6() -> uword {
        val = for_step[osc]
        return val
    }

    sub pope() -> uword {
        osc--
        return 0
    }
}



;my vars saved by recursive expr/term calls
varstack {
    uword[32] svar
    uword val = 0
    ubyte vsc = $FF

    sub clear() {
        vsc = $FF
    }

    sub push(uword svar1) {
        vsc++
        svar[vsc] = svar1
    }

    sub pop() -> uword {
        val = svar[vsc]
        vsc--
        return val
    }
}

;my vars saved by recursive expr/term calls
callstack_b {
    ubyte cbsc = 0
    ubyte[32] cbvar
    ubyte val = $FF

    sub clear() {
        cbsc = $FF
    }

    sub push(ubyte cbvar1) {
        cbsc++
        cbvar[cbsc] = cbvar1
    }

    sub pop() -> ubyte {
        val = cbvar[cbsc]
        cbsc--
        return val
    }
}

callstack_f {
    ubyte[32] cfvar
    ubyte val = 0
    ubyte cfsc = $FF

    sub clear() {
        cfsc = $FF
    }

    sub push(ubyte cfvar1) {
        cfsc++
        cfvar[cfsc] = cfvar1
    }

    sub pop() -> ubyte {
        val = cfvar[cfsc]
        cfsc--
        return val
    }
}

callstack_w {
    uword[32] cwvar
    uword val = 0
    ubyte cwsc = $FF

    sub clear() {
        cwsc = $FF
    }

    sub push(uword cwvar1) {
        cwsc++
        cwvar[cwsc] = cwvar1
    }

    sub pop() -> uword {
        val = cwvar[cwsc]
        cwsc--
        return val
    }
}
