/// The lattice a board's coordinates are interpreted against.
///
/// `square` covers both the 2D plane ([Direction]) and the 3D layer lattice
/// ([Direction] + [LayerDirection]) — those two are the same planar lattice
/// stacked along z. `hex` is planar-only: a hex level is always single-layer.
///
/// A level's topology is carried in its JSON metadata
/// (`metadata.topology`), not inferred from graph shape — axial `(q, r)`
/// hex coordinates and square `(x, y)` coordinates reuse the same integer
/// lattice, so a hex graph and a square graph are indistinguishable by node
/// coordinates alone.
enum BoardTopology { square, hex }
