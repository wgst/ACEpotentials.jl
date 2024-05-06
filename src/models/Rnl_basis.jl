
import LuxCore: AbstractExplicitLayer, 
                initialparameters, 
                initialstates
using StaticArrays: SMatrix 
using Random: AbstractRNG

abstract type AbstractRnlzzBasis <: AbstractExplicitLayer end

# NOTEs: 
#  each smatrix in the types below indexes (i, j) 
#  where i is the center, j is neighbour

const NT_RIN0CUTS{T} = NamedTuple{(:rin, :r0, :rcut), Tuple{T, T, T}}
const NT_NL_SPEC = NamedTuple{(:n, :l), Tuple{Int, Int}}

struct LearnableRnlrzzBasis{NZ, TPOLY, TT, TENV, TW, T} <: AbstractRnlzzBasis
   _i2z::NTuple{NZ, Int}
   polys::TPOLY
   transforms::SMatrix{NZ, NZ, TT}
   envelopes::SMatrix{NZ, NZ, TENV}
   # -------------- 
   weights::SMatrix{NZ, NZ, TW}               # learnable weights, `nothing` when using Lux
   rin0cuts::SMatrix{NZ, NZ, NT_RIN0CUTS{T}}  # matrix of (rin, rout, rcut)
   spec::Vector{NT_NL_SPEC}       
   # --------------
   # meta
   meta::Dict{String, Any} 
end


# struct SplineRnlrzzBasis{NZ, SPL, ENV} <: AbstractRnlzzBasis
#    _i2z::NTuple{NZ, Int}                 # iz -> z mapping
#    splines::SMatrix{NZ, NZ, SPL}         # matrix of splined radial bases
#    envelopes::SMatrix{NZ, NZ, ENV}       # matrix of radial envelopes
#    rincut::SMatrix{NZ, NZ, Tuple{T, T}}  # matrix of (rin, rout)

#    #-------------- 
#    # meta should contain spec 
#    meta::Dict{String, Any} 
# end


# a few getter functions for convenient access to those fields of matrices
_rincut_zz(obj, zi, zj) = obj.rin0cut[_z2i(obj, zi), _z2i(obj, zj)]
_envelope_zz(obj, zi, zj) = obj.envelopes[_z2i(obj, zi), _z2i(obj, zj)]
_spline_zz(obj, zi, zj) = obj.splines[_z2i(obj, zi), _z2i(obj, zj)]
_transform_zz(obj, zi, zj) = obj.transforms[_z2i(obj, zi), _z2i(obj, zj)]
# _polys_zz(obj, zi, zj) = obj.polys[_z2i(obj, zi), _z2i(obj, zj)]


# ------------------------------------------------------------ 
#      CONSTRUCTORS AND UTILITIES 
# ------------------------------------------------------------ 

# these _auto_... are very poor and need to take care of a lot more 
# cases, e.g. we may want to pass in the objects as a Matrix rather than 
# SMatrix ... 




function LearnableRnlrzzBasis(
            zlist, polys, transforms, envelopes, rin0cuts, 
            spec::AbstractVector{NT_NL_SPEC}; 
            weights=nothing, 
            meta=Dict{String, Any}())
   NZ = length(zlist)   
   LearnableRnlrzzBasis(_convert_zlist(zlist), 
                        polys, 
                        _make_smatrix(transforms, NZ), 
                        _make_smatrix(envelopes, NZ), 
                        # --------------
                        _make_smatrix(weights, NZ), 
                        _make_smatrix(rin0cuts, NZ),
                        collect(spec), 
                        meta)
end

Base.length(basis::LearnableRnlrzzBasis) = length(basis.spec)

function initialparameters(rng::AbstractRNG, 
                           basis::LearnableRnlrzzBasis)
   NZ = _get_nz(basis) 
   len_nl = length(basis)
   len_q = length(basis.polys)

   function _W()
      W = randn(rng, len_nl, len_q)
      W  = W ./ sqrt.(sum(W.^2, dims = 2))
   end

   return (Wnlq = [ _W() for i = 1:NZ for j = 1:NZ ], )
end

function initialstates(rng::AbstractRNG, 
                       basis::LearnableRnlrzzBasis)
   return NamedTuple()                       
end
                  


function splinify(basis::LearnableRnlrzzBasis)

end

# ------------------------------------------------------------ 
#      EVALUATION INTERFACE
# ------------------------------------------------------------ 

import Polynomials4ML

(l::LearnableRnlrzzBasis)(args...) = evaluate(l, args...)

function evaluate(basis::LearnableRnlrzzBasis, r, Zi, Zj, ps, st)
   iz = _z2i(basis, Zi)
   jz = _z2i(basis, Zj)
   Wij = ps.W[iz, jz]
   trans_ij = basis.transforms[iz, jz]
   x = trans_ij(r)
   P = Polynomials4ML.evaluate(basis.polys, x)
   env_ij = basis.envelopes[iz, jz]
   e = evaluate(env_ij, x)   
   return Wij * (P .* e), st 
end