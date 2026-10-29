/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <gtk/gtk.h>

static inline gboolean
blackbox_accessible_text_get_extents(GtkAccessibleText *text,
                                    guint start,
                                    guint end,
                                    graphene_rect_t *bounds)
{
  GtkAccessibleTextInterface *iface = GTK_ACCESSIBLE_TEXT_GET_IFACE(text);
  return iface->get_extents && iface->get_extents(text, start, end, bounds);
}
