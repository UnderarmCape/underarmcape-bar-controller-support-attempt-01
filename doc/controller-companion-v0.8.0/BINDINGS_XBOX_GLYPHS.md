# Controller Bindings Xbox glyphs

The Controller Bindings screen always renders the Xbox family from the shipped
glyph atlases. This presentation-only choice is applied on initialize and draw,
so opening the screen cannot inherit PlayStation or Auto presentation state.

Binding chips, action rows, and default/current detail values use the shared
glyph renderer. Face buttons, shoulders/triggers, D-pad directions, sticks,
stick clicks, View, and Menu are mapped. An unknown binding falls back to its
text label. Gameplay glyph preferences remain independent and are not mutated
by the Bindings screen.
