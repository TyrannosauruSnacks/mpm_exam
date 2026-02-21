// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text( size: 0.92em )
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subrefnumbering: "1a",
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => numbering(subrefnumbering, n-super, quartosubfloatcounter.get().first() + 1))
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => {
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          }

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let old_title = old_title_block.body.body.children.at(2)

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block, 
    block_with_new_content(
      old_title_block.body, 
      old_title_block.body.body.children.at(0) +
      old_title_block.body.body.children.at(1) +
      new_title))

  block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color, 
        width: 100%, 
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}



#let article(
  title: none,
  subtitle: none,
  authors: none,
  date: none,
  abstract: none,
  abstract-title: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: "libertinus serif",
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: "libertinus serif",
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  sectionnumbering: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  set par(justify: true)
  set text(lang: lang,
           region: region,
           font: font,
           size: fontsize)
  set heading(numbering: sectionnumbering)
  if title != none {
    align(center)[#block(inset: 2em)[
      #set par(leading: heading-line-height)
      #if (heading-family != none or heading-weight != "bold" or heading-style != "normal"
           or heading-color != black) {
        set text(font: heading-family, weight: heading-weight, style: heading-style, fill: heading-color)
        text(size: title-size)[#title]
        if subtitle != none {
          parbreak()
          text(size: subtitle-size)[#subtitle]
        }
      } else {
        text(weight: "bold", size: title-size)[#title]
        if subtitle != none {
          parbreak()
          text(weight: "bold", size: subtitle-size)[#subtitle]
        }
      }
    ]]
  }

  if authors != none {
    let count = authors.len()
    let ncols = calc.min(count, 3)
    grid(
      columns: (1fr,) * ncols,
      row-gutter: 1.5em,
      ..authors.map(author =>
          align(center)[
            #author.name \
            #author.affiliation \
            #author.email
          ]
      )
    )
  }

  if date != none {
    align(center)[#block(inset: 1em)[
      #date
    ]]
  }

  if abstract != none {
    block(inset: 2em)[
    #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
    ]
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  if cols == 1 {
    doc
  } else {
    columns(cols, doc)
  }
}

#set table(
  inset: 6pt,
  stroke: none
)

#set page(
  paper: "a4",
  margin: (bottom: 2cm,x: 2.5cm,),
  numbering: "1",
)

#show: doc => article(
  title: [Methods of Process Modelling],
  authors: (
    ( name: [Max Arthur Hachemeister],
      affiliation: [],
      email: [] ),
    ),
  date: [2026-02-22],
  font: ("DejaVu Sans",),
  fontsize: 12pt,
  sectionnumbering: "1.1.1",
  toc_title: [Table of contents],
  toc_depth: 3,
  cols: 1,
  doc,
)

= Introduction
<introduction>
Statistical models are invaluable tools for deriving and predicting variables relevant to applied and scientific forest ecology alike. These models not only help scale the time and space dimensions of forest ecosystem to scopes comprehensible by humans, and allow therefore to virtually test and evaluate forest management approaches, and also anticipate relevant developments like climate change, so to effectively inform land managers in a timely manner @pretzsch2009[ch.~1 11].

However, diligence is due when models are to be selected and applied to a given question or an actual tree stand, as there are many models for a wide range of applications, with varying quality, to choose from. It takes both statistical understanding and domain knowledge to find and apply models appropriately.

In the following, the procedure of model selection, fitting, and interpretation is elaborated for a exemplary tree data. The data and model selection are described, and afterwards the fit of the selected models is presented, discussed, and concluded upon.

= Material and Methods
<material-and-methods>
== Initial Data
<initial-data>
The initial data set consisted of 68 total observations, from 6 individual #emph[Picea abies] (Norway Spruce) trees, and for 2 different locations, with the given variables:

- Diameter at breast height (DBH) \[cm\]
- Tree height \[m\]
- Volume \[m³\]
- Age \[years\]
- Location

Volume was not observed but calculated, while for the locations, climate and elevation above sea level were described in the meta data, see #ref(<sec-allometric-models>, supplement: [Section]).

== Software
<software>
The data was processed with the programming language R @rcoreteam2022, RStudio @positteam2025, and the #emph[tidyverse] meta package @wickham2019, while the grwoth models were selected from and fit with the #emph[growthrates] package @petzoldt2025, see also #strong[?\@sec-appendix]

== Tree Volume Calculation
<tree-volume-calculation>
As the tree volume was calculated but no equation given, and the values seeming unlikely high for the unit of cubic meters, the volume was calculated again with the #emph[DENZIN] equation for volume of a tree @kramer2008@rast2026, given as:

$ upright("V") = 2 (d^2 \/ 1000) dot.op (h - N H) dot.op upright("Formfactor") $

where:

- $V = upright("Merchantable wood volume, i.e. stem wood and branches <= 7cm")$
- $N H = upright("\"Normal height\"") = upright("Expected average tree height")$
- $d = upright("DBH [cm], rounded down")$
- $h = upright("Tree height [m]")$

and specifically for #emph[Picea abies:]

- $upright("Formfactor") = 0.04$
- $N H = 19 + 2 (upright("DBH") \/ 10)$

== Relevant Strata
<sec-location>
After initial data exploration, major differences in overall productivity of trees for each location became apparent (#ref(<fig-locations>, supplement: [Figure])).

For further verification, a linear regression model with #emph[volume] as outcome, and #emph[location] as well as #emph[tree] as predictor variables was fit to the data.

#figure([
#box(image("report_files/figure-typst/fig-locations-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Observed Growth Curves and Fitted Linear Regressions of Structural Tree Variables
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-locations>


#ref(<tbl-location-siginifcance>, supplement: [Table]) shows the estimated regression coefficients of the predictor variables with their respective p-values; where lower values represent a higher significance of a variable for the model's estimation. Location 2 and 7 both having the most effective estimates as well as being the most significant predictors; meaning, #emph[location] explains most of the differences in the trees' volumes.

Therefore, all subsequent models were fit and evaluated individually for each location.

#figure([
#table(
  columns: 3,
  align: (left,right,right,),
  table.header([Term], [Estimate], [P Value],),
  table.hline(),
  [location2], [1.445], [0.000],
  [location7], [-1.127], [0.000],
  [tree2], [-0.036], [0.881],
  [tree11], [-0.214], [0.494],
  [tree13], [-0.145], [0.600],
  [tree14], [-0.108], [0.694],
)
], caption: figure.caption(
position: top, 
[
Regression Coefficients and P-Values of a Linear Regression Model for Tree Volume
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-location-siginifcance>


== Growth Models
<sec-growth-models>
Generally in nature, growth follows a sigmoid, also saturation, curve; that is, the curve begins with a flat incline which gradually increases to the steepest point, after which the curve's incline decreases asymptotically towards the maximum.

These curves are expressed with mathematical functions, like #emph[Logistic Regression];, #emph[Gompertz];, or #emph[Richards];. The process of #emph[fitting] functions to data means: to find those function parameters with which the resulting curve estimates the observed data most accurately; where this process is generally executed by computers.

To guide the model fitting computations, so called #emph[measures];, or #emph[criterions];, are calculated and utilized. Two common of these measures are; the #emph[Coefficient of Determination] ($R^2$), which expresses how strong the values estimated by the model correlate with those observed; and the #emph[Residual Sum of Squares] ($R S S$), expressing how much the estimated values deviate from the observed ones overall.

Furthermore, these measures can be used to compare different models, so as to select the most applicable among them. Accordingly, #ref(<fig-growth-curves>, supplement: [Figure]) shows the curves for tree height of three different logistic regression models fitted to this project's data; the respective coefficients being be discussed further in #ref(<sec-results-growth>, supplement: [Section]).

#figure([
#box(image("report_files/figure-typst/fig-growth-curves-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Comparison of Estimated Tree Height from Different Models and Observed Datapoints
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-growth-curves>


== Allometric Models
<sec-allometric-models>
Allometric models are used to derive the values of variables that are impractical to measure, from their relationship with those variables whose mensuration is more easy. For example, to measure the total above ground biomass (AB) of a tree, the tree is usually cut down and separated into compartments for convenient measurement on the ground. If however, one were to study the total AB of a whole tree stand, even a reasonably sized sample of trees would in many cases be unfeasible; economically for the forest owner, and effort-wise for the scientist. It is possible, though, to derive a tree's AB from variables like standing height and DBH with acceptable accuracy, which can both be measured from ground level with the tree being left intact.

Yet the parameters of those models still need to be estimated from representative empirical samples, which remain cost- and labor-intense studies at any rate. For this reason many models have been derived that only areapplicable to certain geographic areas or ranges of input variables, and might also have a small overall sample -- an extensive overview of such models was compiled and published by #cite(<zianis2005>, form: "prose");. It is therefore crucial to diligently select an allometric model so that it is applicable to the conditions of the sample to be estimated. In that regard, #ref(<tbl-sample-ranges>, supplement: [Table]) gives the values ranges for this project's data.

#figure([
#table(
  columns: 5,
  align: (left,right,right,right,right,),
  table.header([Location], [DBH Min], [DBH Max], [Height Min], [Height Max],),
  table.hline(),
  [2], [5.3], [46.3], [4.0], [38.1],
  [7], [2.1], [32.8], [2.5], [21.6],
)
], caption: figure.caption(
position: top, 
[
Value Ranges of the Sample's Variables
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-sample-ranges>


The models to be applied were accordingly selected by region, range, sample size, and $R^2$; in ascending order of relevance. This order came to be because; firstly, #ref(<sec-location>, supplement: [Section]) has shown the location to be most predictive for the structural tree variables; secondly, while a substantial sample size might hint towards a reliable model, if the trees sampled were within a small band of value ranges, such a model will probably be even more unreliable beyond these ranges than another model in the range of interest but with a smaller sample size would be; and lastly, the model choice in the given case, and after regarding all previous points, was so reduced that $R^2$ frankly wasn't a choice anymore.

In conclusion, the following models for AB were selected from those given in the aforementioned publication:

- Location 2
  - Model 141: $A B = 0.57669 dot.op upright("DBH")^1.964$
  - Model 142: $A B = 0.11975 dot.op (upright("DBH")^2 dot.op upright("Height"))^0.81336$
- Location 7
  - Model 147: $A B = - 43.13 + 2.25 dot.op upright("DBH") + 0.452 dot.op upright("DBH")^2$

As location 2 was described to have a #emph[cold temperate] climate and an elevation of 1000 meters above sea level; Norway, Austria, and the Czech Republic were of interest according to geographical data @wikipedia2025@wikipedia2026. However, no AB models existed for Austria, and -- even though having an average of 1000 meters above sea level -- most parts of Norway have higher elevations and colder climate; so the two models from the Czech Republic with the appropriate ranges of values were selected.

Conversely, location 7 was described to be in Central Germany; in which case selecting for the most applicable range of values coincidentally resulted in that German model with also the largest sample size and the only $R^2$ given.

= Results
<results>
== Model Fit
<sec-results-growth>
#ref(<tbl-rsquares>, supplement: [Table]) shows the logistic regression models mentioned in #ref(<sec-growth-models>, supplement: [Section]) ranked according to the aforementioned measures of fitness.

It should be noted, that values up to 1, for $R^2$; and lower values generally, for $upright("RSS")$, express a better model fit respectively. Therefore the #emph[Richards] function shows the best fit of the three models, while the #emph[Gompertz] function could not be sensibly fit for location 7, but scores low overall regardless.

#quarto_super(
kind: 
"quarto-float-tbl"
, 
caption: 
[
Comparison of Growth Models by Measures of Fitness
]
, 
label: 
<tbl-rsquares>
, 
position: 
top
, 
supplement: 
"Table"
, 
subrefnumbering: 
"1a"
, 
subcapnumbering: 
"(a)"
, 
[
#grid(columns: 2, gutter: 2em,
  [
#block[
#figure([
#table(
  columns: 3,
  align: (left,right,right,),
  table.header([Model], [Location 2], [Location 7],),
  table.hline(),
  [Richards], [1.00], [0.94],
  [Logistic], [0.99], [0.93],
  [Gompertz], [0.74], [0.00],
)
], caption: figure.caption(
position: top, 
[
R²
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-rsquares-1>


]
],
  [
#block[
#figure([
#table(
  columns: 3,
  align: (left,right,right,),
  table.header([Model], [Location 2], [Location 7],),
  table.hline(),
  [Richards], [9.47], [55.95],
  [Logistic], [29.43], [63.91],
  [Gompertz], [850.02], [6312.89],
)
], caption: figure.caption(
position: top, 
[
RSS
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-rsquares-2>


]
],
)
]
)
== Above Ground Biomass
<above-ground-biomass>
#ref(<fig-allometric-model>, supplement: [Figure]) shows the derived AB for all the trees, with exact values shown for those trees remaining at year 120 (tree 11 having only been recorded until age 80). The resulting growth curves -- as made up by the grey points -- reflect the overall trend of the originally observed variables, and also echo the respective difference for each location.

#figure([
#box(image("report_files/figure-typst/fig-allometric-model-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Above Ground Biomass (AB) as Derived from Allometric Models
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-allometric-model>


= Conclusion
<conclusion>
This report has shown how model selection and application are accompanied by a range of considerations; from relevant statistic contexts like measures of fitness, to empirical domain knowledge like reasonable values for structural tree attributes under varying climate conditions.

While the exemplary data presented easy to discern differences and inaccuracies in that regard, real world data will be more opaque, requiring special attention and insights of the data scientists concerned.

It is easy to forget that models are just estimations of an unobserved reality, and therefore never truly accurate. So it is upon the scientist to choose and apply the models with scrutiny to make effective as well as efficient use of them and convey the results to practicioners.

#block[
#heading(
level: 
1
, 
numbering: 
none
, 
[
Appendix
]
)
]
#figure([
#table(
  columns: 3,
  align: (left,left,right,),
  table.header([Location], [Model], [Mean AB \[kg\]],),
  table.hline(),
  [2], [141], [885.10],
  [2], [142], [936.53],
  [7], [147], [426.76],
)
], caption: figure.caption(
position: top, 
[
Mean Estimated Above Ground Biomass \[kg\] for a Tree 120 Years of Age
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-mean120>


Session Info

#block[
#block[
```
 package     * version date (UTC) lib source
 growthrates * 0.8.5   2025-06-15 [1] CRAN (R 4.5.0)
 knitr         1.51    2025-12-20 [1] CRAN (R 4.5.0)
 quarto        1.5.1   2025-09-04 [1] CRAN (R 4.5.0)
 tidymodels  * 1.4.1   2025-09-08 [1] CRAN (R 4.5.0)
 tidyverse   * 2.0.0   2023-02-22 [1] CRAN (R 4.5.0)

 [1] /home/max/R/x86_64-pc-linux-gnu-library/4.5
 [2] /usr/local/lib/R/site-library
 [3] /usr/lib/R/site-library
 [4] /usr/lib/R/library
 * ── Packages attached to the search path.
```

]
]


 

#set bibliography(style: "chicago-author-date")


#bibliography("references.bib")

