// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
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
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

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
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
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
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



// This is an example typst template (based on the default template that ships
// with Quarto). It defines a typst function named 'article' which provides
// various customization options. This function is called from the 
// 'typst-show.typ' file (which maps Pandoc metadata function arguments)
//
// If you are creating or packaging a custom typst template you will likely
// want to replace this file and 'typst-show.typ' entirely. You can find 
// documentation on creating typst templates and some examples here: 
//   - https://typst.app/docs/tutorial/making-a-template/
//   - https://github.com/typst/templates

// Global state for appendix mode (must be global to be accessible from document)
#let appendix-mode = state("appendix-mode", false)

#let article(
  title: none,
  subtitle: none,
  authors: none,
  date: none,
  institut: none,
  keywords: none,
  confidential: false,
  thesis-type: none,
  degree-type: none,
  study-year: none,
  submission-date: none,
  study-direction: none,
  supervisors: none,
  cover-image: none,
  notes-on-ai: none,
  reproducibility: none,
  abstract: none,
  abstract-title: none,
  cols: 1,
  margin: (x: 1.25in, y: 2cm),
  paper: "us-letter",
  lang: "en",
  region: "US",
  font: (),
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: "libertinus serif",
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  sectionnumbering: none,
  number-depth: none,
  pagenumbering: "1",
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  set page(
    paper: paper,
    margin: margin,
    numbering: none,
  )
  set par(justify: true)
  set text(lang: lang,
           region: region,
           size: fontsize,
           ..if font != () { (font: font) } else { (:) })
  // Color links (including citeproc-generated citation links) in blue.
  // Using `set text` inside the show rule preserves the link's click target.
  show link: it => {
    set text(fill: rgb("#007cad"))
    it
  }
  set heading(
    numbering: if sectionnumbering != none {
      (..nums) => if nums.pos().len() <= number-depth {
        let is-appendix = appendix-mode.get()
        if is-appendix {
          numbering("A.1.", ..nums)
        } else {
          numbering(sectionnumbering, ..nums)
        }
      }
    } else { none }
  )

  show heading: it => {
    it
    v(0.5em)
  }
  show figure.caption: set text(size: 8pt)
  // Pagebreaks are handled by Lua filter to avoid container conflicts
  
  // Title page
  if title != none or authors != none {
    page(numbering: none, columns: 1)[
      #align(center)[
        #if lang == "en" [
          ZURICH UNIVERSITY OF APPLIED SCIENCES \
          DEPARTEMENT LIFE SCIENCES AND FACILITY MANAGEMENT
        ] else [
          ZÜRCHER HOCHSCHULE FÜR ANGEWANDTE WISSENSCHAFTEN \
          DEPARTEMENT LIFE SCIENCES UND FACILITY MANAGEMENT
        ]
        #if institut != none [
          \ #upper(institut)
        ]
      ]
      #v(1fr)
      #if title != none {
        align(center)[#block(inset: 2em)[
          #set par(leading: heading-line-height)
          #text(weight: "bold", size: title-size)[#title]
          #if subtitle != none {
            parbreak()
            text(weight: "bold", size: subtitle-size)[#subtitle]
          }
          #if cover-image != none {
            v(0.5cm)
            image(cover-image.src, width: eval(cover-image.max-width), height: eval(cover-image.max-height), fit: "contain")
            v(0.1cm)
          }
          #if confidential {
            parbreak()
            if lang == "en" [
              #text(weight: "bold", size: subtitle-size)[confidential]
            ] else [
              #text(weight: "bold", size: subtitle-size)[vertraulich]
            ]
          }
          #if thesis-type != none {
            v(0.2cm)
            text(weight: "bold", size: subtitle-size)[#thesis-type]
          }
        ]]
      }

      #v(0.5cm)

      #if authors != none {
        align(center)[
          #if lang == "en" [
            by \
          ] else [
            von \
          ]
          #for author in authors [
            #author.name \
          ]
          #if degree-type != none and study-year != none [
            \ #degree-type #study-year
          ]
          #if submission-date != none [
            \ #if lang == "en" [
              Submission date #submission-date
            ] else [
              Abgabedatum #submission-date
            ]
          ]
          #if study-direction != none [
            \ Field of Study #study-direction
          ]
        ]
      }

      #v(1fr)
      
      #if supervisors != none {
        align(left)[
          #if lang == "en" [
            *Supervisors:* \
          ] else [
            *Betreuer / Betreuerinnen:* \
          ]
          #for supervisor in supervisors [
            #if supervisor.title != none [#supervisor.title] #supervisor.name \
            #supervisor.affiliation \
            \
          ]
        ]
      }
    ]
  }

  // Imprint page (second page)
  if title != none or authors != none {
    page(numbering: none, columns: 1)[
      #v(1fr)
      
      #align(left)[
        #if lang == "en" [
          *Imprint*
        ] else [
          *Impressum*
        ]
      ]
      
      #v(2em)
      
      // Citation section
      #if authors != none and title != none {
        align(left)[
          #if lang == "en" [
            *Recommended Citation:*
          ] else [
            *Zitiervorschlag:*
          ]
        ]
        
        align(left)[
          #text(size: 10pt)[
            #for author in authors [
              #author.name
              #if author != authors.last() [, ]
            ]
            #if date != none [(#date). ] else if submission-date != none [(#{
              let date-str = repr(submission-date).trim("[").trim("]")
              let year = date-str.split("-").at(0)
              year
            }). ] else [(n.d.). ]
            #emph[#title#if subtitle != none [: #subtitle]]. 
            #if institut != none {
              if lang == "en" [
                Zurich University of Applied Sciences, Department Life Sciences and Facility Management, #institut.
              ] else [
                Zürcher Hochschule für Angewandte Wissenschaften, Departement Life Sciences und Facility Management, #institut.
              ]
            }
          ]
        ]
        
        v(2em)
      }
      
      // Keywords
      #if keywords != none {
        align(left)[
          #if lang == "en" [
            *Keywords:* #keywords
          ] else [
            *Schlagworte:* #keywords
          ]
        ]
        v(2em)
      }
      
      // Notes on AI usage
      #if notes-on-ai != none {
        align(left)[
          *Notes on AI Usage* \
          #v(0.3em)
          #notes-on-ai
        ]
        v(2em)
      }

      // Reproducibility
      #if reproducibility != none {
        align(left)[
          *Reproducibility* \
          #v(0.3em)
          #reproducibility
        ]
        v(2em)
      }

      // Institute
      #if institut != none {
        align(left)[
          #if lang == "en" [
            #institut \
            Department Life Sciences and Facility Management \
            Zurich University of Applied Sciences
          ] else [
            #institut \
            Departement Life Sciences und Facility Management \
            Zürcher Hochschule für Angewandte Wissenschaften
          ]
        ]
      }
    ]
  }

  // Start page numbering for main content with header
  set page(
    numbering: pagenumbering,
    columns: cols,
    header: [
      #text(size: 0.8em)[
        #grid(
          columns: (1fr, 1fr, 1fr),
          align: (left, center, right),
          gutter: 1em,
          [ZHAW LSFM],
          [#if thesis-type != none [#thesis-type]],
          [#if authors != none [
            #for author in authors [
              #author.name
              #if author != authors.last() [, ]
            ]
          ]]
        )
      ]
      #v(0.3em)
      #line(length: 100%, stroke: 0.5pt)
    ],
    footer: [
      #text(size: 0.8em)[
        #align(center)[
          #context counter(page).display()
        ]
      ]
    ]
  )
  counter(page).update(1)

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
    doc
  }
}

#set table(
  inset: 6pt,
  stroke: none
)
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "a4",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 2,
)


// Typst custom formats typically consist of a 'typst-template.typ' (which is
// the source code for a typst template) and a 'typst-show.typ' which calls the
// template's function (forwarding Pandoc metadata values as required)
//
// This is an example 'typst-show.typ' file (based on the default template  
// that ships with Quarto). It calls the typst function named 'article' which 
// is defined in the 'typst-template.typ' file. 
//
// If you are creating or packaging a custom typst template you will likely
// want to replace this file and 'typst-template.typ' entirely. You can find
// documentation on creating typst templates here and some examples here:
//   - https://typst.app/docs/tutorial/making-a-template/
//   - https://github.com/typst/templates
#show: doc => article(
  title: [Modelling alpha diversity of Swiss vascular plants and bryophytes with a wide range of environmental predictors],
  authors: (
    ( name: [Wismer C.],
      affiliation: [],
      email: [] ),
    ),
  date: [1 July 2026],
  institut: [Institute of Natural Resource Sciences (IUNR)],
  keywords: [Vascular Plants, Bryophytes, Random Forest, Environmental Predictors, Modelling, Alpha Diversity],
  thesis-type: [Bachelor Thesis],
  degree-type: [Applied Digital Life Sciences],
  study-year: [2023],
  submission-date: [2026-07-02],
  study-direction: [Digital Environment],
  supervisors: (
    (
      title: [Prof.~Dr.],
      name: [Jürgen Dengler],
      affiliation: [ZHAW Life Sciences and Facility Management, Wädenswil],
    ),
    (
      title: [Dr.],
      name: [Stefan Widmer],
      affiliation: [ZHAW Life Sciences and Facility Management, Wädenswil],
    ),
    (
      title: [],
      name: [Nils Ratnaweera],
      affiliation: [ZHAW Life Sciences and Facility Management, Wädenswil],
    ),
  ),
  notes-on-ai: [AI tools (GitHub Copilot with mainly Claude Sonnet 4.6, Gemini, Perplexity) were used for coding and during the writing for grammar correction and rephrasing of text passages.],
  reproducibility: [All scripts produced in this bachelor thesis analysis are available on my personal GitHub https:\/\/github.com/Jaclawi. Due to large file sizes the data is available upon request.],
  cover-image: (
    src: "cover.png",
    max-width: "100%",
    max-height: "5cm",
  ),
  paper: "a4",
  fontsize: 10pt,
  sectionnumbering: "1.1.",
  number-depth: 2,
  pagenumbering: "1",
  toc_title: [Table of contents],
  toc_depth: 2,
  cols: 2,
  doc,
)

// Helper: place content spanning both columns
#let fullwidth(content) = place(auto, scope: "parent", float: true, block(width: 100%, content))

// Sequential figure numbering across all sections
#set figure(numbering: "1")

// Override any show-heading rule that resets the figure counter per section.
// Captures the counter value before the heading is rendered and restores it after,
// so Quarto's per-chapter counter resets are neutralised.
#show heading.where(level: 1): it => context {
  let fig-n = counter(figure).get().at(0)
  it
  v(0.5em)
  counter(figure).update(fig-n)
}

// Table captions at the top
#show figure.where(kind: table): set figure.caption(position: top)

// Smaller font and tighter spacing for all tables
#show figure.where(kind: table): set text(size: 8.5pt)

// Table style - minimal with no borders
#let styled-table = table.with(
  fill: white,
  stroke: none,
  inset: (x: 4pt, y: 2pt),
)
#fullwidth[
#align(center)[
#heading(level: 1, numbering: none)[Abstract]
<abstract>
]
#quote(block: true)[
Biodiversity loss in ecosystems lead to a significant change in functional aspects, which reduces their productivity and resilience. In order to keep ecosystems functioning it is thus crucial to quantify and understand how biodiversity changes across systems. For this purpose the Swiss Biodiversity Monitoring (BDM) has been gathering valuable data such as the Z9 indicator dataset that measures species richness on a small scale using about 1600 permanent 10 $m^2$ plots spanning a regular grid across the entirety of Switzerland. This species richness data was paired with environmental geodata which was processed to form 20 environmental predictors for climate, topography/soil, vegetation/habitat structure, and land use. Using Random Forest models the relationship between species richness and the environmental predictors was analyzed in a cross-sectional analysis using the latest BDM survey period (2021--2025) as well as a temporal analysis by pairing species richness changes with climatic changes over 2001--2020. The analysis of the cross-sectional data revealed an ensemble of significant environmental predictors for both bryophytes and vascular plants with complementary responses to vegetation height, soil pH and mowing intensity. Vascular plants were less predictable with a lower explained variance of 0.38 in mean Cross-validation R² compared to 0.47 for bryophytes. The species richness change analysis could not directly link climatic changes to richness changes but did indicate that stronger changes are happening in places with lower temperatures. The explained variance was very low with less than 0.02 in mean Cross-validation R² for both taxonomic groups. In conclusion the findings show familiar patterns with species richness being a complex phenomenon that depends on many environmental factors with responses to these factors not always being simple and the same between taxonomic groups. Directly linking climatic changes to BDM species richness changes was not successful and requires more careful predictor selection and target definitions.
]

]
#counter(heading).update(0)
= Introduction
<introduction>
Biodiversity loss is one of the most pressing global environmental challenges of our time \(#link(<ref-cardinaleBiodiversityLossIts2012b>)[Cardinale et al., 2012]). A decline and or redistribution of biodiversity through climatic changes leads to reduction of ecosystem functioning \(#link(<ref-peclBiodiversityRedistributionClimate2017a>)[Pecl et al., 2017]). To deal with this challenge, it is important to have predictive models of biodiversity patterns and their drivers. They help to understand where species occur and why they are changing across landscapes and thus can inform conservation planning and management decisions to mitigate biodiversity loss \(#link(<ref-ferrierMappingSpatialPattern2002>)[Ferrier, 2002]). Among the many aspects of biodiversity, species richness is a widely modelled metric to quantify and communicate biodiversity patterns. Conceptually it can be modelled at the individual level or at the community level \(#link(<ref-ferrierSpatialModellingBiodiversity2006>)[Ferrier & Guisan, 2006]). The theoretical foundation for predicting species richness relies on niche theory, which suggests that species distribution and communities are driven by individual species and their responses to environmental gradients \(#link(<ref-austinSpatialPredictionSpecies2002>)[Austin, 2002]). At broad spatial scales, these gradients are primarily affected by climate, especially energy and water availability, with diversity typically peaking in warm, moist environments where photosynthetic productivity is highest \(#link(<ref-currieEnergyLargeScalePatterns1991>)[Currie, 1991]\; #link(<ref-hawkinsENERGYWATERBROADSCALE2003>)[Hawkins et al., 2003]). At finer scales, topographic complexity, soil chemistry, disturbance regimes, and land usage by humans interact with the climatic factors to shape local richness patterns with greater heterogeneity generally leading to higher species richness \(#link(<ref-steinEnvironmentalHeterogeneityUniversal2014>)[Stein et al., 2014]). Furthermore, the interplay between biotic and abiotic factors create complex dynamics that must be accounted for in ecological modelling \(#link(<ref-krebsEcologyExperimentalAnalysis2014b>)[Krebs, 2014]). With individuals and communities responding to these environmental gradients along response curves which are often not simple hump-shaped curves but rather more complex due to stressors such as climate change \(#link(<ref-oksanenContinuumTheoryRevisited2002>)[Oksanen & Minchin, 2002]). Due to the importance of understanding biodiversity patterns and the reliance on high-quality data a Swiss nationwide biodiversity monitoring program (BDM) was established in 2001 to systematically track biodiversity indicators across the country \(#link(<ref-weberScaleTrendsSpecies2004>)[Weber et al., 2004]). Several studies have already worked with data from this program to model diversity. Wohlgemuth et al. (#link(<ref-wohlgemuthModellingVascularPlant2008>)[2008]) used the BDM Z7 indicator which is a coarse 1 km² sample network to produce nationwide richness maps for vascular plants. Steinmann et al. (#link(<ref-steinmannModellingPlantSpecies2009>)[2009]) used the finer scale Z9 indicator with its 10 m² permanent plots and modelled plant species richness across Switzerland focusing on non-urban areas. Zellweger et al. (#link(<ref-zellwegerDisentanglingEffectsClimate2015>)[2015]) used a subset of the Z9 plots located in temperate forest environments to understand the contributions of various predictors on species richness within forests for both plants and bryophytes. In a follow-up study Zellweger et al. (#link(<ref-zellwegerEnvironmentalPredictorsSpecies2016>)[2016]) then used the coarser Z7 indicator focusing on forests and plants. Finally and most recently Vigués Jorba et al. (#link(<ref-viguesjorbaDifferentialResponsesTaxonomic2025a>)[2025]) examined the response of different taxa and their taxonomic, functional and phylogenetic diversity to environmental factors also within forests.

Despite the rich and high quality dataset at hand no study was done using all BDM Z9 plots to create a model explaining species richness for bryophytes and vascular plants across Switzerland. A in-depth look at the differences between the two taxonomic groups and their response curves to environmental factors with non-parametric models, such as Random Forests, has not yet been done. Additionally the temporal structure of the dataset has not yet been paired with environmental data to understand species richness change over time and new environmental data now allows for a more up to date analysis. To address these gaps, I want to take a closer look at the following research questions:

#block[
#set enum(numbering: "(I)", start: 1)
+ Which environmental variables act as the most significant predictors of species richness and how does their explanatory behaviour differ across bryophytes and vascular plants?
]

#block[
#set enum(numbering: "(i)", start: 2)
+ Which environmental factors constitute significantly to species richness changes in recent years and how does their explanatory behaviour differ across bryophytes and vascular plants?
]

= Material and Methods
<material-and-methods>
== Study Area
<study-area>
The study area encompasses the entire country of Switzerland, which is located in Central Europe. Switzerland covers an area of approximately 41'290 $upright("km")^2$ and is characterized by diverse landscapes, including the Swiss Alps, the Swiss Plateau, and the Jura Mountains. The country has a temperate climate with distinct seasons, ranging from cold winters to warm summers. Between 1991 and 2020 the average annual temperature was 5.8 °C. The highest annual precipitation occurs in the Alpine regions with about 2'000mm, while the northern plateau gets between 1'000mm and 1'500mm of annual precipitation \(#link(<ref-federalofficeofmeteorologyandclimatologymeteoswissClimateSwitzerlandMeteoSwissn.d>)[Federal Office of Meteorology and Climatology MeteoSwiss, n.d]). Switzerland is known for its variety of ecosystems such as forests, grasslands, wetlands, and alpine habitats that support a wide range of plant and animal species \(#link(<ref-delarzeLebensraeumeSchweizOekologie2015>)[Delarze et al., 2015]). The country's topography varies significantly, with elevations ranging from lowland areas to high mountain peaks, influencing local climate conditions and biodiversity patterns.

== Species Data
<species-data>
In my analysis I used the Z9 field data from the Biodiversity Monitoring Switzerland BDM \(#link(<ref-weberScaleTrendsSpecies2004>)[Weber et al., 2004]) which consist of approximately 1'600 circular 10 $m^2$ permanent plots on land, spread across Switzerland in a regular grid with a spacing of 6km in North South and 4km in East West direction between each plot. The centres of these plots are marked with a magnet buried in the upper surface which allows for precise relocation during each survey. If a magnet could not be buried, a steel pin or colour marker was used instead. These plots were surveyed since 2001 by skilled botanists using a staggered approach, meaning that in each year a fifth of the entire sample plots were surveyed. Thus each plot is surveyed once every five years. This levels off extreme annual fluctuations while still allowing for up-to-date reporting \(#link(<ref-bdmcoordinationofficeSwissBiodiversityMonitoring2014a>)[BDM Coordination Office, 2014]). I analyzed all of the data points even when no bryophytes and or vascular plant species were found during the survey. Plots which were not accessible due to them being situated on water bodies or in inaccessible alpine regions were already excluded when receiving the data. Across all survey years a total of 1449 unique plots were visited at least once (#ref(<fig-spatial-distribution>, supplement: [Figure])). Using this data the per-plot and year alpha richness was computed separately for both taxonomic groups from the raw BDM survey records. The resulting richness tables contained 7'105 surveys for bryophytes and 7'137 surveys for vascular plants.

#figure([
#box(image("_figures/plot_locations.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
Spatial distribution of the 10 $m^2$ survey plots on a regular grid across Switzerland.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-spatial-distribution>


== Geodata
<geodata>
=== Acquisition
<acquisition>
Monthly minimum and maximum temperature as well as monthly precipitation data were obtained from MeteoSwiss \(#link(<ref-StartseiteMeteoSchweiz>)[#emph[Startseite - MeteoSchweiz], n.d.]) covering the period of 1971--2023. They were downloaded at a resolution of 1km and were present as GeoTIFF files in EPSG:2056. Monthly direct solar irradiation layers were additionally obtained from MeteoSwiss as GeoTiff with the same resolution covering the period of 2004--2021 in EPSG:4326. Topographic raw data was obtained from the Federal Office of Topography (swisstopo) in the form of a nationwide elevation Model at 25m resolution downloaded directly from swisstopo \(#link(<ref-swisstopo2010dhm25>)[swisstopo, 2010]). The data were downloaded as ASCII grid files in the older Swiss coordinate system EPSG:21781. Habitat data were obtained from EnviDat by the Swiss Federal Institute for Forest, Snow and Landscape Research (WSL) in form of the Swiss habitat map v1\_2 2025 \(#link(<ref-the-habitat-map-of-switzerland-v1_2-2025>)[Price et al., 2025]), a polygon vector layer in EPSG:2056 classifying habitats into 9 first level and 32 second level classes according to Delarze et al. (#link(<ref-delarzeLebensraeumeSchweizOekologie2015>)[2015]). A Vegetation height map \(#link(<ref-ginzler2021vegetationheightmodelnfi>)[Ginzler, 2021]) was obtained from the 2021 national stereo vegetation height model at 2m resolution, downloaded also from EnviDat by WSL as a GeoTIFF in EPSG:2056. Soil data were obtained from the Kompetenzzentrum Boden (KoBo) national soil service provider \(#link(<ref-kobo_bodenportal>)[Kompetenzzentrum Boden (KOBO), 2026]). It provides raster layers as GeoTIFFs in EPSG:2056 in 30m resolution for various soil properties. Humus content, cation exchange capacity (KAK), pH, sand fraction, silt fraction, and clay fraction were available in three depth profiles (0--30, 30--60, 60--120 cm), while soil organic carbon stock was available in just one (0-120 cm). Land use data was obtained from the Swiss Arealstatistik, provided by the Federal Statistical Office \(#link(<ref-bfs_geostat_1979_85_arealstatistik>)[BFS GEOSTAT, 1985]), which classifies land cover on a regular point grid across Switzerland at 100m spacing, available in EPSG:2056 as a vector layer. It provides multiple classification levels for different analytical purposes. Additionally a grassland mowing intensity map for the year 2021 was obtained at 10m resolution from WSL \(#link(<ref-grassland-use-intensity-maps-for-switzerland-2023>)[Weber et al., 2023]). It was available as a GeoTiff in EPSG:32632 and contained values representing the modelled number of mowing events per year.

#fullwidth[
  #figure(
    placement: auto,
    table(
      columns: (auto, 1fr, auto, auto, auto),
      stroke: none,
      align: left,
      inset: (x: 4pt, y: 2pt),
      table.header([*Data Type*], [*Variables*], [*Resolution*], [*Acquired Layers*], [*Source*]),
      table.hline(stroke: 0.5pt),
      [Climate], [Monthly minimum and maximum temperature, monthly precipitation], [1 km], [1908], [MeteoSwiss],
      [Climate], [Monthly direct solar irradiation], [1 km], [252], [MeteoSwiss],
      [Topography/Soil], [Digital elevation model ], [25 m], [1], [swisstopo],
      [Topography/Soil], [Humus, pH, KAK, sand, silt, clay (3 depth profiles, 0–30, 30–60, 60–120 cm)], [30 m], [18], [KoBo],
      [Topography/Soil], [Organic carbon stock in 1 depth profile 0–120 cm], [30 m], [1], [KoBo],
      [Vegetation/Habitat], [Habitat classification], [Vector polygons], [1], [WSL],
      [Vegetation/Habitat], [Vegetation height], [2 m], [1], [WSL],
      [Land Use], [Arealstatistik land cover classification containing classes LU\_4, LU\_10 and AS\_4], [Vector points], [1], [FSO],
      [Land Use], [Grassland mowing intensity], [10 m], [1], [WSL],
    ),
    caption: [Raw environmental data sources and number of acquired geodata layers.],
  ) <tbl-raw-data>
]
=== Geodata Processing
<geodata-processing>
To capture the climatic conditions relevant to each survey year, 19 bioclimatic variables (BIO1--BIO19) were computed using a 30-year sliding window approach with R \(#link(<ref-rcoreteamLanguageEnvironmentStatistical2026>)[R Core Team, 2026]) and the packages #NormalTok("terra"); \(#link(<ref-hijmansTerraSpatialData2026>)[Hijmans et al., 2026]) and #NormalTok("dismo"); \(#link(<ref-hijmansDismoSpeciesDistribution2024>)[Hijmans et al., 2024]). For each year between 2001 and 2021, the monthly averages over the preceding 30 years were first calculated for the maximum and minimum temperature and the mean precipitation, the bioclimatic variables were then derived from these averages using the #NormalTok("biovars"); function from #NormalTok("dismo");. This produces a time series of bioclimatic layers as GeoTIFFs in the original resolution of 1 km. For Radiation the data for a full 30-year window was not available and thus the yearly average over a 15 year window (2004--2021) was computed to derive a single climatic variable representing radiation conditions. Beforehand the data was originally in EPSG:4326 and was reprojected to EPSG:2056 using #NormalTok("terra"); prior to averaging and saving as GeoTIFFs also in 1 km resolution. The Digital Elevation Model (DEM) was originally in the older Swiss coordinate system (EPSG:21781) and was reprojected to EPSG:2056 again using #NormalTok("terra");. From the reprojected DEM, the slope, aspect and Topographic Position Index (TPI) were derived keeping the 25m resolution using the #NormalTok("terrain"); function, with slope and aspect expressed in degrees. The Topographic Wetness Index (TWI) was computed separately using the R package #NormalTok("whitebox"); \(#link(<ref-lindsayWhiteboxGATCase2016>)[Lindsay, 2016]). Prior to TWI calculation, artificial flow sinks were removed from the DEM using a least-cost depression breaching algorithm (#NormalTok("wbt_breach_depressions_least_cost");). A slope raster was then temporarly derived from the sink-free DEM and clamped to a minimum of 0.001° to prevent infinite TWI values in flat terrain resulting in false values. The temporary specific catchment area layer was then calculated using the D-Infinity flow accumulation algorithm, and TWI was derived from the catchment area and slope using #NormalTok("wbt_wetness_index");. Only the final TWI layer was saved as GeoTIFFs in the original 25m resolution. The gathered land cover classification layer (Arealstatistik) is distributed as a vector point layer where each point represents the centre of a 100 $times$ 100 m cell. To enable spatial extraction the three classification levels LU\_4, LU\_10, and AS\_4 were each rasterized to a 100 m resolution grid in EPSG:2056 using #NormalTok("rasterize");. A template raster was constructed from the bounding box of the point layer, extended by 50 m (half the cell size) on each side so that the survey points align with cell centres rather than cell edges. Each classification column was then placed into this template individually and saved as a GeoTIFF. The grassland use intensity map was originally provided in EPSG:32632 and was reprojected to EPSG:2056 using #NormalTok("terra"); and saved as a GeoTIFF in the original 10m resolution. Due to it being a rather large dataset, the grassland use intensity map was reprojected using a High Performance Computing cluster (HPC) with larger amounts of computing power available.

=== Variable extraction
<variable-extraction>
Static Raster layers including topography, soil, land use, vegetation height, and mowing intensity were extracted at each BDM plot location using #NormalTok("extract");. The per plot habitat type was extracted by overlaying the plot coordinates with the habitat map using #NormalTok("st_intersection"); from the sf package \(#link(<ref-pebesmaSimpleFeaturesStandardized2018a>)[Pebesma, 2018]). The bioclimatic variables were extracted separately by extracting the per plot and year values from the GeoTIFFs, resulting in a long-format panel with one row per plot times the end years covering 2001--2021.

=== Post-extraction processing
<post-extraction-processing>
Ranger's Importance p-values method used later in the analysis required that all predictor variables to be without any missing values. This meant I had to deal with missing values which were present in the KoBo soil, vegetation height, and mowing intensity rasters. KoBo soil rasters did not provide complete national coverage because the maps are built from exposed soil pixels only \(#link(<ref-stumpfSpatiotemporalLandUse2018>)[Stumpf et al., 2018]). Thus for about a fifth of the plots, which are located in urban sealed areas or in mountainous regions, no valid raster values were extractable. For these plots, missing values were gap-filled by assigning the value of the nearest valid raster pixel. This imputation of missing values was preferred over leaving them as "Not-a-Number" (#NormalTok("NaN");) or imputing them with the mean or median of the raster layer as I assumed that the nearest valid pixel is more likely to represent the local soil conditions of the plot. The gap-filling procedure was implemented using an expanding search radius until a valid pixel was found, allowing for the imputation of missing values using #NormalTok("nearest");. The vegetation height raster contained #NormalTok("NaN"); values in areas which were not computed. These #NormalTok("NaN"); values were set to zero to represent the absence of vegetation height in these locations. The assumption here being that the #NormalTok("NaN"); values were not due to data errors but rather reflected true zero vegetation height, such as in rocky terrain or low grassland areas. Similarly with mowing intensity, simply imputing missing values with often used mean would most likely skew the interpretation. Thus Mowing intensity #NormalTok("NaN"); values, indicating locations outside the grassland mask, were also set to zero to represent no mowing events. Mowing intensity was then binned into four categories (No Mowing, Low, Medium, High) based on the number of mowing events per year. No-Mowing was defined as 0 events per year, Low as 1--2 events, Medium as 3--4 events, and High as 5 or more events. Aspect was discretised as well, into eight cardinal directions (N, NE, E, SE, S, SW, W, NW). This was done after calculating the aspect raster from the DEM. The resulting categorical variables were then converted to factors.

== Dataset Construction
<dataset-construction>
=== Species Richness Cross-sectional Dataset
<species-richness-cross-sectional-dataset>
For the cross-sectional dataset only the latest survey period was used (2021--2025), meaning that only the most recent survey records for each plot were retained. This resulted in 1'435 bryophyte and 1'442 vascular plant plots with valid richness values. These were then joined with the extracted environmental per plot values by plot ID. The result were two datasets with one row per plot, one column for species richness and 68 columns for the environmental predictors. Because the dimensionality was way to high for the number of observations, a variable selection process was carried out to reduce the number of predictors. Firstly only the first level of the TypoCH habitat classification was retained (9 habitat types) since the second level (32 habitat types) was assumed to be to detailed. Then the Land use classification with 10 classes was dropped in favour of the 4-class classification (1=urban area, 2=agricultural area, 3=forest, 4=unproductive). The aspect layer could be dropped as this was turned into a factor and so could the mowing intensity. The elevation was not included as it was assumed to be very strongly correlated with the bioclimatic variables and would mask their effects. Then only the top level of the soil variables was retained (0--30 cm) as Goebes et al. (#link(<ref-goebesStrengthSoilplantInteractions2019>)[2019]) have shown that it leads to the best predictive performance of richness. The silt and clay fractions were dropped as they are dependent on the sand fraction. Similarly to Zellweger et al. (#link(<ref-zellwegerEnvironmentalPredictorsSpecies2016>)[2016]), Wohlgemuth et al. (#link(<ref-wohlgemuthModellingVascularPlant2008>)[2008]) and Ellerbrok et al. (#link(<ref-ellerbrokDeterminantsTerrestrialLimnic2026>)[2026]) I tried to choose bioclimatic variables representing the most ecologically relevant aspects of temperature and precipitation. Meaning that the focus was on temperature and precipitation during the coldest and warmest quarters of the year, as well as temperature seasonality and isothermality. Thus only bioclimatic variables BIO3, BIO4, BIO10, BIO11, BIO18, and BIO19 were retained while the other 13 bioclimatic variables were dropped. All this reduced the number of predictors from 68 to 20. A mixed correlation matrix using pearson for continues variables, polyserial correlation for continuous--ordinal pairs, and polychoric correlation for ordinal--ordinal pairs was computed using #NormalTok("hetcor"); from the package #NormalTok("polycor"); \(#link(<ref-foxPolycorPolychoricPolyserial2025>)[Fox, 2025]) to check for collinearity among the remaining predictors. The correlation matrix constructed with the remaining predictors (Appendix) revealed still some strong correlation between the bioclimatic variables. According to Booth (#link(<ref-boothCheckingBioclimaticVariables2022>)[2022]) this was deemed fine and thus the final set of 20 predictors entering the model for the cross-sectional attempt is summarized in @tbl-predictors.

#fullwidth[
  #figure(
    placement: auto,
    table(
      columns: (auto, 1fr, auto),
      stroke: none,
      align: left,
      inset: (x: 4pt, y: 2pt),
      table.header([*Variable*], [*Description*], [*Type*]),
      table.hline(stroke: 0.8pt),
      table.cell(colspan: 3)[#text(size: 8pt)[Climate]],
      [#h(8pt)`bio3`], [Isothermality (BIO3), BIO2 / BIO7 × 100], [Numeric],
      [#h(8pt)`bio4`], [Temperature seasonality (BIO4), standard deviation × 100], [Numeric],
      [#h(8pt)`bio10`], [Mean temperature of the warmest quarter (°C)], [Numeric],
      [#h(8pt)`bio11`], [Mean temperature of the coldest quarter (°C)], [Numeric],
      [#h(8pt)`bio18`], [Precipitation of the warmest quarter (mm)], [Numeric],
      [#h(8pt)`bio19`], [Precipitation of the coldest quarter (mm)], [Numeric],
      [#h(8pt)`radiation_y_15yr`], [Mean annual direct solar irradiation, 15-year average], [Numeric],
      table.cell(colspan: 3)[#text(size: 8pt)[Vegetation/Habitat]],
      [#h(8pt)`veg_height`], [Vegetation height, 2021 stereo model (m)], [Numeric],
      [#h(8pt)`TypoCH_1st_code`], [First-level habitat type code (TypoCH)], [Factor],
      table.cell(colspan: 3)[#text(size: 8pt)[Topography/Soil]],
      [#h(8pt)`aspect_factor`], [Slope aspect as 8 direction factors (N, NE, E, SE, S, SW, W, NW)], [Factor],
      [#h(8pt)`slope`], [Terrain slope (°)], [Numeric],
      [#h(8pt)`tpi`], [Topographic Position Index], [Numeric],
      [#h(8pt)`twi`], [Topographic Wetness Index], [Numeric],
      [#h(8pt)`soc_stock_0_120`], [Soil organic carbon stock, 0–120 cm (t ha⁻¹)], [Numeric],
      [#h(8pt)`humus_0_30`], [Humus content, 0–30 cm (%)], [Numeric],
      [#h(8pt)`kak_0_30`], [Cation exchange capacity, 0–30 cm (cmol#sub[c] kg⁻¹)], [Numeric],
      [#h(8pt)`ph_0_30`], [Soil pH, 0–30 cm], [Numeric],
      [#h(8pt)`sand_0_30`], [Sand fraction, 0–30 cm (%)], [Numeric],
      table.cell(colspan: 3)[#text(size: 8pt)[Land Use]],
      [#h(8pt)`LU_4`], [Land use class (4-level Arealstatistik classification)], [Factor],
      [#h(8pt)`mow_int_cat`], [Grassland mowing intensity category (No Mowing, Low, Medium, High)], [Factor],
    ),
    caption: [Final set of 20 environmental predictors used in the cross-sectional richness models. The four factor variables enter the Random Forest as unordered categorical predictors.],
  ) <tbl-predictors>
]
=== Species Richness Change Dataset
<species-richness-change-dataset>
Based on the variables selected in the cross-sectional dataset a second dataset was constructed to quantify temporal change at each plot. For each plot with at least three survey records within the 2001--2020 survey window, a simple linear regression of species richness against survey year was fitted. The latest survey period was not included in this analysis because MeteoSwiss and thus bioclimatic data for the 2021--2025 survey period was not fully available. The slope coefficient (species / year) was the target measure of the rate of richness change. Then for the same period the bioclimatic trends were derived from the 21-year bioclimatic panel data. For each of the six retained bioclimatic variables, a per-plot linear regression over 2001--2020 was computed as the rate of climatic change. Additionally, the 2001 bioclimatic snapshot was extracted as a baseline capturing the starting climate conditions at each plot. The change modelling dataset was then assembled by joining the linear regression fitted richness changes, the six bioclimatic changes, the six bioclimatic baselines, and the 14 remaining static environmental predictors (I.e., the full 20-predictor set with the six bioclimatic normals replaced by their trends and baselines) resulting in a total of 26 predictors @tbl-predictors-change with 1'433 valid bryophyte and 1'437 vascular plant plots.

#fullwidth[
  #figure(
    placement: auto,
    table(
      columns: (auto, 1fr, auto),
      stroke: none,
      align: left,
      inset: (x: 4pt, y: 2pt),
      table.header([*Variable*], [*Description*], [*Type*]),
      table.hline(stroke: 0.8pt),
      table.cell(colspan: 3)[#text(size: 8pt)[Climate — Static]],
      [#h(8pt)`radiation_y_15yr`], [Mean annual direct solar irradiation, 15-year average], [Numeric],
      table.cell(colspan: 3)[#text(size: 8pt)[Climate — Baseline (2001)]],
      [#h(8pt)`bio3_baseline`], [Isothermality (BIO3) at 2001 baseline, BIO2 / BIO7 × 100], [Numeric],
      [#h(8pt)`bio4_baseline`], [Temperature seasonality (BIO4) at 2001 baseline, standard deviation × 100], [Numeric],
      [#h(8pt)`bio10_baseline`], [Mean temperature of the warmest quarter at 2001 baseline (°C)], [Numeric],
      [#h(8pt)`bio11_baseline`], [Mean temperature of the coldest quarter at 2001 baseline (°C)], [Numeric],
      [#h(8pt)`bio18_baseline`], [Precipitation of the warmest quarter at 2001 baseline (mm)], [Numeric],
      [#h(8pt)`bio19_baseline`], [Precipitation of the coldest quarter at 2001 baseline (mm)], [Numeric],
      table.cell(colspan: 3)[#text(size: 8pt)[Climate — Trend (2001–2020)]],
      [#h(8pt)`bio3_slope`], [Isothermality (BIO3) linear trend 2001–2020, BIO2 / BIO7 × 100], [Numeric],
      [#h(8pt)`bio4_slope`], [Temperature seasonality (BIO4) linear trend 2001–2020, standard deviation × 100], [Numeric],
      [#h(8pt)`bio10_slope`], [Mean temperature of the warmest quarter trend 2001–2020 (°C yr⁻¹)], [Numeric],
      [#h(8pt)`bio11_slope`], [Mean temperature of the coldest quarter trend 2001–2020 (°C yr⁻¹)], [Numeric],
      [#h(8pt)`bio18_slope`], [Precipitation of the warmest quarter trend 2001–2020 (mm yr⁻¹)], [Numeric],
      [#h(8pt)`bio19_slope`], [Precipitation of the coldest quarter trend 2001–2020 (mm yr⁻¹)], [Numeric],
      table.cell(colspan: 3)[#text(size: 8pt)[Vegetation/Habitat]],
      [#h(8pt)`veg_height`], [Vegetation height, 2021 stereo model (m)], [Numeric],
      [#h(8pt)`TypoCH_1st_code`], [First-level habitat type code (TypoCH)], [Factor],
      table.cell(colspan: 3)[#text(size: 8pt)[Topography/Soil]],
      [#h(8pt)`aspect_factor`], [Slope aspect as 8 direction factors (N, NE, E, SE, S, SW, W, NW)], [Factor],
      [#h(8pt)`slope`], [Terrain slope (°)], [Numeric],
      [#h(8pt)`tpi`], [Topographic Position Index], [Numeric],
      [#h(8pt)`twi`], [Topographic Wetness Index], [Numeric],
      [#h(8pt)`soc_stock_0_120`], [Soil organic carbon stock, 0–120 cm (t ha⁻¹)], [Numeric],
      [#h(8pt)`humus_0_30`], [Humus content, 0–30 cm (%)], [Numeric],
      [#h(8pt)`kak_0_30`], [Cation exchange capacity, 0–30 cm (cmol#sub[c] kg⁻¹)], [Numeric],
      [#h(8pt)`ph_0_30`], [Soil pH, 0–30 cm], [Numeric],
      [#h(8pt)`sand_0_30`], [Sand fraction, 0–30 cm (%)], [Numeric],
      table.cell(colspan: 3)[#text(size: 8pt)[Land Use]],
      [#h(8pt)`LU_4`], [Land use class (4-level Arealstatistik classification)], [Factor],
      [#h(8pt)`mow_int_cat`], [Grassland mowing intensity category (No Mowing, Low, Medium, High)], [Factor],
    ),
    caption: [Final set of 26 environmental predictors used in the richness change models. The six bioclimatic normals from the cross-sectional model are replaced by their 2001 baseline values and linear trends over 2001–2020.],
  ) <tbl-predictors-change>
]
== Modelling Approach
<modelling-approach>
For modelling species richness and species richness change, I used Random Forests (RF) implemented in the R package #NormalTok("ranger"); \(#link(<ref-wrightRangerFastImplementation2017>)[Wright & Ziegler, 2017]). RF is a non-parametric ensemble learning method that constructs multiple decision trees during training and outputs the mean prediction of the individual trees. It is robust to collinearity among predictors, less prone to overfitting and can handle high-dimensional data. To find suitable hyperparameters for the RF models, a Cross validation on the entire dataset was performed like Zellweger et al. (#link(<ref-zellwegerDisentanglingEffectsClimate2015>)[2015]) did, since the in Machine-Learning often used train-test split was not applicable because the dataset was small and the initial random train-split mainly determined the model performance. This was implemented using the the R package #NormalTok("caret"); \(#link(<ref-kuhnBuildingPredictiveModels2008a>)[Kuhn, 2008]) with the #NormalTok("ranger"); method. The hyperparameters tuned included the number of variables randomly sampled as candidates at each split (#NormalTok("mtry");), the minimum node size (#NormalTok("min.node.size");). The resulting hyperparameter combination revealed almost no deviations and thus for simplicity in all models rangers default values of mtry equalling the rounded down square root of the number of predictors and minimum node size of 3 were used. Using these hyperparameters the first constructed bryophyte richness model was checked for stability in regards of the number of trees chosen and based on this 500 trees seemed stable and was chosen for all other models (Appendix). The final RF models were then fitted using #NormalTok("ranger"); with the selected hyperparameters and 500 trees. The same modelling approach was applied separately for bryophytes and vascular plants, as well as for species richness and species richness change, resulting in a total of four RF models. Afterwards the models were interpreted using the variable importance measure based on permutation importance and partial dependence plots for the top predictors. The variable importance was computed using the #NormalTok("importance_pvalues"); function from #NormalTok("ranger");, which provides p-values for the importance scores based on 100 permutation tests. The partial dependence plots were generated using the #NormalTok("partialPlot"); function from the R package #NormalTok("pdp"); \(#link(<ref-greenwellPdpPackageConstructing2017>)[Greenwell, 2017]), which shows the marginal effect of a predictor on the response variable while averaging out the effects of other predictors. To produce spatially continuous richness maps for the entirety of Switzerland, the finalised RF richness models for bryophytes and vascular plants richness were applied to a initialized national raster grid at 100 m resolution in EPSG:2056 based on the arealstatistik LU\_4 raster. Before assembling the raster stack, the habitat type vector layer was rasterized to 10 m resolution in a separate file. Afterwards a shared predictor stack of all 20 variables was assembled by loading each source raster and resampling it to the grid using #NormalTok("resample");. Continuous predictors were resampled with bilinear interpolation and categorical predictors (habitat type, land-use class) were resampled using nearest-neighbour assignment to preserve their integer codes. Using the same rules as in training the missing values in the vegetation height and mowing intensity rasters were set to zero and the mowing intensity and aspect were binned into categories. The final raster stack was then passed to the RF models to predict species richness for each pixel using #NormalTok("predict"); and to compute the standard error of the predictions via the infinitesimal jackknife estimator saving 2 GeoTIFF's for each taxonomic group \(#link(<ref-wagerConfidenceIntervalsRandom2014>)[Wager et al., 2014]). Only the soil layers were restricting the prediction extent, as they did not cover the entire country. Due to large files sizes and computational power needed this step was also done on a HPC cluster.

= Results
<results>
==== Models of species richness
<models-of-species-richness>
In the cross-sectional dataset during the latest survey period (2021--2025) the average bryophyte species richness across all plots was 9.9 species per 10 $m^2$ (SD = 8.8, range = 0--46), while the mean vascular plant species richness was 23.6 species per 10 $m^2$ (SD = 15.2, range = 0--77). During hyperparameter tuning the result on the test set was highly dependent on the random train-test split, thus as mentioned in the materials and methods section a Cross-validation on the entire dataset was performed. Plant species were less predictable than bryophyte species with a CV mean explained variance (R²) of 0.38 for vascular plants and 0.47 for bryophytes, and standard deviation of 0.04 for both vascular plants and bryophytes. This meant that the prediction performance of the models could vary up to 8 percentage points depending on the random split performed. Also during Cross-validation the mean absolute error (MAE) was 9.7 for vascular plants and 4.8 for bryophytes. Meaning on average the species richness predictions were off by about 10 species for vascular plants and 5 species for bryophytes. Out of Bag (OOB) Root mean squared error (RMSE) on the final models fitted on the entire dataset was 12.1 for vascular plants and 6.4 for bryophytes, OOB R² of the final RF model was similar to the CV results with an R² of 0.47 for bryophytes and 0.36 for vascular plants.

The most important predictor of bryophyte and plant species richness were the 4 Land use classes (LU\_4) by the Arealstatistik (@fig-imp-richness-combined). It was able to explain a large portion of the variance in species richness for both groups, with a percentage decrease in explained variance of 17% for vascular plants and 77% for bryophytes when left out during permutation. The temperatures in the warmest and coldest quarters, the slope, the mowing intensity and the vegetation height were also among the most important predictors for both groups. The only difference in the top predictors between the two groups was that for bryophytes the soil organic carbon, the pH value and the solar radiation was also amongst the most important predictors.

Partial dependence plots for the significant continuous predictors of bryophyte and plant species richness reveal approximately a bell curve as response for the mean temperature of the warmest quarter (BIO10) and mean temperature of the coldest quarter (BIO11) for both groups (@fig-pdp-richness-continuous). Vegetation height revealed a decrease in plant richness with increasing vegetation height whilst for bryophytes the relationship was exactly the opposite. It is to be noted that an artefact from setting the vegetation height #NormalTok("NaN"); values to zero is visible as a spike in the plot at zero vegetation height. The slope appears as a important predictor for both groups with a positive relationship for both. Soil organic carbon content (SOC) shows a rapid decline in richness with increasing SOC for bryophytes and a similar response for vascular plants despite not being significant. Finally, soil pH shows a negative relationship with bryophyte richness whilst vascular plants show the opposite pattern. For the factorial predictors, the partial dependence plots show that for vascular plants the highest species richness could be found amongst agricultural land followed by urban areas whilst for bryophytes the highest species richness was found in forests followed by unproductive areas (@fig-pdp-richness-factor). For mowing intensity it can be seen that plant richness increases with increasing mowing intensity, whilst bryophytes show the opposite pattern. Finally in the Aspect partial dependency once again a contrasting pattern between the two groups could be observed with bryophytes showing the highest richness on south-facing slopes and vascular plants showing the highest richness on north-facing slopes.

#fullwidth[
  #figure(
    placement: auto,
    scope: "parent",
    image("_figures/combined_importance_richness_barplot.png", width: 100%),
    caption: [Variable importance scores as the percentage decrease in explained variance for the most important and significant (p\<0.05) predictors of bryophyte (top) and plant (bottom) species richness colored according to their group.],
  ) <fig-imp-richness-combined>
  #figure(
    placement: auto,
    scope: "parent",
    image("_figures/combined_richness_pdp.png", width: 100%),
    caption: [Partial dependence plots to compare continuous predictors of bryophyte and plant species richness. Significant (p\<0.05) predictors are shown as solid lines with insignificant ones as dashed lines. The initial spike at zero vegetation height is an artefact from setting the `NaN` values to zero during data processing.],
  ) <fig-pdp-richness-continuous>
]
#figure(
  placement: top,
  scope: "column",
  image("_figures/combined_richness_factor_pdp.png", width: 100%),
  caption: [Partial dependence for factorial species richness predictors. Insignificant (p\<0.05) ones are shown as diagonal hatching. Dependencies have been mean centered. LU 4 code 1 is urban, 2 is agricultural, 3 is forest and 4 is unproductive.],
) <fig-pdp-richness-factor>
The created extrapolated species richness maps for bryophytes and vascular plants show some clear distribution patterns (@fig-spatial-prediction-combined) with higher species richness occurring in pre-alpine regions whilst in the central plateau the richness is lower. The estimated prediction uncertainty maps reveal an overall evenly distributed modelling uncertainty across the country with some higher uncertainty in local patches found in the Jura region and in between the central plateau and the alpine regions (@fig-spatial-prediction-combined-se).

#fullwidth[
  #figure(
    placement: auto,
    scope: "parent",
    image("_figures/prediction_combined_100m_viridis.png", width: 100%),
    caption: [Applied RF model predicting bryophyte (left) and plant (right) species richness at 100m resolution. Predictions in darker blue/purple colours indicate lower predicted richness. Not predicted areas due to missing KoBo soil coverage are shown in grey.],
  ) <fig-spatial-prediction-combined>
  #figure(
    placement: auto,
    scope: "parent",
    image("_figures/prediction_combined_se_100m.png", width: 100%),
    caption: [Applied RF model estimating bryophyte (left) and plant (right) species richness error using the oob jackknife estimator at 100m resolution. Not predicted areas due to missing KoBo soil coverage are shown in grey.],
  ) <fig-spatial-prediction-combined-se>
]
#pagebreak()
==== Models of Species Richness Change
<models-of-species-richness-change>
In the species richness change dataset, the average change of bryophyte richness change was 0.06 species per year and plot (SD = 0.31, range = -2.03 to 1.94), with vascular plants having the same mean change of 0.06 species per year and plot (SD = 0.55, range = -3.74 to 3.72). The richness change models showed near-zero predictive performance. Cross-validation revealed a mean R² of 0.01 for vascular plants and 0.02 for bryophytes, with standard deviations of 0.01 and 0.01 respectively. The mean absolute error (MAE) was 0.38 species per year for vascular plants and 0.21 species per year for bryophytes, meaning that on average the predicted rate of richness change was off by roughly 0.4 species per year for vascular plants and 0.2 species per year for bryophytes. The OOB R² of the final models confirmed the poor fit, with values of −0.01 for vascular plants and 0.01 for bryophytes.

#fullwidth[
  #figure(
    placement: none,
    image("_figures/combined_importance_change_barplot.png", width: 100%),
    caption: [Variable importance scores as the percentage decrease in explained variance for the most important and significant (p\<0.05) predictors of bryophyte (top) and plant (bottom) species richness changes colored according to their group.],
  ) <fig-imp-change-combined>
  #figure(
    placement: none,
    image("_figures/combined_change_pdp.png", width: 100%),
    caption: [Partial dependence plots to compare continuous predictors of bryophyte and plant species richness changes. Significant (p\<0.05) predictors are shown as solid lines with insignificant ones shown as dashed lines.],
  ) <fig-pdp-change-continuous>
]
The analysis did reveal some significant predictors of bryophyte and plant species richness change with the Land-use class (LU\_4) once again being important for both groups (@fig-imp-change-combined). However this time the most important predictor was the Soil organic carbon stock (SOC) for bryophytes and the baseline temperature of the coldest quarter (BIO11) for vascular plants. The partial dependence plots for the significant continuous predictors of bryophyte and plant species richness change reveal a faster change rate in places with lower Soil organic carbon content (SOC) for bryophytes, with a similar trend for vascular plants despite not being significant (@fig-pdp-change-continuous). Also for bryophytes the change rate is higher in steeper slopes with plants showing an opposite trend and not being significant. Furthermore the change rate was higher for vascular plants with a lower baseline temperature in the coldest quarter (BIO11) and the warmest quarter (BIO10). For categorical predictors, only the land use class (LU\_4) and the mowing intensity factor were significant predictors of species richness change with the land use class being significant in both whilst the mowing intensity only being significant for vascular plants revealing a faster change rate with increasing mowing intensity (@fig-pdp-change-factor).

#figure(
  placement: auto,
  scope: "column",
  image("_figures/combined_change_factor_pdp.png", width: 100%),
  caption: [Partial dependence for factorial species richness change predictors. Insignificant (p\<0.05) ones are shown as diagonal hatching. Dependencies have been mean centered. LU 4 code 1 is urban, 2 is agricultural, 3 is forest and 4 is unproductive.],
) <fig-pdp-change-factor>
= Discussion
<discussion>
A wide variety of environmental predictors are needed to capture the huge complexity of ecological systems and accurately model the species richness and the changes within them. I found reoccurring patterns that govern the distribution of species richness for both bryophytes and plant species. Bryophytes were more predictable than vascular plants with a higher explained variance achieved. The two groups followed opposite patterns in regards to vegetation height, mowing intensity, land cover as well as soil pH, whilst having similar response curves to climate. Predicting the species richness change was not as successful as only a small portion of variance could be explained. It was able to find some significant predictors of change which indicate that faster changes are happening in regions with lower temperatures. But the overall predictive performance was very low and thus the environmental variables that have been found and thus deemed as responsible for the change in species richness must be interpreted with caution.

== Models of species richness
<models-of-species-richness-1>
==== Model Performance and predictive power
<model-performance-and-predictive-power>
It is difficult to compare species richness model performances across studies, even to ones using BDM data, due to the data selection processes done. Prior studies often have focused only on subsets of the BDM Z9 plots instead of the entire dataset like I have done and have used different environmental predictor data. Zellweger et al. (#link(<ref-zellwegerDisentanglingEffectsClimate2015>)[2015]) used 410 plots situated in forest regions surveyed between 2004-2008 and have achieved average Cross-validation accuracies of 16.8% for plant species and 24% for bryophyte species. Vigués Jorba et al. (#link(<ref-viguesjorbaDifferentialResponsesTaxonomic2025a>)[2025]) have also used plots in forested areas and have looked at the survey period between 2017-2021. With their 290 plots selected their models achieved accuracies of 17% for plant species and 41% for bryophytes. Steinmann et al. (#link(<ref-steinmannModellingPlantSpecies2009>)[2009]) have not used subsets but were for unclear reasons not able to study an entire sampling period and thus only had 421 plots available for modelling. They have achieved and explained variance across all plant species of 28%. Other studies not using BDM data but also doing nationwide richness models have achieved plant richness accuracies of 40-65% in grassland vegetation and 44-47% in forests within Czechia Divíšek & Chytrý (#link(<ref-divisekHighresolutionLargeextentMapping2018>)[2018]) whilst Ellerbrok et al. (#link(<ref-ellerbrokDeterminantsTerrestrialLimnic2026>)[2026]) were able to explain 55.6% of the variance for the entirety of Germany using larger sampling plots. My analysis achieved an explained variance of 36% for vascular plants and 47% for bryophytes, which is consistent with these before mentioned results and does not appear to be an outlier. I assume the slight increase in accuracy compared to other studies using BDM data comes from three factors. First I was not as strict in the variable selection process as others, Random Forest can handle collinearity but strictly reducing collinear predictors leads to fewer predictors and thus less information for the model to learn from. Second I have used more recent ecological relevant data such as the soil maps, and grassland use intensity maps. And third, I have used the entire dataset instead of carefully selected BDM plots like others have done which might have led to better model performance. The created vascular plant spatial extrapolation maps match well with the one created by Steinmann et al. (#link(<ref-steinmannModellingPlantSpecies2009>)[2009]) which also shows patches of high species richness in the Jura and pre-alpine region and low species richness in the southern alps as well as the central plateau. It does differ however to Wohlgemuth et al. (#link(<ref-wohlgemuthModellingVascularPlant2008>)[2008]) whose spatial extrapolation using the coarser BDM samples in 1 km resolution shows patches of high species richness even in the southern alps and misses the high species richness patches in the Jura. This difference, as I assume, mainly comes from the different indicator sampling design. It is to be noted that my extrapolation does not take into account the scale of the sampling plots and the spatial extrapolation to larger grain sizes. The extrapolation maps have not been adjusted and so they should be interpreted only as qualitative and not quantitative.

==== Environmental implications
<environmental-implications>
Predictors that were found to be important for both bryophytes and vascular plants were the land use class (LU\_4), the mean temperature of the warmest quarter (BIO10), the mean temperature of the coldest quarter (BIO11), the slope, the mowing intensity and the vegetation height. With their response not following unimodal linear, hump or bell curves indicating that the response can be more complex \(#link(<ref-oksanenContinuumTheoryRevisited2002>)[Oksanen & Minchin, 2002]). The land use class was the most important predictor for both groups. Together with mowing intensity it underlines the impact of human land use in shaping species richness patterns as established by others \(#link(<ref-ellerbrokDeterminantsTerrestrialLimnic2026>)[Ellerbrok et al., 2026]\; #link(<ref-newboldGlobalEffectsLand2015>)[Newbold et al., 2015]). Bioclimatic variables were also found as significant and important predictors reflecting the fundamental role that climate plays in shaping species distribution \(#link(<ref-currieEnergyLargeScalePatterns1991>)[Currie, 1991]\; #link(<ref-hawkinsENERGYWATERBROADSCALE2003>)[Hawkins et al., 2003]). The positive relationship found between slope and species richness for both groups are in line with the findings from Zellweger et al. (#link(<ref-zellwegerDisentanglingEffectsClimate2015>)[2015]) which indicates that steeper areas are less affected by humans and provide more microhabitats. The negative relationship between vascular plant richness with the vegetation height and the pH value line up with the findings of Vigués Jorba et al. (#link(<ref-viguesjorbaDifferentialResponsesTaxonomic2025a>)[2025]), Dembicz et al. (#link(<ref-dembiczDriversPlantDiversity2021>)[2021]) and Zellweger et al. (#link(<ref-zellwegerDisentanglingEffectsClimate2015>)[2015]). It indicates that largely untouched and long standing forest regions with high vegetation height let less light through to the forest floor and thus have lower species richness. This is shown by Vigués Jorba et al. (#link(<ref-viguesjorbaDifferentialResponsesTaxonomic2025a>)[2025]) who have used canopy transmissivity as a variable in their modelling approach. For bryophytes the opposite was found with a positive relationship with vegetation height and a negative relationship with pH. Showing that for bryophytes the presence of a canopy cover is beneficial for species richness because it provides shade and thus water buffers.

== Models of species richness change
<models-of-species-richness-change-1>
Directly Comparing the results of the species richness change models to prior studies is not possible due to the lack of studies that have used the same dataset and approach. Amongst a few significant predictors I have found that the baseline Bioclimatic variables 10 and 11 were amongst the most important predictors of plant richness changes which is consistent with the cross-sectional richness models. The partial dependancy plot for them show a stronger change in species richness for plots with colder baseline temperatures which could be an indication of climatic changes and the effect on the elevation distribution with species moving from warmer to colder regions Freeman et al. (#link(<ref-freemanExpandingShiftingShrinking2018a>)[2018]). This is supported by Häberlin & Dengler (#link(<ref-haberlinRecentBiodiversityChanges2025e>)[2025]) which have reported an increase in the mean in ecological indicator values for temperature whilst a thermophilisation of communities have been reported by Kiebacher et al. (#link(<ref-kiebacherThermophilisationCommunitiesDiffers2023c>)[2023]) both indicating that climatic changes, which are present in Switzerland \(#link(<ref-meteoschweiz2025klimareport2024>)[MeteoSchweiz, 2025]), do affect the communities. Because of these prior findings I would have expected to find the directly modelled bioclimatic changes to be amongst the significant predictors of richness change. I assume that my approach is the main reason this is not the case. Thus the results of the richness change models should be interpreted with caution and it is difficult to draw exact conclusions about which environmental variables are responsible for the observed changes.

== Methodological limitations
<methodological-limitations>
Several methodological limitations should be considered when interpreting the results of this Bachelor thesis analysis. The first being that the standard cross-validation approach used to assess hyperparameter performance is not accounting for spatial autocorrelation in the data \(#link(<ref-robertsCrossvalidationStrategiesData2017>)[Roberts et al., 2017]). Thus the splits are not independent which can lead to overoptimistic estimates of model performance for the hyperparameters and thus the best ones are not identifiable. For this reason Koldasbayeva & Zaytsev (#link(<ref-koldasbayevaFoundationUnbiasedCrossvalidation2025>)[2025]) have advised to use spatial blocking methods in Cross-validation. However due to the small size of the dataset, the rather small spatial scale and the sampling using a regular spaced grid the implementation of such a spatial blocking was not pursued. As already mentionend was I able to achieve better accuracy for the static richness models by including even some co-linear variables. My variable selection process was guided by reasoning and information from previous studies to reduce the dataset from 68 to 20 predictors. This is less strict than the correlation-threshold approaches used by Zellweger et al. (#link(<ref-zellwegerDisentanglingEffectsClimate2015>)[2015]) and Dembicz et al. (#link(<ref-dembiczDriversPlantDiversity2021>)[2021]) who looked at the correlation matrix and from highly correlated predictors picked the ones they deemed more relevant. Ellerbrok et al. (#link(<ref-ellerbrokDeterminantsTerrestrialLimnic2026>)[2026]) have used a fully automated selection procedure which might even is more strict and less biased than the correlation threshold. But even if I had strictly removed co-linear predictors with some threshold, some correlations still remain. Exampled in the case of slope and land use intensity, which are correlated but not as strongly as the correlation threshold would have picked up, Roth et al. (#link(<ref-rothSpeciesTurnoverReveals2019>)[2019]) have even used slope as a proxy for land use intensity since steeper terrain is assumed to be less accessible to machinery and therefore less intensively managed. Other correlations which are more obvious but still are below a threshols like the vegetation height, LU\_4, and mowing intensity all capture overlapping aspects of land-use intensity, as agricultural land is typically more intensively managed than forested land, which is reflected simultaneously in the mowing intensity values, the vegetation height and the land use classes. Because some predictors are thus correlated with one another, be it above a chosen threshold or below it, the permutation importance scores could be misleading and the importance of predictors must be looked at with care since predictors could be masked by other correlated predictors. I still kept these colinear predictors in the model since they improved the predictive accuracy of the models and Random Forest can handle colinear features. It is essentially a trade off between explainability and predictive accuracy and I have stuck more on the side of the predictive accuracy.

== Data Limitations and uncertainty
<data-limitations-and-uncertainty>
Several sources of uncertainty stem from the data themselves and my handling of them. The permutation importance function used did not account for missing values and thus the missing values in the predictors had to be imputed. The soil variables from the KoBo dataset had incomplete national coverage, requiring nearest-neighbour gap-filling for roughly a fifth of the plots. While I assumed this would be preferable to mean imputation, the imputed values do not reflect true measured conditions at those locations and introduce a degree of noise into the soil predictors. Similarly, setting vegetation height and mowing intensity #NormalTok("NaN"); values to zero is a pragmatic assumption that does not hold in all cases, for example in grassland regions where vegetation height varies seasonally and certainly is not truly 0 m.

The extracted mowing intensity per plot is also a rather noisy since the map is a modelled product at 10 m resolution pixels, but mowing decisions are, as I assume, made at the parcel level. The map has quite some fluctuations within parcels and a single raster pixel can therefore not reliably represent whether a specific 10 $m^2$ BDM plot was actually mowed. The land-use classification from the Arealstatistik is also a rather coarse set of data with its 100 m resolution relative to the 10 $m^2$ plot size. Visual inspection in QGIS lets one see that plots are certainly located in urban areas but are not sealed surfaces. For this problem, the habitat map provided a more detailed alternative with its vector polygons but introductes many more factors and co-linearities to the model.

Finally, the cross-sectional richness model relies entirely on static predictors representing snapshots in time, yet even for this dataset I use data from around the year 2021 and try to explain the variance in the entire survey period of 2021 to 2025. This problem is even worse in the change dataset as I use highly dynamic predictors such as the vegetation height and mowing intensity from 2021 to explain the change in species richness from 2001 to 2020. Being rather strict with variable selection and removing predictors that are highly dynamic over time could thus improve the explainability of the change models.

= Conclusion
<conclusion>
Species richness is a complex ecological process and thus a wide variety of environmental predictors are needed to accurately predict and explain the variance in species richness. The use of Random Forests allowed me to include a large number of predictors and thus better capture the complexity of the system. Explainability of the models was achieved through the use of permutation importance and partial dependence plots which reveal the most important predictors and their response curves. The created species richness models are able to explain a great deal of variance and many reoccurring patterns from prior studies, either using the BDM data or different datasets, are present. The response curves for the most important predictors are in line with prior studies and thus confirm the validity of my approach and underline that the response is not always linear or hump-shaped but can also be more complex which random forests are able to capture. The created species richness maps reveal clear spatial patterns with the highest species richness for both groups located in alpine or pre-alpine landscapes which offer more microhabitats and are less affected by humans. The lowest species richness is present in the central plateau which is a rather homogenous landscape with high human land usage through agriculture and urbanization. The estimated model error maps reveal an overall evenly distributed uncertainty across the country with some higher uncertainty in local patches in the Jura region and in between the central plateau and alpine regions. The species richness change models are not able to explain a large portion of the variance in species richness change and thus the found significant predictors of change must be interpreted with caution. It does indicate that more changes are happening in plots situated in pre-alpine to alpine regions with lower baseline temperatures which could be an indication of climatic changes and the effect on the elevation distribution with species moving from warmer to colder regions.

Future work could focus on improving the models by using more high resolution environmental data to better capture the microhabitats and thus improve the predictive performance of the models. Exchanging the higher resolution elevation models with the available 2m resolution models might be used to capture the per plot topography and thus the microhabitats better \(#link(<ref-camathiasHighresolutionRemoteSensing2013>)[Camathias et al., 2013]). For vegetation structure variables, other studies already used the available high resolution LiDar datasets in Switzerland and proved that it is possible to derive more accurate vegetation structure variables through the use of such data rather than the coarse stereo-photogrammetry-based model used here \(#link(<ref-viguesjorbaDifferentialResponsesTaxonomic2025a>)[Vigués Jorba et al., 2025]\; #link(<ref-zellwegerEnvironmentalPredictorsSpecies2016>)[Zellweger et al., 2016]). The habitat map, as it is used now, is most likely not yielding a lot of additional information as it is made up of many different habitat classes which are highly correlated with other predictors. It could be used however to create a sealed surface predictor which could account for the sealed surfaces in the landscape. Furthermore, the bioclimatic variables were derived at 1 km resolution, which does not capture the fine-scale microclimatic variation that is relevant at the plot level. Vigués Jorba et al. (#link(<ref-viguesjorbaDifferentialResponsesTaxonomic2025a>)[2025]) have used high resolution microclimatic data from Zellweger et al. (#link(<ref-zellwegerMicroclimateMappingUsing2024>)[2024]) and have shown that modelled microclimate maps can be used for such a modelling task. A closer look at the variable selection process is also needed to reduce the biases introduced through some assumptions made, especially regarding the vegetation height and mowing intensity predictors which are highly dynamic over time and are here assumed to be static. Furthermore the handling with cross-validation could be improved by using spatial blocking methods to account for the spatial autocorrelation \(#link(<ref-robertsCrossvalidationStrategiesData2017>)[Roberts et al., 2017]) and the permutation importance scores could be improved by using conditional permutation importance to account for collinearity between predictors \(#link(<ref-stroblConditionalVariableImportance2008>)[Strobl et al., 2008]). The extrapolation maps also need adjustments if a quantitative interpretation is desired as the scale of the sampling plots was not taken into account and thus the extrapolation to larger grain sizes has not been adjusted \(#link(<ref-steinmannNichesNoiseDisentangling2011>)[Steinmann et al., 2011]). A better approach for the target variable definition is also needed to better capture the change in species richness over time by adjusting for high and low initial species richness and thus better capture the change in species richness over time. This could be done by using a panel dataset and modelling the change in species richness with mixed effects random forests which could filter out plots with high variability and adjust for these different baselines, thus better capturing the effects of climatic changes.

= References
<references>
#block[
#block[
Austin, M. P. (2002). Spatial prediction of species distribution: An interface between ecological theory and statistical modelling. #emph[Ecological Modelling], #emph[157]\(2-3), 101--118. #link("https://doi.org/10.1016/S0304-3800(02)00205-3")

] <ref-austinSpatialPredictionSpecies2002>
#block[
BDM Coordination Office. (2014). #emph[Swiss Biodiversity Monitoring BDM. Description of Methods and Indicators.] (No. 1410; pp. 103 pp). Federal Office for the Environment.

] <ref-bdmcoordinationofficeSwissBiodiversityMonitoring2014a>
#block[
BFS GEOSTAT. (1985). #emph[Arealstatistik]. https:\/\/www.bfs.admin.ch.

] <ref-bfs_geostat_1979_85_arealstatistik>
#block[
Booth, T. H. (2022). Checking bioclimatic variables that combine temperature and precipitation data before their use in species distribution models. #emph[Austral Ecology], #emph[47]\(7), 1506--1514. #link("https://doi.org/10.1111/aec.13234")

] <ref-boothCheckingBioclimaticVariables2022>
#block[
Camathias, L., Bergamini, A., Küchler, M., Stofer, S., & Baltensweiler, A. (2013). High-resolution remote sensing data improves models of species richness. #emph[Applied Vegetation Science], #emph[16]\(4), 539--551. #link("https://doi.org/10.1111/avsc.12028")

] <ref-camathiasHighresolutionRemoteSensing2013>
#block[
Cardinale, B. J., Duffy, J. E., Gonzalez, A., Hooper, D. U., Perrings, C., Venail, P., Narwani, A., Mace, G. M., Tilman, D., Wardle, D. A., Kinzig, A. P., Daily, G. C., Loreau, M., Grace, J. B., Larigauderie, A., Srivastava, D. S., & Naeem, S. (2012). Biodiversity loss and its impact on humanity. #emph[Nature], #emph[486]\(7401), 59--67. #link("https://doi.org/10.1038/nature11148")

] <ref-cardinaleBiodiversityLossIts2012b>
#block[
Currie, D. J. (1991). Energy and Large-Scale Patterns of Animal- and Plant-Species Richness. #emph[The American Naturalist], #emph[137]\(1), 27--49. #link("https://doi.org/10.1086/285144")

] <ref-currieEnergyLargeScalePatterns1991>
#block[
Delarze, R., Gonseth, Y., Eggenberg, S., Vust, M., & Delarze, R. (2015). #emph[Lebensräume der Schweiz: Ökologie - Gefährdung - Kennarten] (3., vollständig überarbeitete Auflage). Ott der Sachbuchverlag.

] <ref-delarzeLebensraeumeSchweizOekologie2015>
#block[
Dembicz, I., Velev, N., Boch, S., Janišová, M., Palpurina, S., Pedashenko, H., Vassilev, K., & Dengler, J. (2021). Drivers of plant diversity in Bulgarian dry grasslands vary across spatial scales and functional-taxonomic groups. #emph[Journal of Vegetation Science], #emph[32]\(1), e12935. #link("https://doi.org/10.1111/jvs.12935")

] <ref-dembiczDriversPlantDiversity2021>
#block[
Divíšek, J., & Chytrý, M. (2018). High-resolution and large-extent mapping of plant species richness using vegetation-plot databases. #emph[Ecological Indicators], #emph[89], 840--851. #link("https://doi.org/10.1016/j.ecolind.2017.11.005")

] <ref-divisekHighresolutionLargeextentMapping2018>
#block[
Ellerbrok, J. S., Sporbert, M., Schreiner, V., Ristok, C., Farwig, N., Hähn, G. J. A., Klenke, R., Seidler, G., Marx, J. M., Schmidt, A., Settele, J., Wirth, C., Albert, C., Bässler, C., Braunisch, V., Brunken, H., Conze, K.-J., Eichenberg, D., Eisenhauer, N., … Bruelheide, H. (2026). Determinants of Terrestrial and Limnic Species Richness in Germany. #emph[Diversity and Distributions], #emph[32]\(3), e70170. #link("https://doi.org/10.1111/ddi.70170")

] <ref-ellerbrokDeterminantsTerrestrialLimnic2026>
#block[
Federal Office of Meteorology and Climatology MeteoSwiss. (n.d). #emph[The climate of Switzerland - MeteoSwiss]. https:\/\/www.meteoswiss.admin.ch/climate/the-climate-of-switzerland.html.

] <ref-federalofficeofmeteorologyandclimatologymeteoswissClimateSwitzerlandMeteoSwissn.d>
#block[
Ferrier, S. (2002). Mapping Spatial Pattern in Biodiversity for Regional Conservation Planning: Where to from Here? #emph[Systematic Biology], #emph[51]\(2), 331--363. #link("https://doi.org/10.1080/10635150252899806")

] <ref-ferrierMappingSpatialPattern2002>
#block[
Ferrier, S., & Guisan, A. (2006). Spatial modelling of biodiversity at the community level. #emph[Journal of Applied Ecology], #emph[43]\(3), 393--404. #link("https://doi.org/10.1111/j.1365-2664.2006.01149.x")

] <ref-ferrierSpatialModellingBiodiversity2006>
#block[
Fox, J. (2025). #emph[Polycor: Polychoric and polyserial correlations] \[Manual\].

] <ref-foxPolycorPolychoricPolyserial2025>
#block[
Freeman, B. G., Lee-Yaw, J. A., Sunday, J. M., & Hargreaves, A. L. (2018). Expanding, shifting and shrinking: The impact of global warming on species' elevational distributions. #emph[Global Ecology and Biogeography], #emph[27]\(11), 1268--1276. #link("https://doi.org/10.1111/geb.12774")

] <ref-freemanExpandingShiftingShrinking2018a>
#block[
Ginzler, C. (2021). #emph[Vegetation height model NFI]. National Forest Inventory (NFI). #link("https://doi.org/10.16904/1000001.1")

] <ref-ginzler2021vegetationheightmodelnfi>
#block[
Goebes, P., Schmidt, K., Seitz, S., Both, S., Bruelheide, H., Erfmeier, A., Scholten, T., & Kühn, P. (2019). The strength of soil-plant interactions under forest is related to a Critical Soil Depth. #emph[Scientific Reports], #emph[9]\(1), 8635. #link("https://doi.org/10.1038/s41598-019-45156-5")

] <ref-goebesStrengthSoilplantInteractions2019>
#block[
Greenwell, B. M. (2017). Pdp: An R package for constructing partial dependence plots. #emph[The R Journal], #emph[9]\(1), 421--436. #link("https://doi.org/10.32614/RJ-2017-016")

] <ref-greenwellPdpPackageConstructing2017>
#block[
Häberlin, K. E. R., & Dengler, J. (2025). Recent biodiversity changes in grasslands across elevational bands in Switzerland. #emph[Basic and Applied Ecology], #emph[87], 29--37. #link("https://doi.org/10.1016/j.baae.2025.05.003")

] <ref-haberlinRecentBiodiversityChanges2025e>
#block[
Hawkins, B. A., Field, R., Cornell, H. V., Currie, D. J., Guégan, J.-F., Kaufman, D. M., Kerr, J. T., Mittelbach, G. G., Oberdorff, T., O'Brien, E. M., Porter, E. E., & Turner, J. R. G. (2003). Energy, water and broad-scale geographic patterns of species richness. #emph[Ecology], #emph[84]\(12), 3105--3117. #link("https://doi.org/10.1890/03-8006")

] <ref-hawkinsENERGYWATERBROADSCALE2003>
#block[
Hijmans, R. J., Brown, A., & Barbosa, M. (2026). #emph[Terra: Spatial data analysis] \[Manual\].

] <ref-hijmansTerraSpatialData2026>
#block[
Hijmans, R. J., Phillips, S., Leathwick, J., & Elith, J. (2024). #emph[Dismo: Species distribution modeling] \[Manual\].

] <ref-hijmansDismoSpeciesDistribution2024>
#block[
Kiebacher, T., Meier, M., Kipfer, T., & Roth, T. (2023). Thermophilisation of communities differs between land plant lineages, land use types and elevation. #emph[Scientific Reports], #emph[13]\(1), 11395. #link("https://doi.org/10.1038/s41598-023-38195-6")

] <ref-kiebacherThermophilisationCommunitiesDiffers2023c>
#block[
Koldasbayeva, D., & Zaytsev, A. (2025). Foundation for unbiased cross-validation of spatio-temporal models for Species Distribution Modeling. #emph[Ecological Informatics], #emph[92], 103521. #link("https://doi.org/10.1016/j.ecoinf.2025.103521")

] <ref-koldasbayevaFoundationUnbiasedCrossvalidation2025>
#block[
Kompetenzzentrum Boden (KOBO). (2026). #emph[Bodeninformationen National: Hinweiskarten für Bodeneigenschaften]. https:\/\/ccsols.ch/de/boeden-kartieren/kartenerstellung/hinweiskarten-fuer-bodeneigenschaften.

] <ref-kobo_bodenportal>
#block[
Krebs, C. J. (2014). #emph[Ecology: The experimental analysis of distribution and abundance] (6. ed., Pearson new international ed.). Pearson.

] <ref-krebsEcologyExperimentalAnalysis2014b>
#block[
Kuhn, M. (2008). Building predictive models in R using the caret package. #emph[Journal of Statistical Software], #emph[28]\(5), 1--26. #link("https://doi.org/10.18637/jss.v028.i05")

] <ref-kuhnBuildingPredictiveModels2008a>
#block[
Lindsay, J. B. (2016). Whitebox GAT: A case study in geomorphometric analysis. #emph[Computers & Geosciences], #emph[95], 75--84. #link("https://doi.org/10.1016/j.cageo.2016.07.003")

] <ref-lindsayWhiteboxGATCase2016>
#block[
MeteoSchweiz. (2025). #emph[Klimareport 2024] \[Report\]. Bundesamt für Meteorologie und Klimatologie MeteoSchweiz.

] <ref-meteoschweiz2025klimareport2024>
#block[
Newbold, T., Hudson, L. N., Hill, S. L. L., Contu, S., Lysenko, I., Senior, R. A., Börger, L., Bennett, D. J., Choimes, A., Collen, B., Day, J., De Palma, A., Díaz, S., Echeverria-Londoño, S., Edgar, M. J., Feldman, A., Garon, M., Harrison, M. L. K., Alhusseini, T., … Purvis, A. (2015). Global effects of land use on local terrestrial biodiversity. #emph[Nature], #emph[520]\(7545), 45--50. #link("https://doi.org/10.1038/nature14324")

] <ref-newboldGlobalEffectsLand2015>
#block[
Oksanen, J., & Minchin, P. R. (2002). Continuum theory revisited: What shape are species responses along ecological gradients? #emph[Ecological Modelling], #emph[157]\(2-3), 119--129. #link("https://doi.org/10.1016/S0304-3800(02)00190-4")

] <ref-oksanenContinuumTheoryRevisited2002>
#block[
Pebesma, E. (2018). Simple features for R: Standardized support for spatial vector data. #emph[The R Journal], #emph[10]\(1), 439--446. #link("https://doi.org/10.32614/RJ-2018-009")

] <ref-pebesmaSimpleFeaturesStandardized2018a>
#block[
Pecl, G. T., Araújo, M. B., Bell, J. D., Blanchard, J., Bonebrake, T. C., Chen, I.-C., Clark, T. D., Colwell, R. K., Danielsen, F., Evengård, B., Falconi, L., Ferrier, S., Frusher, S., Garcia, R. A., Griffis, R. B., Hobday, A. J., Janion-Scheepers, C., Jarzyna, M. A., Jennings, S., … Williams, S. E. (2017). Biodiversity redistribution under climate change: Impacts on ecosystems and human well-being. #emph[Science], #emph[355]\(6332), eaai9214. #link("https://doi.org/10.1126/science.aai9214")

] <ref-peclBiodiversityRedistributionClimate2017a>
#block[
Price, B., Kolecka, N., Ginzler, C., Rüetschi, M., Allemann, R., Bubula, E., & Joseph, C. (2025). #emph[The habitat map of switzerland V1\_2 2025]. EnviDat. https:\/\/doi.org/#link("http://dx.doi.org/10.16904/envidat.723")

] <ref-the-habitat-map-of-switzerland-v1_2-2025>
#block[
R Core Team. (2026). #emph[R: A language and environment for statistical computing] \[Manual\]. R Foundation for Statistical Computing.

] <ref-rcoreteamLanguageEnvironmentStatistical2026>
#block[
Roberts, D. R., Bahn, V., Ciuti, S., Boyce, M. S., Elith, J., Guillera-Arroita, G., Hauenstein, S., Lahoz-Monfort, J. J., Schröder, B., Thuiller, W., Warton, D. I., Wintle, B. A., Hartig, F., & Dormann, C. F. (2017). Cross-validation strategies for data with temporal, spatial, hierarchical, or phylogenetic structure. #emph[Ecography], #emph[40]\(8), 913--929. #link("https://doi.org/10.1111/ecog.02881")

] <ref-robertsCrossvalidationStrategiesData2017>
#block[
Roth, T., Kohli, L., Bühler, C., Rihm, B., Meuli, R. G., Meier, R., & Amrhein, V. (2019). Species turnover reveals hidden effects of decreasing nitrogen deposition in mountain hay meadows. #emph[PeerJ], #emph[7], e6347. #link("https://doi.org/10.7717/peerj.6347")

] <ref-rothSpeciesTurnoverReveals2019>
#block[
#emph[Startseite - MeteoSchweiz]. (n.d.). https:\/\/www.meteoschweiz.admin.ch/.

] <ref-StartseiteMeteoSchweiz>
#block[
Stein, A., Gerstner, K., & Kreft, H. (2014). Environmental heterogeneity as a universal driver of species richness across taxa, biomes and spatial scales. #emph[Ecology Letters], #emph[17]\(7), 866--880. #link("https://doi.org/10.1111/ele.12277")

] <ref-steinEnvironmentalHeterogeneityUniversal2014>
#block[
Steinmann, K., Eggenberg, S., Wohlgemuth, T., Linder, H. P., & Zimmermann, N. E. (2011). Niches and noise---Disentangling habitat diversity and area effect on species diversity. #emph[Ecological Complexity], #emph[8]\(4), 313--319. #link("https://doi.org/10.1016/j.ecocom.2011.06.004")

] <ref-steinmannNichesNoiseDisentangling2011>
#block[
Steinmann, K., Linder, H. P., & Zimmermann, N. E. (2009). Modelling plant species richness using functional groups. #emph[Ecological Modelling], #emph[220]\(7), 962--967. #link("https://doi.org/10.1016/j.ecolmodel.2009.01.006")

] <ref-steinmannModellingPlantSpecies2009>
#block[
Strobl, C., Boulesteix, A.-L., Kneib, T., Augustin, T., & Zeileis, A. (2008). Conditional variable importance for random forests. #emph[BMC Bioinformatics], #emph[9]\(1), 307. #link("https://doi.org/10.1186/1471-2105-9-307")

] <ref-stroblConditionalVariableImportance2008>
#block[
Stumpf, F., Keller, A., Schmidt, K., Mayr, A., Gubler, A., & Schaepman, M. (2018). Spatio-temporal land use dynamics and soil organic carbon in Swiss agroecosystems. #emph[Agriculture, Ecosystems & Environment], #emph[258], 129--142. #link("https://doi.org/10.1016/j.agee.2018.02.012")

] <ref-stumpfSpatiotemporalLandUse2018>
#block[
swisstopo. (2010). #emph[DHM25 -- the digital height model of switzerland]. http:\/\/www.swisstopo.admin.ch.

] <ref-swisstopo2010dhm25>
#block[
Vigués Jorba, J., Scherrer, D., Duchenne, F., Zellweger, F., Gossner, M. M., & Bollmann, K. (2025). Differential responses of taxonomic, functional and phylogenetic multi-taxa diversity to environmental factors in temperate forest ecosystems. #emph[Ecological Indicators], #emph[178], 113855. #link("https://doi.org/10.1016/j.ecolind.2025.113855")

] <ref-viguesjorbaDifferentialResponsesTaxonomic2025a>
#block[
Wager, S., Hastie, T., & Efron, B. (2014). #emph[Confidence Intervals for Random Forests: The Jackknife and the Infinitesimal Jackknife] (arXiv:1311.4555). arXiv. #link("https://doi.org/10.48550/arXiv.1311.4555")

] <ref-wagerConfidenceIntervalsRandom2014>
#block[
Weber, D., Hintermann, U., & Zangger, A. (2004). Scale and trends in species richness: Considerations for monitoring biological diversity for political purposes. #emph[Global Ecology and Biogeography], #emph[13]\(2), 97--104. #link("https://doi.org/10.1111/j.1466-882X.2004.00078.x")

] <ref-weberScaleTrendsSpecies2004>
#block[
Weber, D., Schwieder, M., Ritter, L., Koch, T., Psomas, A., Huber, N., Ginzler, C., & Boch, S. (2023). #emph[Grassland-use intensity maps for Switzerland]. EnviDat. https:\/\/doi.org/#link("http://dx.doi.org/10.16904/envidat.428")

] <ref-grassland-use-intensity-maps-for-switzerland-2023>
#block[
Wohlgemuth, T., Nobis, M. P., Kienast, F., & Plattner, M. (2008). Modelling vascular plant diversity at the landscape scale using systematic samples. #emph[Journal of Biogeography], #emph[35]\(7), 1226--1240. #link("https://doi.org/10.1111/j.1365-2699.2008.01884.x")

] <ref-wohlgemuthModellingVascularPlant2008>
#block[
Wright, M. N., & Ziegler, A. (2017). Ranger: A fast implementation of random forests for high dimensional data in C++ and R. #emph[Journal of Statistical Software], #emph[77]\(1), 1--17. #link("https://doi.org/10.18637/jss.v077.i01")

] <ref-wrightRangerFastImplementation2017>
#block[
Zellweger, F., Baltensweiler, A., Ginzler, C., Roth, T., Braunisch, V., Bugmann, H., & Bollmann, K. (2016). Environmental predictors of species richness in forest landscapes: Abiotic factors versus vegetation structure. #emph[Journal of Biogeography], #emph[43]\(6), 1080--1090. #link("https://doi.org/10.1111/jbi.12696")

] <ref-zellwegerEnvironmentalPredictorsSpecies2016>
#block[
Zellweger, F., Braunisch, V., Morsdorf, F., Baltensweiler, A., Abegg, M., Roth, T., Bugmann, H., & Bollmann, K. (2015). Disentangling the effects of climate, topography, soil and vegetation on stand-scale species richness in temperate forests. #emph[Forest Ecology and Management], #emph[349], 36--44. #link("https://doi.org/10.1016/j.foreco.2015.04.008")

] <ref-zellwegerDisentanglingEffectsClimate2015>
#block[
Zellweger, F., Sulmoni, E., Malle, J. T., Baltensweiler, A., Jonas, T., Zimmermann, N. E., Ginzler, C., Karger, D. N., De Frenne, P., Frey, D., & Webster, C. (2024). Microclimate mapping using novel radiative transfer modelling. #emph[Biogeosciences], #emph[21]\(2), 605--623. #link("https://doi.org/10.5194/bg-21-605-2024")

] <ref-zellwegerMicroclimateMappingUsing2024>
] <refs>
#pagebreak(weak: true)
#appendix-mode.update(true)
#counter(heading).update(0)
#set page(columns: 1)
= Appendix
<appendix>
== Correlation Matrices
<correlation-matrices>
#figure([
#box(image("_figures/appendix/corr_mixed_full.png", width: 75.0%))
], caption: figure.caption(
position: bottom, 
[
Mixed correlation matrix (Pearson / Polyserial / Polychoric) for all environmental predictors before variable selection.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-corr-mixed-full>


#figure([
#box(image("_figures/appendix/corr_pearson_full.png", width: 75.0%))
], caption: figure.caption(
position: bottom, 
[
Pearson correlation matrix for numeric predictors before variable selection.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-corr-pearson-full>


#figure([
#box(image("_figures/appendix/corr_mixed_final.png", width: 75.0%))
], caption: figure.caption(
position: bottom, 
[
Mixed correlation matrix (Pearson / Polyserial / Polychoric) for the final 20 selected predictors.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-corr-mixed-final>


#figure([
#box(image("_figures/appendix/corr_pearson_final.png", width: 75.0%))
], caption: figure.caption(
position: bottom, 
[
Pearson correlation matrix for the numeric subset of the final 20 selected predictors.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-corr-pearson-final>


== Model Stability
<model-stability>
#figure([
#box(image("_figures/appendix/rf_moss_cv_tree_metrics.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
Number of trees vs.~mean cross-validation metrics for the bryophyte richness model showing MAE, RMSE, and R² as a function of the number of trees. Based on this analysis, 500 trees were chosen for all models.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-ntrees-stability>


== Prediction maps
<prediction-maps>
#figure([
#box(image("_figures/appendix/prediction_moss_100m_viridis_legend.png", width: 140.0%))
], caption: figure.caption(
position: bottom, 
[
Prediction maps for bryophytes richness at 100 m resolution.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-prediction-maps-bryophyte>


#figure([
#box(image("_figures/appendix/prediction_plant_100m_viridis_legend.png", width: 140.0%))
], caption: figure.caption(
position: bottom, 
[
Prediction maps for vascular plant richness at 100 m resolution.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-prediction-maps-plant>


#figure([
#box(image("_figures/appendix/prediction_moss_se_100m_legend.png", width: 140.0%))
], caption: figure.caption(
position: bottom, 
[
Prediction estimated model error maps for bryophytes richness at 100 m resolution.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-prediction-maps-bryophyte-se>


#figure([
#box(image("_figures/appendix/prediction_plant_se_100m_legend.png", width: 140.0%))
], caption: figure.caption(
position: bottom, 
[
Prediction estimated model error maps for vascular plant richness at 100 m resolution.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-prediction-maps-plant-se>





