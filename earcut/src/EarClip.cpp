#include "EarClip.h"
#include "earcut.h"

using Point = std::array<float, 2>;

namespace godot
{
void EarClip::_register_methods()
{
  register_method("_process", &EarClip::_process);
  register_method("triangulate", &EarClip::triangulate);
  register_property<EarClip, PoolVector2Array>("positions", &EarClip::set_positions, &EarClip::get_positions, PoolVector2Array());
  register_property<EarClip, Array>("rejects", &EarClip::set_rejects, &EarClip::get_rejects, Array());
}

EarClip::EarClip()
{
  // initialize any variables here
  time_passed = 0.0;
}

EarClip::~EarClip()
{
  // add your cleanup here
}

void EarClip::_init()
{
  // initialize any variables here
  time_passed = 0.0;
}

void EarClip::_process(float delta)
{
  time_passed += delta;
}

PoolVector2Array EarClip::triangulate()
{
  std::vector<std::vector<Point>> polygon;  
  std::vector<Point> points;

  for (int i = 0; i < positions.size(); ++i)
  {
    points.push_back({positions[i].x, positions[i].y});
  }

  polygon.push_back(points);

  for (int i = 0; i < rejects.size(); ++i)
  {
    std::vector<Point> rejection_points;
    PoolVector2Array arr = rejects[i];
    
    for (int j = 0; j < arr.size(); ++j)
    {
      rejection_points.push_back({arr[j].x, arr[j].y});
    }
    
    polygon.push_back(rejection_points);    
  }

  std::vector<uint32_t> indices = mapbox::earcut<uint32_t>(polygon);

  PoolVector2Array result;
  PoolVector2Array overall;
  
  overall.append_array (positions);
  
  for (int i = 0; i < rejects.size(); ++i)
  {
    PoolVector2Array arr = rejects[i];
    
    overall.append_array (arr);
  }
    
  overall.append_array (rejects);

  for (uint32_t index : indices)
  {
    result.append(overall[index]);
  }

  return result;
}

void EarClip::set_positions(PoolVector2Array p_pos)
{
  positions = p_pos;
}

PoolVector2Array EarClip::get_positions()
{
  return positions;
}

void EarClip::set_rejects(Array p_pos)
{
  rejects = p_pos;
}

Array EarClip::get_rejects()
{
  return rejects;
}

} // namespace godot