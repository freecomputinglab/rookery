#import "/src/lib.typ": *
#show: rookery.with(
  citations: "notes",
  bibliography: arguments(
    bytes("@book{k, title={T}, author={A}, year={2020}}"),
    style: "chicago-notes",
  ),
)

#idea("cites")[
  A #cite(<k>, supplement: [ch. 2]) b. #rotate(5deg)[a]

  #figure([i], caption: [cap @k])

  #quote(block: true, attribution: [Who @k])[q]

  / Term: desc @k
]

#bibliography(bytes("@book{k, title={T}, author={A}, year={2020}}"), style: "chicago-notes")
