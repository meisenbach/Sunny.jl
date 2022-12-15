export trace, depolarize

abstract type Contraction end

struct Trace{N} <: Contraction 
    indices :: SVector{N, Int64}
end

struct Depolarize <: Contraction
    idxinfo :: SortedDict{CartesianIndex{2}, Int64}
end

struct Element <: Contraction
    index :: Int64
end


function Trace(sf::StructureFactor{N}) where N
    # Collect all indices for matrix elements 𝒮^αβ where α=β
    indices = Int64[]
    for (ci, idx) in sf.sfdata.idxinfo
        α, β = ci.I
        if α == β
            push!(indices, idx)
        end
    end
    # Check that there are the correct number of such elements
    if N == 0 || sf.sftraj.dipolemode
        if length(indices) != 3
            error("Not all diagonal elements of the structure factor have been computed. Can't calculate trace.")
        end
    else
        if length(indices) != N*N-1
            error("Not all diagonal elements of the structure factor have been computed. Can't calculate trace.")
        end
    end
    indices = sort(indices)
    return Trace(SVector{length(indices), Int64}(indices))
end
Trace() = sf -> Trace(sf)

function Depolarize(sf::StructureFactor)
    return Depolarize(sf.sfdata.idxinfo)
end
Depolarize() = sf -> Depolarize(sf)

function Element(sf::StructureFactor, pair)
    index = sf.sfdata.idxinfo[CartesianIndex(pair)]
    return Element(index)
end
Element(pair) = sf -> Element(sf, pair)




function contract(elems, _, traceinfo::Trace)
    intensity = 0.0
    for i in traceinfo.indices
        intensity += abs(elems[i])
    end
    return intensity
end


function contract(elems::SVector{N, ComplexF64}, q::Vec3, depolar::Depolarize) where N
    q /= norm(q) + 1e-12
    dip_factor = SMatrix{3, 3, Float64, 9}(I(3) - q * q')
    intensity = 0.0
    for (ci, idx) in depolar.idxinfo # Loop from 1 to 6 
        α, β = ci.I
        factor = α == β ? 1.0 : 2.0 # Double off-diagonal contribution (if ij is in iteration, ji will not be)
        intensity += factor * dip_factor[α, β] * real(elems[idx])  
    end
    return abs(intensity)
end


function contract(elems::SVector{N, ComplexF64}, _, elem::Element) where N
    return abs(elems[elem.index])
end
