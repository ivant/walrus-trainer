library utils;

class Tuple<A, B> {
  A fst;
  B snd;

  Tuple(this.fst, this.snd);
  Tuple<B, A> swap() => new Tuple(snd, fst);

}