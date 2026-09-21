---
Type: review
Purpose: "The ways a system can tell somebody where a tool is, ranked by what each costs to author and who each one actually works for, so that the map question is decided by who is looking rather than by which option is most fun to build."
Depends on: [supabase/migrations/0132_a_place_is_inside_another_place.sql, supabase/migrations/0134_a_domain_tags_a_place_and_a_thing.sql]
Depended on by: [docs/status-ledger.md]
---

# Showing somebody where a thing is

Researched 2026-09-20 at the winemaker's request: "look into different ways to
present maps for tools. Like visual modeling vs description or both or whatever."

**The framing that makes this decidable is not visual versus description.** It is
*who is looking*, and the warehouse literature says so in one sentence: an
experienced storekeeper understands a coded location name, and a production
supervisor does not. Here that is Randy, who knows every shed, and a WWOOFer in
their first week, who knows none of them. Same data, same question, and the
presentation that serves one is useless to the other.

The spatial cognition literature gives the ladder this sits on. The
**Landmark, Route, Survey** model describes three kinds of spatial knowledge that
people acquire in that order: landmark knowledge is recognising places by how
they look, without knowing how they relate; route knowledge is the sequence that
connects them; survey knowledge is the overall layout. They are not competing
designs. They are a progression, and somebody new has only the first.

Five presentations follow, each with what it costs to author, because on a farm
with five rooms and one person to maintain any of it, authoring cost is the
constraint that decides everything.

## 1. The written address

`location_tree` already computes it: **Woodshed > Bay 3 > top shelf**, walked up
through the parents, never stored.

*Costs to author:* nothing. It falls out of the nesting that shipped this
morning.

*Works for:* anyone who knows the buildings. It is route knowledge handed to
somebody who already has the landmarks.

*Fails for:* everybody else, completely. "Bay 3" means nothing to a person who
has never been told which bay is 3, and the failure is silent: they will go and
look and come back and say it was not there.

The warehouse literature is blunt that a coded address is a decoding task, and
that decoding is exactly what a newcomer cannot do.

## 2. A photograph of the place

One photo per storage spot, showing the shelf with the thing on it.

*Costs to author:* a few minutes per location, once. Five rooms and a dozen bays
is an afternoon with a phone.

*Works for:* everybody, immediately, with no training. This is landmark
knowledge delivered directly, which is the rung a newcomer is actually standing
on.

**And this is free in this repository today.** `location` has been a registered
subject type since the resolver went in, `attach_photo` takes a subject type and
a subject id rather than a vessel, the bucket accepts any content type, and
sixteen attachments already exist, so the upload path is proven rather than
theoretical. Nothing needs building to try it. The only thing in the way is that
the bucket is called `vessel-photos` and its policies are scoped to that literal
name, which is a naming problem rather than a capability one.

*Fails for:* nothing much, except that a photo goes stale when a shelf is
rearranged and nothing tells you it has. That is a real weakness and it is
smaller than it sounds: a stale photo of roughly the right shelf still gets
somebody to the right shelf.

## 3. The shadow board, and its software shadow

The physical practice from 5S: trace each tool's outline where it hangs, so a
missing tool is a visible gap. The literature on it makes a claim worth quoting
for the size of the prize, which is that workers spend nearly a quarter of their
time looking for tools, information or equipment.

*Costs to author:* physical work, in the shed, not in software.

**The interesting part for us is what it implies about the photograph.** A
picture of a storage spot *in its correct state* is not only a findability aid.
It is also the answer to "is anything missing", and it is the answer to "where
does this go" when somebody is holding a tool at the end of a job. One artefact,
three uses, and the third is exactly the end-of-task flag he described for
putting tools back.

## 4. A code on the bin

Every home-inventory product converges on this: a QR label on the container,
scan it, see what should be inside. Bin Tracker, BoxQR, SnapFind, SmartLabels,
Elephant Trax all ship the same idea.

*Costs to author:* printing labels and sticking them on, plus a scanning path in
whichever periphery wants it.

**It answers the reverse question, which is the one nothing else here answers.**
Finding a tool and putting a tool away are different problems. Every option above
starts from "I want the shears, where are they". A code on the shelf starts from
"I am standing at this shelf", which is the question somebody has at the end of
pruning with shears in their hand, and it is the moment at which the custody
record either gets closed or does not.

*Fails for:* nothing, but it is the option that most needs a periphery built for
it, and a camera permission, and labels that survive a barn.

## 5. A drawn floor plan

The mature version of this is the library stack map: enter a call number, see the
shelf highlighted in red on a floor plan, with a route from where you are.
StackMap and LibMaps both ship it, and the problem they were built for is exactly
ours, stated at Yale as patrons being able to find the book in the catalogue and
then not knowing how to use the call number to find it on the shelf.

*Costs to author:* hours of drawing per building, and then it decays. Someone has
to redraw it when a bay moves. The library products exist because that authoring
cost is real enough to outsource.

*Works for:* survey knowledge, which is the rung above route. It is the only
option that helps somebody who does not know the building *at all*, and it is the
only one that answers "what else is near here".

**There is an in-repo precedent worth weighing.** The vineyard row screen already
draws a spatial layout: one cell per plant space, coloured by what stands in it.
It works, it was worth building, and it was worth building because the source
document encoded the information in colours and was unreadable without it. That
is not the case here: the shed's layout is not a dataset anybody has, and drawing
it would mean authoring the data as well as the view.

## What this adds up to

**Photograph plus written address answers the question for this farm**, and one
of the two is free today and the other is an afternoon with a phone. The address
serves the person who knows the place; the photo serves the person who does not;
together they cover both rungs anybody here is standing on.

**A code on the bin is the one worth building next**, and not for finding things.
It is the natural place for the end-of-job return he described, because it is the
only design where the moment of putting a tool back is also a moment the phone is
already out.

**The floor plan is premature and compost entry C-6 is the reason.** That entry
killed configuration screens for vocabulary on the grounds that a general surface
would be built "before anyone had discovered which fields they actually want to
edit", and it was only partly reactivated once five specific fields had been
named. The same test applies: nobody here has yet been unable to find a room. The
condition to revive it is somebody saying they could not find a *building*, or a
second site existing, and neither is true today.

**One thing to be careful of**, which none of the sources say because none of
them are farms: everything above assumes the thing is where it is supposed to be.
A photograph of the shelf, an address for the shelf and a code on the shelf all
fail identically when somebody walked off with the shears, and that is the common
case rather than the exception. The presentation question and the custody
question look separate and are not: the best map in the world answers the wrong
question if what you needed was "Matthew has it".

## Sources

- [Wayfinding in interior environments, an integrative review](https://pmc.ncbi.nlm.nih.gov/articles/PMC7677306/)
- [Landmarks in wayfinding, a review of the existing literature](https://link.springer.com/article/10.1007/s10339-021-01012-x)
- [Mapping the evolutions and trends of literature on wayfinding in indoor environments](https://pmc.ncbi.nlm.nih.gov/articles/PMC8314368/)
- [Reducing picking errors with better location visibility](https://blog.cyberstockroom.com/2026/09/02/how-to-reduce-picking-errors-with-better-location-visibility-in-your-warehouse/)
- [Designing a warehouse location numbering system](https://www.shipbob.com/blog/warehouse-location-numbering-system/)
- [Bin location, a beginner's guide](https://racklify.com/encyclopedia/bin-location-a-beginners-guide/)
- [5S tools and visual management](https://tulip.co/blog/5s-tools-and-visual-management/)
- [Shadow board](https://en.wikipedia.org/wiki/Shadow_board)
- [5S tool control solutions with shadow boards](https://www.compliancesigns.com/blog/5s-tool-control/)
- [From the catalog to the book on the shelf, building a mapping application](https://journal.code4lib.org/articles/6924)
- [Transforming library navigation and collection access with StackMap](https://www.libraryjournal.com/story/transforming-library-navigation-and-collection-access-with-stackmap-lj241112)
- [LibMaps](https://www.springshare.com/libmaps)
- [Bin Tracker, QR inventory](https://apps.apple.com/us/app/bin-tracker-qr-inventory/id6792130323)
- [BoxQR](https://boxqr.io/)
- [SnapFind home inventory](https://www.snapfind.app/solutions/home-inventory-app)
