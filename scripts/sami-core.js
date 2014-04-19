if (typeof (SAMI) === "undefined") var SAMI = {};

/* HTML5 space characters */
SAMI.SpaceChars = /[\x09\x0A\x0C\x0D\x20]+/;

/* --- Class --- */

SAMI.Class = function (constructor, prototype) {
  return SAMI.Subclass (constructor, SAMI.EventTarget, prototype);
}; // Class

SAMI.Class.addClassMethods = function (classObject, methods) {
  new SAMI.Hash (methods).forEach (function (n, v) {
    if (!classObject[n]) {
      classObject[n] = v;
    }
  });
}; // addClassMethods

SAMI.Class.addAliasMethods = function (classObject, methods) {
  for (var n in methods) {
    if (!classObject[n]) {
      classObject.prototype[n]
          = classObject.prototype[methods[n]] ||
              classObject.prototype._super.prototype[methods[n]];
    }
  }
}; // addAliasMethods

SAMI.Class.mix = function (classObject, mixedClass) {
  for (var n in mixedClass.prototype) {
    if (!classObject.prototype[n]) {
      classObject.prototype[n] = mixedClass.prototype[n];
    }
  }
}; // mix

SAMI.Subclass = function (constructor, superclass, prototype) {
  constructor.prototype = new superclass;
  for (var n in prototype) {
    constructor.prototype[n] = prototype[n];
  }
  constructor.prototype.constructor = constructor;
  constructor.prototype._super = superclass;
  return constructor;
}; // Subclass

/* --- Event --- */

SAMI.EventTarget = new SAMI.Subclass (function () {
  
}, function () {}, {
  addEventListener: function (eventType, handler, useCapture) {
    if (useCapture) return;
    if (!this.eventListeners) this.eventListeners = {};
    if (!this.eventListeners[eventType]) {
      this.eventListeners[eventType] = new SAMI.List;
    }
    this.eventListeners[eventType].push (handler);
  }, // addEventListener
  removeEventListener: function (eventType, handler, useCapture) {
    if (useCapture) return;
    if (!this.eventListeners) return;
    if (!this.eventListeners[eventType]) return;
    this.eventListeners[eventType].remove (handler);
  }, // removeEventListener
  dispatchEvent: function (e) {
    if (!this.eventListeners) return;
    var handlers = this.eventListeners[e.type];
    if (!handlers) return;
    e.currentTarget = this;
    e.target = this;
    var preventDefault;
    handlers.forEach (function (handler) {
      if (handler.apply (this, [e])) {
        preventDefault = true;
      }
    });
    return preventDefault || e.isDefaultPrevented ();
  }, // dispatchEvent
  reportError: function (args) {
    var e = new SAMI.Event.Error;
    for (p in args) {
      var n = p;
      if (p == 'type') {
        n = 'errorType';
      }
      e[n] = args[p];
    }
    this.dispatchEvent (e);
  }, // reportError
  die: function (m) {
    throw m;
  } // die
}); // EventTarget

SAMI.Event = new SAMI.Class (function (eventType, canBubble, cancelable) {
  this.type = eventType;
  this.bubbles = canBubble;
  this.cancelable = cancelable;
}, {
  preventDefault: function () {
    this.defaultPrevented = true;
  }, // preventDefault
  isDefaultPrevented: function () {
    return this.defaultPrevented;
  } // isDefaultPrevented
}); // Event

SAMI.Event.Error = new SAMI.Subclass (function () {
  this._super.apply (this, ['error']);
}, SAMI.Event, {
  
}); // Error

SAMI.Event.Browser = new SAMI.Subclass (function (be) {
  if (!be) return; // For inheriting
  be = be || window.event;
  this.browserEvent = be;
  if (be.type == 'datasetchanged' && be.samiEventType) {
    this.type = be.samiEventType;
    this.bubbles = be.samiBubbles;
  } else {
    this.type = be.type;
    this.bubbles = be.bubbles;
  }
  this.cancelable = be.cancelable;
  this.target = be.target || be.srcElement;
}, SAMI.Event, {
  preventDefault: function () {
    this.defaultPrevented = true;
    try {
      if (this.browserEvent.preventDefault) {
        this.browserEvent.preventDefault ();
      } else {
        this.browserEvent.returnValue = false;
      }
    } catch (e) {
      // IE's unknown error
    }
  }, // preventDefault
  isDefaultPrevented: function () {
    if (this.defaultPrevented) {
      return this.defaultPrevented;
    } else if (this.browserEvent.isDefaultPrevented) {
      return this.browserEvent.isDefaultPrevented ();
    } else {
      return !this.browserEvent.returnValue;
    }
  } // isDefaultPrevented
}); // Browser

SAMI.Event.Browser.Custom = new SAMI.Subclass (function (opts) {
  var be;
  if (document.createEvent) {
    be = document.createEvent ('Event');
    be.initEvent (opts.type, opts.bubbles, opts.cancelable);
    this.type = be.type;
    this.bubbles = be.bubbles;
  } else {
    be = document.createEventObject ();
    be.samiBubbles = opts.bubbles || false;
    be.cancelable = opts.cancelable || false;
    be.samiEventType = opts.type;
    this.type = be.samiEventType;
    this.bubbles = be.samiBubbles;
  }
  this.browserEvent = be;
  this.cancelable = be.cancelable;
  if (opts.args) {
    for (var n in opts.args) {
      be[n] = opts.args[n];
    }
  }
}, SAMI.Event.Browser, {
  fireOn: function (el) {
    this.target = el;
    if (el.dispatchEvent) {
      el.dispatchEvent (this.browserEvent);
    } else {
      // IE does not support custom events.  Instead, we fire
      // |ondatasetchanged|, as modern scripts are unlikely relying
      // on outdated databinding feature.
      //
      // |fireEvent| cannot be invoked for elements not part of the document.
      el.fireEvent ('ondatasetchanged', this.browserEvent);
    }
  } // fireOn
}); // Custom

SAMI.Observer = new SAMI.Class (function (target, eventType, onevent, opts) {
  if (!target) return; // For inheriting
  if (typeof (target) == 'string') { // for compatibility
    this.eventType = target;
    this.target = eventType;
  } else {
    this.eventType = eventType;
    this.target = target;
  }
  if (target.addEventListener) {
    this.code = onevent;
  } else if (target.attachEvent) {
    this.code = function (event) {
      onevent (event);
    };
  } else {
    this.code = onevent;
  }
  this.disabled = true;
  if (!opts || !opts.disabled) {
    this.start ();
  }
}, {
  start: function () {
    if (!this.disabled) return;
    if (this.target.addEventListener) {
      this.target.addEventListener (this.eventType, this.code, false);
      this.disabled = false;
    } else if (this.target.attachEvent) {
      this.target.attachEvent ("on" + this.eventType, this.code);
      this.disabled = false;
    }
  }, // start
  stop: function () {
    if (this.disabled) return;
    if (this.target.removeEventListener) {
      this.target.removeEventListener (this.eventType, this.code, false);
      this.disabled = true;
    } else if (this.target.detachEvent) {
      this.target.detachEvent ("on" + this.eventType, this.code);
      this.disabled = true;
    }
  } // stop
}); // Observer

SAMI.Observer.Custom = function (target, eventType, onevent) {
  if (document.dispatchEvent) {
    return new SAMI.Observer (target, eventType, onevent);
  } else {
    return new SAMI.Observer (target, 'datasetchanged', function (event) {
      if (event.samiEventType && event.samiEventType == eventType) {
        if (!event.samiBubbles) {
          if (event.srcElement != target) return;
        }
        onevent.apply (this, arguments);
        event.returnValue = false;
      }
    });
  }
};

new SAMI.Observer ('load', window, function () {
  SAMI.windowLoaded = true;
});

/* --- Hash --- */

SAMI.Hash = new SAMI.Class (function (hash) {
  this.hash = hash || {};
}, {
  forEach: function (code) {
    for (var n in this.hash) {
      var r = code (n, this.hash[n]);
      if (r && r.stop) break;
    }
  }, // forEach
  mapToList: function (code) {
    var l = new SAMI.List;
    for (var n in this.hash) {
      var r = code (n, this.hash[n]);
      l.push (r);
    }
    return l;
  }, // mapToList
  clone: function (code) {
    var newHash = {};
    this.forEach (function (n, v) {
      newHash[n] = v;
    });
    return new this.constructor (newHash);
  }, // clone
  
  // Obsolete
  getNamedItem: function (n) {
    return this.hash[n];
  }, // getNamedItem
  // Obsolete
  setNamedItem: function (n, v) {
    return this.hash[n] = v;
  }, // setNamedItem

  get: function (n) {
    return this.hash[n];
  }, // get
  has: function (n) {
    return this.hash[n] !== undefined;
  }, // has
  set: function (n, v) {
    this.hash[n] = v;
  }, // set

  getNames: function () {
    var r = new SAMI.List;
    for (var n in this.hash) {
      r.push (n);
    }
    return r;
  }, // getNames

  getByNames: function (names) {
    var self = this;
    return names.forEach (function (name) {
      var value = self.getNamedItem (name);
      if (value != null) {
        return new SAMI.List.Return (value);
      } else {
        return null;
      }
    });
  } // getByNames
}); // Hash

/* --- List --- */

SAMI.List = new SAMI.Class (function (arrayLike) {
  if (arrayLike instanceof SAMI.List) {
    this.list = arrayLike.list;
  } else {
    this.list = arrayLike || [];
  }
}, {
  getLength: function () {
    return this.list.length;
  }, // getLength

  getFirst: function () {
    if (this.list.length) {
      return this.list[0];
    } else {
      return null;
    }
  }, // getFirst
  getLast: function () {
    if (this.list.length) {
      return this.list[this.list.length - 1];
    } else {
      return null;
    }
  }, // getLast

  forEach: function (code) {
    var length = this.list.length;
    for (var i = 0; i < length; i++) {
      var r = code (this.list[i]);
      if (r && r.stop) return r.returnValue;
    }
    return null;
  }, // forEach
  forEachReverse: function (code) {
    var length = this.list.length;
    for (var i = length - 1; i >= 0; i--) {
      var r = code (this.list[i]);
      if (r && r.stop) return r.returnValue;
    }
    return null;
  }, // forEachReverse

  forEachAsync: function (code, ondone, opts) {
    var list = [];
    var length = this.list.length;
    if (length == 0) {
      if (ondone) ondone (undefined);
      return;
    }
    for (var i = 0; i < length; i++) {
      list.push (this.list[i]);
    }
    var n = (opts ? opts.n : null) || 1000;
    var nOrig = n;
    var delay = (opts ? opts.delay : null) || 0;
    var loopCode = function () {
      while (list.length && (n > 0)) {
        var r = code (list.shift ());
        if (r && r.stop) return ondone (r.returnValue);
        n--;
      }
      if (list.length) {
        n = nOrig;
        setTimeout (loopCode, delay);
      } else {
        if (ondone) ondone (undefined);
      }
    };
    setTimeout (loopCode, delay);
  }, // forEachAsync

  map: function (code) {
    var newList = new this.constructor;
    var length = this.list.length;
    for (var i = 0; i < length; i++) {
      newList.push (code (this.list[i]));
    }
    return newList;
  }, // map
  mapToHash: function (code) {
    var newHash = new SAMI.Hash;
    var length = this.list.length;
    for (var i = 0; i < length; i++) {
      var nv = code (this.list[i]);
      newHash.setNamedItem (nv[0], nv[1]);
    }
    return newHash;
  }, // mapToHash

  numberToInteger: function () {
    var newList = [];
    this.forEach (function (item) {
      if (typeof item === "number") {
        newList.push (Math.floor (item));
      } else {
        newList.push (item);
      }
    });
    return new this.constructor (newList);
  }, // numberToInteger
    
  clone: function () {
    var newList = [];
    this.forEach (function (item) {
      newList.push (item);
    });
    return new this.constructor (newList);
  }, // clone
  
  grep: function (code) {
    var newList = [];
    this.forEach (function (item) {
      if (code (item)) {
        newList.push (item);
      }
    });
    return new this.constructor (newList);
  }, // grep
  onlyNonNull: function () {
    return this.grep (function (item) {
      return item != null; /* Intentionally "!=" */
    });
  }, // onlyNonNull

  uniq: function (eq) {
    if (!eq) eq = function (i1, i2) { return i1 === i2 };
    var prevItems = [];
    return this.grep (function (item) {
      for (var i = 0; i < prevItems.length; i++) {
        if (eq (item, prevItems[i])) {
          return false;
        }
      }
      prevItems.push (item);
      return true;
    });
  }, // uniq

  join: function () {
    return this.list.join.apply (this.list, arguments);
  }, // join

  sort: function (code) {
    var l = code ? this.list.sort (code) : this.list.sort ();
    return new this.constructor (l);
  }, // sort
  
  getFirstMatch: function (code) {
    return this.forEach (function (item) {
      if (code (item)) {
        return new SAMI.List.Return (item);
      }
    });
  }, // getFirstMatch
  has: function (value, eq) {
    if (!eq) eq = function (i1, i2) { return i1 === i2 };
    return this.forEach (function (item) {
      if (eq (item, value)) {
        return new SAMI.List.Return (true);
      }
    }) || false;
  }, // has
  
  switchByElementType: function () {
    var cases = new SAMI.List (arguments);
    this.forEach (function (n) {
      cases.forEach (function (c) {
        if (c.namespaceURI == n.namespaceURI) {
          return new SAMI.List.Return (c.execute (n));
        }
      });
    });
  }, // switchByElementType
  
  // destructive
  push: function (item) {
    this.list.push (item);
  }, // push
  // destructive
  unshift: function (v) {
    return this.list.unshift (v);
  }, // unshift

  // destructive
  pushCloneOfLast: function () {
    this.list.push (this.getLast ().clone ());
  }, // pushCloneOfLast

  // destructive
  prepend: function (list) {
    var self = this;
    list.forEachReverse (function (n) {
      self.list.unshift (n);
    });
    return this;
  }, // prepend

  // destructive
  append: function (list) {
    var self = this;
    list.forEach (function (n) {
      self.list.push (n);
    });
    return this;
  }, // append
  
  // destructive
  shift: function () {
    return this.list.shift ();
  }, // shift
  // destructive
  pop: function () {
    return this.list.pop ();
  }, // pop

  // destructive
  remove: function (removedItem) {
    var length = this.list.length;
    for (var i = length - 1; i >= 0; --i) {
      var item = this.list[i];
      if (item == removedItem) { // Intentionally "=="
        this.list.splice (i, 1);
      }
    }
  }, // remove

  // destructive
  clear: function () {
    this.list.splice (0, this.list.length);
  } // clear
  
}); // List

SAMI.Class.addClassMethods (SAMI.List, {
  spaceSeparated: function (v) {
    return new SAMI.List ((v || '').split (SAMI.SpaceChars)).grep (function (v) {
      return v.length;
    });
  }, // spaceSeparated

  getCommonItems: function (l1, l2, cb, eq) {
    if (!eq) eq = function (i1, i2) { return i1 === i2 };

    var common = new SAMI.List;

    l1 = l1.grep (function (i1) {
      var hasI1;
      l2 = l2.grep (function (i2) {
        if (eq (i1, i2)) {
          common.push (i1);
          hasI1 = true;
          return false;
        } else {
          return true;
        }
      });
      return !hasI1;
    });

    cb (common, l1, l2);
  } // getCommonItems
}); // List class methods

SAMI.List.Return = new SAMI.Class (function (rv) {
  this.stop = true;
  this.returnValue = rv;
}, {
  
}); // Return

SAMI.List.SwitchByLocalName = new SAMI.Class (function (ns, cases, ow) {
  this.namespaceURI = ns;
  this.cases = cases;
  this.otherwise = ow || function (n) { };
}, {
  execute: function (n) {
    for (var ln in this.cases) {
      if (SAMI.Element.matchLocalName (n, ln)) {
        return this.cases[ln] (n);
      }
    }
    return this.otherwise (n);
  }
});

/* --- Set --- */

SAMI.Set = {};

SAMI.Set.Unordered = new SAMI.Class (function () {
  // this.caseInsensitive
}, {
  addFromList: function (list) {
    var self = this;
    list.forEach (function (name) {
      if (self.caseInsensitive) name = name.toLowerCase ();
      self['value-' + name] = true;
    });
  }, // addFromList

  has: function (name) {
    if (this.caseInsensitive) name = name.toLowerCase ();
    return this['value-' + name] !== undefined;
  } // has
}); // Unordered

/* --- Integer --- */

if (!SAMI.Integer) SAMI.Integer = {};

SAMI.Class.addClassMethods (SAMI.Integer, {
  toPaddedHex: function (i, n) {
    var h = parseInt (i).toString (16).toUpperCase ();
    while (h.length < n) {
      h = '0' + h;
    }
    return h;
  } // toPaddedHex
}); // SAMI.Integer class methods

/* --- String --- */

if (!SAMI.String) SAMI.String = {};

SAMI.Class.addClassMethods (SAMI.String, {
  uUnescape: function (s) {
    return s.replace (/\\(?:u([0-9A-Fa-f]{4})|U([0-9A-Fa-f]{8}))/g, function (_, c, d) {
      c = parseInt ('0x' + (c || d));
      if (c > 0x10FFFF) {
        return "\uFFFD";
      } else if (c > 0xFFFF) {
        c -= 0x10000;
        var h = 55296 // 0b1101100000000000
            | (((c & 1047552) >> 10)); // 0b11111111110000000000
        var l = 56320 // 0b1101110000000000
            | (c & 1023); // 0b1111111111
        return String.fromCharCode (h, l);
      } else {
        return String.fromCharCode (c);
      }
    });
  }, // uUnescape

  toJSStringLiteral: function (s) {
    s += '';
    if (s.toSource) {
      return s.toSource ();
    } else {
      s = s.replace (/['\\]/g, '\\$1').replace (/\u000D/g, '\\u000D').replace (/\u000A/g, '\\u000A');
      return "'" + s + "'";
    }
  }, // toJSStringLiteral

  toCSSIDENT: function (s) {
    s += '';
    s = s.replace (/[\u0000-\u002C\u002E\u002F\u003A-\u0040\u005B-\u005E\u0060\u007A-\u007F]|^[0-9-]/g, function (t) {
      return '\\' + SAMI.Integer.toPaddedHex (t.charCodeAt (0), 6);
    });
    return s;
  }, // toCSSIDENT

  htescape: function (s) {
    return s
        .replace (/&/g, '&amp;')
        .replace (/</g, '&lt;')
        .replace (/>/g, '&gt;')
        .replace (/"/g, '&quot;');
  } // htescape
}); // String class methods

SAMI.StringContainer = new SAMI.Class (function () {
  // Abstract
}, {
  appendText: function (s) {
    alert ('appendText: not implemented');
  }, // appendText

  say: function (s) {
    this.appendText (s + "\n");
  }, // say
  sayPrefixed: function (prefix, s) {
    if (s.length) {
      s = prefix + s.replace (/\x0A/g, "\x0A" + prefix);
    }
    this.say (s);
  } // sayPrefixed
}); // StringContainer

SAMI.StringContainer.Element = new SAMI.Subclass (function (el) {
  this.element = el;
}, SAMI.StringContainer, {
  appendText: function (s) {
    var lc = this.element.lastChild;
    if (!lc || lc.nodeType != 3 /* TEXT_NODE */) {
      lc = this.element.appendChild (this.element.ownerDocument.createTextNode (''));
    }

    lc.data += s;
  } // appendText
});

/* --- DOM --- */

if (!SAMI.Node) SAMI.Node = {};

SAMI.Class.addClassMethods (SAMI.Node, {
  querySelector: function (node, selectors) {
    if (node.querySelector) {
      var el;
      try {
        el = node.querySelector (selectors);
      } catch (e) {
        el = null;
      }
      return el;
    } else if (window.uu && uu.css) {
      if (selectors != "") {
        /* NOTE: uu.css return all elements for "" or ",xxx" */
        return uu.css (selectors, node)[0];
      } else {
        return null;
      }
    } else if (window.Ten && Ten.DOM && Ten.DOM.getElementsBySelector) {
      return Ten.DOM.getElementsBySelector (selectors)[0];
    } else {
      return null;
    }
  }, // querySelector
  querySelectorAll: function (node, selectors) {
    if (node.querySelectorAll) {
      var nl;
      try {
        nl = node.querySelectorAll (selectors);
      } catch (e) {
        nl = null;
      }
      return new SAMI.List (nl);
    } else if (self.uu && uu.css) {
      if (selectors != "") {
        /* NOTE: uu.css return all elements for "" or ",xxx". */
        return new SAMI.List (uu.css (selectors, node));
      } else {
        return new SAMI.List;
      }
    } else if (self.Ten && Ten.DOM && Ten.DOM.getElementsBySelector) {
      return new SAMI.List (Ten.DOM.getElementsBySelector (selectors));
    } else {
      return new SAMI.List; // XXX
    }
  }, // querySelectorAll

  getElementsByClassName: function (node, className) {
    if (node.getElementsByClassName) {
      // Live, but applications should not rely on it.
      return new SAMI.List (node.getElementsByClassName (className));
    } else if (self.Ten && Ten.DOM && Ten.DOM.getElementsByClassName) {
      // Not live
      return new SAMI.List (Ten.DOM.getElementsByClassName (className, node));
    } else {
      // Not live
      return SAMI.Node.querySelectorAll (node, '.' + SAMI.String.toCSSIDENT (className));
    }
  }, // getElementsByClassName

  isDescendantOf: function (descendant, ancestor) {
    if (!descendant || !ancestor) return false;
    if (ancestor.contains &&
        ancestor.nodeType == 1 /* ELEMENT_NODE */ &&
        descendant.nodeType == 1 /* ELEMENT_NODE */) {
      return descendant != ancestor && ancestor.contains (descendant);
    } else if (ancestor.compareDocumentPosition) {
      if (ancestor.compareDocumentPosition (descendant)
              & 0x10 /* DOCUMENT_POSITION_CONTAINED_BY */) {
        if (descendant.nodeType != 2 /* ATTRIBUTE_NODE */) {
          return true;
        }
      }
      return false;
    } else {
      while (descendant) {
        descendant = descendant.parentNode;
        if (descendant == ancestor) {
          return true;
        }
      }
      return false;
    }
  } // isDescendantOf
}); // SAMI.Node

SAMI.Document = {};

SAMI.Class.addClassMethods (SAMI.Document, {
  getTheHTMLElement: function (doc) {
    var el = doc.documentElement;
// BUG: XML support
    if (el.nodeName.toUpperCase () == 'HTML') {
      return el;
    } else {
      return null;
    }
  }, // getTheHTMLElement
  getTheHeadElement: function (doc) {
// BUG: XML support
    var el = SAMI.Document.getTheHTMLElement (doc);
    if (!el) return null;
    var elc = el.childNodes;
    for (i = 0; i < elc.length; i++) {
      var cel = elc[i];
      if (cel.nodeName.toUpperCase () == 'HEAD') {
        return cel;
      }
    }
    return null;
  }, // getTheHeadElement

  getClassNames: function (doc) {
// BUG: XML support
    var r = new SAMI.Set.Unordered ();
    r.caseInsensitive = doc.compatMode != 'CSS1Compat';
    
    var docEl = doc.documentElement;
    if (docEl) {
      r.addFromList (SAMI.List.spaceSeparated (docEl.className));
    }

    var bodyEl = doc.body;
    if (bodyEl) {
      r.addFromList (SAMI.List.spaceSeparated (bodyEl.className));
    }
    
    return r;
  } // getClassNames
}); // SAMI.Document class methods

if (!SAMI.Element) SAMI.Element = {};

SAMI.Class.addClassMethods (SAMI.Element, {
  getLocalName: function (el) {
    var localName = el.localName;
    if (!localName) {
      localName = el.nodeName;
      if (el.prefix) {
        localName = localName.substring (el.prefix.length + 1);
      }
    }
    return localName;
  }, // getLocalName
  
  match: function (el, ns, ln) {
    if (el.nodeType !== 1) return false;
    if (el.namespaceURI !== ns) return false;
    return SAMI.Element.matchLocalName (el, ln);
  }, // match
  matchLocalName: function (el, ln) {
    var localName = SAMI.Element.getLocalName (el);
    if (ln instanceof RegExp) {
      if (!localName.match (ln)) return false;
    } else {
      if (localName !== ln) return false;
    }
    return true;
  }, // matchLocalName
  
  getChildElement: function (el, ns, ln) {
    return new SAMI.List (el.childNodes).getFirstMatch (function (item) {
      return SAMI.Element.match (item, ns, ln);
    });
  }, // getChildElement
  getChildElements: function (el, ns, ln) {
    return new SAMI.List (el.childNodes).grep (function (item) {
      return SAMI.Element.match (item, ns, ln);
    });
  }, // getChildElements
  getChildrenClassifiedByType: function (el) {
    var r = new SAMI.ElementHash;
    new SAMI.List (el.childNodes).forEach (function (n) {
      if (n.nodeType == 1) {
        r.getOrCreate (n.namespaceURI, SAMI.Element.getLocalName (n)).push (n);
      } else {
        r.getOrCreate (null, n.nodeType).push (n);
      }
    });
    return r;
  }, // getChildrenClassifiedByType

  getTextContent: function (el) {
    var tc = el.textContent;
    if (tc === undefined) {
      tc = el.innerText;
    }
    return tc;
  }, // getTextContent
  setTextContent: function (el, s) {
    var tc = el.innerText;
    if (tc === undefined) {
      el.textContent = s;
    } else {
      el.innerText = s;
    }
  }, // setTextContent

  isEmpty: function (el) {
    // HTML5 definition of "empty"
    return !new SAMI.List (el.childNodes).forEach (function (n) {
      var nt = n.nodeType;
      if (nt == 1) {
        return new SAMI.List.Return (true /* not empty */);
      } else if (nt == 3 || nt == 4) {
        if (/[^\u0009\u000A\u000C\u000D\u0020]/.test (n.data)) {
          return new SAMI.List.Return (true /* not empty */);
        }
      } else if (nt == 7 || nt == 8) { // comment/pi
        // does not affect emptyness
      } else {
        // We don't support EntityReference.
        return new SAMI.List.Return (true /* not empty */);
      }
    });
  }, // isEmpty
  
  appendText: function (el, s) {
    return el.appendChild (el.ownerDocument.createTextNode (s));
  }, // appendText
  
  appendToHead: function (el) {
    var doc = el.ownerDocument;
    var head = SAMI.Document.getTheHeadElement (doc) || doc.body || doc.documentElement || doc;
    head.appendChild (el);
  }, // appendToHead

  createTemplate: function (doc, node) {
    var df = doc.createDocumentFragment ();
    new SAMI.List (node.childNodes).forEach (function (n) {
      if (n.nodeType == 1) {
        var c = doc.createElement (SAMI.Element.getLocalName (n));
        new SAMI.List (n.attributes).forEach (function (n) {
          c.setAttribute (n.name, n.value);
        });
        c.appendChild (SAMI.Element.createTemplate (doc, n));
        df.appendChild (c);
      } else if (n.nodeType == 3 || n.nodeType == 4) {
        df.appendChild (doc.createTextNode (n.data));
      }
    });
    return df;
  }, // createTemplate
  
  hasAttribute: function (el, localName) {
    if (el.hasAttribute) {
      return el.hasAttribute (localName);
    } else {
      return el.getAttribute (localName) != null;
    }
  }, // hasAttribute
  
  getClassNames: function (el) {
    var classNames = el.className;
    return new SAMI.List (classNames ? classNames.split (SAMI.SpaceChars) : []).grep (function (v) { return v.length });
  }, // getClassNames
  hasClassName: function (el, className) {
    return this.getClassNames (el).has (className);
  }, // hasClassName
  addClassName: function (el, newClassName) {
    el.className = el.className + ' ' + newClassName;
  }, // addClassName
  deleteClassName: function (el, oldClassName) {
    var classNames = el.className.split (SAMI.SpaceChars);
    var newClasses = [];
    for (var n in classNames) {
      if (classNames[n] != oldClassName) {
        newClasses.push (classNames[n]);
      }
    }
    el.className = newClasses.join (' ');
  }, // deleteClassName
  replaceClassName: function (el, oldClassName, newClassName) {
    var classNames = el.className.split (SAMI.SpaceChars);
    var newClasses = [newClassName];
    for (var n in classNames) {
      if (classNames[n] != oldClassName) {
        newClasses.push (classNames[n]);
      }
    }
    el.className = newClasses.join (' ');
  }, // replaceClassName
  
  getIds: function (el) {
    return new SAMI.List (el.id != "" ? [el.id] : []);
  }, // getIds

  /* 
    NR.js <http://suika.fam.cx/www/css/noderect/NodeRect.js> must be loaded
    before the invocation.
  */  
  scroll: function (elements) {
    if (!SAMI.windowLoaded) {
      new SAMI.Observer ('load', window, function () {
        SAMI.Element.scroll (elements);
      });
      return;
    }

    var top = Infinity;
    var left = Infinity;
    var topEl;
    var leftEl;
    elements.forEach (function (el) {
      var rect = NR.Element.getRects (el, window).borderBox;
      if (rect.top < top) {
        top = rect.top;
        topEl = el;
      }
      if (rect.left < left) {
        left = rect.left;
        leftEl = el;
      }
    });

    if (!leftEl && !topEl) {
      return;
    }

    var doc = (leftEl || topEl).ownerDocument;
  
    var rect = NR.View.getViewportRects (window, doc).contentBox;
    if (rect.top <= top && top <= rect.bottom) {
      top = rect.top;
    }
    if (rect.left <= left && left <= rect.right) {
      left = rect.left;
    }

    /*
      Set scroll* of both <html> and <body> elements, to support all of 
      four browsers and two (or three) rendering modes.  This might result
      in confusing the user if both <html> and <body> elements have their
      'overflow' properties specified to 'scroll'.

      Note that this code does not do a good job if the |el| is within an
      |overflow: scroll| element.
    */
    doc.body.scrollTop = top;
    doc.body.scrollLeft = left;
    doc.documentElement.scrollTop = top;
    doc.documentElement.scrollLeft = left;
  } // scroll
}); // Element

SAMI.ElementHash = new SAMI.Class (function () {
  this.items = [];
}, {
  get: function (ns, ln) {
    ns = ns || '';
    if (this.items[ns]) {
      return this.items[ns].getNamedItem (ln) || new SAMI.List;
    } else {
      return new SAMI.List;
    }
  }, // get
  getOrCreate: function (ns, ln) {
    ns = ns || '';
    if (this.items[ns]) {
      var l = this.items[ns].getNamedItem (ln);
      if (!l) this.items[ns].setNamedItem (ln, l = new SAMI.List);
      return l;
    } else {
      var l;
      this.items[ns] = new SAMI.Hash;
      this.items[ns].setNamedItem (ln, l = new SAMI.List);
      return l;
    }
  } // getOrCreate
}); // ElementHash

/* --- Script --- */

SAMI.Script = {};

SAMI.Class.addClassMethods (SAMI.Script, {
  loadScripts: function (urls, onload) {
    urls = new SAMI.List (urls);
    var number = urls.list.length;
    var counter = 0;
    var check = function () {
      if (counter == number) {
        onload ();
      }
    };
    urls.forEach (function (url) {
      if (/\.css(?:\?|$)/.test (url)) {
        SAMI.Style.loadStyle (url, function () {
          counter++;
          check ();
        });
        return;
      }

      var script = document.createElement ('script');
      script.src = url;
      script.onload = function () {
        counter++;
        check ();
        script.onload = null;
        script.onreadystatechange = null;
      };
      script.onreadystatechange = function () {
        if (script.readyState != 'complete' && script.readyState != 'loaded') {
          return;
        }
        counter++;
        check ();
        script.onload = null;
        script.onreadystatechange = null;
      };
      document.body.appendChild (script);
    });
  } // loadScripts
}); // Script class methods

/* --- Style and rendering --- */

SAMI.Style = {};

SAMI.Class.addClassMethods (SAMI.Style, {
  loadStyle: function (url, onload) {
    var link = document.createElement ('link');
    link.rel = 'stylesheet';
    link.href = url;
    if (onload) {
      link.onload = function () {
        onload ();
        link.onload = null;
        link.onreadystatechange = null;
      };
      link.onreadystatechange= function () {
        if (link.readyState != 'complete' && link.readyState != 'loaded') {
          return;
        }
        onload ();
        link.onload = null;
        link.onreadystatechange = null;
      };
    }
    SAMI.Element.appendToHead (link);
  } // loadStyle
}); // Style class methods

SAMI.Viewport = new SAMI.Class (function (window) {
  this.window = window;
}, {
  getElementFromVector: function (vector) {
    if (vector.x < 0 || vector.y < 0) return null;
    var node = this.window.document.elementFromPoint (vector.x, vector.y);
    while (node && (node.nodeType != 1 /* ELEMENT_NODE */)) {
      node = node.parentNode;
    }
    return node; // or |null|
  } // getElementFromVector
}); // Viewport

SAMI.Viewport.top = new SAMI.Viewport (window);

/* --- URL --- */

SAMI.URL = new SAMI.Class (function (urlString) {
  if (urlString instanceof SAMI.URL) {
    return urlString;
  } else if (urlString === undefined) {
    return; // subclassing
  }

  var self = this;
  urlString = urlString.replace (/#([\s\S]*)/, function (_, s) {
    self._fragment = s;
    return '';
  });
  urlString = urlString.replace (/\?([\s\S]*)/, function (_, s) {
    self._query = s;
    return '';
  });
  urlString = urlString.replace (/^([^:\/]+):/, function (_, s) {
    self._scheme = s;
    return '';
  });
  urlString = urlString.replace (/^\/\/([^\/]+)/, function (_, s) {
    s = s.replace (/([^@]*?)(?:(:)([^:]*))?$/, function (_, h, c, p) {
      self._hostName = decodeURIComponent (h); // XXX IPv? addresses
      self._port = c ? p : null;
      return '';
    });
    if (s.length) {
      self._userinfo = s.substring (0, s.length - 1);
    }
    return '';
  });
  self._path = urlString;
}, {

  getScheme: function () {
    return decodeURIComponent (this._scheme).toLowerCase ();
  }, // getScheme
  getURLScheme: function () {
    return this._scheme;
  }, // getURLScheme
  setURLScheme: function (newScheme) {
    this._scheme = newScheme;
  }, // setURLScheme

  getURLHostName: function () {
    return this._hostName != null ? encodeURIComponent (this._hostName) : null;
  }, // getURLHostName
  getHostName: function () {
    return this._hostName;
  }, // getHostName

  getURLHost: function () {
    var h = this.getURLHostName ();
    var p = this._port;
    if (h == null && p != null) {
      return ':' + p;
    } else if (p != null) {
      return h + ':' + p;
    } else {
      return h;
    }
  }, // getURLHost
  setURLHost: function (host) {
    var self = this;
    self._port = null;
    host = host.replace (/:([^:]*)$/, function (_, p) {
      self._port = p;
      return '';
    });
    this._hostName = host;
  }, // setURLHost

  getURLAuthority: function () {
    var s = '';
    var userinfo = this._userinfo;
    var hostname = this.getURLHostName ();
    var port = this._port;
    if (userinfo != null || port != null) {
      hostname = hostname || '';
    }
    if (hostname == null) return null;

    if (userinfo != null) {
      s += userinfo + '@';
    }
    s += hostname;
    if (port != null) {
      s += ':' + port;
    }
    return s;
  }, // getURLAuthority;

  getURLPath: function () {
    return this._path;
  }, // getURLPath
  setURLPath: function (newPath) {
    this._path = newPath;
  }, // setURLPath

  _parseQuery: function () {
    var qp = this._qparams = new SAMI.Hash;
    if (this._query != null) {
      new SAMI.List (this._query.split (/[&;]/)).forEach (function (x) {
        var nv = x.split (/=/, 2);
        qp.set (decodeURIComponent (nv[0]), decodeURIComponent (nv[1] || ''));
      });
    }
    this._query = null;
  }, // _parseQuery
  getQueryParam: function (n) {
    if (!this._qparams) this._parseQuery ();
    return this._qparams.get (n);
  }, // getQueryParam
  setQueryParam: function (n, v) {
    if (!this._qparams) this._parseQuery ();
    if (v != null) this._qparams.set (n, v);
  }, // setQueryParam
  getURLQuery: function () {
    if (this._qparams) {
      var v = this._qparams.mapToList (function (n, v) {
        return encodeURIComponent (n) + '=' + encodeURIComponent (v);
      }).list.join ('&');
      if (v.length) {
        return v;
      } else {
        return null;
      }
    } else {
      return this._query;
    }
  } // getURLQuery
}); // URL

SAMI.URL.prototype.toString = function () {
  var u = '';

  var s = this.getURLScheme ();
  if (s != null) {
    u += s + ':';
  }

  var a = this.getURLAuthority ();
  if (a != null) {
    u += '//' + a;
  }

  var p = this.getURLPath ();
  if (p != null) {
    u += p;
  }

  var q = this.getURLQuery ();
  if (q != null) {
    u += '?' + q;
  }

  if (this._fragment != null) {
    u += '#' + this._fragment;
  }

  return u;
}; // toString

SAMI.Class.addClassMethods (SAMI.URL, {
  eq: function (u1, u2) {
    // TODO: maybe we should once decode URLs and then reencode them
    u1 = (u1 || '').replace (/([^\x21-\x7E]+)/, function (s) { return encodeURI (s) });
    u2 = (u2 || '').replace (/([^\x21-\x7E]+)/, function (s) { return encodeURI (s) });
    return u1 == u2;
  } // eq
}); // URL class methods

/* --- External Object --- */

SAMI.Prefetch = {};

SAMI.Class.addClassMethods (SAMI.Prefetch, {
  URL: function (url) {
    var link = document.createElement ('link');
    link.rel = 'prefetch';
    link.href = url;
    SAMI.Element.appendToHead (link);
  } // url
}); // SAMI.Prefetch class methods

SAMI.XHR = new SAMI.Class (function (url, onsuccess, onerror) {
  try {
    this._xhr = new XMLHttpRequest ();
  } catch (e) {
    try {
      this._xhr = new ActiveXObject ('Msxml2.XMLHTTP');
    } catch (e) {
      try {
        this._xhr = new ActiveXObject ('Microsoft.XMLHTTP');
      } catch (e) {
        try {
          this._xhr = new ActiveXObject ('Msxml2.XMLHTTP.4.0');
        } catch (e) {
          this._xhr = null;
        }
      }
    }
  }

  this._url = url;
  this._onsuccess = onsuccess || function () { };
  this._onerror = onerror || function () { };
}, {
  get: function () {
    if (!this._xhr) return;

    var self = this;
    try {
      this._xhr.open ('GET', this._url, true);
      this._xhr.onreadystatechange = function () {
        self._onreadystatechange ();
      }; // onreadystatechange
      this._xhr.send (null);
    } catch (e) {
      this._xhr = new SAMI.XHR.ErrorXHR (e);
      this._onerror ();
    }
  }, // get

  post: function () { // XXX response body
    if (!this._xhr) return;

    var self = this;
    try {
      this._xhr.open ('POST', this._url, true);
      this._xhr.onreadystatechange = function () {
        self._onreadystatechange ();
      }; // onreadystatechange
      this._xhr.send (null);
    } catch (e) {
      this._xhr = new SAMI.XHR.ErrorXHR (e);
      this._onerror ();
    }
  }, // post

  _onreadystatechange: function () {
    if (this._xhr.readyState == 4) {
      if (this.succeeded ()) {
        this._onsuccess ();
      } else {
        this._onerror ();
      }
    }
  }, // _onreadystatechange

  succeeded: function () {
    return (this._xhr.status < 400);
  }, // succeeded

  getText: function () {
    return this._xhr.responseText;
  }, // getText
  getJSON: function () {
    return SAMI.JSON.parse (this._xhr.responseText);
  }, // getJSON
  getDocument: function () {
    return this._xhr.responseXML;
  }, // getDocument

  getRequestURL: function () {
    var doc = this.getDocument ();
    if (doc) {
      var url = doc.documentURI || doc.URL;
      if (url) return new SAMI.URL (url);
    }
    return new SAMI.URL (this._url); // might be wrong if redirected
  }, // getRequestURL

  getMediaTypeNoParam: function () {
    // XXX maybe we should apply HTML5 content sniffing algorithm, at
    // least for unspecified case

    var type = this.getHeaderFieldBody ('Content-Type') || 'text/plain';
    type = (type.split(/;/, 2)[0] || 'text/plain').replace (/\s+/g, '').toLowerCase ();
    return type;
  }, // getMediaTypeNoParam

  getHeaderFieldBody: function (name) {
    return this._xhr.getResponseHeader (name);
  }, // getHeaderFieldBody

  getSimpleErrorInfo: function () {
    var r = this._xhr.status + ' ' + this._xhr.statusText;
    return r;
  } // getSimpleErrorInfo

}); // XHR

SAMI.XHR.ErrorXHR = new SAMI.Class (function (e) {
  this.status = 400;
  this.statusText = e + '';
}, {
  responseText: '',
  responseXML: null,

  getResponseHeader: function () {
    return null;
  } // getResponseHeader
}); // ErrorXHR

/* --- Storage --- */

// An abstract class
SAMI.Storage = new SAMI.Class (function () {
  
}, {
  get: function (name) {
    throw "not implemented";
  }, // get
  getJSON: function (name) {
    var value = this.get (name);
    if (value != null) {
      return SAMI.JSON.parse (value); // XXX: try-catch?
    } else {
      return value;
    }
  }, // getJSON

  set: function (name, value) {
    throw "not implemented";
  }, // set
  setJSON: function (name, obj) {
    this.set (name, SAMI.JSON.stringify (obj));
  }, // setJSON

  has: function (name) {
    return this.get (name) !== undefined;
  }, // has

  del: function (name) {
    throw "del not implemented";
  }, // del

  flushGet: function (name) {
    var v = this.get ('flush-' + name);
    if (v !== undefined) {
      this.del ('flush-' + name);
    }
    return v;
  }, // flushGet
  flushSet: function (name, value) {
    this.set ('flush-' + name, value);
  }, // flushSet
  
  getNames: function () {
    throw "not implemented";
  }, // getNames

  setPrefix: function (newPrefix) {
    throw "not implemented";
  } // setPrefix
}); // Storage

SAMI.Storage.PageLocal = new SAMI.Subclass (function () {
  this.keyPrefix = '';
}, SAMI.Storage, {
  get: function (name) {
    return this['value-' + this.keyPrefix + name];
  }, // get
  set: function (name, value) {
    this['value-' + this.keyPrefix + name] = value;
  }, // set

  getNames: function () {
    var names = new SAMI.List;
    for (var n in this) {
      if (n.substring (0, 6 + this.keyPrefix.length) == 'value-' + this.keyPrefix) {
        names.push (n.substring (6 + this.keyPrefix.length));
      }
    }
    return names;
  }, // getNames
  
  setPrefix: function (newPrefix) {
    this.keyPrefix = newPrefix;
  } // setPrefix
}); // PageLocal

SAMI.Storage.Cookie = SAMI.Subclass (function () {
  this.keyPrefix = '';
  this.domain = null;
  this.path = '/';
  this.persistent = false;
  this.expires = null; // or Date
}, SAMI.Storage, {
  _parse: function () {
    return new SAMI.List (document.cookie.split (/;/)).mapToHash (function (nv) {
      nv = nv.replace (/^\s+/, '').replace (/\s+$/, '').split (/=/, 2);
      nv[0] = decodeURIComponent (nv[0]);
      nv[1] = decodeURIComponent (nv[1]);
      return nv;
    });
  }, // _parse

  get: function (name) {
    return this._parse ().getNamedItem (this.keyPrefix + name);
  }, // get
  set: function (name, value) {
    name = this.keyPrefix + name;
    var r = encodeURIComponent (name) + '=' + encodeURIComponent (value);
    if (this.domain) {
      r += '; domain=' + this.domain;
    }
    if (this.path) {
      r += '; path=' + this.path;
    }
    if (this.persistent) {
      r += '; expires=' + new Date (2030, 1-1, 1).toUTCString ();
    } else if (this.expires) {
      r += '; expires=' + this.expires.toUTCString ();
    }
    document.cookie = r;
  }, // set
  del: function (name) {
    var expires = this.expires;
    var persistent = this.persistent;
    this.expires = new Date (0);
    this.persistent = false;
    this.set (name, '');
    this.expires = expires;
    this.persistent = persistent;
  }, // del

  getNames: function () {
    var self = this;
    return this._parse ().getNames ().grep (function (name) {
      return name.substring (0, self.keyPrefix.length) == self.keyPrefix;
    }).map (function (name) {
      return name.substring (self.keyPrefix.length);
    });
  }, // getNames

  setPrefix: function (newPrefix) {
    this.keyPrefix = newPrefix;
  } // setPrefix
}); // Cookie

SAMI.Storage.Local = SAMI.Class (function () {
  var self = new SAMI.Storage.Cookie;
  self.keyPrefix = 'localStorage-';
  self.persistent = true;
  self.setPrefix = function (newPrefix) {
    this.keyPrefix = 'localStorage-' + newPrefix;
  }; // setPrefix
  return self;
}); // Local

/* --- JSON --- */

SAMI.JSON = {};

SAMI.Class.addClassMethods (SAMI.JSON, {
  parse: function (value) {
    if (self.JSON && JSON.parse) {
      return JSON.parse (value); // json2.js or ES3.1
    } else {
      return eval ('(' + value + ')');
    }
  }, // parse

  stringify: function (obj) {
    if (self.JSON && JSON.stringify) {
      return JSON.stringify (obj); // json2.js or ES3.1
    } else {
      throw "SAMI.JSON.stringify not implemented";
    }
  } // serialize
}); // JSON class methods

/* --- Parser --- */

SAMI.Parser = {};

SAMI.Parser.SimpleTokenizer = new SAMI.Class (function () {

}, {
  // _patterns

  tokenizeString: function tokenize (s) {
    var tokens = new SAMI.List;
    while (s.length) {
      if (this._patterns.forEach (function (p) {
        var match = null;
        s = s.replace (new RegExp ('^(?:' + p.pattern.source + ')'), function (_) { match = _; return '' });
        if (match != null) {
          var token = {type: p.type || match};
          if (p.code) {
            p.code (token, match);
          }
          if (!p.ignore) tokens.push (token);
          return new SAMI.List.Return (true);
        }
      })) {
        //
      } else {
        s = s.replace (/^[\s\S]/, function (_) {
        tokens.push ({type: _});
          return '';
        });
      }
    }
    tokens.push ({type: 'EOF'});
    return tokens;
  } // tokenizeString
}); // SimpleTokenizer

/* -- LR(1) Parser -- */

SAMI.Parser.LR1 = new SAMI.Class (function () {

}, {
  // _parsingTable
  // _processLR1StackObjects

  _parseTokens: function (tokens) {
    var stack = new SAMI.Parser.LR1.Stack;
    stack.push (this._parsingTable.getInitialRow ());

    while (tokens.list.length) {
      var token = tokens.shift ();
//outn ('Token: {' + token.type + ', ' + token.value + '}');
//outn ('Current stack: '  + stack);
      var state = stack.getLast ();
      var goTo = state.getCellByTokenType (token.type);
      if (goTo) {
//outn('goTo: ' + goTo );
        if (goTo.isReduction) {
          stack.pop (); // state
          var args = new SAMI.List;
          var i = goTo.reductionLength * 2 - 1;
          while (i) {
            args.unshift (stack.pop ());
            i--;
            if (i) {
              stack.pop (); // state
              i--;
            }
          }
          if (goTo.reductionType == '$start') {
            return args.list[0];
          } else {
            var pState = stack.getLast ();
            var stackObject = this._processLR1StackObjects (goTo.reductionType, args);
            stack.push (stackObject);
            var pStateGoTo = pState.getCellByTokenType (goTo.reductionType);
            stack.push (this._parsingTable.getRowByIndex (pStateGoTo.nextRowId));
            tokens.unshift (token);
          }
        } else {
          stack.push (token);
          stack.push (this._parsingTable.getRowByIndex (goTo.nextRowId));
        }
      } else {
        if (!this._onParseError (stack, token, tokens)) {
          break;
        }
      }
    }

    return null;
  }, // _parseTokens

  _onParseError: function (stack, token, tokens) {
    this.reportError ({type: 'parse error', level: 'm', token: token, value: stack + ''});
  } // _onParseError
}); // LR1

SAMI.Parser.LR1.Stack = new SAMI.Subclass (function () {
  this._super.apply (this, arguments);
}, SAMI.List, {
  toString: function () {
    return this.map (function (item) {
      if (item instanceof SAMI.Parser.LR1.ParsingTableRow) {
        return '#' + item.index;
      } else {
        return item.type;
      }
    }).list.join (', ');
  } // toString
}); // Stack

SAMI.Parser.LR1.ParsingTable = new SAMI.Subclass (function () {
  this._super.apply (this, arguments);
}, SAMI.List, {
  getInitialRow: function () {
    return this.list[0];
  }, // getInitialRow
  getRowByIndex: function (index) {
    return this.list[index];
  }, // getRowByIndex

  toString: function () {
    return this.list.join ("\n");
  }, // toString

  toSource: function () {
    return "new SAMI.Parser.LR1.ParsingTable ([\n  " + this.map (function (row) {
      return row.toSource ('  ');
    }).list.join (", \n  ") + "\n])";
  } // toSource
}); // ParsingTable

SAMI.Parser.LR1.ParsingTableRow = new SAMI.Subclass (function () {
  this._super.apply (this, arguments);
}, SAMI.Hash, {
  // index
  setIndex: function (index) {
    this.index = index;
    return this;
  }, // setIndex

  toString: function () {
    return this.index + ': ' + this.mapToList (function (n, v) {
      return n + ' -> ' + v;
    }).list.join ('; ');
  }, // toString

  toSource: function (indent) {
    indent = indent || '';
    return "new SAMI.Parser.LR1.ParsingTableRow ({\n" + indent + "  " + this.mapToList (function (n, v) {
      return '"' + n.replace (/([\u005C\u0022])/g, '\\$1') + '": ' + v.toSource ();
    }).list.join (",\n" + indent + "  ") + "\n" + indent + '}).setIndex (' + this.index + ')';
  } // toSource
}); // ParsingTableRow

SAMI.Class.addAliasMethods (SAMI.Parser.LR1.ParsingTableRow, {
  getCellByTokenType: 'get'
});

SAMI.Parser.LR1.ParsingTableCell = new SAMI.Class (function (isReduction, type, length, id) {
  this.isReduction = isReduction;
  this.reductionType = type;
  this.reductionLength = length;
  this.nextRowId = id;
}, {
  // isReduction
  // reductionType, reductionLength
  // nextRowId

  toString: function () {
    if (this.isReduction) {
      return this.reductionLength + ' -> ' + this.reductionType;
    } else {
      return '#' + this.nextRowId;
    }
  }, // toString

  toSource: function () {
    if (this.isReduction) {
      return 'new SAMI.Parser.LR1.ParsingTableCell (true, "'
          + this.reductionType.replace (/([\u005C\u0022])/g, '\\$1') + '", '
          + this.reductionLength + ')';
    } else {
      return 'new SAMI.Parser.LR1.ParsingTableCell (false, undefined, undefined, ' + this.nextRowId + ')';
    }
  } // toSource
}); // ParsingTableCell

/* --- Global --- */

SAMI.Global = {};
SAMI.Class.addClassMethods (SAMI.Global, {
  '$': function (id) {
    return document.getElementById (id);
  }, // $

  install: function () {
    for (var p in {'$': true}) {
      self[p] = this[p];
    }
  } // install
}); // SAMI.Global class methods

/* --- Onload --- */

if (SAMI.onLoadFunctions) {
  new SAMI.List (SAMI.onLoadFunctions).forEach (function (code) {
    code ();
  });
  delete SAMI.onLoadFunctions;
}

if (SAMI.isDynamicallyLoaded) {
  SAMI.windowLoaded = true;
}

/* ***** BEGIN LICENSE BLOCK *****
 * Copyright 2008-2011 Wakaba <w@suika.fam.cx>.  All rights reserved.
 *
 * This program is free software; you can redistribute it and/or 
 * modify it under the same terms as Perl itself.
 *
 * Alternatively, the contents of this file may be used 
 * under the following terms (the "MPL/GPL/LGPL"), 
 * in which case the provisions of the MPL/GPL/LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of the MPL/GPL/LGPL, and not to allow others to
 * use your version of this file under the terms of the Perl, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the MPL/GPL/LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the Perl or the MPL/GPL/LGPL.
 *
 * "MPL/GPL/LGPL":
 *
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * <http://www.mozilla.org/MPL/>
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is JSTE code.
 *
 * The Initial Developer of the Original Code is Wakaba.
 * Portions created by the Initial Developer are Copyright (C) 2008
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Wakaba <w@suika.fam.cx>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the LGPL or the GPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */
