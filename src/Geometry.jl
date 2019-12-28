# Geometric Utilities

export show_cs

show_cs(p, scale=1) =
    let rcyl = scale/10
        rcon = scale/5
        lcyl = scale
        lcon = scale/5
        px = add_x(p, 3*lcyl)
        py = add_y(p, 2*lcyl)
        pz = add_z(p, 1*lcyl)
        union(cylinder(p, rcyl, px),
              cone(px, rcon, add_x(px, lcon)),
              cylinder(p, rcyl, py),
              cone(py, rcon, add_y(py, lcon)),
              cylinder(p, rcyl, pz))
    end

project_to_world(surf) =
    transform(surf, inverse_transformation(frame_at(surf, 0, 0)))

#project_to_world(surface_polygon(xyz(1,1,1), xyz(10,1,1), xyz(10,1,5), xyz(1,1,5)))

#=

Given a poligonal line described by its vertices, we need to compute another
polygonal line that is parallel to the first one.

=#

v_in_v(v0, v1) =
  let v = v0 + v1
    v*dot(v0, v0)/dot(v, v0)
  end

rotated_v(v, alpha) =
  vpol(pol_rho(v), pol_phi(v) + alpha)

centered_rectangle(p0, w, p1) =
  let v0 = p1 - p0,
      v1 = rotated_v(v0, pi/2),
      c = loc_from_o_vx_vy(p0, v0, v1)
    rectangle(c-vy(w/2, c.cs), distance(p0, p1), w)
  end

offset_vertices(ps::Locs, d::Real, closed) =
  let qs = closed ? [ps[end], ps..., ps[1]] : ps,
      vs = map((p0, p1) -> rotated_v(unitized(p1 - p0)*d, pi/2), qs[2:end], qs[1:end-1]),
      ws = map(v_in_v, vs[1:end-1], vs[2:end])
    map(+, ps, closed ? ws : [vs[1], ws..., vs[end]])
  end

offset(path::Union{Path,Shape}, d::Real) = d == 0 ? path : nonzero_offset(path, d)
nonzero_offset(path::RectangularPath, d::Real) =
  rectangular_path(add_xy(path.corner, -d, -d), path.dx + 2d, path.dy + 2d)

nonzero_offset(path::OpenPolygonalPath, d::Real) =
  d == 0 ? path : open_polygonal_path(offset_vertices(path.vertices, d, false))
nonzero_offset(path::ClosedPolygonalPath, d::Real) = closed_polygonal_path(offset_vertices(path.vertices, d, true))
nonzero_offset(l::Line, d::Real) = line(offset(l.vertices, d, false))
nonzero_offset(path::CircularPath, d::Real) = circular_path(path.center, path.radius + d)

export offset

# Polygon combination

closest_vertices_indexes(pts1, pts2) =
  # This is a brute force method. There are better algorithms to do this.
  let min_dist = Inf,
      min_i = nothing,
      min_j = nothing
    for (i, pt1) in enumerate(pts1)
      for (j, pt2) in enumerate(pts2)
        let dist = distance(pt1, pt2)
          if dist < min_dist
            min_dist = dist
            min_i = i
            min_j = j
          end
        end
      end
    end
    min_i, min_j
  end

#=
using Test
pts1 = regular_polygon_vertices(4, xy(1,2), 4)
pts2 = regular_polygon_vertices(4, xy(2,2), 1)
pts3 = regular_polygon_vertices(5, xy(1,4), 1)
pts4 = regular_polygon_vertices(6, xy(0,1), 1)

polygon(pts1)
polygon(pts2)
polygon(pts3)
polygon(pts4)

@test closest_vertices_indexes(pts1, pts2) == (1,1)
@test closest_vertices_indexes(pts1, pts3) == (2,2)
@test closest_vertices_indexes(pts1, pts4) == (4,6)
@test closest_vertices_indexes(pts2, pts3) == (2,5)
=#

point_in_segment(r, p, q) =
  let pr = r-p,
      pq = q-p,
      rx = cx(pr)/cx(pq),
      ry = cy(pr)/cy(pq)
    isapprox(rx, ry) && isapprox(ry, cz(pr)/cz(pq))
  end

collinear_segments(p1, p2, q1, q2) =
  point_in_segment(q1, p1, p2) &&
  point_in_segment(q2, p1, p2)

collinear_vertices_indexes(pts1, pts2) =
  for (i1, p1) in enumerate(pts1)
    let i2 = (i1+1)%length(pts1),
        p2 = pts1[i2]
      for (j1, q1) in enumerate(pts2)
        let j2 = (j1+1)%length(pts2),
            q2 = pts2[j2]
          if collinear_segments(p1, p2, q1, q2)
            return (i1, j1)
          end
        end
      end
    end
  end

subtract_polygon_vertices(pts1, pts2) =
  let ij = collinear_vertices_indexes(pts1, pts2)
    isnothing(ij) ?
      inject_polygon_vertices_at_indexes(pts1, pts2, closest_vertices_indexes(pts1, pts2)) :
      splice_polygon_vertices_at_indexes(pts1, pts2, ij)
  end

inject_polygon_vertices_at_indexes(pts1, pts2, (i, j)) =
  [pts1[1:i]..., reverse([pts2[j:end]..., pts2[1:j]...])..., pts1[i:end]...]

export closest_vertices_indexes, inject_polygon_vertices_at_indexes, subtract_polygon_vertices

#=
pts1 = subtract_polygon_vertices(pts1, pts2)
pts1 = subtract_polygon_vertices(pts1, pts3)
pts1 = subtract_polygon_vertices(pts1, pts4)
polygon(pts1)
for (i,p) in enumerate(pts1)
  text(string(i), p, 0.1)
  sleep(1)
end
=#

# Intersection

segments_intersection(p0, p1, p2, p3) =
  let denom = (p3.y - p2.y)*(p1.x - p0.x) - (p3.x - p2.x)*(p1.y - p0.y)
    if denom == 0
      nothing
    else
      let u = ((p3.x - p2.x)*(p0.y - p2.y) - (p3.y - p2.y)*(p0.x - p2.x))/denom,
          v = ((p1.x - p0.x)*(p0.y - p2.y) - (p1.y - p0.y)*(p0.x - p2.x))/denom
        if 0 <= u <= 1 && 0 <= v <= 1
          xy(p0.x + u*(p1.x - p0.x), p0.y + u*(p1.y - p0.y))
        else
          nothing
        end
      end
    end
  end

lines_intersection(p0, p1, p2, p3) =
  let denom = (p3.y - p2.y)*(p1.x - p0.x) - (p3.x - p2.x)*(p1.y - p0.y)
    if denom == 0
      nothing
    else
      let u = ((p3.x - p2.x)*(p0.y - p2.y) - (p3.y - p2.y)*(p0.x - p2.x))/denom,
          v = ((p1.x - p0.x)*(p0.y - p2.y) - (p1.y - p0.y)*(p0.x - p2.x))/denom
        xy(p0.x + u*(p1.x - p0.x), p0.y + u*(p1.y - p0.y))
      end
    end
  end
