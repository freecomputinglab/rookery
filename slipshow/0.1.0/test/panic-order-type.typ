#import "/src/lib.typ": resolve-slips, slip

#slip("a", title: [A])[Body]

#context resolve-slips(tags: "slip", order: r => r.title)
