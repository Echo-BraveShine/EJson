#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <cstring>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static void set_window_icon(GtkWindow* window, const gchar* assets, bool dark) {
  g_autofree gchar* path = g_build_filename(
      assets, "assets", "branding", dark ? "logo_dark.png" : "logo_light.png",
      nullptr);
  g_autoptr(GError) error = nullptr;
  if (!gtk_window_set_icon_from_file(window, path, &error)) {
    g_warning("Could not load EJson window icon: %s", error->message);
  }
}

static void appearance_call(FlMethodChannel*, FlMethodCall* call,
                            gpointer user_data) {
  auto* view = FL_VIEW(user_data);
  FlValue* args = fl_method_call_get_args(call);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (std::strcmp(fl_method_call_get_name(call), "setDarkAppearance") != 0) {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  } else if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_BOOL) {
    response = FL_METHOD_RESPONSE(fl_method_error_response_new(
        "invalid_appearance", "Expected a boolean", nullptr));
  } else {
    const bool dark = fl_value_get_bool(args);
    auto* widget = GTK_WIDGET(view);
    g_object_set(gtk_widget_get_settings(widget),
                 "gtk-application-prefer-dark-theme", dark, nullptr);
    auto* window = GTK_WINDOW(gtk_widget_get_toplevel(widget));
    auto* header = gtk_window_get_titlebar(window);
    auto* header_style = gtk_widget_get_style_context(header);
    if (dark) {
      gtk_style_context_add_class(header_style, "ejson-dark");
    } else {
      gtk_style_context_remove_class(header_style, "ejson-dark");
    }
    const auto* assets = static_cast<const gchar*>(
        g_object_get_data(G_OBJECT(view), "ejson-assets-path"));
    set_window_icon(window, assets, dark);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  fl_method_call_respond(call, response, nullptr);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Draw the title bar with GTK so it can follow the app's appearance.
  GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
  gtk_widget_show(GTK_WIDGET(header_bar));
  gtk_header_bar_set_title(header_bar, "EJson");
  gtk_header_bar_set_show_close_button(header_bar, TRUE);
  gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  gtk_window_set_title(window, "EJson");
  gtk_style_context_add_class(
      gtk_widget_get_style_context(GTK_WIDGET(header_bar)), "ejson-titlebar");
  g_autoptr(GtkCssProvider) titlebar_styles = gtk_css_provider_new();
  gtk_css_provider_load_from_data(
      titlebar_styles,
      ".ejson-titlebar { background-image: none; background-color: #efeff1; }"
      ".ejson-titlebar, .ejson-titlebar label, "
      ".ejson-titlebar button.titlebutton { color: #252527; }"
      ".ejson-titlebar.ejson-dark { background-color: #2b2b2d; }"
      ".ejson-titlebar.ejson-dark, .ejson-titlebar.ejson-dark label, "
      ".ejson-titlebar.ejson-dark button.titlebutton { color: #f2f2f4; }",
      -1, nullptr);
  gtk_style_context_add_provider_for_screen(
      gtk_window_get_screen(window), GTK_STYLE_PROVIDER(titlebar_styles),
      GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  const gchar* assets = fl_dart_project_get_assets_path(project);
  set_window_icon(window, assets, false);
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  g_object_set_data_full(G_OBJECT(view), "ejson-assets-path",
                         g_strdup(assets), g_free);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "dev.ekko.ejson/appearance", FL_METHOD_CODEC(codec));
  g_object_set_data_full(G_OBJECT(window), "ejson-appearance-channel", channel,
                         g_object_unref);
  fl_method_channel_set_method_call_handler(channel, appearance_call, view,
                                            nullptr);
  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, "#efeff1");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
