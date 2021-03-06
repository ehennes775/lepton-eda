/* Lepton EDA Schematic Capture
 * Copyright (C) 1998-2010 Ales Hvezda
 * Copyright (C) 1998-2016 gEDA Contributors
 * Copyright (C) 2017-2019 Lepton EDA Contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */
#include <config.h>
#include <version.h>

#include <stdio.h>
#ifdef HAVE_STRING_H
#include <string.h>
#endif
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

#include <glib.h>

#include "gschem.h"

#ifdef HAVE_LOCALE_H
#include <locale.h>
#endif



static gboolean
precompile_mode()
{
  return getenv ("LEPTON_SCM_PRECOMPILE") != NULL;
}



static void
precompile_prepare()
{
  setenv ("GUILE_AUTO_COMPILE", "0", 1);
}



static int
precompile_run()
{
  char* scm_precompile_script = getenv ("LEPTON_SCM_PRECOMPILE_SCRIPT");
  g_return_val_if_fail (scm_precompile_script != NULL, 1);

  if (scm_precompile_script != NULL)
  {
    libgeda_init();
    g_register_funcs();
    g_init_window();
    g_init_select();
    g_init_hook();
    g_init_action();
    g_init_attrib();
    g_init_keys();
    g_init_builtins();
    g_init_util();
    scheme_init_undo();

    SCM script = scm_from_utf8_string (scm_precompile_script);
    scm_primitive_load (script);
  }

  return 0;
}



/* These are generated by parse_commandline() */
extern SCM s_pre_load_expr;
extern SCM s_post_load_expr;

typedef struct {
  gschem_atexit_func func;
  gpointer arg;
} gschem_atexit_struct;

static GList *exit_functions = NULL;

/*! \brief Register a function to be called on program exit
 *
 *  \par Function Description
 *  This function registers a function to be called on
 *  program exit. Multiple functions will be executed in
 *  the order they are registered.
 *
 *  \param [in] func a pointer to the function to be registered
 *  \param [in] data an arbitrary argument provided to the function
 *                   when it is called
 */
void gschem_atexit(gschem_atexit_func func, gpointer data)
{
  gschem_atexit_struct *p;

  p = g_new(gschem_atexit_struct, 1);
  p->func = func;
  p->arg = data;
  exit_functions = g_list_append(exit_functions, p);
}

/*! \brief Cleanup gSchem on exit.
 *  \par Function Description
 *  This function cleans up all memory objects allocated during the
 *  gSchem runtime.
 */
void gschem_quit(void)
{
  GList *list;
  gschem_atexit_struct *p;

  /* Call all registered functions in order */
  list = exit_functions;
  while(list != NULL) {
    p = (gschem_atexit_struct *) list->data;
    p->func(p->arg);
    g_free(p);
    list = g_list_next(list);
  }
  g_list_free(exit_functions);

  s_clib_free();
  s_menu_free();
  s_attrib_free();
#ifdef HAVE_LIBSTROKE
  x_stroke_free ();
#endif /* HAVE_LIBSTROKE */
  o_undo_cleanup();

  i_vars_freenames();
  i_vars_libgeda_freenames();

  /* Check whether the main loop is running:
  */
  if (gtk_main_level() == 0)
  {
    exit (0);
  }
  else
  {
    gtk_main_quit();
  }
}

/*! \brief Main Scheme(GUILE) program function.
 *  \par Function Description
 *  This function is the main program called from scm_boot_guile.
 *  It handles initializing all libraries and gSchem variables
 *  and passes control to the gtk main loop.
 */
void main_prog(void *closure, int argc, char *argv[])
{
  int i;
  char *cwd = NULL;
  GschemToplevel *w_current = NULL;
  TOPLEVEL *toplevel = NULL;
  int argv_index;
  char *filename;

#ifdef HAVE_GTHREAD
  /* Gschem isn't threaded, but some of GTK's file chooser
   * backends uses threading so we need to call g_thread_init().
   * GLib requires threading be initialised before any other GLib
   * functions are called. Do it now if its not already setup.  */
  if (!g_thread_supported ()) g_thread_init (NULL);
#endif

#if ENABLE_NLS
  /* This must be the same for all locales */
  setlocale(LC_NUMERIC, "C");
#endif


  /* precompilation:
  */
  if (precompile_mode())
  {
    exit (precompile_run());
  }


  gtk_init(&argc, &argv);

  argv_index = parse_commandline(argc, argv);
  cwd = g_get_current_dir();

  libgeda_init();

  /* create log file right away even if logging is enabled */
  s_log_init ("schematic");

  s_log_message (_("Lepton EDA/lepton-schematic version %1$s%2$s.%3$s git: %4$.7s"),
                 PREPEND_VERSION_STRING,
                 PACKAGE_DOTTED_VERSION,
                 PACKAGE_DATE_VERSION,
                 PACKAGE_GIT_COMMIT);

#if defined(__MINGW32__) && defined(DEBUG)
  fprintf(stderr, _("This is the MINGW32 port.\n"));
#endif

#if DEBUG
  fprintf(stderr, _("Current locale settings: %1$s\n"), setlocale(LC_ALL, NULL));
#endif

  /* init global buffers */
  o_buffer_init();

  /* register guile (scheme) functions */
  g_register_funcs();
  g_init_window ();
  g_init_select ();
  g_init_hook ();
  g_init_action ();
  g_init_attrib ();
  g_init_keys ();
  g_init_builtins ();
  g_init_util ();

  scheme_init_undo();


  /* initialise color map (need to do this before reading rc files */
  x_color_init ();

  o_undo_init();


  scm_dynwind_begin ((scm_t_dynwind_flags) 0);

  /* Run pre-load Scheme expressions */
  g_scm_eval_protected (s_pre_load_expr, scm_current_module ());

  /* Initialize toplevel */
  toplevel = s_toplevel_new ();

  /* Set up default configuration */
  i_vars_init_defaults ();

  /* Set up atexit handlers */
  gschem_atexit (i_vars_atexit_save_cache_config, NULL);

  /* Now read in RC files. */
  g_rc_parse_gtkrc();
  x_rc_parse_gschem (toplevel, NULL);

  /* Set default icon theme and make sure we can find our own icons */
  x_window_set_default_icon();
  x_window_init_icons ();

  /* At end, complete set up of window. */
  x_color_allocate();

  /* Initialize tabbed GUI: */
  x_tabs_init();

  /* Allocate w_current */
  w_current = x_window_new (toplevel);

  g_dynwind_window (w_current);

#ifdef HAVE_LIBSTROKE
  x_stroke_init ();
#endif /* HAVE_LIBSTROKE */

  for (i = argv_index; i < argc; i++) {

    if (g_path_is_absolute(argv[i]))
    {
      /* Path is already absolute so no need to do any concat of cwd */
      filename = g_strdup (argv[i]);
    } else {
      filename = g_build_filename (cwd, argv[i], NULL);
    }

    /*
     * SDB notes:  at this point the filename might be unnormalized, like
     * /path/to/foo/../bar/baz.sch.  Bad filenames will be normalized in
     * f_open (called by x_window_open_page). This works for Linux and MINGW32.
     */

    x_window_open_page(w_current, filename);

    g_free (filename);
  }

  g_free(cwd);


  /* Update the window to show the current page:
  */
  PAGE* page = w_current->toplevel->page_current;

  if (page == NULL)
  {
    page = x_window_open_page (w_current, NULL);
  }

  x_window_set_current_page (w_current, page);


#if DEBUG
  scm_c_eval_string ("(display \"hello guile\n\")");
#endif

  /* Run post-load expressions */
  if (scm_is_false (g_scm_eval_protected (s_post_load_expr, scm_current_module ()))) {
    fprintf (stderr, _("ERROR: Failed to load or evaluate startup script.\n\n"
                       "The lepton-schematic log may contain more information.\n"));
    exit (1);
  }

  /* open up log window on startup */
  if (w_current->log_window == MAP_ON_STARTUP)
  {
    x_widgets_show_log (w_current);
  }

  /* if there were any symbols which had major changes, put up an error */
  /* dialog box */
  major_changed_dialog(w_current);

  scm_dynwind_end ();

  /* enter main loop */
  gtk_main();
}

/*! \brief Main executable entrance point.
 *  \par Function Description
 *  This is the main function for gSchem. It sets up the Scheme(GUILE)
 *  environment and passes control to via scm_boot_guile to
 *  the #main_prog function.
 */
int main (int argc, char *argv[])
{

#if ENABLE_NLS
  setlocale(LC_ALL, "");
  setlocale(LC_NUMERIC, "C");
  bindtextdomain("lepton-schematic", LOCALEDIR);
  textdomain("lepton-schematic");
  bind_textdomain_codeset("lepton-schematic", "UTF-8");
#endif


  if (precompile_mode())
  {
    precompile_prepare();
  }
  else
  {
    set_guile_compiled_path();
  }


#ifdef DEBUG
  printf ("\n");
  printf (" >> lepton-schematic::main(): just before scm_boot_guile():\n");
  printf ("\n");
  printf ("    $GUILE_LOAD_COMPILED_PATH:    %s\n", getenv ("GUILE_LOAD_COMPILED_PATH"));
  printf ("    LEPTON_SCM_PRECOMPILE_DIR:    %s\n", LEPTON_SCM_PRECOMPILE_DIR);
  printf ("    LEPTON_SCM_PRECOMPILE_SCRIPT: %s\n", LEPTON_SCM_PRECOMPILE_SCRIPT);
  printf ("    LEPTON_SCM_PRECOMPILE_CFG:    %s\n", LEPTON_SCM_PRECOMPILE_CFG );
  printf ("\n");
#endif


  scm_boot_guile (argc, argv, main_prog, 0);

  return 0;
}
