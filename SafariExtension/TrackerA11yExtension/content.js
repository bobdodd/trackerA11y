/**
 * TrackerA11y Content Script
 * Captures detailed DOM information for focused elements
 */

(function() {
  'use strict';

  let lastFocusedSignature = '';

  function getXPath(element) {
    if (!element) return '';
    if (element.id) return `//*[@id="${element.id}"]`;
    if (element === document.body) return '/html/body';
    if (element === document.documentElement) return '/html';
    
    let ix = 0;
    const siblings = element.parentNode ? element.parentNode.childNodes : [];
    for (let i = 0; i < siblings.length; i++) {
      const sibling = siblings[i];
      if (sibling === element) {
        const parentPath = getXPath(element.parentNode);
        return `${parentPath}/${element.tagName.toLowerCase()}[${ix + 1}]`;
      }
      if (sibling.nodeType === 1 && sibling.tagName === element.tagName) {
        ix++;
      }
    }
    return '';
  }

  function getAllAttributes(element) {
    const attrs = {};
    if (!element.attributes) return attrs;
    for (let i = 0; i < element.attributes.length; i++) {
      const attr = element.attributes[i];
      attrs[attr.name] = attr.value;
    }
    return attrs;
  }

  function getComputedStyles(element) {
    try {
      const cs = window.getComputedStyle(element);
      return {
        display: cs.display,
        visibility: cs.visibility,
        opacity: cs.opacity,
        position: cs.position,
        zIndex: cs.zIndex,
        color: cs.color,
        backgroundColor: cs.backgroundColor,
        fontSize: cs.fontSize,
        fontWeight: cs.fontWeight,
        fontFamily: cs.fontFamily,
        lineHeight: cs.lineHeight,
        textAlign: cs.textAlign,
        textDecoration: cs.textDecoration,
        border: cs.border,
        borderColor: cs.borderColor,
        borderWidth: cs.borderWidth,
        borderStyle: cs.borderStyle,
        borderRadius: cs.borderRadius,
        padding: cs.padding,
        paddingTop: cs.paddingTop,
        paddingRight: cs.paddingRight,
        paddingBottom: cs.paddingBottom,
        paddingLeft: cs.paddingLeft,
        margin: cs.margin,
        marginTop: cs.marginTop,
        marginRight: cs.marginRight,
        marginBottom: cs.marginBottom,
        marginLeft: cs.marginLeft,
        width: cs.width,
        height: cs.height,
        minWidth: cs.minWidth,
        minHeight: cs.minHeight,
        maxWidth: cs.maxWidth,
        maxHeight: cs.maxHeight,
        overflow: cs.overflow,
        overflowX: cs.overflowX,
        overflowY: cs.overflowY,
        cursor: cs.cursor,
        outline: cs.outline,
        outlineColor: cs.outlineColor,
        outlineWidth: cs.outlineWidth,
        outlineStyle: cs.outlineStyle,
        outlineOffset: cs.outlineOffset,
        boxShadow: cs.boxShadow,
        pointerEvents: cs.pointerEvents,
        userSelect: cs.userSelect,
        transform: cs.transform,
        transition: cs.transition,
        animation: cs.animation,
        flexDirection: cs.flexDirection,
        justifyContent: cs.justifyContent,
        alignItems: cs.alignItems,
        gap: cs.gap,
        gridTemplateColumns: cs.gridTemplateColumns,
        gridTemplateRows: cs.gridTemplateRows
      };
    } catch (e) {
      return { error: e.message };
    }
  }

  function getElementDetails(element) {
    if (!element || element === document.body || element === document.documentElement) {
      return null;
    }

    const rect = element.getBoundingClientRect();
    let outerHTML = '';
    try {
      outerHTML = element.outerHTML || '';
      if (outerHTML.length > 1000) {
        outerHTML = outerHTML.substring(0, 1000) + '... [truncated]';
      }
    } catch (e) {
      outerHTML = `<${element.tagName.toLowerCase()}>`;
    }

    return {
      tagName: element.tagName,
      id: element.id || null,
      className: typeof element.className === 'string' ? element.className : null,
      classList: element.classList ? Array.from(element.classList) : [],
      
      type: element.type || null,
      name: element.name || null,
      value: element.value ? element.value.substring(0, 200) : null,
      placeholder: element.placeholder || null,
      href: element.href || null,
      src: element.src || null,
      alt: element.alt || null,
      title: element.title || null,
      
      textContent: element.textContent ? element.textContent.trim().substring(0, 200) : null,
      innerText: element.innerText ? element.innerText.trim().substring(0, 200) : null,
      
      role: element.getAttribute('role'),
      ariaLabel: element.getAttribute('aria-label'),
      ariaDescribedby: element.getAttribute('aria-describedby'),
      ariaLabelledby: element.getAttribute('aria-labelledby'),
      ariaExpanded: element.getAttribute('aria-expanded'),
      ariaHaspopup: element.getAttribute('aria-haspopup'),
      ariaPressed: element.getAttribute('aria-pressed'),
      ariaSelected: element.getAttribute('aria-selected'),
      ariaChecked: element.getAttribute('aria-checked'),
      ariaDisabled: element.getAttribute('aria-disabled'),
      ariaHidden: element.getAttribute('aria-hidden'),
      ariaLive: element.getAttribute('aria-live'),
      ariaAtomic: element.getAttribute('aria-atomic'),
      ariaBusy: element.getAttribute('aria-busy'),
      ariaRequired: element.getAttribute('aria-required'),
      ariaInvalid: element.getAttribute('aria-invalid'),
      ariaCurrent: element.getAttribute('aria-current'),
      ariaControls: element.getAttribute('aria-controls'),
      ariaOwns: element.getAttribute('aria-owns'),
      ariaFlowto: element.getAttribute('aria-flowto'),
      ariaValuenow: element.getAttribute('aria-valuenow'),
      ariaValuemin: element.getAttribute('aria-valuemin'),
      ariaValuemax: element.getAttribute('aria-valuemax'),
      ariaValuetext: element.getAttribute('aria-valuetext'),
      
      tabIndex: element.tabIndex,
      disabled: element.disabled || false,
      readOnly: element.readOnly || false,
      required: element.required || false,
      checked: element.checked || false,
      selected: element.selected || false,
      contentEditable: element.contentEditable,
      isContentEditable: element.isContentEditable || false,
      draggable: element.draggable || false,
      hidden: element.hidden || false,
      
      inputMode: element.inputMode || null,
      autocomplete: element.autocomplete || null,
      pattern: element.pattern || null,
      minLength: element.minLength >= 0 ? element.minLength : null,
      maxLength: element.maxLength >= 0 ? element.maxLength : null,
      min: element.min || null,
      max: element.max || null,
      step: element.step || null,
      
      form: element.form ? element.form.id || element.form.name || '[form]' : null,
      formAction: element.formAction || null,
      formMethod: element.formMethod || null,
      
      xpath: getXPath(element),
      allAttributes: getAllAttributes(element),
      computedStyles: getComputedStyles(element),
      outerHTML: outerHTML,
      
      bounds: {
        x: rect.left + window.scrollX,
        y: rect.top + window.scrollY,
        width: rect.width,
        height: rect.height,
        viewportX: rect.left,
        viewportY: rect.top,
        screenX: rect.left + window.screenX,
        screenY: rect.top + window.screenY
      },
      
      parentURL: window.location.href,
      parentTitle: document.title,
      frameId: window.frameElement ? 'iframe' : 'main',
      timestamp: Date.now()
    };
  }

  function createSignature(element) {
    if (!element) return '';
    const rect = element.getBoundingClientRect();
    return `${element.tagName}|${element.id}|${element.className}|${Math.round(rect.x)}|${Math.round(rect.y)}`;
  }

  function sendFocusEvent(element, trigger) {
    const signature = createSignature(element);
    if (signature === lastFocusedSignature) {
      return;
    }
    lastFocusedSignature = signature;

    const details = getElementDetails(element);
    if (!details) return;

    console.log('TrackerA11y CONTENT: focus on', element.tagName, element.id || element.className, 'trigger:', trigger);

    const message = {
      type: 'focus_change',
      trigger: trigger,
      element: details,
      url: window.location.href,
      title: document.title
    };

    const browserAPI = typeof browser !== 'undefined' ? browser : chrome;
    try {
      browserAPI.runtime.sendMessage(message);
      console.log('TrackerA11y CONTENT: message sent');
    } catch (e) {
      console.log('TrackerA11y CONTENT: Failed to send message', e);
    }
  }

  let lastMouseSignature = '';
  let lastHoverElement = null;

  function sendElementEvent(element, eventType, extraData = {}) {
    const details = getElementDetails(element);
    if (!details) return;

    console.log('TrackerA11y CONTENT:', eventType, 'on', element.tagName, element.id || element.className);

    const message = {
      type: eventType,
      element: details,
      url: window.location.href,
      title: document.title,
      ...extraData
    };

    const browserAPI = typeof browser !== 'undefined' ? browser : chrome;
    try {
      browserAPI.runtime.sendMessage(message);
    } catch (e) {
      console.log('TrackerA11y CONTENT: Failed to send message', e);
    }
  }

  document.addEventListener('focusin', (event) => {
    sendFocusEvent(event.target, 'focusin');
  }, true);

  document.addEventListener('mousedown', (event) => {
    const element = document.elementFromPoint(event.clientX, event.clientY);
    if (element && element !== document.body && element !== document.documentElement) {
      sendElementEvent(element, 'mouse_down', {
        button: event.button,
        clientX: event.clientX,
        clientY: event.clientY,
        screenX: event.screenX,
        screenY: event.screenY
      });
    }
  }, true);

  document.addEventListener('mouseup', (event) => {
    const element = document.elementFromPoint(event.clientX, event.clientY);
    if (element && element !== document.body && element !== document.documentElement) {
      sendElementEvent(element, 'mouse_up', {
        button: event.button,
        clientX: event.clientX,
        clientY: event.clientY,
        screenX: event.screenX,
        screenY: event.screenY
      });
    }
  }, true);

  document.addEventListener('click', (event) => {
    const element = document.elementFromPoint(event.clientX, event.clientY);
    if (element && element !== document.body && element !== document.documentElement) {
      sendElementEvent(element, 'click', {
        button: event.button,
        clientX: event.clientX,
        clientY: event.clientY,
        screenX: event.screenX,
        screenY: event.screenY
      });
    }
    
    setTimeout(() => {
      const focused = document.activeElement;
      if (focused && focused !== document.body) {
        sendFocusEvent(focused, 'click');
      }
    }, 50);
  }, true);

  document.addEventListener('mousemove', (event) => {
    const element = document.elementFromPoint(event.clientX, event.clientY);
    if (!element || element === document.body || element === document.documentElement) {
      lastHoverElement = null;
      return;
    }
    
    const signature = createSignature(element);
    if (signature !== lastMouseSignature) {
      lastMouseSignature = signature;
      lastHoverElement = element;
      
      sendElementEvent(element, 'hover', {
        clientX: event.clientX,
        clientY: event.clientY
      });
    }
  }, true);

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Tab') {
      setTimeout(() => {
        const focused = document.activeElement;
        if (focused && focused !== document.body) {
          sendFocusEvent(focused, 'tab');
        }
      }, 50);
    }
  }, true);

  if (document.activeElement && document.activeElement !== document.body) {
    sendFocusEvent(document.activeElement, 'initial');
  }

  console.log('TrackerA11y content script loaded on', window.location.href);
})();
