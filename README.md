# Final Project Report: peglet
Peglet is a Final Project for BaPL2 course

## Language Syntax

This project follows the syntax defined by Roberto during the course. 
To test, Run the command: ``` lua input.lua [bool(0, 1) for parser output] [bool(0, 1) for compilation output]```
Syntax examples:
```lua
#If:
{x=1; if x==1{return x + 2}; x;}
```
```lua
#Boolean:
true && false
```
```lua
#while:
{n=6; while n>0 {if n<5 and n%2==0{print n;return n}; n = n - 1;};}
```
```lua
#Multidimensional arrays:
{n=new[10][5][3]; n[1][1][1]=123;n[10][5][3]=999;n[2][2][3]=n[1][1][1]+1;print n;}
```
```lua
#Recursion:
function xpto (n);

    function xpto (n) {
        print n
        if n > 0 {
            n = n - 1
            return xpto (n)
        }
        return 0
    }

    function main () {
        x = xpto(10)
        return x
    }
```
## New Features/Changes

* Unless
* Booleans
* Abscence of value

## Future

This project is a baseline for further development.
My main development focus will be to implement new runtimes for different platforms, like .Net and Java.
After the baseline implementation, I intend to work in broader integration patterns, including patterns for dependency injection and inversion of control.


## Self assessment

* Language Completeness (2)
* Code Quality & Report (1)
* Originality & Scope (1)


## References

List any references used in the development of your language besides this courses, including any books, papers, or online resources.
