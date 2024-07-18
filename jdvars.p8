; vars and label hash tables
%import syslib

jdstr {
    uword start = $A000
    uword r = 0
    const ubyte vbank  = $60
    ubyte sbank  = 0
    uword lini = 0

    sub add(str name) -> uword {
        sbank = cx16.getrambank()
        cx16.rambank(vbank)
        lini = string.length(name) + 1 ;we need \0
        if lini > 17 lini = 17        
        r = start
        sys.memcopy(name,r,lini)
        start = start + lini
        cx16.rambank(sbank)
        return r
    }

    sub get(uword prt, uword buf) {
        uword lp = 0
        sbank = cx16.getrambank()
        cx16.rambank(vbank)
        if prt == 0 {
            @(buf) = 0
        } else {
            lp=buf
            do {
                @(lp) = @(prt)
                lp++
                prt++
            } until (@(prt)==0)
            @(lp) = 0    
        }
        cx16.rambank(sbank)
    }
}

jdheap {
    uword start = (main.mend-$FF)
    uword r = 0
    uword ml = 0
    uword ll = 0
    ubyte lini = 0

    sub init_list(ubyte nr)  -> uword {
        ll=0
        r = start - 3
        @(r) = nr
        r++
        ml=r            ;remember length address
        @(r) = 0        ;two bytes for length
        r++        
        @(r) = 0
        start = start - 4
        return start
    }

    sub add_list(uword value) {
        ll++
        r = start - 2
        r++
        @(r) = lsb(value)
        r++
        @(r) = msb(value)
        start = start - 2
    }

    sub close_list() {
        @(ml) = lsb(ll)
        @(ml+1) = msb(ll)
    }

    sub add_str(ubyte nr, str value) -> uword {
        lini = string.length(value) + 1 ;we need terminating \0
        r = start - (lini+2)
        ml = r
        @(r) = nr
        r++
        @(r) = lini
        r++
        sys.memcopy(value, r, lini)
        start = start - (lini+2)            ;we got from heap max mem down
        return ml
    }

    sub get_str(uword prt, uword buf) {
        uword lp = 0
        if prt == 0 {
            @(buf) = 0
        } else {
            lp=buf
            do {
                @(lp) = @(prt)
                lp++
                prt++
            } until (@(prt)==0)
            @(lp) = 0    
        }
    }
}

jdvars {
    ubyte[128] numvars_next
    uword[128] numvars_name     ;jdtodo this is only used by pre-compiler, so can be in banked monory!
    uword[128] numvars_value
    str buffer = "\x00" * 17
    uword r = 0
    ubyte cn = 0

    sub insert(str name, uword value) -> ubyte{
        ubyte index = string.hash(name) / 2 ; for 128 vars
        if index == 0 index = 1
        if numvars_name[index] == 0 {
            r = jdstr.add(name)
            numvars_name[index] = r
            numvars_value[index] = value
            numvars_next[index] = 0
            return index
        } else {
            ubyte current = index
            while (numvars_next[current]!=0) {
                jdstr.get(numvars_name[current],buffer)
                if string.compare(name,buffer) == 0 {
                    numvars_value[current] = value
                    return current
                }
                current = numvars_next[current]
            }
            jdstr.get(numvars_name[current],buffer)
            if string.compare(name,buffer) == 0 {
                numvars_value[current] = value
                return current
            }
            r = jdstr.add(name)
            do {
                cn++
            } until numvars_name[cn] == 0 
            numvars_name[cn] = r
            numvars_value[cn] = value
            numvars_next[cn] = 0
            numvars_next[current] = cn
        }
        return cn
    }

    sub get_name(str name) -> uword {
        ubyte index = string.hash(name) / 2 ; for 128 vars
        if index == 0 index = 1
        ubyte current = numvars_next[index]
        if (current == 0) {
            return numvars_value[current]
        } else {
            while numvars_next[index] != 0 {
                jdstr.get(numvars_name[current],buffer)
                if name == buffer {
                    return numvars_value[current]
                }
                current =  numvars_next[current]
            }
        }
    }

    sub get_value(ubyte index) -> uword {
        return numvars_value[index]
    }

    sub set_value(ubyte index, uword value) {
        numvars_value[index] = value
    }
}

jdstrvars {
    ubyte[64] strvars_next
    uword[64] strvars_name     ;jdtodo this is only used by pre-compiler, so can be in banked monory!
    uword[64] strvars_addr
    str buffer = "\x00" * 17
    uword r = 0
    ubyte cn = 0

    sub insert(str name, str value) -> ubyte{
        ubyte index = string.hash(name) / 4 ;64 string vars
        if index == 0 index = 1
        if strvars_name[index] == 0 {        
            r = jdstr.add(name)
            strvars_name[index] = r
            strvars_addr[index] = index
            strvars_next[index] = 0
            return index
        } else {
            ubyte current = index
            while (strvars_next[current] !=0 ) {
                jdstr.get(strvars_name[current], buffer)
                if string.compare(name, buffer) == 0 {
                    strvars_addr[current] = current
                    return current
                }
                current = strvars_next[current]
            }
            jdstr.get(strvars_name[current],buffer)
            if string.compare(name,buffer) == 0 {
                strvars_addr[current] = current
                return current
            }
            r = jdstr.add(name)
            cn = current
            do {
                cn++
            } until strvars_name[cn] == 0 
            strvars_name[cn] = r
            strvars_addr[cn] = cn
            strvars_next[cn] = 0
            strvars_next[current] = cn
        }
        return cn
    }

    sub get_name(str name) -> uword {
        ubyte index = string.hash(name) / 4 ;64 string vars
        if index == 0 index = 1
        ubyte current = strvars_next[index]
        if (current == 0) {
            return strvars_addr[current]
        } else {
            while strvars_next[index] != 0 {
                jdstr.get(strvars_name[current],buffer)
                if name == buffer {
                    return strvars_addr[current]
                }
                current =  strvars_next[current]
            }
        }
    }

    sub get_value(ubyte index) -> uword {
        return strvars_addr[index]
    }

    sub set_value(ubyte index, uword value) {
        uword taddr = 0
        taddr = jdheap.add_str(index, value)
        strvars_addr[index] = taddr
    }
}

jdarrvars {
    ubyte[64] arrvars_next
    uword[64] arrvars_name     ;jdtodo this is only used by pre-compiler, so can be in banked monory!
    uword[64] arrvars_addr
    str buffer = "\x00" * 17
    uword r = 0
    ubyte cn = 0

    sub insert(str name, str value) -> ubyte{
        ubyte index = string.hash(name) / 4 ; for 64 array vars
        if index == 0 index = 1
        if arrvars_name[index] == 0 {
            r = jdstr.add(name)
            arrvars_name[index] = r
            arrvars_addr[index] = index
            arrvars_next[index] = 0
            return index
        } else {
            ubyte current = index
            while (arrvars_next[current] !=0 ) {
                jdstr.get(arrvars_name[current], buffer)
                if string.compare(name, buffer) == 0 {
                    arrvars_addr[current] = current
                    return current
                }
                current = arrvars_next[current]
            }
            jdstr.get(arrvars_name[current],buffer)
            if string.compare(name,buffer) == 0 {
                arrvars_addr[current] = current
                return current
            }
            r = jdstr.add(name)
            cn = current
            do {
                cn++
            } until arrvars_name[cn] == 0 
            arrvars_name[cn] = r
            arrvars_addr[cn] = cn
            arrvars_next[cn] = 0
            arrvars_next[current] = cn
        }
        return cn
    }

    sub get_value(ubyte nr, uword index) -> uword {
        uword taddr = 0
        uword tind = 0
        uword value = 0
        ubyte l,m
        taddr = arrvars_addr[nr]
        taddr++
        taddr++
        l = @(taddr)
        taddr++
        m = @(taddr)
        tind = mkword(m,l)
        taddr--
        taddr--
        if index < tind {
            index++
            taddr-= index*2
            l = @(taddr)
            taddr++
            m = @(taddr)
            value = mkword(m,l)
        }
        return value
    }

    sub get_len(ubyte nr) -> uword {
        uword taddr = 0
        uword tind = 0
        ubyte l,m
        taddr = arrvars_addr[nr]
        taddr++
        taddr++
        l = @(taddr)
        taddr++
        m = @(taddr)
        tind = mkword(m,l)
        tind--
        return tind
    }

    sub set_value(ubyte nr, uword index, uword value) {
        uword taddr = 0
        uword tind = 0
        ubyte l,m
        taddr = arrvars_addr[nr]
        taddr++
        taddr++
        l = @(taddr)
        taddr++
        m = @(taddr)
        tind = mkword(m,l)
        taddr--
        taddr--
        if index < tind {
            index++
            taddr-= index*2
            @(taddr) = lsb(value)
            taddr++
            @(taddr) = msb(value)
        }
    }
}

jdlocal {
    ubyte[128] localvars_next
    uword[128] localvars_name     
    uword[128] localvars_value
    str buffer = "\x00" * 17
    uword r = 0
    ubyte cn = 0

    sub prnhex(str name) {
        ubyte c = 0
        ubyte i
        uword addr
        addr = name
        for i in 0 to string.length(name) {
            txt.print_ubhex(@(addr), true)
            txt.print(" ")
            addr++
        }
    }

    sub insert(str name, uword value) -> ubyte {
        ubyte index = string.hash(name) / 2 ; for 128 vars
        ; txt.nl()
        ; prnhex(name)
        ; txt.print("index: ")
        ; txt.print_ubhex(index,true)
        ; txt.nl()
        if index == 0 index = 1
        if localvars_name[index] == 0 {
            r = jdstr.add(name)
            localvars_name[index] = r
            localvars_value[index] = value
            localvars_next[index] = 0
            return index
        } else {
            ubyte current = index
            while (localvars_next[current]!=0) {
                jdstr.get(localvars_name[current],buffer)
                if string.compare(name,buffer) == 0 {
                    localvars_value[current] = value
                    return current
                }
                current = localvars_next[current]
            }
            jdstr.get(localvars_name[current], &buffer)
            if string.compare(name,buffer) == 0 {
                localvars_value[current] = value
                return current
            }
            r = jdstr.add(name)
            do {
                cn++
            } until localvars_name[cn] == 0             
            localvars_name[cn] = r
            localvars_value[cn] = value
            localvars_next[cn] = 0
            localvars_next[current] = cn
        }
        return cn
    }

    sub get_name(str name) -> uword {
        ubyte index = string.hash(name) / 2 ; for 128 vars
        if index == 0 index = 1
        if localvars_name[index] == 0 {
            return 0 
        }
        jdstr.get(localvars_name[index], &buffer)   
        ubyte current = localvars_next[index]     
        if (string.compare(name,buffer) == 0) {
            return localvars_value[index]
        } else {
            while localvars_next[current] != 0 {
                jdstr.get(localvars_name[current],buffer)
                if string.compare(name,buffer) == 0 {
                    return localvars_value[current]
                }
                current =  localvars_next[current]
            }
            jdstr.get(localvars_name[current],buffer)
            if string.compare(name,buffer) == 0 {
                return localvars_value[current]
            }
        }
        return 0
    }

    sub get_indexbyname(str name) -> ubyte {
        ubyte index = string.hash(name) / 2 ; for 128 vars
        if index == 0 index = 1
        if localvars_name[index] == 0 {
            return 0 
        }        
        jdstr.get(localvars_name[index], &buffer)           
        ubyte current = localvars_next[index]
        if (string.compare(name,buffer) == 0) {
            return index
        } else {
            while localvars_next[current] != 0 {
                jdstr.get(localvars_name[current],buffer)
                if string.compare(name,buffer) == 0 {
                    return current
                }
                current =  localvars_next[current]
            }
            jdstr.get(localvars_name[current],buffer)
            if string.compare(name,buffer) == 0 {
                return current
            }            
        }
        return 0
    }


    sub get_value(ubyte index) -> uword {
        return localvars_value[index]
    }

    sub set_value(ubyte index, uword value) {
        localvars_value[index] = value
    }
}

labels {
    ubyte[64] label_next
    str[64] label_name          ;jdtodo this is only used by pre-compiler, so can be in banked monory!
    uword[64] label_value
    str buffer = "\x00" * 17
    uword r = 0
    ubyte cn = 0

    sub insert(str name, uword value) -> ubyte{
        ubyte index = string.hash(name) / 4 ; for 64 vars
        if index == 0 index = 1

        if label_name[index] == 0 {
            r = jdstr.add(name)
            label_name[index] = r
            label_value[index] = value
            label_next[index] = 0
            return index
        } else {
            ubyte current = index
            while (label_next[current]!=0) {
                jdstr.get(label_name[current],buffer)
                if string.compare(name,buffer) == 0 {
                    label_value[current] = value
                    return current
                }
                current = label_next[current]
            }
            jdstr.get(label_name[current],buffer)
            if string.compare(name,buffer) == 0 {
                label_value[current] = value
                return current
            }
            r = jdstr.add(name)
            do {
                cn++
            } until label_name[cn] == 0             
            label_name[cn] = r
            label_value[cn] = value
            label_next[cn] = 0
            label_next[current] = cn
        }
        return cn
    }

    sub get_jmpaddress(str name) -> uword {
        ubyte index = string.hash(name) / 4 ; for 64 vars
        if index == 0 index = 1
        ubyte current = label_next[index]
        if (current == 0) {
            return label_value[index]
        } else {
            while label_next[current] != 0 {
                jdstr.get(label_name[current],buffer)
                if string.compare(name,buffer) == 0 {
                    return label_value[current]
                }
                current =  label_next[current]
            }
            jdstr.get(label_name[current],buffer)
            if string.compare(name,buffer) == 0 {
                return label_value[current]
            }            
        }
    }

    sub get_value(ubyte index) -> uword {
        return label_value[index]
    }

    sub set_value(ubyte index, uword value) {
        label_value[index] = value
    }
}

jdfunc {
    ubyte[64] func_next
    uword[64] func_name     ;jdtodo this is only used by pre-compiler, so can be in banked monory!
    uword[64] func_value
    str buffer = "\x00" * 17
    uword r = 0
    ubyte cn = 0

    sub insert(str name, uword value) -> ubyte{
        ubyte index = string.hash(name) / 4 ; for 64 funcs
        if index == 0 index = 1

        if func_name[index] == 0 {
            r = jdstr.add(name)
            func_name[index] = r
            func_value[index] = value
            func_next[index] = 0
            return index
        } else {
            ubyte current = index
            while (func_next[current]!=0) {
                jdstr.get(func_name[current],buffer)
                if string.compare(name,buffer) == 0 {
                    func_value[current] = value
                    return current
                }
                current = func_next[current]
            }
            jdstr.get(func_name[current],buffer)
            if string.compare(name,buffer) == 0 {
                func_value[current] = value
                return current
            }
            r = jdstr.add(name)
            do {
                cn++
            } until func_name[cn] == 0             
            func_name[cn] = r
            func_value[cn] = value
            func_next[cn] = 0
            func_next[current] = cn
        }
        return cn
    }

    sub get_valueByName(str name) -> uword {
        ubyte index = string.hash(name) / 4 ; for 64 funcs
        if index == 0 index = 1
        ubyte current = func_next[index]
        if (current == 0) {
            return func_value[current]
        } else {
            while func_next[current] != 0 {
                jdstr.get(func_name[current],buffer)
                if name == buffer {
                    return func_value[current]
                }
                current =  func_next[current]
            }
        }
    }

    sub get_FuncNoByName(str name) -> ubyte {
        ubyte index = string.hash(name) / 4 ; for 64 funcs
        if index == 0 index = 1
        if (index == 0 and func_name[index]>0) {
            return index
        } else {
            ubyte current = index
            while func_next[current] != 0 {
                jdstr.get(func_name[current],buffer)
                if string.compare(name,buffer) == 0 {
                    return current
                }
                current =  func_next[current]
            }
            jdstr.get(func_name[current],buffer)
            if string.compare(name,buffer) == 0 {
                return current
            }            
        }
        return 0
    }

    sub get_value(ubyte index) -> uword {
        return func_value[index]
    }

    sub set_value(ubyte index, uword value) {
        func_value[index] = value
    }

}