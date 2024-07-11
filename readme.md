# jdBasic - aka NeReLa BASIC

## NeReLa - Neo Retro Lambda

A simple functional BASIC language for the 6502 processor.
Especially for commander x16

You need:

cx16 emulation and Prog8 installed

Prog8 must be a subfolder of cx16 emulation.

The repository must be a subfolder of prog8 to work.

open a command shell and goto subfolder "jdbasic" an start with "code ."

compile with Shift-Control-B

run with Shift-Control-R and "Prog8 run"

## DOS commands:
```
dir
edit
load
list
run
```

## BASIC 
### function Definition and call of functions
```
func lall(a,b)
    return a*b
endfunc

print "func call:"
b=lall(5,3)
print b
```

### Using higher order functions
```
func inc(ab)
    return ab+1
endfunc
func dec(cd)
    return cd-1
endfunc

func apply(fa(),cc)
    return fa(cc)
endfunc
print apply(inc@,10)
print apply(dec@,12) 
```
### Simple  recursion
```
func factorial(a)
    if a > 1 then
        return factorial(a-1)*a
    else
        return a
    endif
endfunc

lall =  factorial(5)
print "erg: ", lall
```

### Recursions
```
func printnumbers(n)
    if n > 0 then
        print n
	r=printnumbers(n - 1)
    endif
endfunc

r=printnumbers(5)  ; returns 5, 4, 3, 2, 1 
```

### Lists and map-like functions
```
numbers[]=[1,2,3,4,5]
result[]=[0,0,0,0,0]

func printresult() 
   for i = 0 to len(result[])
       print result[i], " ";
   next i
endfunc

func inc(a)
    return a+1
endfunc

func dec(a)
    return a-1
endfunc

func map(fu(),in[],out[])
    for i = 0 to 4
        n = in[i]
        out[i]=fu(n)
    next i
endfunc

map(inc@,numbers[],result[])

print "Result inc: "
printresult()

print
print "Result dec: "

map(dec@,numbers[],result[])

printresult()

print 
```

### Filter functions for lists
```
numbers[]=[1,2,3,4,5]
result[]=[0,0,0,0,0]

func printresult() 
   for i = 0 to len(result[])
       if result[i]>0 then
           print result[i], " ";
       endif
   next i
endfunc

func iseven(a)
   if a mod 2 = 0 then
      r=1
   else
      r=0
   endif
   return r
endfunc

func filter(fu(),in[],out[])
   j=0
   for i = 0 to 4
      m=fu(in[i])
      if m = 1 then
         out[j]=in[i]
         j=j+1
      endif
   next i
endfunc

filter(iseven@,numbers[],result[])

print "Result filter: "
printresult()

print
```
