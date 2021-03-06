;;; Lepton EDA netlister
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

(define-module (netlist schematic-connection)
  #:use-module (ice-9 match)
  #:use-module (ice-9 receive)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (srfi srfi-9 gnu)
  #:use-module (srfi srfi-26)
  #:use-module (geda attrib)
  #:use-module (geda object)
  #:use-module (lepton page)

  #:export-syntax (make-schematic-connection schematic-connection?
                   schematic-connection-id set-schematic-connection-id!
                   schematic-connection-tag set-schematic-connection-tag!
                   schematic-connection-name set-schematic-connection-name!
                   schematic-connection-override-name set-schematic-connection-override-name!
                   schematic-connection-objects set-schematic-connection-objects!
                   schematic-connection-pins set-schematic-connection-pins!)

  #:export (make-page-schematic-connections
            schematic-connection-add-pin!
            set-schematic-connection-printer!))


(define-record-type <schematic-connection>
  (make-schematic-connection id tag page name override-name objects pins)
  schematic-connection?
  ;; ID. Dunno, why it is here...
  (id schematic-connection-id set-schematic-connection-id!)
  ;; Hierarchical tag.  Well, it is here temporarily (which may
  ;; mean forever :)), to form real hierarchical net names.
  ;; Should be set only for non-hierarchical connections.  Really,
  ;; here could be parent (sub)schematic instead, to gather this
  ;; info by some function.
  (tag schematic-connection-tag set-schematic-connection-tag!)
  ;; Parent page for direct connections.  Has no sense for named
  ;; or hierarchical connections.
  (page schematic-connection-page set-schematic-connection-page!)
  ;; Net name of the connection taken from the "netname="
  ;; attributes of the connection objects.
  (name schematic-connection-name set-schematic-connection-name!)
  ;; Net name of the connection taken from the "net=" attributes
  ;; of the connection objects.
  (override-name schematic-connection-override-name set-schematic-connection-override-name!)
  ;; Objects of the connection.  They can be net or pin primitives.
  (objects schematic-connection-objects set-schematic-connection-objects!)
  ;; Pins of the connections. Now they are <package-pin> objects.
  (pins schematic-connection-pins set-schematic-connection-pins!))


;;; Sets default printer for <schematic-connection>
(set-record-type-printer!
 <schematic-connection>
 (lambda (record port) (format port "#<schematic-connection ~A>" (schematic-connection-id record))))

(define (set-schematic-connection-printer! format-string . args)
  "Adjust pretty-printing of <schematic-connection> records.
FORMAT-STRING must be in the form required by the procedure
`format'. The following ARGS may be used:
  'id
  'tag
  'page
  'name
  'override-name
  'objects
  'pins
Any other unrecognized argument will lead to yielding '?' in the
corresponding place.
Example usage:
  (set-schematic-connection-printer! \"<schematic-connection-~A (~A)>\" 'id 'name)"
  (set-record-type-printer!
   <schematic-connection>
   (lambda (record port)
     (apply format port format-string
            (map
             (lambda (arg)
               (match arg
                 ('id (schematic-connection-id record))
                 ('tag (schematic-connection-tag record))
                 ('page (schematic-connection-page record))
                 ('name (schematic-connection-name record))
                 ('override-name (schematic-connection-override-name record))
                 ('objects (schematic-connection-objects record))
                 ('pins (schematic-connection-pins record))
                 (_ #\?)))
             args)))))

(define (connected-to? object1 object2)
  (not (not (memv object1 (object-connections object2)))))

(define (connected-to-ls? object1 ls)
  (and (not (null? ls))
       (or (connected-to? object1 (car ls))
           (connected-to-ls? object1 (cdr ls)))))

(define (reconnect-groups object groups)
  (define (object-connected-to? group)
    (connected-to-ls? object group))

  (receive (connected unconnected)
      (partition object-connected-to? groups)
    (let ((result
           `(,@unconnected
             ,(if (null? connected)
                  (list object)
                  (apply append (list object) connected)))))
      result)))

;;; Transforms list of objects LS into the list of lists of
;;; interconnected objects.
(define (group-connections ls)
  (fold reconnect-groups '() ls))


(define (schematic-connection->netnames schematic-connection)
  (filter-map (lambda (attrib)
                (and (string=? (attrib-name attrib) "netname")
                     (attrib-value attrib)))
              (append-map object-attribs schematic-connection)))

(define (connections->netname-groups connections)
  (map (lambda (schematic-connection)
         (cons (schematic-connection->netnames schematic-connection) schematic-connection))
       connections))

(define (get-schematic-connection-netname netnames)
  (match netnames
    ((c) c)
    ((a b ...) netnames)))

(define (get-schematic-connection page tag schematic-connection-ls)
  (let* ((netnames (car schematic-connection-ls))
         (objects (cdr schematic-connection-ls))
         (id (object-id (car objects))))
    (make-schematic-connection id
                               tag
                               page
                               ;; netname
                               (if (null? netnames)
                                   '()
                                   (get-schematic-connection-netname netnames))
                               ;; override-netname
                               #f
                               objects
                               '())))

(define (make-page-schematic-connections page tag)
  (define (connection? object)
    (or (net-pin? object)
        (net? object)))

  (define (page-connections page)
    (let ((nets (filter net? (page-contents page)))
          (pins (filter net-pin?
                        (append-map component-contents
                                    (filter component?
                                            (page-contents page))))))
      (append nets pins)))

  (map (cut get-schematic-connection page tag <>)
       (connections->netname-groups (group-connections (page-connections page)))))


(define (schematic-connection-add-pin! connection pin)
  (set-schematic-connection-pins!
   connection
   (cons pin (schematic-connection-pins connection))))
