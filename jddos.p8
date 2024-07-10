%import syslib
%import textio
%import diskio
%import string
%import jdbasic
%import jdapu
%import jderr
%encoding iso

rundos {

    sub do_load() -> ubyte{
        ubyte r = 0
        ubyte fname_len = 0
        ubyte end_bank = 0
        uword end_address = 0
        ubyte sbank = 0
        bool flag
        r = main.next()
        if r == tokens.STRING {
            main.get_string(main.filename)
        }
        fname_len = string.length (main.filename)
        if (fname_len>0) {
            cbm.SETLFS(1, 8, 2)
            cbm.SETNAM(fname_len, main.filename)
            sbank = cx16.getrambank()
            cx16.rambank(2)
            flag, end_bank, end_address = cbm.LOAD(0,$A000)
            if flag {
                error.set(3)
            } else {
                @(end_address) = tokens.NOCMD
                @(end_address+1) = 0
                txt.print("loaded to: ")
                txt.print_uwhex(end_address, true)
                txt.print(" bank ")
                txt.print_ub(end_bank+cx16.getrambank())
                txt.nl()
            }
            cx16.rambank(sbank)
            return 0
        } else {
            return 1
        }
   }

    sub do_list() -> ubyte {
        ubyte sbank = 0
        bool lende = false
        sbank = cx16.getrambank()
        cx16.rambank(2)        
        uword lptr = $A000
        do {
            if (@(lptr)==$0A) { txt.nl() } else { txt.chrout(@(lptr)) }
            lptr++
            if @(lptr) == tokens.NOCMD and @(lptr+1) == 0 lende = true

        } until lende == true
        cx16.rambank(sbank)
        txt.nl()
        return 0
    }


    sub do_dir() -> bool {
        ubyte num_files = 0
        ubyte r = 0
        r = main.next()
        if r == tokens.STRING {
            main.get_string(main.buffer)
        } else {
            main.buffer = "*"
        }
        if diskio.lf_start_list(main.buffer) {
            txt.print(" Blocks  Filename\r")
            while diskio.lf_next_entry() {
                num_files++
                txt.spc()
                txt.spc()
                if diskio.list_filetype == petscii:"dir"
                    txt.print("[dir]")
                else
                    txt.print_uw(diskio.list_blocks)
                txt.column(9)
                txt.print(diskio.list_filename)
                txt.nl()
                void cbm.STOP()
                if_z {
                    txt.print("Break\r")
                    break
                }
            }
            diskio.lf_end_list()
            if num_files == 0 {
                txt.print("No files\r")
            }
            return true
        }
        return false
    }

    sub do_edit() -> ubyte {
        ubyte r = 0
        ubyte fname_len = 0        
        r = main.next()
        if r == tokens.STRING {
            main.get_string(main.filename)
            fname_len = string.length (main.filename)  
        } else {
            fname_len = string.length (main.filename)
        }
        ; activate rom based x16edit, see https://github.com/stefan-b-jakobsson/x16-edit/tree/master/docs
        ubyte x16edit_bank = cx16.search_x16edit()
        if x16edit_bank<255 {
            ubyte sbank = cx16.getrombank()
            cx16.rombank(x16edit_bank)
            cx16.x16edit_loadfile(2, $FE, main.filename, fname_len)
            cx16.rombank(sbank)
            ;main.init_screen()
            return true
        } else {
            txt.print("No x16edit found.")
            return false
        }
    }

}