(function(window, undefined) {
  var dictionary = {
    "ffcb40eb-736f-4d15-a0c8-7a026775884b": "Activity",
    "4483ce38-8596-4ff0-8190-9b81c10e800a": "Login",
    "fdd11fbc-74e8-49f7-9dac-155b251d5f28": "Dahsboard",
    "d12245cc-1680-458d-89dd-4f0d7fb22724": "Intro",
    "aaac303d-f61a-4823-9059-3616d6788311": "Exercise",
    "f39803f7-df02-4169-93eb-7547fb8c961a": "Template 1",
    "bb8abf58-f55e-472d-af05-a7d1bb0cc014": "default"
  };

  var uriRE = /^(\/#)?(screens|templates|masters|scenarios)\/(.*)(\.html)?/;
  window.lookUpURL = function(fragment) {
    var matches = uriRE.exec(fragment || "") || [],
        folder = matches[2] || "",
        canvas = matches[3] || "",
        name, url;
    if(dictionary.hasOwnProperty(canvas)) { /* search by name */
      url = folder + "/" + canvas;
    }
    return url;
  };

  window.lookUpName = function(fragment) {
    var matches = uriRE.exec(fragment || "") || [],
        folder = matches[2] || "",
        canvas = matches[3] || "",
        name, canvasName;
    if(dictionary.hasOwnProperty(canvas)) { /* search by name */
      canvasName = dictionary[canvas];
    }
    return canvasName;
  };
})(window);