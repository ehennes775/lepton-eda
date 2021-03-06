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

(define-module (netlist schematic-component)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-9)
  #:use-module (srfi srfi-9 gnu)
  #:use-module (netlist package-pin)
  #:export-syntax (make-schematic-component schematic-component?
                   schematic-component-id set-schematic-component-id!
                   schematic-component-refdes set-schematic-component-refdes!
                   schematic-component-tag set-schematic-component-tag!
                   schematic-component-sources set-schematic-component-sources!
                   schematic-component-object set-schematic-component-object!
                   schematic-component-iattribs set-schematic-component-iattribs!
                   schematic-component-attribs set-schematic-component-attribs!
                   schematic-component-net-maps set-schematic-component-net-maps!
                   schematic-component-pins set-schematic-component-pins!
                   schematic-component-port set-schematic-component-port!
                   schematic-component-subschematic set-schematic-component-subschematic!)

  #:export (schematic-component-attributes
            schematic-component-attribute
            schematic-component-graphical?
            schematic-component-nc?
            schematic-component-subcircuit?
            set-schematic-component-printer!
            set-schematic-component-pins/parent!))

(define-record-type <schematic-component>
  (make-schematic-component id refdes tag sources object iattribs attribs net-maps pins port subschematic)
  schematic-component?
  (id schematic-component-id set-schematic-component-id!)
  (refdes schematic-component-refdes set-schematic-component-refdes!)
  (tag schematic-component-tag set-schematic-component-tag!)
  (sources schematic-component-sources set-schematic-component-sources!)
  (object schematic-component-object set-schematic-component-object!)
  (iattribs schematic-component-iattribs set-schematic-component-iattribs!)
  (attribs schematic-component-attribs set-schematic-component-attribs!)
  (net-maps schematic-component-net-maps set-schematic-component-net-maps!)
  (pins schematic-component-pins set-schematic-component-pins!)
  (port schematic-component-port set-schematic-component-port!)
  (subschematic schematic-component-subschematic set-schematic-component-subschematic!))

;;; Sets default printer for <schematic-component>
(set-record-type-printer!
 <schematic-component>
 (lambda (record port) (format port "#<geda-schematic-component ~A>" (schematic-component-id record))))

(define (set-schematic-component-printer! format-string . args)
  "Adjust pretty-printing of <schematic-component> records.
FORMAT-STRING must be in the form required by the procedure
`format'. The following ARGS may be used:
  'id
  'refdes
  'tag
  'sources
  'object
  'iattribs
  'attribs
  'net-maps
  'pins
  'port
  'subschematic
Any other unrecognized argument will lead to yielding '?' in the
corresponding place.
Example usage:
  (set-schematic-component-printer! \"<schematic-component-~A (~A)>\" 'id 'refdes)"
  (set-record-type-printer!
   <schematic-component>
   (lambda (record port)
     (apply format port format-string
            (map
             (lambda (arg)
               (match arg
                 ('id (schematic-component-id record))
                 ('refdes (schematic-component-refdes record))
                 ('tag (schematic-component-tag record))
                 ('sources (schematic-component-sources record))
                 ('object (schematic-component-object record))
                 ('iattribs (schematic-component-iattribs record))
                 ('attribs (schematic-component-attribs record))
                 ('net-maps (schematic-component-net-maps record))
                 ('pins (schematic-component-pins record))
                 ('port (schematic-component-port record))
                 ('subschematic (schematic-component-subschematic record))
                 (_ #\?)))
             args)))))


(define (schematic-component-attributes component name)
  "Returns the list of attached attributes called NAME for
COMPONENT. NAME must be a Scheme symbol (not string). If no
attached attributes found, returns the list of inherited
attributes with the same name. If neither attached nor inherited
attributes have been found, returns #f."
  (or (assq-ref (schematic-component-attribs component) name)
      (assq-ref (schematic-component-iattribs component) name)))


(define (schematic-component-attribute component name)
  "Returns first attached attribute of COMPONENT called NAME. NAME
must be a Scheme symbol (not string). If no attached attribute
found, returns first inherited attribute with NAME. If neither
attached nor inherited attribute found, returns #f."
  (and=> (schematic-component-attributes component name) car))


(define (schematic-component-attribute-string=? component name value)
  "Returns #t if COMPONENT has attribute NAME equal to VALUE,
otherwise returns #f. NAME must be a symbol, while VALUE should be
a string."
  (and=> (schematic-component-attribute component name)
         (lambda (x) (string=? x value))))


(define (schematic-component-graphical? component)
  "Returns #t if COMPONENT is graphical, that is, it has attribute
\"graphical=1\", otherwise returns #f."
  (schematic-component-attribute-string=? component 'graphical "1"))


(define (schematic-component-nc? component)
  "Returns #t if COMPONENT is 'no-connect' component, that is, it
has attribute \"symbol=nc\". Otherwise returns #f."
  (or (schematic-component-attribute-string=? component 'symbol "nc")
      ;; Obsolete "no-connect" component definition.
      (and (schematic-component-graphical? component)
           (schematic-component-attribute-string=? component 'device "DRC_Directive")
           (schematic-component-attribute-string=? component 'value "NoConnection"))))


(define (schematic-component-subcircuit? component)
  "Returns #t if COMPONENT is composite, that is, it has
underlying subcircuit defined by its \"source=\"
attributes. Otherwise returns #f."
  (not (not (schematic-component-sources component))))


(define (set-schematic-component-pins/parent! component pins)
  "Sets COMPONENT field [pins] to PINS and, for each pin in PINS,
sets the component to be its parent component."
  (define (set-pin-parent! pin)
    (force (set-package-pin-parent-component! pin component)))

  (for-each set-pin-parent! pins)
  (set-schematic-component-pins! component pins))
