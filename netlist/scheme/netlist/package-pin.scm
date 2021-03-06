;;; Lepton EDA netlister
;;; Copyright (C) 2016-2017 gEDA Contributors
;;; Copyright (C) 2017-2019 Lepton EDA Contributors
;;;
;;; This program is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 2 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program; if not, write to the Free Software
;;; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
;;; MA 02111-1301 USA.

(define-module (netlist package-pin)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-9)
  #:use-module (srfi srfi-9 gnu)

  #:export-syntax (make-package-pin package-pin?
                   package-pin-id set-package-pin-id!
                   package-pin-object set-package-pin-object!
                   package-pin-number set-package-pin-number!
                   package-pin-name set-package-pin-name!
                   package-pin-netname set-package-pin-netname!
                   package-pin-label set-package-pin-label!
                   package-pin-attribs set-package-pin-attribs!
                   package-pin-net-map set-package-pin-net-map!
                   package-pin-nets set-package-pin-nets!
                   package-pin-parent set-package-pin-parent!
                   package-pin-connection set-package-pin-connection!
                   package-pin-named-connection set-package-pin-named-connection!)

  #:export (set-package-pin-printer!
            set-package-pin-parent-component!))

(define-record-type <package-pin>
  (make-package-pin id object number name netname label attribs net-map nets parent connection named-connection)
  package-pin?
  ;; This field is used just for the record representation in
  ;; set-record-type-printer! below.
  (id package-pin-id set-package-pin-id!)
  ;; The underlying primitive pin object.
  (object package-pin-object set-package-pin-object!)
  ;; Corresponds to pin's "pinnumber" attribute.
  (number package-pin-number set-package-pin-number!)
  ;; Corresponds to net name of the net the pin is connected to.
  (name package-pin-name set-package-pin-name!)
  ;; Corresponds to netname= list of the nets the pin is connected to.
  (netname package-pin-netname set-package-pin-netname!)
  ;; Corresponds to pin's "pinlabel" attribute.
  (label package-pin-label set-package-pin-label!)
  ;; The alist representing attributes of the underlying object.
  (attribs package-pin-attribs set-package-pin-attribs!)
  ;; net= attribute mapping for the pin.
  (net-map package-pin-net-map set-package-pin-net-map!)
  ;; The list of <pin-net>'s connected to the pin.
  (nets package-pin-nets set-package-pin-nets!)
  ;; Parent component of the pin.
  (parent package-pin-parent set-package-pin-parent!)
  ;; <schematic-connection> the pin is connected to.
  (connection package-pin-connection set-package-pin-connection!)
  ;; common netname <schematic-connection> the pin is connected to.
  (named-connection package-pin-named-connection set-package-pin-named-connection!))

;;; Sets default printer for <package-pin>
(set-record-type-printer!
 <package-pin>
 (lambda (record port) (format port "#<geda-package-pin ~A>" (package-pin-id record))))

(define (set-package-pin-printer! format-string . args)
  "Adjust pretty-printing of <package-pin> records.
FORMAT-STRING must be in the form required by the procedure
`format'. The following ARGS may be used:
  'id
  'object
  'number
  'name
  'netname
  'label
  'attribs
  'net-map
  'nets
  'parent
  'connection
  'named-connection
Any other unrecognized argument will lead to yielding '?' in the
corresponding place.
Example usage:
  (set-package-pin-printer! \"<package-pin-~A (~A)>\" 'id 'number)"
  (set-record-type-printer!
   <package-pin>
   (lambda (record port)
     (apply format port format-string
            (map
             (lambda (arg)
               (match arg
                 ('id (package-pin-id record))
                 ('object (package-pin-object record))
                 ('number (package-pin-number record))
                 ('name (package-pin-name record))
                 ('netname (package-pin-netname record))
                 ('label (package-pin-label record))
                 ('attribs (package-pin-attribs record))
                 ('net-map (package-pin-net-map record))
                 ('nets (package-pin-nets record))
                 ('parent (package-pin-parent record))
                 ('connection (package-pin-connection record))
                 ('named-connection (package-pin-named-connection record))
                 (_ #\?)))
             args)))))

(define (set-package-pin-parent-component! pin component)
  (delay (set-package-pin-parent! pin component)))
