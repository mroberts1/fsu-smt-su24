// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text( size: 0.92em )
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = [
  #line(start: (25%,0%), end: (75%,0%))
]

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

#show raw.where(block: true): block.with(
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
    fields.below = fields.below.amount
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == "string" {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == "content" {
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

#show figure: it => {
  if type(it.kind) != "string" {
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
    new_title_block +
    old_callout.body.children.at(1))
}

#show ref: it => locate(loc => {
  let suppl = it.at("supplement", default: none)
  if suppl == none or suppl == auto {
    it
    return
  }

  let sup = it.supplement.text.matches(regex("^45127368-afa1-446a-820f-fc64c546b2c5%(.*)")).at(0, default: none)
  if sup != none {
    let target = query(it.target, loc).first()
    let parent_id = sup.captures.first()
    let parent_figure = query(label(parent_id), loc).first()
    let parent_location = parent_figure.location()

    let counters = numbering(
      parent_figure.at("numbering"), 
      ..parent_figure.at("counter").at(parent_location))
      
    let subcounter = numbering(
      target.at("numbering"),
      ..target.at("counter").at(target.location()))
    
    // NOTE there's a nonbreaking space in the block below
    link(target.location(), [#parent_figure.at("supplement") #counters#subcounter])
  } else {
    it
  }
})

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black) = {
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
      block(
        inset: 1pt, 
        width: 100%, 
        block(fill: white, width: 100%, inset: 8pt, body)))
}



#let article(
  title: none,
  authors: none,
  date: none,
  abstract: none,
  cols: 1,
  margin: (x: 1.25in, y: 1.25in),
  paper: "us-letter",
  lang: "en",
  region: "US",
  font: (),
  fontsize: 11pt,
  sectionnumbering: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  set page(
    paper: paper,
    margin: margin,
    numbering: "1",
  )
  set par(justify: true)
  set text(lang: lang,
           region: region,
           font: font,
           size: fontsize)
  set heading(numbering: sectionnumbering)

  if title != none {
    align(center)[#block(inset: 2em)[
      #text(weight: "bold", size: 1.5em)[#title]
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
    #text(weight: "semibold")[Abstract] #h(1em) #abstract
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
#show: doc => article(
  title: [W3: Smile for the Camera: Selfies],
  margin: (x: 1.25in,y: 1.25in,),
  paper: "us-letter",
  font: ("Source Sans",),
  fontsize: 14pt,
  toc_title: [Table of contents],
  toc_depth: 3,
  cols: 1,
  doc,
)


- Jenka Gurfinkel, "#link("https://medium.com/@socialcreature/ai-and-the-american-smile-76d23a0fbfaf")[AI and the American Smile];" (#strong[Medium];, 17 March 2023)
- Michael Standaert, "#link("https://www.theguardian.com/global-development/2021/mar/03/china-positive-energy-emotion-surveillance-recognition-tech")[Smile for the Camera: The Dark Side of China’s Emotion-Recognition Tech];" (#strong[The Guardian];, 3 March 2021)

== AI and the American Smile
<ai-and-the-american-smile>
#quote(block: true)[
In flattening the diversity of facial expressions of civilizations around the world AI had collapsed the spectrum of history, culture, photography, and emotion concepts into a singular, monolithic perspective. It presented a false visual narrative about the universality of something that in the real world — where real humans have lived and created culture, expression, and meaning for hundreds of thousands of years — is anything but uniform.
]

#quote(block: true)[
—Jenna Gurfinkel, "AI and the American Smile"
]

So this week we are tackling everybody’s favorite social-media topic: the selfie, or if you’ve read the reading assignment, might be more accurately called the #strong[smilie];.

I initially assigned only Jenna Gurfinkel’s article for this week, because the article itself is packed with references to other sources that you are presumably also going to want to explore. But as I was rereading it, I decided to add one other recent article that came to mind, that adds a different perspective to the discussion of social media, cameras, and smiling: a #strong[Guardian] article about the use of facial recognition as a tool of social control in contemporary China. So in some ways, this week we could think about not just the \*smile\*\* but the #emph[face] in social media, as a focus of social, cultural, and political power.

Conceptually, the trickiest concept that’s referenced in the AI-selfie article is "uncertainty avoidance," a rather self-contradictory notion that may need clarification. My favorite example of this is from country walking. As I’m sure you know, it’s an unspoken convention when out walking in a forest or some other remote location, that if you pass someone walking in the other direction, you are expected to make eye contact, say "Hi!," and above all, #strong[smile] at the other person(s)! Why do we all do this? We don’t do it when walking around town, for example. The answer is: to avoid uncertainty - uncertainty, that is, about the potentially malevolent intentions of the other we are encountering in this remote place. In short, eye contact, a brief verbal greeting, and, especially, a smile are a way of reassuring the other person that you are #strong[not a psycho];.

Of course, given that as the article also explains (in the reference to the University of Rochester study), smiling is also a sign of duplicity, there is no reason to be reassured by the smiling stranger that we may encounter alone in a forest; in such cases, indeed, the smile may actually be more a source of anxiety than reassurance.

Regardless of whether smiles and a cheerful demeanor are reassuring or not, the central point of the article is that smiling is a #strong[cultural] practice: even though everyone smiles (universal humanism), we do so - or not - for very different reasons (cultural specificity). The Russian examples discussed in the article are perhaps the clearest example of this.

The central question raised by Gurfinkel’s argument, however, stems from its title: how far can smiling—at least self-type smiling—be considered specifically "American"? Did Americans invent this kind of smiling?

In answer to this, I would add one other example to the discussion of the cultural dimension of smiling: what I would call the #strong[subaltern smile];. ("Subaltern" here refers to a form of social subjectivity that has internalized structures of domination and accept, even welcome, their position of subservience). From this standpoint, the smile is a sign of subservience, of #strong[eagerness to be of service] - is there anything else I can do for you? As the example of the Russian bank teller in the US shows, such smiling is often not just a social but a professional requirement, a form of coercion. In his book #strong[Black Skin, White Masks];, the postcolonial theorist Franz Fanon writes about how during imperialism Africans were expected to #strong[smile] for their colonial masters, as a sign of their willing acceptance of their subservient role. There are numerous examples of this, but the most famous one is the ubiquitous image of the WW1/WW2 African infantryman in the French army (the #emph[tirailleur sénégalais];) that was used for the chocolate milk brand #link("https://en.wikipedia.org/wiki/Banania")[Banania];.

#box(image("../img/banania.jpg", width: 200))

We see from this example that Gurfinkel’s point that smiling is a sign of confidence or power does not always apply, that smiling has many other cultural meanings.

What if AIs were trained not on models of American smiles but African ones? In light of the history of slavery, how awkward does this make the AI selfie of "Ancient African Tribal Warriors"?

#box(image("../img/african-ai.webp", width: 200))

#horizontalrule

== Selfie Studies
<selfie-studies>
The discussion of "smiling for the camera" is itself part of the larger study of the selfe in social media, a field that is much more developed than you would ever believe. To get an idea of the scope of this field, you could start with the #link("https://selfieresearchers.com/")[Selfies Research Network];, founded (as far as I know) by #link("https://researchers.mq.edu.au/en/persons/theresa-m-senft")[Theresa Senft] and other colleagues, notably #link("https://tiara.org/")[Alice Marwick];. In light of this week’s reading, you may be struck by Alice’s authentically American smile!

#box(image("../img/alice-marwick.jpeg", width: 200))

If you’re interested in exploring selfie culture for your research paper, there are many directions you could go, including music video:

#link("https://youtu.be/kdemFfbS5H0")

I’ll be interested to see what other examples are brought to mind both by this week’s readings and my lecture!

#horizontalrule
