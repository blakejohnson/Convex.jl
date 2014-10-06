import Base.isposdef
export Constraint, EqConstraint, LtConstraint, GtConstraint, SDPConstraint, isposdef
export ==, <=, >=

abstract Constraint

### Linear equality constraint
type EqConstraint <: Constraint
  head::Symbol
  children_hash::Uint64
  lhs::AbstractExpr
  rhs::AbstractExpr
  size::(Int64, Int64)

  function EqConstraint(lhs::AbstractExpr, rhs::AbstractExpr)
    if lhs.size == rhs.size || lhs.size == (1, 1)
      sz = rhs.size
    elseif rhs.size == (1, 1)
      sz = lhs.size
    else
      error("Cannot create equality constraint between expressions of size $(lhs.size) and $(rhs.size)")
    end
    return new(:(==), hash((lhs, rhs)), lhs, rhs, sz)
  end
end

function vexity(c::EqConstraint)
  vexity = vexity(lhs) + (-vexity(rhs))
  # You can't have equality constraints with concave/convex expressions
  if vexity == ConvexVexity() || vexity == ConcaveVexity()
    vexity = NotDcp()
  end
  return vexity
end

function conic_form(c::EqConstraint, unique_constr)
  if !((c.head, c.children_hash) in unique_constr)
    expr = c.lhs - c.rhs
    objective, constraints = conic_form(expr, unique_constr)
    new_constraint = ConicConstr([objective], :Zero, [c.size[1] * c.size[2]])
    push!(constraints, new_constraint)
    unique_constr[(c.head, c.children_hash)] = (objective, constraints)
  end
  return unique_constr[(c.head, c.children_hash)]
end

==(lhs::AbstractExpr, rhs::AbstractExpr) = EqConstraint(lhs, rhs)
==(lhs::AbstractExpr, rhs::Value) = ==(lhs, Constant(rhs))
==(lhs::Value, rhs::AbstractExpr) = ==(Constant(lhs), rhs)


### Linear inequality constraints
type LtConstraint <: Constraint
  head::Symbol
  children_hash::Uint64
  lhs::AbstractExpr
  rhs::AbstractExpr
  size::(Int64, Int64)

  function LtConstraint(lhs::AbstractExpr, rhs::AbstractExpr)
    if lhs.size == rhs.size || lhs.size == (1, 1)
      sz = rhs.size
    elseif rhs.size == (1, 1)
      sz = lhs.size
    else
      error("Cannot create inequality constraint between expressions of size $(lhs.size) and $(rhs.size)")
    end
    return new(:(<=), hash((lhs, rhs)), lhs, rhs, sz)
  end
end

function vexity(c::LtConstraint)
  vexity = vexity(lhs) + (-vexity(rhs))
  if vexity == ConcaveVexity()
    vexity = NotDcp()
  end
  return vexity
end

function conic_form(c::LtConstraint, unique_constr)
  if !((c.head, c.children_hash) in unique_constr)
    expr = c.rhs - c.lhs
    objective, constraints = conic_form(expr, unique_constr)
    new_constraint = ConicConstr([objective], :NonNeg, [c.size[1] * c.size[2]])
    push!(constraints, new_constraint)
    unique_constr[(c.head, c.children_hash)] = (objective, constraints)
  end
  return unique_constr[(c.head, c.children_hash)]
end

<=(lhs::AbstractExpr, rhs::AbstractExpr) = LtConstraint(lhs, rhs)
<=(lhs::AbstractExpr, rhs::Value) = <=(lhs, Constant(rhs))
<=(lhs::Value, rhs::AbstractExpr) = <=(Constant(lhs), rhs)

type GtConstraint <: Constraint
  head::Symbol
  children_hash::Uint64
  lhs::AbstractExpr
  rhs::AbstractExpr
  size::(Int64, Int64)

  function GtConstraint(lhs::AbstractExpr, rhs::AbstractExpr)
    if lhs.size == rhs.size || lhs.size == (1, 1)
      sz = rhs.size
    elseif rhs.size == (1, 1)
      sz = lhs.size
    else
      error("Cannot create inequality constraint between expressions of size $(lhs.size) and $(rhs.size)")
    end
    return new(:(>=), hash((lhs, rhs)), lhs, rhs, sz)
  end
end

function vexity(c::GtConstraint)
  vexity = vexity(lhs) + (-vexity(rhs))
  if vexity == ConvexVexity()
    vexity = NotDcp()
  end
  return vexity
end

function conic_form(c::GtConstraint, unique_constr)
  if !((c.head, c.children_hash) in unique_constr)
    expr = c.lhs - c.rhs
    objective, constraints = conic_form(expr, unique_constr)
    new_constraint = ConicConstr([objective], :NonNeg, [c.size[1] * c.size[2]])
    push!(constraints, new_constraint)
    unique_constr[(c.head, c.children_hash)] = (objective, constraints)
  end
  return unique_constr[(c.head, c.children_hash)]
end

>=(lhs::AbstractExpr, rhs::AbstractExpr) = GtConstraint(lhs, rhs)
>=(lhs::AbstractExpr, rhs::Value) = >=(lhs, Constant(rhs))
>=(lhs::Value, rhs::AbstractExpr) = >=(Constant(lhs), rhs)


### Positive semidefinite cone constraint
type SDPConstraint <: Constraint
  head::Symbol
  children_hash::Uint64
  lhs::AbstractExpr
  size::(Int64, Int64)

  function SDPConstraint(lhs::AbstractExpr)
    sz = lhs.size
    if sz[1] != sz[2]
      error("Positive semidefinite expressions must be square")
    end
    return new(:sdp, hash(lhs), lhs, sz)
  end
end

function vexity(c::SDPConstraint)
  vexity = vexity(c.lhs)
  if vexity == AffineVexity() || vexity == ConstVexity()
    return AffineVexity()
  else
    return NotDCP()
  end
end

function conic_form(c::SDPConstraint, unique_constr)
  if !((c.head, c.children_hash) in unique_constr)
    objective, constraints = conic_form(c.lhs, unique_constr)
    new_constraint = ConicConstr([objective], :SDP, [c.size[1] * c.size[2]])
    push!(constraints, new_constraint)
    unique_constr[(c.head, c.children_hash)] = (objective, constraints)
  end
  return unique_constr[(c.head, c.children_hash)]
end

isposdef(x::AbstractExpr) = SDPConstraint(x)


function +{T<:Constraint, T2<:Constraint}(constraints_one::Array{T}, constraints_two::Array{T2})
  constraints = append!(Constraint[], constraints_one)
  return append!(constraints, constraints_two)
end
+(constraint_one::Constraint, constraint_two::Constraint) = [constraint_one] + [constraint_two]
+{T<:Constraint}(constraint_one::Constraint, constraints_two::Array{T}) =
  [constraint_one] + constraints_two
+{T<:Constraint}(constraints_one::Array{T}, constraint_two::Constraint) =
  constraints_one + [constraint_two]
