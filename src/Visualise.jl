
module Visualise

using PyCall
using JuLIP.ASE: ASEAtoms, write

@pyimport IPython.display as ipydisp
@pyimport imolecule

"""
# Varargs (copied from imolecule)

* `size`: Starting dimensions of visualization, in pixels, e.g., `(500,500)`
* `drawing_type`: Specifies the molecular representation. Can be 'ball and
    stick', "wireframe", or 'space filling'.
* `camera_type`: Can be 'perspective' or 'orthographic'.
* `shader`: Specifies shading algorithm to use. Can be 'toon', 'basic',
    'phong', or 'lambert'.
* `display_html`: If True (default), embed the html in a IPython display.
    If False, return the html as a string.
* `element_properties`: A dictionary providing color and radius information
    for custom elements or overriding the defaults in imolecule.js
* `show_save`: If True, displays a save icon for rendering molecule as an
    image.
"""
function Base.view(at::AbstractAtoms; bonds=:babel, box=:auto,
            camera_type="perspective", size=(500,500), display_html=false, varargs...)

   # TODO: implement box (ignore for now)

   if bonds == :babel
      # in this case we assume that OpenBabel and in particular `pybel` is
      # installed; we write the atoms object as xyz and let `pybel`
      # do the rest
      fn = "$(tempname()).xyz"
      write(fn, at)
      out = ipydisp.HTML(
           imolecule.draw(fn, format="xyz", camera_type=camera_type,
                                size=size, display_html=false, varargs...)
                       )
      rm(fn)
      return out
   elseif bonds == :auto
      bonds = autobondlenghts(at)
   elseif !isa(bonds, Dict)
      error("""view(at ...) : at the momement, `bonds` must be
               `:babel`, `:auto` or a `Dict` containing the bonds-length
               information""")
   end

   # we have a `Dict` that contains all the bond-length information
   # (which we guessed really; this needs more work)
   # we can therefore write a JSON file with atom positions + connectivity
   # and let `imolecule` load that; this never needs to import `pybel` so it
   # will work even if OpenBabel is not installed.

   # TODO: bond-length guesses for multiple species
   # TODO: bounding box especially with PBCs
   # TODO: check which other information imolecule accepts

   # temporarily assume there is a single species!
   # and make the bond length 120% of the NN-length
   bondlength = 1.2 * JuLIP.ASE.rnn( JuLIP.ASE.chemical_symbols(at)[1] )

   # we need to turn of PBC otherwise we get weird bonds
   set_pbc!(at, (false, false, false))
   atoms = [Dict("element" => e, "location" => Vector(x))
            for (e, x) in zip(JuLIP.ASE.chemical_symbols(at), positions(at)) ]
   nlist = neighbourlist(at, bondlength)
   b = unique(sort([nlist.i nlist.j], 2), 1) - 1
   bonds = [Dict(:atoms => b[n,:][:], :order => 1) for n = 1:size(b,1)];
   molecule_data = Dict(:atoms=>atoms, :bonds=>bonds);

   # convert write to a temporary file
   fn = "$(tempname()).json"
   fio = open(fn, "w")
   print(fio, JSON.json(molecule_data))
   close(fio)

   # plot
   out = ipydisp.HTML(
        imolecule.draw(fn, format="json", camera_type=camera_type,
                             size=size, display_html=false, varargs...)
                    )
   rm(fn)
   return out
end