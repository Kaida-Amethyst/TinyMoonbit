///|
pub struct Env[K, V] {
  parent : Env[K, V]?
  data : Map[K, V]
}

///|
pub fn[K, V] Env::new(parent? : Env[K, V]? = None) -> Env[K, V] {
  Env::{ parent, data: Map::new() }
}

///|
pub fn[K : Eq + Hash, V] Env::get(self : Self[K, V], key : K) -> V? {
  match self.data.get(key) {
    Some(value) => Some(value)
    None =>
      match self.parent {
        Some(parent_env) => parent_env.get(key)
        None => None
      }
  }
}

///|
pub fn[K : Eq + Hash, V] Env::contains(self : Self[K, V], key : K) -> Bool {
  match self.data.get(key) {
    Some(_) => true
    None =>
      match self.parent {
        Some(parent_env) => parent_env.contains(key)
        None => false
      }
  }
}

///|
pub fn[K, V] Env::sub_env(self : Self[K, V]) -> Env[K, V] {
  Env::new(parent=Some(self))
}

/////|
//pub fn[K : Eq + Hash + Show, V] Env::get_or_err(
//  self : Self[K, V],
//  key : K
//) -> V raise {
//  match self.data.get(key) {
//    Some(value) => value
//    None =>
//      match self.parent {
//        Some(parent_env) => parent_env.get_or_err(key)
//        None => raise TypeCheckError("Error: Key not found: \{key}")
//      }
//  }
//}
//

///|
pub fn[K : Eq + Hash, V] Env::set(
  self : Self[K, V],
  key : K,
  value : V,
) -> Unit {
  self.data.set(key, value)
}
