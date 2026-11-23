// Every element whose constructor takes a positional argument, inside an
// `#idea` body: each must survive `_strip-labelled` untouched.
#import "/src/lib.typ": *
#show: rookery

#idea("al")[#align(right)[a]]
#idea("pl")[#place(top)[a]]
#idea("ro")[#rotate(5deg)[a]]
#idea("co")[#columns(2)[a]]
#idea("ub")[$underbrace(x, "n")$]
#idea("ob")[$overbrace(x, "n")$]
#idea("ubk")[$underbracket(x, "n")$]
#idea("obk")[$overbracket(x, "n")$]
#idea("up")[$underparen(x, "n")$]
#idea("op")[$overparen(x, "n")$]
#idea("us")[$undershell(x, "n")$]
#idea("os")[$overshell(x, "n")$]
