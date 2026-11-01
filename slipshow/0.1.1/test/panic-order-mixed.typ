#import "/src/lib.typ": resolve-slips, slip

#slip("a")[Body]
#slip("b")[Body]

#context resolve-slips(tags: "slip", order: r => if r.name == "a" { 1 } else { "x" })
