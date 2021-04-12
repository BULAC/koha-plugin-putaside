Put Aside
=========

Put Aside is a plugin for Koha. It adds a new entry in the circulation
module. You should configure which item types can be put aside. Then a
Patron can ask staff people to put aside a document for him. It is
mainly intended for on-site checkouts of a patron who has to leave the
library but wish to recover the same item later the same day or the
same week.

When Put Aside, the item is returned and reserved for the patron who
last borrowed it, the patron priority is set to “first”, the item
status is set as “Waiting“.

-----

    make

generates the `.kpz` file you can then load in Koha plugins.