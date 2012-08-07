// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2012 Mario Guerriero <mefrio.g@gmail.com>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as
  published    by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses>

  END LICENSE
***/

using Gtk;
using Gst;

namespace Snap {

    public class Pipelines : GLib.Object {

        // Main elements
        DrawingArea drawing_area;
        Element camerabin;
        Gst.Bus bus;

        public signal void mediasaved ();

        public Pipelines (Gtk.DrawingArea area) {

            this.drawing_area = area;

            // Main elements to show the webcam stream
            this.camerabin = ElementFactory.make ("camerabin", "video");

//            I am already testing the effects

            var p = new Pipeline ("effect");
            var jj = ElementFactory.make ("jpegdec", "jj");

            var ff = ElementFactory.make ("ffmpegcolorspace", "ff");
            var e = ElementFactory.make ("frei0r-filter-sobel", "e");

            var f = ElementFactory.make ("ffmpegcolorspace", "f");

            var j = ElementFactory.make ("jpegenc", "j");

            p.add_many (jj, ff, e, f, j);
            p.set_state (State.PLAYING);
            
            //this.camerabin.set_state (State.NULL);
            var caps = Gst.Caps.from_string ("video/x-raw-yuv, width=600, height=600");
            camerabin.set_property ("filter-caps", caps);
            //camerabin.set_property ("video-encoder", ((Element)p));

            bus = this.camerabin.get_bus ();
            bus.set_sync_handler (on_bus_callback);
            bus.add_signal_watch();

        }

        Gst.BusSyncReply on_bus_callback (Gst.Bus bus, Gst.Message message) {
            if (message.get_structure () != null &&
                message.get_structure().has_name("prepare-xwindow-id") &&
                this.drawing_area.get_window () != null)
            {
                var xoverlay = message.src as XOverlay;
                //xoverlay.set_xwindow_id (Gdk.X11Window.get_xid (this.drawing_area.get_window ()));
                return Gst.BusSyncReply.DROP;
            }
            else return Gst.BusSyncReply.PASS;
            
        }

        public void switch_mode (int mode) {
            this.camerabin.set_property ("mode", mode);
        }

        public void play () {
            this.camerabin.set_state (State.PLAYING);
        }

        public void pause () {
            this.camerabin.set_state (State.PAUSED);
        }

        public void stop () {
            this.camerabin.abort_state ();
            this.camerabin.set_state (State.NULL);
            this.camerabin.unref ();
            Gst.deinit ();
        }

        public void take_photo () {
            debug ("Taking a photo...");

            string filename = Resources.get_new_media_filename (MediaType.PHOTO);

            this.camerabin.set_property ("mode", 0);

            debug ("%s", filename);

            camerabin.set_property ("filename", filename);
            bus.message.connect(on_media_saved);
            GLib.Signal.emit_by_name (camerabin, "capture-start");

        }

        public void take_video () {
            debug ("Taking a video...");

            string filename = Resources.get_new_media_filename (MediaType.VIDEO);

            this.camerabin.set_property ("mode", 1);

            debug ("%s", filename);

            camerabin.set_property ("filename", filename);
            bus.message.connect(on_media_saved);
            GLib.Signal.emit_by_name (camerabin, "capture-start");

        }

        public void take_video_stop () {
            debug ("Video taking finish...");

            GLib.Signal.emit_by_name (camerabin, "capture-stop");
        }

        public void on_media_saved (Gst.Bus bus, Gst.Message msg) {
            string msgtype = msg.get_structure().get_name();
            if(msgtype == "image-captured") {
                mediasaved();
                bus.message.disconnect(on_media_saved);
            }
        }

    }
}
