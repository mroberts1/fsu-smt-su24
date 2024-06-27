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
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: white, width: 100%, inset: 8pt, body))
      }
    )
}


#let PrettyPDF(
  // The document title.
  title: "PrettyPDF",

  // Logo in top right corner.
  typst-logo: none,

  // The document content.
  body
) = {

  // Set document metadata.
  set document(title: title)
  
  // Configure pages.
  set page(
    margin: (left: 2cm, right: 1.5cm, top: 2cm, bottom: 2cm),
    numbering: "1",
    number-align: right,
    background: place(right + top, rect(
      fill: rgb("#E6E6FA"),
      height: 100%,
      width: 3cm,
    ))
  )
  
  // Set the body font.
  set text(10pt, font: "Ubuntu")

  // Configure headings.
  show heading.where(level: 1): set block(below: 0.8em)
  show heading.where(level: 1): underline
  show heading.where(level: 2): set block(above: 0.5cm, below: 0.5cm)

  // Links should be purple.
  show link: set text(rgb("#800080"))

  // Configure light purple border.
  show figure: it => block({
    move(dx: -3%, dy: 1.5%, rect(
      fill: rgb("FF7D79"),
      inset: 0pt,
      move(dx: 3%, dy: -1.5%, it.body)
    ))
  })

  // Purple border column
  grid(
    columns: (1fr, 0.75cm),
    column-gutter: 2.5cm,

    // Title.
    text(font: "Ubuntu", 20pt, weight: 800, upper(title)),

    // The logo in the sidebar.
    locate(loc => {
      set align(right)

      // Logo.
      style(styles => {
        if typst-logo == none {
          return
        }
  
        let img = image(typst-logo.path, width: 1.5cm)
        let img-size = measure(img, styles)
        
        grid(
          columns: (img-size.width, 1cm),
          column-gutter: 16pt,
          rows: img-size.height,
          img,
        )
      })
      
    }),
    
    // The main body text.
    {
      set par(justify: true)
      body
      v(1fr)
    },
  

  )
}


#show: PrettyPDF.with(
  title: "COMM 7018: Social Media Theory",
  typst-logo: (
    path: "\_extensions/nrennie/PrettyPDF/logo.png",
    caption: []
  ), 
)



#link("https://www.polyducks.co.uk")[#box(image("img/polyducks.gif"))]

= Introduction
<introduction>
The term #strong[social media] is popularly understood as referring to corporate-owned, advertising-funded communication #strong[platforms] based on #strong[user-generated content];: YouTube, Instagram, Facebook, Twitter, Twitch, Discord, TikTok. It can also be defined more broadly, however, as a set of networked, technologically-mediated #strong[practices] of communication, structured by economic and political forces that both inflect and are inflected by social and cultural identities. These platforms, the social practices that they enable, and the relationship between the two are the objects of #strong[social media theory];. But what does it mean to theorize social media? Why do we need social media theory at all?

To theorize something involves a number of processes:

- first, how do we define the phenomenon or object of study itself? How does it differ from previous or other related phenomena?
- how are we to account for it? Why did it happen/is it happening now rather than at some other time? What are its conditions of possibility?
- what is its relation to larger areas of society? What are its implications for those areas?
- how are we to evaluate it, in terms of its implications (political, economic, social, ethical, legal, environmental, aesthetic)? What are its possibilities and limits, its progressive and oppressive aspects? How can we change it for the better?

These processes involve developing analytical frameworks or models comprising concepts that are useful for identifying and analyzing key aspects of and issues raised by the phenomenon/object in question. These frameworks and concepts typically draw from existing ones in different fields of study, but often involve the proposal of new frameworks and concepts specific to the field in question.

= Objectives
<objectives>
By the end of the course, students will be able to:

- analyze technologies past, present, and imagined
- describe the ways in which technologies shape our world the ways in which we shape those technologies
- explain how social media is a result of the intersection between technologies and existing human communication dynamics
- discuss how theory of technology and social media can improve the vocational outlook of a student
- play a productive role in and facilitate conversations that tease out the relationships between values and technology. \
- through the skills you will refine in writing your research papers, clearly explain how a specific technology shapes the social world that we live in.

= Course Texts
<course-texts>
- These sources are either available online or excerpts will be posted on Blackboard.

- Byung-Chul Han, #strong[In The Swarm: Digital Prospects] (Cambridge, MA: MIT Press, 2017).

- Robert Pfaller, #strong[Interpassivity: The Aesthetics of Delegated Enjoyment] (Edinburgh: Edinburgh University Press, 2017).

- Whitney Phillips and Ryan M. Milner, #strong[You Are Here: A Field Guide for Navigating Polarized Speech, Conspiracy Theories, and Our Polluted Media Landscape] (Cambridge: MIT Press, 2021).

- Kaitlyn Tiffany, #strong[Everything I Need I Get From You: How Fangirls Created the Internet as We Know It] (Oxford: Blackwell’s, 2022).

= Course Info
<course-info>
#strong[Blackboard] \
We will be using the Blackboard Learning Management System (LMS) as the primary platform for the course. Please be sure to check in to the site at least once daily M-F to check the Announcements page and the Discussion forum for the week.

#strong[Sources] \
Reading assignments will be either from Required texts, linked to online, or available as PDF documents.

PDF documents and the syllabus will be available for download in the #link("https://github.com/mroberts1/social-media-theory-summer-2022")[Course Repository] hosted on GitHub: please bookmark this link. The folder on the repo will have copies of all PDF chapters and articles, which may be downloaded either individually (click on the document in question and then the Download button) or collectively in the zip file.

= Assignments / Evaluation
<assignments-evaluation>
- #strong[Review];: 6, weekly from Week 1, one short post responding to readings, 250 words (maximum), due by Friday (20%) \
- #strong[Discussion];: weekly after Week 1, 2-3 responses to other students’ posts., 100 words max., due by the #emph[following] Friday (20%) \
- #strong[Commentary];: 2 short papers, 750-1000 words, due Sunday of Week 2 and Week 4 (20%) \
- #strong[Research paper/report/other project];: 2,000 words, due Sunday of week 7 (20%)
- #strong[Digital Garden] (practical project, ongoing - information will be provided) (20%)

#strong[Discussion: Agenda, Review, Reply Posts] \
For Weeks 1-6, each of the weekly topics will be active across a cycle of two weeks.

By #strong[Wednesday] of each week, I will post an Agenda item in the Discussion forum for the topic of the week, that introduces and contextualizes the reading assignments for the week, identifying key themes, concepts, and/or issues to look out for as you read. Be sure to read the Agenda post before beginning the reading assignments.

In the first week, complete the reading assignments and make an initial response post called a Review, with question and/or comments on them, by #strong[Sunday] of the week in question.

In the second week, read through the Review posts of the group and post at least one Reply to one of them by Friday of that week.

#strong[Commentary Papers] \
These short papers (750-1,000 words) are due at the end of Week 2 and Week 4 (Sunday). They should consist of close analytical readings of any of the reading assignments for the period Weeks 1-2 or 3-4. You are encouraged to focus in detail on particular sections, arguments, and/or concepts from the readings and develop them.

#strong[Research Paper/Project] \
The culminating written assignment for the course (2,000 words) may consist of various formats: a research paper or report, or a creative project of your choice.

A 1-page preliminary proposal with ideas for your project, with a short bibliography with sources and/or links, should be posted in the Discussion forum for the purpose by the end of Week 3, and you will receive feedback during Week 4.

= Schedule
<schedule>
#strong[Week 1] M 05/20

#strong[Interpassive Aggressive]

Rob Horning, #strong[Internal Exile] (blog)

- "#link("https://robhorning.substack.com/p/empires-of-modern-passivity?r=1dbr0j&utm_medium=ios&triedRedirect=true")[Empires of Modern Passivity];" (17 May 2024) \[Please read the linked references also\]
- "#link("https://robhorning.substack.com/p/a-delightful-intuitive-companion?utm_source=substack&publication_id=1073994&post_id=141075725&utm_medium=email&utm_content=share&utm_campaign=email-share&isFreemail=true&r=1dbr0j&triedRedirect=true")[A Delightful Intuitive Companion];" (26 January 2024)
- Robert Pfaller, "Introduction" \[#link("pdf/interpassivity-intro.pdf")[pdf];\] (#emph[Interpassivity: The Aesthetics of Delegated Enjoyment];)

#horizontalrule

#strong[Week 2] M 05/27

#strong[Digital Swarms]

- Byung-Chul Han, "No Respect"; "Outrage Society"; "In The Swarm" (#strong[In The Swarm: Digital Prospects];, chs.~1-3) \[#link("pdf/in-the-swarm.pdf")[pdf];\]
- Cathy O’Neil, "Humiliation and Defiance" (#strong[The Shame Machine: Who Profits in the New Age of Humiliation];, ch.~6) \[#link("pdf/shame-machine-karens.pdf")[pdf];\]

#horizontalrule

#strong[Week 3] M 06/03

#strong[Smile for the Camera: Selfies]

- Jenka Gurfinkel, "#link("https://medium.com/@socialcreature/ai-and-the-american-smile-76d23a0fbfaf")[AI and the American Smile];" (#strong[Medium];, 17 March 2023)
- Michael Standaert, "#link("https://www.theguardian.com/global-development/2021/mar/03/china-positive-energy-emotion-surveillance-recognition-tech")[Smile for the Camera: The Dark Side of China’s Emotion-Recognition Tech];" (#strong[The Guardian];, 3 March 2021)

#horizontalrule

#strong[Week 4] M 06/10

#strong[Fangirls]

- Nancy Baym, "#link("pdf/playing-to-the-crowd-intro.pdf")[Introduction: The Intimate Work of Connection];" (#strong[Playing to the Crowd];, Introduction)
- Kaitlyn Tiffany, #link("pdf/kaitlyn-tiffany.pdf")[#strong[Everything I Need I Get From You];] (it’s a big excerpt - read at least the Introduction and the first couple of chapters)

#horizontalrule

#strong[Week 5] M 06/17

#strong[Females]

- #link("https://amfq.xyz/")[Alex Quicho];, "#link("https://www.wired.com/story/girls-online-culture/")[Everyone is a Girl Online];" (#strong[WIRED];, 11 September 2023)

- Emma Copley Eisenberg, "#link("https://www.heyalma.com/notes-on-frump-a-style-for-the-rest-of-us/")[Notes on Frump: A Style for the Rest of Us];" (#strong[heyalma];, 10 August 2017)

#horizontalrule

#strong[Week 6] M 06/24

#strong[Toxic Cleanup]

Ryan Milner and Whitney Phillips, #strong[You Are Here]

- ch.~5: "#link("pdf/you-are-here-ch5.pdf")[Cultivating Ecological Literacy];" (skip opening section in italics)
- ch.~6: "#link("pdf/you-are-here-ch6.pdf")[Choose Your Own Ethics Adventure];"

#horizontalrule

#strong[Week 7] M 07/01

#strong[The Dark Forest]

- Maggie Appleton, "#link("https://maggieappleton.com/cozy-web")[The Dark Forest & The Cozy Web];"
- Yancey Strickler, "The Dark Forest Theory of the Internet"; "Beyond The Dark Forest Theory of the Internet" (2019)

= Resources
<resources>
#link("https://www.abbiesr.com/about")[Abbie Richards] (TikTok researcher, Media Matters)

= Bibliography
<bibliography>
danah boyd, #strong[It’s Complicated: The Social Lives of Networked Teens] (New Haven: Yale University Press, 2014).

Amy Bruckman, #strong[Should You Believe Wikipedia? Online Communities and the Construction of Knowledge] (Cambridge: Cambridge University Press, 2022).

Finn Brunton and Helen Nissenbaum, #strong[Obfuscation: A User’s Guide for Privacy and Protest] (Cambridge: MIT Press, 2016).

Gabriella Coleman, #strong[Hacker, Hoaxer, Whistleblower, Spy: The Many Faces of Anonymous] (London and New York: Verso, 2014).

Claire Dederer, #strong[Monsters: A Fan’s Dilemma] (New York: Alfred A. Knopf, 2023).

Sarah J. Jackson, Moya Bailey, et al., #strong[\#Hashtag Activism: Networks of Race and Gender Justice] (Cambridge: MIT Press, 2020).

Lori Kido Lopez, #strong[Race and Media: Critical Approaches] (New York: New York University Press, 2020).

Gary Marcus & Ernest Davis, #strong[Rebooting AI: Building Artificial Intelligence We Can Trust] (New York: Pantheon Books, 2019).

Gretchen McCulloch, #strong[Because Internet: Understanding the New Rules of Language] (New York: Riverhead Books, 2019).

Angela Nagle, #strong[Kill All Normies: Online Culture Wars From 4Chan and Tumblr to Trump and the Alt-Right] (Alresford, Hampshire, UK: Zero Books, 2017). \* Cathy O’Neil, with Stephen Baker, #strong[The Shame Machine: Who Profits in the New Age of Humiliation] (New York: Crown/Random House, 2022).

Whitney Phillips, #strong[This Is Why We Can’t Have Nice Things: Mapping the Relationship between Online Trolling and Mainstream Culture] (Cambridge: MIT Press, 2015).

Whitney Phillips and Ryan M. Milner, #strong[You Are Here: A Field Guide for Navigating Polarized Speech, Conspiracy Theories, and Our Polluted Media Landscape] (Cambridge: MIT Press, 2021).

Allissa V, Richardson, #strong[Bearing Witness While Black: African Americans, Smartphones, and the New Protest \#Journalism] (Oxford: Oxford University Press, 2020).

= Late Policy
<late-policy>
Assignments that are late will lose 1/2 of a grade per day, beginning at the end of class and including weekends and holidays. This means that a paper, which would have received an A if it was on time, will receive a B+ the next day, B- for two days late, and so on. Time management, preparation for our meetings, and timely submission of your work comprise a significant dimension of your professionalism. As such, your work must be completed by the beginning of class on the day it is due. If you have a serious problem that makes punctual submission impossible, you must discuss this matter with me before the due date so that we can make alternative arrangements. Because you are given plenty of time to complete your work, and major due dates are given to you well in advance, last minute problems should not preclude handing in assignments on time.

= Mandatory Reporter
<mandatory-reporter>
Fitchburg State University is committed to providing a safe learning environment for all students that is free of all forms of discrimination and harassment. Please be aware all FSU faculty members are "mandatory reporters," which means that if you tell me about a situation involving sexual harassment, sexual assault, dating violence, domestic violence, or stalking, I am legally required to share that information with the Title IX Coordinator. If you or someone you know has been impacted by sexual harassment, sexual assault, dating or domestic violence, or stalking, FSU has staff members trained to support you. If you or someone you know has been impacted by sexual harassment, sexual assault, dating or domestic violence, or stalking, please visit #link("http://fitchburgstate.edu/titleix") to access information about university support and resources.

= Health
<health>
#link("http://www.google.com/url?q=http%3A%2F%2Fwww.fitchburgstate.edu%2Foffices-services-directory%2Fhealth-services%2F&sa=D&sntz=1&usg=AFQjCNEw5V0i0hL5DVO5b43gejNNaAt4ig")[Health Services]

Hours: Monday-Friday 8:30AM-5PM Location: Ground Level of Russell Towers (across from the entrance of Holmes Dining Hall) Phone: (978) 665-3643/3894

#link("http://www.google.com/url?q=http%3A%2F%2Fwww.fitchburgstate.edu%2Foffices-services-directory%2Fcounseling-services%2F&sa=D&sntz=1&usg=AFQjCNEYiS4EmSvWerpp2bKr5lTpouPuqQ")[Counseling Services]

The Counseling Services Office offers a range of services including individual, couples and group counseling, crisis intervention, psychoeducational programming, outreach ALTERNATIVE ECOSYSTEMSs, and community referrals. Counseling services are confidential and are offered at no charge to all enrolled students. Staff at Counseling Services are also available for consultation to faculty, staff and students. Counseling Services is located in the Hammond, 3rd Floor, Room 317.

#link("http://www.google.com/url?q=http%3A%2F%2Fwww.fitchburgstate.edu%2Foffices-services-directory%2Ffitchburg-anti-violence-education%2F&sa=D&sntz=1&usg=AFQjCNFi5qy-wunMxX-hoWbA9YwT8aa4Ig")[Fitchburg Anti-Violence Education (FAVE)]

FAVE collaborates with a number of community partners (e.g., YWCA Domestic Violence Services, Pathways for Change) to meet our training needs and to link survivors with community based resources. This site also features #link("http://www.google.com/url?q=http%3A%2F%2Fwww.fitchburgstate.edu%2Foffices-services-directory%2Ffitchburg-anti-violence-education%2Ffitchburg-anti-violence-education-resources%2F&sa=D&sntz=1&usg=AFQjCNF9KZ2O1AvPMLJTHdNg1DfmYYtgog")[resources] for help or information about dating violence, domestic violence, sexual assault and stalking. If you or someone you know is in an abusive relationship or has been a victim of sexual assault, there are many places to go for help. Many can be accessed 24 hours a day, seven days a week, 365 days a year. On campus, free and confidential support is provided at both Counseling Services and Health Services.

#emph[Community Food Pantry] Food insecurity is a growing issue and it certainly can affect student learning. The ability to have access to nutritious food is incredibly vital. The Falcon Bazaar, located in Hammond G 15, is stocked with food, basic necessities, and can provide meal swipes to support all Fitchburg State students experiencing food insecurity for a day or a semester.

The university continues to partner with Our Father’s House to support student needs and access to food and services. All Fitchburg State University students are welcome at the Our Father’s House Community Food Pantry. This Pantry is located at the Faith Christian Church at 40 Boutelle St., Fitchburg, MA and is open from 5-7pm. Each "household" may shop for nutritious food once per month by presenting a valid FSU ID.

= Academic Integrity
<academic-integrity>
The University "Academic Integrity" policy can be found online at #link("http://www.fitchburgstate.edu/offices-services-directory/office-of-student-conduct-mediation-education/academic-integrity/")[http:\/\/ www.fitchburgstate.edu/offices-services-directory/office-of-student-conductmediation-education/academic-integrity/.] Students are expected to do their own work. Plagiarism and cheating are inexcusable. Any instance of plagiarism or cheating will automatically result in a zero on the assignment and may be reported the Office of Student and Academic Life at the discretion of the instructor.

Plagiarism includes, but is not limited to: - Using papers or work from another class. - Using another student’s paper or work from any class. - Copying work or a paper from the Internet. - The egregious lack of citing sources or documenting research.

#emph[If you’re not clear on what is or is not plagiarism, ASK. The BEST case scenario if caught is a zero on that assignment, and ignorance of what does or does not count is not an excuse. That being said, I’m a strong supporter of] #link("https://en.wikipedia.org/wiki/Fair_Use")[#emph[Fair Use];] #emph[doctrine. Just attribute what you use–and, again, ASK if there’s any doubt.]

= Americans With Disabilities Act (ADA)
<americans-with-disabilities-act-ada>
If you need course adaptations or accommodations because of a disability, if you have emergency medical information to share with the instructor, or if you need special arrangements in case the building must be evacuated, please inform the faculty member as soon as possible.

= Technology
<technology>
At some point during the semester you will likely have a problem with technology. Your laptop will crash; your iPad battery will die; a recording you make will disappear; you will accidentally delete a file; the wireless will go down at a crucial time. These, however, are inevitabilities of life, not emergences. Technology problems are not excuses for unfinished or late work. Bad things may happen, but you can protect yourself by doing the following:

- Plan ahead: A deadline is the last minute to turn in material. You can start—and finish—early, particularly if challenging resources are required, or you know it will be time consuming to finish this project.

- Save work early and often: Think how much work you do in 10 minutes. I auto save every 2 minutes.

- Make regular backups of files in a different location: Between Box, Google Drive, Dropbox, and iCloud, you have ample places to store and backup your materials. Use them.

- Save drafts: When editing, set aside the original and work with a copy.

- Practice safe computing: On your personal devices, install and use software to control viruses and malware.

= Grading Policy
<grading-policy>
Grading for the course will follow the FSU grading policy below:

4.0: 95-100 \
3.7: 92-94 \
3.5: 89-91 \
3.3: 86-88 \
3.0: 83-85 \
2.7: 80-82 \
2.5: 77-79 \
2.3: 74-76 \
2.0: 71-73 \
0.0: \< 70

= Academic Resources
<academic-resources>
#link("http://www.fitchburgstate.edu/offices-services-directory/tutor-center/writing-help/")[Writing Center]

#link("http://catalog.fitchburgstate.edu/content.php?catoid=13&navoid=851")[Academic Policies]

#link("http://www.fitchburgstate.edu/offices-services-directory/disability-services/")[Disability Services]

#link("https://www.getrave.com/login/fitchburgstate/")[Fitchburg State Alert system for emergencies, snow closures/delays, and faculty absences]

#link("http://www.fitchburgstate.edu/offices-services-directory/career-counseling-and-advising/careerservices/")[University Career Services]
