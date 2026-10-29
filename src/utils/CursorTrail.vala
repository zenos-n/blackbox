// SPDX-License-Identifier: GPL-3.0-or-later

internal class Terminal.CursorTrail : Object {
  internal const int64 DURATION = 180 * TimeSpan.MILLISECOND;
  internal Graphene.Rect target;
  private Graphene.Point origin;
  private int64 started_at = 0;
  private bool initialized = false;

  internal bool active(int64 now) {
    return started_at > 0 && now - started_at < DURATION;
  }

  internal double progress(int64 now) {
    return double.min(1, double.max(0, (double) (now - started_at) / DURATION));
  }

  internal Graphene.Point tail(int64 now) {
    double remaining = 1 - progress(now);
    float weight = (float) (remaining * remaining * remaining);
    var center = target.get_center();
    return Graphene.Point().init(center.x + (origin.x - center.x) * weight,
                                 center.y + (origin.y - center.y) * weight);
  }

  internal bool move(Graphene.Rect next, int64 now) {
    if (!initialized) {
      target = next;
      initialized = true;
      return false;
    }
    if (target.equal(next)) return false;

    var from = active(now) ? tail(now) : target.get_center();
    float dx = (next.origin.x - target.origin.x) / float.max(1, next.size.width);
    float dy = (next.origin.y - target.origin.y) / float.max(1, next.size.height);
    bool animate = active(now) || dx * dx + dy * dy >= 4;
    target = next;
    origin = from;
    started_at = animate ? now : 0;
    return animate;
  }

  internal void reset() {
    started_at = 0;
    initialized = false;
  }
}
