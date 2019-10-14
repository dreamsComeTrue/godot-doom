#ifndef _EARCLIP_H_
#define _EARCLIP_H_

#include <Godot.hpp>
#include <Spatial.hpp>
#include <PoolArrays.hpp>
#include <Array.hpp>

namespace godot
{

class EarClip : public Spatial
{
  GODOT_CLASS(EarClip, Spatial)

private:
  float time_passed;
  PoolVector2Array positions;
  Array rejects;

public:
  static void _register_methods();

  EarClip();
  ~EarClip();

  void _init();
  void _process(float delta);
  PoolVector2Array triangulate ();

  void set_positions(PoolVector2Array p_pos);
  PoolVector2Array get_positions();
  
  void set_rejects(Array p_pos);
  Array get_rejects();  
};

} // namespace godot

#endif
